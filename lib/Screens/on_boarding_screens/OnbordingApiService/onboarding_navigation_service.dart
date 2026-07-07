import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:movezy_driver_app/ApiUrls/api_urls.dart';
import 'package:movezy_driver_app/AppNavigation/app_navigation.dart';
import 'package:movezy_driver_app/Screens/TechnicianDashboard/technician_dashboard.dart';
import 'package:movezy_driver_app/Screens/MyVehicles/my_vehicles.dart';
import 'package:movezy_driver_app/Screens/VerificationScreen/verification_screen.dart';
import 'package:movezy_driver_app/Screens/on_boarding_screens/add_vehicle_details_screen.dart';
import 'package:movezy_driver_app/Screens/on_boarding_screens/basic_details_screen.dart';
import 'package:movezy_driver_app/Screens/on_boarding_screens/driver_details_screen.dart';
import 'package:movezy_driver_app/Utils/PrefsManager/prefs_manager.dart';

class OnboardingNavigationService {
  /// Fetches the onboarding status from the backend and navigates
  /// to the correct step screen.
  ///
  /// Returns true if navigation was handled, false if it failed.
  static Future<bool> navigateToCurrentStep(BuildContext context) async {
    try {
      final response = await http.get(
        Uri.parse(ApiUrls.onboardingStatusUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Prefs.accessToken}',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        final data = body['data'];

        if (data == null) {
          // No data - start from beginning
          replaceRoute(context, BasicDetailsScreen());
          return true;
        }

        final String currentStep = data['currentStep'] ?? 'personal_info';
        final driver = data['driver'];
        final String driverStatus = driver?['status'] ?? '';

        debugPrint('Onboarding currentStep: $currentStep, driverStatus: $driverStatus');

        // Save current step locally for offline reference
        final savedStep = Prefs.getString('onboarding_step');
        final resolvedStep = _resolveStep(currentStep, savedStep, driverStatus);

        await Prefs.setString('onboarding_step', resolvedStep);

        _navigateToStep(context, resolvedStep, driverStatus);
        return true;
      } else {
        debugPrint('Onboarding status API failed: ${response.statusCode} ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Error fetching onboarding status: $e');

      // Fallback: try to use locally saved step
      final savedStep = Prefs.getString('onboarding_step');
      if (savedStep.isNotEmpty) {
        _navigateToStep(context, savedStep, '');
        return true;
      }

      return false;
    }
  }

  /// Resolve a final onboarding step using server data and local cached data.
  static String _resolveStep(String apiStep, String localStep, String driverStatus) {
    // If backend says active/approved/suspended, trust the driver status directly.
    if (driverStatus == 'active' || driverStatus == 'approved' || driverStatus == 'suspended') {
      return driverStatus == 'suspended' ? 'suspended' : 'active';
    }

    // Always trust the API step when available — local cache can be stale.
    if (apiStep.isNotEmpty) {
      return apiStep;
    }

    // Fallback to local cache only when API returns nothing.
    if (localStep.isNotEmpty) {
      return localStep;
    }

    return 'personal_info';
  }

  /// Navigate to the appropriate screen based on the onboarding step.
  static void _navigateToStep(BuildContext context, String currentStep, String driverStatus) {
    switch (currentStep) {
      case 'personal_info':
        // Step 1: Owner details (name, aadhar, pan, selfie)
        replaceRoute(context, BasicDetailsScreen());
        break;

      case 'kyc_documents':
        // KYC not complete - still on step 1 (documents)
        replaceRoute(context, BasicDetailsScreen());
        break;

      case 'vehicle_info':
        // Step 2: Vehicle details (RC, vehicle images)
        replaceRoute(context, AddVehicleDetailsScreen());
        break;

      case 'driver_details':
        // Step 3: Driver details (driving license, driver info)
        replaceRoute(context, DriverDetailsScreen());
        break;

      case 'ready_for_verification':
        // All steps done, pending submission
        replaceRoute(context, VerificationScreen());
        break;

      case 'under_verification':
        // Submitted, waiting for admin approval
        replaceRoute(context, VerificationScreen());
        break;

      case 'active':
      case 'approved':
        // Driver is approved - go to dashboard
        replaceRoute(context, TechnicianDashboard());
        break;

      case 'rejected':
        // Driver was rejected - go back to step 1 to re-upload
        replaceRoute(context, BasicDetailsScreen());
        break;

      case 'suspended':
        // Suspended - go to dashboard (it can show suspension message)
        replaceRoute(context, TechnicianDashboard());
        break;

      case 'draft':
        // New driver - start from beginning
        replaceRoute(context, BasicDetailsScreen());
        break;

      case 'documents_uploaded':
        // Documents done, need vehicle
        replaceRoute(context, AddVehicleDetailsScreen());
        break;

      case 'vehicle_added':
        // Vehicle added, go to my vehicles for payment
        replaceRoute(context, const MyVehiclesScreen());
        break;

      case 'my_vehicles':
        // Vehicles exist but not all paid
        replaceRoute(context, const MyVehiclesScreen());
        break;

      default:
        // Unknown step - check driver status
        if (driverStatus == 'active' || driverStatus == 'approved') {
          replaceRoute(context, TechnicianDashboard());
        } else {
          replaceRoute(context, BasicDetailsScreen());
        }
        break;
    }
  }

  /// Use cached onboarding step when API cannot be fetched.
  static void navigateToStepFromCache(BuildContext context) {
    final savedStep = Prefs.getString('onboarding_step');
    final step = savedStep.isNotEmpty ? savedStep : 'personal_info';
    _navigateToStep(context, step, '');
  }
}
