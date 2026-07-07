import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:movezy_driver_app/ApiUrls/api_urls.dart';
import 'package:movezy_driver_app/Utils/PrefsManager/prefs_manager.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

/// Singleton service that tracks driver location every 60 seconds
/// and emits it via Socket.io when the driver is online.
class LocationTrackingService {
  LocationTrackingService._();
  static final LocationTrackingService instance = LocationTrackingService._();

  IO.Socket? _socket;
  Timer? _timer;
  bool _isTracking = false;

  bool get isTracking => _isTracking;

  /// Start tracking — call when driver goes ONLINE
  Future<void> startTracking() async {
    if (_isTracking) return;

    // Check location permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      debugPrint('Location permission denied — cannot track');
      return;
    }

    // Connect socket if not connected
    _connectSocket();

    _isTracking = true;

    // Send location immediately, then every 60 seconds
    await _sendCurrentLocation();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      _sendCurrentLocation();
    });

    debugPrint('Location tracking started (60s interval)');
  }

  /// Stop tracking — call when driver goes OFFLINE
  void stopTracking() {
    _isTracking = false;
    _timer?.cancel();
    _timer = null;

    // Notify backend that driver is offline
    _socket?.emit('driver:status', {'isOnline': false});
    _disconnectSocket();

    debugPrint('Location tracking stopped');
  }

  /// Send current GPS location to backend via socket
  Future<void> _sendCurrentLocation() async {
    if (!_isTracking || _socket == null) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      _socket!.emit('driver:location:update', {
        'lat': position.latitude,
        'lng': position.longitude,
        'heading': position.heading,
        'speed': position.speed,
      });

      debugPrint(
          'Location sent: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  void _connectSocket() {
    if (_socket?.connected == true) return;

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
      debugPrint('Location socket connected');
      _socket!.emit('driver:status', {'isOnline': true});
    });

    _socket!.onDisconnect((_) {
      debugPrint('Location socket disconnected');
    });

    _socket!.onConnectError((err) {
      debugPrint('Location socket error: $err');
    });
  }

  void _disconnectSocket() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  /// Clean up everything — call on app exit
  void dispose() {
    stopTracking();
  }
}
