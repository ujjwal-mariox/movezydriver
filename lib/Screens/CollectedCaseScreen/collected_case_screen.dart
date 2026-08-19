import 'dart:async';

import 'package:get/get.dart';
import 'package:movezy_driver_app/Utils/OfflineStorage/offline_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:movezy_driver_app/AppNavigation/app_navigation.dart';
import 'package:movezy_driver_app/Screens/CollectedCaseScreen/show_fare_calculation_sheet.dart';
import 'package:movezy_driver_app/Screens/TechnicianDashboard/technician_dashboard.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';
import 'package:movezy_driver_app/Utils/LocationService/location_tracking_service.dart';
import 'package:movezy_driver_app/Screens/TechnicianDashboard/dashboard_api_service.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:movezy_driver_app/Services/routing_service.dart';
import 'package:movezy_driver_app/ApiUrls/api_urls.dart';
import 'package:movezy_driver_app/Utils/PrefsManager/prefs_manager.dart';
import 'package:pinput/pinput.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:url_launcher/url_launcher.dart';

/// The in-trip "Start Trip" screen, per the design: orange header, the drop
/// address in a white chip, the live map, and a bottom card with the distance
/// to the drop, the customer, a call button and COMPLETE.
class AmountToBeCollectedScreen extends StatefulWidget {
  /// Booking being completed. Required so complete/collect-cash hit the right ride.
  final String bookingId;
  final String? amount;
  const AmountToBeCollectedScreen({super.key, required this.bookingId, this.amount});

  @override
  State<AmountToBeCollectedScreen> createState() => _AmountToBeCollectedScreenState();
}

class _AmountToBeCollectedScreenState extends State<AmountToBeCollectedScreen> {
  final DashboardApiService _apiService = DashboardApiService();
  bool _completing = false;

  /// Server message from the last failed completeTrip call. The delivery-OTP
  /// sheet shows this inline — a network blip or state error is not a wrong
  /// code, and saying "code didn't match" for those misled drivers.
  String? _completeError;

  // Real booking details (fare + customer contact), fetched on open.
  Map<String, dynamic>? _booking;

  /// The details fetch failed. Without this the screen rendered misleading
  /// defaults — "Customer", no fare strip, and no delivery-OTP gate, so
  /// COMPLETE failed with a cryptic server error and no way to type the code.
  bool _loadFailed = false;

  // Live position — feeds the distance readout and the arrival state. Never
  // required: with GPS off the screen still works, it just can't show distance.
  StreamSubscription<Position>? _positionSub;
  Position? _position;

  /// Road geometry from the current origin to the drop. Refetched when the
  /// origin changes materially, not on every GPS tick.
  List<LatLng> _roadRoute = const [];
  LatLng? _routedFrom;

  /// Live booking updates for this trip (stops added mid-ride).
  IO.Socket? _socket;

  static const _grayShade1 = Color(0xFF132235);
  static const _grayShade2 = Color(0xFF364B63);

  /// Within this range of the drop the trip counts as arrived and COMPLETE
  /// lights up.
  static const double _arrivedMeters = 300;

  @override
  void initState() {
    super.initState();
    _loadBooking();
    _watchPosition();
    _connectSocket();
    // The driver is on this screen for the whole drive — keep the customer's
    // tracking map updating at the trip cadence, not the idle one.
    LocationTrackingService.instance.setTripActive(true);
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    // Trip is over (completed or backed out) — back to the idle cadence.
    LocationTrackingService.instance.setTripActive(false);
    super.dispose();
  }

