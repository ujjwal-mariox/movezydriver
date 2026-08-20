import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:movezy_driver_app/Screens/TechnicianDashboard/driver_reviews_service.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';

/// Every review a customer has left for this driver.
///
/// Reached from "View All" on the dashboard's Reviews section. The ratings have
/// always been stored on completed bookings; until now nothing showed them back
/// to the driver who earned them.
class DriverReviewsScreen extends StatefulWidget {
  const DriverReviewsScreen({super.key});

  @override
  State<DriverReviewsScreen> createState() => _DriverReviewsScreenState();
}

class _DriverReviewsScreenState extends State<DriverReviewsScreen> {
  DriverReviewsResult? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await DriverReviewsService.fetch(limit: 50);
      if (!mounted) return;
      setState(() {
        _data = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load your reviews.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: AppColors.appColor,
        foregroundColor: Colors.white,
        title: const Text('Reviews'),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!,
                          style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 10),
                      OutlinedButton(
                          onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _buildList(),
                ),
    );
  }

  Widget _buildList() {
    final d = _data!;
    if (d.reviews.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Icon(Icons.star_border,
              size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Center(
            child: Text('No reviews yet',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text('Complete trips to start collecting reviews.',
                style:
                    TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: d.reviews.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) return _summaryCard(d);
        return _tile(d.reviews[i - 1]);
      },
    );
  }

  Widget _summaryCard(DriverReviewsResult d) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Text('${d.average}',
              style: const TextStyle(
                  fontSize: 34, fontWeight: FontWeight.bold)),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  for (var i = 1; i <= 5; i++)
                    Icon(
                      i <= d.average.round() ? Icons.star : Icons.star_border,
                      size: 18,
                      color: const Color(0xFFFFB800),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text('${d.count} review${d.count == 1 ? '' : 's'}',
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tile(DriverReview r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey.shade200,
                backgroundImage:
                    r.customerPhoto.isNotEmpty ? NetworkImage(r.customerPhoto) : null,
                child: r.customerPhoto.isEmpty
                    ? Icon(Icons.person, size: 18, color: Colors.grey.shade500)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(r.customerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              if (r.ratedAt != null)
                Text(DateFormat('dd MMM yyyy').format(r.ratedAt!),
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                Icon(i <= r.rating ? Icons.star : Icons.star_border,
                    size: 14, color: const Color(0xFFFFB800)),
              const SizedBox(width: 8),
              Text(r.bookingNumber,
                  style:
                      TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
          if (r.comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(r.comment,
                style: TextStyle(
                    fontSize: 13, color: Colors.grey.shade800, height: 1.45)),
          ],
        ],
      ),
    );
  }
}
