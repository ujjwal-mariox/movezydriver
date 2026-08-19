import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import 'package:movezy_driver_app/ApiUrls/api_urls.dart';
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
          .build(),
    );

    // The backend event is `booking:request` (dispatch service).
    _socket!.on('booking:request', (payload) {
      _notifyRefresh();
      showIncomingBookingAlert(payload);
    });
    // Kept for backward/admin compatibility; harmless if never fired.
    _socket!.on('booking:new', (_) => _notifyRefresh());
    _socket!.on('booking:closed', (_) {
      _notifyRefresh();
      // Another driver took it — a still-open alert now offers a dead job.
      dismissAlert();
    });
    _socket!.on('booking:cancelled', (_) => _notifyRefresh());
    _socket!.on('booking:status', (_) => _notifyRefresh());
  }

  /// Called on logout so the next driver does not inherit this session.
  void disconnect() {
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