  /// Live updates for THIS booking.
  ///
  /// The booking was fetched once in initState, so a stop the customer added
  /// mid-trip never appeared: the driver kept driving to the old drop and
  /// COMPLETE was then refused by the server. The backend already emits
  /// `booking:stop_added` to the assigned driver — listen for it and refetch.
  void _connectSocket() {
    try {
      _socket = IO.io(
        ApiUrls.socketUrl,
        IO.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .setAuth({'token': Prefs.accessToken})
            // Own connection, so another screen's dispose() cannot tear this
            // listener down mid-trip.
            .enableForceNew()
            .enableAutoConnect()
            .enableReconnection()
            .build(),
      );
      _socket!.on('booking:stop_added', (data) {
        if (!mounted) return;
        final id = (data is Map) ? data['bookingId']?.toString() : null;
        // Events for other bookings of this driver must not disturb this trip.
        if (id != null && id != widget.bookingId) return;

        String address = '';
        if (data is Map && data['stop'] is Map) {
          address = (data['stop'] as Map)['address']?.toString() ?? '';
        }
        Fluttertoast.showToast(
          msg: address.isEmpty
              ? 'The customer added a new stop to this trip.'
              : 'New stop added: $address',
        );
        // New leg — re-route from where the driver actually is.
        _routedFrom = null;
        _roadRoute = const [];
        _loadBooking();
      });
    } catch (e) {
      // Live updates are a bonus: a refused COMPLETE also refetches, so the
      // driver still sees the stop. Never break the trip screen over a socket.
      debugPrint('trip socket connect failed: $e');
    }
  }

  /// Turn a server `message` into something a driver can read.
  ///
  /// The backend answers `{ code, message }`, and many of its message keys have
  /// no entry in its messages map — the response then carries the raw key. That
  /// is how "invalid_delivery_otp" and "complete_stops_first" ended up printed
  /// verbatim under the OTP boxes. Known keys become real sentences; anything
  /// else that still looks like a key falls back to the caller's wording rather
  /// than being shown raw.
  static String _serverMessage(String? raw, String fallback) {
    final msg = (raw ?? '').trim();
    if (msg.isEmpty) return fallback;
    switch (msg) {
      case 'invalid_delivery_otp':
        return 'That delivery OTP is incorrect. Ask the receiver to read it out again.';
      case 'complete_stops_first':
        return 'Mark every stop delivered before you complete this trip.';
      case 'complete_previous_stops_first':
        return 'Deliver the earlier stops first — stops are marked in order.';
      case 'stop_already_completed':
        return 'That stop is already marked delivered.';
      case 'invalid_stop':
        return 'That stop is no longer part of this trip.';
      case 'invalid_token':
        return 'Your session has expired. Please sign in again.';
    }
    // snake_case with no spaces is a key, not a sentence.
    final looksLikeKey =
        !msg.contains(' ') && msg.contains('_') && msg == msg.toLowerCase();
    return looksLikeKey ? fallback : msg;
  }

  Future<void> _loadBooking() async {
    final b = await _apiService.getBookingDetails(widget.bookingId);
    if (!mounted) return;
    setState(() {
      _booking = b ?? _booking;
      _loadFailed = b == null && _booking == null;
    });
    _maybeLoadRoute();
  }

  /// Fetch the road route to the drop. Only refetches once the driver has
  /// moved ~300m from the last routed origin, so a live GPS stream doesn't
  /// hammer the router.
  Future<void> _maybeLoadRoute() async {
    final drop = _currentTargetLatLng;
    if (drop == null) return;
    final origin = _position != null
        ? LatLng(_position!.latitude, _position!.longitude)
        : _pickupLatLng;
    if (origin == null) return;

    final last = _routedFrom;
    if (last != null &&
        Geolocator.distanceBetween(
              last.latitude,
              last.longitude,
              origin.latitude,
              origin.longitude,
            ) <
            300) {
      return;
    }

    _routedFrom = origin;
    final points = await RoutingService.route(origin, drop);
    if (mounted && points.length > 2) setState(() => _roadRoute = points);
  }

