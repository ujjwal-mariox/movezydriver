import 'package:movezy_driver_app/AppNavigation/app_navigation.dart';
import 'package:movezy_driver_app/CommonWidgets/app_bar.dart';
import 'package:movezy_driver_app/CommonWidgets/slider_button_widget.dart';
import 'package:movezy_driver_app/Screens/HomeScreen/Widgets/profile_dialog.dart';
import 'package:movezy_driver_app/Screens/MyProfileScreen/my_profile_screen.dart';
import 'package:movezy_driver_app/Screens/TakeBookingsScreen/take_bookings_screen.dart';
import 'package:movezy_driver_app/Screens/BookingsDetailsScreen/bookings_details_screen.dart';
import 'package:movezy_driver_app/Screens/TechnicianDashboard/dashboard_api_service.dart';
import 'package:movezy_driver_app/Screens/TechnicianDashboard/Model/driver_dashboard_response.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DashboardApiService _apiService = DashboardApiService();
  DriverDashboardData? _dashboard;
  bool _isLoading = true;
  int _selectedTab = 0; // 0: OnGoing, 1: Pending, 2: Completed

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.dark,
    ));
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    final resp = await _apiService.fetchDashboard();
    if (mounted) {
      setState(() {
        _dashboard = resp?.data;
        _isLoading = false;
      });
    }
  }

  bool get _hasOngoingBooking => (_dashboard?.bookings.current != null);

  bool _togglingStatus = false;

  /// Flip the driver's online/offline status via the backend, then refresh.
  /// Previously the slider had no handler so it did nothing.
  Future<void> _toggleOnlineStatus() async {
    if (_togglingStatus) return;
    final next = !(_dashboard?.driver.isOnline == true);
    setState(() => _togglingStatus = true);
    final resp = await _apiService.updateOnlineStatus(isOnline: next);
    if (!mounted) return;
    setState(() => _togglingStatus = false);
    if (resp != null) {
      await _loadDashboard();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update status. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HexColor("#F0F9FF"),
      bottomNavigationBar: Container(
        color: Colors.white,
        height: 115,
        child: Column(
          children: [
            Container(height: 1, width: MediaQuery.of(context).size.width, color: Colors.grey[200]),
            const SizedBox(height: 10),
            Text(
              _dashboard?.driver.isOnline == true
                  ? "You are online - receiving bookings"
                  : "Check-in to get more bookings",
              style: const TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
            ),
            const SizedBox(height: 13),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SliderButtonWidget(
                text: _togglingStatus
                    ? "Please wait..."
                    : (_dashboard?.driver.isOnline == true ? "Online" : "Go Online"),
                onTap: _togglingStatus ? null : _toggleOnlineStatus,
              ),
            ),
            const SizedBox(height: 13),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              commonAppBar(
                height: 100,
                context: context,
                child: Container(
                  padding: const EdgeInsets.only(top: 53),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: () => pushTo(context, const MyProfileScreen()),
                        child: Container(
                          width: 32, height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(100), color: Colors.white),
                          child: const Icon(Icons.menu, size: 20),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Container()),
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _dashboard?.driver.isOnline == true ? HexColor("#64B161") : HexColor("#E02D3C"),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          _dashboard?.driver.isOnline == true ? "Online" : "Offline",
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w400),
                        ),
                      ),
                      Expanded(child: Container()),
                      const SizedBox(width: 50),
                    ],
                  ),
                ),
              ),
              _profileWidget(),
              const SizedBox(height: 15),
              _todaysWidget(),
              if (!_isLoading) ...[  
                const SizedBox(height: 15),
                _bookingsSection(),
              ] else ...[
                const SizedBox(height: 24),
                Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.appColor))),
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileWidget() {
    final driver = _dashboard?.driver;
    return InkWell(
      onTap: () => showDialog(context: context, builder: (_) => const ProfileDialog()),
      child: Container(
        height: 100,
        color: Colors.white,
        child: Row(
          children: [
            const SizedBox(width: 15),
            if (driver?.profilePhoto.isNotEmpty == true)
              ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: CachedNetworkImage(
                  imageUrl: driver!.profilePhoto, width: 50, height: 50, fit: BoxFit.cover,
                  placeholder: (_, _) => Image.asset("assets/profile_pic.png", width: 50, height: 50),
                  errorWidget: (_, _, _) => Image.asset("assets/profile_pic.png", width: 50, height: 50),
                ),
              )
            else
              Image.asset("assets/profile_pic.png", width: 50, height: 50, filterQuality: FilterQuality.low),
            const SizedBox(width: 15),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(driver?.fullName ?? "Driver", style: const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold)),
                Text("ID : ${driver != null && driver.id.length > 6 ? '#${driver.id.substring(driver.id.length - 6)}' : ''}", style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w400)),
              ],
            ),
            Expanded(child: Container()),
            Icon(Icons.star, color: AppColors.appColor, size: 20),
            const SizedBox(width: 2),
            Text((driver?.rating ?? 0).toStringAsFixed(1), style: const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(width: 18),
          ],
        ),
      ),
    );
  }

  Widget _todaysWidget() {
    final stats = _dashboard?.stats;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          const SizedBox(width: 8),
          _statCard("Today's\nEarning", "\u20B9${stats?.todaysEarnings.toStringAsFixed(0) ?? '0'}", HexColor("#13203C"), Colors.white),
          Expanded(child: Container()),
          _statCard("Today's\n Trips", "${stats?.todaysServices ?? 0}", HexColor("#FFCC00"), Colors.black),
          Expanded(child: Container()),
          _statCard("Upcoming\nServices", "${stats?.upcomingServices ?? 0}", AppColors.appColor, Colors.white),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, Color bg, Color textColor) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 7),
      padding: const EdgeInsets.symmetric(horizontal: 25),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(25)),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: textColor)),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _bookingsSection() {
    final stats = _dashboard?.stats;
    final onGoingCount = stats?.onGoingCount ?? 0;
    final pendingCount = stats?.pendingCount ?? 0;
    final completedCount = stats?.completedCount ?? 0;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
      child: Column(
        children: [
          Row(
            children: [
              const Text("Recommended Bookings", style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w600)),
              Expanded(child: Container()),
              Text("View All", style: TextStyle(color: HexColor("#015EA3"), fontSize: 12, fontWeight: FontWeight.w400)),
              Icon(Icons.arrow_right, color: HexColor("#015EA3"), size: 18),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _tabButton("On Going", onGoingCount, 0),
              const SizedBox(width: 10),
              _tabButton("Pending", pendingCount, 1),
              const SizedBox(width: 10),
              _tabButton("Completed", completedCount, 2),
            ],
          ),
          const SizedBox(height: 10),
          if (_selectedTab == 0) ..._buildOnGoingList(),
          if (_selectedTab == 1) ...[
            if (_hasOngoingBooking)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: HexColor("#FFF3CD"),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: HexColor("#856404"), size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        "Complete your ongoing booking before accepting new ones.",
                        style: TextStyle(fontSize: 12, color: Color(0xFF856404)),
                      ),
                    ),
                  ],
                ),
              ),
            ..._buildPendingList(),
          ],
          if (_selectedTab == 2) ..._buildCompletedList(),
        ],
      ),
    );
  }

  List<Widget> _buildOnGoingList() {
    final current = _dashboard?.bookings.current;
    if (current == null) {
      return [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text("No ongoing bookings", style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          ),
        ),
      ];
    }
    return [
      InkWell(
        onTap: () async {
          await pushTo(context, BookingDetailPage(booking: current));
          _loadDashboard();
        },
        child: _bookingListItem(current, showBadge: true),
      ),
    ];
  }

  Widget _tabButton(String label, int count, int tabIndex) {
    final isSelected = _selectedTab == tabIndex;
    return InkWell(
      onTap: () => setState(() => _selectedTab = tabIndex),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.appColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.appColor : HexColor("#E1E6EF")),
        ),
        child: Text(
          "$label($count)",
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPendingList() {
    final pending = _dashboard?.bookings.pending ?? [];
    if (pending.isEmpty) {
      return [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text("No pending bookings for your vehicle", style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          ),
        ),
      ];
    }
    return pending.map((booking) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          onTap: _hasOngoingBooking ? null : () async {
            await pushTo(context, TakeBookingsScreen(booking: booking));
            _loadDashboard();
          },
          child: Opacity(
            opacity: _hasOngoingBooking ? 0.5 : 1.0,
            child: _bookingListItem(booking),
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildCompletedList() {
    final completed = _dashboard?.bookings.completed ?? [];
    if (completed.isEmpty) {
      return [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text("No completed bookings yet", style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          ),
        ),
      ];
    }
    return completed.map((booking) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _bookingListItem(booking),
      );
    }).toList();
  }

  Widget _bookingListItem(DashboardBooking booking, {bool showBadge = false}) {
    String serviceLabel = booking.serviceType == "OUTSTATION" ? "Outstation" : "Within City";
    String title = booking.vehicleTypeName.isNotEmpty
        ? "${booking.vehicleTypeName} - $serviceLabel"
        : serviceLabel;
    String dateStr = "";
    if (booking.scheduledAt.isNotEmpty && booking.scheduledAt != "null") {
      try {
        final dt = DateTime.parse(booking.scheduledAt);
        dateStr = DateFormat("dd MMM, hh:mm a").format(dt);
      } catch (_) {}
    } else if (booking.createdAt.isNotEmpty && booking.createdAt != "null") {
      try {
        final dt = DateTime.parse(booking.createdAt);
        dateStr = DateFormat("dd MMM, hh:mm a").format(dt);
      } catch (_) {}
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: HexColor("#E1E6EF")),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppColors.appColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: booking.vehicleTypeIcon.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: CachedNetworkImage(
                      imageUrl: booking.vehicleTypeIcon,
                      width: 40, height: 40, fit: BoxFit.contain,
                      placeholder: (_, _) => Icon(Icons.local_shipping, color: AppColors.appColor, size: 22),
                      errorWidget: (_, _, _) => Icon(Icons.local_shipping, color: AppColors.appColor, size: 22),
                    ),
                  )
                : Icon(
                    booking.serviceType == "OUTSTATION" ? Icons.route : Icons.local_shipping,
                    color: AppColors.appColor, size: 22,
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title, style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                    ),
                    if (dateStr.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.appColor, borderRadius: BorderRadius.circular(20)),
                        child: Text(dateStr, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                      ),
                    if (showBadge) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: HexColor("#64B161"), borderRadius: BorderRadius.circular(20)),
                        child: Text(booking.status, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text("Estimate Usage: ${booking.durationMin} min", style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.w400)),
                    const Spacer(),
                    Text("Total Dist.: ${booking.distanceKm.toStringAsFixed(1)} km", style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.w400)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
