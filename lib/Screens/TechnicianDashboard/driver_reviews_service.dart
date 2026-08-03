import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:movezy_driver_app/ApiUrls/api_urls.dart';
import 'package:movezy_driver_app/Utils/PrefsManager/prefs_manager.dart';

/// One customer review of this driver.
class DriverReview {
  final String bookingNumber;
  final int rating;
  final String comment;
  final String customerName;
  final String customerPhoto;
  final DateTime? ratedAt;

  DriverReview({
    required this.bookingNumber,
    required this.rating,
    required this.comment,
    required this.customerName,
    required this.customerPhoto,
    this.ratedAt,
  });

  factory DriverReview.fromJson(Map<String, dynamic> j) => DriverReview(
        bookingNumber: (j['bookingNumber'] ?? '').toString(),
        rating: (j['rating'] as num?)?.round() ?? 0,
        comment: (j['comment'] ?? '').toString(),
        customerName: (j['customerName'] ?? 'Customer').toString(),
        customerPhoto: (j['customerPhoto'] ?? '').toString(),
        ratedAt:
            j['ratedAt'] != null ? DateTime.tryParse(j['ratedAt'].toString()) : null,
      );
}

class DriverReviewsResult {
  final List<DriverReview> reviews;
  final double average;
  final int count;

  DriverReviewsResult({
    required this.reviews,
    required this.average,
    required this.count,
  });
}

class DriverReviewsService {
  /// Reviews customers have left, newest first.
  ///
  /// These are read from the ratings already stored on completed bookings —
  /// there is no separate reviews collection, and none is needed.
  static Future<DriverReviewsResult> fetch({int limit = 4}) async {
    final res = await http.get(
      Uri.parse('${ApiUrls.driverReviewsUrl}?page=1&limit=$limit'),
      headers: {
        'Content-Type': 'application/json',
        // Prefs.accessToken — what every other driver service uses.
        // Prefs.getString('token') is the *user* app's convention and reads
        // empty here, so this request was rejected as unauthorized.
        'Authorization': 'Bearer ${Prefs.accessToken}',
      },
    ).timeout(const Duration(seconds: 20));

    final body = jsonDecode(res.body);
    // These driver routes answer the {code, message, data} envelope.
    if (res.statusCode != 200 || body is! Map || body['code'] != 1) {
      throw Exception(
          (body is Map ? body['message'] : null) ?? 'Failed to load reviews');
    }
    final data = body['data'] as Map<String, dynamic>;
    final list = (data['reviews'] as List?) ?? [];
    final summary = (data['summary'] as Map?) ?? {};
    return DriverReviewsResult(
      reviews: list
          .map((e) => DriverReview.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      average: ((summary['average'] as num?) ?? 0).toDouble(),
      count: (summary['count'] as num?)?.toInt() ?? 0,
    );
  }
}
