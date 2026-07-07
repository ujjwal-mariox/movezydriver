import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:movezy_driver_app/AppNavigation/app_navigation.dart';
import 'package:movezy_driver_app/Screens/LanguageScreen/language_selection_screen.dart';
import 'package:movezy_driver_app/Screens/LoginScreen/login_screen.dart';
import 'package:movezy_driver_app/Screens/on_boarding_screens/OnbordingApiService/onboarding_navigation_service.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';
import 'package:movezy_driver_app/Utils/PermissionService/permission_service.dart';
import 'package:movezy_driver_app/Utils/PrefsManager/prefs_manager.dart';


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    Future.delayed(Duration(seconds: 3), () async {

      print("Prefs.check_log_in ${Prefs.check_log_in}");
      print("Prefs.mobile_number ${Prefs.mobile_number}");

      await Prefs.load();
      Prefs.loadData();

      // Request all permissions on first launch
      if (context.mounted) {
        await PermissionService.requestAllPermissions(context);
      }
      // Show language selection if not chosen yet
      final languageSelected = Prefs.getString('language_selected');
      if (languageSelected.isEmpty) {
        replaceRoute(context, const LanguageSelectionScreen());
        return;
      }

      if(Prefs.check_log_in == true)
        {
          // Check onboarding status from backend to redirect to correct step
          final navigated = await OnboardingNavigationService.navigateToCurrentStep(context);
          if (!navigated) {
            // Fallback: if API fails, use locally saved step.
            OnboardingNavigationService.navigateToStepFromCache(context);
          }
        }
      else
        {
          replaceRoute(context, LoginScreen());
        }
     });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.dark,
    ));

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.appColor, // light green background
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top spacer for status bar
          const SizedBox(height: 120),

          // Center logo
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Container(
                      height: 180,
                      width: 180,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Image.asset(
                        "assets/app_icon.png", // <-- put your logo here
                        width: 220,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),


          Image.asset(
            "assets/building_image.png", // <-- put your logo here
            width: MediaQuery.of(context).size.width,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }
}
