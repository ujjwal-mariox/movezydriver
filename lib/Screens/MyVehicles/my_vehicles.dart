import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:movezy_driver_app/AppNavigation/app_navigation.dart';
import 'package:movezy_driver_app/CommonWidgets/button_widget.dart';
import 'package:movezy_driver_app/Screens/HelpSupportScreen/help_support_screen.dart';
import 'package:movezy_driver_app/Screens/MyVehicles/Model/driver_details_response.dart';
import 'package:movezy_driver_app/Screens/MyVehicles/my_vehicles_api_service.dart';
import 'package:movezy_driver_app/Screens/VerificationScreen/verification_screen.dart';
import 'package:movezy_driver_app/Screens/on_boarding_screens/add_vehicle_details_screen.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';
import 'package:movezy_driver_app/Utils/PrefsManager/prefs_manager.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class MyVehiclesScreen extends StatefulWidget {
  /// False when an already-onboarded driver opens this from their profile to
  /// add another vehicle. Onboarding routes to VerificationScreen after payment;
  /// an onboarded driver must stay here, since that screen has no way back.
  /// Mirrors the same flag on AddVehicleDetailsScreen.
  final bool isOnboarding;

  const MyVehiclesScreen({super.key, this.isOnboarding = true});

  @override
  State<MyVehiclesScreen> createState() => _MyVehiclesScreenState();
}

class _MyVehiclesScreenState extends State<MyVehiclesScreen> {
  final _apiService = MyVehiclesApiService();
  final _referralController = TextEditingController();
  late Razorpay _razorpay;

  List<VehicleItem> _vehicles = [];
  DriverInfo? _driver;
  bool _isLoading = true;
  List<String> _payingVehicleIds = [];
  String? _applyingReferralVehicleId;
  int _feePerVehicle = 999;

