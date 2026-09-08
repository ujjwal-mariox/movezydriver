import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// The bell: an in-app looping ring for a new booking offer, plus the
/// heads-up notification (with the same sound) for when the app is in the
/// background or the screen is locked.
///
/// Before this, a new booking arrived silently — a driver looking away from
/// the screen simply missed it, and with one-at-a-time dispatch a missed ring
/// hands the job to the next driver.
class BookingRingService {
  BookingRingService._();
  static final BookingRingService instance = BookingRingService._();

  static const String _bookingChannelId = 'booking_requests_v2';
  static const String _chatChannelId = 'chat_messages_v1';

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  AudioPlayer? _player;
  bool _initialised = false;
  bool _ringing = false;

  /// Receives the notification payload ("booking:<id>" or "chat:<id>").
  void Function(String payload)? onNotificationTap;

  bool get isRinging => _ringing;

  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _notifications.initialize(
        settings: const InitializationSettings(android: android, iOS: ios),
        onDidReceiveNotificationResponse: (resp) {
          final p = resp.payload;
          if (p != null && p.isNotEmpty) onNotificationTap?.call(p);
        },
      );

      final androidImpl = _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        // Android caches a channel's sound forever; a new id is the only way
        // to change it, hence the version suffix.
        await androidImpl.createNotificationChannel(
          AndroidNotificationChannel(
            _bookingChannelId,
            'Booking requests',
            description: 'Rings when a new booking is offered to you',
            importance: Importance.max,
            playSound: true,
            sound: const RawResourceAndroidNotificationSound('booking_bell'),
            enableVibration: true,
          ),
        );
        await androidImpl.createNotificationChannel(
          const AndroidNotificationChannel(
            _chatChannelId,
            'Customer messages',
            description: 'Messages from the customer on your current trip',
            importance: Importance.high,
          ),
        );
      }

      // App opened from a notification while it was killed.
      final launch = await _notifications.getNotificationAppLaunchDetails();
      final p = launch?.notificationResponse?.payload;
      if (launch?.didNotificationLaunchApp == true && p != null && p.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) => onNotificationTap?.call(p));
      }
    } catch (e) {
      debugPrint('ring: notification init failed: $e');
    }
  }

  Future<void> requestPermission() async {
    if (!Platform.isAndroid) return;
    try {
      await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (_) {}
  }

  Future<void> startRing() async {
    if (_ringing) return;
    _ringing = true;
    try {
      _player ??= AudioPlayer();
      await _player!.setReleaseMode(ReleaseMode.loop);
      await _player!.play(AssetSource('sounds/booking_bell.wav'), volume: 1.0);
    } catch (e) {
      debugPrint('ring: play failed: $e');
    }
  }

  Future<void> stopRing() async {
    if (!_ringing) return;
    _ringing = false;
    try {
      await _player?.stop();
    } catch (_) {}
  }

  static int _idFor(String payload) => payload.hashCode & 0x7fffffff;

  Future<void> showBookingNotification({
    required String bookingId,
    required String pickup,
    double fare = 0,
  }) async {
    try {
      await _notifications.show(
        id: _idFor('booking:$bookingId'),
        title: 'New booking request',
        body: [if (fare > 0) '₹${fare.toStringAsFixed(0)}', if (pickup.isNotEmpty) 'Pickup: $pickup']
            .join(' · '),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _bookingChannelId,
            'Booking requests',
            channelDescription: 'Rings when a new booking is offered to you',
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.call,
            fullScreenIntent: true,
            playSound: true,
            sound: const RawResourceAndroidNotificationSound('booking_bell'),
            enableVibration: true,
            ticker: 'New booking request',
            autoCancel: true,
          ),
          iOS: const DarwinNotificationDetails(presentSound: true, presentAlert: true),
        ),
        payload: 'booking:$bookingId',
      );
    } catch (e) {
      debugPrint('ring: booking notification failed: $e');
    }
  }

  Future<void> cancelBookingNotification(String bookingId) async {
    try {
      await _notifications.cancel(id: _idFor('booking:$bookingId'));
    } catch (_) {}
  }

  Future<void> showChatNotification({
    required String bookingId,
    required String preview,
  }) async {
    try {
      await _notifications.show(
        id: _idFor('chat:$bookingId'),
        title: 'New message from the customer',
        body: preview,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _chatChannelId,
            'Customer messages',
            channelDescription: 'Messages from the customer on your current trip',
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.message,
            autoCancel: true,
          ),
          iOS: DarwinNotificationDetails(presentSound: true, presentAlert: true),
        ),
        payload: 'chat:$bookingId',
      );
    } catch (e) {
      debugPrint('ring: chat notification failed: $e');
    }
  }
}
