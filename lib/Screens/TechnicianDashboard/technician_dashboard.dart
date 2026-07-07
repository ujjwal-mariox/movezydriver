import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:intl/intl.dart';
import 'package:movezy_driver_app/AppNavigation/app_navigation.dart';
import 'package:movezy_driver_app/CommonWidgets/app_bar.dart';
import 'package:movezy_driver_app/Screens/MyProfileScreen/my_profile_screen.dart';
import 'package:movezy_driver_app/Screens/TakeBookingsScreen/take_bookings_screen.dart';
import 'package:movezy_driver_app/Screens/BookingsDetailsScreen/bookings_details_screen.dart';
import 'package:movezy_driver_app/Screens/VerifyRideScreen/verify_ride_screen.dart';
import 'package:movezy_driver_app/Screens/CollectedCaseScreen/collected_case_screen.dart';
import 'package:movezy_driver_app/Screens/TechnicianDashboard/Model/driver_dashboard_response.dart';
import 'package:movezy_driver_app/Screens/TechnicianDashboard/dashboard_api_service.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';
import 'package:movezy_driver_app/Utils/CustomToast/custome_toast.dart';
import 'package:movezy_driver_app/Utils/LocationService/location_tracking_service.dart';
import 'package:movezy_driver_app/Utils/PrefsManager/prefs_manager.dart';
import 'package:movezy_driver_app/ApiUrls/api_urls.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

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
  IO.Socket? _socket;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
    _connectSocket();
  }

  @override
  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }

  /// Listen for real-time booking events via socket
  void _connectSocket() {
    _socket = IO.io(
      ApiUrls.socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setAuth({'token': Prefs.accessToken})
          .enableAutoConnect()
          .enableReconnection()
          .build(),
    );

    // Refresh dashboard when a new booking is dispatched to this driver
    _socket!.on('booking:new', (_) {
      _loadDashboard(showLoader: false);
    });

    // Refresh when booking status changes (accepted, completed, cancelled, etc.)
    _socket!.on('booking:status', (_) {
      _loadDashboard(showLoader: false);
    });
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _dashboard == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: AppColors.appColor)),
      );
    }
    if (_dashboard == null) {
      return Scaffold(
        backgroundColor: Colors.white,
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
    final pendingBookings = _dashboard!.bookings.pending;
    final currentBooking = _dashboard!.bookings.current;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: RefreshIndicator(
        color: AppColors.appColor,
        onRefresh: () => _loadDashboard(showLoader: false),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // --- Top Header with Profile & Rating ---
              Stack(
                children: [
                  commonAppBar(
                    height: 140,
                    context: context,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16, right: 16, top: 50),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () => pushTo(context, MyProfileScreen()),
                            child: _avatar(driver.profilePhoto),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  driver.fullName.isEmpty ? 'Driver' : driver.fullName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  driver.city.isNotEmpty ? driver.city : 'Welcome back',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Rating badge (small corner)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                                const SizedBox(width: 3),
                                Text(
                                  driver.rating > 0 ? driver.rating.toStringAsFixed(1) : '--',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // --- Approval Banner (if not approved) ---
              if (driver.status != 'approved') ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _approvalBanner(driver),
                ),
              ],

              const SizedBox(height: 16),

              // --- BIG ONLINE / OFFLINE TOGGLE ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GestureDetector(
                  onTap: _toggleStatus,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: double.infinity,
                    height: 80,
                    decoration: BoxDecoration(
                      color: driver.isOnline ? const Color(0xFF1F8B4C) : const Color(0xFF93000C),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: (driver.isOnline ? const Color(0xFF1F8B4C) : const Color(0xFF93000C)).withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isUpdatingStatus)
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        else ...[
                          Icon(
                            driver.isOnline ? Icons.power_settings_new : Icons.power_off_outlined,
                            color: Colors.white,
                            size: 32,
                          ),
                          const SizedBox(width: 14),
                          Text(
                            driver.isOnline ? 'online'.tr : 'offline'.tr,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // --- TODAY'S EARNINGS ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.appColor, AppColors.appColor.withValues(alpha: 0.85)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.appColor.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'todays_earnings'.tr,
                        style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _money.format(stats.todaysEarnings),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _earningMiniStat(Icons.local_shipping_outlined, '${stats.todaysServices}', 'trips'.tr),
                          Container(width: 1, height: 30, color: Colors.white30),
                          _earningMiniStat(Icons.schedule, '${stats.upcomingServices}', 'upcoming'.tr),
                          Container(width: 1, height: 30, color: Colors.white30),
                          _earningMiniStat(Icons.account_balance_wallet_outlined, _money.format(_dashboard!.wallet.balance), 'wallet'.tr),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // --- NEW BOOKING ALERT AREA ---
              if (currentBooking != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF1F8B4C),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'current_booking'.tr,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _bookingCard(currentBooking, isOngoing: true),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // --- PENDING BOOKINGS ---
              if (pendingBookings.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.notifications_active, color: AppColors.appColor, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '${'new_bookings'.tr} (${pendingBookings.length})',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...pendingBookings.map((booking) {
                        final isDisabled = currentBooking != null;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: isDisabled
                              ? Opacity(opacity: 0.5, child: IgnorePointer(child: _bookingCard(booking)))
                              : _bookingCard(booking),
                        );
                      }),
                      if (currentBooking != null)
                        Container(
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
                              child: Text(
                                'complete_ongoing'.tr,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF856404)),
                              ),
                            ),
                          ]),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // --- Empty state when no bookings ---
              if (currentBooking == null && pendingBookings.isEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE1E6EF)),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          driver.isOnline ? Icons.hourglass_empty : Icons.power_off_outlined,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          driver.isOnline
                              ? 'no_bookings_yet'.tr
                              : 'go_online'.tr,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _earningMiniStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 11),
        ),
      ],
    );
  }

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
                    earnings: booking.estimatedFare.toStringAsFixed(0),
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
              padding: const EdgeInsets.all(14),
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
                  Expanded(child: Text(_bookingTitle(booking), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                  const SizedBox(width: 8),
                  if (isOngoing)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFF1F8B4C), borderRadius: BorderRadius.circular(100)),
                      child: Text('active'.tr, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Text('${booking.distanceKm.toStringAsFixed(1)} km', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  Container(width: 4, height: 4, decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(_duration(booking.durationMin), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  if (booking.customerName.isNotEmpty) ...[
                    const Spacer(),
                    Text(booking.customerName, style: TextStyle(fontSize: 11.5, color: HexColor('#6C757D'), fontWeight: FontWeight.w600)),
                  ],
                ]),
              ]),
            ),
            Container(height: 1, color: const Color(0xFFE1E6EF)),
            // Pickup
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  height: 10,
                  width: 10,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: const BoxDecoration(color: Color(0xFF1F8B4C), shape: BoxShape.circle),
                ),
                const SizedBox(width: 11),
                Expanded(child: Text(booking.pickupAddress.isEmpty ? 'Pickup' : booking.pickupAddress, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
              ]),
            ),
            // Drop
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  height: 10,
                  width: 10,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: const BoxDecoration(color: Color(0xFFE02D3C), shape: BoxShape.circle),
                ),
                const SizedBox(width: 11),
                Expanded(child: Text(booking.dropAddress.isEmpty ? 'Drop' : booking.dropAddress, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
              ]),
            ),
            Container(height: 1, color: const Color(0xFFE1E6EF)),
            // Fare
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: HexColor('#F0F9FF'),
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(14), bottomRight: Radius.circular(14)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Image.asset('assets/moneys.png', height: 22, color: Colors.black),
                const SizedBox(width: 6),
                Text(
                  _money.format(booking.estimatedFare),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ]),
            ),
          ]),
        ),
      );

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

  String _duration(int min) => min >= 60 ? '${min ~/ 60} hr${min % 60 == 0 ? '' : ' ${min % 60} min'}' : '$min min';
}
