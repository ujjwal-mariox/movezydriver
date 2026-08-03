import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:intl/intl.dart';
import 'package:movezy_driver_app/CommonWidgets/app_bar.dart';
import 'package:movezy_driver_app/Screens/TechnicianDashboard/dashboard_api_service.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';

/// The itemised ledger behind the Awards screen's "Incentives Unlocked"
/// aggregate — every bonus the driver was actually awarded, newest first.
///
/// The /incentives/history endpoint and its copy shipped long ago; only this
/// screen was missing, so the number had no drill-down.
class IncentiveHistoryScreen extends StatefulWidget {
  const IncentiveHistoryScreen({super.key});

  @override
  State<IncentiveHistoryScreen> createState() => _IncentiveHistoryScreenState();
}

class _IncentiveHistoryScreenState extends State<IncentiveHistoryScreen> {
  final DashboardApiService _api = DashboardApiService();

  bool _loading = true;
  bool _failed = false;
  List<Map<String, dynamic>> _items = const [];
  num _total = 0;

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
    final res = await _api.fetchIncentiveHistory();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res == null) {
        // null means the call failed — distinct from an empty history, so the
        // driver sees a retry rather than a misleading "no incentives".
        _failed = true;
      } else {
        _items = res.items;
        _total = res.total;
      }
    });
  }

  /// Each ledger row carries a `type` of daily / weekly / peak.
  ({IconData icon, Color color}) _style(String type) {
    switch (type) {
      case 'weekly':
        return (icon: Icons.emoji_events, color: const Color(0xFFF7C748));
      case 'peak':
        return (icon: Icons.bolt, color: const Color(0xFF2E7D32));
      case 'daily':
      default:
        return (icon: Icons.local_shipping, color: AppColors.appColor);
    }
  }

  String _formatDate(dynamic awardedAt) {
    if (awardedAt is! String || awardedAt.isEmpty) return '';
    final dt = DateTime.tryParse(awardedAt);
    if (dt == null) return '';
    return DateFormat('d MMM yyyy, h:mm a').format(dt.toLocal());
  }

  int _int(dynamic v) {
    if (v is num) return v.round();
    if (v is String) return (double.tryParse(v) ?? 0).round();
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: Column(
        children: [
          // Header — mirrors AwardsScreen's gradient chrome, with the total.
          Stack(
            children: [
              Container(
                height: 190,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [HexColor("#6234EC"), HexColor("#C371A4")],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                ),
              ),
              commonAppBar(
                height: 110,
                context: context,
                child: Container(
                  padding: const EdgeInsets.only(top: 57),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.only(left: 16),
                          width: 40,
                          height: 35,
                          alignment: Alignment.center,
                          child: const Icon(Icons.arrow_back_ios,
                              color: Colors.white),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'incentive_history'.tr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Total-awarded card
              Positioned(
                top: 108,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.appColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.account_balance_wallet,
                            color: AppColors.appColor, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'total_incentives'.tr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '₹${_total.toStringAsFixed(0)}',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.appColor),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 46),

          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_failed) {
      return _CenteredMessage(
        icon: Icons.wifi_off,
        message: 'Could not load your incentive history.',
        actionLabel: 'Retry',
        onAction: _load,
      );
    }
    if (_items.isEmpty) {
      return _CenteredMessage(
        icon: Icons.emoji_events_outlined,
        message: 'no_incentives_yet'.tr,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _tile(_items[i]),
      ),
    );
  }

  Widget _tile(Map<String, dynamic> item) {
    final type = (item['type'] ?? 'daily').toString();
    final s = _style(type);
    final title = (item['title'] ?? '').toString();
    final amount = _int(item['amount']);
    final date = _formatDate(item['awardedAt'] ?? item['createdAt']);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: s.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(s.icon, color: s.color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isNotEmpty ? title : type,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
                if (date.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    date,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black54),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '+₹$amount',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: s.color),
          ),
        ],
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _CenteredMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.appColor,
                  foregroundColor: Colors.white,
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
