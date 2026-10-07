import 'package:movezy_driver_app/Services/booking_alert_service.dart';
import 'package:movezy_driver_app/Services/booking_ring_service.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:movezy_driver_app/ApiUrls/api_urls.dart';
import 'package:movezy_driver_app/Utils/PrefsManager/prefs_manager.dart';

/// Keeps the driver ONLINE while the screen is locked or the app is in the
/// background (Android).
///
/// Android suspends a plain app within seconds of the screen locking: the
/// socket drops, the GPS timer stops, and the server used to mark the driver
/// offline — while the app still said "Online". A foreground service (the
/// persistent "you're online" notification) keeps the process alive, and its
/// task isolate posts a heartbeat with the current position every minute.
/// The server keeps a driver online as long as any heartbeat arrives within
/// its grace window, and refreshes their dispatch position from it.
///
/// iOS has no equivalent; there the app stays online while in the foreground,
/// as before.
class BackgroundPresenceService {
  BackgroundPresenceService._();

  static const String _kToken = 'presence_token';
  static const String _kUrl = 'presence_heartbeat_url';
  static const String _kOffersUrl = 'presence_offers_url';
  static const String _kOfferSeen = 'presence_offer_seen';
  static const int _serviceId = 1001;
  static bool _initialised = false;
  static Future<void> _operation = Future.value();

  // Starting and stopping touch the same native service. Preserve their order
  // when permissions or a platform response arrive after an Offline action.
  static Future<T> _enqueue<T>(Future<T> Function() action) {
    final result = Completer<T>();
    _operation = _operation.then((_) async {
      try {
        result.complete(await action());
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    return result.future;
  }

  static Future<void> init() async {
    if (!Platform.isAndroid || _initialised) return;
    _initialised = true;
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.addTaskDataCallback((data) {
      if (data is Map && data['offers'] is List) {
        BookingAlertService.instance.handleRecoveredOffers(
          data['offers'] as List,
        );
      }
    });
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'movezy_online_status',
        channelName: 'Online status',
        channelDescription: 'Shown while you are online and receiving bookings',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
        showWhen: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5 * 1000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// Start (or refresh) the service. Safe to call repeatedly.
  static Future<bool> start() => _enqueue(_start);

  static Future<bool> _start() async {
    if (!Platform.isAndroid) return true;
    await init();

    // Battery optimisation kills background work on many OEM builds even with
    // a foreground service; ask once for the exemption.
    try {
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
    } catch (e) {
      debugPrint('presence: battery optimisation prompt failed: $e');
    }
    try {
      final perm = await FlutterForegroundTask.checkNotificationPermission();
      if (perm != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
    } catch (e) {
      debugPrint('presence: notification permission prompt failed: $e');
    }

    // The task runs in its own isolate with no access to Prefs — hand it what
    // it needs through the plugin's store.
    await FlutterForegroundTask.saveData(
      key: _kToken,
      value: Prefs.accessToken,
    );
    await FlutterForegroundTask.saveData(
      key: _kUrl,
      value: ApiUrls.driverHeartbeatUrl,
    );
    await FlutterForegroundTask.saveData(
      key: _kOffersUrl,
      value: ApiUrls.driverIncomingOffersUrl,
    );

    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.updateService(
          notificationTitle: 'Movezy — you are online',
          notificationText:
              'Receiving bookings. Keep this running to stay online.',
        );
        return true;
      }
      final result = await FlutterForegroundTask.startService(
        serviceId: _serviceId,
        serviceTypes: [ForegroundServiceTypes.location],
        notificationTitle: 'Movezy — you are online',
        notificationText:
            'Receiving bookings. Keep this running to stay online.',
        callback: presenceTaskCallback,
      );
      if (result is ServiceRequestFailure) return false;
      return await FlutterForegroundTask.isRunningService;
    } catch (e) {
      debugPrint('presence: foreground service start failed: $e');
      return false;
    }
  }

  static Future<void> noteOffer(String key) async {
    if (!Platform.isAndroid) return;
    await FlutterForegroundTask.saveData(key: _kOfferSeen, value: key);
  }

  static Future<void> stop() => _enqueue(_stop);

  static Future<void> _stop() async {
    if (!Platform.isAndroid) return;
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (e) {
      debugPrint('presence: foreground service stop failed: $e');
    }
  }

  /// One heartbeat from the main isolate (app resume, socket reconnect).
  static Future<void> sendHeartbeat({String source = 'app'}) async {
    final token = Prefs.accessToken;
    if (token.isEmpty) return;
    double? lat;
    double? lng;
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      lat = p.latitude;
      lng = p.longitude;
    } catch (_) {
      // Position is optional; the heartbeat alone keeps the driver online.
    }
    await _post(ApiUrls.driverHeartbeatUrl, token, lat, lng, source);
  }

  static Future<void> _post(
    String url,
    String token,
    double? lat,
    double? lng,
    String source,
  ) async {
    try {
      await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'source': source,
              if (lat != null) 'lat': lat,
              if (lng != null) 'lng': lng,
            }),
          )
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      debugPrint('presence: heartbeat failed ($source): $e');
    }
  }
}

