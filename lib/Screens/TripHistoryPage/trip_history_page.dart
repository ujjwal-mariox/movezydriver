import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:movezy_driver_app/ApiUrls/api_urls.dart';
import 'package:movezy_driver_app/AppNavigation/app_navigation.dart';
import 'package:movezy_driver_app/CommonWidgets/app_bar.dart';
import 'package:movezy_driver_app/Screens/TripSummeryPage/trip_summery_page.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';
import 'package:movezy_driver_app/Utils/PrefsManager/prefs_manager.dart';

/// A history tab, and the ONLY booking statuses that tab can ever contain.
///
/// A booking receives its `driverId` in the same write that sets its status to
/// ASSIGNED (booking-dispatch.service.ts `handleDriverAcceptance` and both admin
/// assign paths), and this screen's endpoint queries `{ driverId: <me> }`. So of
/// the eight statuses in the schema enum, DRAFT and SEARCHING can never reach
/// this screen, and CANCELLED can (cancelling keeps `driverId`).
///
/// "Pending" therefore cannot mean what the dashboard calls pending — that is
/// open work with `driverId: null`, which by definition is not this driver's
/// history. Here it means ASSIGNED: the job is this driver's but nothing has
/// happened on it yet. Anything from DRIVER_ARRIVED onward is genuinely under
/// way, so those are "Ongoing".
enum _HistoryFilter {
  all('all', <String>[]),
  completed('completed', <String>['COMPLETED']),
  ongoing('ongoing', <String>['DRIVER_ARRIVED', 'PICKED', 'IN_PROGRESS']),
  pending('pending', <String>['ASSIGNED']),
  cancelled('cancelled', <String>['CANCELLED']);

  const _HistoryFilter(this.labelKey, this.statuses);

  final String labelKey;

  /// Empty means "no status filter at all" (every ride).
  final List<String> statuses;
}

/// One page of the history endpoint.
class _PageResult {
  const _PageResult(this.bookings, this.total);

  final List<dynamic> bookings;
  final int total;
}

class TripHistoryPage extends StatefulWidget {
  const TripHistoryPage({super.key});

  @override
  State<TripHistoryPage> createState() => _TripHistoryPageState();
}

class _TripHistoryPageState extends State<TripHistoryPage> {
  static const int _pageSize = 20;

  // Status colours. Each maps to a filter bucket, so the pill colour and the
  // chip a ride answers to always agree.
  static const Color _blue = Color(0xFF2563EB); // under way
  static const Color _green = Color(0xFF1F8B4C); // completed
  static const Color _amber = Color(0xFFC77700); // accepted, not started
  static const Color _red = Color(0xFFE02D3C); // cancelled
  static const Color _pickupPin = Color(0xFF6C4CE0);
  static const Color _palePeach = Color(0xFFFFEDE0);
  static const Color _ink = Color(0xFF1B1D28);

