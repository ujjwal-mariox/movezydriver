import 'package:movezy_driver_app/CommonWidgets/network_indicator.dart';
import 'package:movezy_driver_app/Routes/app_routes.dart';
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
