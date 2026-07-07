import 'package:movezy_driver_app/AppNavigation/app_navigation.dart';
import 'package:movezy_driver_app/CommonWidgets/slider_button_widget.dart';
import 'package:movezy_driver_app/Screens/CollectedCaseScreen/show_fare_calculation_sheet.dart';
import 'package:movezy_driver_app/Screens/TechnicianDashboard/technician_dashboard.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';
import 'package:movezy_driver_app/Screens/TechnicianDashboard/dashboard_api_service.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:url_launcher/url_launcher.dart';

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

  // Real booking details (fare + customer contact), fetched on open.
  Map<String, dynamic>? _booking;

  @override
  void initState() {
    super.initState();
    _loadBooking();
  }

  Future<void> _loadBooking() async {
    final b = await _apiService.getBookingDetails(widget.bookingId);
    if (!mounted) return;
    setState(() => _booking = b);
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

  /// Real trip duration (was a hardcoded "1 Hr 58 Mins"). Prefers actual
  /// pickup→completion timestamps, falls back to the estimated durationMin.
  String get _tripDuration {
    final picked = DateTime.tryParse(_booking?['pickedAt']?.toString() ?? '');
    final completed =
        DateTime.tryParse(_booking?['completedAt']?.toString() ?? '');
    int? minutes;
    if (picked != null && completed != null) {
      minutes = completed.difference(picked).inMinutes;
    } else {
      final est = _booking?['durationMin'];
      if (est is num) minutes = est.round();
    }
    if (minutes == null || minutes < 0) return '--';
    if (minutes >= 60) return '${minutes ~/ 60} Hr ${minutes % 60} Mins';
    return '$minutes Mins';
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

  /// Raise a real support ticket for this booking (button did nothing before).
  Future<void> _raiseTicket() async {
    final resp = await _apiService.raiseTicket(
      category: 'Order Issue',
      subject: 'Issue with booking ${widget.bookingId}',
      message: 'Driver raised a ticket from the collection screen.',
      bookingId: widget.bookingId,
    );
    if (!mounted) return;
    final ok = resp != null && (resp['code'] == 1 || resp['code'] == 200);
    Fluttertoast.showToast(
      msg: ok ? 'Ticket raised. Support will contact you.' : 'Could not raise ticket. Try again.',
    );
  }

  /// Complete the trip, then mark cash collected. Backend credits coins on
  /// completion. Shows the fare sheet on success.
  Future<void> _completeAndCollect() async {
    if (_completing) return;
    setState(() => _completing = true);

    // completeTrip requires the booking to be IN_PROGRESS. If we arrived here
    // with the trip still PICKED (e.g. resumed from the dashboard, or start
    // didn't run), start it first so "Collected Cash" always works.
    final status = _booking?['status']?.toString();
    if (status == 'PICKED') {
      await _apiService.startTrip(widget.bookingId);
    }

    final complete = await _apiService.completeTrip(widget.bookingId);
    final completeOk = complete != null && (complete['code'] == 1 || complete['code'] == 200);
    if (!completeOk) {
      if (!mounted) return;
      setState(() => _completing = false);
      Fluttertoast.showToast(msg: complete?['message']?.toString() ?? "Could not complete trip");
      return;
    }

    // Mark cash collected (COD). Non-fatal if it fails — trip is already done.
    await _apiService.collectCash(widget.bookingId);

    if (!mounted) return;
    setState(() => _completing = false);

    Fluttertoast.showToast(msg: 'Trip completed & cash collected');

    // Pass the completed booking so the sheet shows the REAL fare breakdown.
    final bookingData = complete['data'];
    await showFareCalculationSheet(
      context,
      booking: bookingData is Map<String, dynamic> ? bookingData : null,
    );

    // Trip is done — return to the dashboard (clears the trip screens).
    if (!mounted) return;
    replaceRoute(context, const TechnicianDashboard());
  }

  @override
  Widget build(BuildContext context) {

    const Color cardBorder = Color(0xFFE6EEF2);
    const Color darkBlue = Color(0xFF14233B);
    const Color buttonGreen = Color(0xFFBFD87D);


    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // for Android
      statusBarBrightness: Brightness.dark, // for iOS
    )
    );

    return Scaffold(
      backgroundColor: HexColor('#F0F5FF'),
      body: Column(
        children: [


        Container(
        height: 110,
        width: MediaQuery.of(context).size.width,
        decoration:  BoxDecoration(
            color: AppColors.appColor,
        ),
        child: Container(
          padding: const EdgeInsets.only(top: 50),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              InkWell(
                onTap: ()
                {
                  Navigator.pop(context);
                },
                child: Container(
                  padding: EdgeInsets.only(left: 16),
                  width: 40,
                  height: 35,
                  alignment: Alignment.center,
                  child: Image.asset("assets/back_arrow.png", color: Colors.white,),
                ),
              ),

              SizedBox(width: 8,),

              Text(
                "Summary",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),

              Spacer(),

            ],
          ),
        ),
      ),

          // Top green section
          Container(
            width: double.infinity,
            color: HexColor("#08875D"),
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                const Text(
                  "Amount to be Collected",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 6),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      _collectAmount.isNotEmpty ? "₹$_collectAmount" : "₹--",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(
                      Icons.info_outline,
                      color: Colors.white,
                      size: 22,
                    ),
                  ],
                )
              ],
            ),
          ),


          // Duration Section
          Container(
            width: MediaQuery.of(context).size.width,
            margin: const EdgeInsets.only(top: 16, bottom: 16, left: 30, right: 30),
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: HexColor("#2F6FED")),
            ),
            child:  Column(
              children: [
                Text(
                  "DURATION OF USE",
                  style: TextStyle(
                    color: HexColor("#2F6FED"),
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  _tripDuration,
                  style: TextStyle(
                    color: HexColor("#2F6FED"),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),



          const Text(
            "Customer",
            style: TextStyle(
              color: darkBlue,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            _customerName,
            style: const TextStyle(
              color: darkBlue,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _customerPhone.isNotEmpty ? _customerPhone : "Contact unavailable",
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),

          Spacer(),


          Container(
            color: Colors.white,
            child: Column(
              children: [

                const SizedBox(height: 16),

                Row(
                  children: [
                    SizedBox(width: 20,),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          if (_customerPhone.isEmpty) {
                            Fluttertoast.showToast(msg: 'Customer number unavailable');
                            return;
                          }
                          final uri = Uri.parse('tel:$_customerPhone');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri);
                          }
                        },
                        child: Container(
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cardBorder),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.phone_in_talk, color: AppColors.greenColor, size: 19,),
                              SizedBox(width: 6),
                              Text('contact'.tr, style: TextStyle(color: AppColors.greenColor)),
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
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cardBorder),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset("assets/raise_ticket_icon.png", height: 20,),
                              SizedBox(width: 8),
                              Text('raise_ticket'.tr, style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 20,),
                  ],
                ),

                const SizedBox(height: 16),

                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20),
                  child: SliderButtonWidget(
                    text: _completing ? "Completing..." : "Collected Cash",
                    arrowColor: AppColors.appColor,
                    backgroundColor: AppColors.appColor,
                    onTap: _completing ? null : _completeAndCollect,
                  ),
                ),
              ],
            ),
          ),


          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