  Future<void> _watchPosition() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return; // tracking service already asked at go-online; don't nag here
      }
      _positionSub = Geolocator.getPositionStream(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 20),
      ).listen((p) {
        if (!mounted) return;
        setState(() => _position = p);
        _maybeLoadRoute();
      });
    } catch (_) {
      // No GPS → no distance readout; everything else still works.
    }
  }

  // ── Booking-derived getters ──

  LatLng? get _dropLatLng {
    final d = _booking?['drop'];
    if (d is Map && d['lat'] != null && d['lng'] != null) {
      final lat = (d['lat'] as num?)?.toDouble() ?? 0;
      final lng = (d['lng'] as num?)?.toDouble() ?? 0;
      if (lat != 0 && lng != 0) return LatLng(lat, lng);
    }
    return null;
  }

  LatLng? get _pickupLatLng {
    final d = _booking?['pickup'];
    if (d is Map && d['lat'] != null && d['lng'] != null) {
      final lat = (d['lat'] as num?)?.toDouble() ?? 0;
      final lng = (d['lng'] as num?)?.toDouble() ?? 0;
      if (lat != 0 && lng != 0) return LatLng(lat, lng);
    }
    return null;
  }

  String get _dropAddress {
    final d = _booking?['drop'];
    if (d is Map && d['address'] != null) return d['address'].toString();
    return '';
  }

  // ── Multi-stop legs ──
  // The trip visits every stop in order, then the final drop. "Current target"
  // is the first undelivered stop, or the drop once none remain — the map,
  // distance readout, navigation button and primary action all follow it.

  List<Map<String, dynamic>> get _stops {
    final raw = _booking?['stops'];
    if (raw is List) {
      return [
        for (final st in raw)
          if (st is Map) Map<String, dynamic>.from(st),
      ];
    }
    return const [];
  }

  static bool _stopDone(Map<String, dynamic> st) {
    final c = st['completedAt'];
    return c != null && c.toString().isNotEmpty && c.toString() != 'null';
  }

  /// First undelivered stop; -1 when all stops are done (or there are none).
  int get _nextStopIndex {
    final stops = _stops;
    for (var i = 0; i < stops.length; i++) {
      if (!_stopDone(stops[i])) return i;
    }
    return -1;
  }

  bool get _isOnStopLeg => _nextStopIndex >= 0;

  LatLng? _stopLatLng(Map<String, dynamic> st) {
    final lat = (st['lat'] as num?)?.toDouble() ?? 0;
    final lng = (st['lng'] as num?)?.toDouble() ?? 0;
    if (lat != 0 && lng != 0) return LatLng(lat, lng);
    return null;
  }

  LatLng? get _currentTargetLatLng {
    final i = _nextStopIndex;
    if (i >= 0) return _stopLatLng(_stops[i]) ?? _dropLatLng;
    return _dropLatLng;
  }

  String get _currentTargetAddress {
    final i = _nextStopIndex;
    if (i >= 0) {
      final a = _stops[i]['address']?.toString() ?? '';
      if (a.isNotEmpty) return a;
    }
    return _dropAddress;
  }

  /// Straight-line metres from the driver to the CURRENT target (next stop or
  /// final drop); null without GPS fix.
  double? get _distanceToDropM {
    final target = _currentTargetLatLng;
    final pos = _position;
    if (target == null || pos == null) return null;
    return Geolocator.distanceBetween(
        pos.latitude, pos.longitude, target.latitude, target.longitude);
  }

  bool get _arrived => (_distanceToDropM ?? double.infinity) <= _arrivedMeters;

  /// True when the fare was already paid online/by wallet, so the driver must
  /// NOT collect cash. Without this the screen demanded cash on prepaid trips
  /// (a double charge) and the backend flipped paymentStatus to PAID anyway.
  bool get _isPrepaid {
    final method = (_booking?['paymentMethod'] ?? 'CASH').toString().toUpperCase();
    final status = (_booking?['paymentStatus'] ?? '').toString().toUpperCase();
    return method != 'CASH' || status == 'PAID';
  }

  /// Fare added AFTER the card was charged — stops the customer added
  /// mid-trip. The server deliberately does not re-charge the card for it; it
  /// records the difference here and tells the customer the driver collects it
  /// in cash. This screen ignored it, so a prepaid booking said "do not collect
  /// cash" and the top-up was never collected from anyone.
  double get _pendingTopUp {
    final v = _booking?['pendingCashTopUp'];
    final n = (v is num) ? v.toDouble() : double.tryParse('${v ?? ''}');
    return (n == null || n <= 0) ? 0 : n;
  }

  String get _topUpLabel => _pendingTopUp == _pendingTopUp.roundToDouble()
      ? _pendingTopUp.toStringAsFixed(0)
      : _pendingTopUp.toStringAsFixed(2);

  /// Is there cash to take at the door? True for COD, and also for a prepaid
  /// trip that accrued a top-up.
  bool get _owesCash => !_isPrepaid || _pendingTopUp > 0;

  /// The one sentence shown on the money strip.
  String get _moneyStripText {
    if (_pendingTopUp > 0) {
      return _isPrepaid
          ? 'Collect ₹$_topUpLabel in cash (added stops)'
          : 'Collect ₹$_collectAmount in cash (incl. ₹$_topUpLabel for added stops)';
    }
    if (_isPrepaid) return 'Paid online — do not collect cash';
    return _collectAmount.isNotEmpty
        ? 'Collect ₹$_collectAmount in cash'
        : 'Collect cash on delivery';
  }

  /// Amount to collect: prefer the passed amount, else the booking's real fare.
  String get _collectAmount {
    if (widget.amount != null && widget.amount!.isNotEmpty) return widget.amount!;
    final fare = _booking?['finalFare'] ?? _booking?['fare'];
    if (fare != null) {
      final n = (fare is num) ? fare : num.tryParse(fare.toString());
      if (n != null) return n.toStringAsFixed(n == n.roundToDouble() ? 0 : 2);
    }
    return '';
  }

  /// Customer name + phone from the populated booking.userId.
  String get _customerName {
    final u = _booking?['userId'];
    if (u is Map && u['fullName'] != null) return u['fullName'].toString();
    return 'Customer';
  }

  String get _customerPhone {
    final u = _booking?['userId'];
    if (u is Map && u['mobileNumber'] != null) return u['mobileNumber'].toString();
    return '';
  }

  // ── Actions ──

  Future<void> _callCustomer() async {
    if (_customerPhone.isEmpty) {
      Fluttertoast.showToast(msg: 'Customer number unavailable');
      return;
    }
    final uri = Uri.parse('tel:$_customerPhone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  /// Open turn-by-turn navigation to the current target (next stop or drop).
  Future<void> _openDropDirections() async {
    final drop = _currentTargetLatLng;
    if (drop == null) return;
    final uri = Uri.parse(
        "https://www.google.com/maps/dir/?api=1&destination=${drop.latitude},${drop.longitude}");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Raise a real support ticket for this booking.
  Future<void> _raiseTicket() async {
    final resp = await _apiService.raiseTicket(
      category: 'Order Issue',
      subject: 'Issue with booking ${widget.bookingId}',
      message: 'Driver raised a ticket from the trip screen.',
      bookingId: widget.bookingId,
    );
    if (!mounted) return;
    final ok = resp != null && (resp['code'] == 1 || resp['code'] == 200);
    Fluttertoast.showToast(
      msg: ok ? 'Ticket raised. Support will contact you.' : 'Could not raise ticket. Try again.',
    );
  }

  /// Whether this booking is gated by a delivery OTP. The flag comes from the
  /// details endpoint; the code itself is never sent to the driver.
  bool get _needsDeliveryOtp => _booking?['deliveryOtpRequired'] == true;

  /// COMPLETE tap. When GPS says the driver is still clearly away from the
  /// drop, ask before completing rather than block — GPS can be wrong and a
  /// driver must never be stranded unable to finish a trip. Then, when the
  /// booking carries a delivery OTP, the receiver's code is collected in the
  /// Complete Delivery sheet; legacy bookings complete directly.
  Future<void> _onCompletePressed() async {
    final dist = _distanceToDropM;
    if (dist != null && dist > _arrivedMeters) {
      final km = (dist / 1000).toStringAsFixed(1);
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Complete trip?'),
          content: Text(
              'You appear to be about $km km from the drop location. Complete the trip anyway?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Not yet')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Complete')),
          ],
        ),
      );
      if (go != true) return;
    }

    if (_needsDeliveryOtp) {
      await _showCompleteDeliverySheet();
    } else {
      await _completeAndCollect();
    }
  }

  /// Mark the current stop delivered. Same far-from-target confirm as
  /// COMPLETE — GPS drift must never strand a driver — then the server
  /// records it (in order) and the refreshed booking advances the leg.
  Future<void> _onStopDeliveredPressed() async {
    final idx = _nextStopIndex;
    if (idx < 0) return;

    final dist = _distanceToDropM;
    if (dist != null && dist > _arrivedMeters) {
      final km = (dist / 1000).toStringAsFixed(1);
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Deliver stop ${idx + 1}?'),
          content: Text(
              'You appear to be about $km km from stop ${idx + 1}. Mark it delivered anyway?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Not yet')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delivered')),
          ],
        ),
      );
      if (go != true) return;
    }

    setState(() => _completing = true);
    final resp = await _apiService.completeStop(widget.bookingId, idx);
    if (!mounted) return;

    final ok = resp != null && resp['code'] == 1;
    if (ok) {
      Fluttertoast.showToast(msg: 'Stop ${idx + 1} delivered');
      // New leg: force a fresh route from the current position.
      _routedFrom = null;
      _roadRoute = const [];
      await _loadBooking();
    } else {
      // A refusal means this screen's copy of the stop list is stale (the
      // customer may have added or the server reordered) — resync before
      // telling the driver anything, and show the server's real reason.
      await _loadBooking();
      Fluttertoast.showToast(
        msg: _serverMessage(resp?['message']?.toString(),
            'Could not update the stop. Try again.'),
      );
    }
    if (mounted) setState(() => _completing = false);
  }

  /// The design's Complete Delivery panel: drag handle, "Enter Delivery OTP /
  /// to complete delivery", the grey code boxes, the cash strip, and a verify
  /// bar with the white chevron chip. Wrong codes surface inline and the sheet
  /// stays open; it closes itself only when completion succeeds.
  Future<void> _showCompleteDeliverySheet() async {
    String pin = '';
    String? error;
    bool submitting = false;

    final pinTheme = PinTheme(
      width: 58,
      height: 46,
      textStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: _grayShade1,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(6),
      ),
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) {
          Future<void> submit() async {
            if (submitting) return;
            if (pin.length < 4) {
              setSheet(() => error = 'Enter the 4-digit delivery OTP');
              return;
            }
            setSheet(() {
              submitting = true;
              error = null;
            });
            final ok = await _completeAndCollect(deliveryOtp: pin);
            if (!sheetCtx.mounted) return;
            if (ok) {
              // _completeAndCollect has already replaced the route; nothing to
              // close here — the sheet went down with the screen.
              return;
            }
            // The refusal revealed an undelivered stop (added mid-trip and just
            // refetched). The OTP gate belongs at the FINAL drop, so close it
            // and send the driver back to the trip screen, which now shows the
            // new leg and a "STOP n DELIVERED" action.
            if (_isOnStopLeg) {
              Navigator.pop(sheetCtx);
              Fluttertoast.showToast(
                  msg: _completeError ??
                      'Mark every stop delivered before you complete this trip.');
              return;
            }
            setSheet(() {
              submitting = false;
              // Prefer the server's reason (wrong code, state error, offline)
              // over guessing that the code was wrong.
              error = _completeError ??
                  'That code didn\'t match. Ask the receiver again.';
            });
          }

          return Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                      color: Color(0x59000000),
                      blurRadius: 15,
                      offset: Offset(0, 5)),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 32,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFF94A3B3),
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Enter Delivery OTP',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: _grayShade1),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'to complete delivery',
                        style: TextStyle(fontSize: 15, color: _grayShade1),
                      ),
                      const SizedBox(height: 14),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Enter OTP',
                            style:
                                TextStyle(fontSize: 14, color: Colors.black)),
                      ),
                      const SizedBox(height: 8),
                      Pinput(
                        // 4 digits — the real length of booking.deliveryOtp.
                        length: 4,
                        autofocus: true,
                        defaultPinTheme: pinTheme,
                        focusedPinTheme: pinTheme.copyWith(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: AppColors.appColor, width: 1.4),
                          ),
                        ),
                        onChanged: (v) => setSheet(() {
                          pin = v;
                          error = null;
                        }),
                        onCompleted: (v) => pin = v,
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          error!,
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFE02D3C)),
                        ),
                      ],
                      const SizedBox(height: 14),
                      // The money strip again, at the moment of handover.
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: !_owesCash
                              ? const Color(0xFFE8F5E9)
                              : const Color(0xFFFFF6F0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _moneyStripText,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: !_owesCash
                                ? const Color(0xFF1F8B4C)
                                : AppColors.appColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      InkWell(
                        onTap: submitting ? null : submit,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 48,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppColors.appColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Text(
                                submitting
                                    ? 'Verifying...'
                                    : 'Verify & Complete',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700),
                              ),
                              Positioned(
                                left: 2,
                                top: 2,
                                child: Container(
                                  width: 56,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: submitting
                                      ? Center(
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                                color: AppColors.appColor,
                                                strokeWidth: 2.4),
                                          ),
                                        )
                                      : Icon(
                                          Icons.keyboard_double_arrow_right,
                                          color: AppColors.appColor,
                                          size: 26),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Complete the trip, then mark cash collected. Backend credits coins on
  /// completion. Shows the fare sheet on success. Returns whether completion
  /// went through, so the delivery-OTP sheet can stay open on a wrong code.
  Future<bool> _completeAndCollect({String? deliveryOtp}) async {
    if (_completing) return false;
    setState(() => _completing = true);

    // completeTrip requires the booking to be IN_PROGRESS. If we arrived here
    // with the trip still PICKED (e.g. resumed from the dashboard, or start
    // didn't run), start it first so COMPLETE always works.
    final status = _booking?['status']?.toString();
    if (status == 'PICKED') {
      await _apiService.startTrip(widget.bookingId);
    }

    final complete = await _apiService.completeTrip(widget.bookingId,
        deliveryOtp: deliveryOtp);

    // NETWORK failure vs server refusal, and they must be treated differently:
    // a null response means the request never reached the server (offline,
    // timeout) — the trip is genuinely done in the real world, so save it
    // locally and let OfflineService replay it when the network returns. A
    // non-null refusal (bad OTP, wrong state) must NEVER be stored as
    // completed — replaying a rejection forever can't fix it.
    if (complete == null) {
      final connectivity = await Connectivity().checkConnectivity();
      final offline = connectivity.contains(ConnectivityResult.none);
      if (offline && Get.isRegistered<OfflineService>()) {
        final saved = await Get.find<OfflineService>().storeTripCompletion(
          TripCompletionData(
            tripId: widget.bookingId,
            driverId: Prefs.getString('driverId'),
            completedAt: DateTime.now(),
            fare: (_booking?['finalFare'] as num?)?.toDouble() ?? 0,
            paymentMode: _booking?['paymentMethod']?.toString() ?? '',
            deliveryOtp: deliveryOtp,
            owesCash: _owesCash,
            needsStart: status == 'PICKED',
          ),
        );
        if (!mounted) return saved;
        setState(() => _completing = false);
        if (saved) {
          Fluttertoast.showToast(
              msg:
                  'No internet — trip saved on this phone and will sync automatically.',
              toastLength: Toast.LENGTH_LONG);
          Navigator.pop(context, true);
          return true;
        }
      }
      // Reachable network but the call still failed — transient. Say what is
      // actually happening instead of a generic failure.
      _completeError = 'Network issue detected. Please try again.';
      if (!mounted) return false;
      setState(() => _completing = false);
      if (deliveryOtp == null) Fluttertoast.showToast(msg: _completeError!);
      return false;
    }

    final completeOk = complete['code'] == 1 || complete['code'] == 200;
    if (!completeOk) {
      final raw = complete?['message']?.toString();
      // The server refuses COMPLETE while any intermediate drop is unmarked.
      // That happens when the customer added a stop after this screen loaded
      // the booking, so the new leg isn't on screen at all — refetch, and the
      // primary action becomes "STOP n DELIVERED" instead of a dead COMPLETE.
      if (raw == 'complete_stops_first') {
        await _loadBooking();
      }
      final msg = _serverMessage(raw, 'Could not complete trip. Try again.');
      _completeError = msg;
      if (!mounted) return false;
      setState(() => _completing = false);
      // The OTP-sheet path surfaces the message inline; toasting it there too
      // doubled the feedback with two different texts.
      if (deliveryOtp == null) Fluttertoast.showToast(msg: msg);
      return false;
    }

    // Only collect cash on a genuine COD trip. Prepaid trips are already PAID;
    // calling collectCash would be a double charge.
    if (_owesCash) {
      await _apiService.collectCash(widget.bookingId);
    }

    if (!mounted) return true;
    setState(() => _completing = false);

    Fluttertoast.showToast(
      msg: _owesCash ? 'Trip completed & cash collected' : 'Trip completed',
    );

    // Pass the completed booking so the sheet shows the REAL fare breakdown.
    final bookingData = complete['data'];
    await showFareCalculationSheet(
      context,
      booking: bookingData is Map<String, dynamic> ? bookingData : null,
    );

    // Trip is done — return to the dashboard (clears the trip screens).
    if (!mounted) return true;
    replaceRoute(context, const TechnicianDashboard());
    return true;
  }

  // ── UI ──

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F5FA),
      body: Column(
        children: [
          _header(),
          // Until the booking loads, everything below would be misleading
          // defaults (no OTP gate, "Customer", no fare) — show the real state.
          if (_booking == null)
            Expanded(
              child: _loadFailed
                  ? _loadErrorState()
                  : Center(
                      child:
                          CircularProgressIndicator(color: AppColors.appColor)),
            )
          else ...[
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(child: _map()),
                  if (_dropAddress.isNotEmpty)
                    Positioned(
                      top: 12,
                      left: 16,
                      right: 16,
                      child: _addressChip(),
                    ),
                ],
              ),
            ),
            _bottomCard(),
          ],
        ],
      ),
    );
  }

  /// Shown when the details fetch failed outright — a Retry beats a screen
  /// full of placeholders whose COMPLETE cannot pass the delivery-OTP gate.
  Widget _loadErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_outlined, size: 44, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'Could not load this trip. Check your connection and retry.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: _grayShade2),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() => _loadFailed = false);
                _loadBooking();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.appColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8, bottom: 16),
      color: AppColors.appColor,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Text(
            'Start Trip',
            style: TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
          ),
          Positioned(
            left: 4,
            child: IconButton(
              // Reached via replaceRoute after the OTP gate, this can be the
              // navigator's ONLY route — popping it then left a blank app.
              // Fall back to the dashboard in that case.
              onPressed: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  replaceRoute(context, const TechnicianDashboard());
                }
              },
              icon: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white, size: 20),
            ),
          ),
          // Support lives where the design's filter glyph sits — a dead filter
          // control would be decoration; raising a ticket is real.
          Positioned(
            right: 4,
            child: IconButton(
              onPressed: _raiseTicket,
              icon: const Icon(Icons.support_agent,
                  color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  /// The design's white address chip over the map: orange badge, drop address.
  /// Tapping it opens turn-by-turn navigation.
  Widget _addressChip() {
    return InkWell(
      onTap: _openDropDirections,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.appColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.location_on, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isOnStopLeg)
                    Text(
                      'Stop ${_nextStopIndex + 1} of ${_stops.length}',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.appColor),
                    ),
                  Text(
                    _currentTargetAddress,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        color: _grayShade1),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.directions, color: AppColors.appColor, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _map() {
    final drop = _currentTargetLatLng;
    if (drop == null) {
      return Container(
        color: const Color(0xFFE7EDF4),
        alignment: Alignment.center,
        child: const Text('Map not available',
            style: TextStyle(color: _grayShade2)),
      );
    }

    // Route line: live position → drop when GPS is on; else pickup → drop.
    final origin = _position != null
        ? LatLng(_position!.latitude, _position!.longitude)
        : _pickupLatLng;

    return FlutterMap(
      options: MapOptions(
        initialCameraFit: origin != null
            ? CameraFit.bounds(
                bounds: LatLngBounds.fromPoints([origin, drop]),
                padding: const EdgeInsets.fromLTRB(60, 90, 60, 60),
              )
            : null,
        initialCenter: drop,
        initialZoom: 14,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.movezy.driver',
        ),
        if (origin != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points:
                    _roadRoute.isNotEmpty ? _roadRoute : [origin, drop],
                color: AppColors.appColor,
                strokeWidth: 3,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            if (origin != null)
              Marker(
                point: origin,
                width: 30,
                height: 30,
                child: _blueDot(),
              ),
            Marker(
              point: drop,
              width: 44,
              height: 56,
              child: const Icon(Icons.location_on,
                  color: Color(0xFFE02D3C), size: 44),
            ),
            // Upcoming stops beyond the current one, numbered; the final drop
            // gets a small grey pin while a stop is still the target.
            for (var i = _nextStopIndex + 1;
                _isOnStopLeg && i < _stops.length;
                i++)
              if (_stopLatLng(_stops[i]) != null)
                Marker(
                  point: _stopLatLng(_stops[i])!,
                  width: 26,
                  height: 26,
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.appColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Text('${i + 1}',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                ),
            if (_isOnStopLeg && _dropLatLng != null)
              Marker(
                point: _dropLatLng!,
                width: 30,
                height: 38,
                child: const Icon(Icons.location_on,
                    color: Color(0xFF9AA4B2), size: 30),
              ),
          ],
        ),
      ],
    );
  }

  Widget _blueDot() => Center(
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: const Color(0xFF2F6FED).withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: const Color(0xFF2F6FED),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ),
      );

  Widget _bottomCard() {
    final dist = _distanceToDropM;
    final distLabel =
        dist == null ? null : '${(dist / 1000).toStringAsFixed(1)} km';
    final arrived = _arrived;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: Color(0x26000000), blurRadius: 12, offset: Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  // Customer initial in a circle (no photo in this payload).
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.appColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _customerName.isNotEmpty
                          ? _customerName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.appColor),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Live distance where GPS allows; the design's "2 min"
                        // ETA needs routing data this app doesn't have, so the
                        // readout is distance-only rather than an invented time.
                        Text(
                          distLabel == null
                              ? 'On the way'
                              : (arrived
                                  ? 'Arrived · $distLabel'
                                  : '$distLabel to ${_isOnStopLeg ? 'stop ${_nextStopIndex + 1}' : 'drop'}'),
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _grayShade1),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isOnStopLeg
                              ? (arrived
                                  ? 'Arrived — deliver stop ${_nextStopIndex + 1} of ${_stops.length}'
                                  : 'Stop ${_nextStopIndex + 1} of ${_stops.length} · final drop after')
                              : (arrived
                                  ? 'Arrived — hand over to $_customerName'
                                  : 'Delivering to $_customerName'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12.5, color: _grayShade2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _callCustomer,
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.appColor, width: 1.4),
                      ),
                      child: Icon(Icons.phone,
                          color: AppColors.appColor, size: 19),
                    ),
                  ),
                ],
              ),

              // Money strip — what the driver must (or must not) collect.
              // Kept from the old screen: dropping it to match the mock would
              // hide the one thing that prevents double-charging a prepaid trip.
              if (_booking != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: !_owesCash
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFFFF6F0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _moneyStripText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: !_owesCash
                          ? const Color(0xFF1F8B4C)
                          : AppColors.appColor,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // COMPLETE — grey until arrived (per the design), but always
              // tappable: far taps confirm first instead of blocking, because
              // GPS drift must never strand a driver mid-settlement.
              InkWell(
                onTap: _completing
                    ? null
                    : (_isOnStopLeg ? _onStopDeliveredPressed : _onCompletePressed),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 48,
                  width: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: (arrived || dist == null)
                        ? AppColors.appColor
                        : const Color(0xFFD5DAE3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _completing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.4),
                        )
                      : Text(
                          _isOnStopLeg
                              ? 'STOP ${_nextStopIndex + 1} DELIVERED'
                              : 'COMPLETE',
                          style: TextStyle(
                            color: (arrived || dist == null)
                                ? Colors.white
                                : const Color(0xFF7A8698),
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
