import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:movezy_driver_app/AppNavigation/app_navigation.dart';
import 'package:movezy_driver_app/CommonWidgets/app_bar.dart';
import 'package:movezy_driver_app/CommonWidgets/button_widget.dart';
import 'package:movezy_driver_app/Screens/LoginScreen/login_screen.dart';
import 'package:movezy_driver_app/Services/account_service.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';
import 'package:movezy_driver_app/Utils/Auth/driver_logout.dart';
import 'package:movezy_driver_app/Utils/CustomToast/custome_toast.dart';

const _red = Color(0xFFE02D3C);
const _ink = Color(0xFF14233B);
const _muted = Color(0xFF6B7A90);

/// "Delete my account", required by both app stores. Explains the 30-day
/// window, shows what's in the way (a live trip, unpaid earnings, a payout in
/// progress) and any wallet money that would be lost, then schedules the
/// deletion and signs out.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  DeletionCheck? _check;
  bool _loading = true;
  bool _failed = false;
  bool _ackMoney = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    final check = await AccountService.deletionCheck();
    if (!mounted) return;
    setState(() {
      _check = check;
      _failed = check == null;
      _loading = false;
    });
  }

  bool get _hasMoney => (_check?.walletBalance ?? 0) > 0;

  bool get _canDelete =>
      _check != null &&
      _check!.blockers.isEmpty &&
      (!_hasMoney || _ackMoney) &&
      !_deleting;

  String get _days => '${_check?.graceDays ?? 30}';

  Future<void> _confirmAndDelete() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('delete_confirm_title'.tr,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        content: Text(
          'delete_confirm_body'.trParams({'days': _days}),
          style: const TextStyle(fontSize: 13.5, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('keep_account'.tr, style: const TextStyle(color: _muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('delete_action'.tr,
                style: const TextStyle(color: _red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;

    setState(() => _deleting = true);
    final (ok, message) = await AccountService.requestDeletion();
    if (!mounted) return;
    showCustomToast(context, message);
    if (ok) {
      // Same routine as Logout: stops GPS/socket, goes offline, clears the
      // session and the push token.
      await performDriverLogout();
      if (!mounted) return;
      replaceRoute(context, LoginScreen());
    } else {
      setState(() => _deleting = false);
      _load(); // a trip may have started meanwhile; show why
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          commonAppBar(
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
                      width: 40,
                      height: 35,
                      alignment: Alignment.center,
                      child: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    ),
                  ),
                  Text(
                    'delete_account'.tr,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: AppColors.appColor))
                : _failed
                    ? _retry()
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                        children: [
                          Text(
                            'delete_what_happens'.tr,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700, color: _ink),
                          ),
                          const SizedBox(height: 14),
                          _point(Icons.logout, 'delete_point_signout'.tr),
                          _point(Icons.undo, 'delete_point_undo'.trParams({'days': _days})),
                          _point(Icons.delete_outline,
                              'delete_point_wipe'.trParams({'days': _days})),
                          _point(Icons.receipt_long_outlined, 'delete_point_records'.tr),
                          if (_check!.blockers.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _box(
                              color: const Color(0xFFFDECEC),
                              border: _red.withValues(alpha: 0.35),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('delete_blocked_title'.tr,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700, color: _red)),
                                  const SizedBox(height: 6),
                                  for (final b in _check!.blockers)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(b,
                                          style: const TextStyle(
                                              fontSize: 13, height: 1.4, color: _ink)),
                                    ),
                                ],
                              ),
                            ),
                          ],
                          if (_check!.blockers.isEmpty && _hasMoney) ...[
                            const SizedBox(height: 8),
                            _box(
                              color: const Color(0xFFFCEDE4),
                              border: AppColors.appColor.withValues(alpha: 0.4),
                              child: CheckboxListTile(
                                value: _ackMoney,
                                onChanged: (v) => setState(() => _ackMoney = v ?? false),
                                activeColor: AppColors.appColor,
                                contentPadding: EdgeInsets.zero,
                                controlAffinity: ListTileControlAffinity.leading,
                                title: Text(
                                  'delete_money_ack'.trParams({
                                    'amount': _check!.walletBalance.toStringAsFixed(2),
                                  }),
                                  style: const TextStyle(
                                      fontSize: 13, height: 1.4, color: _ink),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          Opacity(
                            opacity: _canDelete ? 1 : 0.45,
                            child: ButtonWidget(
                              text: _deleting ? 'deleting'.tr : 'delete_my_account'.tr,
                              backgroundColor: _red,
                              onTap: _canDelete ? _confirmAndDelete : null,
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _point(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFFFCEDE4),
              child: Icon(icon, size: 17, color: AppColors.appColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(text,
                    style: const TextStyle(fontSize: 13.5, height: 1.45, color: _ink)),
              ),
            ),
          ],
        ),
      );

  Widget _box({required Color color, required Color border, required Widget child}) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: child,
      );

  Widget _retry() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('account_load_failed'.tr, style: const TextStyle(color: _muted)),
            TextButton(
              onPressed: _load,
              child: Text('retry'.tr, style: TextStyle(color: AppColors.appColor)),
            ),
          ],
        ),
      );
}
