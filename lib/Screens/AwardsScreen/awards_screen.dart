import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:movezy_driver_app/CommonWidgets/app_bar.dart';
import 'package:movezy_driver_app/Screens/TechnicianDashboard/dashboard_api_service.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';

class AwardsScreen extends StatefulWidget {
  const AwardsScreen({super.key});

  @override
  State<AwardsScreen> createState() => _AwardsScreenState();
}

class _AwardsScreenState extends State<AwardsScreen> {
  final DashboardApiService _api = DashboardApiService();

  bool _loading = true;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await _api.fetchIncentives();
    if (!mounted) return;
    setState(() {
      _data = res;
      _loading = false;
    });
  }

  double _num(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  int _int(dynamic v) => _num(v).round();

  /// Find a tracker by key from the response.
  Map<String, dynamic>? _tracker(String key) {
    final trackers = _data?['trackers'];
    if (trackers is List) {
      for (final t in trackers) {
        if (t is Map && t['key'] == key) return Map<String, dynamic>.from(t);
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final todayEarnings = _int(_data?['todayEarnings']);
    final rating = _num(_data?['rating']);
    final incentivesEarned = _int(_data?['incentivesEarned']);

    final daily = _tracker('daily');
    final weekly = _tracker('weekly');
    final peak = _tracker('peak');

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Stack(
              children: [
                Container(
                  height: 260,
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
                            width: 40, height: 35,
                            alignment: Alignment.center,
                            child: const Icon(Icons.arrow_back_ios, color: Colors.white),
                          ),
                        ),
                        Text('my_awards'.tr, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
                // Motivational card — real today's earnings + rating
                Positioned(
                  top: 120,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                todayEarnings > 0 ? 'Great job today!' : 'Keep going!',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: HexColor("#6234EC")),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'You earned ₹$todayEarnings today',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.star, size: 14, color: Colors.amber),
                                  const SizedBox(width: 4),
                                  Text(
                                    rating > 0 ? 'Rating: ${rating.toStringAsFixed(1)}' : 'No rating yet',
                                    style: const TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Image.asset('assets/trophy_big.png', width: 72, height: 72, fit: BoxFit.contain),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 80),

            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: CircularProgressIndicator(),
              )
            else if (_data == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                child: Text(
                  'Could not load incentives right now. Pull to refresh later.',
                  style: TextStyle(color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
              )
            else ...[
              // --- DAILY TARGET INCENTIVE (real) ---
              if (daily != null)
                _buildTrackerCard(
                  title: 'Daily Target',
                  subtitle: (daily['remaining'] as num) > 0
                      ? '${daily['remaining']} more trips to earn ₹${daily['reward']} bonus'
                      : '₹${daily['reward']} daily bonus unlocked!',
                  current: _int(daily['current']),
                  target: _int(daily['target']),
                  color: AppColors.appColor,
                  icon: Icons.local_shipping,
                  bonusText: (daily['achieved'] == true) ? '₹${daily['reward']} bonus unlocked!' : null,
                ),

              const SizedBox(height: 12),

              // --- WEEKLY MILESTONE (real) ---
              if (weekly != null)
                _buildTrackerCard(
                  title: 'Weekly Milestone',
                  subtitle: '${weekly['current']}/${weekly['target']} trips completed',
                  current: _int(weekly['current']),
                  target: _int(weekly['target']),
                  color: const Color(0xFFF7C748),
                  icon: Icons.emoji_events,
                  bonusText: (weekly['achieved'] == true) ? '₹${weekly['reward']} bonus unlocked!' : null,
                ),

              const SizedBox(height: 12),

              // --- PEAK HOUR BONUS (real) ---
              if (peak != null)
                _buildTrackerCard(
                  title: 'Peak Hour Bonus',
                  subtitle: '${peak['current']} peak trips today (6-10 AM, 5-9 PM)',
                  current: _int(peak['current']),
                  target: _int(peak['target']),
                  color: const Color(0xFF2E7D32),
                  icon: Icons.bolt,
                  bonusText: (peak['achieved'] == true)
                      ? '₹${peak['reward']} peak bonus unlocked!'
                      : '${peak['remaining']} more for ₹${peak['reward']} extra',
                ),

              const SizedBox(height: 20),

              // --- INCENTIVE SUMMARY (real) ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.appColor.withValues(alpha: 0.1), AppColors.appColor.withValues(alpha: 0.05)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.appColor.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.account_balance_wallet, color: AppColors.appColor, size: 20),
                        const SizedBox(width: 8),
                        Text('incentive_summary'.tr, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _summaryRow('Today\'s Earnings', '₹$todayEarnings'),
                    _summaryRow('Incentives Unlocked', '₹$incentivesEarned'),
                    const Divider(height: 20),
                    _summaryRow('Total (Earnings + Bonus)', '₹${todayEarnings + incentivesEarned}', bold: true),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackerCard({
    required String title,
    required String subtitle,
    required int current,
    required int target,
    required Color color,
    required IconData icon,
    String? bonusText,
  }) {
    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  ],
                ),
              ),
              Text('$current/$target', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
          const SizedBox(height: 14),
          // Big progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 14,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          if (bonusText != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 14),
                const SizedBox(width: 6),
                Text(bonusText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
        ],
      ),
    );
  }
}
