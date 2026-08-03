import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:movezy_driver_app/ApiUrls/api_urls.dart';
import 'package:movezy_driver_app/Utils/PrefsManager/prefs_manager.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

/// Singleton service that tracks driver location and emits it via Socket.io
/// while the driver is online.
///
/// Two cadences: a slow idle ping (enough to stay in the dispatch geo-index)
/// and a fast one during an active trip, because the customer's tracking map
/// renders these pings — at the idle rate the "live" marker jumped once a
/// minute, which reads as broken.
class LocationTrackingService {
  LocationTrackingService._();
  static final LocationTrackingService instance = LocationTrackingService._();

  static const Duration _idleInterval = Duration(seconds: 60);
  static const Duration _tripInterval = Duration(seconds: 10);

  IO.Socket? _socket;
  Timer? _timer;
  bool _isTracking = false;
  bool _tripActive = false;

  bool get isTracking => _isTracking;

  /// Switch cadence when a trip starts/ends. Safe to call repeatedly.
  void setTripActive(bool active) {
    if (_tripActive == active) return;
    _tripActive = active;
    if (_isTracking) {
      _restartTimer();
      debugPrint(
        'Location cadence → ${active ? "${_tripInterval.inSeconds}s (trip)" : "${_idleInterval.inSeconds}s (idle)"}',
      );
    }
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      _tripActive ? _tripInterval : _idleInterval,
      (_) => _sendCurrentLocation(),
    );
  }

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

    // Send location immediately, then on the cadence for the current mode.
    await _sendCurrentLocation();
    _restartTimer();

    debugPrint(
      'Location tracking started (${_tripActive ? _tripInterval.inSeconds : _idleInterval.inSeconds}s interval)',
    );
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
          // See ChatService.connect(): without forceNew this reuses another
          // service's already-connected socket and onConnect never fires, so
          // the driver:status announce below would be silently skipped.
          .enableForceNew()
          .enableAutoConnect()
          .enableReconnection()
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('Location socket connected');
      _announceOnline();
    });

    _socket!.onDisconnect((_) {
      debugPrint('Location socket disconnected');
    });

    _socket!.onConnectError((err) {
      debugPrint('Location socket error: $err');
    });

    // 'connect' is not replayed for listeners added after connection.
    if (_socket!.connected) _announceOnline();
  }

  /// Tell the backend this driver is online so it joins the drivers:online room.
  void _announceOnline() {
    _socket!.emit('driver:status', {'isOnline': true});
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
