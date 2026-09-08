import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import 'package:movezy_driver_app/ApiUrls/api_urls.dart';
import 'package:movezy_driver_app/Screens/ChatScreen/chat_screen.dart';
import 'package:movezy_driver_app/Services/app_lifecycle_service.dart';
import 'package:movezy_driver_app/Services/booking_ring_service.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';
import 'package:movezy_driver_app/Utils/PrefsManager/prefs_manager.dart';

/// App-lifetime listener for incoming booking offers.
///
/// This used to live inside `_TechnicianDashboardState`, so its `dispose()`
/// tore the socket down: any flow that replaced the dashboard out of the stack
/// (`replaceRoute` = pushAndRemoveUntil with `(route) => false`) permanently
/// killed the only listener, and the driver stopped being told about new jobs
/// until they restarted the app. The socket now belongs to the app, not to a
/// screen, and the dialog is presented through Get's global navigator so it
/// appears over whatever route is on top.
///
/// Scope note: this covers the app being OPEN (any screen, foreground). A
/// backgrounded or killed app needs a push notification to wake it — that is a
/// different transport, not something a socket can do.
class BookingAlertService {
  BookingAlertService._();
  static final BookingAlertService instance = BookingAlertService._();

  IO.Socket? _socket;
  bool _alertShowing = false;

  /// The offer currently ringing, and the timer that silences it when the
  /// server's window closes (or after 30 s, whichever first).
  String? _ringingBookingId;
  Timer? _ringTimer;

  /// Screens that want to react to booking events register here. The dashboard
  /// uses this to refresh its pending list; it no longer owns the connection.
  final List<VoidCallback> _refreshListeners = [];

  /// Set by the dashboard so "View Booking" can open the offer using the
  /// dashboard's own data. Null when no dashboard is mounted — the alert then
  /// just returns to the root route, which shows the pending list.
  Future<void> Function(String bookingId)? openBookingHandler;

  void addRefreshListener(VoidCallback cb) {
    if (!_refreshListeners.contains(cb)) _refreshListeners.add(cb);
  }

  void removeRefreshListener(VoidCallback cb) => _refreshListeners.remove(cb);

  void _notifyRefresh() {
    for (final cb in List<VoidCallback>.from(_refreshListeners)) {
      try {
        cb();
      } catch (e) {
        debugPrint('booking refresh listener failed: $e');
      }
    }
  }

  /// Idempotent — safe to call on every login and every dashboard build.
  void connect() {
    if (_socket != null && _socket!.connected) return;
    if (Prefs.accessToken.isEmpty) return;

    _socket?.dispose();
    _socket = IO.io(
      ApiUrls.socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setAuth({'token': Prefs.accessToken})
          // Own connection, so another service's dispose() cannot tear down
          // these listeners. See ChatService.connect().
          .enableForceNew()
          .enableAutoConnect()
          .enableReconnection()
          // Keep trying for as long as the app lives; the OS drops sockets on
          // every lock/unlock and the driver must not have to notice.
          .setReconnectionAttempts(1000000)
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(15000)
          .build(),
    );

    _socket!.onConnect((_) => debugPrint('Booking alert socket connected'));
    _socket!.onDisconnect((_) => debugPrint('Booking alert socket disconnected'));

    // The backend event is `booking:request` (dispatch service). Offers now
    // go to ONE driver at a time, so a missed ring means the job moves on.
    _socket!.on('booking:request', (payload) {
      _notifyRefresh();
      _startRinging(payload);
      showIncomingBookingAlert(payload);
    });
    // Kept for backward/admin compatibility; harmless if never fired.
    _socket!.on('booking:new', (_) => _notifyRefresh());
    _socket!.on('booking:closed', (payload) {
      _notifyRefresh();
      final id = _bookingIdOf(payload);
      _stopRingingFor(id);
      // Another driver took it, or the window passed — a still-open alert
      // now offers a dead job.
      dismissAlert();
      final reason = _field(payload, 'reason');
      if (reason == 'EXPIRED') {
        Get.snackbar('Request timed out', 'The booking was offered to the next driver.',
            snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 3));
      }
    });
    _socket!.on('booking:cancelled', (payload) {
      _notifyRefresh();
      _stopRingingFor(_bookingIdOf(payload));
      dismissAlert();
    });
    _socket!.on('booking:status', (_) => _notifyRefresh());

