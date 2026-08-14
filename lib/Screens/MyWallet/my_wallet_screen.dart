import 'dart:convert';
import 'dart:math' as math;
import 'package:movezy_driver_app/ApiUrls/api_urls.dart';
import 'package:movezy_driver_app/AppNavigation/app_navigation.dart';
import 'package:movezy_driver_app/CommonWidgets/app_bar.dart';
import 'package:movezy_driver_app/Screens/BankDetailsScreen/bank_details_settings_screen.dart';
import 'package:movezy_driver_app/Screens/MyWallet/Widgets/wallet_transaction_list.dart';
import 'package:movezy_driver_app/Screens/RechargeWalletScreen/recharge_wallet_screen.dart';
import 'package:movezy_driver_app/Screens/TechnicianDashboard/dashboard_api_service.dart';
import 'package:movezy_driver_app/Screens/TransactionsScreen/transactions_screen.dart';
import 'package:movezy_driver_app/Utils/PrefsManager/prefs_manager.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';

/// The four-action strip under the balance. Darker than the #364B63 disc baked
/// into each action PNG so those discs read as raised buttons on it.
const Color _kActionPanel = Color(0xFF26313E);
const Color _kPageBg = Color(0xFFF4F5F7);

class MyWalletScreen extends StatefulWidget {
  const MyWalletScreen({super.key});

  @override
  State<MyWalletScreen> createState() => _MyWalletScreenState();
}

class _MyWalletScreenState extends State<MyWalletScreen> {
  double _balance = 0;
  List<dynamic> _transactions = [];
  bool _loading = true;

  final DashboardApiService _api = DashboardApiService();
  // Withdrawable earnings info (from /wallet/withdrawal-info).
  double _available = 0;
  // Real earnings: Σ driverEarnings frozen on each COMPLETED booking + awarded
  // incentives, computed server-side. This is the only earnings figure the app
  // can get; there is no per-week earnings endpoint.
  double _lifetimeEarnings = 0;
  double _minWithdrawal = 100;
  bool _hasBankDetails = false;
  bool _submittingWithdrawal = false;

  @override
  void initState() {
    super.initState();
    _fetchWallet();
    _fetchWithdrawalInfo();
  }

  Future<void> _fetchWithdrawalInfo() async {
    final info = await _api.fetchWithdrawalInfo();
    if (info != null && mounted) {
      setState(() {
        _available = (info['available'] ?? 0).toDouble();
        _lifetimeEarnings = (info['lifetimeEarnings'] ?? 0).toDouble();
        _minWithdrawal = (info['minWithdrawal'] ?? 100).toDouble();
        _hasBankDetails = info['hasBankDetails'] == true;
      });
    }
  }

