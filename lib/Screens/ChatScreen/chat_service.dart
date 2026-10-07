import 'dart:math';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:movezy_driver_app/ApiUrls/api_urls.dart';
import 'package:movezy_driver_app/Utils/PrefsManager/prefs_manager.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class ChatMessage {
  final String? id;
  final String bookingId;
  final String senderId;
  final String senderType;
  final String messageType;
  final String message;
  final String? imageUrl;
  final String? clientMessageId;
  final DateTime createdAt;

  ChatMessage({
    this.id,
    required this.bookingId,
    required this.senderId,
    required this.senderType,
    required this.messageType,
    required this.message,
    this.imageUrl,
    this.clientMessageId,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['_id']?.toString(),
      bookingId: json['bookingId']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      senderType: json['senderType']?.toString() ?? 'USER',
      messageType: json['messageType']?.toString() ?? 'TEXT',
      message: json['message']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString(),
      clientMessageId: json['clientMessageId']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
    );
  }

  bool get isMe => senderType == 'DRIVER';
  bool get isImage => messageType == 'IMAGE';
}

class ChatService {
  IO.Socket? _socket;
  final String bookingId;
  final http.Client _historyClient;
  final String Function() _tokenProvider;
  final bool _ownsClient;
  final IO.Socket Function(String, Map<String, dynamic>) _socketFactory;
  bool _disposed = false;
  Future<void>? _historyRequest;
  bool _reloadRequested = false;
  Completer<bool>? _delivery;
  String? _retryText;
  String? _retryId;
  final ValueNotifier<List<ChatMessage>> messages = ValueNotifier([]);
  final ValueNotifier<bool> isConnected = ValueNotifier(false);
  final ValueNotifier<String?> error = ValueNotifier(null);

  ChatService({
    required this.bookingId,
    http.Client? historyClient,
    String Function()? tokenProvider,
    IO.Socket Function(String, Map<String, dynamic>)? socketFactory,
  }) : _historyClient = historyClient ?? http.Client(),
       _ownsClient = historyClient == null,
       _socketFactory = socketFactory ?? IO.io,
       _tokenProvider = tokenProvider ?? (() => Prefs.accessToken);

  String get _token => _tokenProvider();

  void connect() {
    if (_disposed || _socket != null) return;
    _socket = _socketFactory(
      ApiUrls.socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setAuth({'token': _token})
          .enableForceNew()
          .disableAutoConnect()
          .enableReconnection()
          .build(),
    );
    _socket!.onConnect((_) {
      if (_disposed) return;
      isConnected.value = true;
      _socket!.emit('chat:join', {'bookingId': bookingId});
      _socket!.emit('chat:read', {'bookingId': bookingId});
      // REST recovers anything sent while this socket was disconnected.
      unawaited(loadHistory());
    });
    _socket!.onDisconnect((_) {
      if (!_disposed) isConnected.value = false;
    });
    _socket!.onConnectError((_) {
      if (!_disposed) isConnected.value = false;
    });
    _socket!.on('chat:message', (data) {
      if (_disposed || data is! Map) return;
      final msg = ChatMessage.fromJson(Map<String, dynamic>.from(data));
      if (msg.bookingId != bookingId) return;
      _merge([msg]);
      // Older servers echo persisted messages without an acknowledgement/nonce.
      if (msg.isMe &&
          msg.message == _retryText &&
          (msg.clientMessageId == _retryId || msg.clientMessageId == null)) {
        _confirmDelivery(true);
      }
      _socket!.emit('chat:read', {'bookingId': bookingId});
    });
    _socket!.on('chat:error', (data) {
      if (!_disposed)
        _report(
          data is Map
              ? data['message']?.toString() ?? 'Unable to send message'
              : 'Unable to send message',
        );
    });
    _socket!.connect();
  }

  void _report(String message) {
    if (_disposed) return;
    error.value = null;
    error.value = message;
  }

  bool _canSend() {
    if (_disposed) return false;
    if (_socket?.connected != true) {
      _report('Chat is reconnecting. Please try again when connected.');
      return false;
    }
    return true;
  }

  void _confirmDelivery(bool success) {
    final delivery = _delivery;
    if (delivery != null && !delivery.isCompleted) delivery.complete(success);
  }

