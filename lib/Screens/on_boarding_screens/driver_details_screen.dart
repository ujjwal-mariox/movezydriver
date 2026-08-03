import 'package:get/get.dart';
import 'dart:io';
import 'package:movezy_driver_app/AppNavigation/app_navigation.dart';
import 'package:movezy_driver_app/CommonWidgets/button_widget.dart';
import 'package:movezy_driver_app/Utils/PrefsManager/prefs_manager.dart';
import 'package:movezy_driver_app/CommonWidgets/edit_text_controller.dart';
import 'package:movezy_driver_app/Screens/AadharCaptureScreen/capture_screen.dart';
import 'package:movezy_driver_app/Screens/on_boarding_screens/OnbordingApiService/on_boarding_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';
import 'package:movezy_driver_app/Utils/CustomToast/custome_toast.dart';
import 'package:movezy_driver_app/CommonWidgets/onboarding_stepper.dart';
import 'package:movezy_driver_app/Screens/HelpSupportScreen/help_support_screen.dart';
import 'package:movezy_driver_app/Screens/on_boarding_screens/onboarding_logout_action.dart';


class DriverDetailsScreen extends StatefulWidget {
  const DriverDetailsScreen({super.key});

  @override
  State<DriverDetailsScreen> createState() => _DriverDetailsScreenState();
}

class _DriverDetailsScreenState extends State<DriverDetailsScreen> {
  var driverNameController = TextEditingController();
  var phoneNumberController = TextEditingController();
  String? driverLicence;

  bool willDriveVehicle = true;
  String _ownerName = '';
  String _ownerPhone = '';

  @override
  void initState() {
    super.initState();
    _ownerName = Prefs.getString('owner_name').trim();
    _ownerPhone = Prefs.getString('mobile_number').trim();
    // Default "Yes" — auto-fill owner info
    if (_ownerName.isNotEmpty) driverNameController.text = _ownerName;
    if (_ownerPhone.isNotEmpty) phoneNumberController.text = _ownerPhone;
  }

  @override
  void dispose() {
    driverNameController.dispose();
    phoneNumberController.dispose();
    super.dispose();
  }

  void _onDriveVehicleSelection(bool willDrive) {
    if (willDrive) {
      if (_ownerName.isNotEmpty) {
        driverNameController.text = _ownerName;
      }
      if (_ownerPhone.isNotEmpty) {
        phoneNumberController.text = _ownerPhone;
      }
    } else {
      driverNameController.clear();
      phoneNumberController.clear();
      driverLicence = null;
    }
    setState(() => willDriveVehicle = willDrive);
  }


