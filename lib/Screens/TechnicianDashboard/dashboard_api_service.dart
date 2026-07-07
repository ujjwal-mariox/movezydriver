import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:movezy_driver_app/ApiUrls/api_urls.dart';
import 'package:movezy_driver_app/Screens/TechnicianDashboard/Model/driver_dashboard_response.dart';
import 'package:movezy_driver_app/Utils/PrefsManager/prefs_manager.dart';

class DashboardApiService {
  Future<DriverDashboardResponse?> fetchDashboard() async {
    try {
      final response = await http.get(
        Uri.parse(ApiUrls.driverDashboardUrl),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));

      return driverDashboardResponseFromJson(response.body);
    } catch (_) {
      return null;
    }
  }

  Future<DriverStatusResponse?> updateOnlineStatus({
    required bool isOnline,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiUrls.driverToggleStatusUrl),
        headers: _headers,
        body: json.encode({'isOnline': isOnline}),
      ).timeout(const Duration(seconds: 30));

      return driverStatusResponseFromJson(response.body);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> acceptBooking(String bookingId) async {
    try {
      final response = await http.post(
        Uri.parse(ApiUrls.driverAcceptBookingUrl(bookingId)),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);
      if (data is Map<String, dynamic>) return data;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> rejectBooking(String bookingId) async {
    try {
      final response = await http.post(
        Uri.parse(ApiUrls.driverRejectBookingUrl(bookingId)),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);
      if (data is Map<String, dynamic>) return data;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> arrivedAtPickup(String bookingId) async {
    try {
      final response = await http.post(
        Uri.parse(ApiUrls.driverArrivedBookingUrl(bookingId)),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);
      if (data is Map<String, dynamic>) return data;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Verify the pickup OTP the customer shows the driver. Backend requires the
  /// booking to be DRIVER_ARRIVED. Returns the response map, or null on error.
  Future<Map<String, dynamic>?> verifyPickupOtp(String bookingId, String otp) async {
    try {
      final response = await http.post(
        Uri.parse(ApiUrls.driverVerifyOtpUrl(bookingId)),
        headers: _headers,
        body: json.encode({'otp': otp}),
      ).timeout(const Duration(seconds: 30));
      final data = json.decode(response.body);
      if (data is Map<String, dynamic>) return data;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Start the trip (after OTP verification).
  Future<Map<String, dynamic>?> startTrip(String bookingId) async {
    try {
      final response = await http.post(
        Uri.parse(ApiUrls.driverStartTripUrl(bookingId)),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));
      final data = json.decode(response.body);
      if (data is Map<String, dynamic>) return data;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Complete the trip. Backend marks COMPLETED and credits the customer's coins.
  Future<Map<String, dynamic>?> completeTrip(String bookingId) async {
    try {
      final response = await http.post(
        Uri.parse(ApiUrls.driverCompleteTripUrl(bookingId)),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));
      final data = json.decode(response.body);
      if (data is Map<String, dynamic>) return data;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Mark cash collected (for COD bookings).
  Future<Map<String, dynamic>?> collectCash(String bookingId) async {
    try {
      final response = await http.post(
        Uri.parse(ApiUrls.driverCollectCashUrl(bookingId)),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));
      final data = json.decode(response.body);
      if (data is Map<String, dynamic>) return data;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Raise a support ticket (persists a real ticket via the support service).
  Future<Map<String, dynamic>?> raiseTicket({
    required String category,
    required String subject,
    required String message,
    String? bookingId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiUrls.driverRaiseTicketUrl),
        headers: _headers,
        body: json.encode({
          'category': category,
          'subject': subject,
          'message': message,
          if (bookingId != null) 'bookingId': bookingId,
        }),
      ).timeout(const Duration(seconds: 30));
      final data = json.decode(response.body);
      if (data is Map<String, dynamic>) return data;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Withdrawable balance + minimum + bank-on-file flag + recent payout history.
  /// Returns the inner `data` map, or null on failure.
  Future<Map<String, dynamic>?> fetchWithdrawalInfo() async {
    try {
      final response = await http.get(
        Uri.parse(ApiUrls.driverWithdrawalInfoUrl),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));
      final data = json.decode(response.body);
      if (data is Map<String, dynamic>) {
        final inner = data['data'];
        if (inner is Map<String, dynamic>) return inner;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Request a payout (withdrawal) of earned money. Returns the full
  /// {code, message, data} response so the caller can show the server message.
  Future<Map<String, dynamic>?> requestWithdrawal({
    required double amount,
    String method = 'BANK',
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiUrls.driverWithdrawUrl),
        headers: _headers,
        body: json.encode({'amount': amount, 'method': method}),
      ).timeout(const Duration(seconds: 30));
      final data = json.decode(response.body);
      if (data is Map<String, dynamic>) return data;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Save user's preferred language to backend
  Future<bool> saveLanguagePreference(String languageCode) async {
    try {
      final response = await http.put(
        Uri.parse(ApiUrls.driverLanguageUrl),
        headers: _headers,
        body: json.encode({'language': languageCode}),
      ).timeout(const Duration(seconds: 30));

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Fetch user's saved language preference from backend
  Future<String?> getLanguagePreference() async {
    try {
      final response = await http.get(
        Uri.parse(ApiUrls.driverLanguageUrl),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map && data['data'] != null) {
          return data['data']['language']?.toString();
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Real incentive summary (today earnings/trips, peak trips, trackers).
  Future<Map<String, dynamic>?> fetchIncentives() async {
    try {
      final response = await http.get(
        Uri.parse(ApiUrls.driverIncentivesUrl),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));
      final data = json.decode(response.body);
      if (data is Map<String, dynamic>) {
        // Response is wrapped as { code, data: {...}, message }.
        final inner = data['data'];
        if (inner is Map<String, dynamic>) return inner;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Fetch full booking details (fare + customer contact) for a booking.
  Future<Map<String, dynamic>?> getBookingDetails(String bookingId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiUrls.driverBookingDetailsUrl}/$bookingId'),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));
      final data = json.decode(response.body);
      if (data is Map<String, dynamic>) {
        // Response is wrapped as { code, data: {booking...}, message }.
        final inner = data['data'];
        if (inner is Map<String, dynamic>) return inner;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${Prefs.accessToken}',
      };
}
