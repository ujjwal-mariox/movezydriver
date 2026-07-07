import 'dart:io';
import 'package:movezy_driver_app/AppNavigation/app_navigation.dart';
import 'package:movezy_driver_app/CommonWidgets/button_widget.dart';
import 'package:movezy_driver_app/CommonWidgets/edit_text_controller.dart';
import 'package:movezy_driver_app/Screens/AadharCaptureScreen/capture_screen.dart';
import 'package:movezy_driver_app/Screens/on_boarding_screens/OnbordingApiService/on_boarding_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:movezy_driver_app/Screens/on_boarding_screens/add_vehicle_details_screen.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';
import 'package:movezy_driver_app/Utils/CustomToast/custome_toast.dart';
import 'package:movezy_driver_app/Utils/PrefsManager/prefs_manager.dart';
import 'package:movezy_driver_app/CommonWidgets/onboarding_stepper.dart';
import 'package:movezy_driver_app/Screens/HelpSupportScreen/help_support_screen.dart';
import 'package:movezy_driver_app/Utils/DocumentValidator/document_validator.dart';
import 'package:movezy_driver_app/Screens/on_boarding_screens/onboarding_logout_action.dart';


class BasicDetailsScreen extends StatefulWidget {
  const BasicDetailsScreen({super.key});
  @override
  State<BasicDetailsScreen> createState() => _BasicDetailsScreenState();
}

class _BasicDetailsScreenState extends State<BasicDetailsScreen> {
  var ownerNameController = TextEditingController();
  String? ownerAdharFrontCard;
  String? ownerAdharBackCard;
  String? ownerPanCard;
  String? ownerSelfieCard;
  bool isUploading = false;

