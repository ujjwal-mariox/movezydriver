import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:movezy_driver_app/ApiUrls/api_urls.dart';
import 'package:movezy_driver_app/AppNavigation/app_navigation.dart';
import 'package:movezy_driver_app/CommonWidgets/app_bar.dart';
import 'package:movezy_driver_app/Screens/TechnicianDashboard/technician_dashboard.dart';
import 'package:movezy_driver_app/Utils/LocationService/location_tracking_service.dart';
import 'package:movezy_driver_app/Utils/PrefsManager/prefs_manager.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:movezy_driver_app/CommonWidgets/network_indicator.dart';
import 'package:movezy_driver_app/CommonWidgets/panic_button.dart';
import 'package:movezy_driver_app/CommonWidgets/slider_button_widget.dart';
import 'package:movezy_driver_app/Screens/HelpSupportScreen/help_support_screen.dart';
import 'package:movezy_driver_app/Screens/VerifyRideScreen/verify_ride_screen.dart';
import 'package:movezy_driver_app/Screens/ChatScreen/chat_screen.dart';
import 'package:movezy_driver_app/Screens/TechnicianDashboard/dashboard_api_service.dart';
import 'package:movezy_driver_app/Screens/TechnicianDashboard/Model/driver_dashboard_response.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hexcolor/hexcolor.dart';
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
    final points = await RoutingService.route(pickupLatLng, dropLatLng);
    if (mounted && points.length > 2) setState(() => _roadRoute = points);
  }
  LatLng get dropLatLng => LatLng(booking.drop.lat, booking.drop.lng);

  bool get _hasValidCoords =>
      booking.pickup.lat != 0 && booking.pickup.lng != 0 &&
      booking.drop.lat != 0 && booking.drop.lng != 0;

  LatLngBounds get _mapBounds {
    final minLat = booking.pickup.lat < booking.drop.lat ? booking.pickup.lat : booking.drop.lat;
    final maxLat = booking.pickup.lat > booking.drop.lat ? booking.pickup.lat : booking.drop.lat;
    final minLng = booking.pickup.lng < booking.drop.lng ? booking.pickup.lng : booking.drop.lng;
    final maxLng = booking.pickup.lng > booking.drop.lng ? booking.pickup.lng : booking.drop.lng;
    return LatLngBounds(
      LatLng(minLat - 0.01, minLng - 0.01),
      LatLng(maxLat + 0.01, maxLng + 0.01),
    );
  }

  /// Raise a real support ticket for this booking (the button was a
  /// non-interactive Container before — it did nothing).
  Future<void> _raiseTicket() async {
    final resp = await _apiService.raiseTicket(
      category: 'Order Issue',
      subject: 'Issue with booking ${booking.id}',
      message: 'Driver raised a ticket from the booking screen.',
      bookingId: booking.id,
    );
    if (!mounted) return;
    final ok = resp != null && (resp['code'] == 1 || resp['code'] == 200);
    Fluttertoast.showToast(
      msg: ok ? 'Ticket raised. Support will contact you.' : 'Could not raise ticket. Try again.',
    );
  }

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
              child: const Text('Cancel booking',
                  style: TextStyle(color: Colors.red)),
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
      final res = await http.get(
        Uri.parse(
            '${ApiUrls.baseUrlApi}/driver/app/bookings/${booking.id}/instruction-gate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Prefs.accessToken}',
        },
      ).timeout(const Duration(seconds: 8));
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
                const Text('Before you start',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Tap each point to confirm.',
                    style: TextStyle(fontSize: 12.5, color: Colors.black54)),
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
                            size: 21,
                            color: done
                                ? const Color(0xFF22C55E)
                                : Colors.grey.shade400,
                          ),
                          const SizedBox(width: 10),
                          Text((ins['icon'] ?? '').toString(),
                              style: const TextStyle(fontSize: 15)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text((ins['text'] ?? '').toString(),
                                style: const TextStyle(
                                    fontSize: 13.5, height: 1.35)),
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
                          borderRadius: BorderRadius.circular(12)),
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
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (confirmed != true) return false;

      await http.post(
        Uri.parse(
            '${ApiUrls.baseUrlApi}/driver/app/bookings/${booking.id}/acknowledge-instructions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Prefs.accessToken}',
        },
        body: jsonEncode({'instructionIds': checked.toList()}),
      ).timeout(const Duration(seconds: 8));
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
          earnings: (booking.estimatedEarnings > 0
                            ? booking.estimatedEarnings
                            : booking.estimatedFare)
                        .toStringAsFixed(0),
          earningsIsGross: booking.estimatedEarnings <= 0,
          scheduledAt: booking.scheduledAt,
          createdAt: booking.createdAt,
        ),
      );
    } else {
      Fluttertoast.showToast(msg: resp?['message']?.toString() ?? "Failed to mark arrived");
    }
  }

  Future<void> _openDirections() async {
    final lat = booking.pickup.lat;
    final lng = booking.pickup.lng;
    final uri = Uri.parse("https://www.google.com/maps/dir/?api=1&destination=$lat,$lng");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _callCustomer() async {
    final phone = booking.pickup.contactPhone;
    if (phone.isEmpty) {
      Fluttertoast.showToast(msg: 'no_contact_number'.tr);
      return;
    }
    final uri = Uri.parse("tel:$phone");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  /// Scheduled pickup time where there is one, else when the job was raised -
  /// the design's "Start In" row. The backend can send the literal string
  /// "null", which must not be shown as a time.
  String _startTime() {
    for (final raw in [booking.scheduledAt, booking.assignedAt, booking.createdAt]) {
      if (raw.isEmpty || raw == 'null') continue;
      final dt = DateTime.tryParse(raw);
      if (dt == null) continue;
      return DateFormat('hh:mm a').format(dt.toLocal());
    }
    return '--';
  }

  /// Before the goods are aboard the driver is heading to the pickup;
  /// afterwards, to the drop.
  bool get _headingToPickup =>
      booking.status == 'ASSIGNED' || booking.status == 'DRIVER_ARRIVED';

  @override
  Widget build(BuildContext context) {
    const Color cardBorder = Color(0xFFE6EEF2);
    // serviceType is WITHIN_CITY | OUTSTATION. "One Way" is a PRODUCT-CHOSEN
    // label for WITHIN_CITY, not a field: nothing in the booking model records a
    // one-way/round-trip axis, and the trip-summary screen still calls the same
    // value "Within City". Kept because the design calls for it — if the two
    // names ever need to agree, change the copy, not the mapping.
    String serviceLabel = booking.serviceType == "OUTSTATION" ? "Outstation" : "One Way";

    // What this trip pays the DRIVER (subtotal minus commission, pre-GST) —
    // the same figure the Take Booking screen quoted. estimatedFare is the
    // customer's gross, GST included, and must never wear the earnings label:
    // it overstated the payout by roughly a quarter.
    final bool earningsKnown = booking.estimatedEarnings > 0;
    final double earnings =
        earningsKnown ? booking.estimatedEarnings : booking.estimatedFare;

    return Scaffold(
      backgroundColor: Colors.grey,
      body: Column(
        children: [
          const NetworkIndicator(),
          commonAppBar(
            height: 100,
            context: context,
            child: Container(
              padding: const EdgeInsets.only(top: 50),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.only(left: 16),
                      width: 40, height: 35,
                      alignment: Alignment.center,
                      child: Image.asset("assets/back_arrow.png", color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('on_route'.tr, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  const SizedBox(width: 10),
                ],
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                // Map
                if (_hasValidCoords)
                  FlutterMap(
                    options: MapOptions(
                      initialCameraFit: CameraFit.bounds(
                        bounds: _mapBounds,
                        padding: const EdgeInsets.all(60),
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.movezy.driver',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: pickupLatLng,
                            width: 40, height: 40,
                            child: const Icon(Icons.location_on, color: Colors.green, size: 36),
                          ),
                          Marker(
                            point: dropLatLng,
                            width: 40, height: 40,
                            child: const Icon(Icons.location_on, color: Colors.red, size: 36),
                          ),
                        ],
                      ),
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _roadRoute.isNotEmpty
                                ? _roadRoute
                                : [pickupLatLng, dropLatLng],
                            color: AppColors.appColor,
                            strokeWidth: 3,
                          ),
                        ],
                      ),
                    ],
                  )
                else
                  Container(color: Colors.grey[300], child: Center(child: Text('map_not_available'.tr))),

                // Panic SOS button
                Positioned(
                  top: 16,
                  right: 16,
                  child: PanicButton(bookingId: booking.id),
                ),

                // Bottom panel
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    // Bottom-anchored panel: keep the design's 18/5 padding and
                    // ADD the device's real bottom inset, otherwise the "At
                    // Pickup" slider — the only way off this screen — sits
                    // under the gesture bar / 3-button nav. Padding the panel
                    // also shortens the scroll viewport, so the slider is no
                    // longer trapped under the system UI when the list scrolls.
                    padding: EdgeInsets.fromLTRB(
                        18, 5, 18, 5 + MediaQuery.of(context).padding.bottom),
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
                      color: Colors.white,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 6),
                          // Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(width: MediaQuery.of(context).size.width * 0.25),
                              Column(
                                children: [
                                  Text(serviceLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  Text(booking.vehicleTypeName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
                                ],
                              ),
                              Container(width: MediaQuery.of(context).size.width * 0.03),
                              if (booking.bookingNumber.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: AppColors.appColor, borderRadius: BorderRadius.circular(20)),
                                  child: Text("#${booking.bookingNumber}", style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Customer + Pickup info
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: cardBorder),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3))],
                            ),
                            // The design's four rows: Start In, Customer Name,
                            // the address, and the goods type - replacing a
                            // Status row (the trip stage already names the
                            // slider) and a pickup+drop pair.
                            child: Column(
                              children: [
                                // Start In
                                Row(
                                  children: [
                                    SizedBox(
                                      height: 27, width: 27,
                                      child: Image.asset("assets/clock.png", height: 27, width: 27, fit: BoxFit.cover, color: AppColors.appColor),
                                    ),
                                    const SizedBox(width: 10),
                                    const Text('Start In', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 13)),
                                    const Spacer(),
                                    Text(_startTime(), style: TextStyle(color: HexColor("#364B63"), fontSize: 13, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                                Container(margin: const EdgeInsets.symmetric(vertical: 10), color: Colors.grey, height: 0.4, width: MediaQuery.of(context).size.width - 50),
                                // Customer Name
                                Row(
                                  children: [
                                    SizedBox(
                                      height: 27, width: 27,
                                      child: Image.asset("assets/profile_circle.png", height: 27, width: 27, fit: BoxFit.cover, color: AppColors.appColor),
                                    ),
                                    const SizedBox(width: 10),
                                    const Text('Customer Name', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 13)),
                                    const Spacer(),
                                    Flexible(child: Text(booking.customerName, style: TextStyle(color: HexColor("#364B63"), fontSize: 13), overflow: TextOverflow.ellipsis)),
                                  ],
                                ),
                                Container(margin: const EdgeInsets.symmetric(vertical: 10), color: Colors.grey, height: 0.4, width: MediaQuery.of(context).size.width - 50),
                                // The stage's target address - pickup until the
                                // goods are aboard, drop afterwards. The design
                                // draws ONE address row; showing whichever one
                                // the driver is actually heading to keeps that
                                // without hiding where the trip goes next.
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      height: 24, width: 24,
                                      child: Image.asset("assets/location.png", height: 24, width: 24, fit: BoxFit.contain, color: AppColors.appColor),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _headingToPickup ? booking.pickup.address : booking.drop.address,
                                        style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w500, height: 1.45),
                                      ),
                                    ),
                                  ],
                                ),
                                if (booking.goodsType.isNotEmpty) ...[
                                  Container(margin: const EdgeInsets.symmetric(vertical: 10), color: Colors.grey, height: 0.4, width: MediaQuery.of(context).size.width - 50),
                                  // Goods type + description, per the design
                                  // ("Furniture - Chairs, tables, small home
                                  // items"). No package-outline asset ships in
                                  // this app, so a Material glyph stands in
                                  // until one is exported from Figma.
                                  Row(
                                    children: [
                                      Icon(Icons.inventory_2_outlined, size: 22, color: AppColors.appColor),
                                      const SizedBox(width: 12),
                                      Text(booking.goodsType, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 13)),
                                      const Spacer(),
                                      Flexible(
                                        child: Text(
                                          booking.goodsDescription,
                                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Action buttons
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: cardBorder),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 3))],
                            ),
                            // The design's three equal columns. Get Directions is
                            // the emphasised one - a solid orange rounded square
                            // holding a white glyph, which is exactly how
                            // get_direction.png is cut: one flat colour with the
                            // paper-plane knocked out to transparency, so tinting
                            // it orange over this white card gives the design
                            // (the shipped fill is the old green, hence the tint).
                            child: Row(
                              children: [
                                _ActionTile(
                                  icon: Image.asset("assets/call_icon.png",
                                      height: 28, width: 28, color: AppColors.appColor),
                                  label: 'contact'.tr,
                                  onTap: _callCustomer,
                                ),
                                _ActionTile(
                                  icon: Image.asset("assets/get_direction.png",
                                      height: 38, width: 38, color: AppColors.appColor),
                                  label: 'get_directions'.tr,
                                  onTap: _openDirections,
                                ),
                                // The design's third column is "ID Card", but the
                                // driver's booking payload carries no customer
                                // identity beyond a name and a phone number -
                                // no ID document, photo or KYC field exists to
                                // show (mapDashboardBooking, driver.controller.ts).
                                // A tile that opens nothing is worse than none,
                                // so the slot holds Chat, which is real and
                                // would otherwise have lost its home here.
                                _ActionTile(
                                  icon: Icon(Icons.chat_bubble_outline,
                                      color: AppColors.appColor, size: 28),
                                  label: 'Chat',
                                  showDivider: false,
                                  onTap: () => pushTo(
                                    context,
                                    ChatScreen(
                                      bookingId: booking.id,
                                      customerName: booking.customerName,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 7),

                          // Add-on services (if any)
                          if (booking.addons.isNotEmpty) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: cardBorder),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('addon_services'.tr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 6),
                                  ...booking.addons.map((addon) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      children: [
                                        Icon(Icons.check_circle_outline, color: AppColors.appColor, size: 16),
                                        const SizedBox(width: 6),
                                        Expanded(child: Text(addon.name, style: const TextStyle(fontSize: 12))),
                                        Text("\u20B9${addon.price.toStringAsFixed(0)} x${addon.quantity}", style: TextStyle(fontSize: 12, color: AppColors.appColor, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  )),
                                  if (booking.loadingUnloading != null && booking.loadingUnloading!.type != "NONE") ...[
                                    const Divider(height: 12),
                                    Row(
                                      children: [
                                        const Icon(Icons.elevator, size: 16, color: Colors.grey),
                                        const SizedBox(width: 6),
                                        Text(booking.loadingUnloading!.type, style: const TextStyle(fontSize: 12)),
                                        const Spacer(),
                                        Text("\u20B9${booking.loadingUnloading!.charge.toStringAsFixed(0)}", style: TextStyle(fontSize: 12, color: AppColors.appColor, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 7),
                          ],

                          // Earnings card
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: HexColor("#E1E6EF")),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.currency_rupee, color: AppColors.appColor, size: 20),
                                        const SizedBox(width: 4),
                                        Text(earnings.toStringAsFixed(0), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                      ],
                                    ),
                                    Text(earningsKnown ? 'your_estimated_earnings'.tr : 'Trip value (earnings pending)', style: const TextStyle(fontSize: 13, color: Colors.black)),
                                  ],
                                ),
                                // Add-on work is already inside the settlement
                                // base, so "incl.", not an additive bonus.
                                if (booking.addonTotal > 0)
                                  Text("incl. \u20B9${booking.addonTotal.toStringAsFixed(0)}", style: TextStyle(color: AppColors.appColor, fontWeight: FontWeight.w600, fontSize: 14)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 7),

                          // Payment method
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: HexColor("#E1E6EF")),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.payment, size: 18, color: Colors.grey),
                                const SizedBox(width: 8),
                                Text('payment'.tr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                const Spacer(),
                                Text(booking.paymentMethod, style: TextStyle(fontSize: 12, color: HexColor("#364B63"), fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 7),

                          // Help & Raise Ticket
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => pushTo(context, const HelpSupportScreen()),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    height: 54,
                                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: cardBorder)),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.headset_mic, color: HexColor("#015EA3"), size: 24),
                                        const SizedBox(width: 8),
                                        Text('help_support'.tr, style: TextStyle(color: HexColor("#015EA3"), fontSize: 14, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: InkWell(
                                  onTap: _raiseTicket,
                                  child: Container(
                                    height: 54,
                                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: cardBorder)),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Image.asset("assets/raise_ticket_icon.png", height: 24),
                                        const SizedBox(width: 8),
                                        Text('raise_ticket'.tr, style: const TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Cancelling is still pre-pickup only: once the goods
                          // are aboard it is a support case. The design's action
                          // row has no room for it, so it sits with the other
                          // "something is wrong" routes as a quiet text button -
                          // deleting it would have taken away the driver's only
                          // way to hand a bad pickup back.
                          if (booking.status == 'ASSIGNED' ||
                              booking.status == 'DRIVER_ARRIVED')
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: _cancelBooking,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: const Size(0, 36),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: const Icon(Icons.close, size: 15, color: Colors.red),
                                label: Text('cancel_booking'.tr,
                                    style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600)),
                              ),
                            ),
                          const SizedBox(height: 7),

                          // At Pickup slider
                          _isArriving
                              ? Container(
                                  height: 50,
                                  decoration: BoxDecoration(color: AppColors.appColor, borderRadius: BorderRadius.circular(20)),
                                  child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))),
                                )
                              : SliderButtonWidget(
                                  text: 'at_pickup'.tr,
                                  arrowColor: AppColors.appColor,
                                  backgroundColor: AppColors.appColor,
                                  onTap: _markArrived,
                                ),
                          const SizedBox(height: 7),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  /// A whole widget, not an IconData: one of the design's three columns is a
  /// solid orange square rendered from an asset, the others are glyphs.
  final Widget icon;
  final String label;
  final VoidCallback onTap;

  /// The separator sits between columns, so the last one leaves it off -
  /// a trailing rule used to draw a line down the card's own right edge.
  final bool showDivider;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    const Color cardBorder = Color(0xFFE6EEF2);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            border: showDivider
                ? const Border(right: BorderSide(color: cardBorder, width: 1))
                : null,
          ),
          child: Column(
            children: [
              // Fixed boxes for both rows: the emphasised square is taller than
              // the glyphs beside it, and translated labels ("Get Directions" is
              // one word longer in several locales) wrap to two lines. Without
              // them the columns end up different heights and the separators
              // between them come out ragged.
              SizedBox(height: 38, child: Center(child: icon)),
              const SizedBox(height: 6),
              SizedBox(
                height: 32,
                child: Text(label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
