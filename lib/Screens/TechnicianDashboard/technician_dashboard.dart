
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:intl/intl.dart';
import 'package:movezy_driver_app/Utils/OfflineStorage/offline_service.dart';
import 'package:movezy_driver_app/Services/booking_alert_service.dart';
import 'package:movezy_driver_app/AppNavigation/app_navigation.dart';
import 'package:movezy_driver_app/Screens/MyProfileScreen/my_profile_screen.dart';
import 'package:movezy_driver_app/Screens/TakeBookingsScreen/take_bookings_screen.dart';
import 'package:movezy_driver_app/Screens/TrainingScreen/training_screen.dart';
import 'package:movezy_driver_app/Screens/BookingsDetailsScreen/bookings_details_screen.dart';
import 'package:movezy_driver_app/Screens/EarningsScreen/earnings_screen.dart';
import 'package:movezy_driver_app/Screens/VerifyRideScreen/verify_ride_screen.dart';
import 'package:movezy_driver_app/Screens/CollectedCaseScreen/collected_case_screen.dart';
import 'package:movezy_driver_app/Screens/TechnicianDashboard/driver_reviews_screen.dart';
import 'package:movezy_driver_app/Screens/TechnicianDashboard/Model/driver_dashboard_response.dart';
import 'package:movezy_driver_app/Screens/TechnicianDashboard/dashboard_api_service.dart';
import 'package:movezy_driver_app/Screens/TripHistoryPage/trip_history_page.dart';
import 'package:movezy_driver_app/Screens/TripSummeryPage/trip_summery_page.dart';
import 'package:movezy_driver_app/Screens/MyWallet/my_wallet_screen.dart';
import 'package:movezy_driver_app/Screens/NotificationsScreen/notifications_screen.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';
import 'package:movezy_driver_app/Utils/CustomToast/custome_toast.dart';
import 'package:movezy_driver_app/Utils/LocationService/location_tracking_service.dart';
import 'package:movezy_driver_app/ApiUrls/api_urls.dart';

class TechnicianDashboard extends StatefulWidget {
  const TechnicianDashboard({super.key});

  @override
  State<TechnicianDashboard> createState() => _TechnicianDashboardState();
}