/// Entry point for the service isolate — must be top-level.
@pragma('vm:entry-point')
void presenceTaskCallback() {
  FlutterForegroundTask.setTaskHandler(_PresenceTaskHandler());
}

class _PresenceTaskHandler extends TaskHandler {
  bool _polling = false;
  bool _beating = false;
  DateTime? _lastBeat;
  String? _notifiedBooking;

  void _tick() {
    unawaited(_pollOffers());
    if (_lastBeat == null ||
        DateTime.now().difference(_lastBeat!) >= const Duration(seconds: 60)) {
      unawaited(_beat());
    }
  }

  Future<void> _pollOffers() async {
    if (_polling) return;
    _polling = true;
    try {
      final token = await FlutterForegroundTask.getData<String>(
        key: BackgroundPresenceService._kToken,
      );
      final url = await FlutterForegroundTask.getData<String>(
        key: BackgroundPresenceService._kOffersUrl,
      );
      if (token == null || token.isEmpty || url == null) return;
      final response = await http
          .get(Uri.parse(url), headers: {'Authorization': 'Bearer ' + token})
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['data'] is! List) return;
      final offers = body['data'] as List;
      final ring = BookingRingService.instance;
      await ring.init(handleLaunch: false);
      if (_notifiedBooking != null &&
          !offers.any((o) => o['bookingId'] == _notifiedBooking)) {
        await ring.cancelBookingNotification(_notifiedBooking!);
        _notifiedBooking = null;
      }
      for (final offer in offers) {
        final id = offer['bookingId']?.toString() ?? '';
        final expires = (offer['expiresAt'] as num?)?.toInt() ?? 0;
        final remaining = expires - DateTime.now().millisecondsSinceEpoch;
        if (id.isEmpty || remaining <= 0) continue;
        final key = id + ':' + expires.toString();
        final seen = await FlutterForegroundTask.getData<String>(
          key: BackgroundPresenceService._kOfferSeen,
        );
        if (key != seen) {
          await BackgroundPresenceService.noteOffer(key);
          await ring.showBookingNotification(
            bookingId: id,
            pickup: offer['pickup']?['address']?.toString() ?? '',
            fare: (offer['estimatedFare'] as num?)?.toDouble() ?? 0,
            expiresIn: Duration(milliseconds: remaining),
          );
          _notifiedBooking = id;
        }
      }
      FlutterForegroundTask.sendDataToMain({'offers': offers});
    } catch (e) {
      debugPrint('presence: offer recovery failed: $e');
    } finally {
      _polling = false;
    }
  }

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _tick();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _tick();
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }

  Future<void> _beat() async {
    if (_beating) return;
    _beating = true;
    _lastBeat = DateTime.now();
    try {
      final token = await FlutterForegroundTask.getData<String>(
        key: BackgroundPresenceService._kToken,
      );
      final url = await FlutterForegroundTask.getData<String>(
        key: BackgroundPresenceService._kUrl,
      );
      if (token == null || token.isEmpty || url == null || url.isEmpty) return;
      double? lat;
      double? lng;
      try {
        final p = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 20),
          ),
        );
        lat = p.latitude;
        lng = p.longitude;
      } catch (_) {
        // Keep the heartbeat even without a fix.
      }
      await BackgroundPresenceService._post(
        url,
        token,
        lat,
        lng,
        'foreground-service',
      );
    } finally {
      _beating = false;
    }
  }
}
