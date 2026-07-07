import 'dart:ui';
import 'package:movezy_driver_app/AppNavigation/app_navigation.dart';
import 'package:movezy_driver_app/CommonWidgets/slider_button_widget.dart';
import 'package:movezy_driver_app/Screens/CollectedCaseScreen/collected_case_screen.dart';
import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';
import 'package:movezy_driver_app/Screens/TechnicianDashboard/dashboard_api_service.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:pinput/pinput.dart';

class VerifyRideScreen extends StatefulWidget {
  /// Booking being verified. Required so OTP/start calls target the right ride.
  final String bookingId;
  final String? bookingNumber;
  final String? earnings;
  final String? incentive;
  const VerifyRideScreen({
    super.key,
    required this.bookingId,
    this.bookingNumber,
    this.earnings,
    this.incentive,
  });
  @override
  State<VerifyRideScreen> createState() => _VerifyRideScreenState();
}

class _VerifyRideScreenState extends State<VerifyRideScreen> {
  final DashboardApiService _apiService = DashboardApiService();
  String pinValue = "";
  bool _verifying = false;

  /// Verify the pickup OTP, then start the trip, then go to the collect screen.
  Future<void> _verifyAndStart() async {
    if (_verifying) return;
    if (pinValue.length < 4) {
      Fluttertoast.showToast(msg: "Enter the pickup OTP");
      return;
    }
    setState(() => _verifying = true);

    final verify = await _apiService.verifyPickupOtp(widget.bookingId, pinValue);
    final verifyOk = verify != null && (verify['code'] == 1 || verify['code'] == 200);
    if (!verifyOk) {
      if (!mounted) return;
      setState(() => _verifying = false);
      Fluttertoast.showToast(msg: verify?['message']?.toString() ?? "Invalid OTP");
      return;
    }

    final start = await _apiService.startTrip(widget.bookingId);
    if (!mounted) return;
    setState(() => _verifying = false);
    final startOk = start != null && (start['code'] == 1 || start['code'] == 200);
    if (startOk) {
      pushTo(context, AmountToBeCollectedScreen(bookingId: widget.bookingId));
    } else {
      Fluttertoast.showToast(msg: start?['message']?.toString() ?? "Could not start trip");
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFFBFD87D);
    const Color cardBorder = Color(0xFFE6EEF2);


    final defaultPinTheme = PinTheme(
      width: 60,
      height: 60,
      textStyle: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w400,
      ),
      decoration: BoxDecoration(
        //  color: HexColor("#158DFE").withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.transparent),
      ),
    );


    final focusedPinTheme = PinTheme(
      width: 45,
      height: 45,
      textStyle: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w400,
      ),
      decoration: BoxDecoration(
            color: HexColor("#F5F5F5"),
        borderRadius: BorderRadius.circular(6),
      //  border: Border.all(color: HexColor("#D3DDE7"), width: 1.5),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.grey,
      body: SizedBox(
        height: MediaQuery.of(context).size.height,
        child: Stack(
          children: [

            Image.asset("assets/map_image.png", height: MediaQuery.of(context).size.height * 0.7,fit: BoxFit.cover,),

            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                child: Container(
                  color: Colors.black.withOpacity(0.1),
                ),
              ),
            ),

            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 5),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
                    color: Colors.white
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(width: MediaQuery.of(context).size.width * 0.18,),
                        Column(
                          children: [
                            const Text(
                              "Please Enter the OTP",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),

                            const Text(
                              "to confirm your ride.",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),


                        SizedBox(width: 10,),

                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.appColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            // Real booking number (was a hardcoded "#12345678").
                            widget.bookingNumber?.isNotEmpty == true
                                ? "#${widget.bookingNumber}"
                                : "#${widget.bookingId.length > 6 ? widget.bookingId.substring(widget.bookingId.length - 6) : widget.bookingId}",
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 15),

                    Container(
                      width: MediaQuery.of(context).size.width,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Enter OTP",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    Center(
                      child: Pinput(
                        // Backend pickup OTP is 4 digits (booking.model otp).
                        length: 4,
                        defaultPinTheme: focusedPinTheme,
                        focusedPinTheme: focusedPinTheme,
                        onChanged: (value){
                          pinValue = value;
                          setState(() {
                          });
                        },
                        onCompleted: (pin) {
                          pinValue = pin;
                          setState(() {});
                        },
                      ),
                    ),

                    const SizedBox(height: 15),

                    Container(
                      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: HexColor("#E1E6EF")),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Icon(Icons.currency_rupee, color: AppColors.appColor, size: 20),
                                      SizedBox(width: 4),
                                      Text(
                                        widget.earnings ?? "--",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    "Your estimated earnings",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),

                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children:  [
                              Text(
                                widget.incentive ?? "",
                                style: TextStyle(
                                  color: AppColors.appColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 15),

                    Padding(
                      padding: const EdgeInsets.only(left: 0, right: 0),
                      child: SliderButtonWidget(
                        text: _verifying ? "Verifying..." : "Verify & Start Trip",
                        arrowColor: AppColors.appColor,
                        backgroundColor: AppColors.appColor,
                        onTap: _verifying ? null : _verifyAndStart,
                      ),
                    ),

                    const SizedBox(height: 7),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String icon;
  final String label;
  const _ActionTile({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    const Color cardBorder = Color(0xFFE6EEF2);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: cardBorder, width: 1)),
        ),
        child: Column(
          children: [
            Image.asset(icon, width: 24,),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: Color(0xFF7EBF5C), fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
