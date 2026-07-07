import 'dart:convert';
import 'package:movezy_driver_app/ApiUrls/api_urls.dart';
import 'package:movezy_driver_app/AppNavigation/app_navigation.dart';
import 'package:movezy_driver_app/CommonWidgets/app_bar.dart';
import 'package:movezy_driver_app/Screens/TripSummeryPage/trip_summery_page.dart';
import 'package:movezy_driver_app/Utils/PrefsManager/prefs_manager.dart';
import 'package:flutter/material.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class TripHistoryPage extends StatefulWidget {
  const TripHistoryPage({super.key});

  @override
  State<TripHistoryPage> createState() => _TripHistoryPageState();
}

class _TripHistoryPageState extends State<TripHistoryPage> {
  List<dynamic> _bookings = [];
  bool _loading = true;
  int _page = 1;
  int _total = 0;
  bool _loadingMore = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchHistory();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_loadingMore &&
          _bookings.length < _total) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchHistory() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiUrls.driverBookingHistoryUrl}?page=1&limit=20'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Prefs.accessToken}',
        },
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body['data'] ?? body;
        setState(() {
          _bookings = data['bookings'] ?? [];
          _total = data['total'] ?? 0;
          _page = 1;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('Error fetching history: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final nextPage = _page + 1;
      final response = await http.get(
        Uri.parse('${ApiUrls.driverBookingHistoryUrl}?page=$nextPage&limit=20'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Prefs.accessToken}',
        },
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body['data'] ?? body;
        final newBookings = data['bookings'] ?? [];
        setState(() {
          _bookings.addAll(newBookings);
          _page = nextPage;
          _loadingMore = false;
        });
      } else {
        setState(() => _loadingMore = false);
      }
    } catch (e) {
      setState(() => _loadingMore = false);
    }
  }

  Map<String, List<dynamic>> _groupByDate() {
    final Map<String, List<dynamic>> grouped = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final booking in _bookings) {
      final createdAt = booking['createdAt'] ?? booking['completedAt'] ?? '';
      DateTime? date;
      if (createdAt is String && createdAt.isNotEmpty) {
        date = DateTime.tryParse(createdAt)?.toLocal();
      }

      String label;
      if (date != null) {
        final dateOnly = DateTime(date.year, date.month, date.day);
        if (dateOnly == today) {
          label = 'TODAY';
        } else if (dateOnly == yesterday) {
          label = 'YESTERDAY';
        } else {
          label = DateFormat('dd MMM yyyy').format(date).toUpperCase();
        }
      } else {
        label = 'UNKNOWN';
      }

      grouped.putIfAbsent(label, () => []);
      grouped[label]!.add(booking);
    }
    return grouped;
  }

  String _formatDistance(dynamic km) {
    if (km == null) return '0 km';
    final val = (km is num) ? km.toDouble() : double.tryParse(km.toString()) ?? 0;
    return '${val.toStringAsFixed(1)} km';
  }

  String _formatDuration(dynamic minutes) {
    if (minutes == null) return '0 min';
    final min = (minutes is num) ? minutes.toInt() : int.tryParse(minutes.toString()) ?? 0;
    if (min >= 60) {
      return '${min ~/ 60}h ${min % 60}m';
    }
    return '$min min';
  }

  String _formatFare(dynamic fare) {
    if (fare == null) return '\u20B90';
    final val = (fare is num) ? fare : num.tryParse(fare.toString()) ?? 0;
    return '\u20B9${NumberFormat('#,##0').format(val)}';
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    final date = DateTime.tryParse(dateStr)?.toLocal();
    if (date == null) return '';
    return DateFormat('hh:mm a').format(date);
  }

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
                      width: 40, height: 35,
                      alignment: Alignment.center,
                      child: Image.asset("assets/back_arrow.png", color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('history'.tr, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                  const Spacer(),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: AppColors.appColor))
                : _bookings.isEmpty
                    ? Center(child: Text('no_trip_history'.tr, style: const TextStyle(fontSize: 16, color: Colors.grey)))
                    : _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    final grouped = _groupByDate();
    final List<Widget> children = [];

    for (final entry in grouped.entries) {
      children.add(_buildDateHeader(entry.key));
      for (int i = 0; i < entry.value.length; i++) {
        children.add(_buildTripCard(entry.value[i]));
        if (i < entry.value.length - 1) {
          children.add(const SizedBox(height: 10));
        }
      }
      children.add(const SizedBox(height: 12));
    }

    if (_loadingMore) {
      children.add(Padding(
        padding: const EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(color: AppColors.appColor)),
      ));
    }

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      children: children,
    );
  }

  Widget _buildDateHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Expanded(child: Divider(color: Color(0xFFE2E5EA), thickness: 1, endIndent: 8)),
          Text(
            text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF757E90)),
          ),
          const Expanded(child: Divider(color: Color(0xFFE2E5EA), thickness: 1, indent: 8)),
        ],
      ),
    );
  }

  Widget _buildTripCard(dynamic booking) {
    final pickupAddress = booking['pickup']?['address'] ?? '';
    final dropAddress = booking['drop']?['address'] ?? '';
    final distanceKm = booking['distanceKm'];
    final durationMin = booking['durationMin'];
    final fare = booking['finalFare'] ?? booking['fare'] ?? 0;
    final createdAt = booking['createdAt'] ?? '';
    final bookingId = booking['_id'] ?? '';

    return InkWell(
      onTap: () {
        pushTo(context, TripSummeryPage(bookingId: bookingId));
      },
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
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: pickup/drop icons with line
              Column(
                children: [
                  const SizedBox(height: 2),
                  // Green dot (Pickup)
                  Container(
                    width: 14, height: 14,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1F8B4C),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(width: 2, height: 28, color: Colors.grey.shade300),
                  // Red dot (Drop)
                  Container(
                    width: 14, height: 14,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE02D3C),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),

              // Middle: addresses + meta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pickupAddress.isEmpty ? 'Pickup location' : pickupAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      dropAddress.isEmpty ? 'Drop location' : dropAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87),
                    ),
                    const SizedBox(height: 10),
                    // Time & distance (smaller text)
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 13, color: Colors.grey.shade500),
                        const SizedBox(width: 3),
                        Text(
                          _formatTime(createdAt),
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.straighten, size: 13, color: Colors.grey.shade500),
                        const SizedBox(width: 3),
                        Text(
                          _formatDistance(distanceKm),
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.timer_outlined, size: 13, color: Colors.grey.shade500),
                        const SizedBox(width: 3),
                        Text(
                          _formatDuration(durationMin),
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Right: BIG earning amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const SizedBox(height: 10),
                  Text(
                    _formatFare(fare),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.appColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
