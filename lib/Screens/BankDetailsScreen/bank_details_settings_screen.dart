import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
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
///
/// Once an account is on file, the server no longer lets this PUT overwrite it
/// (a self-served swap is how a stolen phone redirects payouts) — it records a
/// bankDetailsUpdateRequest an admin approves or rejects. The screen must not
/// pretend such a submission applied: the button reads "Request To Update", a
/// "requested" response keeps the driver here with a pending banner instead of
/// popping with "saved", and GET's `updateRequest` renders the same banner (or
/// the rejection, with the admin's reason) on the next visit.
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

  /// Whether an account number is already on file — this decides whether the
  /// PUT writes directly ("Submit") or files an approval request ("Request To
  /// Update"), so the button must say which one the driver is about to do.
  bool _hasExistingAccount = false;

  /// The server's bankDetailsUpdateRequest, verbatim (status PENDING /
  /// APPROVED / REJECTED + requestedAt / decidedAt / rejectionReason). null
  /// when the server sent none — the banner then simply doesn't render; no
  /// status is ever synthesised client-side.
  Map<String, dynamic>? _updateRequest;

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
          _hasExistingAccount =
              (bank['accountNumber'] ?? '').toString().trim().isNotEmpty;
        }
        // Rides alongside bankDetails so a request filed on a previous visit
        // (or from another device) is visible the moment the screen opens.
        final reqRaw = data is Map ? data['updateRequest'] : null;
        _updateRequest =
            reqRaw is Map ? Map<String, dynamic>.from(reqRaw) : null;
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
        // The PUT has two success outcomes now: a direct write (first-time
        // details) or a PENDING approval request (an account was already on
        // file). Telling a driver whose money-path change still needs an admin
        // "saved" — and popping — would be a lie, so the two are told apart by
        // the response itself.
        Map<String, dynamic> body = const {};
        try {
          final decoded = jsonDecode(res.body);
          if (decoded is Map) body = Map<String, dynamic>.from(decoded);
        } catch (_) {
          // Non-JSON 200 — fall through to the direct-write handling, which is
          // all pre-request servers ever did.
        }
        final data = body['data'];
        final reqRaw = data is Map ? data['updateRequest'] : null;
        final requested = body['message'] == 'bank_update_requested' ||
            (reqRaw is Map &&
                (reqRaw['status'] ?? '').toString().toUpperCase() == 'PENDING');
        if (requested) {
          setState(() {
            _hasExistingAccount = true;
            _updateRequest = reqRaw is Map
                ? Map<String, dynamic>.from(reqRaw)
                // The server said "requested" without echoing the request row;
                // PENDING is that message's meaning, not a guess.
                : {'status': 'PENDING'};
          });
          _snack('Update requested — awaiting approval');
        } else {
          _snack('Bank details saved');
          Navigator.pop(context, true);
        }
      } else {
        // Surface the server's own reason when it sent one (the envelope's
        // `message`), instead of a blind generic.
        String msg = 'Could not save bank details. Try again.';
        try {
          final decoded = jsonDecode(res.body);
          if (decoded is Map &&
              (decoded['message'] ?? '').toString().trim().isNotEmpty) {
            msg = decoded['message'].toString();
          }
        } catch (_) {}
        _snack(msg, isError: true);
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

  String? _fmtDate(dynamic raw) {
    final parsed = DateTime.tryParse(raw?.toString() ?? '');
    return parsed == null
        ? null
        : DateFormat('MMM d, yyyy').format(parsed.toLocal());
  }

  /// Display-only masking for the banner; the request itself keeps the full
  /// number.
  String _last4(String value) =>
      value.length <= 4 ? value : value.substring(value.length - 4);

  /// The lifecycle of the driver's change request, straight off the server.
  /// Rendered only from a status the server actually sent — inventing an
  /// approval state on a payout account is exactly what this flow exists to
  /// prevent.
  Widget _requestBanner() {
    final request = _updateRequest;
    if (request == null) return const SizedBox.shrink();

    final status = (request['status'] ?? '').toString().toUpperCase();
    final requestedAt = _fmtDate(request['requestedAt']);
    final decidedAt = _fmtDate(request['decidedAt']);

    Color bg;
    Color border;
    Color fg;
    IconData icon;
    String title;
    final lines = <String>[];

    switch (status) {
      case 'PENDING':
        bg = const Color(0xFFFFF8E1);
        border = const Color(0xFFFFD54F);
        fg = const Color(0xFF9A6700);
        icon = Icons.hourglass_top_rounded;
        title = 'Update requested — awaiting approval';
        final bank = (request['bankName'] ?? '').toString().trim();
        final acct = (request['accountNumber'] ?? '').toString().trim();
        final what = <String>[
          if (bank.isNotEmpty) bank,
          if (acct.isNotEmpty) 'a/c ····${_last4(acct)}',
        ];
        if (what.isNotEmpty || requestedAt != null) {
          lines.add([
            'Requested',
            if (what.isNotEmpty) what.join(' '),
            if (requestedAt != null) 'on $requestedAt',
          ].join(' '));
        }
        // Both facts matter to the driver: payouts still go to the old
        // account meanwhile, and the server keeps only the latest request.
        lines.add('Your current account stays in use until an admin approves. '
            'Submitting again replaces this request.');
        break;
      case 'REJECTED':
        bg = const Color(0xFFFFEBEE);
        border = const Color(0xFFEF9A9A);
        fg = const Color(0xFFB71C1C);
        icon = Icons.cancel_outlined;
        title = 'Update request rejected';
        final reason = (request['rejectionReason'] ?? '').toString().trim();
        if (reason.isNotEmpty) lines.add('Reason: $reason');
        if (decidedAt != null) lines.add('Decided on $decidedAt');
        lines.add('You can request another update below.');
        break;
      case 'APPROVED':
        bg = const Color(0xFFE8F5E9);
        border = const Color(0xFFA5D6A7);
        fg = const Color(0xFF1B5E20);
        icon = Icons.check_circle_outline;
        title = 'Update request approved';
        if (decidedAt != null) lines.add('Approved on $decidedAt');
        lines.add('The details below are now your account on file.');
        break;
      default:
        // A status this build doesn't know is not guessed at.
        return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                      color: fg, fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
                for (final line in lines) ...[
                  const SizedBox(height: 4),
                  Text(
                    line,
                    style: TextStyle(
                        color: fg.withValues(alpha: 0.85),
                        fontSize: 11.5,
                        height: 1.3),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
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
                // The label is a promise: with an account on file this button
                // files an approval request and changes nothing by itself, so
                // it must not say anything save-shaped.
                text: _saving
                    ? (_hasExistingAccount ? 'Requesting…' : 'Saving…')
                    : (_hasExistingAccount ? 'Request To Update' : 'submit'.tr),
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
                  _requestBanner(),
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
