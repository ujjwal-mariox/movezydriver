import 'dart:async';
import 'package:movezy_driver_app/AppNavigation/app_navigation.dart';
import 'package:movezy_driver_app/Screens/BookingsDetailsScreen/bookings_details_screen.dart';
import 'package:movezy_driver_app/Screens/TechnicianDashboard/dashboard_api_service.dart';
import 'package:movezy_driver_app/Screens/TechnicianDashboard/Model/driver_dashboard_response.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:movezy_driver_app/Services/routing_service.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';

/// Offers this driver has already declined, for as long as the app is running.
///
/// The backend's reject only prunes a Redis dispatch set — the booking itself
/// stays SEARCHING and is still one of *this* driver's pending rows, so the
/// dashboard refresh that runs the moment this screen pops put the very same
/// card straight back on screen. Held in memory only: a skip is a decision
/// about one dispatch round, not a permanent block, so a relaunch starts clean.
class SkippedBookings {
  SkippedBookings._();

  static final Set<String> _ids = <String>{};

  static void add(String bookingId) {
    if (bookingId.isNotEmpty) _ids.add(bookingId);
  }

  static bool contains(String bookingId) => _ids.contains(bookingId);

  /// [offers] minus everything this driver has skipped.
  static List<DashboardBooking> filter(List<DashboardBooking> offers) =>
      offers.where((o) => !_ids.contains(o.id)).toList();
}

class TakeBookingsScreen extends StatefulWidget {
  final DashboardBooking booking;
  const TakeBookingsScreen({super.key, required this.booking});

  @override
  State<TakeBookingsScreen> createState() => _TakeBookingsScreenState();
}

class _TakeBookingsScreenState extends State<TakeBookingsScreen> {
  final DashboardApiService _apiService = DashboardApiService();
  bool _isAccepting = false;
  bool _isRejecting = false;

  // Countdown from the SERVER's persisted offer window (offerExpiresAt on the
  // pending payload — the very condition the old removal note set for bringing
  // a timer back). Two rules survive from that lesson:
  //  - no offerExpiresAt → no countdown. Never an invented number.
  //  - at zero we say the window ended and STOP the timer — we never
  //    auto-decline and never disable Accept, because the server still allows
  //    accepting any booking that remains unassigned.
  Timer? _offerTimer;
  int? _remainingSeconds;
  int _offerWindowTotal = 1;