  Future<void> _fetchWallet() async {
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
          _transactions = data['transactions'] ?? [];
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('Error fetching wallet: $e');
      setState(() => _loading = false);
    }
  }

  // A "_weeklyEarnings" getter used to live here, feeding the "This Week's
  // Earnings" label. It summed CREDIT rows of the driver's WALLET — and the
  // only thing that ever credits a driver wallet is the driver's own Razorpay
  // top-up; no trip money is written to it anywhere in the backend. So a real,
  // non-zero number — the driver's own deposits — was displayed as earnings.
  // Real driver earnings live on the booking as driverEarnings, frozen at
  // completion, and reach the app as the server-computed lifetime total from
  // /wallet/withdrawal-info, which is what the card now shows.

  void _showWhyRechargeInfo() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.appColor, size: 24),
                const SizedBox(width: 10),
                // Expanded: bare Row child next to the icon got unbounded width, so a
                // long translated title could never wrap or ellipsize.
                Expanded(
                  child: Text(
                    'why_recharge_title'.tr,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Every one of the four bullets that used to sit here was false, and
            // together they pressured drivers into depositing money:
            //   "Pay platform commission fees"        - commission is taken off
            //      the trip settlement at completion, never from this wallet.
            //   "Cover insurance and safety deposits" - no such mechanism exists.
            //   "Ensure uninterrupted booking acceptance" and the minimum-balance
            //      line - accepting a booking checks driver status, vehicle and
            //      whether a trip is already active. It never checks a balance.
            //   "Access premium features and priority booking" - no such feature.
            // Nothing in the backend debits a driver wallet at all. Only what is
            // actually true is stated here.
            const Text(
              'About your wallet',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            _infoPoint('Your earnings from completed trips are settled here'),
            _infoPoint('You can withdraw your available balance to your registered bank account'),
            const SizedBox(height: 16),
            const Text(
              'Commission is already deducted from each trip before it reaches you — you never pay it from this wallet.',
              style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.5),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.appColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('got_it'.tr, style: const TextStyle(fontWeight: FontWeight.w600)),
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
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, height: 1.4))),
        ],
      ),
    );
  }

  void _openWithdrawSheet() {
    // Refresh the withdrawable figure just before opening so it's current.
    _fetchWithdrawalInfo();

    if (!_hasBankDetails) {
      // Previously this was a dead end: it told the driver to add bank details
      // but gave no way to do so. Now offer to open the bank details screen,
      // and refresh withdrawal info when they return.
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('bank_details'.tr,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          content: Text('add_bank_details_first'.tr),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('cancel'.tr),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await pushTo(context, const BankDetailsSettingsScreen());
                // Re-check bank status after they come back.
                _fetchWithdrawalInfo();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.appColor,
                foregroundColor: Colors.white,
              ),
              child: Text('add_bank_details'.tr),
            ),
          ],
        ),
      );
      return;
    }
    if (_available < _minWithdrawal) {
      _showSnack(
        '${'min_withdrawal_is'.tr} ${walletMoney.format(_minWithdrawal)}',
        isError: true,
      );
      return;
    }

    final amountController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('withdraw'.tr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                    '${'available_to_withdraw'.tr}: ${walletMoney.format(_available)}',
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: false),
                    autofocus: true,
                    decoration: InputDecoration(
                      prefixText: '₹ ',
                      hintText: 'enter_amount'.tr,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: 8),
                  // Quick "withdraw all" chip
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        amountController.text = _available.toStringAsFixed(0);
                        setSheetState(() {});
                      },
                      child: Text('withdraw_all'.tr, style: TextStyle(color: AppColors.appColor, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _submittingWithdrawal
                          ? null
                          : () => _submitWithdrawal(sheetContext, amountController.text),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.appColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _submittingWithdrawal
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text('request_withdrawal'.tr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // The 'withdrawal_note' key this used to render ended with
                  // "usually within 1–2 business days" — the last of the three
                  // payout timings the app quoted (the others were "Next
                  // Payout: Every Monday" on the balance card and a "24-48
                  // hours" line in the FAQ, both already removed). No schedule
                  // or turnaround exists to quote: a withdrawal is a Payout row
                  // that goes PENDING → APPROVED → PAID entirely at an
                  // operator's hand, with nothing timed anywhere in the
                  // backend. What is left states only the part that is true and
                  // says nothing about when.
                  //
                  // Plain English rather than a key because the localisation
                  // files are outside this change and only the English map ever
                  // defined 'withdrawal_note' — a correct English line beats a
                  // localised untruth. Add an honest key and swap it in when
                  // the translations are next touched.
                  Text(
                    'Withdrawals are paid to your registered bank account after your request is approved.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500, height: 1.4),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitWithdrawal(BuildContext sheetContext, String raw) async {
    final amount = double.tryParse(raw.trim());
    if (amount == null || amount <= 0) {
      _showSnack('enter_valid_amount'.tr, isError: true);
      return;
    }
    if (amount < _minWithdrawal) {
      _showSnack('${'min_withdrawal_is'.tr} ${walletMoney.format(_minWithdrawal)}', isError: true);
      return;
    }
    if (amount > _available) {
      _showSnack('insufficient_balance'.tr, isError: true);
      return;
    }

    // Capture the sheet's navigator before the async gap so we don't touch a
    // BuildContext after awaiting.
    final sheetNavigator = Navigator.of(sheetContext);

    setState(() => _submittingWithdrawal = true);
    final result = await _api.requestWithdrawal(amount: amount);
    if (!mounted) return;
    setState(() => _submittingWithdrawal = false);

    // Backend wraps as {code, message, data}; code 1 = success.
    final ok = result != null && (result['code'] == 1);
    final message = (result?['message'] as String?) ??
        (ok ? 'withdrawal_requested'.tr : 'something_went_wrong'.tr);

    if (ok) {
      if (sheetNavigator.canPop()) sheetNavigator.pop();
      _showSnack(message);
      // Refresh available balance + payout-affected wallet view.
      await Future.wait([_fetchWallet(), _fetchWithdrawalInfo()]);
    } else {
      _showSnack(message, isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFC62828) : const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kPageBg,
      body: _loading
          ? Column(
              children: [
                _buildAppBar(),
                Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.appColor))),
              ],
            )
          : RefreshIndicator(
              color: AppColors.appColor,
              onRefresh: () async {
                await Future.wait([_fetchWallet(), _fetchWithdrawalInfo()]);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildAppBar(),
                    _buildBalanceAndActionsCard(),
                    _buildEarningsAndWithdrawCard(),
                    ..._buildTransactionSection(),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAppBar() {
    return commonAppBar(
      height: 100,
      context: context,
      child: Container(
        padding: const EdgeInsets.only(top: 50),
        child: Row(
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
            // Flexible: bare Row child got unbounded width, so at large text scale a
            // long translation squeezed the Spacer to zero and overflowed. Flexible
            // (not Expanded) keeps the title at its intrinsic width when it fits.
            Flexible(
              child: Text(
                'my_wallet'.tr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  /// Orange balance panel and the dark four-action strip, joined inside one
  /// ClipRRect so they read as a single card with no seam between them.
  Widget _buildBalanceAndActionsCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.appColor.withValues(alpha: 0.20),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: AppColors.appColor,
              child: Stack(
                children: [
                  // Decorative only, and painted first so the amount always sits
                  // on top of it. IgnorePointer keeps it out of hit-testing.
                  Positioned(
                    top: -34,
                    right: -26,
                    child: IgnorePointer(
                      child: CustomPaint(
                        size: const Size(190, 150),
                        painter: _SwirlPainter(),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
                    child: Column(
                      children: [
                        // 'total_available_balance' would have read "Total
                        // Available Balance", which is the label the withdrawable
                        // figure in the card below carries — two different numbers
                        // under one name. This is the wallet's own balance, so it
                        // is labelled plainly. English literal because the screen
                        // already mixes literals with .tr and no matching key
                        // exists; add a `total_balance` key when the translation
                        // maps are next touched.
                        const Text(
                          'Total balance',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // FittedBox: a large balance at a big text scale would
                        // otherwise overflow the card width rather than shrink.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            walletMoney.format(_balance),
                            maxLines: 1,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: _kActionPanel,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _walletAction(
                      asset: 'rechage_amount',
                      label: 'Recharge Wallet',
                      onTap: () {
                        pushTo(context, const RechargeScreen()).then((_) {
                          if (mounted) _fetchWallet();
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: _walletAction(
                      asset: 'statement',
                      label: 'Wallet Statement',
                      // Unfiltered, chips left on: this is the one entry point
                      // where the driver is meant to slice the list themselves.
                      onTap: () => pushTo(context, const TransactionsScreen()),
                    ),
                  ),
                  Expanded(
                    child: _walletAction(
                      asset: 'send_amount',
                      label: 'Send Amount',
                      onTap: () => pushTo(
                        context,
                        const TransactionsScreen(
                          initialFilter: TransactionFilter.debit,
                          title: 'Send Amount',
                          showFilters: false,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _walletAction(
                      asset: 'recieve_amount',
                      label: 'Received Amount',
                      onTap: () => pushTo(
                        context,
                        const TransactionsScreen(
                          initialFilter: TransactionFilter.credit,
                          title: 'Received Amount',
                          showFilters: false,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _walletAction({
    required String asset,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      // Transparent Material so the ink splash lands on the dark panel; without
      // it InkWell would splash on the Scaffold's Material, hidden underneath.
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Column(
            children: [
              // Each PNG already *is* the design's dark circular button with a
              // white outline glyph — a #364B63 disc on transparency — so it is
              // dropped straight onto the panel instead of being re-drawn behind.
              Image.asset('assets/$asset.png', width: 46, height: 46),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Not in the design, and deliberately kept: Withdraw creates a real payout
  /// request, and the two figures here are the only real earnings numbers the app
  /// has (server-computed lifetime earnings and the withdrawable balance). The
  /// design's single "Total balance" is the wallet balance above, which is a
  /// different quantity — dropping this block would have removed the withdrawal
  /// feature and the only place a driver can see what they have actually earned.
  Widget _buildEarningsAndWithdrawCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Your earnings',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              // The "About your wallet" sheet used to hang off a help icon on the
              // old Recharge button, which the four-action strip replaced. Moved
              // here so the explanation stays reachable rather than being lost.
              InkWell(
                onTap: _showWhyRechargeInfo,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.help_outline, size: 18, color: Colors.grey.shade400),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _earningsRow('Total earnings (all time)', _lifetimeEarnings),
          const Divider(height: 20, thickness: 1, color: Color(0xFFF0F1F4)),
          _earningsRow('available_to_withdraw'.tr, _available),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _openWithdrawSheet,
              icon: const Icon(Icons.account_balance, size: 19),
              // The button was white-on-indigo before the card turned white, so it
              // takes the brand fill to stay visible.
              label: Text('withdraw'.tr, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.appColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _earningsRow(String label, double amount) {
    return Row(
      children: [
        // Expanded: as a bare Row child the label got unbounded width and could
        // never ellipsize against the amount.
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          walletMoney.format(amount),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1E2430)),
        ),
      ],
    );
  }

  List<Widget> _buildTransactionSection() {
    // /driver/wallet returns the latest rows inline; an empty list means the
    // driver genuinely has no wallet movements, so it says exactly that instead
    // of showing sample rows. The full paginated history is one tap away via
    // Wallet Statement.
    if (_transactions.isEmpty) {
      return [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 24, 16, 0),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              'no_transactions'.tr,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
        ),
      ];
    }
    return buildMonthGroupedTransactions(_transactions);
  }
}

/// The design's faint swirl in the balance card's top-right corner: a few
/// concentric arcs at low opacity. The parent ClipRRect trims whatever runs past
/// the card's rounded corner.
class _SwirlPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.18);

    final center = Offset(size.width * 0.68, size.height * 0.22);
    for (var i = 0; i < 3; i++) {
      final radius = size.width * (0.28 + i * 0.17);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        math.pi * 0.52,
        math.pi * 0.96,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
