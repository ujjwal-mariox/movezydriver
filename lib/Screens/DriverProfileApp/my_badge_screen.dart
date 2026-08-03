import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:http/http.dart' as http;
import 'package:movezy_driver_app/ApiUrls/api_urls.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';
import 'package:movezy_driver_app/Utils/PrefsManager/prefs_manager.dart';

/// The My Badge screen, per the design: purple hero with the trophy, progress
/// card with the orange percentage medallion, category chips coloured per
/// category, the ring-badge grid, and the "Next Badge to Unlock" footer.
///
/// Every badge and unlock state comes from GET /badges — the backend evaluates
/// the full 18-badge catalog against real driver data (trips, earnings,
/// punctuality, referrals, training, KYC…). Nothing here is hardcoded.
class MyBadgeScreen extends StatefulWidget {
  const MyBadgeScreen({super.key});

  @override
  State<MyBadgeScreen> createState() => _MyBadgeScreenState();
}

class _MyBadgeScreenState extends State<MyBadgeScreen> {
  bool _loading = true;
  bool _failed = false;
  List<Map<String, dynamic>> _badges = const [];
  String _activeCategory = '_all';

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
    try {
      final response = await http.get(
        Uri.parse(ApiUrls.driverBadgesUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Prefs.accessToken}',
        },
      ).timeout(const Duration(seconds: 30));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body['data'];
        setState(() {
          _badges = data is List
              ? List<Map<String, dynamic>>.from(data)
              : const [];
          _loading = false;
        });
      } else {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  /// The design's per-category accent: ring, sparkle medallion, active chip.
  Color _categoryColor(String code) {
    switch (code) {
      case 'onboarding':
        return AppColors.appColor; // orange
      case 'milestones':
        return const Color(0xFF3CB882); // green
      case 'performance':
        return const Color(0xFF4D86F3); // blue
      case 'engagement':
        return const Color(0xFFE34C99); // pink
      case 'earnings':
        return const Color(0xFFF9C12E); // yellow
      default:
        return AppColors.appColor;
    }
  }

  String _categoryLabel(String code) {
    switch (code) {
      case 'onboarding':
        return 'cat_onboarding'.tr;
      case 'milestones':
        return 'cat_milestones'.tr;
      case 'performance':
        return 'cat_performance'.tr;
      case 'engagement':
        return 'cat_engagement'.tr;
      case 'earnings':
        return 'cat_earnings'.tr;
      default:
        return code.isEmpty ? code : '${code[0].toUpperCase()}${code.substring(1)}';
    }
  }

  List<String> get _categories {
    const order = [
      'onboarding',
      'milestones',
      'performance',
      'engagement',
      'earnings',
    ];
    final present = _badges
        .map((b) => (b['category'] ?? '').toString())
        .where((c) => c.isNotEmpty)
        .toSet();
    final ordered = [for (final c in order) if (present.contains(c)) c];
    for (final c in present) {
      if (!ordered.contains(c)) ordered.add(c);
    }
    return ordered;
  }

  List<Map<String, dynamic>> get _visibleBadges {
    if (_activeCategory == '_all') return _badges;
    return _badges
        .where((b) => (b['category'] ?? '').toString() == _activeCategory)
        .toList();
  }

  Map<String, dynamic>? get _nextBadge {
    for (final b in _badges) {
      if (b['isUnlocked'] != true) return b;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final earned = _badges.where((b) => b['isUnlocked'] == true).length;
    final total = _badges.length;
    final percent = total > 0 ? (earned / total) : 0.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _header(earned, total, percent),
          Expanded(child: _content()),
        ],
      ),
    );
  }

  // ─────────────────────────── Header ───────────────────────────
  Widget _header(int earned, int total, double percent) {
    return Stack(
      children: [
        // Purple hero behind everything; the orange bar sits on top of it.
        Container(
          height: total > 0 ? 320 : 200,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [HexColor("#6234EC"), HexColor("#C371A4")],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        // Orange app bar with rounded bottom, as designed.
        Container(
          height: MediaQuery.of(context).padding.top + 54,
          decoration: BoxDecoration(
            color: AppColors.appColor,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
          child: Row(
            children: [
              InkWell(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.only(left: 16),
                  width: 44,
                  height: 40,
                  alignment: Alignment.center,
                  child: const Icon(Icons.arrow_back_ios,
                      color: Colors.white, size: 20),
                ),
              ),
              Expanded(
                child: Text(
                  'my_badge'.tr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        // Hero copy + trophy.
        Positioned(
          top: MediaQuery.of(context).padding.top + 66,
          left: 26,
          right: 20,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'My Badges &\nAchievements',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          height: 1.25,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Earn badges as you grow with\nMovezy',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: 12,
                          height: 1.3),
                    ),
                  ],
                ),
              ),
              const Text('🏆', style: TextStyle(fontSize: 74)),
            ],
          ),
        ),
        if (total > 0)
          Positioned(
            top: MediaQuery.of(context).padding.top + 178,
            left: 15,
            right: 15,
            child: _progressCard(earned, total, percent),
          ),
      ],
    );
  }

  Widget _progressCard(int earned, int total, double percent) {
    final remaining = total - earned;
    return Container(
      padding: const EdgeInsets.fromLTRB(21, 20, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 4,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your Progress',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF323232))),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: '$earned',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.appColor)),
                    TextSpan(
                        text: ' of $total Badges Earned',
                        style: const TextStyle(
                            fontSize: 13.5, color: Color(0xFF323232))),
                  ]),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: percent,
                    minHeight: 12,
                    backgroundColor: const Color(0xFFF1F0F3),
                    valueColor: AlwaysStoppedAnimation(AppColors.appColor),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  remaining > 0
                      ? 'Almost there! $remaining more to go'
                      : 'All badges earned — incredible!',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF323232)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // The orange percentage medallion.
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.appColor,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${(percent * 100).round()}%',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── Body ───────────────────────────
  Widget _content() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_failed) {
      return _centered(
        icon: Icons.wifi_off,
        message: 'Could not load your badges.',
        actionLabel: 'Retry',
        onAction: _load,
      );
    }
    if (_badges.isEmpty) {
      return _centered(
        icon: Icons.emoji_events_outlined,
        message: 'no_badges'.tr,
      );
    }
    final cats = _categories;
    final visible = _visibleBadges;
    final next = _nextBadge;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 14, bottom: 24),
        children: [
          if (cats.length > 1)
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 15),
                children: [
                  _tab('_all', 'all_badges'.tr, AppColors.appColor),
                  for (final c in cats)
                    _tab(c, _categoryLabel(c), _categoryColor(c)),
                ],
              ),
            ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 20,
              runSpacing: 22,
              children: [
                for (final badge in visible)
                  SizedBox(
                    width: (MediaQuery.of(context).size.width - 60) / 2,
                    child: _ringBadge(badge),
                  ),
              ],
            ),
          ),
          if (next != null) ...[
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: Column(
                children: [
                  // "Next Badge to Unlock" card, orange-bordered per design.
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.appColor),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.10),
                            blurRadius: 12),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Next Badge to Unlock',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF323232))),
                        const SizedBox(height: 3),
                        Text(
                          '${next['name']} – ${next['description']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF323232)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => _showRequirements(next),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.appColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text('view_requirements'.tr,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tab(String value, String label, Color color) {
    final active = _activeCategory == value;
    return Padding(
      padding: const EdgeInsets.only(right: 11),
      child: InkWell(
        onTap: () => setState(() => _activeCategory = value),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? color : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: active ? color : const Color(0xFFCCCCCC)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: active ? Colors.white : const Color(0xFF4C4C4C),
            ),
          ),
        ),
      ),
    );
  }

  /// One badge as the design draws it: unlocked = category-coloured 118px ring
  /// with the emoji and a sparkle medallion; locked = solid grey disc with a
  /// faint lock. Title and progress line beneath.
  Widget _ringBadge(Map<String, dynamic> badge) {
    final unlocked = badge['isUnlocked'] == true;
    final color = _categoryColor((badge['category'] ?? '').toString());

    return InkWell(
      onTap: () => _showRequirements(badge),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          SizedBox(
            width: 132,
            height: 126,
            child: Stack(
              children: [
                Center(
                  child: Container(
                    width: 118,
                    height: 118,
                    decoration: unlocked
                        ? BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: color, width: 2),
                          )
                        : const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFD9D9D9),
                          ),
                    child: Center(
                      child: unlocked
                          ? Text((badge['icon'] ?? '🏆').toString(),
                              style: const TextStyle(fontSize: 52))
                          : Icon(Icons.lock,
                              size: 44,
                              color:
                                  Colors.black.withValues(alpha: 0.10)),
                    ),
                  ),
                ),
                if (unlocked)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.auto_awesome,
                          color: Colors.white, size: 16),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            (badge['name'] ?? '').toString(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            (unlocked
                    ? (badge['description'] ?? '')
                    : (badge['progressLabel'] ?? badge['description'] ?? ''))
                .toString(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11.5, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  void _showRequirements(Map<String, dynamic> badge) {
    final progress = badge['progress'];
    final target = badge['progressTarget'];
    final hasProgress = progress is num && target is num && target > 0;
    final unlocked = badge['isUnlocked'] == true;
    final color = _categoryColor((badge['category'] ?? '').toString());

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Row(
              children: [
                Text((badge['icon'] ?? '🏆').toString(),
                    style: const TextStyle(fontSize: 34)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    (badge['name'] ?? '').toString(),
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
                if (unlocked)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('Earned',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: color)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'requirements'.tr,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade600),
            ),
            const SizedBox(height: 6),
            Text(
              (badge['description'] ?? '').toString(),
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            if (hasProgress) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: ((progress) / target).clamp(0.0, 1.0),
                  minHeight: 12,
                  backgroundColor: Colors.grey.shade100,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$progress / $target',
                style: const TextStyle(fontSize: 12.5, color: Colors.black54),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _centered({
    required IconData icon,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
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
                child: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
