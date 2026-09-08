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
  static const int _serviceId = 1001;
  static bool _initialised = false;

  static Future<void> init() async {
    if (!Platform.isAndroid || _initialised) return;
    _initialised = true;
    FlutterForegroundTask.initCommunicationPort();
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
        eventAction: ForegroundTaskEventAction.repeat(60 * 1000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// Start (or refresh) the service. Safe to call repeatedly.
  static Future<void> start() async {
    if (!Platform.isAndroid) return;
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
    await FlutterForegroundTask.saveData(key: _kToken, value: Prefs.accessToken);
    await FlutterForegroundTask.saveData(key: _kUrl, value: ApiUrls.driverHeartbeatUrl);

    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.updateService(
          notificationTitle: 'Movezy — you are online',
          notificationText: 'Receiving bookings. Keep this running to stay online.',
        );
        return;
      }
      final result = await FlutterForegroundTask.startService(
        serviceId: _serviceId,
        serviceTypes: [ForegroundServiceTypes.location],
        notificationTitle: 'Movezy — you are online',
        notificationText: 'Receiving bookings. Keep this running to stay online.',
        callback: presenceTaskCallback,
      );
      debugPrint('presence: foreground service start → $result');
    } catch (e) {
      debugPrint('presence: foreground service start failed: $e');
    }
  }

  static Future<void> stop() async {
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

  static Future<void> _post(String url, String token, double? lat, double? lng, String source) async {
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
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await _beat();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _beat();
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }

  Future<void> _beat() async {
    final token = await FlutterForegroundTask.getData<String>(key: BackgroundPresenceService._kToken);
    final url = await FlutterForegroundTask.getData<String>(key: BackgroundPresenceService._kUrl);
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
    await BackgroundPresenceService._post(url, token, lat, lng, 'foreground-service');
  }
}
