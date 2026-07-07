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
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';

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

  // Countdown timer
  static const int _countdownSeconds = 30;
  int _remainingSeconds = _countdownSeconds;
  Timer? _timer;

  DashboardBooking get booking => widget.booking;

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
    _startCountdown();
    // Strong vibration on new order
    _vibrateNewOrder();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _vibrateNewOrder() async {
    // Triple vibration pattern for new orders
    for (int i = 0; i < 3; i++) {
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _remainingSeconds--;
      });
      // Vibrate at 10 seconds warning
      if (_remainingSeconds == 10) {
        HapticFeedback.heavyImpact();
      }
      if (_remainingSeconds <= 0) {
        timer.cancel();
        // Auto-ignore on timeout
        if (mounted && !_isAccepting) {
          _rejectBooking();
        }
      }
    });
  }

  Future<void> _acceptBooking() async {
    _timer?.cancel();
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

  Future<void> _rejectBooking() async {
    _timer?.cancel();
    setState(() => _isRejecting = true);
    await _apiService.rejectBooking(booking.id);
    if (!mounted) return;
    setState(() => _isRejecting = false);
    Fluttertoast.showToast(msg: 'booking_declined'.tr);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final countdownProgress = _remainingSeconds / _countdownSeconds;

    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      body: Column(
        children: [
          // Map area with back button overlay
          Expanded(
            flex: 3,
            child: Stack(
              children: [
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
                            points: [pickupLatLng, dropLatLng],
                            color: AppColors.appColor,
                            strokeWidth: 3,
                          ),
                        ],
                      ),
                    ],
                  )
                else
                  Container(color: Colors.grey[300], child: Center(child: Text('map_not_available'.tr))),

                // Back button
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10,
                  left: 16,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
                      ),
                      child: const Icon(Icons.arrow_back_ios_new, size: 18),
                    ),
                  ),
                ),

                // Countdown timer overlay (top right)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10,
                  right: 16,
                  child: Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8)],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 48, height: 48,
                          child: CircularProgressIndicator(
                            value: countdownProgress,
                            strokeWidth: 4,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation(
                              _remainingSeconds <= 10 ? Colors.red : AppColors.appColor,
                            ),
                          ),
                        ),
                        Text(
                          '$_remainingSeconds',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _remainingSeconds <= 10 ? Colors.red : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom sheet
          Expanded(
            flex: 5,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topRight: Radius.circular(28), topLeft: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Drag handle
                    Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- ESTIMATED EARNINGS BIG BOLD ---
                    Text(
                      '\u20B9${booking.estimatedFare.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      'estimated_earnings'.tr,
                      style: const TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.w500),
                    ),

                    // Incentive below earnings in green
                    if (booking.addonTotal > 0) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '+\u20B9${booking.addonTotal.toStringAsFixed(0)} add-on bonus',
                          style: const TextStyle(
                            color: Color(0xFF2E7D32),
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 18),

                    // --- Pickup & Drop (short) ---
                    _locationRow(
                      color: const Color(0xFF1F8B4C),
                      label: 'pickup'.tr,
                      address: booking.pickupAddress,
                    ),
                    const SizedBox(height: 10),
                    _locationRow(
                      color: const Color(0xFFE02D3C),
                      label: 'drop'.tr,
                      address: booking.dropAddress,
                    ),

                    const SizedBox(height: 14),

                    // Distance & duration row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.straighten, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text('${booking.distanceKm.toStringAsFixed(1)} km', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(width: 16),
                        Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text('${booking.durationMin} min', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        if (booking.paymentMethod.isNotEmpty) ...[
                          const SizedBox(width: 16),
                          Icon(Icons.payments_outlined, size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(booking.paymentMethod, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ],
                    ),

                    // Add-on services (compact)
                    if (booking.addons.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE1E6EF)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('addons'.tr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54)),
                            const SizedBox(height: 6),
                            ...booking.addons.map((addon) => Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Row(
                                children: [
                                  Icon(Icons.add_circle_outline, color: AppColors.appColor, size: 14),
                                  const SizedBox(width: 6),
                                  Expanded(child: Text(addon.name, style: const TextStyle(fontSize: 12))),
                                  Text("\u20B9${addon.price.toStringAsFixed(0)} x${addon.quantity}",
                                    style: TextStyle(fontSize: 12, color: AppColors.appColor, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            )),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // --- ACCEPT BUTTON (Big - Green - Dominant) ---
                    SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: ElevatedButton(
                        onPressed: _isAccepting || _isRejecting ? null : _acceptBooking,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1F8B4C),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          elevation: 4,
                          shadowColor: const Color(0xFF1F8B4C).withValues(alpha: 0.4),
                        ),
                        child: _isAccepting
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check_circle, size: 28),
                                  const SizedBox(width: 10),
                                  Text('accept'.tr, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 1)),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // --- DECLINE BUTTON (Small - Red) ---
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton(
                        onPressed: _isAccepting || _isRejecting ? null : _rejectBooking,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFE02D3C),
                          side: const BorderSide(color: Color(0xFFE02D3C), width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _isRejecting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Color(0xFFE02D3C), strokeWidth: 2))
                            : Text('decline'.tr, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // --- Ignore button (small at bottom) ---
                    TextButton(
                      onPressed: _isAccepting || _isRejecting ? null : () {
                        _timer?.cancel();
                        Navigator.pop(context);
                      },
                      child: Text(
                        'ignore'.tr,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _locationRow({required Color color, required String label, required String address}) {
    return Row(
      children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Text('$label: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        Expanded(
          child: Text(
            address.isEmpty ? 'Not available' : address,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
        ),
      ],
    );
  }
}
