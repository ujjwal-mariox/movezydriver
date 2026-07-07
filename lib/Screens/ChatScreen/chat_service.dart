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
  final DateTime createdAt;

  ChatMessage({
    this.id,
    required this.bookingId,
    required this.senderId,
    required this.senderType,
    required this.messageType,
    required this.message,
    this.imageUrl,
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
  final ValueNotifier<List<ChatMessage>> messages = ValueNotifier([]);
  final ValueNotifier<bool> isConnected = ValueNotifier(false);

  ChatService({required this.bookingId});

  /// Connect to socket and join booking room
  void connect() {
    _socket = IO.io(
      ApiUrls.socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setAuth({'token': Prefs.accessToken})
          .enableAutoConnect()
          .enableReconnection()
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('Chat socket connected');
      isConnected.value = true;
      _socket!.emit('chat:join', {'bookingId': bookingId});
      // Mark existing messages as read
      _socket!.emit('chat:read', {'bookingId': bookingId});
    });

    _socket!.onDisconnect((_) {
      debugPrint('Chat socket disconnected');
      isConnected.value = false;
    });

    _socket!.onConnectError((data) {
      debugPrint('Chat socket connection error: $data');
      isConnected.value = false;
    });

    // Listen for incoming messages
    _socket!.on('chat:message', (data) {
      final msg = ChatMessage.fromJson(data as Map<String, dynamic>);
      final current = List<ChatMessage>.from(messages.value);
      // Avoid duplicates
      if (msg.id != null && current.any((m) => m.id == msg.id)) return;
      current.add(msg);
      messages.value = current;
    });

    _socket!.on('chat:error', (data) {
      debugPrint('Chat error: $data');
    });
  }

  /// Send a text message
  void sendMessage(String text) {
    if (text.trim().isEmpty || _socket == null) return;

    _socket!.emit('chat:message', {
      'bookingId': bookingId,
      'message': text.trim(),
      'messageType': 'TEXT',
    });
  }

  /// Send an image message (upload first, then emit via socket)
  Future<void> sendImage(File imageFile) async {
    try {
      final imageUrl = await _uploadImage(imageFile);
      if (imageUrl == null) return;

      _socket!.emit('chat:message', {
        'bookingId': bookingId,
        'message': '',
        'messageType': 'IMAGE',
        'imageUrl': imageUrl,
      });
    } catch (e) {
      debugPrint('Error sending image: $e');
    }
  }

  /// Upload image via REST API, returns the URL
  Future<String?> _uploadImage(File imageFile) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiUrls.chatUploadImageUrl(bookingId)),
      );

      request.headers['Authorization'] = 'Bearer ${Prefs.accessToken}';
      request.files.add(await http.MultipartFile.fromPath(
        'image',
        imageFile.path,
        contentType: MediaType('image', 'jpeg'),
      ));

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return body['data']?['imageUrl']?.toString();
      }
      return null;
    } catch (e) {
      debugPrint('Image upload error: $e');
      return null;
    }
  }

  /// Load chat history from REST API
  Future<void> loadHistory() async {
    try {
      final response = await http.get(
        Uri.parse(ApiUrls.chatHistoryUrl(bookingId)),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Prefs.accessToken}',
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final list = body['data']?['messages'] as List? ?? [];
        messages.value = list
            .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading chat history: $e');
    }
  }

  /// Disconnect and clean up
  void dispose() {
    _socket?.emit('chat:leave', {'bookingId': bookingId});
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    messages.dispose();
    isConnected.dispose();
  }
}
