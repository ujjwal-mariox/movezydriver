import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:movezy_driver_app/AppNavigation/app_navigation.dart';
import 'package:movezy_driver_app/Screens/LoginScreen/login_screen.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';
import 'package:movezy_driver_app/Utils/PrefsManager/prefs_manager.dart';

/// Supported language codes in the app
const _supportedLanguageCodes = {
  'en', 'hi', 'ta', 'te', 'kn', 'mr', 'bn', 'gu', 'pa', 'ml', 'or', 'as', 'ur', 'ne',
};

/// Detect the best matching language from device locale.
/// Falls back to 'hi' if device language is not supported.
String _detectDeviceLanguage() {
  final deviceLocale = ui.PlatformDispatcher.instance.locale;
  final code = deviceLocale.languageCode;
  if (_supportedLanguageCodes.contains(code)) return code;
  return 'hi';
}

/// Shows a language selection bottom sheet popup
/// Returns the selected language code or null if cancelled
Future<String?> showLanguageSelectionPopup(BuildContext context, {String? currentLanguage}) async {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _LanguageSelectionBottomSheet(currentLanguage: currentLanguage),
  );
}

class _LanguageSelectionBottomSheet extends StatefulWidget {
  final String? currentLanguage;
  
  const _LanguageSelectionBottomSheet({this.currentLanguage});

  @override
  State<_LanguageSelectionBottomSheet> createState() => _LanguageSelectionBottomSheetState();
}

class _LanguageSelectionBottomSheetState extends State<_LanguageSelectionBottomSheet> {
  String? _selectedLanguage;

