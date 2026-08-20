import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:movezy_driver_app/AppNavigation/app_navigation.dart';
import 'package:movezy_driver_app/CommonWidgets/app_bar.dart';
import 'package:movezy_driver_app/Screens/TechnicianDashboard/Model/driver_dashboard_response.dart';
import 'package:movezy_driver_app/Screens/TechnicianDashboard/dashboard_api_service.dart';
import 'package:movezy_driver_app/Screens/TripSummeryPage/trip_summery_page.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';

/// The period the tab row scopes the grid and the recent list to.
enum _Period { today, week, month }

/// Driver Earnings.
///
/// Every figure here comes off a real endpoint the app already calls:
///   • /driver/app/dashboard          → totalEarnings, todaysEarnings,
///                                      todaysServices, completedCount,
///                                      weekEarnings, weekTrips,
///                                      monthEarnings, monthTrips,
///                                      monthlyRevenue[]
///   • /driver/app/incentives         → weekTrips (fallback), incentivesEarned
///   • /wallet/withdrawal-info        → available (earned, not yet paid out)
///   • /bookings/history?status=…     → the completed trips in the list, with
///                                      their real completedAt + driverEarnings
///
/// The weekly earnings total and monthly trip count used to be em dashes
/// because no endpoint served them; the dashboard now aggregates all four
/// week/month figures (Σ driverEarnings — the driver's net, never finalFare).
/// They stay nullable end-to-end so a server that predates them still draws an
/// em dash with the reason, not a fabricated zero. See [_periodEarnings] /
/// [_periodTrips].
class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  final DashboardApiService _api = DashboardApiService();

  /// Whole-rupee display for the headline and the tiles, matching the
  /// dashboard's formatter so the same money reads the same on both screens.
  final NumberFormat _money =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  bool _loading = true;

  DashboardStats? _stats;

  /// /driver/app/incentives. null means the call FAILED — kept distinct from a
  /// zero so a network blip can't be shown to the driver as "no bonuses".
  Map<String, dynamic>? _incentives;

  /// /wallet/withdrawal-info. null likewise means the call failed.
  Map<String, dynamic>? _payout;

  List<Map<String, dynamic>>? _completedTrips;

  _Period _period = _Period.today;

  static const Color _green = Color(0xFF1F8B4C);
  static const Color _blue = Color(0xFF2563EB);
  static const Color _purple = Color(0xFF7C3AED);
  static const Color _pageBg = Color(0xFFF7F8FC);

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// [showLoader] is false for pull-to-refresh: swapping the list out for a
  /// spinner mid-gesture kills the RefreshIndicator that started the reload.
  Future<void> _load({bool showLoader = true}) async {
    if (showLoader && !_loading) setState(() => _loading = true);

    // Four independent reads — fired together so the screen isn't four
    // round-trips deep. Each one degrades on its own: a failed incentives call
    // must not blank out today's earnings.
    final dashboardFuture = _api.fetchDashboard();
    final incentivesFuture = _api.fetchIncentives();
    final payoutFuture = _api.fetchWithdrawalInfo();
    final tripsFuture = _api.fetchCompletedTrips();

    final dashboard = await dashboardFuture;
    final incentives = await incentivesFuture;
    final payout = await payoutFuture;
    final trips = await tripsFuture;

    if (!mounted) return;
    setState(() {
      _loading = false;
      _stats = dashboard?.data?.stats;
      _incentives = incentives;
      _payout = payout;
      // Server pages by createdAt; re-order by real completion time so the
      // "Recent Earnings" list is genuinely most-recently-earned first.
      if (trips == null) {
        _completedTrips = null;
      } else {
        final list = [...trips.bookings];
        list.sort((a, b) {
          final da = _completedAt(a);
          final db = _completedAt(b);
          if (da == null && db == null) return 0;
          if (da == null) return 1;
          if (db == null) return -1;
          return db.compareTo(da);
        });
        _completedTrips = list;
      }
    });
  }

  // ------------------------------ helpers ------------------------------

  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  DateTime? _completedAt(Map<String, dynamic> booking) {
    final raw = booking['completedAt'];
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  /// Per-trip amounts keep their paise. Driver earnings are the subtotal minus
  /// commission and rarely land on a whole rupee; rounding overstates the trip.
  String _exactMoney(double value) {
    final pattern = value == value.roundToDouble() ? '#,##0' : '#,##0.00';
    return '₹${NumberFormat(pattern, 'en_IN').format(value)}';
  }

  DateTime get _startOfToday {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Monday-based, to match the backend's own week (incentive.service's
  /// startOfWeek). A Sunday-based week here would disagree with the weekly
  /// trip count this screen shows next to it.
  DateTime get _startOfWeek {
    final today = _startOfToday;
    return today.subtract(Duration(days: (today.weekday - 1)));
  }

  DateTime get _startOfMonth {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  DateTime get _periodStart => switch (_period) {
        _Period.today => _startOfToday,
        _Period.week => _startOfWeek,
        _Period.month => _startOfMonth,
      };

  String get _periodEarningsLabel => switch (_period) {
        _Period.today => 'todays_earnings'.tr,
        _Period.week => 'this_weeks_earnings'.tr,
        _Period.month => 'this_months_earnings'.tr,
      };

  /// Earnings for the selected period, or null when the server has no such
  /// figure.
  ///
  /// Today  → stats.todaysEarnings (Σ driverEarnings of trips completed since
  ///          midnight, aggregated server-side).
  /// Week   → stats.weekEarnings (Σ driverEarnings since Monday 00:00,
  ///          server-aggregated). Null only on servers that predate the field —
  ///          then the em dash stands, because summing the recent-trips list
  ///          instead would be a partial total (the list is capped and paged
  ///          by createdAt).
  /// Month  → stats.monthEarnings, same basis since the 1st. Older servers
  ///          without it: the monthlyRevenue bucket for the CURRENT month,
  ///          matched by its name rather than taken positionally — the trend is
  ///          eight buckets and a server that ever changed their order would
  ///          otherwise put some other month's total under this label.
  double? get _periodEarnings {
    final s = _stats;
    if (s == null) return null;
    switch (_period) {
      case _Period.today:
        return s.todaysEarnings;
      case _Period.week:
        return s.weekEarnings;
      case _Period.month:
        final direct = s.monthEarnings;
        if (direct != null) return direct;
        // The backend labels each bucket with an en-US short month, so the
        // comparison is pinned to en_US — under a Hindi app locale a
        // device-locale 'MMM' would never match and the tile would read "—".
        final key = DateFormat('MMM', 'en_US').format(DateTime.now());
        for (final point in s.monthlyRevenue) {
          if (point.month == key) return point.amount;
        }
        return null;
    }
  }

  /// Completed-trip count for the selected period, or null when unavailable.
  ///
  /// Today → stats.todaysServices. Week → stats.weekTrips, falling back to
  /// incentives.weekTrips on servers that predate the dashboard aggregate
  /// (both are real, server-counted, Monday-based weeks). Month →
  /// stats.monthTrips; older servers have no per-month count anywhere
  /// (monthlyRevenue carries amounts only), so there it stays an em dash.
  int? get _periodTrips {
    switch (_period) {
      case _Period.today:
        return _stats?.todaysServices;
      case _Period.week:
        final direct = _stats?.weekTrips;
        if (direct != null) return direct;
        final v = _incentives?['weekTrips'];
        return v is num ? v.toInt() : null;
      case _Period.month:
        return _stats?.monthTrips;
    }
  }

  String get _periodTripsCaption => switch (_period) {
        _Period.today => 'Completed today',
        // Null here means both sources came up empty (old server AND a failed
        // /incentives call) — say so rather than letting the em dash read as
        // "you drove nothing".
        _Period.week => _periodTrips == null
            ? 'Could not load this week’s trip count'
            : 'Completed since Monday',
        _Period.month => _periodTrips == null
            ? 'This server does not report a monthly trip count'
            : 'Completed since the 1st',
      };

  String get _periodEarningsCaption => switch (_period) {
        _Period.today => 'Your share of today’s completed trips',
        _Period.week => _periodEarnings == null
            ? 'This server does not total a week’s earnings'
            : 'Your share since Monday',
        _Period.month => DateFormat('MMMM yyyy').format(DateTime.now()),
      };

  /// Completed trips from the fetched page that fall inside the selected
  /// period. A view of real rows — never summed into a period total.
  List<Map<String, dynamic>> get _periodTripRows {
    final all = _completedTrips;
    if (all == null) return const [];
    final start = _periodStart;
    return all.where((b) {
      final at = _completedAt(b);
      return at != null && !at.isBefore(start);
    }).toList();
  }

  // ------------------------------- build -------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
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
                      // Material glyph, not assets/back_arrow.png: that PNG is
                      // white-on-transparent and its shape could not be
                      // verified, so it is not wired on trust.
                      child: const Icon(Icons.arrow_back_ios,
                          color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Earnings',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(color: AppColors.appColor))
                : RefreshIndicator(
                    color: AppColors.appColor,
                    onRefresh: () => _load(showLoader: false),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                      children: _stats == null
                          ? [_dashboardUnavailable()]
                          : [
                              _totalCard(_stats!),
                              const SizedBox(height: 16),
                              _tabRow(),
                              const SizedBox(height: 16),
                              _statGrid(),
                              const SizedBox(height: 22),
                              _sectionDivider('Recent Earnings'),
                              const SizedBox(height: 14),
                              ..._recentRows(),
                            ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _dashboardUnavailable() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
      child: Column(
        children: [
          Icon(Icons.wifi_off, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 14),
          const Text(
            'Could not load your earnings right now.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _load,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.appColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // ----------------------------- total card -----------------------------

  /// The headline.
  ///
  /// Uses stats.totalEarnings — Σ driverEarnings of completed trips — NOT the
  /// withdrawal endpoint's `lifetimeEarnings`, which already has the awarded
  /// bonuses folded in. This screen shows those bonuses in their own tile, so
  /// the wallet's figure here would count them twice.
  Widget _totalCard(DashboardStats stats) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.appColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          children: [
            // Faint decorative swirls from the design. Drawn as translucent
            // rings so they cost nothing and cannot mask the figures.
            Positioned(
              right: -34,
              top: -48,
              child: _swirl(150, 0.10),
            ),
            Positioned(
              right: 44,
              bottom: -66,
              child: _swirl(120, 0.08),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Earnings',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 6),
                        // FittedBox: a seven-figure lifetime total, or a large
                        // system text scale, would otherwise clip.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _money.format(stats.totalEarnings),
                            maxLines: 1,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                height: 1.1),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${stats.completedCount} completed trip'
                          '${stats.completedCount == 1 ? '' : 's'} · all time',
                          maxLines: 2,
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    // No rising-chart artwork ships in assets/, so this is the
                    // Material glyph rather than a lookalike PNG.
                    child: Icon(Icons.trending_up_rounded,
                        color: AppColors.appColor, size: 28),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _swirl(double size, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: opacity),
            width: 18,
          ),
        ),
      );

  // ------------------------------ tab row ------------------------------

  /// Colour-only segmented row, per the design: no pill, no underline.
  Widget _tabRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9EDF3)),
      ),
      child: Row(
        children: [
          _tab('Today', _Period.today),
          _tab('Weekly', _Period.week),
          _tab('Monthly', _Period.month),
        ],
      ),
    );
  }

  Widget _tab(String label, _Period period) {
    final selected = _period == period;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: selected ? null : () => setState(() => _period = period),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.appColor : Colors.grey.shade500,
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------- tiles -------------------------------

  /// 2x2, built as two IntrinsicHeight rows rather than a fixed-aspect
  /// GridView: the captions run to two lines and a large system text scale
  /// would overflow a locked tile height.
  Widget _statGrid() {
    final trips = _periodTrips;
    final earnings = _periodEarnings;

    // Awarded bonus money, from the DriverIncentive ledger (the same figure the
    // Awards screen calls "Incentives Unlocked"). It is real, withdrawable
    // money — not a live sum of trackers that merely read as achieved.
    final incentivesLoaded = _incentives != null;
    final incentives =
        incentivesLoaded ? _toDouble(_incentives!['incentivesEarned']) : null;

    // Earned but not yet in the driver's hands: lifetime earnings minus every
    // payout already requested, approved or paid. Server-computed.
    final payoutLoaded = _payout != null;
    final pending = payoutLoaded ? _toDouble(_payout!['available']) : null;

    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _tile(
                  label: 'Completed Trips',
                  value: trips?.toString(),
                  caption: _periodTripsCaption,
                  icon: Icons.check_circle_outline_rounded,
                  color: _green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _tile(
                  label: _periodEarningsLabel,
                  value: earnings == null ? null : _money.format(earnings),
                  caption: _periodEarningsCaption,
                  icon: Icons.currency_rupee_rounded,
                  color: _blue,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _tile(
                  label: 'Incentives / Bonus',
                  value: incentives == null ? null : _money.format(incentives),
                  caption: incentivesLoaded
                      ? 'Bonuses awarded to you, all time'
                      : 'Could not load your bonuses',
                  icon: Icons.card_giftcard_rounded,
                  color: _purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _tile(
                  label: 'Pending Amount',
                  value: pending == null ? null : _money.format(pending),
                  caption: payoutLoaded
                      ? 'Earned, not yet paid out'
                      : 'Could not load your payout balance',
                  icon: Icons.schedule_rounded,
                  color: AppColors.appColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// One stat tile. A null [value] renders an em dash, never a placeholder
  /// number — the caption then has to say why the figure is missing.
  Widget _tile({
    required String label,
    required String? value,
    required String caption,
    required IconData icon,
    required Color color,
  }) {
    final missing = value == null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9EDF3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value ?? '—',
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: missing ? Colors.grey.shade400 : Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  caption,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 10,
                      height: 1.25,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Pastel rounded square from the design. No asset in the repo matches
          // these four icons, so they are Material glyphs on a tinted square.
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
        ],
      ),
    );
  }

  // --------------------------- recent earnings ---------------------------

  Widget _sectionDivider(String text) {
    return Row(
      children: [
        const Expanded(
          child: Divider(color: Color(0xFFE2E5EA), thickness: 1, endIndent: 10),
        ),
        Text(
          text,
          style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF757E90)),
        ),
        const Expanded(
          child: Divider(color: Color(0xFFE2E5EA), thickness: 1, indent: 10),
        ),
      ],
    );
  }

  String get _periodEmptyText => switch (_period) {
        _Period.today => 'No trips completed today yet.',
        _Period.week => 'No trips completed since Monday.',
        _Period.month => 'No trips completed this month.',
      };

  List<Widget> _recentRows() {
    if (_completedTrips == null) {
      return [
        _listMessage(
          Icons.wifi_off,
          'Could not load your completed trips.',
          action: 'Retry',
        ),
      ];
    }
    final rows = _periodTripRows;
    if (rows.isEmpty) {
      return [_listMessage(Icons.receipt_long_outlined, _periodEmptyText)];
    }
    return [
      for (int i = 0; i < rows.length; i++) ...[
        _tripRow(rows[i]),
        if (i < rows.length - 1) const SizedBox(height: 10),
      ],
    ];
  }

  Widget _listMessage(IconData icon, String message, {String? action}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
      child: Column(
        children: [
          Icon(icon, size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, color: Colors.black54),
          ),
          if (action != null) ...[
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: _load,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.appColor,
                side: BorderSide(color: AppColors.appColor),
              ),
              child: Text(action),
            ),
          ],
        ],
      ),
    );
  }

  /// One completed trip: its real completion timestamp and the driver's real
  /// per-trip earnings. `driverEarnings` only — finalFare is what the CUSTOMER
  /// paid and is roughly a quarter larger.
  Widget _tripRow(Map<String, dynamic> booking) {
    final bookingId = (booking['_id'] ?? '').toString();
    final bookingNumber = (booking['bookingNumber'] ?? '').toString();
    final dropAddress = (booking['drop'] is Map
            ? (booking['drop'] as Map)['address']
            : null)
        ?.toString();
    final at = _completedAt(booking);
    final earnings = _toDouble(booking['driverEarnings']);

    final title = bookingNumber.isNotEmpty
        ? 'Trip $bookingNumber'
        : (dropAddress != null && dropAddress.isNotEmpty
            ? dropAddress
            : 'Completed trip');

    // The design's grey line is a date and a time. Both come off completedAt;
    // when the server never stamped one the line is dropped rather than shown
    // as an invented date.
    final subtitle = at == null
        ? ''
        : '${DateFormat('MMM d, yyyy').format(at)} • '
            '${DateFormat('h:mm a').format(at)}';

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: bookingId.isEmpty
          ? null
          : () => pushTo(context, TripSummeryPage(bookingId: bookingId)),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE9EDF3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11.5, color: Colors.grey.shade600),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // A completed trip with no frozen settlement (pre-driverEarnings
            // history) shows an em dash, not the customer's fare in earnings
            // colours.
            Text(
              earnings > 0 ? _exactMoney(earnings) : '—',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: earnings > 0 ? _green : Colors.grey.shade400,
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
