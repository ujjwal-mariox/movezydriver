import 'dart:ui';
import 'package:movezy_driver_app/AppNavigation/app_navigation.dart';
import 'package:movezy_driver_app/Screens/CollectedCaseScreen/collected_case_screen.dart';
import 'package:movezy_driver_app/Screens/TechnicianDashboard/technician_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';
import 'package:movezy_driver_app/Screens/TechnicianDashboard/dashboard_api_service.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:pinput/pinput.dart';

/// "Start Trip" OTP gate, per the design: blurred map behind, sheet with
/// "Enter Pickup OTP", the code boxes, the earnings card, and a Verify Ride
/// button with the white chevron chip.
class VerifyRideScreen extends StatefulWidget {
  /// Booking being verified. Required so OTP/start calls target the right ride.
  final String bookingId;
  final String? bookingNumber;
  final String? earnings;

  /// True when [earnings] is really the customer's gross fare because the
  /// driver figure wasn't on the booking (older rides) — swaps the label so
  /// the gross never wears "your earnings".
  final bool earningsIsGross;
  final String? incentive;

  /// ISO timestamps from the dashboard payload, used to show the driver when
  /// the pickup is due. `scheduledAt` is set only for scheduled bookings;
  /// `createdAt` (when the customer booked) is the fallback for instant ones.
  final String? scheduledAt;
  final String? createdAt;

  const VerifyRideScreen({
    super.key,
    required this.bookingId,
    this.bookingNumber,
    this.earnings,
    this.earningsIsGross = false,
    this.incentive,
    this.scheduledAt,
    this.createdAt,
  });
  @override
  State<VerifyRideScreen> createState() => _VerifyRideScreenState();
}

class _VerifyRideScreenState extends State<VerifyRideScreen> {
  final DashboardApiService _apiService = DashboardApiService();
  String pinValue = "";
  bool _verifying = false;

  /// A previous attempt already passed the OTP gate (server flipped the
  /// booking to PICKED). A retried verify then fails with "invalid booking"
  /// even though the code was right — treat that retry as verified instead of
  /// stranding the driver on a gate they already cleared.
  bool _otpVerified = false;

  static const _grayShade1 = Color(0xFF132235);
  static const _grayShade2 = Color(0xFF364B63);
  static const _grayShade4 = Color(0xFF94A3B3);
  static const _grayBorder = Color(0xFFE1E6EF);

  /// Pickup time to show, as (label, formatted time). Prefers the scheduled slot
  /// and falls back to when the booking was placed. Returns null when neither
  /// timestamp is usable, so the row is hidden rather than showing an empty one.
  /// The backend can send the literal string "null".
  (String, String)? _pickupTime() {
    final scheduled = widget.scheduledAt ?? '';
    final created = widget.createdAt ?? '';

    for (final entry in [
      ('Scheduled pickup', scheduled),
      ('Booked at', created),
    ]) {
      final raw = entry.$2;
      if (raw.isEmpty || raw == 'null') continue;
      final dt = DateTime.tryParse(raw);
      if (dt == null) continue;
      return (entry.$1, DateFormat("dd MMM, hh:mm a").format(dt.toLocal()));
    }
    return null;
  }

  /// Verify the pickup OTP, then start the trip, then go to the trip screen.
  Future<void> _verifyAndStart() async {
    if (_verifying) return;
    if (pinValue.length < 4) {
      Fluttertoast.showToast(msg: "Enter the pickup OTP");
      return;
    }
    setState(() => _verifying = true);

    final verify = await _apiService.verifyPickupOtp(widget.bookingId, pinValue);
    final verifyOk = verify != null && (verify['code'] == 1 || verify['code'] == 200);
    if (verifyOk) _otpVerified = true;
    if (!verifyOk && !_otpVerified) {
      if (!mounted) return;
      setState(() => _verifying = false);
      Fluttertoast.showToast(msg: verify?['message']?.toString() ?? "Invalid OTP");
      return;
    }

    // Best-effort: the OTP gate is behind us on the server, so a failed start
    // must NOT strand the driver here — retrying verify would only get
    // "invalid booking" (the booking is PICKED now). The trip screen re-runs
    // startTrip itself when the booking is still PICKED, so hand over always.
    await _apiService.startTrip(widget.bookingId);
    if (!mounted) return;
    setState(() => _verifying = false);
    // Replace, not push: backing out of the trip screen onto this OTP prompt
    // again read as the app being broken.
    replaceRoute(
        context, AmountToBeCollectedScreen(bookingId: widget.bookingId));
  }

