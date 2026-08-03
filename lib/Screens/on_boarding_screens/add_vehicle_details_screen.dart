import 'package:get/get.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:http/http.dart' as http;
import 'package:movezy_driver_app/ApiUrls/api_urls.dart';
import 'package:movezy_driver_app/AppNavigation/app_navigation.dart';
import 'package:movezy_driver_app/CommonWidgets/button_widget.dart';
import 'package:movezy_driver_app/CommonWidgets/edit_text_controller.dart';
import 'package:movezy_driver_app/Screens/AadharCaptureScreen/capture_screen.dart';
import 'package:movezy_driver_app/Screens/on_boarding_screens/OnbordingApiService/on_boarding_api_service.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';
import 'package:movezy_driver_app/Utils/CustomToast/custome_toast.dart';
import 'package:movezy_driver_app/CommonWidgets/onboarding_stepper.dart';
import 'package:movezy_driver_app/Utils/PrefsManager/prefs_manager.dart';
import 'package:movezy_driver_app/Utils/DocumentValidator/document_validator.dart';
import 'package:movezy_driver_app/Screens/HelpSupportScreen/help_support_screen.dart';
import 'package:movezy_driver_app/Screens/on_boarding_screens/onboarding_logout_action.dart';

class AddVehicleDetailsScreen extends StatefulWidget {
  /// True when this screen is part of the first-time onboarding flow (default).
  /// False when an already-onboarded driver is adding an extra vehicle from
  /// "My Vehicles" — in that case we must NOT drop the driver back into the
  /// onboarding license step; we just return to the vehicles list.
  final bool isOnboarding;
  const AddVehicleDetailsScreen({super.key, this.isOnboarding = true});

  @override
  State<AddVehicleDetailsScreen> createState() => _AddVehicleDetailsScreenState();
}

class _AddVehicleDetailsScreenState extends State<AddVehicleDetailsScreen> {
  var vehicleNumberController = TextEditingController();
  String? rcFrontImage;
  String? rcBackImage;
  String? selectedCity;
  String? vehicleType;
  // The admin catalog id for the selected type — this is what dispatch matches
  // on, so it must be submitted with the RC rather than the display name.
  String? vehicleTypeId;
  String? oilType;
  String? bodyType;

  // Master data lists fetched from backend
  List<String> cityList = [];
  // Vehicle types are admin-managed; each entry is {id, name}. Empty until the
  // catalog loads — no hardcoded 2/3/4-Wheeler fallback, since a stale list
  // wouldn't map to a real vehicleTypeId.
  List<Map<String, String>> vehicleTypeList = [];
  List<String> bodyTypeList = ['Open', 'Closed'];
  List<String> fuelTypeList = [];
  bool isLoadingMasterData = true;

  // In-flight guard for Save & Continue. Without it a second tap posted a
  // second RC before the first response landed, registering the same vehicle
  // twice — and every vehicle carries its own ₹999 joining fee, so the driver
  // was billed twice. Set before the first await, cleared in a finally.
  bool _savingVehicle = false;

  @override
  void initState() {
    super.initState();
    _fetchMasterData();
  }