  void _startOfferCountdown() {
    final expiry = booking.offerExpiresAt;
    if (expiry == null) return;
    _offerWindowTotal =
        expiry.difference(DateTime.now()).inSeconds.clamp(1, 999);
    void tick() {
      final left = expiry.difference(DateTime.now()).inSeconds;
      if (!mounted) return;
      setState(() => _remainingSeconds = left > 0 ? left : 0);
      if (left <= 0) _offerTimer?.cancel();
    }

    tick();
    _offerTimer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  DashboardBooking get booking => widget.booking;

  /// Road geometry pickup → drop; empty until fetched, straight line until then.
  List<LatLng> _roadRoute = const [];

  Future<void> _loadRoadRoute() async {
    if (!_hasValidCoords) return;
    final points = await RoutingService.route(pickupLatLng, dropLatLng);
    if (mounted && points.length > 2) setState(() => _roadRoute = points);
  }

  LatLng get pickupLatLng => LatLng(booking.pickup.lat, booking.pickup.lng);
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

  @override
  void initState() {
    super.initState();
    _loadRoadRoute();
    // Strong vibration on new order
    _vibrateNewOrder();
    _startOfferCountdown();
  }

  @override
  void dispose() {
    _offerTimer?.cancel();
    super.dispose();
  }

  void _vibrateNewOrder() async {
    // Triple vibration pattern for new orders
    for (int i = 0; i < 3; i++) {
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  Future<void> _acceptBooking() async {
    setState(() => _isAccepting = true);
    HapticFeedback.heavyImpact();

    final resp = await _apiService.acceptBooking(booking.id);
    if (!mounted) return;
    setState(() => _isAccepting = false);

    if (resp != null && (resp['code'] == 1 || resp['code'] == 200)) {
      final data = resp['data'];
      DashboardBooking? accepted;
      if (data is Map) {
        accepted = DashboardBooking.fromJson(Map<String, dynamic>.from(data));
      }
      Fluttertoast.showToast(msg: 'booking_accepted'.tr);
      if (accepted != null) {
        Navigator.pop(context);
        pushTo(context, BookingDetailPage(booking: accepted));
      } else {
        Navigator.pop(context);
      }
    } else {
      Fluttertoast.showToast(msg: resp?['message']?.toString() ?? "Could not accept booking");
    }
  }

  /// Skip is now only ever a decision the driver made: the auto-decline path
  /// that fired on the invented countdown is gone. A Skip the server refused
  /// must NOT pretend it declined — the card would just reappear on the
  /// dashboard with no explanation.
  Future<void> _rejectBooking() async {
    setState(() => _isRejecting = true);
    final resp = await _apiService.rejectBooking(booking.id);
    if (!mounted) return;
    setState(() => _isRejecting = false);
    final ok = resp != null && (resp['code'] == 1 || resp['code'] == 200);
    if (ok) {
      // Remember the decline for this session. Without it the dashboard's
      // post-pop refresh re-rendered the same offer, because the server keeps
      // the booking pending for this driver either way.
      SkippedBookings.add(booking.id);
      Fluttertoast.showToast(msg: 'booking_declined'.tr);
      Navigator.pop(context);
    } else {
      Fluttertoast.showToast(
          msg: resp?['message']?.toString() ??
              'Could not skip the booking. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _grayBackground,
      body: Stack(
        children: [
          Positioned.fill(child: _map()),
          Align(alignment: Alignment.topCenter, child: _header()),
          Align(alignment: Alignment.bottomCenter, child: _sheet()),
        ],
      ),
    );
  }

  // Palette from the design.
  static const _grayBackground = Color(0xFFF0F5FA);
  static const _grayShade1 = Color(0xFF132235);
  static const _grayShade2 = Color(0xFF364B63);
  static const _grayShade4 = Color(0xFF94A3B3);
  static const _grayShade5 = Color(0xFFD3DDE7);
  static const _grayBorder = Color(0xFFE1E6EF);
  static const _errorRed = Color(0xFFE02D3C);
  static const _acceptGreen = Color(0xFF64B161);

  Widget _map() {
    if (!_hasValidCoords) {
      return Container(
        color: const Color(0xFFE7EDF4),
        alignment: Alignment.center,
        child: Text('map_not_available'.tr,
            style: const TextStyle(color: _grayShade2)),
      );
    }
    return FlutterMap(
      options: MapOptions(
        initialCameraFit: CameraFit.bounds(
          bounds: _mapBounds,
          // Generous bottom inset: the sheet covers roughly the lower half, so
          // an evenly padded fit would centre the route underneath it.
          padding: const EdgeInsets.fromLTRB(60, 150, 60, 380),
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.movezy.driver',
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
        MarkerLayer(
          markers: [
            Marker(
              point: pickupLatLng,
              width: 34,
              height: 34,
              child: _pickupMarker(),
            ),
            Marker(
              point: dropLatLng,
              width: 44,
              height: 56,
              child: const Icon(Icons.location_on,
                  color: _errorRed, size: 44),
            ),
          ],
        ),
      ],
    );
  }

  /// The design's pickup marker: a translucent halo around a white-ringed dot.
  Widget _pickupMarker() => Center(
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppColors.appColor.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: AppColors.appColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 1)),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8, bottom: 18),
      decoration: BoxDecoration(
        color: AppColors.appColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Text(
            'Take Booking',
            style: TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
          ),
          Positioned(
            left: 4,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheet() {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: Color(0x59000000), blurRadius: 15, offset: Offset(0, 5)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetHeader(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _pickupCard(),
                    const SizedBox(height: 8),
                    for (var i = 0; i < booking.stops.length; i++) ...[
                      _stopCard(i),
                      const SizedBox(height: 8),
                    ],
                    _destinationCard(),
                    const SizedBox(height: 8),
                    _earningsCard(),
                    if (booking.addons.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _addonsCard(),
                    ],
                  ],
                ),
              ),
            ),
            _actions(),
          ],
        ),
      ),
    );
  }

  Widget _sheetHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        children: [
          Container(
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: _grayShade4,
              borderRadius: BorderRadius.circular(100),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  _tripTitle(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _grayShade1),
                ),
              ),
              const SizedBox(width: 10),
              _grabNowPill(),
            ],
          ),
        ],
      ),
    );
  }

  /// The design's orange badge.
  ///
  /// It used to carry a seconds counter and flip to "Expired" at zero. Both
  /// were invented — see the note at the top of this state class. The badge now
  /// says only what is true: the job goes to whichever driver takes it first,
  /// so it can be gone before you tap Accept. No deadline is asserted.
  Widget _grabNowPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.appColor,
        borderRadius: BorderRadius.circular(99),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt, color: Colors.white, size: 14),
          SizedBox(width: 2),
          Text(
            'Grab now',
            style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget icon, required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _grayBorder),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 3,
                offset: const Offset(0, 1)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.only(top: 1), child: icon),
            const SizedBox(width: 8),
            Expanded(child: child),
          ],
        ),
      );

  /// "07:45AM | 9.69KM | 60 Mins" — hairline-separated meta, as designed.
  Widget _meta(List<String> parts) {
    final items = <Widget>[];
    for (var i = 0; i < parts.length; i++) {
      if (i > 0) {
        items
          ..add(const SizedBox(width: 9))
          ..add(Container(width: 1, height: 12, color: _grayShade5))
          ..add(const SizedBox(width: 9));
      }
      items.add(Text(parts[i],
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: _grayShade2)));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: items);
  }

  Widget _cardTitleRow(String title, List<String> meta) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _grayShade1)),
          ),
          const SizedBox(width: 8),
          if (meta.isNotEmpty)
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: _meta(meta),
              ),
            ),
        ],
      );

  Widget _address(String value) => Text(
        value.isEmpty ? 'Address not available' : value,
        style: const TextStyle(
            fontSize: 13, height: 1.38, color: _grayShade2),
      );

  Widget _pickupCard() => _card(
        icon: SizedBox(width: 20, height: 20, child: _pickupMarker()),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Only the pickup time is shown: the design's second figure is the
            // distance from the driver to the pickup, which this payload does
            // not carry. The map above already conveys it.
            _cardTitleRow('Pickup', [
              if (_pickupTime().isNotEmpty) _pickupTime(),
            ]),
            const SizedBox(height: 4),
            _address(booking.pickupAddress),
          ],
        ),
      );

  /// One intermediate drop of a multi-stop ride, numbered in delivery order.
  Widget _stopCard(int index) {
    final stop = booking.stops[index];
    return _card(
      icon: Container(
        width: 20,
        height: 20,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.appColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '${index + 1}',
          style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitleRow('Stop ${index + 1}', []),
          const SizedBox(height: 4),
          _address(stop.address),
        ],
      ),
    );
  }

  Widget _destinationCard() => _card(
        icon: const Icon(Icons.location_on, size: 20, color: _errorRed),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardTitleRow(
                booking.stops.isEmpty ? 'Destination' : 'Final drop', [
              '${booking.distanceKm.toStringAsFixed(2)}KM',
              '${booking.durationMin} Mins',
            ]),
            const SizedBox(height: 4),
            _address(booking.dropAddress),
          ],
        ),
      );

  Widget _earningsCard() {
    // estimatedEarnings is the driver's own settlement estimate (subtotal minus
    // commission, pre-GST) — the same basis the payout screen uses. The gross
    // customer fare lives in estimatedFare and must never wear this label.
    final earnings = booking.estimatedEarnings > 0
        ? booking.estimatedEarnings
        : booking.estimatedFare;
    final estimateOnly = booking.estimatedEarnings <= 0;

    return _card(
      icon: Icon(Icons.currency_rupee, size: 20, color: AppColors.appColor),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('₹${earnings.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _grayShade1)),
                const SizedBox(height: 4),
                Text(
                  estimateOnly
                      ? 'Trip value (earnings pending)'
                      : 'Your estimated earnings',
                  style: const TextStyle(fontSize: 13, color: _grayShade2),
                ),
              ],
            ),
          ),
          // Add-on work is already inside the settlement base, so this is
          // labelled "incl." rather than shown as an additive bonus.
          if (booking.addonTotal > 0)
            Text(
              'incl. ₹${booking.addonTotal.toStringAsFixed(0)}',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.appColor),
            ),
        ],
      ),
    );
  }

  Widget _addonsCard() => _card(
        icon: Icon(Icons.add_task, size: 20, color: AppColors.appColor),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add-on work',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _grayShade1)),
            const SizedBox(height: 4),
            ...booking.addons.map(
              (a) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        a.quantity > 1 ? '${a.name} x${a.quantity}' : a.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, color: _grayShade2),
                      ),
                    ),
                    Text('₹${a.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _grayShade2)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _actions() {
    final busy = _isAccepting || _isRejecting;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        // min, so this block reports its true height to the sheet's Column and
        // is laid out after the scroll area rather than competing with it.
        mainAxisSize: MainAxisSize.min,
        // stretch, so buttons fill the sheet width instead of shrinking to
        // their label — a Column's default centre alignment gives children
        // loose constraints, which is what collapsed them.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Accept first and visibly larger. Skip used to sit ON TOP at the
          // same size, so the natural first tap — reaching for the primary
          // action — landed on Skip and silently rejected the job. The order
          // and the size difference both push the thumb toward Accept.
          if (_remainingSeconds != null) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _remainingSeconds! > 0
                  ? Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (_remainingSeconds! / _offerWindowTotal)
                                .clamp(0.0, 1.0),
                            minHeight: 5,
                            backgroundColor: const Color(0xFFEDEDED),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _remainingSeconds! <= 10
                                  ? const Color(0xFFEF4444)
                                  : _acceptGreen,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Offer window: ${_remainingSeconds}s',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: _remainingSeconds! <= 10
                                ? const Color(0xFFEF4444)
                                : Colors.black54,
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      'Offer window ended — you can still accept if the job is unclaimed.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
            ),
          ],
          _actionButton(
            label: 'Accept Booking',
            colour: _acceptGreen,
            iconOnRight: false,
            icon: Icons.keyboard_double_arrow_right,
            busy: _isAccepting,
            onTap: busy ? null : _acceptBooking,
            height: 58,
          ),
          const SizedBox(height: 12),
          _actionButton(
            label: 'Skip Booking',
            colour: _errorRed,
            iconOnRight: true,
            icon: Icons.keyboard_double_arrow_left,
            busy: _isRejecting,
            onTap: busy ? null : _rejectBooking,
            height: 42,
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required Color colour,
    required bool iconOnRight,
    required IconData icon,
    required bool busy,
    required VoidCallback? onTap,
    // Accept renders taller than Skip so the primary action is the easier
    // target; the chip scales with the bar so it never overflows the 42px Skip.
    double height = 48,
  }) {
    final chipH = height - 6;
    final chip = Container(
      width: 56,
      height: chipH,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: colour, size: 26),
    );

    return Opacity(
      opacity: onTap == null && !busy ? 0.6 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          height: height,
          decoration: BoxDecoration(
            color: colour,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                // Symmetric, so the label sits centred in the bar and stays
                // clear of the 56px chip on whichever side it sits.
                padding: const EdgeInsets.symmetric(horizontal: 64),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700),
                ),
              ),
              Positioned(
                left: iconOnRight ? null : 2,
                right: iconOnRight ? 2 : null,
                top: 2,
                child: busy
                    ? SizedBox(
                        width: 56,
                        height: chipH,
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: colour, strokeWidth: 2.4),
                          ),
                        ),
                      )
                    : chip,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The sheet's heading. There is no one-way/round-trip flag on a booking —
  /// every job here is a single pickup to a single drop — so this states what
  /// the trip actually is rather than echoing the mock's label.
  String _tripTitle() {
    final vehicle = booking.vehicleTypeName.trim();
    final service = switch (booking.serviceType) {
      'WITHIN_CITY' => 'Within City',
      'OUTSTATION' => 'Outstation',
      _ => booking.serviceType.replaceAll('_', ' ').trim(),
    };
    if (vehicle.isEmpty && service.isEmpty) return 'New Booking';
    if (vehicle.isEmpty) return service;
    if (service.isEmpty) return vehicle;
    return '$vehicle · $service';
  }

  /// Scheduled pickup time where there is one, else when the job was raised.
  /// Parsed then converted to local — the backend also sends the literal
  /// string "null", which must not be shown as a time.
  String _pickupTime() {
    for (final raw in [booking.scheduledAt, booking.createdAt]) {
      if (raw.isEmpty || raw == 'null') continue;
      final dt = DateTime.tryParse(raw);
      if (dt == null) continue;
      return DateFormat('hh:mma').format(dt.toLocal());
    }
    return '';
  }
}