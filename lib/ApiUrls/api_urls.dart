

class ApiUrls {
  // Physical device → local backend on this PC's LAN IP (phone on same WiFi)
  static String baseUrlApi = "http://192.168.1.34:9050/v1/api";
  // Production API endpoint
  // static String baseUrlApi = "https://movize-backend.maidkart.in/v1/api";
  // Local development: Android emulator uses 10.0.2.2 to reach host machine's localhost
  // static String baseUrlApi = "http://10.0.2.2:9050/v1/api";

  static String loginUrl = "$baseUrlApi/driver/login";

  static String otpUrlVerify = "$baseUrlApi/driver/verify-otp";

  static String detailsUrl = "$baseUrlApi/driver/personal-info";

  // Bank details save (writes driver.bankDetails) — distinct from personal-info
  static String driverBankDetailsUrl = "$baseUrlApi/driver/app/bank-details";
  // Support tickets (driver) — create + list + thread + reply
  static String driverRaiseTicketUrl = "$baseUrlApi/driver/app/support/ticket";
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
  static String socketUrl = "http://192.168.1.34:9050";
  // static String socketUrl = "https://movize-backend.maidkart.in";

  // Vehicle Referral
  static String vehicleApplyReferralUrl(String vehicleId) => "$baseUrlApi/driver/app/my-vehicles/$vehicleId/apply-referral";

  // SOS / Emergency
  static String sosTriggerUrl = "$baseUrlApi/driver/app/sos/trigger";

  // Support phone number shown in Help & Support call actions. PLACEHOLDER —
  // replace with the real support line before release (single source of truth;
  // previously this number was hardcoded in 3 places in help_support_screen).
  static String supportPhoneNumber = "+911234567890";

  // Incentives / Awards (real summary computed from completed bookings)
  static String driverIncentivesUrl = "$baseUrlApi/driver/app/incentives";
}