  @override
  void dispose() {
    ownerNameController.dispose();
    super.dispose();
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
      bottomNavigationBar: Container(
        height: 90,
        decoration: BoxDecoration(color: Colors.grey[100]),
        child: Column(
          children: [

            SizedBox(height: 16,),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: ButtonWidget(
                onTap: () async
                {
                  if(ownerNameController.text.toString() == "")
                  {
                    showCustomToast(context, 'please_enter_owner_name'.tr);
                  }
                  else if(ownerAdharFrontCard == null)
                  {
                    showCustomToast(context, 'please_add_aadhar'.tr);
                  }
                  else if(ownerAdharBackCard == null)
                  {
                    showCustomToast(context, 'Please add Aadhaar back side');
                  }
                  else if(ownerPanCard == null)
                  {
                    showCustomToast(context, 'please_add_pan'.tr);
                  }
                  else if(ownerSelfieCard == null)
                  {
                    showCustomToast(context, 'please_add_selfie'.tr);
                  }
                  else
                    {
                      setState(() { isUploading = true; });
                      await Prefs.setString('owner_name', ownerNameController.text.trim());

                      // Single API call: upload name + Aadhaar + PAN + Selfie together
                      final result = await OnBoardingApiService().uploadOwnerDetails(
                        ownerName: ownerNameController.text.toString(),
                        aadhaarFrontImage: File(ownerAdharFrontCard.toString()),
                        aadhaarBackImage: File(ownerAdharBackCard.toString()),
                        panImage: File(ownerPanCard.toString()),
                        selfieImage: File(ownerSelfieCard.toString()),
                        context: context,
                      );

                      setState(() { isUploading = false; });

                      if (result['success'] == true) {
                        await Prefs.setString('onboarding_step', 'vehicle_info');
                        pushTo(context, AddVehicleDetailsScreen());
                      } else {
                        showCustomToast(context, "Upload failed: ${result['message']}");
                      }
                    }
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
      body: Stack(
        children: [
          SingleChildScrollView(
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

              const OnboardingStepper(currentStep: 0),

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
                            controller: ownerNameController,
                            hintText: 'enter_owner_name'.tr,
                            isOptional: false,
                            labelText: 'enter_owner_name'.tr
                        )
                    ),

                    SizedBox(height: 25,),

                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: 18,),
                        Container(
                            margin: EdgeInsets.only(bottom: 6),
                            child: Text('owner_aadhar_card'.tr, style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w600),)
                        ),

                        Container(
                            margin: EdgeInsets.only(bottom: 6),
                            child: Text("*", style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600),)
                        ),
                      ],
                    ),

                    Padding(
                      padding: const EdgeInsets.only(left: 18, bottom: 8),
                      child: Text('helper_aadhaar'.tr, style: TextStyle(color: Colors.grey, fontSize: 11)),
                    ),

                    InkWell(
                      onTap: () async {
                       var res = await pushTo(context, CaptureScreen(
                         title: "Aadhaar Front",
                         imageIcon: "assets/aadhar_card.png",
                         description: "Aadhaar Card — Front Side",
                         expectedDocumentType: DocumentType.aadhaar,
                         nextCapture: NextCaptureConfig(
                           title: "Aadhaar Back",
                           imageIcon: "assets/aadhar_card.png",
                           description: "Aadhaar Card — Back Side",
                           expectedDocumentType: DocumentType.aadhaar,
                         ),
                       ));

                       if(res != null && res is List<String> && res.length == 2)
                         {
                           ownerAdharFrontCard = res[0];
                           ownerAdharBackCard = res[1];
                           // Auto-extract name from Aadhaar
                           if (ownerNameController.text.trim().isEmpty) {
                             final extracted = await DocumentValidator.extractData(
                               File(res[0]), DocumentType.aadhaar,
                             );
                             if (extracted['name'] != null && extracted['name']!.isNotEmpty) {
                               ownerNameController.text = extracted['name']!;
                             }
                           }
                         }
                       setState(() {});
                      },
                      child: Container(
                        margin: EdgeInsets.only(left: 15, right: 15),
                        child: ownerAdharFrontCard != null && ownerAdharBackCard != null
                          ? Column(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: SizedBox(
                                    height: 120,
                                    width: MediaQuery.of(context).size.width,
                                    child: Image.file(File(ownerAdharFrontCard.toString()), fit: BoxFit.cover,)),
                                ),
                                SizedBox(height: 8,),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: SizedBox(
                                    height: 120,
                                    width: MediaQuery.of(context).size.width,
                                    child: Image.file(File(ownerAdharBackCard.toString()), fit: BoxFit.cover,)),
                                ),
                              ],
                            )
                          : Image.asset('assets/front_side_upload_icon.png'),
                      ),
                    ),

                    SizedBox(height: 25,),

                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: 18,),
                        Container(
                            margin: EdgeInsets.only(bottom: 6),
                            child: Text('owner_pan_card'.tr, style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w600),)
                        ),

                        Container(
                            margin: EdgeInsets.only(bottom: 6),
                            child: Text("*", style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600),)
                        ),
                      ],
                    ),

                    Padding(
                      padding: const EdgeInsets.only(left: 18, bottom: 8),
                      child: Text('helper_pan'.tr, style: TextStyle(color: Colors.grey, fontSize: 11)),
                    ),

                    InkWell(
                      onTap: () async {
                        var res = await pushTo(context, CaptureScreen(title: "PAN Card",imageIcon: "assets/pan_card.png",description: "PAN Card — Front Side", expectedDocumentType: DocumentType.pan,));

                        if(res != null)
                          {
                            ownerPanCard = res;
                          }

                        setState(() {});
                      },
                      child: Container(
                        margin: EdgeInsets.only(left: 15, right: 15),
                        child: ownerPanCard != null ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                              height: 150,
                              width: MediaQuery.of(context).size.width,
                              child: Image.file(File(ownerPanCard.toString()), fit: BoxFit.cover,)),
                        ) : Image.asset('assets/back_side_upload_icon.png'),
                      ),
                    ),

                    SizedBox(height: 25,),

                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: 18,),
                        Container(
                            margin: EdgeInsets.only(bottom: 6),
                            child: Text('owner_selfie'.tr, style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w600),)
                        ),

                        Container(
                            margin: EdgeInsets.only(bottom: 6),
                            child: Text("*", style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600),)
                        ),
                      ],
                    ),

                    Padding(
                      padding: const EdgeInsets.only(left: 18, bottom: 8),
                      child: Text('helper_selfie'.tr, style: TextStyle(color: Colors.grey, fontSize: 11)),
                    ),

                    InkWell(
                      onTap: () async {
                        var res = await pushTo(context, CaptureScreen(title: "Selfie",imageIcon: "",description: "Good light, clear face visible", expectedDocumentType: DocumentType.selfie,));

                        if(res != null)
                          {
                            ownerSelfieCard = res;
                          }

                        setState(() {});
                        },
                      child: Container(
                        margin: EdgeInsets.only(left: 15, right: 15),
                        child: ownerSelfieCard != null ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                              height: 150,
                              width: MediaQuery.of(context).size.width,
                              child: Image.file(File(ownerSelfieCard.toString()), fit: BoxFit.cover,)),
                        ) : Image.asset('assets/back_side_upload_icon.png'),
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

          if (isUploading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.4),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppColors.appColor),
                      SizedBox(height: 16),
                      Text('uploading_documents'.tr, style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
