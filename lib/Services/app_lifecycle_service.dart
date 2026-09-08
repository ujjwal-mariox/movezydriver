import 'package:flutter/material.dart';
import 'package:movezy_driver_app/Services/background_presence_service.dart';
import 'package:movezy_driver_app/Services/booking_alert_service.dart';
import 'package:movezy_driver_app/Utils/LocationService/location_tracking_service.dart';

/// App-wide foreground/background awareness.
///
/// On resume: reconnect the booking socket if the OS dropped it, send a
/// heartbeat so the server knows the driver is still here, and push a fresh
/// location. Nothing is torn down on pause — the foreground service keeps
/// the driver online while the app is in the background.
class AppLifecycleService with WidgetsBindingObserver {
  AppLifecycleService._();
  static final AppLifecycleService instance = AppLifecycleService._();

  bool _registered = false;
  AppLifecycleState _state = AppLifecycleState.resumed;

  bool get isForeground => _state == AppLifecycleState.resumed;

  void register() {
    if (_registered) return;
    _registered = true;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _state = state;
    if (state == AppLifecycleState.resumed) {
      BookingAlertService.instance.connect();
      LocationTrackingService.instance.onResume();
      BackgroundPresenceService.sendHeartbeat(source: 'app-resume');
    }
  }
}
