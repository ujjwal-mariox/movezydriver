import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:movezy_driver_app/ApiUrls/api_urls.dart';
import 'package:movezy_driver_app/CommonWidgets/button_widget.dart';
import 'package:movezy_driver_app/Screens/LanguageScreen/language_selection_screen.dart';
import 'package:movezy_driver_app/Screens/LoginScreen/LoginApiService/login_api_service.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';
import 'package:movezy_driver_app/Utils/CustomToast/custome_toast.dart';
import 'package:movezy_driver_app/Utils/PrefsManager/prefs_manager.dart';
import 'package:hexcolor/hexcolor.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isChecked = false;
  bool showLoader = false;

  /// Call the support line. Same pattern as HelpSupportScreen/FaqScreen.
  /// NOTE: ApiUrls.supportPhoneNumber is still the placeholder +911234567890 —
  /// replace it with the real line before release.
  Future<void> _callSupport() async {
    final uri = Uri(scheme: 'tel', path: ApiUrls.supportPhoneNumber);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else if (mounted) {
        showCustomToast(context, 'Could not open the dialer');
      }
    } catch (_) {
      if (mounted) showCustomToast(context, 'Could not open the dialer');
    }
  }

  static const Map<String, String> _langNames = {
    'hi': 'हिन्दी',
    'en': 'English',
    'ta': 'தமிழ்',
    'te': 'తెలుగు',
    'kn': 'ಕನ್ನಡ',
    'mr': 'मराठी',
    'bn': 'বাংলা',
    'gu': 'ગુજરાતી',
    'pa': 'ਪੰਜਾਬੀ',
    'ml': 'മലയാളം',
    'or': 'ଓଡ଼ିଆ',
    'as': 'অসমীয়া',
    'ur': 'اردو',
    'ne': 'नेपाली',
  };

  String get _selectedLangLabel {
    final code = Prefs.getString('selected_language');
    return _langNames[code] ?? 'भाषा';
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: SizedBox(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          child: Stack(
            children: [

              SizedBox(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height * 0.45,
                child: Stack(
                  children: [

                    Container(
                      height: MediaQuery.of(context).size.height * 0.45,
                      width: MediaQuery.of(context).size.width,
                      color: HexColor("#FF6200"),
                    ),

                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      top: 0,
                      child: Image.asset(
                        width: MediaQuery.of(context).size.width,
                        height: 300,
                        "assets/trucks_icon.png",
                        fit: BoxFit.fill,
                      ),
                    ),

                    Positioned(
                      bottom: 50,
                      left: 0,
                      right: 0,
                      child: Column(
                        children: [
                          SizedBox(
                            width: 100,
                            child: Image.asset(
                              width: 100,
                              height: 100,
                              "assets/track_trip.png",
                            ),
                          ),

                          SizedBox(height: 20,),

                          Container(
                            margin: EdgeInsets.only(left: 30, right: 30),
                            child: Center(
                              child: Text.rich(
                                TextSpan(
                                  text: "Track trips ",
                                  style: TextStyle(fontSize: 21, color: Colors.amber, fontWeight: FontWeight.bold),
                                  children: [
                                    TextSpan(
                                      text: "from pickup \nto drop",
                                      style:  TextStyle(
                                        fontSize: 21,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Positioned(
                      top: 55,
                      right: 20,
                      child: Row(
                        children: [
                          // Language switcher
                          GestureDetector(
                            onTap: () async {
                              final selectedLang = await showLanguageSelectionPopup(
                                context,
                                currentLanguage: Prefs.getString('selected_language'),
                              );
                              if (selectedLang != null) {
                                setState(() {});
                              }
                            },
                            child: Container(
                              height: 35,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.white, width: 0.3),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.language, color: Colors.white, size: 20),
                                  const SizedBox(width: 6),
                                  Text(_selectedLangLabel, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Help button
                          // Was a bare Container with no onTap — it looked like
                          // a button and did nothing. Pre-login the driver has
                          // no account yet, so calling support is the only
                          // help we can actually offer here.
                          GestureDetector(
                            onTap: _callSupport,
                            child: Container(
                              height: 35,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.white, width: 0.3),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(width: 10),
                                  Image.asset("assets/headphones.png", color: Colors.white, width: 22, height: 22),
                                  SizedBox(width: 10),
                                  Text('help'.tr, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                                  SizedBox(width: 10),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),

              Positioned(
                top: MediaQuery.of(context).size.height * 0.42,
                left: 0,
                right: 0,
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.58,
                  // This card is flush with the bottom of the screen, so its
                  // last rows (the terms line and the WhatsApp opt-in checkbox)
                  // sat under the gesture bar / 3-button nav. The widget that
                  // owns the bottom edge reserves the device's real inset once,
                  // instead of trusting the trailing SizedBox(10).
                  // viewPadding, not padding: padding.bottom drops to 0 while
                  // the number keypad is open, which made the whole card jump
                  // down over the gesture bar the moment the field was tapped.
                  padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewPadding.bottom),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25))
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.24,
                        child: Image.asset("assets/app_icon.png"),
                      ),

                      // Phone number label
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        width: MediaQuery.of(context).size.width,
                        alignment: Alignment.topLeft,
                        child: Text(
                          'login_title'.tr,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.black
                          ),
                        ),
                      ),

                      SizedBox(height: 20,),

                      // Phone number input
                      Container(
                        margin: EdgeInsets.only(left: 16, right: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: HexColor("#B8B8B8")),
                        ),
                        child: TextField(
                          maxLength: 10,
                          controller: _phoneController,
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9]')),
                          ],
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            counterText: "",
                            hintText: 'enter_phone'.tr,
                            hintStyle: TextStyle(color: HexColor("#B8B8B8")),
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 10,),

                      Expanded(child: Container(height: 0,)),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: ButtonWidget(
                          text: 'get_otp'.tr,
                          textStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                          backgroundColor: AppColors.appColor,
                          borderRadius: BorderRadius.circular(10),
                          onTap: () async {
                            if(_phoneController.text.toString() == "")
                            {
                              showCustomToast(context, 'please_enter_mobile'.tr);
                            }
                            else if(_phoneController.text.toString().length != 10)
                            {
                              showCustomToast(context, 'please_enter_valid_mobile'.tr);
                            }
                            else
                            {
                              setState(() {
                                showLoader = true;
                              });

                              await LoginApiService().loginApi(context, _phoneController.text.toString());

                              setState(() {
                                showLoader = false;
                              });
                            }
                          },
                        ),
                      ),

                      SizedBox(height: 10,),

                      Expanded(child: Container(height: 0,)),

                      Container(
                        width: MediaQuery.of(context).size.width,
                        margin: EdgeInsets.only(left: 15, right: 15),
                        alignment: Alignment.center,
                        child: Text.rich(
                            TextSpan(
                              text: 'terms_prefix'.tr,
                              style: TextStyle(fontSize: 9, color: Colors.black, fontWeight: FontWeight.bold),
                              children: [
                                TextSpan(
                                  text: 'terms_of_use'.tr,
                                  style:  TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: HexColor("#0082DF"),
                                  ),
                                ),
                                TextSpan(
                                  text: 'and'.tr,
                                  style:  TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                TextSpan(
                                  text: 'privacy_policy'.tr,
                                  style:  TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: HexColor("#0082DF"),
                                  ),
                                ),
                              ],
                            )
                        ),
                      ),

                      Expanded(child: Container(height: 0,)),

                      SizedBox(height: 10,),

                      // Checkbox
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            InkWell(
                              onTap : (){
                                if(_isChecked == true)
                                {
                                  _isChecked = false;
                                }
                                else
                                {
                                  _isChecked = true;
                                }

                                setState(() {});
                              },
                              child: Container(
                                height: 25,
                                width: 25,
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.black, width: 1.5)
                                ),
                                child: _isChecked == true ? Icon(Icons.check_outlined, size: 20,color: Colors.black) : Container(width: 0,),
                              ),
                            ),

                            SizedBox(width: 7,),

                            Text('get_notifications'.tr, style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w500),),

                            SizedBox(width: 5,),

                            Image.asset("assets/whats_app_icon.png", width: 22,height: 22,),

                            SizedBox(width: 5,),

                            Text('whatsapp'.tr, style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w500),),
                          ],
                        ),
                      ),

                      Expanded(child: Container(height: 0,)),

                      SizedBox(height: 10,),
                    ],
                  ),
                ),
              ),

              if(showLoader == true)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                top: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                        height: 40,
                        width: 40,
                        child: CircularProgressIndicator()
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

}