class _TechnicianDashboardState extends State<TechnicianDashboard> {
  final DashboardApiService _api = DashboardApiService();
  final NumberFormat _money =
      NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 0);

  DriverDashboardData? _dashboard;
  bool _isLoading = true;
  bool _isUpdatingStatus = false;
  String _error = '';

  // What customers said about this driver. The design has a Reviews section
  // here, but nothing ever read the ratings back out of the bookings they were
  // written to, so the driver could never see a single one.

  // Bookings are a tabbed, swipeable carousel in the design: On Going /
  // Pending / Completed, with page dots beneath.
  int _selectedTab = 0;
  int _carouselPage = 0;
  final PageController _pageController =
      PageController(viewportFraction: 0.92);

  @override
  void initState() {
    super.initState();
    _loadDashboard();
    _connectSocket();
    // Pull the admin-configured support number once per session so any call
    // control in the app has a real value to guard on. It stays empty — and
    // every call control stays hidden — if none is configured.
    ApiUrls.loadSupportContact();
  }



  /// True while the incoming-booking alert is on screen, so a burst of
  /// dispatch retries for the same job cannot stack dialogs.


  /// Full-screen offer alert, raised over WHATEVER route is on top.
  ///
  /// Uses the root navigator (Get.dialog), not this screen's context: the
  /// dashboard sits at the bottom of the stack and its own context cannot
  /// present above pushed routes. Fields are read defensively — the payload
  /// is the dispatch service's slim shape (pickup/drop/fare/vehicle), not the
  /// full booking document.
  /// Close the alert, return to the dashboard, and open the offer if it is
  /// still available. The offer can be gone by now (taken, cancelled, timed
  /// out) — say so honestly rather than opening a dead Skip/Accept screen.
  Future<void> _openIncomingBookingAlertTarget(String bookingId) async {
    final pending = _dashboard?.bookings.pending ?? [];
    DashboardBooking? match;
    for (final b in pending) {
      if (b.id == bookingId) {
        match = b;
        break;
      }
    }
    if (match == null && pending.length == 1) {
      // Refresh raced the socket event: a single pending offer is that offer.
      match = pending.first;
    }
    if (match != null) {
      await pushTo(context, TakeBookingsScreen(booking: match));
      _loadDashboard(showLoader: false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('This booking is no longer available.')),
      );
    }
  }

  Future<void> _openIncomingBooking(String bookingId) async {
    BookingAlertService.instance.dismissAlert();
    // Back to the dashboard first so the pending list behind the pushed
    // screen is the fresh one.
    Get.until((route) => route.isFirst);
    // The refresh fired when the socket event arrived; give it a beat if it
    // has not landed yet.
    if ((_dashboard?.bookings.pending ?? []).isEmpty) {
      await _loadDashboard(showLoader: false);
    }
    if (!mounted) return;
    await _openIncomingBookingAlertTarget(bookingId);
  }

  @override
  void dispose() {
    _pageController.dispose();
    // Unsubscribe only. Disconnecting here is what used to kill booking
    // alerts app-wide whenever this screen left the stack.
    final svc = BookingAlertService.instance;
    svc.removeRefreshListener(_onBookingEvent);
    if (identical(svc.openBookingHandler, _openIncomingBooking)) {
      svc.openBookingHandler = null;
    }
    super.dispose();
  }

  /// Subscribe to the app-lifetime booking listener.
  ///
  /// The socket used to be owned by this State, so replacing the dashboard out
  /// of the navigation stack disposed it and the driver silently stopped
  /// receiving offers. BookingAlertService owns the connection now; this
  /// screen only registers what it needs.
  void _connectSocket() {
    final svc = BookingAlertService.instance;
    svc.connect();
    svc.addRefreshListener(_onBookingEvent);
    svc.openBookingHandler = _openIncomingBooking;
  }

  void _onBookingEvent() {
    if (!mounted) return;
    _loadDashboard(showLoader: false);
  }

  Future<void> _loadDashboard({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _isLoading = true;
        _error = '';
      });
    }
    final response = await _api.fetchDashboard();
    if (!mounted) return;
    if (response?.code == 1 && response?.data != null) {
      setState(() {
        _dashboard = response!.data;
        _isLoading = false;
        _error = '';
        // A socket-driven refresh can shrink the active tab's list under a live
        // PageController, leaving the dots pointing at a page that no longer
        // exists. Clamp before the next build reads _carouselPage.
        if (_carouselPage >= _activeList(response.data!.bookings).length) {
          _carouselPage = 0;
          if (_pageController.hasClients) _pageController.jumpToPage(0);
        }
      });

      // Start location tracking if driver is already online
      if (response!.data!.driver.isOnline) {
        LocationTrackingService.instance.startTracking();
      }
      return;
    }
    setState(() {
      _isLoading = false;
      _error = response?.message.isNotEmpty == true
          ? response!.message
          : 'Unable to load dashboard right now.';
    });
  }

  Future<void> _toggleStatus() async {
    final driver = _dashboard?.driver;
    if (driver == null || _isUpdatingStatus) return;
    if (!driver.isOnline && driver.status != 'approved') {
      showCustomToast(context, _approvalMessage(driver));
      return;
    }
    // Training gate: intercept going online when required training is unfinished
    // and offer to start it, rather than firing the toggle and bouncing off the
    // server's 403. Going offline is never gated.
    if (!driver.isOnline && (_dashboard?.training.shouldGate ?? false)) {
      _showTrainingGate();
      return;
    }
    setState(() => _isUpdatingStatus = true);

    // Vibrate on status change
    HapticFeedback.heavyImpact();

    final response = await _api.updateOnlineStatus(isOnline: !driver.isOnline);
    if (!mounted) return;
    setState(() => _isUpdatingStatus = false);
    showCustomToast(
      context,
      response?.message.isNotEmpty == true
          ? response!.message
          : 'Unable to update status.',
    );
    if (response?.code == 1) {
      // Start or stop location tracking based on new status
      if (!driver.isOnline) {
        // Was offline, now going online
        LocationTrackingService.instance.startTracking();
      } else {
        // Was online, now going offline
        LocationTrackingService.instance.stopTracking();
      }
      await _loadDashboard(showLoader: false);
    }
  }

  /// Prompt shown when a driver tries to go online with training unfinished.
  /// "Start Training Now" opens the training library; "Later" dismisses.
  Future<void> _showTrainingGate() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
                Icon(Icons.school_outlined, color: AppColors.appColor, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'complete_training_to_earn'.tr,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'training_gate_body'.tr,
              style: const TextStyle(fontSize: 14, height: 1.4, color: Colors.black54),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(sheetCtx);
                  await pushTo(context, const TrainingScreen());
                  // Re-check the gate after they return from training.
                  await _loadDashboard(showLoader: false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.appColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('start_training_now'.tr,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(sheetCtx),
                child: Text('later'.tr,
                    style: const TextStyle(
                        fontSize: 14, color: Colors.black54)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Home-screen banner mirroring the Figma "Complete Your Training to Start
  /// Earning" card: progress + a Start Training button.
  Widget _trainingGateCard(DashboardTraining training) {
    final total = training.totalRequired;
    final done = training.completedRequired;
    final progress = total > 0 ? (done / total).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFFD6A5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.school_outlined, color: AppColors.appColor, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'complete_training_to_earn'.tr,
                    style: const TextStyle(
                        fontSize: 15.5, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'training_gate_body'.tr,
              style: const TextStyle(fontSize: 13, height: 1.35, color: Colors.black54),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: Colors.white,
                      valueColor: AlwaysStoppedAnimation(AppColors.appColor),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text('$done/$total',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.appColor)),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await pushTo(context, const TrainingScreen());
                  await _loadDashboard(showLoader: false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.appColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('start_training_now'.tr,
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _dashboard == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        bottomNavigationBar: _bottomNav(),
        body: Center(child: CircularProgressIndicator(color: AppColors.appColor)),
      );
    }
    if (_dashboard == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        bottomNavigationBar: _bottomNav(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_error, textAlign: TextAlign.center),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: _loadDashboard,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.appColor,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('retry'.tr),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final driver = _dashboard!.driver;
    final stats = _dashboard!.stats;
    final wallet = _dashboard!.wallet;
    final bookings = _dashboard!.bookings;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      bottomNavigationBar: _bottomNav(),
      body: RefreshIndicator(
        color: AppColors.appColor,
        onRefresh: () async {
          // Reviews are a prominent section now, but _loadReviews used to run
          // only from initState — pull-to-refresh never updated them.
          await Future.wait([
            _loadDashboard(showLoader: false),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _header(driver, wallet),

              if (driver.status != 'approved') ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _approvalBanner(driver),
                ),
              ],

              if (_dashboard!.training.shouldGate) ...[
                const SizedBox(height: 12),
                _trainingGateCard(_dashboard!.training),
              ],

              const SizedBox(height: 20),
              // The client's remove-list for this screen was the graph, the
              // monthly revenue section and the reviews list — the stat tiles
              // stay. Rating is a small corner detail (their instruction),
              // not a tile, and the earnings tile shows TODAY's figure as the
              // doc asks; lifetime detail lives on the Earnings screen.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [_ratingCorner()],
                ),
              ),
              const SizedBox(height: 6),
              _statGrid(stats),
              const SizedBox(height: 24),
              _bookingsSection(stats, bookings),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------- Header ---------------------------
  /// Always-visible connection state (client spec). States are Online /
  /// Offline / Syncing-N: the connectivity plugin reports transport presence,
  /// not signal quality, so no "Weak" state is claimed — that would be a
  /// number the device cannot actually measure.
  Widget _networkChip() {
    final svc = Get.isRegistered<OfflineService>() ? Get.find<OfflineService>() : null;
    if (svc == null) return const SizedBox.shrink();
    return Obx(() {
      final offline = svc.isOffline.value;
      final syncing = svc.isSyncing.value;
      final pending = svc.pendingCount.value;
      // Normal state shows NOTHING (client asked the "Online" bubble removed):
      // the chip appears only when something needs the driver's attention —
      // offline, or an offline-saved trip syncing back.
      if (!offline && !syncing) return const SizedBox.shrink();
      final String label;
      final Color dot;
      if (syncing) {
        label = 'Syncing…';
        dot = Colors.amber;
      } else {
        label = pending > 0 ? 'Offline · $pending saved' : 'Offline';
        dot = Colors.redAccent;
      }
      return Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 7, color: dot),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    });
  }

  /// Avatar, wallet balance and the online/offline toggle in one orange bar,
  /// per the design. Built locally rather than through commonAppBar: that
  /// helper is shared by 24 screens and its Stack child does not expand.
  Widget _header(DashboardDriver driver, DashboardWallet wallet) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          16, MediaQuery.of(context).padding.top + 12, 16, 18),
      decoration: BoxDecoration(
        color: AppColors.appColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => pushTo(context, const MyProfileScreen()),
            borderRadius: BorderRadius.circular(100),
            child: _avatar(driver.profilePhoto),
          ),
          const Spacer(),
          _networkChip(),
          _walletPill(wallet.balance),
          const SizedBox(width: 10),
          _statusButton(driver),
        ],
      ),
    );
  }

  Widget _walletPill(double balance) => InkWell(
        onTap: () async {
          await pushTo(context, const MyWalletScreen());
          _loadDashboard(showLoader: false);
        },
        borderRadius: BorderRadius.circular(50),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/moneys.png', height: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                _money.format(balance),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );

  /// The design's dark button at the right of the header. It replaces the old
  /// full-width 80px toggle; _toggleStatus itself is untouched, so the approval
  /// gate, training gate, haptics and location tracking all still apply.
  Widget _statusButton(DashboardDriver driver) {
    final online = driver.isOnline;
    return InkWell(
      onTap: _isUpdatingStatus ? null : _toggleStatus,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: online ? const Color(0xFF1F8B4C) : const Color(0xFF93000C),
          borderRadius: BorderRadius.circular(10),
        ),
        child: _isUpdatingStatus
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : Text(
                online ? 'Online' : 'Offline',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  // -------------------------- Stat grid --------------------------
  /// Four tiles. "Today's Earnings" leads (the client doc asks for today's
  /// figure, not the lifetime total the tile used to show); the three service
  /// counters stay — the client's remove-list was the graph, monthly revenue
  /// and the reviews list, nothing else. Rating is the corner detail above
  /// the grid, not a tile.
  Widget _statGrid(DashboardStats stats) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.62,
        children: [
          // The only earnings figure on the dashboard, so it is the natural
          // entry point for the full Earnings breakdown.
          _statTile(_money.format(stats.todaysEarnings), "Today's Earnings",
              Icons.account_balance_wallet_outlined, onTap: () async {
            await pushTo(context, const EarningsScreen());
            _loadDashboard(showLoader: false);
          }),
          _statTile('${stats.totalServices}', 'Total Service',
              Icons.receipt_long_outlined),
          _statTile('${stats.upcomingServices}', 'Upcoming Services',
              Icons.event_available_outlined),
          // Zero-padded to two digits, as the design shows ("05").
          _statTile('${stats.todaysServices}'.padLeft(2, '0'),
              'Todays Service', Icons.today_outlined),
        ],
      ),
    );
  }

  Widget _statTile(String value, String label, IconData icon,
      {VoidCallback? onTap}) {
    final tile = Container(
      padding: const EdgeInsets.all(16),
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
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // FittedBox: a big earnings day would otherwise overflow the
                // tile at large text scales.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.appColor),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: AppColors.appColor.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: AppColors.appColor),
          ),
        ],
      ),
    );

    if (onTap == null) return tile;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: tile,
    );
  }

  /// "Rating (small corner)" — a small detail tucked in the corner of the
  /// earnings card rather than a tile of its own, and still the way into the
  /// reviews behind the number.
  Widget _ratingCorner() {
    return InkWell(
      onTap: () => pushTo(context, const DriverReviewsScreen()),
      borderRadius: BorderRadius.circular(50),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rate_rounded,
                size: 14, color: Color(0xFFF5A623)),
            const SizedBox(width: 3),
            Text(
              _dashboard!.driver.rating.toStringAsFixed(1),
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700),
            ),
            Icon(Icons.chevron_right, size: 14, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  // ------------------------ Bookings section ------------------------

  /// Pending offers minus the ones this driver skipped in this session. The
  /// backend's reject only prunes a Redis dispatch set, so an unfiltered
  /// refresh re-offered a job seconds after it was declined.
  List<DashboardBooking> _pendingOffers(DashboardBookings b) =>
      SkippedBookings.filter(b.pending);

  List<DashboardBooking> _activeList(DashboardBookings b) {
    switch (_selectedTab) {
      case 0:
        return b.current == null ? const [] : [b.current!];
      case 1:
        return _pendingOffers(b);
      default:
        return b.completed;
    }
  }

  Widget _bookingsSection(DashboardStats stats, DashboardBookings bookings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text('Recommended Bookings',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              InkWell(
                onTap: () async {
                  await pushTo(context, const TripHistoryPage());
                  _loadDashboard(showLoader: false);
                },
                child: Row(
                  children: [
                    Text('View All',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700)),
                    Icon(Icons.chevron_right,
                        size: 18, color: Colors.grey.shade700),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _tabButton('On Going',
                  _tabCount(stats.onGoingCount, bookings.current == null ? 0 : 1), 0),
              const SizedBox(width: 8),
              // Skipped offers are dropped from the badge too, or the tab
              // advertised a job the list no longer shows.
              _tabButton(
                  'Pending',
                  _tabCount(
                      stats.pendingCount -
                          (bookings.pending.length -
                              _pendingOffers(bookings).length),
                      _pendingOffers(bookings).length),
                  1),
              const SizedBox(width: 8),
              _tabButton('Completed',
                  _tabCount(stats.completedCount, bookings.completed.length), 2),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _bookingCarousel(bookings),
      ],
    );
  }

  /// Badge text for a tab. The stats are full-DB counts while each list is
  /// capped server-side (5 per tab), so a veteran driver saw "Completed(1240)"
  /// over five cards — show "5+" when the list is the cap, not the total.
  String _tabCount(int count, int shown) {
    if (count <= 0) return '';
    if (shown > 0 && count > shown) return '$shown+';
    return '$count';
  }

  Widget _tabButton(String label, String count, int tabIndex) {
    final selected = _selectedTab == tabIndex;
    // Width proportional to the text each tab carries.
    //
    // All three were equal thirds, so the longest label — "Completed" plus its
    // count — was the only one that didn't fit, and the FittedBox shrank just
    // that tab's text. The row still fills edge to edge; the space is simply
    // divided by what each pill actually has to show.
    final flex = (label.length + count.length).clamp(1, 40);
    return Expanded(
      flex: flex,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          if (selected) return;
          setState(() {
            _selectedTab = tabIndex;
            _carouselPage = 0;
          });
          // jumpToPage, not animateToPage: the new tab's list may be shorter
          // than the current index, which an animation would run off the end of.
          if (_pageController.hasClients) _pageController.jumpToPage(0);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.appColor : const Color(0xFFEFF1F5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              count.isNotEmpty ? '$label ($count)' : label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : const Color(0xFF3A4250),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bookingCarousel(DashboardBookings bookings) {
    final list = _activeList(bookings);
    if (list.isEmpty) return _tabEmptyState();

    // Pending jobs stay visible but untappable while a trip is in progress —
    // the same rule the old flat pending list enforced.
    final blocked = _selectedTab == 1 && bookings.current != null;

    return Column(
      children: [
        SizedBox(
          // Tracks the card's interior padding: a fixed height would clip the
          // last row now that the card carries 16px instead of 14px.
          height: 258,
          child: PageView.builder(
            controller: _pageController,
            itemCount: list.length,
            padEnds: false,
            onPageChanged: (i) => setState(() => _carouselPage = i),
            itemBuilder: (_, i) => Padding(
              padding: EdgeInsets.only(left: i == 0 ? 16 : 0, right: 12),
              child: blocked
                  ? Opacity(
                      opacity: 0.5,
                      child: IgnorePointer(child: _bookingCard(list[i])))
                  : _bookingCard(list[i], isOngoing: _selectedTab == 0),
            ),
          ),
        ),
        if (blocked) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: HexColor('#FFF3CD'),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                Icon(Icons.info_outline, color: HexColor('#856404'), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('complete_ongoing'.tr,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF856404))),
                ),
              ]),
            ),
          ),
        ],
        if (list.length > 1) ...[
          const SizedBox(height: 12),
          _pageDots(list.length),
        ],
      ],
    );
  }

  Widget _pageDots(int count) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (i) {
          final active = i == _carouselPage;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: active ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: active ? AppColors.appColor : const Color(0xFFD5DAE3),
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      );

  /// Per-tab empty state, at the carousel's height so switching tabs does not
  /// jolt the scroll position.
  Widget _tabEmptyState() {
    final driver = _dashboard!.driver;
    late final IconData icon;
    late final String text;
    switch (_selectedTab) {
      case 0:
        icon =
            driver.isOnline ? Icons.hourglass_empty : Icons.power_off_outlined;
        text = driver.isOnline ? 'no_bookings_yet'.tr : 'go_online'.tr;
        break;
      case 1:
        icon = Icons.inbox_outlined;
        text = 'No new bookings right now';
        break;
      default:
        icon = Icons.check_circle_outline;
        text = 'No completed trips yet';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 250,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE1E6EF)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------- Bottom nav --------------------------
  Widget _bottomNav() => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 58,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navIcon(Icons.home_rounded, active: true, onTap: null),
                _navIcon(Icons.receipt_long_outlined, onTap: () async {
                  await pushTo(context, const TripHistoryPage());
                  _loadDashboard(showLoader: false);
                }),
                _navIcon(Icons.account_balance_wallet_outlined,
                    onTap: () async {
                  await pushTo(context, const MyWalletScreen());
                  _loadDashboard(showLoader: false);
                }),
                _navIcon(Icons.notifications_none_rounded, onTap: () async {
                  await pushTo(context, const NotificationsScreen());
                  _loadDashboard(showLoader: false);
                }),
              ],
            ),
          ),
        ),
      );

  Widget _navIcon(IconData icon,
          {bool active = false, required VoidCallback? onTap}) =>
      InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Icon(
            icon,
            size: 24,
            color: active ? AppColors.appColor : Colors.grey.shade400,
          ),
        ),
      );

  Widget _avatar(String imageUrl) {
    final url = imageUrl.trim();
    return CircleAvatar(
      radius: 24,
      backgroundColor: Colors.white,
      child: ClipOval(
        child: url.isEmpty
            ? Icon(Icons.person_outline, color: AppColors.appColor, size: 28)
            : CachedNetworkImage(
                imageUrl: url,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => Icon(Icons.person_outline, color: AppColors.appColor, size: 28),
                placeholder: (context, url) => SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.appColor),
                ),
              ),
      ),
    );
  }

  Widget _approvalBanner(DashboardDriver driver) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: driver.status == 'suspended' || driver.status == 'rejected'
              ? HexColor('#B42318')
              : HexColor('#2E90FA'),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(
            driver.status == 'suspended' || driver.status == 'rejected'
                ? Icons.error_outline
                : Icons.schedule_outlined,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _approvalMessage(driver),
              style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.4),
            ),
          ),
        ]),
      );

  Widget _bookingCard(DashboardBooking booking, {bool isOngoing = false}) => InkWell(
        onTap: () async {
          if (isOngoing) {
            // Resume the trip at the correct step based on its current status,
            // so a driver re-entering mid-trip isn't stuck on "Mark Arrived".
            switch (booking.status) {
              case 'DRIVER_ARRIVED':
                await pushTo(
                  context,
                  VerifyRideScreen(
                    bookingId: booking.id,
                    bookingNumber: booking.bookingNumber,
                    earnings: (booking.estimatedEarnings > 0
                            ? booking.estimatedEarnings
                            : booking.estimatedFare)
                        .toStringAsFixed(0),
                    earningsIsGross: booking.estimatedEarnings <= 0,
                    scheduledAt: booking.scheduledAt,
                    createdAt: booking.createdAt,
                  ),
                );
                break;
              case 'PICKED':
              case 'IN_PROGRESS':
                await pushTo(
                  context,
                  AmountToBeCollectedScreen(bookingId: booking.id),
                );
                break;
              default: // ASSIGNED (or anything earlier) → mark-arrived screen
                await pushTo(context, BookingDetailPage(booking: booking));
            }
          } else if (booking.status == 'COMPLETED' ||
              booking.status == 'CANCELLED') {
            // A finished ride is a record, not an offer — the Completed tab
            // used to open the Skip/Accept screen for rides already done.
            await pushTo(context, TripSummeryPage(bookingId: booking.id));
          } else {
            await pushTo(context, TakeBookingsScreen(booking: booking));
          }
          _loadDashboard(showLoader: false);
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isOngoing ? const Color(0xFF1F8B4C).withValues(alpha: 0.3) : const Color(0xFFE1E6EF)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Row(children: [
                  Container(
                    height: 42,
                    width: 42,
                    decoration: BoxDecoration(
                      color: HexColor('#F0F9FF'),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: booking.vehicleTypeIcon.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(100),
                            child: CachedNetworkImage(
                              imageUrl: booking.vehicleTypeIcon,
                              width: 42, height: 42, fit: BoxFit.contain,
                              placeholder: (_, _) => Padding(padding: const EdgeInsets.all(8), child: Image.asset('assets/repeate_music.png')),
                              errorWidget: (_, _, _) => Padding(padding: const EdgeInsets.all(8), child: Image.asset('assets/repeate_music.png')),
                            ),
                          )
                        : Padding(padding: const EdgeInsets.all(8), child: Image.asset('assets/repeate_music.png')),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_bookingTitle(booking), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                  const SizedBox(width: 8),
                  if (isOngoing)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFF1F8B4C), borderRadius: BorderRadius.circular(100)),
                      child: Text('active'.tr, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    )
                  else if (_bookingWhen(booking).isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.appColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _bookingWhen(booking),
                        style: TextStyle(
                            color: AppColors.appColor,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Flexible(
                    child: Text(
                      'Estimate Usage: ${_duration(booking.durationMin)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'Total Dist.: ${booking.distanceKm.toStringAsFixed(1)} km',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                    ),
                  ),
                  if (booking.customerName.isNotEmpty)
                    // Expanded + textAlign.end: behind a Spacer the name was a bare Row
                    // child with unbounded width, so a long server-driven name could never
                    // ellipsize. Expanded fills the same gap the Spacer did and keeps the
                    // text flush to the trailing edge.
                    Expanded(
                      child: Text(
                        booking.customerName,
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: HexColor('#6C757D'), fontWeight: FontWeight.w600),
                      ),
                    ),
                ]),
              ]),
            ),
            Container(height: 1, color: const Color(0xFFE1E6EF)),
            // Pickup
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  height: 13,
                  width: 13,
                  margin: const EdgeInsets.only(top: 2, left: 1),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF1F8B4C), width: 2),
                  ),
                  child: const SizedBox(
                    height: 4,
                    width: 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                          color: Color(0xFF1F8B4C), shape: BoxShape.circle),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(child: Text(booking.pickupAddress.isEmpty ? 'Pickup' : booking.pickupAddress, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
              ]),
            ),
            // Drop
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(Icons.location_on,
                      size: 14, color: Color(0xFFE02D3C)),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(booking.dropAddress.isEmpty ? 'Drop' : booking.dropAddress, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
              ]),
            ),
            Container(height: 1, color: const Color(0xFFE1E6EF)),
            // What the driver gets — not the customer's fare.
            //
            // This showed booking.estimatedFare, the customer's gross, while
            // every screen it opens (TakeBookings, VerifyRide) shows
            // estimatedEarnings — subtotal minus commission, pre-GST — under
            // "Your estimated earnings". The card therefore advertised roughly
            // a quarter more than the next screen promised. Same basis and the
            // same fallback label as those screens now.
            _bookingEarnings(booking),
          ]),
        ),
      );

  /// The card's money row: the driver's own settlement estimate.
  ///
  /// `estimatedEarnings` is what the server computes for this driver
  /// (subtotal − commission, pre-GST, and the frozen `driverEarnings` once the
  /// trip is complete). Older bookings can carry 0 for it; in that case the
  /// gross fare is shown but labelled as trip value, never as earnings —
  /// exactly what TakeBookingsScreen and VerifyRideScreen do.
  Widget _bookingEarnings(DashboardBooking booking) {
    final bool earningsUnknown = booking.estimatedEarnings <= 0;
    final double amount =
        earningsUnknown ? booking.estimatedFare : booking.estimatedEarnings;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: HexColor('#F0F9FF'),
        borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(14), bottomRight: Radius.circular(14)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Image.asset('assets/moneys.png', height: 22, color: Colors.black),
        const SizedBox(width: 6),
        Text(
          _money.format(amount),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            earningsUnknown
                ? 'Trip value (earnings pending)'
                : 'Your estimated earnings',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600),
          ),
        ),
      ]),
    );
  }

  String _approvalMessage(DashboardDriver driver) {
    if (driver.status == 'suspended') {
      return driver.suspensionReason.trim().isEmpty
          ? 'Your account is suspended. You cannot go online until admin reactivates it.'
          : 'Your account is suspended: ${driver.suspensionReason}';
    }
    if (driver.status == 'rejected') {
      return driver.rejectionReason.trim().isEmpty
          ? 'Your documents were rejected by admin. Please update them before going online.'
          : 'Your account was rejected: ${driver.rejectionReason}';
    }
    return 'Your account is waiting for admin approval. You can view the dashboard, but you cannot go online yet.';
  }

  String _bookingTitle(DashboardBooking b) => b.vehicleTypeName.isNotEmpty
      ? '${b.vehicleTypeName}${b.serviceType.isNotEmpty ? ' - ${_serviceType(b.serviceType)}' : ''}'
      : (b.bookingNumber.isNotEmpty ? b.bookingNumber : _serviceType(b.serviceType));

  String _serviceType(String value) => value == 'WITHIN_CITY' ? 'Within City' : (value == 'OUTSTATION' ? 'Outstation' : value.replaceAll('_', ' '));

  /// The design's orange badge, e.g. "28 Feb. 10:10 AM". Prefers the scheduled
  /// time and falls back to when the booking was raised. Parsed as UTC then
  /// converted, so an IST driver is not shown a time 5.5 hours out; the backend
  /// also sends the literal string "null", which must not become a date.
  String _bookingWhen(DashboardBooking b) {
    for (final raw in [b.scheduledAt, b.createdAt]) {
      if (raw.isEmpty || raw == 'null') continue;
      final dt = DateTime.tryParse(raw);
      if (dt == null) continue;
      return DateFormat('dd MMM. hh:mm a').format(dt.toLocal());
    }
    return '';
  }

  String _duration(int min) => min >= 60 ? '${min ~/ 60} hr${min % 60 == 0 ? '' : ' ${min % 60} min'}' : '$min min';
}
