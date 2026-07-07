import 'package:get/get.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart';
import 'package:http_parser/http_parser.dart';
import 'package:movezy_driver_app/ApiUrls/api_urls.dart';
import 'package:movezy_driver_app/AppNavigation/app_navigation.dart';
import 'package:movezy_driver_app/Screens/LoginScreen/Model/login_response.dart';
import 'package:movezy_driver_app/Screens/MyVehicles/my_vehicles.dart';
import 'package:movezy_driver_app/Screens/VerificationScreen/verification_screen.dart';
import 'package:movezy_driver_app/Screens/on_boarding_screens/driver_details_screen.dart';
import 'package:movezy_driver_app/Utils/CustomToast/custome_toast.dart';
import 'package:http/http.dart' as http;
import 'package:movezy_driver_app/Utils/PrefsManager/prefs_manager.dart';

class OnBoardingApiService {
  /// Upload all owner details (name + Aadhaar + PAN + Selfie) in a single API call.
  Future<Map<String, dynamic>> uploadOwnerDetails({
    required String ownerName,
    required File aadhaarFrontImage,
    required File aadhaarBackImage,
    required File panImage,
    required File selfieImage,
    required BuildContext context,
  }) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(ApiUrls.ownerDetailsUrl));

      // Add owner name field
      request.fields['ownerName'] = ownerName;

      // Add Aadhaar front and back images
      request.files.add(await http.MultipartFile.fromPath(
        'aadhaarFrontImage',
        aadhaarFrontImage.path,
        contentType: MediaType('image', 'jpeg'),
      ));

      request.files.add(await http.MultipartFile.fromPath(
        'aadhaarBackImage',
        aadhaarBackImage.path,
        contentType: MediaType('image', 'jpeg'),
      ));

      request.files.add(await http.MultipartFile.fromPath(
        'panImage',
        panImage.path,
        contentType: MediaType('image', 'jpeg'),
      ));

      request.files.add(await http.MultipartFile.fromPath(
        'selfieImage',
        selfieImage.path,
        contentType: MediaType('image', 'jpeg'),
      ));

      request.headers.addAll({
        'Authorization': 'Bearer ${Prefs.accessToken}',
      });

      debugPrint('Owner details upload URL: ${ApiUrls.ownerDetailsUrl}');

      var response = await request.send().timeout(const Duration(seconds: 120));
      final body = await response.stream.bytesToString();
      debugPrint('Owner details upload response: ${response.statusCode} $body');

      if (response.statusCode == 200) {
        return {'success': true, 'message': ''};
      } else {
        String errorMsg = 'Status ${response.statusCode}';
        try {
          final decoded = json.decode(body);
          errorMsg = decoded['message'] ?? decoded['rMsg'] ?? errorMsg;
        } catch (_) {}
        return {'success': false, 'message': errorMsg};
      }
    } catch (e) {
      debugPrint('Owner details upload error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  void addRcDetailsApi({required String vehicleNumber, required File? rcFrontImage, required File? rcBackImage, required BuildContext context, required String cityName, required String vehicleType, required String bodyType, required String oilType, bool isOnboarding = true,}) async {

    var request = http.MultipartRequest('POST', Uri.parse(ApiUrls.addRcDetailsApi));

    request.fields.addAll({
      "vehicleNumber": vehicleNumber,
      "city": cityName,
      "vehicalId": vehicleType,
      "bodyType": bodyType,
      "fuelType": oilType,
    });

    if (rcFrontImage != null) {
      request.files.add(await http.MultipartFile.fromPath(
        'rcFrontImage',
        rcFrontImage.path,
        contentType: MediaType('image', 'jpeg'),
      ));
    }

    if (rcBackImage != null) {
      request.files.add(await http.MultipartFile.fromPath(
        'rcBackImage',
        rcBackImage.path,
        contentType: MediaType('image', 'jpeg'),
      ));
    }

    // Add headers
    request.headers.addAll({
      'Authorization': 'Bearer ${Prefs.accessToken}',
      'Content-Type': 'multipart/form-data',
    });

    // Send request
    var response = await request.send();

    print("Add Rc details ${response.request?.url}");

    var dataT = json.decode(await response.stream.bytesToString());
    print("Decoded JSON Response: $dataT");

    if(response.statusCode == 200)
    {
      if (!isOnboarding) {
        // Already-onboarded driver adding an extra vehicle from "My Vehicles".
        // Never route back into the onboarding license step — just return to
        // the vehicles list (the caller refreshes it on pop).
        if (context.mounted) {
          showCustomToast(context, dataT['message']?.toString() ?? 'Vehicle added successfully');
          Navigator.pop(context);
        }
        return;
      }

      final bool hasLicense = dataT['data']?['hasLicense'] == true;
      if (hasLicense) {
        // Driver already submitted license — skip to payment screen
        await Prefs.setString('onboarding_step', 'my_vehicles');
        replaceRoute(context, const MyVehiclesScreen());
      } else {
        // First vehicle — need driver details + license
        await Prefs.setString('onboarding_step', 'driver_details');
        pushTo(context, DriverDetailsScreen());
      }
    }
    else
    {
      showCustomToast(context, dataT['message']?.toString() ?? "Something went wrong");
    }
  }

  Future<LoginResponse> addBankDetailsApi(BuildContext context, var params) async {
    // Bank details go to the dedicated /driver/app/bank-details endpoint, which
    // writes driver.bankDetails. (Previously this PUT hit /driver/personal-info,
    // which has no bank fields, so account number/IFSC were silently dropped.)
    var response = await http.put(Uri.parse(ApiUrls.driverBankDetailsUrl),
        body: json.encode(params),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Prefs.accessToken}'
        }
    );

    print("Add bank details $params");
    print("Add bank details ${response.request?.url}");
    print("Add bank details ${response.body}");

    var dataT = loginResponseFromJson(response.body);
    if(response.statusCode == 200)
    {
      pushTo(context, VerificationScreen());
    }
    else
    {
      showCustomToast(context, dataT.data?.txnId.toString() ?? "",);
    }
    return loginResponseFromJson(response.body);
  }

  Future<LoginResponse> addLicenceApi(BuildContext context, var params) async {
    try {
      final String licencePath = (params["driverLicence"] ?? "").toString().trim();
      if (licencePath.isEmpty) {
        if (context.mounted) {
          showCustomToast(context, 'please_add_licence'.tr);
        }
        return LoginResponse(code: 0, message: "driver_licence_required");
      }

      final request = http.MultipartRequest('POST', Uri.parse(ApiUrls.addLicenceApi));
      request.headers.addAll({
        'Authorization': 'Bearer ${Prefs.accessToken}',
      });

      request.fields.addAll({
        "licenseNumber": (params["licenseNumber"] ?? "").toString().trim().isNotEmpty
            ? params["licenseNumber"].toString().trim()
            : "DL-PENDING",
        "expiryDate": (params["expiryDate"] ?? "").toString().trim().isNotEmpty
            ? params["expiryDate"].toString().trim()
            : "2099-12-31",
      });

      request.files.add(await http.MultipartFile.fromPath(
        'frontImage',
        licencePath,
        contentType: MediaType('image', 'jpeg'),
      ));
      request.files.add(await http.MultipartFile.fromPath(
        'backImage',
        licencePath,
        contentType: MediaType('image', 'jpeg'),
      ));

      final streamedResponse = await request.send();
      final body = await streamedResponse.stream.bytesToString();

      print("Add licence details $params");
      print("Add licence details ${streamedResponse.request?.url}");
      print("Add licence details $body");

      Map<String, dynamic> decoded = {};
      try {
        decoded = body.isNotEmpty ? json.decode(body) : {};
      } catch (_) {}

      if (streamedResponse.statusCode == 200) {
        await Prefs.setString('onboarding_step', 'my_vehicles');
        if (context.mounted) {
          replaceRoute(context, const MyVehiclesScreen());
        }
      } else {
        final errorMessage = decoded['message']?.toString() ??
            decoded['rMsg']?.toString() ??
            "Unable to save driver details.";
        if (context.mounted) {
          showCustomToast(context, errorMessage);
        }
      }

      return LoginResponse.fromJson(decoded);
    } catch (e) {
      if (context.mounted) {
        showCustomToast(context, 'network_error'.tr);
      }
      return LoginResponse(code: 0, message: e.toString());
    }
  }
}
