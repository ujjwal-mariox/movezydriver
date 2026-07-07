import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:movezy_driver_app/AppNavigation/app_navigation.dart';
import 'package:movezy_driver_app/Screens/LoginScreen/login_screen.dart';
import 'package:movezy_driver_app/Utils/PrefsManager/prefs_manager.dart';

Widget onboardingLogoutAction(BuildContext context) {
  return InkWell(
    onTap: () => _confirmAndLogout(context),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Text(
        'logout'.tr,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}

Future<void> _confirmAndLogout(BuildContext context) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('logout'.tr),
      content: const Text('Are you sure you want to logout?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text('cancel'.tr),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(
            'logout'.tr,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ],
    ),
  );

  if (confirm != true) return;

  Prefs.setBool('check_log_in', false);
  Prefs.setString('mobile_number', '');
  Prefs.setString('onboarding_step', '');
  await Prefs.load();
  Prefs.loadData();

  if (!context.mounted) return;
  replaceRoute(context, LoginScreen());
}
