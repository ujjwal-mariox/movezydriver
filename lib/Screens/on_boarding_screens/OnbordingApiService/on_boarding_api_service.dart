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

  /// Registers a vehicle from its RC.
  ///
  /// Returns a Future so the caller can await it: this used to be a bare
  /// `void ... async`, which made the call fire-and-forget. The Save & Continue
  /// button had no way to know a submit was in flight, so a second tap posted a
  /// second RC and created a second vehicle — each of which carries its own
  /// ₹999 joining fee. The screen now awaits this and blocks the button.
  Future<void> addRcDetailsApi({required String vehicleNumber, required File? rcFrontImage, required File? rcBackImage, required BuildContext context, required String cityName, required String vehicleType, String vehicleTypeId = '', required String bodyType, required String oilType, bool isOnboarding = true,}) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(ApiUrls.addRcDetailsApi));

      request.fields.addAll({
        "vehicleNumber": vehicleNumber,
        "city": cityName,
        "vehicalId": vehicleType,
        // Admin-catalog id — backend ties the DriverVehicle to it so dispatch can
        // match this driver to bookings of this vehicle type.
        if (vehicleTypeId.isNotEmpty) "vehicleTypeId": vehicleTypeId,
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

      debugPrint("Add Rc details ${response.request?.url}");

      final body = await response.stream.bytesToString();
      Map<String, dynamic> dataT = {};
      try {
        dataT = body.isNotEmpty ? json.decode(body) as Map<String, dynamic> : {};
      } catch (_) {
        // Non-JSON body (gateway HTML, empty 502…) — don't let it throw past
        // the caller's in-flight guard.
      }
      debugPrint("Decoded JSON Response: $dataT");

      if (response.statusCode == 200) {
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
          if (context.mounted) replaceRoute(context, const MyVehiclesScreen());
        } else {
          // First vehicle — need driver details + license
          await Prefs.setString('onboarding_step', 'driver_details');
          if (context.mounted) pushTo(context, DriverDetailsScreen());
        }
      } else {
        if (context.mounted) {
          showCustomToast(context, dataT['message']?.toString() ?? "Something went wrong");
        }
      }
    } catch (e) {
      // The upload used to be able to throw straight out of a fire-and-forget
      // async void. Now that the screen awaits it, a failure has to surface as
      // a message and let the caller re-enable its button.
      debugPrint('Add RC details error: $e');
      if (context.mounted) {
        showCustomToast(context, 'network_error'.tr);
      }
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

      // Only send what was actually collected.
      //
      // This used to fall back to licenseNumber "DL-PENDING" and expiryDate
      // "2099-12-31" whenever the caller didn't supply them — which is always,
      // because the licence step only captures a photo. Those two invented
      // values were written to the driver's KYC record and then read back as
      // fact: the profile printed "DL-PENDING" as the licence number and an
      // expiry 74 years out, and an admin reviewing the document saw the same.
      // Omitted instead: the backend stores drivingLicense.number /
      // .expiryDate as optional strings and the express-validator notEmpty()
      // checks on them are never enforced (the route's final middleware only
      // inspects req.files, it never calls validationResult), so leaving them
      // out saves the images exactly as before. The profile screen already
      // degrades honestly — it hides the DL Number row when the number is
      // empty and renders "-" for an unparseable/absent expiry date.
      final String licenseNumber =
          (params["licenseNumber"] ?? "").toString().trim();
      final String expiryDate = (params["expiryDate"] ?? "").toString().trim();
      request.fields.addAll({
        if (licenseNumber.isNotEmpty) "licenseNumber": licenseNumber,
        if (expiryDate.isNotEmpty) "expiryDate": expiryDate,
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