  List<dynamic> _bookings = [];
  bool _loading = true;
  bool _failed = false;
  int _page = 1;
  int _total = 0;
  bool _loadingMore = false;
  _HistoryFilter _filter = _HistoryFilter.all;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_loadingMore &&
          _canLoadMore) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool get _canLoadMore => _bookings.length < _total;

  /// The chips the design draws. "Cancelled" only has a chip while it is the
  /// active filter — it is reachable from the filter sheet, because cancelled
  /// rides exist in this list and the design has no tab for them.
  List<_HistoryFilter> get _visibleChips => [
        _HistoryFilter.all,
        _HistoryFilter.completed,
        _HistoryFilter.ongoing,
        _HistoryFilter.pending,
        if (_filter == _HistoryFilter.cancelled) _HistoryFilter.cancelled,
      ];

  Future<_PageResult> _fetchPage(String? status, int page) async {
    final uri = Uri.parse(ApiUrls.driverBookingHistoryUrl).replace(
      queryParameters: {
        'page': '$page',
        'limit': '$_pageSize',
        if (status != null) 'status': status,
      },
    );
    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${Prefs.accessToken}',
      },
    );
    if (response.statusCode != 200) {
      throw http.ClientException('history ${response.statusCode}', uri);
    }
    final body = jsonDecode(response.body);
    final data = body is Map ? (body['data'] ?? body) : null;
    final rows = (data is Map ? data['bookings'] : null);
    final list = rows is List ? rows : const <dynamic>[];
    final total = (data is Map ? data['total'] : null);
    return _PageResult(
      List<dynamic>.from(list),
      total is num ? total.toInt() : list.length,
    );
  }

  /// Newest first, matching the server's own `sort({ createdAt: -1 })` so a
  /// merged multi-status tab reads in the same order as a single-status one.
  int _newestFirst(dynamic a, dynamic b) {
    final da = DateTime.tryParse((a['createdAt'] ?? '').toString());
    final db = DateTime.tryParse((b['createdAt'] ?? '').toString());
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return db.compareTo(da);
  }

  Future<void> _load({bool spinner = false}) async {
    if (spinner) {
      setState(() {
        _loading = true;
        _failed = false;
      });
    }
    final statuses = _filter.statuses;
    try {
      List<dynamic> rows;
      int total;
      if (statuses.length <= 1) {
        final res =
            await _fetchPage(statuses.isEmpty ? null : statuses.first, 1);
        rows = res.bookings;
        total = res.total;
      } else {
        // getBookingHistory matches `status` EXACTLY (`query.status = status`),
        // so a tab covering several statuses has to ask once per status and
        // merge. Only "Ongoing" does. The backend refuses to assign a driver a
        // second booking while one is in these states, so the first page of
        // each status is the whole bucket — hence total == rows.length, which
        // also switches off load-more for this tab.
        final pages =
            await Future.wait(statuses.map((s) => _fetchPage(s, 1)));
        rows = pages.expand((p) => p.bookings).toList()..sort(_newestFirst);
        total = rows.length;
      }
      if (!mounted) return;
      setState(() {
        _bookings = rows;
        _total = total;
        _page = 1;
        _loading = false;
        _failed = false;
      });
    } catch (e) {
      debugPrint('Error fetching history: $e');
      if (!mounted) return;
      // A failed request and a genuinely empty history used to render the same
      // "no trip history" line, so a dead network looked like a driver who had
      // never worked. They are separate states now.
      setState(() {
        _bookings = [];
        _total = 0;
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _loadMore() async {
    final statuses = _filter.statuses;
    if (statuses.length > 1) return; // merged tab has no further pages
    setState(() => _loadingMore = true);
    try {
      final nextPage = _page + 1;
      final res = await _fetchPage(
        statuses.isEmpty ? null : statuses.first,
        nextPage,
      );
      if (!mounted) return;
      setState(() {
        _bookings.addAll(res.bookings);
        _total = res.total;
        _page = nextPage;
        _loadingMore = false;
      });
    } catch (e) {
      debugPrint('Error loading more history: $e');
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  void _applyFilter(_HistoryFilter next) {
    if (next == _filter) return;
    // Jump before the list is swapped for the spinner: once it is, the
    // controller has no client to jump.
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    _filter = next;
    _load(spinner: true);
  }

  // ---------------------------------------------------------------- formatting

  double _amount(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatFare(dynamic fare) {
    if (fare == null) return '₹0';
    final val = _amount(fare);
    // Keep the paise when there are any. Driver earnings are the subtotal minus
    // commission and rarely land on a whole rupee; rounding them up overstated
    // what the trip actually paid.
    final pattern = val == val.roundToDouble() ? '#,##0' : '#,##0.00';
    return '₹${NumberFormat(pattern).format(val)}';
  }

  /// "12.4 km · 45 min" — the two figures the design has no room for on the
  /// date line. Dropped entirely rather than printed as "0 km" when absent.
  String _metrics(dynamic km, dynamic minutes) {
    final parts = <String>[];
    if (km is num && km > 0) parts.add('${km.toDouble().toStringAsFixed(1)} km');
    if (minutes is num && minutes > 0) {
      final min = minutes.toInt();
      parts.add(min >= 60 ? '${min ~/ 60}h ${min % 60}m' : '$min min');
    }
    return parts.join(' · ');
  }

  /// "Dec 11, 2025 • 10:30 AM" from the booking's own timestamp.
  String _formatWhen(dynamic raw) {
    final text = (raw ?? '').toString();
    if (text.isEmpty) return '';
    final date = DateTime.tryParse(text)?.toLocal();
    if (date == null) return '';
    return '${DateFormat('MMM d, yyyy').format(date)} • '
        '${DateFormat('hh:mm a').format(date)}';
  }

  /// Human label for the booking's real status.
  ///
  /// The history endpoint returns EVERY booking this driver ever touched —
  /// cancelled ones and the trip currently under way included — and the card
  /// showed none of that, so a cancelled ride looked like a completed, paid one.
  /// The label stays specific ("At pickup", "Picked up") rather than collapsing
  /// to the tab's name; the pill's colour is what ties it to its tab.
  static const Map<String, String> _statusLabels = {
    'DRAFT': 'Scheduled',
    'SEARCHING': 'Searching',
    'ASSIGNED': 'Assigned',
    'DRIVER_ARRIVED': 'At pickup',
    'PICKED': 'Picked up',
    'IN_PROGRESS': 'In progress',
    'COMPLETED': 'Completed',
    'CANCELLED': 'Cancelled',
  };

  String _statusLabel(String status) {
    if (status.isEmpty) return 'Unknown';
    final known = _statusLabels[status];
    if (known != null) return known;
    final words = status.toLowerCase().replaceAll('_', ' ');
    return words[0].toUpperCase() + words.substring(1);
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'COMPLETED':
        return _green;
      case 'CANCELLED':
        return _red;
      case 'ASSIGNED':
        return _amber;
      case 'DRIVER_ARRIVED':
      case 'PICKED':
      case 'IN_PROGRESS':
        return _blue;
      default:
        return Colors.grey.shade600;
    }
  }

  // -------------------------------------------------------------------- layout

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
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
                      child: Image.asset("assets/back_arrow.png",
                          color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('history'.tr,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold)),
                  const Spacer(),
                  InkWell(
                    onTap: _openFilterSheet,
                    child: Container(
                      padding: const EdgeInsets.only(right: 16),
                      width: 48,
                      height: 35,
                      alignment: Alignment.center,
                      child: Image.asset(
                        "assets/Filter.png",
                        width: 20,
                        height: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _filterChips(),
          Expanded(
            // Pull-to-refresh, as the dashboard has: a trip completed while
            // this page sat open otherwise never appeared without re-entering.
            child: _loading
                ? Center(
                    child:
                        CircularProgressIndicator(color: AppColors.appColor))
                : RefreshIndicator(
                    color: AppColors.appColor,
                    onRefresh: _load,
                    child: _failed
                        ? _errorState()
                        : (_bookings.isEmpty ? _emptyState() : _buildList()),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterChips() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
      // Scrolls rather than wraps: the translated labels are much longer in
      // several of the app's languages and a fixed row clipped them.
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: _visibleChips.map(_chip).toList()),
      ),
    );
  }

  Widget _chip(_HistoryFilter filter) {
    final active = filter == _filter;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _applyFilter(filter),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          decoration: BoxDecoration(
            color: active ? AppColors.appColor : _palePeach,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            filter.labelKey.tr,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : AppColors.appColor,
            ),
          ),
        ),
      ),
    );
  }

  /// The header's filter glyph. It exists so the one bucket the design has no
  /// chip for — cancelled rides, which really are in this list — is reachable.
  void _openFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E5EA),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('filters'.tr,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _ink)),
                const SizedBox(height: 8),
                for (final filter in _HistoryFilter.values)
                  InkWell(
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _applyFilter(filter);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Icon(
                            filter == _filter
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            size: 20,
                            color: filter == _filter
                                ? AppColors.appColor
                                : Colors.grey.shade400,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            filter.labelKey.tr,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: filter == _filter
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: filter == _filter ? _ink : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildList() {
    final children = <Widget>[];
    for (int i = 0; i < _bookings.length; i++) {
      children.add(_buildTripCard(_bookings[i]));
      if (i < _bookings.length - 1) children.add(const SizedBox(height: 12));
    }

    if (_loadingMore) {
      children.add(Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
            child: CircularProgressIndicator(color: AppColors.appColor)),
      ));
    }

    return ListView(
      controller: _scrollController,
      // Always scrollable so pull-to-refresh works on a short list too.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      children: children,
    );
  }

  /// No rides. Never a sample row — an empty tab says it is empty.
  Widget _emptyState() {
    final filtered = _filter != _HistoryFilter.all;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 130),
        Center(
          child: Icon(Icons.receipt_long_outlined,
              size: 56, color: Colors.grey.shade400),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            filtered ? 'no_rides_in_filter'.tr : 'no_trip_history'.tr,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: Color(0xFF757E90)),
          ),
        ),
      ],
    );
  }

  Widget _errorState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 130),
        Center(
          child:
              Icon(Icons.cloud_off_rounded, size: 56, color: Colors.grey.shade400),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            'couldnt_load_history'.tr,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: Color(0xFF757E90)),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: TextButton(
            onPressed: () => _load(spinner: true),
            child: Text('retry'.tr,
                style: TextStyle(
                    color: AppColors.appColor, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _buildTripCard(dynamic booking) {
    final pickupAddress = (booking['pickup']?['address'] ?? '').toString();
    final dropAddress = (booking['drop']?['address'] ?? '').toString();
    final metrics = _metrics(booking['distanceKm'], booking['durationMin']);
    final fare = booking['finalFare'] ?? booking['fare'] ?? 0;
    final when = _formatWhen(booking['createdAt'] ?? booking['completedAt']);
    final bookingId = booking['_id'] ?? '';

    final status = (booking['status'] ?? '').toString().toUpperCase();
    final isCompleted = status == 'COMPLETED';
    final isCancelled = status == 'CANCELLED';
    // driverEarnings is the settlement frozen at completion (subtotal minus
    // commission, pre-GST). finalFare is what the CUSTOMER paid — showing that
    // as the driver's take overstates it by roughly a quarter. Older bookings
    // completed before the field existed fall back to the fare, labelled as
    // the fare rather than as earnings.
    final earnings = _amount(booking['driverEarnings']);
    final hasEarnings = isCompleted && earnings > 0;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => pushTo(context, TripSummeryPage(bookingId: bookingId)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pickup + the money. A cancelled trip earned nothing, so it
              // carries no figure at all rather than the customer's fare shown
              // in "earnings" colours.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child:
                        Icon(Icons.location_on, size: 16, color: _pickupPin),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      pickupAddress.isEmpty ? 'Pickup location' : pickupAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                  ),
                  if (!isCancelled) ...[
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatFare(hasEarnings ? earnings : fare),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            // Only a completed trip's money is the driver's.
                            color: isCompleted
                                ? AppColors.appColor
                                : Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          hasEarnings ? 'You earned' : 'Trip fare',
                          style: TextStyle(
                              fontSize: 9.5, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              // Drop, with the trip's distance/duration beside the destination
              // they belong to — the design's date line has no room for them.
              Row(
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      dropAddress.isEmpty ? 'Drop location' : dropAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12.5, color: Colors.grey.shade600),
                    ),
                  ),
                  if (metrics.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(metrics,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ],
              ),
              const SizedBox(height: 11),
              Row(
                children: [
                  Image.asset('assets/calendar_2.png',
                      width: 13, height: 13, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      when,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _statusPill(status),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusPill(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            _statusLabel(status),
            style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}
