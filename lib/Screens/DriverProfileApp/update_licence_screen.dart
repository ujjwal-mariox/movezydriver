import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:movezy_driver_app/AppNavigation/app_navigation.dart';
import 'package:movezy_driver_app/CommonWidgets/button_widget.dart';
import 'package:movezy_driver_app/CommonWidgets/expiry_date_tile.dart';
import 'package:movezy_driver_app/Screens/AadharCaptureScreen/capture_screen.dart';
import 'package:movezy_driver_app/Screens/DriverProfileApp/document_renewal_api_service.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';
import 'package:movezy_driver_app/Utils/CustomToast/custome_toast.dart';

/// Renew the driving licence from Profile: a photo of the renewed licence and
/// its new expiry date, both required. The date applies at once (lifting a
/// licence-expiry pause) and the licence shows "Under review" until the admin
/// re-checks the photo. Pops `true` when saved so Profile reloads.
class UpdateLicenceScreen extends StatefulWidget {
  /// The expiry on file, already formatted for display ('' when none).
  final String currentExpiry;

  const UpdateLicenceScreen({super.key, this.currentExpiry = ''});

  @override
  State<UpdateLicenceScreen> createState() => _UpdateLicenceScreenState();
}

class _UpdateLicenceScreenState extends State<UpdateLicenceScreen> {
  String? _photoPath;
  DateTime? _expiry;
  bool _showErrors = false;
  bool _saving = false;

  Future<void> _capture() async {
    final res = await pushTo(
      context,
      CaptureScreen(
        title: 'capture_dl_front'.tr,
        imageIcon: "assets/aadhar_card.png",
        description: 'dl_front_desc'.tr,
      ),
    );
    if (res != null && mounted) setState(() => _photoPath = res.toString());
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_photoPath == null || _expiry == null) {
      setState(() => _showErrors = true);
      showCustomToast(
        context,
        _photoPath == null
            ? 'please_add_renewed_licence'.tr
            : 'please_add_dl_expiry'.tr,
      );
      return;
    }
    setState(() => _saving = true);
    final result = await DocumentRenewalApiService().renewLicence(
      photoPath: _photoPath!,
      expiryDate: formatExpiryDate(_expiry)!,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    showCustomToast(
      context,
      result.message.isNotEmpty ? result.message : 'network_error'.tr,
    );
    if (result.ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final missingPhoto = _showErrors && _photoPath == null;
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: Colors.grey[100],
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: ButtonWidget(
            onTap: _saving ? null : _save,
            borderRadius: BorderRadius.circular(12),
            text: _saving ? '...' : 'update'.tr,
            backgroundColor: AppColors.appColor,
          ),
        ),
      ),
      body: Column(
        children: [
          _header(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Text(
                      'update_licence_hint'.tr,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF607080)),
                    ),
                  ),
                  if (widget.currentExpiry.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Text(
                        '${'current_expiry'.tr}: ${widget.currentExpiry}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _label('renewed_licence_photo'.tr),
                  Padding(
                    padding: const EdgeInsets.only(left: 18, bottom: 8),
                    child: Text('helper_dl'.tr,
                        style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  ),
                  InkWell(
                    onTap: _capture,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 15),
                      decoration: missingPhoto
                          ? BoxDecoration(
                              border: Border.all(color: Colors.red, width: 1.5),
                              borderRadius: BorderRadius.circular(10),
                            )
                          : null,
                      child: _photoPath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                height: 150,
                                width: double.infinity,
                                child: Image.file(File(_photoPath!), fit: BoxFit.cover),
                              ),
                            )
                          : Image.asset('assets/upload_licence_image.png'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _label('new_expiry_date'.tr),
                  ExpiryDateTile(
                    label: 'expiry_date'.tr,
                    value: _expiry,
                    showError: _showErrors,
                    onPicked: (d) => setState(() => _expiry = d),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(left: 18, bottom: 6),
        child: Text.rich(TextSpan(children: [
          TextSpan(
            text: text,
            style: const TextStyle(
                color: Colors.black, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const TextSpan(
            text: ' *',
            style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ])),
      );

  /// Same orange bar as My Vehicles and the onboarding steps.
  Widget _header() {
    return Container(
      height: 95,
      padding: const EdgeInsets.only(top: 38),
      color: AppColors.appColor,
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.only(left: 16),
              width: 40,
              height: 35,
              alignment: Alignment.center,
              child: Image.asset("assets/back_arrow.png", color: Colors.white),
            ),
          ),
          const SizedBox(width: 9),
          Text(
            'update_licence'.tr,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