  @override
  Widget build(BuildContext context) {

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // for Android
      statusBarBrightness: Brightness.dark, // for iOS
      )
    );

    return Scaffold(
      backgroundColor: Colors.white,
      // top: false — the bar owns only the bottom edge. Without this the 90pt
      // box ends at the screen edge and the gesture bar / nav buttons sit on
      // top of "Save & Continue", making it untappable. SafeArea reads the real
      // device inset (and correctly reports 0 while the keyboard is up, so the
      // button still rides directly above the keyboard on this form).
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
        height: 90,
        decoration: BoxDecoration(color: Colors.grey[100]),
        child: Column(
          children: [

            SizedBox(height: 16,),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: ButtonWidget(
                onTap: () {
                  if (driverNameController.text.trim().isEmpty) {
                    showCustomToast(context, 'please_enter_driver_name'.tr);
                    return;
                  }
                  if (phoneNumberController.text.trim().isEmpty) {
                    showCustomToast(context, 'please_enter_phone'.tr);
                    return;
                  }
                  if (driverLicence == null) {
                    showCustomToast(context, 'please_add_licence'.tr);
                    return;
                  }

                  // Save step so app can resume from driver_details if needed.
                  Prefs.setString('onboarding_step', 'driver_details');

                  var params = {
                    "willDriveVehicle": willDriveVehicle == true ? "yes" : "no",
                    "driverName": driverNameController.text.trim(),
                    "driverPhone": phoneNumberController.text.trim(),
                    "driverLicence": driverLicence?.toString() ?? '',
                  };

                  OnBoardingApiService().addLicenceApi(context, params);
                },
                borderRadius: BorderRadius.circular(12),
                text: 'save_continue'.tr,
                backgroundColor: AppColors.appColor,
              ),
            ),

            SizedBox(height: 16,),
          ],
        ),
        ),
      ),
      body: SingleChildScrollView(
        child: Container(
          child: Column(
            children: [
              Container(
                height: 95,
                padding: const EdgeInsets.only(top: 38),
                color: AppColors.appColor,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    InkWell(
                      onTap: ()
                      {
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: EdgeInsets.only(left: 16),
                        width: 40,
                        height: 35,
                        alignment: Alignment.center,
                        child: Image.asset("assets/back_arrow.png", color: Colors.white,),
                      ),
                    ),

                    SizedBox(width: 9,),

                    Text(
                      'onboarding'.tr,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    Spacer(),

                    onboardingLogoutAction(context),

                    SizedBox(width: 15,)
                  ],
                ),
              ),

              const OnboardingStepper(currentStep: 2),

              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: InkWell(
                  onTap: () => _onDriveVehicleSelection(!willDriveVehicle),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        Checkbox(
                          value: willDriveVehicle,
                          onChanged: (value) => _onDriveVehicleSelection(value ?? false),
                          activeColor: AppColors.appColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                        Expanded(
                          child: Text(
                            'driver_same_as_owner'.tr,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              Container(
                color: Colors.white,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    SizedBox(height: 17,),

                    Container(
                        margin: EdgeInsets.only(left: 15, right: 15),
                        child: editTextWidget(
                            context: context,
                            controller: driverNameController,
                            hintText: 'enter_driver_name'.tr,
                            isOptional: false,
                            labelText: 'driver_name'.tr
                        )
                    ),
                    SizedBox(height: 12,),

                    Container(
                        margin: EdgeInsets.only(left: 15, right: 15),
                        child: editTextWidget(
                            context: context,
                            controller: phoneNumberController,
                            hintText: 'enter_phone'.tr,
                            isOptional: false,
                            labelText: 'driver_phone'.tr
                        )
                    ),

                    SizedBox(height: 25,),

                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: 18,),
                        Container(
                            margin: EdgeInsets.only(bottom: 6),
                            child: Text('upload_driver_license'.tr, style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w600),)
                        ),

                        Container(
                            margin: EdgeInsets.only(bottom: 6),
                            child: Text("*", style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600),)
                        ),
                      ],
                    ),

                    Padding(
                      padding: const EdgeInsets.only(left: 18, bottom: 8),
                      child: Text('helper_dl'.tr, style: TextStyle(color: Colors.grey, fontSize: 11)),
                    ),

                    InkWell(
                      onTap: () async {
                       var res = await pushTo(context, CaptureScreen(title: 'capture_dl_front'.tr,imageIcon: "assets/aadhar_card.png",description: 'dl_front_desc'.tr,));

                       if(res != null)
                         {
                           driverLicence = res;
                         }
                       setState(() {});
                      },
                      child: Container(
                        margin: EdgeInsets.only(left: 15, right: 15),
                        child: driverLicence != null ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            height: 150,
                              width: MediaQuery.of(context).size.width,
                              child: Image.file(File(driverLicence.toString()), fit: BoxFit.cover,)),
                        ) : Image.asset('assets/upload_licence_image.png'),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20,),

              // Need Help? Call Us
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    Get.to(() => const HelpSupportScreen());
                  },
                  icon: Icon(Icons.headset_mic, color: AppColors.appColor, size: 18),
                  label: Text('need_help_call'.tr, style: TextStyle(color: AppColors.appColor, fontWeight: FontWeight.w600, fontSize: 14)),
                ),
              ),

              SizedBox(height: 10,),
            ],
          ),
        ),
      ),
    );
  }
}
