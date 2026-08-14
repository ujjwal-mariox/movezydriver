import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:movezy_driver_app/ApiUrls/api_urls.dart';
import 'package:movezy_driver_app/Screens/MyVehicles/Model/driver_details_response.dart';
import 'package:movezy_driver_app/Utils/PrefsManager/prefs_manager.dart';

class MyVehiclesApiService {
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${Prefs.accessToken}',
      };

  /// Fetch all vehicles for the current driver
  Future<DriverDetailsResponse> getMyVehicles() async {
    final response = await http.get(
      Uri.parse(ApiUrls.myVehiclesUrl),
      headers: _headers,
    );

    print("getMyVehicles ${response.request?.url}");
    print("getMyVehicles ${response.body}");

    return driverDetailsResponseFromJson(response.body);
  }

  /// Initiate onboarding fee payment for one or more vehicles in a single order.
  /// Returns {orderId, amount, currency, vehicleIds, razorpayKeyId} on success.
  Future<Map<String, dynamic>> initiatePayment(List<String> vehicleIds) async {
    final response = await http.post(
      Uri.parse(ApiUrls.onboardingFeePayUrl),
      headers: _headers,
      body: jsonEncode({'vehicleIds': vehicleIds}),
    );

    print("initiatePayment ${response.request?.url}");
    print("initiatePayment ${response.body}");

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(body['message']?.toString() ?? 'Payment initiation failed');
    }
    return body['data'] as Map<String, dynamic>;
  }

  /// Verify Razorpay payment after successful checkout. Marks every vehicleId
  /// in the list as paid against this order.
  Future<Map<String, dynamic>> verifyPayment({
    required List<String> vehicleIds,
    required String paymentId,
    required String orderId,
    required String signature,
  }) async {
    final response = await http.post(
      Uri.parse(ApiUrls.onboardingFeeVerifyUrl),
      headers: _headers,
      body: jsonEncode({
        'vehicleIds': vehicleIds,
        'razorpay_payment_id': paymentId,
        'razorpay_order_id': orderId,
        'razorpay_signature': signature,
      }),
    );

    print("verifyPayment ${response.request?.url}");
    print("verifyPayment ${response.body}");

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(body['message']?.toString() ?? 'Payment verification failed');
    }
    return body['data'] as Map<String, dynamic>;
  }

  /// Apply a referral code to a specific vehicle
  Future<Map<String, dynamic>> applyReferral({
    required String vehicleId,
    required String referralCode,
  }) async {
    final response = await http.post(
      Uri.parse(ApiUrls.vehicleApplyReferralUrl(vehicleId)),
      headers: _headers,
      body: jsonEncode({'referralCode': referralCode}),
    );

    print("applyReferral ${response.request?.url}");
    print("applyReferral ${response.body}");

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(body['message']?.toString() ?? 'Invalid referral code');
    }
    return body['data'] as Map<String, dynamic>;
  }

  /// Apply an admin-created onboarding coupon to a specific vehicle
  Future<Map<String, dynamic>> applyCoupon({
    required String vehicleId,
    required String couponCode,
  }) async {
    final response = await http.post(
      Uri.parse(ApiUrls.vehicleApplyCouponUrl(vehicleId)),
      headers: _headers,
      body: jsonEncode({'couponCode': couponCode}),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    // {code, message, data} envelope: code 0 = rejected (invalid/expired/used).
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body['code'] == 0) {
      throw Exception(body['message']?.toString() ?? 'Invalid coupon code');
    }
    return (body['data'] ?? {}) as Map<String, dynamic>;
  }

  /// Get onboarding fee details (amounts, discounts)
  Future<Map<String, dynamic>> getOnboardingFee() async {
    final response = await http.get(
      Uri.parse(ApiUrls.onboardingFeeUrl),
      headers: _headers,
    );

    print("getOnboardingFee ${response.request?.url}");
    print("getOnboardingFee ${response.body}");

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(body['message']?.toString() ?? 'Unable to load fee details');
    }
    return body['data'] as Map<String, dynamic>;
  }
}
