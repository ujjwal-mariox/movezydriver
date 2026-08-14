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

  /// Cancel an assigned booking (pre-pickup only). The backend releases this
  /// driver and re-dispatches the booking to others.
  Future<Map<String, dynamic>?> cancelBooking(
    String bookingId, {
    String? reason,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiUrls.driverCancelBookingUrl(bookingId)),
        headers: _headers,
        body: json.encode({if (reason != null) 'reason': reason}),
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
  Future<Map<String, dynamic>?> completeTrip(String bookingId,
      {String? deliveryOtp}) async {
    try {
      final response = await http.post(
        Uri.parse(ApiUrls.driverCompleteTripUrl(bookingId)),
        headers: _headers,
        // The delivery OTP the receiver read out; server enforces it only when
        // the booking carries one.
        body: deliveryOtp == null ? null : json.encode({'otp': deliveryOtp}),
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

  /// Mark one intermediate stop of a multi-drop ride delivered. Returns the
  /// whole envelope so the caller can distinguish success (code 1) from a
  /// server refusal (wrong order, already done) and show the real message.
  Future<Map<String, dynamic>?> completeStop(
      String bookingId, int stopIndex) async {
    try {
      final response = await http.post(
        Uri.parse(
            '${ApiUrls.driverBookingDetailsUrl}/$bookingId/stops/$stopIndex/complete'),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));
      final data = json.decode(response.body);
      if (data is Map<String, dynamic>) return data;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// The driver's COMPLETED trips, newest first, for the Earnings screen.
  ///
  /// Reuses the existing history route with `status=COMPLETED` rather than
  /// inventing an endpoint. That route returns the RAW booking documents (it is
  /// the one driver route that does not run them through mapDashboardBooking),
  /// so callers read `driverEarnings` / `completedAt` / `bookingNumber` straight
  /// off the map. `driverEarnings` is the settlement frozen at completion —
  /// never substitute finalFare, which is the customer's gross.
  ///
  /// The server pages by `createdAt` desc, so this is "the N most recently
  /// created completed trips", not a period total — do not sum it and present
  /// the result as one. Returns null ONLY on failure, so the caller can tell a
  /// broken call from a driver who has completed nothing yet.
  Future<({List<Map<String, dynamic>> bookings, int total})?> fetchCompletedTrips({
    int limit = 30,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
            '${ApiUrls.driverBookingHistoryUrl}?page=1&limit=$limit&status=COMPLETED'),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) return null;
      final data = json.decode(response.body);
      if (data is! Map<String, dynamic>) return null;
      final inner = data['data'];
      if (inner is! Map<String, dynamic>) return null;
      final raw = inner['bookings'];
      final bookings = <Map<String, dynamic>>[
        if (raw is List)
          for (final b in raw)
            if (b is Map<String, dynamic>) b,
      ];
      final total =
          inner['total'] is num ? (inner['total'] as num).toInt() : bookings.length;
      return (bookings: bookings, total: total);
    } catch (_) {
      return null;
    }
  }

  /// The bonuses actually awarded to this driver (the ledger behind the
  /// "Incentives Unlocked" aggregate on the Awards screen), newest first.
  ///
  /// Returns null ONLY on failure (network/auth/parse) so the caller can tell a
  /// real error from a legitimately empty history — the other methods here
  /// collapse both to null, which the Awards screen can't distinguish. The
  /// backend keys each row `_id` (not `id`), so read that.
  Future<({List<Map<String, dynamic>> items, num total})?>
      fetchIncentiveHistory() async {
    try {
      final response = await http.get(
        Uri.parse(ApiUrls.driverIncentiveHistoryUrl),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) return null;
      final data = json.decode(response.body);
      if (data is! Map<String, dynamic>) return null;
      final inner = data['data'];
      if (inner is! Map<String, dynamic>) return null;
      final rawItems = inner['items'];
      final items = <Map<String, dynamic>>[
        if (rawItems is List)
          for (final it in rawItems)
            if (it is Map<String, dynamic>) it,
      ];
      final total = inner['total'] is num ? inner['total'] as num : 0;
      return (items: items, total: total);
    } catch (_) {
      return null;
    }
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${Prefs.accessToken}',
      };
}