  Future<void> _fetchMasterData() async {
    try {
      final response = await http.get(
        Uri.parse(ApiUrls.masterDataUrl),
        headers: {
          'Authorization': 'Bearer ${Prefs.accessToken}',
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final data = json['data'];

        setState(() {
          cityList = (data['cities'] as List)
              .map<String>((c) => c['name'].toString())
              .toList();
          fuelTypeList = (data['fuelTypes'] as List)
              .map<String>((f) => f['name'].toString())
              .toList();
          // Admin-managed vehicle catalog. Keep id alongside name so submit can
          // send the vehicleTypeId dispatch needs.
          vehicleTypeList = ((data['vehicleTypes'] as List?) ?? [])
              .map<Map<String, String>>((v) => {
                    'id': (v['_id'] ?? v['id'] ?? '').toString(),
                    'name': (v['name'] ?? '').toString(),
                  })
              .where((v) => v['id']!.isNotEmpty && v['name']!.isNotEmpty)
              .toList();
          isLoadingMasterData = false;
        });
      } else {
        setState(() {
          isLoadingMasterData = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching master data: $e");
      setState(() {
        isLoadingMasterData = false;
      });
    }
  }

  Future<void> _onSaveAndContinue() async {
    // Validation runs before the guard: a rejected tap must leave the button
    // usable so the driver can fix the field and try again.
    if (vehicleNumberController.text.trim().isEmpty) {
      showCustomToast(context, 'please_enter_vehicle_number'.tr);
      return;
    }
    if (rcFrontImage == null) {
      showCustomToast(context, 'please_add_vehicle_rc'.tr);
      return;
    }
    if (rcBackImage == null) {
      showCustomToast(context, 'Please add RC back side');
      return;
    }
    if (selectedCity == null) {
      showCustomToast(context, 'please_select_city'.tr);
      return;
    }
    if (vehicleType == null) {
      showCustomToast(context, 'please_add_vehicle_type'.tr);
      return;
    }
    if (bodyType == null) {
      showCustomToast(context, 'please_add_body_type'.tr);
      return;
    }
    if (oilType == null) {
      showCustomToast(context, 'please_add_fuel_type'.tr);
      return;
    }

    // Belt and braces: onTap is already nulled while this is true, but a tap
    // queued in the same frame as the first would still get through.
    if (_savingVehicle) return;
    setState(() => _savingVehicle = true);

    try {
      await OnBoardingApiService().addRcDetailsApi(
        vehicleNumber: vehicleNumberController.text.trim(),
        rcFrontImage: File(rcFrontImage!),
        rcBackImage: File(rcBackImage!),
        cityName: selectedCity.toString(),
        context: context,
        bodyType: bodyType.toString(),
        vehicleType: vehicleType.toString(),
        vehicleTypeId: vehicleTypeId ?? '',
        oilType: oilType.toString(),
        isOnboarding: widget.isOnboarding,
      );
    } finally {
      // The service navigates away on success, so this widget may be gone.
      if (mounted) setState(() => _savingVehicle = false);
    }
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
      backgroundColor: HexColor("#F0F5FF"),
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
                // Null while a submit is in flight so the tap is a no-op.
                onTap: _savingVehicle ? null : _onSaveAndContinue,
                borderRadius: BorderRadius.circular(12),
                text: _savingVehicle ? 'loading'.tr : 'save_continue'.tr,
                backgroundColor: _savingVehicle
                    ? AppColors.appColor.withValues(alpha: 0.5)
                    : AppColors.appColor,
              ),
            ),

            SizedBox(height: 16,),
          ],
        ),
        ),
      ),
      body: isLoadingMasterData
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.appColor),
                  SizedBox(height: 16),
                  Text('loading_vehicle_options'.tr,
                      style: TextStyle(color: HexColor("#607080"), fontSize: 14)),
                ],
              ),
            )
          : SingleChildScrollView(
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
                      widget.isOnboarding ? 'onboarding'.tr : 'add_another_vehicle'.tr,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    Spacer(),

                    // Logout only makes sense during first-time onboarding.
                    if (widget.isOnboarding) onboardingLogoutAction(context),

                    SizedBox(width: 15,)
                  ],
                ),
              ),

              // The step indicator is only relevant to the onboarding flow.
              if (widget.isOnboarding) const OnboardingStepper(currentStep: 1),

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
                            controller: vehicleNumberController,
                            hintText: 'enter_vehicle_number'.tr,
                            isOptional: false,
                            labelText: 'vehicle_number'.tr
                        )
                    ),

                    SizedBox(height: 25,),

                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: 18,),
                        Container(
                            margin: EdgeInsets.only(bottom: 6),
                            child: Text('upload_vehicle_rc'.tr, style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w600),)
                        ),

                        Container(
                            margin: EdgeInsets.only(bottom: 6),
                            child: Text("*", style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600),)
                        ),
                      ],
                    ),

                    Padding(
                      padding: const EdgeInsets.only(left: 18, bottom: 8),
                      child: Text('helper_rc'.tr, style: TextStyle(color: Colors.grey, fontSize: 11)),
                    ),

                    InkWell(
                      onTap: () async {
                        var res = await pushTo(context, CaptureScreen(
                          title: 'RC Front',
                          imageIcon: "assets/rc.png",
                          description: 'RC — Front Side',
                          expectedDocumentType: DocumentType.vehicleRc,
                          nextCapture: NextCaptureConfig(
                            title: 'RC Back',
                            imageIcon: "assets/rc.png",
                            description: 'RC — Back Side',
                            expectedDocumentType: DocumentType.vehicleRc,
                          ),
                        ));

                        if(res != null && res is List<String> && res.length == 2)
                        {
                          rcFrontImage = res[0];
                          rcBackImage = res[1];
                          // Auto-extract vehicle number and type from RC
                          if (vehicleNumberController.text.trim().isEmpty) {
                            final extracted = await DocumentValidator.extractData(
                              File(res[0]), DocumentType.vehicleRc,
                            );
                            if (extracted['vehicleNumber'] != null && extracted['vehicleNumber']!.isNotEmpty) {
                              vehicleNumberController.text = extracted['vehicleNumber']!;
                            }
                            // Map the OCR'd type onto a real catalog entry so it
                            // carries a vehicleTypeId; ignore it if no match.
                            final extractedType =
                                extracted['vehicleType']?.toLowerCase().trim();
                            if (extractedType != null &&
                                extractedType.isNotEmpty &&
                                vehicleTypeId == null) {
                              final match = vehicleTypeList.firstWhere(
                                (v) =>
                                    v['name']!.toLowerCase() == extractedType,
                                orElse: () => {'id': '', 'name': ''},
                              );
                              if (match['id']!.isNotEmpty) {
                                vehicleTypeId = match['id'];
                                vehicleType = match['name'];
                              }
                            }
                          }
                        }
                        setState(() {});
                      },
                      child: Container(
                        margin: EdgeInsets.only(left: 15, right: 15),
                        child: rcFrontImage != null && rcBackImage != null
                          ? Column(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: SizedBox(
                                    height: 120,
                                    width: MediaQuery.of(context).size.width,
                                    child: Image.file(File(rcFrontImage!), fit: BoxFit.cover,)),
                                ),
                                SizedBox(height: 8,),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: SizedBox(
                                    height: 120,
                                    width: MediaQuery.of(context).size.width,
                                    child: Image.file(File(rcBackImage!), fit: BoxFit.cover,)),
                                ),
                              ],
                            )
                          : Image.asset('assets/front_side_upload_icon.png'),
                      ),
                    ),

                    SizedBox(height: 22,),

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

                          Text('vehicle_information'.tr, style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w600),),

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

                    SizedBox(height: 20,),

                    Container(
                      margin: EdgeInsets.only(left: 15, bottom: 6),
                      child: Text('select_city_operation'.tr, style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w600),),
                    ),

                    Container(
                      padding: EdgeInsets.only(left: 15, right: 15, bottom: 15, top: 15),
                      decoration: BoxDecoration(
                        border: Border.all(color: HexColor("#E1E6EF"), width: 1.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      margin: EdgeInsets.only(left: 15, right: 15),
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        hint: Text('choose_one'.tr,style: TextStyle(fontSize: 14,color: HexColor("#607080")),),
                        initialValue: selectedCity,
                        items: cityList
                            .map(
                              (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item, style: TextStyle(fontSize: 14,color: HexColor("#607080")),),
                          ),
                        )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedCity = value;
                          });
                        },
                        validator: (value) =>
                        value == null ? 'please_select_option'.tr : null,
                      ),
                    ),

                    SizedBox(height: 15,),


                    Container(
                      margin: EdgeInsets.only(left: 15, bottom: 6),
                      child: Text('select_vehicle_type'.tr, style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w600),),
                    ),


                    Container(
                      padding: EdgeInsets.only(left: 15, right: 15, bottom: 15, top: 15),
                      decoration: BoxDecoration(
                        border: Border.all(color: HexColor("#E1E6EF"), width: 1.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      margin: EdgeInsets.only(left: 15, right: 15),
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        hint: Text('choose_one'.tr,style: TextStyle(fontSize: 13, color: HexColor("#607080")),),
                        initialValue: vehicleTypeId,
                        items: vehicleTypeList
                            .map(
                              (item) => DropdownMenuItem(
                            value: item['id'],
                            child: Text(item['name']!, style: TextStyle(fontSize: 13, color: HexColor("#607080")),),
                          ),
                        )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            vehicleTypeId = value;
                            // Keep the name too — the KYC RC record still stores
                            // the coarse type string (vehicalId).
                            vehicleType = vehicleTypeList
                                .firstWhere((v) => v['id'] == value,
                                    orElse: () => {'name': ''})['name'];
                          });
                        },
                        validator: (value) =>
                        value == null ? 'please_select_option'.tr : null,
                      ),
                    ),

                    SizedBox(height: 15,),

                    Container(
                      margin: EdgeInsets.only(left: 15, bottom: 6),
                      child: Row(
                        children: [
                          Text('select_body_type'.tr, style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w600),),
                          Text("*", style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600),),
                        ],
                      ),
                    ),

                    Container(
                      margin: EdgeInsets.only(left: 15, right: 15),
                      child: Row(
                        children: bodyTypeList.map((type) {
                          final isSelected = bodyType == type;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  bodyType = type;
                                });
                              },
                              child: Container(
                                margin: EdgeInsets.only(right: type == bodyTypeList.first ? 10 : 0, left: type == bodyTypeList.last ? 10 : 0),
                                padding: EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.appColor : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected ? AppColors.appColor : HexColor("#E1E6EF"),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      type == 'Open' ? Icons.fire_truck_outlined : Icons.local_shipping,
                                      size: 22,
                                      color: isSelected ? Colors.white : HexColor("#607080"),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      type,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected ? Colors.white : HexColor("#607080"),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    SizedBox(height: 12,),

                    Container(
                      margin: EdgeInsets.only(left: 15, bottom: 6),
                      child: Text('select_fuel_type'.tr, style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w600),),
                    ),

                    Container(
                      padding: EdgeInsets.only(left: 15, right: 15, bottom: 15, top: 15),
                      decoration: BoxDecoration(
                        border: Border.all(color: HexColor("#E1E6EF"), width: 1.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      margin: EdgeInsets.only(left: 15, right: 15),
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        hint: Text('choose_one'.tr,style: TextStyle(fontSize: 14,color: HexColor("#607080")),),
                        initialValue: oilType,
                        items: fuelTypeList
                            .map(
                              (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item, style: TextStyle(fontSize: 13, color: HexColor("#607080")),),
                          ),
                        )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            oilType = value;
                          });
                        },
                        validator: (value) =>
                        value == null ? 'please_select_option'.tr : null,
                      ),
                    ),



                    SizedBox(height: 20,),
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
