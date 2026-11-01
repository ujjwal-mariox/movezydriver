import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:movezy_driver_app/ApiUrls/api_urls.dart';
import 'package:movezy_driver_app/Services/booking_alert_service.dart';
import 'package:movezy_driver_app/Services/booking_ring_service.dart';
import 'package:movezy_driver_app/Utils/PrefsManager/prefs_manager.dart';

/// Push notifications (Firebase Cloud Messaging).
///
/// The backend already sends pushes for booking offers, verification and
/// vehicle approvals, account status, training and document reminders, but
/// nothing arrived because the app never registered the phone. This
/// registers it, shows pushes while the app is open, and routes taps through
/// the same handler as the ring's own notifications.
///
/// Notification permission is asked by the splash screen
/// (PermissionService), so registering here never prompts.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  // Classic FCM registration tokens: firebase_messaging 17 deprecates them in
  // favour of register()/onRegistered, which yield installation IDs for a
  // newer send model. The backend's firebase-admin sends to tokens, so the
  // token calls stay until the backend moves too.
  bool _ready = false;

  /// Call once before runApp, after BookingRingService.init (its plugin shows
  /// the foreground notifications and owns the tap handler).
  Future<void> init() async {
    if (_ready || kIsWeb) return;
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('push: Firebase init failed: $e');
      return;
    }
    _ready = true;

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
    FirebaseMessaging.onMessage.listen(_showWhileOpen);
    FirebaseMessaging.onMessageOpenedApp.listen((m) => _open(m.data));
    // ignore: deprecated_member_use
    FirebaseMessaging.instance.onTokenRefresh.listen(_uploadToken);

    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _open(initial.data));
    }

    // Existing session: make sure the server has this phone's current token.
    unawaited(registerDevice());
  }

  /// Sends this phone's token to the server. Call after login too, so a
  /// driver still in onboarding gets "verification approved".
  Future<void> registerDevice() async {
    if (!_ready || Prefs.getString('access_token').isEmpty) return;
    try {
      // ignore: deprecated_member_use
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _uploadToken(token);
    } catch (e) {
      debugPrint('push: register failed: $e');
    }
  }

  /// On logout: retire this phone's token, so the next driver signed in on
  /// the phone doesn't receive this driver's offers and account messages.
  Future<void> unregisterDevice() async {
    if (!_ready) return;
    try {
      // ignore: deprecated_member_use
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }

  Future<void> _uploadToken(String fcmToken) async {
    final auth = Prefs.getString('access_token');
    if (auth.isEmpty) return;
    try {
      await http
          .put(
            Uri.parse(ApiUrls.driverFcmTokenUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $auth',
            },
            body: jsonEncode({'fcmToken': fcmToken}),
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('push: token upload failed: $e');
    }
  }

  void _showWhileOpen(RemoteMessage message) {
    final n = message.notification;
    if (n == null || !Platform.isAndroid) return;
    // With the app open, offers and chat already arrive over the socket with
    // the in-app popup and ring; a second alert would double up.
    final type = message.data['type']?.toString() ?? '';
    if (type == 'BOOKING_REQUEST' || type == 'CHAT') return;
    BookingRingService.instance.showGeneralNotification(
      title: n.title ?? 'Movezy',
      body: n.body ?? '',
      payload: _payloadFor(message.data),
    );
  }

  void _open(Map<String, dynamic> data) {
    final payload = _payloadFor(data);
    if (payload.isEmpty || Prefs.getString('access_token').isEmpty) return;
    BookingAlertService.instance.handleNotificationTap(payload);
  }

  /// Same payload form as the ring's notifications: `chat:<id>` for chat,
  /// `booking:<id>` for anything about a booking, empty to just open the app.
  static String _payloadFor(Map<String, dynamic> data) {
    final bookingId = data['bookingId']?.toString() ?? '';
    if (bookingId.isEmpty) return '';
    return data['type'] == 'CHAT' ? 'chat:$bookingId' : 'booking:$bookingId';
  }
}
