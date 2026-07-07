import 'dart:convert';
import 'package:movezy_driver_app/ApiUrls/api_urls.dart';
import 'package:movezy_driver_app/AppNavigation/app_navigation.dart';
import 'package:movezy_driver_app/CommonWidgets/app_bar.dart';
import 'package:movezy_driver_app/Screens/BankDetailsScreen/bank_details_settings_screen.dart';
import 'package:movezy_driver_app/Screens/RechargeWalletScreen/recharge_wallet_screen.dart';
import 'package:movezy_driver_app/Screens/TechnicianDashboard/dashboard_api_service.dart';
import 'package:movezy_driver_app/Screens/TransactionsScreen/transactions_screen.dart';
import 'package:movezy_driver_app/Utils/PrefsManager/prefs_manager.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:get/get.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';

class MyWalletScreen extends StatefulWidget {
  const MyWalletScreen({super.key});

  @override
  State<MyWalletScreen> createState() => _MyWalletScreenState();
}

class _MyWalletScreenState extends State<MyWalletScreen> {
  double _balance = 0;
  List<dynamic> _transactions = [];
  bool _loading = true;
  final NumberFormat _money = NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 0);

  final DashboardApiService _api = DashboardApiService();
  // Withdrawable earnings info (from /wallet/withdrawal-info).
  double _available = 0;
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

  // Compute this week's earnings from CREDIT transactions
  double get _weeklyEarnings {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartDate = DateTime(weekStart.year, weekStart.month, weekStart.day);
    double total = 0;
    for (final txn in _transactions) {
      if (txn['type'] != 'CREDIT') continue;
      final dateStr = txn['createdAt'] ?? '';
      if (dateStr is String && dateStr.isNotEmpty) {
        final date = DateTime.tryParse(dateStr)?.toLocal();
        if (date != null && date.isAfter(weekStartDate)) {
          total += (txn['amount'] ?? 0).toDouble();
        }
      }
    }
    return total;
  }

  String _formatDescription(dynamic txn) {
    final desc = txn['description'] ?? '';
    if (desc == 'Refund - Trip Issue') return 'Trip Adjustment';
    return desc.isNotEmpty ? desc : (txn['type'] == 'CREDIT' ? 'Credit' : 'Debit');
  }

  String _formatDate(dynamic txn) {
    final dateStr = txn['createdAt'] ?? '';
    if (dateStr is String && dateStr.isNotEmpty) {
      final date = DateTime.tryParse(dateStr)?.toLocal();
      if (date != null) return DateFormat('dd MMM, hh:mm a').format(date);
    }
    return '';
  }

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
                Text('why_recharge_title'.tr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
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
        '${'min_withdrawal_is'.tr} ${_money.format(_minWithdrawal)}',
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
                    '${'available_to_withdraw'.tr}: ${_money.format(_available)}',
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
                  Text(
                    'withdrawal_note'.tr,
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
      _showSnack('${'min_withdrawal_is'.tr} ${_money.format(_minWithdrawal)}', isError: true);
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
      backgroundColor: const Color(0xFFF7F8FC),
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
                  children: [
                    _buildAppBar(),
                    _buildBalanceCard(),
                    const SizedBox(height: 16),
                    _buildQuickActions(),
                    const SizedBox(height: 20),
                    _buildTransactionList(),
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
            Text('my_wallet'.tr, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF283593)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A237E).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Text('total_available_balance'.tr, style: const TextStyle(color: Colors.white60, fontSize: 13)),
          const SizedBox(height: 8),
          Text(
            _money.format(_balance),
            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          // This Week's Earnings
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('this_weeks_earnings'.tr, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                Text(_money.format(_weeklyEarnings), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Available to withdraw (earned from completed trips, minus payouts)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('available_to_withdraw'.tr, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                Text(_money.format(_available), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Next Payout Date placeholder
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('next_payout'.tr, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                Text('every_monday'.tr, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // WITHDRAW BUTTON (big)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _openWithdrawSheet,
              icon: const Icon(Icons.account_balance, size: 20),
              label: Text('withdraw'.tr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1A237E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _actionButton(
              icon: Icons.add_circle_outline,
              label: 'Recharge',
              color: AppColors.appColor,
              onTap: () {
                pushTo(context, RechargeScreen()).then((_) => _fetchWallet());
              },
              showInfo: true,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _actionButton(
              icon: Icons.receipt_long,
              label: 'Transactions',
              color: const Color(0xFF2575FC),
              onTap: () {
                pushTo(context, const TransactionsScreen());
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool showInfo = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: color)),
            if (showInfo) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _showWhyRechargeInfo,
                child: Icon(Icons.help_outline, size: 16, color: Colors.grey.shade400),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionList() {
    if (_transactions.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text('no_transactions'.tr, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('transaction_history'.tr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _transactions.length,
            separatorBuilder: (_, i) => Divider(height: 1, color: Colors.grey.shade100),
            itemBuilder: (_, index) => _buildTransactionTile(_transactions[index]),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(dynamic txn) {
    final type = txn['type'] ?? '';
    final isCredit = type == 'CREDIT';
    final amount = (txn['amount'] ?? 0).toDouble();
    final description = _formatDescription(txn);
    final dateStr = _formatDate(txn);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // Icon
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: isCredit ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: isCredit ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          // Description + date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(description, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                if (dateStr.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(dateStr, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ],
            ),
          ),
          // Amount
          Text(
            "${isCredit ? '+' : '-'} ${_money.format(amount)}",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isCredit ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
            ),
          ),
        ],
      ),
    );
  }
}
