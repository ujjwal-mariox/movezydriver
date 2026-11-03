import 'dart:convert';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:movezy_driver_app/ApiUrls/api_urls.dart';
import 'package:movezy_driver_app/Utils/PrefsManager/prefs_manager.dart';

/// A support ticket summary (list row).
class SupportTicket {
  final String id; // Mongo _id
  final String ticketId; // human TKT... id
  final String subject;
  final String status;
  final String category;
  final DateTime? createdAt;
  final DateTime? lastMessageAt;

  SupportTicket({
    required this.id,
    required this.ticketId,
    required this.subject,
    required this.status,
    required this.category,
    this.createdAt,
    this.lastMessageAt,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> j) => SupportTicket(
        id: j['_id']?.toString() ?? '',
        ticketId: j['ticketId']?.toString() ?? '',
        subject: j['subject']?.toString() ?? 'Support request',
        status: j['status']?.toString() ?? 'OPEN',
        category: j['category']?.toString() ?? '',
        createdAt: _date(j['createdAt']),
        lastMessageAt: _date(j['lastMessageAt']),
      );

  static DateTime? _date(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
}

/// A single message in a ticket thread.
class SupportMessage {
  final String? id;
  final String senderType; // DRIVER | ADMIN | SYSTEM
  final String message;
  final DateTime createdAt;

  SupportMessage({
    this.id,
    required this.senderType,
    required this.message,
    required this.createdAt,
  });

  factory SupportMessage.fromJson(Map<String, dynamic> j) => SupportMessage(
        id: j['_id']?.toString(),
        senderType: j['senderType']?.toString() ?? 'DRIVER',
        message: j['message']?.toString() ?? '',
        createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? '')
                ?.toLocal() ??
            DateTime.now(),
      );

  bool get isMe => senderType == 'DRIVER';
}

class SupportChatService {
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${Prefs.accessToken}',
      };

  /// List the driver's tickets.
  Future<List<SupportTicket>> getTickets() async {
    try {
      final res = await http
          .get(Uri.parse(ApiUrls.driverSupportTicketsUrl), headers: _headers)
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final data = body['data'] ?? body;
        final list = (data is List) ? data : (data['tickets'] ?? []);
        return (list as List)
            .map((e) => SupportTicket.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// The guided support tree, in the app's language (English when the
  /// server has no translation). Empty when it can't be loaded.
  Future<List<Map<String, dynamic>>> getFlow() async {
    try {
      final lang = Get.locale?.languageCode ?? 'en';
      final res = await http
          .get(Uri.parse('${ApiUrls.driverSupportFlowUrl}?lang=$lang'),
              headers: _headers)
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body)['data'];
        final List rows = (data is Map ? data['flow'] : null) ?? [];
        return rows.map((r) => Map<String, dynamic>.from(r)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Create a new ticket. Returns the created ticket's human id, or null.
  /// With [supportNodeId] (an issue picked in the guided chat) the server sets
  /// the category, subject and priority, so those may be left out.
  Future<String?> createTicket({
    String? category,
    String? subject,
    required String message,
    String? bookingId,
    String? supportNodeId,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse(ApiUrls.driverRaiseTicketUrl),
            headers: _headers,
            body: jsonEncode({
              if (category != null) 'category': category,
              if (subject != null) 'subject': subject,
              'message': message,
              if (bookingId != null && bookingId.isNotEmpty)
                'bookingId': bookingId,
              if (supportNodeId != null) 'supportNodeId': supportNodeId,
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 200 || res.statusCode == 201) {
        final body = jsonDecode(res.body);
        final data = body['data'] ?? body;
        return data is Map ? data['ticketId']?.toString() : null;
      }
    } catch (_) {}
    return null;
  }

  /// Fetch a ticket's message thread, plus the chips to offer for the
  /// driver's reply after a support message (from the issue picked).
  Future<(List<SupportMessage>, List<String>)> getMessages(
      String ticketId) async {
    try {
      final lang = Get.locale?.languageCode ?? 'en';
      final res = await http
          .get(
              Uri.parse(
                  '${ApiUrls.driverSupportTicketDetailsUrl(ticketId)}?lang=$lang'),
              headers: _headers)
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final data = body['data'] ?? body;
        final msgs = (data is Map ? data['messages'] : null) ?? [];
        final followUps = (data is Map ? data['followUps'] : null) ?? [];
        return (
          (msgs as List)
              .map((e) => SupportMessage.fromJson(e as Map<String, dynamic>))
              .toList(),
          (followUps as List).map((e) => e.toString()).toList(),
        );
      }
    } catch (_) {}
    return (<SupportMessage>[], <String>[]);
  }

  /// Send a reply on an existing ticket.
  Future<bool> reply(String ticketId, String message) async {
    try {
      final res = await http
          .post(
            Uri.parse(ApiUrls.driverSupportTicketReplyUrl(ticketId)),
            headers: _headers,
            body: jsonEncode({'message': message}),
          )
          .timeout(const Duration(seconds: 20));
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }
}

/// Live delivery of admin replies via socket. The backend emits
/// `support:message` to room `user:<driverId>` when an admin replies on the
/// DRIVER channel.
class SupportSocket {
  IO.Socket? _socket;
  final void Function(String ticketId, SupportMessage msg) onMessage;

  SupportSocket({required this.onMessage});

  void connect() {
    _socket = IO.io(
      ApiUrls.socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setAuth({'token': Prefs.accessToken})
          // Own connection: dispose() below would otherwise kill the shared
          // socket used by the dashboard and location tracking.
          .enableForceNew()
          .enableAutoConnect()
          .enableReconnection()
          .build(),
    );

    _socket!.on('support:message', (data) {
      try {
        final map = data as Map<String, dynamic>;
        final ticketId = map['ticketId']?.toString() ?? '';
        onMessage(ticketId, SupportMessage.fromJson(map));
      } catch (_) {}
    });
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
  }
}
