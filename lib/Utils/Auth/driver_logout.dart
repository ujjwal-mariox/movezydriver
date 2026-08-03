import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:movezy_driver_app/ApiUrls/api_urls.dart';
import 'package:movezy_driver_app/Utils/LocationService/location_tracking_service.dart';
import 'package:movezy_driver_app/Utils/PrefsManager/prefs_manager.dart';

/// The single logout routine for the driver app.
///
/// Logging out used to only flip a local flag, which left three things running:
///  - the auth token stayed on the device (still a valid bearer token),
///  - the server never learned the driver went offline, so `isOnline` stayed
///    true and dispatch kept sending them bookings,
///  - the location service is a singleton, not tied to any widget, so its GPS
///    timer + socket kept streaming until the app was killed.
///
/// Order matters: tell the server while the token is still valid, THEN clear
/// local state.
Future<void> performDriverLogout() async {
  // 1. Stop GPS/socket streaming first — it must not outlive the session.
  try {
    LocationTrackingService.instance.stopTracking();
  } catch (e) {
    debugPrint('logout: stopTracking failed: $e');
  }

  // 2. Tell the backend to mark us offline, while the token still works.
  //    Best-effort: a network failure must not trap the driver in the app.
  try {
    await http
        .post(
          Uri.parse(ApiUrls.driverLogoutUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${Prefs.accessToken}',
          },
          body: jsonEncode({}),
        )
        .timeout(const Duration(seconds: 8));
  } catch (e) {
    debugPrint('logout: server logout failed (continuing): $e');
  }

  // 3. Clear local session — including the token, which was previously left behind.
  Prefs.setBool('check_log_in', false);
  Prefs.setString('mobile_number', '');
  Prefs.setString('access_token', '');
  Prefs.setString('onboarding_step', '');
  await Prefs.load();
  Prefs.loadData();
}
