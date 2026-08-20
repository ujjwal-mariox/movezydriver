import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiUrls {
  /// Backend origin, chosen at BUILD time.
  ///
  /// This used to be a hand-edited constant with the other environments
  /// commented out beneath it — so whichever line was uncommented when someone
  /// hit build is what shipped, and a local-testing URL in a release APK is a
  /// dead app on every device that isn't tethered to that machine.
  ///
  /// Production is the default: a plain `flutter build apk` is always safe.
  /// For local work pass the override:
  ///   flutter run --dart-define=API_ORIGIN=http://127.0.0.1:9050
  static const String _origin = String.fromEnvironment(
    'API_ORIGIN',
    defaultValue: 'https://movezybackend.onrender.com',
  );

  static String baseUrlApi = "$_origin/v1/api";
  // Production API endpoint
  // Local development: Android emulator uses 10.0.2.2 to reach host machine's localhost

  static String loginUrl = "$baseUrlApi/driver/login";

  static String otpUrlVerify = "$baseUrlApi/driver/verify-otp";

  static String detailsUrl = "$baseUrlApi/driver/personal-info";

  // Bank details save (writes driver.bankDetails) — distinct from personal-info
  static String driverBankDetailsUrl = "$baseUrlApi/driver/app/bank-details";
  // Support tickets (driver) — create + list + thread + reply
  static String driverRaiseTicketUrl = "$baseUrlApi/driver/app/support/ticket";

  /// Admin-managed FAQs (public endpoint, same source the admin panel edits).
  /// The driver FAQ screen used to ship a hardcoded list, so nothing an admin
  /// wrote in Content & Policies ever reached drivers.
  static String faqsUrl = "$baseUrlApi/support/faqs";
  static String driverSupportTicketsUrl = "$baseUrlApi/driver/app/support/tickets";
  static String driverSupportTicketDetailsUrl(String ticketId) =>
      "$baseUrlApi/driver/app/support/tickets/$ticketId";
  static String driverSupportTicketReplyUrl(String ticketId) =>
      "$baseUrlApi/driver/app/support/tickets/$ticketId/reply";

  static String addLicenceUrl = "$baseUrlApi/driver/kyc/driving-license";

  static String addAAdharUrl = "$baseUrlApi/driver/kyc/aadhaar";

  static String addPanUrl = "$baseUrlApi/driver/kyc/pan";

  static String addSelfieUrl = "$baseUrlApi/driver/kyc/selfie";

  static String addRcDetailsApi = "$baseUrlApi/driver/kyc/rc";

  // Server-side logout — sets isOnline:false so dispatch stops targeting them.
  static String driverLogoutUrl = "$baseUrlApi/driver/logout";

  // Admin-managed vehicle-type catalog (populates the Add Vehicle dropdown).
  static String driverVehicleTypesUrl = "$baseUrlApi/driver/vehicle-types";

  static String addLicenceApi = "$baseUrlApi/driver/kyc/driving-license";

  static String ownerDetailsUrl = "$baseUrlApi/driver/kyc/owner-details";

  static String onboardingStatusUrl = "$baseUrlApi/driver/onboarding-status";

  static String driverDetailsUrl = "$baseUrlApi/driver/details";

  static String masterDataUrl = "$baseUrlApi/driver/master-data";

  static String driverDashboardUrl = "$baseUrlApi/driver/app/dashboard";

  static String driverProfileUrl = "$baseUrlApi/driver/app/profile";

  static String driverProfilePhotoUrl = "$baseUrlApi/driver/app/profile/photo";

  static String driverLanguageUrl = "$baseUrlApi/driver/app/profile/language";

  static String driverToggleStatusUrl = "$baseUrlApi/driver/app/status/toggle";

  static String driverInstructionsUrl = "$baseUrlApi/driver/app/instructions";

  static String driverInstructionsAcknowledgeUrl =
      "$baseUrlApi/driver/app/instructions/acknowledge";

  static String driverBookingHistoryUrl = "$baseUrlApi/driver/app/bookings/history";

  static String driverBookingDetailsUrl = "$baseUrlApi/driver/app/bookings";

  // Wallet
  static String driverWalletUrl = "$baseUrlApi/driver/app/wallet";

  static String driverWalletTransactionsUrl = "$baseUrlApi/driver/app/wallet/transactions";

  static String driverWalletAddUrl = "$baseUrlApi/driver/app/wallet/add";
  // Wallet recharge via Razorpay: create order, then verify + credit
  static String driverWalletRechargeUrl = "$baseUrlApi/driver/app/wallet/recharge";
  static String driverWalletRechargeVerifyUrl = "$baseUrlApi/driver/app/wallet/recharge/verify";
  // Withdraw earnings: fetch withdrawable balance/info, then request a payout
  static String driverWithdrawalInfoUrl = "$baseUrlApi/driver/app/wallet/withdrawal-info";
  static String driverWithdrawUrl = "$baseUrlApi/driver/app/wallet/withdraw";

  // Referral
  static String driverReferralStatsUrl = "$baseUrlApi/driver/app/referral/stats";

  static String driverReferralApplyUrl = "$baseUrlApi/driver/app/referral/apply";

  // Badges
  static String driverBadgesUrl = "$baseUrlApi/driver/app/badges";

  // Training
  static String driverTrainingUrl = "$baseUrlApi/driver/app/training";
  static String driverTrainingProgressUrl = "$baseUrlApi/driver/app/training/progress";
  // Backend route is /training/:moduleId/lessons/:lessonId/complete and stores
  // the completion key as `${moduleId}_${lessonId}`, so the two IDs must be
  // distinct. The previous builder reused one id for both segments.
  static String driverTrainingCompleteUrl(String moduleId, String lessonId) =>
      "$baseUrlApi/driver/app/training/$moduleId/lessons/$lessonId/complete";

  // Bookings
  static String driverRecommendedBookingsUrl = "$baseUrlApi/driver/app/bookings/recommended";

  static String driverCurrentBookingUrl = "$baseUrlApi/driver/app/bookings/current";

  static String driverAcceptBookingUrl(String bookingId) => "$baseUrlApi/driver/app/bookings/$bookingId/accept";

  static String driverRejectBookingUrl(String bookingId) => "$baseUrlApi/driver/app/bookings/$bookingId/reject";

  static String driverArrivedBookingUrl(String bookingId) => "$baseUrlApi/driver/app/bookings/$bookingId/arrived";
  // Driver cancels an assigned booking (pre-pickup) — returns it to the pool.
  static String driverCancelBookingUrl(String bookingId) => "$baseUrlApi/driver/app/bookings/$bookingId/cancel";

  // Trip lifecycle: verify pickup OTP → start → complete → collect cash
  static String driverVerifyOtpUrl(String bookingId) => "$baseUrlApi/driver/app/bookings/$bookingId/verify-otp";
  static String driverStartTripUrl(String bookingId) => "$baseUrlApi/driver/app/bookings/$bookingId/start";
  static String driverCompleteTripUrl(String bookingId) => "$baseUrlApi/driver/app/bookings/$bookingId/complete";
  static String driverCollectCashUrl(String bookingId) => "$baseUrlApi/driver/app/bookings/$bookingId/collect-cash";

  // My Vehicles
  static String myVehiclesUrl = "$baseUrlApi/driver/app/my-vehicles";

  // Onboarding Fee
  static String onboardingFeeUrl = "$baseUrlApi/driver/app/onboarding-fee";
  static String onboardingFeePayUrl = "$baseUrlApi/driver/app/onboarding-fee/pay";
  static String onboardingFeeVerifyUrl = "$baseUrlApi/driver/app/onboarding-fee/verify";

  // Chat
  static String chatHistoryUrl(String bookingId) => "$baseUrlApi/driver/app/chat/$bookingId/history";
  static String chatUploadImageUrl(String bookingId) => "$baseUrlApi/driver/app/chat/$bookingId/upload-image";

  // Socket.io base URL (no /v1/api path) — must match the API server the app
  // uses so driver + customer land in the same chat room.
  /// Socket.io origin — same host as the API, no /v1/api suffix.
  static String socketUrl = _origin;

  // Vehicle Referral
  static String vehicleApplyReferralUrl(String vehicleId) => "$baseUrlApi/driver/app/my-vehicles/$vehicleId/apply-referral";
  static String vehicleApplyCouponUrl(String vehicleId) => "$baseUrlApi/driver/app/my-vehicles/$vehicleId/apply-coupon";

  // SOS / Emergency
  static String sosTriggerUrl = "$baseUrlApi/driver/app/sos/trigger";

  /// Support helpline, published by admin.
  ///
  /// Public (no auth) so it can be read before login. Verified shape — this is
  /// a bare handler in the backend's routes/index.ts, NOT one of the
  /// `{code, message, data}` envelope routes:
  ///   `{ "success": true, "data": { "supportPhone": "<string>" } }`
  /// `supportPhone` is `""` whenever the admin has not set one
  /// (`AppConfig` key `SUPPORT_PHONE`, edited at /admin/config/support-contact).
  static String supportContactUrl = "$baseUrlApi/support-contact";

  /// The number the app is allowed to dial, as configured by admin.
  ///
  /// EMPTY until [loadSupportContact] has fetched a non-empty value, and empty
  /// whenever no number is configured. An empty value means "no helpline" —
  /// every call control (including the post-accident escalation) must be
  /// hidden while [hasSupportPhone] is false rather than dialling anything.
  ///
  /// This was hardcoded to `"+911234567890"`, a placeholder that every call
  /// control in the app dialled: a driver escalating an accident was sent to a
  /// number that belongs to a stranger. Never hardcode a number here again —
  /// the value comes from the server or the controls stay hidden.
  static String supportPhoneNumber = "";

  /// True only when a real, admin-configured number is available to dial.
  static bool get hasSupportPhone => supportPhoneNumber.trim().isNotEmpty;

  /// Refresh [supportPhoneNumber] from [supportContactUrl].
  ///
  /// Never throws and never guesses: on any failure (network, non-200,
  /// unexpected body) the cached value is left exactly as it was, so a bad
  /// response can't turn "no helpline" into a dialled number.
  static Future<void> loadSupportContact() async {
    try {
      final response = await http
          .get(Uri.parse(supportContactUrl))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return;
      final body = json.decode(response.body);
      if (body is! Map) return;
      final data = body['data'];
      if (data is! Map) return;
      if (!data.containsKey('supportPhone')) return;
      supportPhoneNumber = (data['supportPhone'] ?? '').toString().trim();
    } catch (_) {
      // Leave the cached value untouched.
    }
  }

  // Incentives / Awards (real summary computed from completed bookings)
  static String driverIncentivesUrl = "$baseUrlApi/driver/app/incentives";
  // Bonuses actually awarded (the ledger), not the live tracker summary.
  static String driverIncentiveHistoryUrl =
      "$baseUrlApi/driver/app/incentives/history";
  // What customers said. The ratings always existed on bookings; nothing ever
  // showed them back to the driver.
  static String driverReviewsUrl = "$baseUrlApi/driver/app/reviews";
  // The inbox behind the bell in the bottom nav. The endpoint has always been
  // real (list + unreadCount + mark-read); the app simply had no screen for it.
  static String driverNotificationsUrl =
      "$baseUrlApi/driver/app/notifications";
}
