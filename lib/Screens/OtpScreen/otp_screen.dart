import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:movezy_driver_app/CommonWidgets/button_widget.dart';
import 'package:movezy_driver_app/Screens/OtpScreen/OtpApiService/otp_api_service.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';
import 'package:movezy_driver_app/Utils/CustomToast/custome_toast.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:pinput/pinput.dart';


class OtpScreen extends StatefulWidget {
  final String mobileNumber;

  /// Transaction id from the login call. Resending the OTP issues a NEW one,
  /// which used to be written back onto the widget itself (a mutable field on
  /// an @immutable Widget); the live value now lives in the State.
  final String token;

  const OtpScreen({super.key, required this.mobileNumber, required this.token});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  int _secondsRemaining = 60;
  Timer? _timer;
  String pinValue = "";
  bool showLoader = false;

  /// Live txnId — starts as the one login handed us, replaced by each resend.
  late String _token = widget.token;

  @override
  void initState() {
    super.initState();
    startTimer();
  }

  void startTimer() {
    _timer?.cancel();
    _secondsRemaining = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining == 0) {
        timer.cancel();
      }
      else
      {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 50,
      height: 50,
      margin: EdgeInsets.only(left: 3, right: 3),
      textStyle: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w400,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: HexColor("#AFAFAF"), // or any color you want
            width: 2.0,
          ),
        ),
      ),
    );

    final focusedPinTheme = PinTheme(
      width: 50,
      height: 50,
      margin: EdgeInsets.only(left: 3, right: 3),
      textStyle: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w400,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: HexColor("#AFAFAF"), // or any color you want
            width: 2.0,
          ),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leadingWidth: 100,
        leading: InkWell(
          onTap: (){
            Navigator.pop(context);
          },
          child: Container(
            padding: EdgeInsets.only(left: 20, top: 12, bottom: 8, right: 12),
            height: 30,
              width: 90,
              child: Row(
                children: [
                  Icon(Icons.arrow_back_ios_rounded, size: 19,),
                  SizedBox(width: 5,),
                  Text('back'.tr, style: TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w500),
                  )
                ],
              )
          ),
        ),
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 0),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 10),

                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'phone_verification'.tr,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 7),

                // Subtitle
                 Padding(
                   padding: const EdgeInsets.symmetric(horizontal: 20),
                   child: Text(
                    'otp_message'.tr,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: HexColor("#A0A0A0"),
                      fontWeight: FontWeight.w400
                    ),
                               ),
                 ),
                const SizedBox(height: 40),

                // OTP boxes
                Container(
                  margin: EdgeInsets.only(left: 30, right: 30),
                  child: Center(
                    child: Pinput(
                      length: 6,
                      defaultPinTheme: defaultPinTheme,
                      focusedPinTheme: focusedPinTheme,
                      onChanged: (value){
                        pinValue = value;
                        setState(() {

                        });
                      },
                      onCompleted: (pin) => print("Entered OTP: $pin"),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Countdown text
                InkWell(
                  onTap: () async {
                    var res = await OtpApiService().resendOtp(context, widget.mobileNumber);
                    _token = res?.data?.txnId ?? "";
                    setState(() {});
                  },
                  child: Center(
                    child: Text.rich(
                      TextSpan(
                        text: "${'didnt_receive'.tr}  ",
                        style: TextStyle(fontSize: 15, color: Colors.black, fontWeight: FontWeight.w500),
                        children: [
                          TextSpan(
                            text: 'resend_again'.tr,
                            style:  TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: HexColor("#FF4E80"),
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                Expanded(child: Container(width: 0,)),

                // Sign In Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: ButtonWidget(
                    borderRadius: BorderRadius.circular(10),
                    backgroundColor: AppColors.appColor,
                    textStyle: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 17
                    ),
                    text: 'verify'.tr,
                    onTap: () async {
                      if(pinValue.toString().length < 6)
                      {
                        showCustomToast(context, 'please_enter_valid_otp'.tr);
                      }
                      else
                      {
                        await OtpApiService().otpVerifyApi(context : context,otp: pinValue.toString(), token: _token, mobileNumber: widget.mobileNumber);
                      }
                    },
                  ),
                ),

                SizedBox(height: 15,),

                Container(
                  margin: EdgeInsets.only(left: 30, right: 30),
                  child: Center(
                    child: Text.rich(
                      TextSpan(
                        text: "${'by_continuing_agree'.tr} ",
                        style: TextStyle(fontSize: 12, color: HexColor('#A0A0A0'), fontWeight: FontWeight.w500),
                        children: [
                          TextSpan(
                            text: 'terms_of_service'.tr,
                            style:  TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: HexColor("#0082DF"),
                            ),
                          ),
                          TextSpan(
                            text: " ${'and_text'.tr} ",
                            style:  TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: HexColor("#A0A0A0"),
                            ),
                          ),
                          TextSpan(
                            text: 'privacy_policy'.tr,
                            style:  TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: HexColor("#0082DF"),
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

                // This Column runs to the bottom of the Scaffold body, so a
                // fixed 20pt tail left the terms line — and the Verify button
                // on short screens — under the gesture bar. Add the real inset.
                // viewPadding, not padding: padding.bottom collapses to 0 while
                // the OTP keypad is open, so the reserved space vanished at the
                // exact moment the driver reaches for Verify.
                SizedBox(height: 20 + MediaQuery.of(context).viewPadding.bottom),
              ],
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
    );
  }
}
