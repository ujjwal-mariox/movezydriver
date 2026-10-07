import 'dart:convert';
import 'package:movezy_driver_app/CommonWidgets/trip_support_sheet.dart';
import 'dart:async';
import 'package:movezy_driver_app/Screens/BookingsDetailsScreen/pickup_trip_sheet.dart';
import 'package:movezy_driver_app/Services/masked_call_service.dart';
import 'package:http/http.dart' as http;
import 'package:movezy_driver_app/ApiUrls/api_urls.dart';
import 'package:movezy_driver_app/AppNavigation/app_navigation.dart';
import 'package:movezy_driver_app/Screens/TechnicianDashboard/technician_dashboard.dart';
import 'package:movezy_driver_app/Utils/LocationService/location_tracking_service.dart';
import 'package:movezy_driver_app/Utils/PrefsManager/prefs_manager.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:movezy_driver_app/CommonWidgets/network_indicator.dart';
import 'package:movezy_driver_app/CommonWidgets/panic_button.dart';
import 'package:movezy_driver_app/Screens/HelpSupportScreen/help_support_screen.dart';
import 'package:movezy_driver_app/Screens/VerifyRideScreen/verify_ride_screen.dart';
import 'package:movezy_driver_app/Screens/ChatScreen/chat_screen.dart';
import 'package:movezy_driver_app/Screens/TechnicianDashboard/dashboard_api_service.dart';
import 'package:movezy_driver_app/Screens/TechnicianDashboard/Model/driver_dashboard_response.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:movezy_driver_app/Services/routing_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

class BookingDetailPage extends StatefulWidget {
  final DashboardBooking booking;
  const BookingDetailPage({super.key, required this.booking});

  @override
  State<BookingDetailPage> createState() => _BookingDetailPageState();
}

class _BookingDetailPageState extends State<BookingDetailPage> {
  final DashboardApiService _apiService = DashboardApiService();
  bool _isArriving = false;
  IO.Socket? _socket;
  final MapController _mapController = MapController();
  Timer? _mapFitTimer;
  Size _mapSize = Size.zero;
  double _sheetExtent = .42;

  /// Set just before handing over to the OTP screen. When this page is
  /// disposed WITHOUT having advanced (back-press, cancel, customer cancel),
  /// the trip-rate location cadence must be switched off again — otherwise the
  /// fast pings ran until the driver's next completed trip or logout.
  bool _advancedToTrip = false;

  DashboardBooking get booking => widget.booking;

  @override
  void initState() {
    super.initState();
    _loadRoadRoute();
    _listenForCancellation();
    // Ping location faster while on a trip — the customer's tracking map
    // renders these, and the idle cadence made the marker crawl.
    LocationTrackingService.instance.setTripActive(true);
  }

  @override
  void dispose() {
    _mapFitTimer?.cancel();
    _mapController.dispose();
    _socket?.dispose();
    _socket = null;
    // Leaving without moving on to the OTP screen means no trip is underway.
    if (!_advancedToTrip) {
      LocationTrackingService.instance.setTripActive(false);
    }
    super.dispose();
  }

  /// The customer can cancel right up until the trip starts. Without this the
  /// driver kept driving to a dead pickup and only found out when their next
  /// action failed with a generic error.
  void _listenForCancellation() {
    _socket = IO.io(
      ApiUrls.socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setAuth({'token': Prefs.accessToken})
          // Own connection — see ChatService.connect(): without forceNew this
          // reuses a cached socket and dispose() would kill other services.
          .enableForceNew()
          .enableAutoConnect()
          .enableReconnection()
          .build(),
    );

    _socket!.on('booking:cancelled', (data) {
      final cancelledId =
          (data is Map ? (data['bookingId'] ?? data['_id']) : null)?.toString();
      // Only react to THIS booking; the driver may have others queued.
      if (cancelledId != null && cancelledId != booking.id) return;
      if (!mounted) return;

      Fluttertoast.showToast(msg: 'This booking was cancelled by the customer');
      replaceRoute(context, const TechnicianDashboard());
    });
  }

  LatLng get pickupLatLng => LatLng(booking.pickup.lat, booking.pickup.lng);

  /// Road geometry pickup → drop; empty until fetched (straight line meanwhile).
  List<LatLng> _roadRoute = const [];

  Future<void> _loadRoadRoute() async {
    if (!_hasValidCoords) return;
    final points = await RoutingService.route(pickupLatLng, dropLatLng);
    if (mounted && points.length > 2) {
      setState(() => _roadRoute = points);
      _scheduleMapFit();
    }
  }

  LatLng get dropLatLng => LatLng(booking.drop.lat, booking.drop.lng);

  bool get _hasValidCoords => [booking.pickup, booking.drop].every(
    (point) =>
        point.lat.isFinite &&
        point.lng.isFinite &&
        point.lat.abs() <= 90 &&
        point.lng.abs() <= 180 &&
        !(point.lat == 0 && point.lng == 0),
  );

