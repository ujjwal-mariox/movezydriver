import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:http/http.dart' as http;
import 'package:movezy_driver_app/ApiUrls/api_urls.dart';
import 'package:movezy_driver_app/CommonWidgets/app_bar.dart';
import 'package:movezy_driver_app/CommonWidgets/button_widget.dart';
import 'package:movezy_driver_app/CommonWidgets/edit_text_controller.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';
import 'package:movezy_driver_app/Utils/PrefsManager/prefs_manager.dart';

/// Settings-context Bank Details screen (distinct from the onboarding
/// `BankDetailsScreen`, which pushes the onboarding VerificationScreen on save).
/// This one:
///   • fetches existing bank details via GET /driver/app/bank-details and
///     prefills the form,
///   • saves via PUT to the same endpoint and stays in settings (pops back),
///   • sends accountHolderName (the onboarding screen never did, so it was
///     always saved empty).
class BankDetailsSettingsScreen extends StatefulWidget {
  const BankDetailsSettingsScreen({super.key});

  @override
  State<BankDetailsSettingsScreen> createState() =>
      _BankDetailsSettingsScreenState();
}

class _BankDetailsSettingsScreenState extends State<BankDetailsSettingsScreen> {
  final _accountHolderController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _ifscController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _isVerified = false;

  @override
  void initState() {
    super.initState();
    _fetchBankDetails();
  }

  @override
  void dispose() {
    _accountHolderController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _ifscController.dispose();
    super.dispose();
  }

  Future<void> _fetchBankDetails() async {
    try {
      final res = await http.get(
        Uri.parse(ApiUrls.driverBankDetailsUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Prefs.accessToken}',
        },
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        // Response is wrapped as { success, data } or { code, message, data }.
        final data = body['data'] ?? body;
        final bank = data is Map ? (data['bankDetails'] ?? data) : null;
        if (bank is Map) {
          _accountHolderController.text =
              (bank['accountHolderName'] ?? '').toString();
          _bankNameController.text = (bank['bankName'] ?? '').toString();
          _accountNumberController.text =
              (bank['accountNumber'] ?? '').toString();
          _ifscController.text = (bank['ifscCode'] ?? '').toString();
          _isVerified = bank['isVerified'] == true;
        }
      }
    } catch (_) {
      // Non-fatal — the form just starts empty.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final accountHolder = _accountHolderController.text.trim();
    final bankName = _bankNameController.text.trim();
    final accountNumber = _accountNumberController.text.trim();
    final ifsc = _ifscController.text.trim();

    if (accountHolder.isEmpty ||
        bankName.isEmpty ||
        accountNumber.isEmpty ||
        ifsc.isEmpty) {
      _snack('Please fill all fields', isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      final res = await http.put(
        Uri.parse(ApiUrls.driverBankDetailsUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Prefs.accessToken}',
        },
        body: jsonEncode({
          'accountHolderName': accountHolder,
          'bankName': bankName,
          'accountNumber': accountNumber,
          'ifscCode': ifsc,
        }),
      );
      final ok = res.statusCode == 200 || res.statusCode == 201;
      if (!mounted) return;
      if (ok) {
        _snack('Bank details saved');
        Navigator.pop(context, true);
      } else {
        _snack('Could not save bank details. Try again.', isError: true);
      }
    } catch (_) {
      if (mounted) _snack('Network error. Try again.', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: Colors.white,
      // top: false — the bar owns only the bottom edge. Without this the box
      // ends at the screen edge and the gesture bar / nav buttons sit on top of
      // "Save", making it untappable. SafeArea reads the real device inset (and
      // correctly reports 0 while the keyboard is up, so the button still rides
      // directly above the keyboard on this form).
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
        // 90, matching the onboarding BankDetailsScreen. At 82 the box was 4px
        // shorter than its children (15 + ButtonWidget's default 56 + 15 = 86),
        // so the Column overflowed and clipped the bottom of the button —
        // on every device, no narrow screen or text scale needed.
        height: 90,
        decoration: BoxDecoration(color: Colors.grey[100]),
        child: Column(
          children: [
            const SizedBox(height: 15),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: ButtonWidget(
                onTap: _saving ? null : _save,
                borderRadius: BorderRadius.circular(8),
                text: _saving ? 'Saving...' : 'save'.tr,
                backgroundColor: AppColors.appColor,
              ),
            ),
            const SizedBox(height: 15),
          ],
        ),
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AppColors.appColor))
          : SingleChildScrollView(
              child: Column(
                children: [
                  commonAppBar(
                    height: 110,
                    context: context,
                    child: Container(
                      padding: const EdgeInsets.only(top: 50),
                      child: Row(
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
                          const SizedBox(width: 6),
                          Text(
                            'bank_details'.tr,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),
                  Image.asset('assets/bank_sc.png',
                      errorBuilder: (_, e, s) => const SizedBox()),
                  if (_isVerified)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.verified, color: Colors.green, size: 18),
                          SizedBox(width: 6),
                          Text('Bank account verified',
                              style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  _sectionHeader('bank_details'.tr),
                  const SizedBox(height: 17),
                  _field(_accountHolderController, 'Account holder name',
                      'Enter account holder name'),
                  const SizedBox(height: 14),
                  _field(_bankNameController, 'bank'.tr, 'select_bank'.tr),
                  const SizedBox(height: 14),
                  _field(_accountNumberController, 'account_number'.tr,
                      'enter_account_number'.tr,
                      keyboard: TextInputType.number),
                  const SizedBox(height: 14),
                  _field(_ifscController, 'ifsc_code'.tr, 'enter_ifsc'.tr,
                      caps: true),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _sectionHeader(String label) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      child: Row(
        children: [
          const SizedBox(width: 16),
          Expanded(child: Container(height: 1, color: HexColor("#E1E6EF"))),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: Colors.black, fontSize: 13)),
          const SizedBox(width: 10),
          Expanded(child: Container(height: 1, color: HexColor("#E1E6EF"))),
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, String hint,
      {TextInputType? keyboard, bool caps = false}) {
    return Container(
      margin: const EdgeInsets.only(left: 15, right: 15),
      child: editTextWidget(
        context: context,
        controller: controller,
        hintText: hint,
        isOptional: false,
        labelText: label,
      ),
    );
  }
}
