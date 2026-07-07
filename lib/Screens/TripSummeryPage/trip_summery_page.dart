import 'dart:convert';
import 'package:movezy_driver_app/ApiUrls/api_urls.dart';
import 'package:movezy_driver_app/CommonWidgets/app_bar.dart';
import 'package:movezy_driver_app/Utils/PrefsManager/prefs_manager.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class TripSummeryPage extends StatefulWidget {
  final String bookingId;
  const TripSummeryPage({super.key, required this.bookingId});

  @override
  State<TripSummeryPage> createState() => _TripSummeryPageState();
}

class _TripSummeryPageState extends State<TripSummeryPage> {
  final Color lightGray = const Color(0xFFF5F5F5);
  Map<String, dynamic>? _booking;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiUrls.driverBookingDetailsUrl}/${widget.bookingId}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Prefs.accessToken}',
        },
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        setState(() {
          _booking = body['data'] ?? body;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('Error fetching booking details: $e');
      setState(() => _loading = false);
    }
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '--';
    final date = DateTime.tryParse(dateStr)?.toLocal();
    if (date == null) return '--';
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }

  String _formatDistance(dynamic km) {
    if (km == null) return '0 km';
    final val = (km is num) ? km.toDouble() : double.tryParse(km.toString()) ?? 0;
    return '${val.toStringAsFixed(2)} km';
  }

  String _formatDuration(dynamic minutes) {
    if (minutes == null) return '0min';
    final min = (minutes is num) ? minutes.toInt() : int.tryParse(minutes.toString()) ?? 0;
    if (min >= 60) {
      return '${min ~/ 60}h ${(min % 60).toString().padLeft(2, '0')}min';
    }
    return '${min}min';
  }

  String _formatFare(dynamic fare) {
    if (fare == null) return '₹0';
    final val = (fare is num) ? fare : num.tryParse(fare.toString()) ?? 0;
    return '₹${NumberFormat('#,##0').format(val)}';
  }

  @override
  Widget build(BuildContext context) {
    final bookingNumber = _booking?['bookingNumber'] ?? '';

    return Scaffold(
      backgroundColor: lightGray,
      body: _loading
          ? Column(
              children: [
                _buildAppBar('#...'),
                const Expanded(
                    child: Center(child: CircularProgressIndicator())),
              ],
            )
          : _booking == null
              ? Column(
                  children: [
                    _buildAppBar('#...'),
                    Expanded(
                        child: Center(
                            child: Text('failed_load_details'.tr,
                                style: const TextStyle(
                                    fontSize: 16, color: Colors.grey)))),
                  ],
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildAppBar('#$bookingNumber'),
                      _buildPickupDestination(),
                      const SizedBox(height: 3),
                      _buildBasicDetails(),
                      const SizedBox(height: 12),
                      _buildFareDetails(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
    );
  }

  Widget _buildAppBar(String title) {
    return commonAppBar(
      height: 100,
      context: context,
      child: Container(
        padding: const EdgeInsets.only(top: 50),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
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
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildPickupDestination() {
    final pickup = _booking?['pickup'] ?? {};
    final drop = _booking?['drop'] ?? {};
    final pickedAt = _booking?['pickedAt'] ?? _booking?['assignedAt'];
    final completedAt = _booking?['completedAt'];

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: HexColor("#E1E6EF")),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('pickup_destination'.tr,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.black)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  const Icon(Icons.radio_button_checked, color: Colors.green),
                  Container(width: 2, height: 30, color: Colors.grey),
                  const Icon(Icons.location_on, color: Colors.red),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("${'started'.tr} : ${_formatDateTime(pickedAt)}",
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(pickup['address'] ?? ''),
                    const SizedBox(height: 12),
                    Text("${'ended'.tr} : ${_formatDateTime(completedAt)}",
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(drop['address'] ?? ''),
                  ],
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildBasicDetails() {
    final bookingNumber = _booking?['bookingNumber'] ?? '';
    final serviceType = _booking?['serviceType'] ?? '';
    final tripType = serviceType == 'OUTSTATION' ? 'Outstation' : 'Within City';
    final vehicleType = _booking?['vehicleTypeId']?['name'] ?? '--';

    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: HexColor("#E1E6EF")),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('basic_details'.tr,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.black)),
          const SizedBox(height: 12),
          infoRow("Trip ID:", "#$bookingNumber"),
          infoRow("Trip Type:", tripType),
          infoRow("Trip Distance:", _formatDistance(_booking?['distanceKm'])),
          infoRow("Trip Duration:", _formatDuration(_booking?['durationMin'])),
          infoRow("Vehicle Type:", vehicleType),
        ],
      ),
    );
  }

  Widget _buildFareDetails() {
    final fare = _booking?['finalFare'] ?? _booking?['fare'] ?? 0;
    final baseFare = _booking?['baseFare'] ?? fare;

    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: HexColor("#E1E6EF")),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('estimated_fare_details'.tr,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.black)),
          const SizedBox(height: 12),
          infoRow("Estimated Total Fare:", _formatFare(fare)),
          const Divider(),
          Center(
            child: Column(
              children: [
                Text('earned_from_trip'.tr,
                    style: const TextStyle(color: Colors.blue)),
                const SizedBox(height: 4),
                Text(_formatFare(baseFare),
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w500))),
          Expanded(
              child: Text(value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w400))),
        ],
      ),
    );
  }
}