  @override
  Widget build(BuildContext context) {
    // The design's OTP boxes: grey #F5F5F5, radius 6. Four of them, not the
    // mock's six — the real pickup OTP is 4 digits (booking.model `otp`), and
    // six boxes would leave two that can never fill.
    final pinTheme = PinTheme(
      width: 58,
      height: 46,
      textStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: _grayShade1,
      ),
      decoration: BoxDecoration(
        color: HexColor("#F5F5F5"),
        borderRadius: BorderRadius.circular(6),
      ),
    );
    final focusedTheme = pinTheme.copyWith(
      decoration: BoxDecoration(
        color: HexColor("#F5F5F5"),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.appColor, width: 1.4),
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF0F5FA),
      body: Stack(
        children: [
          // Map backdrop, blurred with a light wash — the design's frosted look.
          Positioned.fill(
            child: Image.asset("assets/map_image.png", fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: Container(color: Colors.white.withValues(alpha: 0.3)),
            ),
          ),

          // Orange header.
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 8, bottom: 18),
              color: AppColors.appColor,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Text(
                    'Start Trip',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700),
                  ),
                  Positioned(
                    left: 4,
                    child: IconButton(
                      // Reached via replaceRoute after Mark Arrived, this can
                      // be the navigator's ONLY route — popping it then left a
                      // blank app. Fall back to the dashboard in that case.
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
                ],
              ),
            ),
          ),

          // Bottom sheet.
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
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
                          color: _grayShade4,
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Enter Pickup OTP',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: _grayShade1),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'to start delivery',
                        style: TextStyle(fontSize: 15, color: _grayShade1),
                      ),
                      if (_pickupTime() case (final label, final time)?) ...[
                        const SizedBox(height: 6),
                        Text(
                          '$label: $time',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _grayShade2),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Enter OTP',
                          style: const TextStyle(
                              fontSize: 14, color: Colors.black),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Pinput(
                        // Backend pickup OTP is 4 digits (booking.model otp).
                        length: 4,
                        defaultPinTheme: pinTheme,
                        focusedPinTheme: focusedTheme,
                        onChanged: (value) => setState(() => pinValue = value),
                        onCompleted: (pin) => setState(() => pinValue = pin),
                      ),
                      const SizedBox(height: 16),

                      // Earnings card, same anatomy as the Take Booking screen.
                      Container(
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
                          children: [
                            Icon(Icons.currency_rupee,
                                size: 20, color: AppColors.appColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '₹${widget.earnings ?? "--"}',
                                    style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: _grayShade1),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.earningsIsGross
                                        ? 'Trip value (earnings pending)'
                                        : 'Your estimated earnings',
                                    style: const TextStyle(
                                        fontSize: 13, color: _grayShade2),
                                  ),
                                ],
                              ),
                            ),
                            if ((widget.incentive ?? '').isNotEmpty)
                              Text(
                                widget.incentive!,
                                style: TextStyle(
                                    color: AppColors.appColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Verify Ride — orange bar, white chevron chip on the left.
                      InkWell(
                        onTap: _verifying ? null : _verifyAndStart,
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
                                _verifying ? 'Verifying...' : 'Verify Ride',
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
                                  child: _verifying
                                      ? Center(
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                                color: AppColors.appColor,
                                                strokeWidth: 2.4),
                                          ),
                                        )
                                      : Icon(Icons.keyboard_double_arrow_right,
                                          color: AppColors.appColor, size: 24),
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
          ),
        ],
      ),
    );
  }
}