  static const List<LanguageOption> _languages = [
    LanguageOption(code: 'en', name: 'English', flag: '🇬🇧'),
    LanguageOption(code: 'hi', name: 'हिन्दी', flag: '🇮🇳'),
    LanguageOption(code: 'ta', name: 'தமிழ்', flag: '🇮🇳'),
    LanguageOption(code: 'te', name: 'తెలుగు', flag: '🇮🇳'),
    LanguageOption(code: 'kn', name: 'ಕನ್ನಡ', flag: '🇮🇳'),
    LanguageOption(code: 'mr', name: 'मराठी', flag: '🇮🇳'),
    LanguageOption(code: 'bn', name: 'বাংলা', flag: '🇮🇳'),
    LanguageOption(code: 'gu', name: 'ગુજરાતી', flag: '🇮🇳'),
    LanguageOption(code: 'pa', name: 'ਪੰਜਾਬੀ', flag: '🇮🇳'),
    LanguageOption(code: 'ml', name: 'മലയാളം', flag: '🇮🇳'),
    LanguageOption(code: 'or', name: 'ଓଡ଼ିଆ', flag: '🇮🇳'),
    LanguageOption(code: 'as', name: 'অসমীয়া', flag: '🇮🇳'),
    LanguageOption(code: 'ur', name: 'اردو', flag: '🇮🇳'),
    LanguageOption(code: 'ne', name: 'नेपाली', flag: '🇳🇵'),
  ];

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.currentLanguage ?? 'en';
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Container(
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.7,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with gradient background
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.appColor.withValues(alpha: 0.12),
                  Colors.white,
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Choose Language',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.appColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.close,
                          color: AppColors.appColor,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Scrollable Language grid
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.2,
                ),
                itemCount: _languages.length,
                itemBuilder: (context, index) {
                  final lang = _languages[index];
                  final isSelected = _selectedLanguage == lang.code;
                  
                  return GestureDetector(
                    onTap: () => setState(() => _selectedLanguage = lang.code),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? AppColors.appColor.withValues(alpha: 0.08)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppColors.appColor : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            lang.flag,
                            style: const TextStyle(fontSize: 22),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            lang.name,
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.w500,
                              height: 1.0,
                              letterSpacing: -0.36,
                              color: isSelected ? AppColors.appColor : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          
          // Continue button
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    if (_selectedLanguage != null) {
                      await Prefs.setString('selected_language', _selectedLanguage!);
                      await Prefs.setString('language_selected', 'true');
                      Get.updateLocale(Locale(_selectedLanguage!, 'IN'));
                      if (context.mounted) {
                        Navigator.pop(context, _selectedLanguage);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.appColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Language option model for the popup
class LanguageOption {
  final String code;
  final String name;
  final String flag;

  const LanguageOption({
    required this.code,
    required this.name,
    required this.flag,
  });
}

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  String? _selectedLanguage;

  static const List<_LanguageOption> _languages = [
    _LanguageOption(code: 'hi', name: 'हिन्दी', englishName: 'Hindi', icon: '🇮🇳'),
    _LanguageOption(code: 'en', name: 'English', englishName: 'English', icon: '🇬🇧'),
    _LanguageOption(code: 'ta', name: 'தமிழ்', englishName: 'Tamil', icon: '🇮🇳'),
    _LanguageOption(code: 'te', name: 'తెలుగు', englishName: 'Telugu', icon: '🇮🇳'),
    _LanguageOption(code: 'kn', name: 'ಕನ್ನಡ', englishName: 'Kannada', icon: '🇮🇳'),
    _LanguageOption(code: 'mr', name: 'मराठी', englishName: 'Marathi', icon: '🇮🇳'),
    _LanguageOption(code: 'bn', name: 'বাংলা', englishName: 'Bengali', icon: '🇮🇳'),
    _LanguageOption(code: 'gu', name: 'ગુજરાતી', englishName: 'Gujarati', icon: '🇮🇳'),
    _LanguageOption(code: 'pa', name: 'ਪੰਜਾਬੀ', englishName: 'Punjabi', icon: '🇮🇳'),
    _LanguageOption(code: 'ml', name: 'മലയാളം', englishName: 'Malayalam', icon: '🇮🇳'),
    _LanguageOption(code: 'or', name: 'ଓଡ଼ିଆ', englishName: 'Odia', icon: '🇮🇳'),
    _LanguageOption(code: 'as', name: 'অসমীয়া', englishName: 'Assamese', icon: '🇮🇳'),
    _LanguageOption(code: 'ur', name: 'اردو', englishName: 'Urdu', icon: '🇮🇳'),
    _LanguageOption(code: 'ne', name: 'नेपाली', englishName: 'Nepali', icon: '🇮🇳'),
  ];

  @override
  void initState() {
    super.initState();
    // Auto-suggest based on device locale
    _selectedLanguage = _detectDeviceLanguage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 40),

              // App logo
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.asset("assets/app_icon.png", width: 80, height: 80, fit: BoxFit.cover),
              ),
              const SizedBox(height: 24),

              // Title in Hindi + English
              const Text(
                'अपनी भाषा चुनें',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.black),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose your language',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 30),

              // Language grid
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.8,
                  ),
                  itemCount: _languages.length,
                  itemBuilder: (context, index) {
                    final lang = _languages[index];
                    final isSelected = _selectedLanguage == lang.code;

                    return GestureDetector(
                      onTap: () => setState(() => _selectedLanguage = lang.code),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.appColor.withValues(alpha: 0.08) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? AppColors.appColor : Colors.grey.shade300,
                            width: isSelected ? 2.5 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Native name (large)
                            Text(
                              lang.name,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? AppColors.appColor : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // English name (small)
                            Text(
                              lang.englishName,
                              style: TextStyle(
                                fontSize: 12,
                                color: isSelected ? AppColors.appColor : Colors.grey.shade500,
                              ),
                            ),
                            if (isSelected)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Icon(Icons.check_circle, color: AppColors.appColor, size: 18),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Continue button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _selectedLanguage != null
                      ? () async {
                          await Prefs.setString('selected_language', _selectedLanguage!);
                          await Prefs.setString('language_selected', 'true');
                          // Update app locale globally
                          Get.updateLocale(Locale(_selectedLanguage!, 'IN'));
                          if (!mounted) return;
                          // If this screen was pushed from inside the app (e.g.
                          // Profile → Language while logged in), just go back.
                          // Only on first-launch (opened from Splash, nothing to
                          // pop) do we route to Login.
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context, _selectedLanguage);
                          } else {
                            replaceRoute(context, const LoginScreen());
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.appColor,
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'जारी रखें  ',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      Text(
                        '/ Continue',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white70),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageOption {
  final String code;
  final String name;
  final String englishName;
  final String icon;

  const _LanguageOption({
    required this.code,
    required this.name,
    required this.englishName,
    required this.icon,
  });
}
