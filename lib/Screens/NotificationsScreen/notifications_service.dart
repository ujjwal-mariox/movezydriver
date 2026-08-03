import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:movezy_driver_app/ApiUrls/api_urls.dart';
import 'package:movezy_driver_app/Utils/PrefsManager/prefs_manager.dart';

/// One notification addressed to this driver.
class DriverNotification {
  final String id;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final DateTime? createdAt;

  DriverNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    this.createdAt,
  });

  factory DriverNotification.fromJson(Map<String, dynamic> j) =>
      DriverNotification(
        id: (j['_id'] ?? j['id'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        body: (j['body'] ?? '').toString(),
        type: (j['type'] ?? 'SYSTEM').toString(),
        isRead: j['isRead'] == true,
        createdAt: j['createdAt'] != null
            ? DateTime.tryParse(j['createdAt'].toString())
            : null,
      );
}

class NotificationsResult {
  final List<DriverNotification> notifications;
  final int unreadCount;

  NotificationsResult({required this.notifications, required this.unreadCount});
}

class NotificationsService {
  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        // Prefs.accessToken is the driver-app convention; Prefs.getString('token')
        // is the user app's and reads empty here.
        'Authorization': 'Bearer ${Prefs.accessToken}',
      };

  /// Newest first. Returns the unread count alongside, so the caller can badge
  /// without a second request.
  static Future<NotificationsResult> fetch({int page = 1, int limit = 30}) async {
    final res = await http.get(
      Uri.parse('${ApiUrls.driverNotificationsUrl}?page=$page&limit=$limit'),
      headers: _headers,
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to load notifications (${res.statusCode})');
    }

    final decoded = jsonDecode(res.body);
    // The backend wraps payloads as {code, message, data}; code 1 = success.
    final data = decoded is Map ? decoded['data'] : null;
    if (data is! Map) {
      return NotificationsResult(notifications: const [], unreadCount: 0);
    }

    final raw = (data['notifications'] as List?) ?? const [];
    return NotificationsResult(
      notifications: raw
          .whereType<Map>()
          .map((e) => DriverNotification.fromJson(e.cast<String, dynamic>()))
          .toList(),
      unreadCount: (data['unreadCount'] as num?)?.toInt() ?? 0,
    );
  }

  /// Marks one notification read, or every unread one when [id] is omitted —
  /// the backend treats a missing id as "mark all".
  static Future<bool> markRead({String? id}) async {
    final res = await http.post(
      Uri.parse(id == null || id.isEmpty
          ? '${ApiUrls.driverNotificationsUrl}/read-all'
          : '${ApiUrls.driverNotificationsUrl}/$id/read'),
      headers: _headers,
    );
    return res.statusCode == 200;
  }
}
