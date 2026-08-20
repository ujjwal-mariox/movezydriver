import 'package:get/get.dart';
import 'package:movezy_driver_app/CommonWidgets/app_bar.dart';
import 'package:movezy_driver_app/CommonWidgets/button_widget.dart';
import 'package:movezy_driver_app/CommonWidgets/edit_text_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:movezy_driver_app/Screens/on_boarding_screens/OnbordingApiService/on_boarding_api_service.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';
import 'package:movezy_driver_app/Screens/on_boarding_screens/onboarding_logout_action.dart';


class BankDetailsScreen extends StatefulWidget {
  const BankDetailsScreen({super.key});

  @override
  State<BankDetailsScreen> createState() => _BankDetailsScreenState();
}

class _BankDetailsScreenState extends State<BankDetailsScreen> {
  var driverNameController = TextEditingController();
  var driverAccountNumController = TextEditingController();
  var driverIfscCodeController = TextEditingController();


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
        // 90, matching the three sibling onboarding screens. At 82 this box was
        // 4px shorter than its children (15 + ButtonWidget's default 56 + 15 =
        // 86), so it overflowed on every device on every render — no narrow
        // screen or text scale needed.
        height: 90,
        decoration: BoxDecoration(color: Colors.grey[100]),
        child: Column(
          children: [

            SizedBox(height: 15,),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: ButtonWidget(
                onTap: ()
                {
                  // Keys must match the /driver/app/bank-details endpoint.
                  // driverNameController is the BANK NAME field (UI label
                  // "select_bank"), not a person's name.
                  var params = {
                    "bankName": driverNameController.text.toString(),
                    "accountNumber": driverAccountNumController.text.toString(),
                    "ifscCode": driverIfscCodeController.text.toString(),
                  };

                  OnBoardingApiService().addBankDetailsApi(context, params);
                },
                borderRadius: BorderRadius.circular(8),
                // The design labels this "Submit", and unlike the settings
                // screen this first-time save really is a direct submit (no
                // admin approval), so the existing 'submit' key is accurate.
                text: 'submit'.tr,
                backgroundColor: AppColors.appColor,
              ),
            ),

            SizedBox(height: 15,),
          ],
        ),
        ),
      ),
      body: SingleChildScrollView(
        child: Container(
          child: Column(
            children: [
              commonAppBar(
                  height : 110,
                  context : context,
                  child: Container(
                    padding: const EdgeInsets.only(top: 50),
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

                        SizedBox(width: 6,),

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
                  )
              ),

              SizedBox(height: 25,),

              Image.asset('assets/bank_sc.png'),

              Container(
                color: Colors.white,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    SizedBox(height: 17,),

                    SizedBox(
                      width: MediaQuery.of(context).size.width,
                      child: Row(
                        children: [
                          SizedBox(width: 16,),

                          Expanded(
                            child: Container(
                              height: 1,
                              color: HexColor("#E1E6EF"),
                            ),
                          ),

                          SizedBox(width: 10,),

                          Text('bank_details'.tr, style: TextStyle(color: Colors.black, fontSize: 13),),

                          SizedBox(width: 10,),

                          Expanded(
                            child: Container(
                              height: 1,
                              color: HexColor("#E1E6EF"),
                            ),
                          ),

                          SizedBox(width: 16,),
                        ],
                      ),
                    ),

                    SizedBox(height: 17,),

                    Container(
                        margin: EdgeInsets.only(left: 15, right: 15),
                        child: editTextWidget(context: context,controller: driverNameController,hintText: 'select_bank'.tr,isOptional: false, labelText: 'bank'.tr,
                            suffixIcon: SizedBox(
                              width: 50,
                              child: Icon(Icons.arrow_drop_down_rounded, size: 32,),
                            )
                        )
                    ),

                    SizedBox(height: 14,),

                    Container(
                        margin: EdgeInsets.only(left: 15, right: 15),
                        child: editTextWidget(context: context,controller: driverAccountNumController,hintText: 'enter_account_number'.tr,isOptional: false, labelText: 'account_number'.tr)
                    ),

                    SizedBox(height: 14,),

                    Container(
                        margin: EdgeInsets.only(left: 15, right: 15),
                        child: editTextWidget(context: context,controller: driverIfscCodeController,hintText: 'enter_ifsc'.tr,isOptional: false, labelText: 'ifsc_code'.tr)
                    ),

                  ],
                ),
              ),

              SizedBox(height: 20,),
            ],
          ),
        ),
      ),
    );
  }
}
