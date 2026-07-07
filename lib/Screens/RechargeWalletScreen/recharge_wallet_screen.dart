import 'dart:convert';
import 'package:movezy_driver_app/ApiUrls/api_urls.dart';
import 'package:movezy_driver_app/CommonWidgets/app_bar.dart';
import 'package:movezy_driver_app/Utils/PrefsManager/prefs_manager.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class RechargeScreen extends StatefulWidget {
  const RechargeScreen({super.key});

  @override
  State<RechargeScreen> createState() => _RechargeScreenState();
}

class _RechargeScreenState extends State<RechargeScreen> {
  final TextEditingController _controller = TextEditingController(text: '500');
  final List<int> amounts = [250, 500, 750, 1000];
  int selectedAmount = 500;
  double _balance = 0;
  bool _loadingBalance = true;
  bool _recharging = false;

  late Razorpay _razorpay;
  String? _pendingOrderId;
  double _pendingAmount = 0;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _fetchBalance();
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _fetchBalance() async {
    try {
      final response = await http.get(
        Uri.parse(ApiUrls.driverWalletUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Prefs.accessToken}',
        },
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body['data'] ?? body;
        setState(() {
          _balance = (data['balance'] ?? 0).toDouble();
          _loadingBalance = false;
        });
      } else {
        setState(() => _loadingBalance = false);
      }
    } catch (e) {
      setState(() => _loadingBalance = false);
    }
  }

  /// Step 1: create a real Razorpay order on the backend, then open checkout.
  /// The wallet is credited only after server-side verification (step 2).
  Future<void> _recharge() async {
    if (selectedAmount <= 0) return;
    setState(() => _recharging = true);
    try {
      final response = await http.post(
        Uri.parse(ApiUrls.driverWalletRechargeUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Prefs.accessToken}',
        },
        body: jsonEncode({'amount': selectedAmount}),
      );
      final body = jsonDecode(response.body);
      final data = body['rData'] ?? body['data'] ?? body;

      if (response.statusCode == 200 && data['orderId'] != null) {
        _pendingOrderId = data['orderId'];
        _pendingAmount = selectedAmount.toDouble();
        final options = {
          'key': data['razorpayKeyId'] ?? '',
          'amount': ((data['amount'] ?? selectedAmount) * 100).toInt(),
          'currency': data['currency'] ?? 'INR',
          'order_id': data['orderId'],
          'name': 'Movezy Wallet',
          'description': 'Wallet Recharge',
          'prefill': {'contact': Prefs.mobile_number, 'email': ''},
          'theme': {'color': '#FF6200'},
        };
        _razorpay.open(options);
      } else {
        setState(() => _recharging = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('recharge_failed'.tr), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      setState(() => _recharging = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recharge failed. Please try again.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Step 2: verify the payment server-side; the backend credits on success.
  void _onPaymentSuccess(PaymentSuccessResponse response) async {
    try {
      final res = await http.post(
        Uri.parse(ApiUrls.driverWalletRechargeVerifyUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Prefs.accessToken}',
        },
        body: jsonEncode({
          'orderId': _pendingOrderId ?? response.orderId ?? '',
          'paymentId': response.paymentId ?? '',
          'signature': response.signature ?? '',
          'amount': _pendingAmount,
        }),
      );
      final body = jsonDecode(res.body);
      final data = body['rData'] ?? body['data'] ?? body;
      final ok = res.statusCode == 200 && (data['balance'] != null);

      if (!mounted) return;
      setState(() {
        _recharging = false;
        if (ok) _balance = (data['balance'] ?? _balance).toDouble();
      });
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('wallet_recharged'.tr), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'recharge_failed'.tr} Contact support if money was deducted.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _recharging = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification failed. Contact support if money was deducted.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _onPaymentError(PaymentFailureResponse response) {
    if (mounted) {
      setState(() => _recharging = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${'recharge_failed'.tr} ${response.message ?? ""}'), backgroundColor: Colors.red),
      );
    }
  }

  void _showWhyRechargeInfo() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.appColor, size: 24),
                const SizedBox(width: 10),
                Text(
                  'why_recharge_title'.tr,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Your wallet balance is used to:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            _infoPoint('Pay platform commission fees'),
            _infoPoint('Cover insurance and safety deposits'),
            _infoPoint('Ensure uninterrupted booking acceptance'),
            _infoPoint('Access premium features and priority booking'),
            const SizedBox(height: 16),
            const Text(
              'Maintaining a minimum balance ensures you can accept bookings without interruption.',
              style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.5),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(sheetContext),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.appColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('got_it'.tr,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _infoPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, color: AppColors.appColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 13, height: 1.4)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: Column(
        children: [
          commonAppBar(
            height: 100,
            context: context,
            child: Container(
              padding: const EdgeInsets.only(top: 50),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.only(left: 16),
                      width: 40,
                      height: 35,
                      alignment: Alignment.center,
                      child: Image.asset("assets/back_arrow.png",
                          color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "Recharge Wallet",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: _showWhyRechargeInfo,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            'why_recharge'.tr,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
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

          // Top balance section
          Container(
            color: Colors.white,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              children: [
                const Text(
                  'Available Balance',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF4B5563),
                  ),
                ),
                const SizedBox(height: 4),
                _loadingBalance
                    ? const SizedBox(
                        height: 30,
                        width: 30,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(
                        '₹${NumberFormat('#,##0.00').format(_balance)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
              ],
            ),
          ),

          const Spacer(),

          // Middle input section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    '₹',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(width: 5),
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _controller,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.start,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (val) {
                        final value = int.tryParse(val) ?? 0;
                        setState(() => selectedAmount = value);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          const Spacer(),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: amounts.map((amt) {
                final isSelected = selectedAmount == amt;
                return GestureDetector(
                  onTap: () {
                    _controller.text = amt.toString();
                    setState(() => selectedAmount = amt);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 7),
                    padding: const EdgeInsets.only(left: 18, right: 18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.appColor
                            : const Color(0xFFE5EAF0),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '₹$amt',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? AppColors.appColor
                              : const Color(0xFF111827),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 17),

          // Recharge Now Button
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, 0, 16, 20 + MediaQuery.of(context).padding.bottom),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _recharging ? null : _recharge,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.appColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _recharging
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text(
                        'Recharge Now',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
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
