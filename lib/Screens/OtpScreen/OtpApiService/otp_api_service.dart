import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:movezy_driver_app/ApiUrls/api_urls.dart';
import 'package:movezy_driver_app/AppNavigation/app_navigation.dart';
import 'package:movezy_driver_app/Screens/LoginScreen/Model/login_response.dart';
import 'package:movezy_driver_app/Screens/OtpScreen/Model/otp_response.dart';
import 'package:movezy_driver_app/Screens/on_boarding_screens/OnbordingApiService/onboarding_navigation_service.dart';
import 'package:movezy_driver_app/Screens/TechnicianDashboard/technician_dashboard.dart';
import 'package:movezy_driver_app/Screens/TechnicianDashboard/dashboard_api_service.dart';
import 'package:movezy_driver_app/Screens/on_boarding_screens/basic_details_screen.dart';
import 'package:movezy_driver_app/Utils/CustomToast/custome_toast.dart';
import 'package:movezy_driver_app/Utils/PrefsManager/prefs_manager.dart';
import 'package:http/http.dart' as http;

class OtpApiService {
  Future<bool> otpVerifyApi({required BuildContext context,required String otp, required String mobileNumber, required String token}) async {
    try {
      var params = {
        "txnId": token,
        "otp": otp
      };

      var response = await http.post(
          Uri.parse(ApiUrls.otpUrlVerify),
          body: json.encode(params),
          headers: {
            'Content-Type': 'application/json',
          }
      ).timeout(const Duration(seconds: 30));

      var dataT = otpResponseFromJson(response.body);

      if(response.statusCode == 200 && dataT.code == 1)
        {
          await Prefs.setString('access_token', dataT.data?.token ?? "");
          await Prefs.setBool('check_log_in', true);
          await Prefs.setString('mobile_number', mobileNumber);
          // Clear any stale onboarding step from previous sessions
          await Prefs.setString('onboarding_step', '');
          Prefs.loadData();

          // Sync language preference: save local choice to backend,
          // or load backend preference if no local selection
          await _syncLanguagePreference();

          // Check onboarding status and navigate to the correct step
          final navigated = await OnboardingNavigationService.navigateToCurrentStep(context);
          if (!navigated) {
            // Fallback: if API call fails, check isNewDriver from OTP response
            if (dataT.data?.isNewDriver == true) {
              replaceRoute(context, BasicDetailsScreen());
            } else {
              // Existing driver - use status from OTP response
              final status = dataT.data?.status ?? 'draft';
              if (status == 'approved' || status == 'active') {
                replaceRoute(context, TechnicianDashboard());
              } else {
                replaceRoute(context, BasicDetailsScreen());
              }
            }
          }
        }
      else
        {
          showCustomToast(context, dataT.message.toString(),);
        }
      return true;
    } catch (e) {
      showCustomToast(context, 'network_error'.tr);
      return false;
    }
  }



  /// Sync language preference between local and backend.
  /// If the user selected a language locally before login, push it to backend.
  /// If no local selection but backend has one, apply it locally.
  Future<void> _syncLanguagePreference() async {
    final apiService = DashboardApiService();
    final localLang = Prefs.getString('selected_language');

    if (localLang.isNotEmpty) {
      // User already selected a language locally — save to backend
      apiService.saveLanguagePreference(localLang);
    } else {
      // No local selection — try to load from backend
      final backendLang = await apiService.getLanguagePreference();
      if (backendLang != null && backendLang.isNotEmpty) {
        await Prefs.setString('selected_language', backendLang);
        await Prefs.setString('language_selected', 'true');
        Get.updateLocale(Locale(backendLang, 'IN'));
      }
    }
  }

  Future<LoginResponse?> resendOtp(BuildContext context, String mobileNumber) async {
    try {
      var params = {
        "countryCode": "+91",
        "mobileNumber": mobileNumber
      };

      var response = await http.post(
          Uri.parse(ApiUrls.loginUrl),
          body: json.encode(params),
          headers: {
            'Content-Type': 'application/json',
          }
      ).timeout(const Duration(seconds: 30));

      return loginResponseFromJson(response.body);
    } catch (e) {
      showCustomToast(context, 'network_error'.tr);
      return null;
    }
  }
}