  void _scheduleMapFit() {
    _mapFitTimer?.cancel();
    _mapFitTimer = Timer(const Duration(milliseconds: 180), () {
      if (!mounted || !_hasValidCoords || _mapSize.isEmpty) return;
      final topInset = MediaQuery.paddingOf(context).top;
      final sheetHeight = (_mapSize.height - topInset) * _sheetExtent;
      final exposed = _mapSize.height - sheetHeight;
      final topPadding = (topInset + 84).clamp(
        12.0,
        (exposed - 44).clamp(12.0, double.infinity),
      );
      try {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: _mapBounds,
            padding: EdgeInsets.fromLTRB(28, topPadding, 28, sheetHeight + 12),
          ),
        );
      } catch (_) {
        /* Map may not be attached yet; onMapReady retries. */
      }
    });
  }

  LatLngBounds get _mapBounds {
    final minLat = booking.pickup.lat < booking.drop.lat
        ? booking.pickup.lat
        : booking.drop.lat;
    final maxLat = booking.pickup.lat > booking.drop.lat
        ? booking.pickup.lat
        : booking.drop.lat;
    final minLng = booking.pickup.lng < booking.drop.lng
        ? booking.pickup.lng
        : booking.drop.lng;
    final maxLng = booking.pickup.lng > booking.drop.lng
        ? booking.pickup.lng
        : booking.drop.lng;
    return LatLngBounds(
      LatLng(minLat - 0.01, minLng - 0.01),
      LatLng(maxLat + 0.01, maxLng + 0.01),
    );
  }

  /// Raise a real support ticket for this booking (the button was a
  /// non-interactive Container before — it did nothing).
  /// Help sheet: call customer care, chat with support, or raise a ticket
  /// with a chosen reason (the old button filed a blank ticket silently).
  Future<void> _raiseTicket() =>
      showTripSupportSheet(context, bookingId: booking.id, screen: 'booking');

  /// Cancel this booking (customer unreachable, wrong address, etc.). Confirmed
  /// first — it hands the job back to the pool and ends this driver's trip.
  Future<void> _cancelBooking() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Cancel this booking?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "The customer will be told you cancelled and we'll look for another driver. Only do this if you can't complete the pickup.",
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'Reason (e.g. customer unreachable)',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Keep booking'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text(
                'Cancel booking',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
    if (reason == null) return;

    final resp = await _apiService.cancelBooking(booking.id, reason: reason);
    if (!mounted) return;
    final ok = resp != null && (resp['code'] == 1 || resp['code'] == 200);
    Fluttertoast.showToast(
      msg: ok
          ? 'Booking cancelled'
          : (resp?['message']?.toString() ?? 'Could not cancel booking'),
    );
    if (ok) replaceRoute(context, const TechnicianDashboard());
  }

  /// Mandatory-instruction gate: before the first trip action, fetch the
  /// active MANDATORY instructions and require a tap-through once per trip.
  /// The acknowledgment is persisted server-side, so the admin's per-
  /// instruction usage stats read real data. Fail-open on network error —
  /// a driver standing at the pickup must not be blocked from working by a
  /// gate the server can't serve.
  Future<bool> _ensureInstructionsAcknowledged() async {
    try {
      final res = await http
          .get(
            Uri.parse(
              '${ApiUrls.baseUrlApi}/driver/app/bookings/${booking.id}/instruction-gate',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${Prefs.accessToken}',
            },
          )
          .timeout(const Duration(seconds: 8));
      final body = jsonDecode(res.body);
      final data = body['data'] ?? {};
      final List required = data['required'] ?? [];
      if (data['acknowledged'] == true || required.isEmpty) return true;
      if (!mounted) return true;

      final checked = <String>{};
      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setSheet) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Before you start',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Tap each point to confirm.',
                  style: TextStyle(fontSize: 12.5, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                ...required.map((ins) {
                  final id = (ins['_id'] ?? '').toString();
                  final done = checked.contains(id);
                  return InkWell(
                    onTap: () => setSheet(() {
                      if (done) {
                        checked.remove(id);
                      } else {
                        checked.add(id);
                      }
                    }),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        children: [
                          Icon(
                            done
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            size: 20,
                            color: done
                                ? const Color(0xFF22C55E)
                                : Colors.grey.shade400,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            (ins['icon'] ?? '').toString(),
                            style: const TextStyle(fontSize: 15),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              (ins['text'] ?? '').toString(),
                              style: const TextStyle(
                                fontSize: 13.5,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: checked.length == required.length
                          ? const Color(0xFF22C55E)
                          : Colors.grey.shade300,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: checked.length == required.length
                        ? () => Navigator.pop(ctx, true)
                        : null,
                    child: Text(
                      checked.length == required.length
                          ? 'Confirm & continue'
                          : 'Confirm all points (${checked.length}/${required.length})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (confirmed != true) return false;

      await http
          .post(
            Uri.parse(
              '${ApiUrls.baseUrlApi}/driver/app/bookings/${booking.id}/acknowledge-instructions',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${Prefs.accessToken}',
            },
            body: jsonEncode({'instructionIds': checked.toList()}),
          )
          .timeout(const Duration(seconds: 8));
      return true;
    } catch (_) {
      // Gate unreachable — fail open, never trap a driver at the kerb.
      return true;
    }
  }

  Future<void> _markArrived() async {
    if (!await _ensureInstructionsAcknowledged()) return;
    setState(() => _isArriving = true);
    final resp = await _apiService.arrivedAtPickup(booking.id);
    if (!mounted) return;
    setState(() => _isArriving = false);

    if (resp != null && (resp['code'] == 1 || resp['code'] == 200)) {
      Fluttertoast.showToast(msg: 'marked_arrived'.tr);
      // The trip carries on past this page — keep the fast location cadence.
      _advancedToTrip = true;
      // Replace, not push: arrival is confirmed server-side, so backing out of
      // the OTP screen onto a stale "Mark Arrived" page was a dead end.
      replaceRoute(
        context,
        VerifyRideScreen(
          bookingId: booking.id,
          bookingNumber: booking.bookingNumber,
          earnings:
              (booking.estimatedEarnings > 0
                      ? booking.estimatedEarnings
                      : booking.estimatedFare)
                  .toStringAsFixed(0),
          earningsIsGross: booking.estimatedEarnings <= 0,
          scheduledAt: booking.scheduledAt,
          createdAt: booking.createdAt,
        ),
      );
    } else {
      Fluttertoast.showToast(
        msg: resp?['message']?.toString() ?? "Failed to mark arrived",
      );
    }
  }

  Future<void> _openDirections() async {
    final lat = booking.pickup.lat;
    final lng = booking.pickup.lng;
    final uri = Uri.parse(
      "https://www.google.com/maps/dir/?api=1&destination=$lat,$lng",
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Server-bridged: the customer's number never reaches this app; both
  /// sides only see the Movezy number. A missing provider leaves chat available.
  Future<void> _callCustomer() =>
      MaskedCallService.callCustomer(context, booking.id);

  /// Scheduled pickup time where there is one, else when the job was raised -
  /// the design's "Start In" row. The backend can send the literal string
  /// "null", which must not be shown as a time.
  String _startTime() {
    for (final raw in [
      booking.scheduledAt,
      booking.assignedAt,
      booking.createdAt,
    ]) {
      if (raw.isEmpty || raw == 'null') continue;
      final dt = DateTime.tryParse(raw);
      if (dt == null) continue;
      return DateFormat('hh:mm a').format(dt.toLocal());
    }
    return '--';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (_mapSize != size) {
          _mapSize = size;
          _scheduleMapFit();
        }
        return Stack(
          children: [
            Positioned.fill(
              child: _hasValidCoords
                  ? FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCameraFit: CameraFit.bounds(
                          bounds: _mapBounds,
                          padding: const EdgeInsets.all(60),
                        ),
                        onMapReady: _scheduleMapFit,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.movezy.driver',
                        ),
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: _roadRoute.isNotEmpty
                                  ? _roadRoute
                                  : [pickupLatLng, dropLatLng],
                              color: AppColors.appColor,
                              strokeWidth: 4,
                            ),
                          ],
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: pickupLatLng,
                              width: 40,
                              height: 40,
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.green,
                                size: 32,
                              ),
                            ),
                            Marker(
                              point: dropLatLng,
                              width: 40,
                              height: 40,
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.red,
                                size: 32,
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Container(
                      color: Colors.grey.shade200,
                      child: Center(child: Text('map_not_available'.tr)),
                    ),
            ),
            Positioned.fill(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Material(
                          color: Colors.white,
                          elevation: 3,
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Row(
                              children: [
                                IconButton(
                                  tooltip: 'Back',
                                  onPressed: () => Navigator.pop(context),
                                  icon: Icon(
                                    Icons.arrow_back,
                                    color: AppColors.appColor,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'on_route'.tr,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Trip support',
                                  onPressed: _raiseTicket,
                                  icon: Icon(
                                    Icons.help_outline,
                                    color: AppColors.appColor,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: PanicButton(bookingId: booking.id),
                                ),
                              ],
                            ),
                          ),
                        ),
                        MediaQuery.removePadding(
                          context: context,
                          removeTop: true,
                          child: const NetworkIndicator(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              top: MediaQuery.paddingOf(context).top,
              child: PickupTripSheet(
                booking: booking,
                startTime: _startTime(),
                isArriving: _isArriving,
                onCall: _callCustomer,
                onChat: () => pushTo(
                  context,
                  ChatScreen(
                    bookingId: booking.id,
                    customerName: booking.customerName,
                  ),
                ),
                onDirections: _openDirections,
                onHelp: () => pushTo(context, const HelpSupportScreen()),
                onTicket: _raiseTicket,
                onCancel: _cancelBooking,
                onArrived: _markArrived,
                onExtentChanged: (extent) {
                  _sheetExtent = extent;
                  _scheduleMapFit();
                },
              ),
            ),
          ],
        );
      },
    ),
  );
}
