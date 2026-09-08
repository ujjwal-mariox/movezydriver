import 'package:movezy_driver_app/CommonWidgets/network_indicator.dart';
import 'package:movezy_driver_app/Services/booking_ring_service.dart';
import 'package:movezy_driver_app/Services/background_presence_service.dart';
import 'package:movezy_driver_app/Services/app_lifecycle_service.dart';
import 'package:movezy_driver_app/Routes/app_routes.dart';
import 'package:movezy_driver_app/Services/booking_alert_service.dart';
import 'package:movezy_driver_app/Utils/Localization/app_translations.dart';
import 'package:movezy_driver_app/Utils/OfflineStorage/offline_service.dart';
import 'package:movezy_driver_app/Utils/PrefsManager/prefs_manager.dart';
import 'package:movezy_driver_app/Utils/VoiceService/voice_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Prefs.load();
  Prefs.loadData();

  // Initialize background services so widgets can Get.find<> them safely.
  await Get.putAsync<OfflineService>(() => OfflineService().init());
  await Get.putAsync<VoiceService>(() => VoiceService().init());

  // Booking alerts belong to the app, not to a screen — but connect() was only
  // ever CALLED from the dashboard's initState, so a session that hadn't
  // mounted the dashboard yet (or logged in on another screen) had no listener
  // and the global popup never fired. Start it here when a session already
  // exists; connect() is a no-op without a token, and login/dashboard still
  // call it (idempotent) for sessions that begin after startup.
  // Ring + notifications for offers, foreground service for staying online
  // with the screen locked, and resume hooks — all app-lifetime.
  await BookingRingService.instance.init();
  BookingRingService.instance.onNotificationTap =
      BookingAlertService.instance.handleNotificationTap;
  await BackgroundPresenceService.init();
  AppLifecycleService.instance.register();

  BookingAlertService.instance.connect();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Locale _getSavedLocale() {
    final code = Prefs.getString('selected_language');
    if (code.isNotEmpty) {
      return Locale(code, 'IN');
    }
    return const Locale('en', 'IN');
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      navigatorKey: Get.key,
      debugShowCheckedModeBanner: false,
      translations: AppTranslations(),
      locale: _getSavedLocale(),
      fallbackLocale: const Locale('en', 'IN'),
      title: 'Movezy Driver',
      theme: ThemeData(
        textTheme: GoogleFonts.poppinsTextTheme(
          Theme.of(context).textTheme,
        ),
        fontFamily: GoogleFonts.poppins().fontFamily,
      ),
      initialRoute: AppRoutes.initialRoute,
      getPages: AppRoutes.pages,
      builder: (context, child) {
        // Wraps every screen with a persistent NetworkIndicator and a floating
        // sync badge that surfaces pending offline trip uploads.
        return Stack(
          children: [
            Column(
              children: [
                const NetworkIndicator(),
                Expanded(child: child ?? const SizedBox.shrink()),
              ],
            ),
            const Positioned(
              top: 8,
              right: 8,
              child: SafeArea(
                child: SyncStatusWidget(),
              ),
            ),
          ],
        );
      },
    );
  }
}