  Future<bool> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || !_canSend()) return false;
    if (_delivery != null) {
      _report('Your message is still being sent. Please wait.');
      return false;
    }
    if (_retryText != trimmed || _retryId == null) {
      _retryText = trimmed;
      final random = Random.secure();
      _retryId = List.generate(
        12,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
    }
    final delivery = Completer<bool>();
    _delivery = delivery;
    _socket!.emitWithAck(
      'chat:message',
      {
        'bookingId': bookingId,
        'message': trimmed,
        'messageType': 'TEXT',
        'clientMessageId': _retryId,
      },
      ack: (data) {
        if (_disposed || !identical(_delivery, delivery)) return;
        if (data is Map && data['success'] == true && data['message'] is Map) {
          _merge([
            ChatMessage.fromJson(
              Map<String, dynamic>.from(data['message'] as Map),
            ),
          ]);
        }
        _confirmDelivery(data is Map && data['success'] == true);
      },
    );
    final sent = await delivery.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => false,
    );
    if (identical(_delivery, delivery)) _delivery = null;
    if (sent) {
      _retryId = null;
      _retryText = null;
    } else {
      _report(
        'Message delivery was not confirmed. Your draft is kept; please retry.',
      );
      unawaited(loadHistory());
    }
    return sent;
  }

  Future<void> sendImage(File imageFile) async {
    if (!_canSend()) return;
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiUrls.chatUploadImageUrl(bookingId)),
      );
      request.headers['Authorization'] = 'Bearer $_token';
      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
          contentType: MediaType('image', 'jpeg'),
        ),
      );
      final streamed = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final response = await http.Response.fromStream(streamed);
      if (_disposed) return;
      if (response.statusCode != 200) {
        _report('Unable to upload image. Please try again.');
        return;
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final url = body['data']?['imageUrl'];
      final imageUrl = url is List
          ? (url.isEmpty ? null : url.first.toString())
          : url?.toString();
      if (imageUrl == null || imageUrl.isEmpty) {
        _report('Unable to upload image. Please try again.');
        return;
      }
      if (!_canSend()) return;
      _socket!.emit('chat:message', {
        'bookingId': bookingId,
        'message': '',
        'messageType': 'IMAGE',
        'imageUrl': imageUrl,
      });
    } catch (_) {
      _report('Unable to send image. Please try again.');
    }
  }

  void _merge(Iterable<ChatMessage> incoming) {
    if (_disposed) return;
    final byId = <String, ChatMessage>{};
    for (final m in [...messages.value, ...incoming]) {
      final key =
          m.id ??
          (m.senderId +
              ':' +
              m.createdAt.toIso8601String() +
              ':' +
              m.message +
              ':' +
              (m.imageUrl ?? ''));
      byId[key] = m;
      if (m.isMe &&
          m.clientMessageId != null &&
          m.clientMessageId == _retryId) {
        _confirmDelivery(true);
      }
    }
    final merged = byId.values.toList()
      ..sort((a, b) {
        final time = a.createdAt.compareTo(b.createdAt);
        return time != 0 ? time : (a.id ?? '').compareTo(b.id ?? '');
      });
    messages.value = merged;
  }

  Future<void> loadHistory() {
    if (_disposed) return Future.value();
    if (_historyRequest != null) {
      _reloadRequested = true;
      return _historyRequest!;
    }
    return _historyRequest = _loadHistory().whenComplete(() {
      _historyRequest = null;
      if (_reloadRequested && !_disposed) {
        _reloadRequested = false;
        unawaited(loadHistory());
      }
    });
  }

  Future<void> _loadHistory() async {
    try {
      var page = 1;
      var pages = 1;
      do {
        final base = Uri.parse(ApiUrls.chatHistoryUrl(bookingId));
        final response = await _historyClient
            .get(
              base.replace(
                queryParameters: {
                  ...base.queryParameters,
                  'page': '$page',
                  'limit': '100',
                },
              ),
              headers: {
                'Authorization': 'Bearer $_token',
                'Content-Type': 'application/json',
              },
            )
            .timeout(const Duration(seconds: 20));
        if (_disposed) return;
        if (response.statusCode != 200) throw StateError('History unavailable');
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final data = body['data'] as Map<String, dynamic>? ?? {};
        final list = data['messages'] as List? ?? [];
        _merge(
          list.map(
            (m) => ChatMessage.fromJson(Map<String, dynamic>.from(m as Map)),
          ),
        );
        pages = (data['pagination']?['pages'] as num?)?.toInt() ?? 1;
        page++;
      } while (page <= pages && !_disposed);
    } catch (_) {
      _report('Unable to load chat history. Reopen chat to try again.');
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _confirmDelivery(false);
    _socket?.emit('chat:leave', {'bookingId': bookingId});
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    if (_ownsClient) _historyClient.close();
    messages.dispose();
    isConnected.dispose();
    error.dispose();
  }
}