    // A customer message while the chat screen is closed: badge the driver
    // in-app, or notify when the app is in the background.
    _socket!.on('chat:notify', (payload) {
      final id = _bookingIdOf(payload);
      final preview = _field(payload, 'preview');
      if (id.isEmpty) return;
      if (AppLifecycleService.instance.isForeground) {
        Get.snackbar(
          'Message from customer',
          preview.isEmpty ? 'Tap to open the chat' : preview,
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 4),
          onTap: (_) => _openChat(id),
          mainButton: TextButton(onPressed: () => _openChat(id), child: const Text('Open')),
        );
      } else {
        BookingRingService.instance.showChatNotification(
          bookingId: id,
          preview: preview.isEmpty ? 'Tap to open the chat' : preview,
        );
      }
    });
  }

  static String _bookingIdOf(dynamic payload) => _field(payload, 'bookingId');

  static String _field(dynamic payload, String key) {
    try {
      final v = (payload as Map)[key];
      return v?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

  // ── Ring ──

  void _startRinging(dynamic payload) {
    final id = _bookingIdOf(payload);
    // A fresh offer always restarts the ring.
    _ringTimer?.cancel();
    _ringingBookingId = id;

    int expiresAt = 0;
    try {
      expiresAt = ((payload as Map)['expiresAt'] as num?)?.toInt() ?? 0;
    } catch (_) {}
    final untilExpiry = expiresAt > 0
        ? Duration(milliseconds: expiresAt - DateTime.now().millisecondsSinceEpoch)
        : const Duration(seconds: 30);
    final window = untilExpiry.inSeconds <= 0
        ? const Duration(seconds: 5)
        : (untilExpiry > const Duration(seconds: 30) ? const Duration(seconds: 30) : untilExpiry);

    BookingRingService.instance.startRing();
    _vibrate();
    if (!AppLifecycleService.instance.isForeground) {
      double fare = 0;
      try {
        fare = ((payload as Map)['estimatedFare'] as num?)?.toDouble() ?? 0;
      } catch (_) {}
      final pickup = _field((payload as Map)['pickup'], 'address');
      BookingRingService.instance.showBookingNotification(bookingId: id, pickup: pickup, fare: fare);
    }
    _ringTimer = Timer(window, () => _stopRingingFor(id));
  }

  Future<void> _vibrate() async {
    for (int i = 0; i < 3; i++) {
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 220));
    }
  }

  void _stopRingingFor(String bookingId) {
    if (bookingId.isNotEmpty && _ringingBookingId != null && _ringingBookingId != bookingId) return;
    stopRinging();
  }

  /// Silence the bell — called when the driver answers the offer (accept or
  /// skip), when the offer closes, or when the window passes.
  void stopRinging() {
    _ringTimer?.cancel();
    _ringTimer = null;
    final id = _ringingBookingId;
    _ringingBookingId = null;
    BookingRingService.instance.stopRing();
    if (id != null && id.isNotEmpty) BookingRingService.instance.cancelBookingNotification(id);
  }

  /// Notification taps: "booking:<id>" opens the offer, "chat:<id>" the chat.
  void handleNotificationTap(String payload) {
    if (payload.startsWith('booking:')) {
      _openBooking(payload.substring('booking:'.length));
    } else if (payload.startsWith('chat:')) {
      _openChat(payload.substring('chat:'.length));
    }
  }

  void _openChat(String bookingId) {
    if (bookingId.isEmpty) return;
    if (Get.isSnackbarOpen) Get.closeCurrentSnackbar();
    Get.to(() => ChatScreen(bookingId: bookingId, customerName: 'Customer'));
  }

  /// Called on logout so the next driver does not inherit this session.
  void disconnect() {
    stopRinging();
    dismissAlert();
    _refreshListeners.clear();
    openBookingHandler = null;
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  void dismissAlert() {
    if (_alertShowing && Get.isDialogOpen == true) Get.back();
    _alertShowing = false;
  }

  void showIncomingBookingAlert(dynamic payload) {
    if (_alertShowing) return;

    String pickupAddr = '';
    String dropAddr = '';
    String vehicle = '';
    double fare = 0;
    String bookingId = '';
    try {
      final map = Map<String, dynamic>.from(payload as Map);
      bookingId = map['bookingId']?.toString() ?? '';
      pickupAddr = (map['pickup']?['address'] ?? '').toString();
      dropAddr = (map['drop']?['address'] ?? '').toString();
      vehicle = (map['vehicleType'] ?? '').toString();
      fare = (map['estimatedFare'] as num?)?.toDouble() ?? 0;
    } catch (_) {
      // Unparseable payload — still worth announcing; the driver can open the
      // pending list from the dashboard.
    }

    _alertShowing = true;
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.appColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.notifications_active,
                        color: AppColors.appColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'new_booking'.tr,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (fare > 0)
                    Text(
                      '₹${fare.toStringAsFixed(0)}',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.appColor),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              if (pickupAddr.isNotEmpty) _addressRow(true, pickupAddr),
              if (dropAddr.isNotEmpty) ...[
                const SizedBox(height: 8),
                _addressRow(false, dropAddr),
              ],
              if (vehicle.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(vehicle,
                    style:
                        TextStyle(fontSize: 12.5, color: HexColor('#6B7280'))),
              ],
              const SizedBox(height: 18),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.appColor,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: () => _openBooking(bookingId),
                child: const Text('View Booking',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
              ),
              TextButton(
                onPressed: dismissAlert,
                child:
                    Text('Dismiss', style: TextStyle(color: HexColor('#6B7280'))),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    ).then((_) => _alertShowing = false);
  }

  Widget _addressRow(bool isPickup, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            isPickup ? Icons.circle : Icons.location_on,
            size: 14,
            color: isPickup ? const Color(0xFF25AA59) : const Color(0xFFE23B32),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, height: 1.35)),
        ),
      ],
    );
  }

  Future<void> _openBooking(String bookingId) async {
    stopRinging();
    dismissAlert();
    // Back to the root route first so the pending list behind any pushed
    // screen is the fresh one.
    Get.until((route) => route.isFirst);
    final handler = openBookingHandler;
    if (handler != null) {
      await handler(bookingId);
    }
    // No dashboard mounted: returning to root already shows the pending list,
    // so the driver can still pick the job up from there.
  }
}
