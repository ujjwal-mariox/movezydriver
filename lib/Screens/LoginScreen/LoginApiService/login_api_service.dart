import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:movezy_driver_app/ApiUrls/api_urls.dart';
import 'package:movezy_driver_app/AppNavigation/app_navigation.dart';
import 'package:movezy_driver_app/Screens/LoginScreen/Model/login_response.dart';
import 'package:movezy_driver_app/Screens/OtpScreen/otp_screen.dart';
import 'package:movezy_driver_app/Utils/CustomToast/custome_toast.dart';
import 'package:http/http.dart' as http;


class LoginApiService {
  Future<LoginResponse?> loginApi(BuildContext context, String mobileNumber) async {
    try {
      var params = {
        "countryCode": "+91",
        "mobileNumber": mobileNumber
      };

      var response = await http.post(
          Uri.parse(ApiUrls.loginUrl),
        body: json.encode(params),
          headers: {
            'Content-Type': 'application/json',
          }
      ).timeout(const Duration(seconds: 30));

      var dataT = loginResponseFromJson(response.body);

      if(response.statusCode == 200)
      {
        pushTo(context, OtpScreen(mobileNumber: mobileNumber, token: dataT.data?.txnId.toString() ?? "",));
      }
      else
      {
        showCustomToast(context, dataT.data?.txnId.toString() ?? "",);
      }

      return loginResponseFromJson(response.body);
    } catch (e) {
      showCustomToast(context, 'network_error'.tr);
      return null;
    }
  }
}