  bool get _isPaying => _payingVehicleIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _fetchVehicles();
  }

  @override
  void dispose() {
    _razorpay.clear();
    _referralController.dispose();
    super.dispose();
  }

  Future<void> _fetchVehicles() async {
    try {
      final vehiclesFuture = _apiService.getMyVehicles();
      final feeFuture = _apiService.getOnboardingFee();

      final res = await vehiclesFuture;
      Map<String, dynamic>? feeData;
      try { feeData = await feeFuture; } catch (_) {}

      if (res.data != null) {
        setState(() {
          _vehicles = res.data!.vehicles ?? [];
          _driver = res.data!.driver;
          if (feeData != null && feeData['amount'] != null) {
            _feePerVehicle = (feeData['amount'] as num).toInt();
          }
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching vehicles: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Get the first unpaid vehicle (for payment/referral actions)
  VehicleItem? get _firstUnpaidVehicle {
    try {
      return _vehicles.firstWhere((v) => v.onboardingFeePaid != true);
    } catch (_) {
      return null;
    }
  }

  /// Calculate total fee for all unpaid vehicles
  int get _totalUnpaidFee {
    int count = _vehicles.where((v) => v.onboardingFeePaid != true).length;
    return count * _feePerVehicle;
  }

  /// Calculate total discount from referrals
  num get _totalDiscount {
    num discount = 0;
    for (var v in _vehicles) {
      if (v.onboardingFeePaid != true && v.referralDiscount != null) {
        discount += v.referralDiscount!;
      }
    }
    return discount;
  }

  /// Net payable amount
  int get _netPayable {
    int net = _totalUnpaidFee - _totalDiscount.toInt();
    return net > 0 ? net : 0;
  }

  bool get _allVehiclesPaid => _vehicles.isNotEmpty && _vehicles.every((v) => v.onboardingFeePaid == true);

  // ─── Payment Flow ───

  Future<void> _initiatePayment() async {
    final unpaidIds = _vehicles
        .where((v) => v.onboardingFeePaid != true && v.id != null)
        .map((v) => v.id!)
        .toList();
    if (unpaidIds.isEmpty) return;

    setState(() => _payingVehicleIds = unpaidIds);

    try {
      final data = await _apiService.initiatePayment(unpaidIds);
      final returnedIds = (data['vehicleIds'] as List?)?.cast<String>();
      if (returnedIds != null && returnedIds.isNotEmpty) {
        _payingVehicleIds = returnedIds;
      }
      final options = {
        'key': data['razorpayKeyId'] ?? '',
        'amount': data['amount'] ?? 0,
        'currency': data['currency'] ?? 'INR',
        'order_id': data['orderId'] ?? '',
        'name': 'Movezy',
        'description': 'joining_fees_info'.tr,
        'prefill': {
          'contact': _driver?.mobileNumber ?? Prefs.mobile_number,
          'email': '',
          'name': _driver?.fullName ?? '',
        },
        'theme': {
          'color': '#FF6200',
        },
      };
      _razorpay.open(options);
    } catch (e) {
      setState(() => _payingVehicleIds = []);
      Fluttertoast.showToast(msg: 'payment_failed'.tr);
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      await _apiService.verifyPayment(
        vehicleIds: _payingVehicleIds,
        paymentId: response.paymentId ?? '',
        orderId: response.orderId ?? '',
        signature: response.signature ?? '',
      );

      Fluttertoast.showToast(msg: 'payment_success'.tr);

      // Refresh list
      await _fetchVehicles();

      // If all vehicles paid, go to verification — but only during onboarding.
      // An onboarded driver stays on this list, where the new vehicle shows its
      // own per-vehicle verification badge.
      if (widget.isOnboarding && _allVehiclesPaid && mounted) {
        replaceRoute(context, VerificationScreen());
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'payment_failed'.tr);
    } finally {
      setState(() => _payingVehicleIds = []);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    setState(() => _payingVehicleIds = []);
    Fluttertoast.showToast(msg: 'payment_failed'.tr);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('External wallet: ${response.walletName}');
  }

  // ─── Referral Flow ───

  Future<void> _applyReferral() async {
    final code = _referralController.text.trim();
    if (code.isEmpty) return;

    final vehicle = _firstUnpaidVehicle;
    if (vehicle == null || vehicle.id == null) return;

    setState(() => _applyingReferralVehicleId = vehicle.id);

    try {
      final data = await _apiService.applyReferral(
        vehicleId: vehicle.id!,
        referralCode: code,
      );

      Fluttertoast.showToast(msg: 'referral_applied'.tr);
      _referralController.clear();
      await _fetchVehicles();
    } catch (e) {
      Fluttertoast.showToast(msg: e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _applyingReferralVehicleId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // ─── App Bar ───
          _buildAppBar(),

          // ─── Info Banner ───
          _buildInfoBanner(),

          // ─── Content ───
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Vehicle cards
                        ..._vehicles.map((v) => _buildVehicleCard(v)),

                        const SizedBox(height: 16),

                        // + Add Another Vehicle
                        ButtonWidget(
                          onTap: () async {
                            await pushTo(context, const AddVehicleDetailsScreen(isOnboarding: false));
                            _fetchVehicles();
                          },
                          borderRadius: BorderRadius.circular(8),
                          text: '+ ${'add_another_vehicle'.tr}',
                          textStyle: TextStyle(
                            color: AppColors.appColor,
                            fontWeight: FontWeight.w600,
                          ),
                          backgroundColor: Colors.transparent,
                          border: Border.all(color: AppColors.appColor, width: 1.4),
                        ),

                        const SizedBox(height: 20),

                        // Pay Fees button
                        if (!_allVehiclesPaid)
                          ButtonWidget(
                            onTap: _isPaying ? null : _initiatePayment,
                            borderRadius: BorderRadius.circular(8),
                            text: _isPaying
                                ? '...'
                                : '${'pay_fees'.tr} ₹$_netPayable',
                            backgroundColor: AppColors.appColor,
                          ),

                        if (!_allVehiclesPaid) ...[
                          const SizedBox(height: 20),

                          // One-time fees info
                          Text(
                            'onetime_fees'.tr,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                          ),

                          const SizedBox(height: 24),

                          // ─── Or divider ───
                          Center(
                            child: Text(
                              'or'.tr,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // ─── Referral Code Input ───
                          Container(
                            height: 50,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: HexColor("#BEBEBE"), width: 1.4),
                            ),
                            child: TextField(
                              controller: _referralController,
                              textCapitalization: TextCapitalization.characters,
                              decoration: InputDecoration(
                                hintText: 'enter_referral_code'.tr,
                                hintStyle: TextStyle(
                                  color: HexColor("#BEBEBE"),
                                  fontWeight: FontWeight.w600,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Verify & Onboard button
                          ButtonWidget(
                            onTap: _applyingReferralVehicleId != null ? null : _applyReferral,
                            borderRadius: BorderRadius.circular(8),
                            text: _applyingReferralVehicleId != null
                                ? '...'
                                : 'verify_onboard'.tr,
                            backgroundColor: HexColor('#35B255'),
                          ),

                          const SizedBox(height: 20),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      height: 95,
      padding: const EdgeInsets.only(top: 38),
      color: AppColors.appColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.only(left: 16),
              width: 40,
              height: 35,
              alignment: Alignment.center,
              child: Image.asset("assets/back_arrow.png", color: Colors.white),
            ),
          ),
          const SizedBox(width: 9),
          Text(
            'my_vehicles'.tr,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          InkWell(
            onTap: () => Get.to(() => const HelpSupportScreen()),
            child: Padding(
              padding: const EdgeInsets.only(right: 15),
              child: Text(
                'help'.tr,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      color: HexColor("#FFF2EA"),
      child: Row(
        children: [
          SizedBox(
            height: 28,
            width: 28,
            child: Image.asset("assets/clock_icon.png"),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'joining_fees_info'.tr,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  /// Human wording for a verificationStatus enum.
  String _verificationLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Verified';
      case 'rejected':
        return 'Rejected';
      case 'under_verification':
        return 'Under Verification';
      default:
        return 'Pending';
    }
  }

  Color _verificationColor(String status) {
    switch (status) {
      case 'approved':
        return HexColor('#35B255');
      case 'rejected':
        return HexColor('#EE3E35');
      default:
        return HexColor('#E8A33D');
    }
  }

  /// "Name, Phone" — but only the parts that exist, and empty when neither
  /// does, so the card never shows a stray comma.
  String _assignedDriverLine(VehicleItem vehicle) {
    final parts = [
      (vehicle.assignedDriverName ?? '').trim(),
      (vehicle.assignedDriverPhone ?? '').trim(),
    ].where((p) => p.isNotEmpty);
    return parts.join(', ');
  }

  Widget _buildVehicleCard(VehicleItem vehicle) {
    final isPaid = vehicle.onboardingFeePaid == true;
    final hasDiscount = (vehicle.referralDiscount ?? 0) > 0;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 6,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vehicle number + status badge
          Row(
            children: [
              Expanded(
                child: Text(
                  vehicle.vehicleNumber ?? '',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
              if (isPaid)
                Builder(builder: (_) {
                  // This printed the raw database enum ("under_verification")
                  // in green no matter what it said — so a rejected vehicle
                  // looked approved, and the label read like a bug.
                  final status = (vehicle.verificationStatus ?? 'pending').toLowerCase();
                  final label = _verificationLabel(status);
                  final color = _verificationColor(status);
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  );
                }),
              if (hasDiscount && !isPaid)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: HexColor('#35B255').withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '-₹${vehicle.referralDiscount?.toInt()}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: HexColor('#35B255'),
                    ),
                  ),
                ),
            ],
          ),
          // Driver name + phone.
          // Interpolating both unconditionally printed a bare ", " on every
          // card where no driver is assigned — which is most of them, since
          // assignedDriverName/Phone are optional at onboarding.
          if (_assignedDriverLine(vehicle).isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              _assignedDriverLine(vehicle),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 3),
          ],

          // The "Upto Rs.25000 monthly earnings" line was removed. It was a
          // fixed marketing string printed next to a money icon on each
          // specific vehicle card, so it read as that vehicle's actual
          // earnings. Nothing measures it: bookings do not record which
          // vehicle ran the trip (booking.vehicleNumber is never populated),
          // so real per-vehicle earnings cannot be shown yet.
        ],
      ),
    );
  }
}
