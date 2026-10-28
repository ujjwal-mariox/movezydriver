import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:movezy_driver_app/AppNavigation/app_navigation.dart';
import 'package:movezy_driver_app/CommonWidgets/button_widget.dart';
import 'package:movezy_driver_app/CommonWidgets/expiry_date_tile.dart';
import 'package:movezy_driver_app/Screens/AadharCaptureScreen/capture_screen.dart';
import 'package:movezy_driver_app/Screens/DriverProfileApp/document_renewal_api_service.dart';
import 'package:movezy_driver_app/Screens/MyVehicles/Model/driver_details_response.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';
import 'package:movezy_driver_app/Utils/CustomToast/custome_toast.dart';
import 'package:movezy_driver_app/Utils/DocumentValidator/document_validator.dart';

/// Renew one vehicle's RC / insurance / PUC dates from My Vehicles. Unlike
/// Edit Vehicle this does not send the vehicle back for approval: the dates
/// apply at once and lift an "expired documents" pause. PUC is not asked for
/// electric vehicles. A new RC photo can be attached when the RC itself was
/// renewed. Pops `true` when saved so the list reloads.
class UpdateVehicleDocumentsScreen extends StatefulWidget {
  final VehicleItem vehicle;

  const UpdateVehicleDocumentsScreen({super.key, required this.vehicle});

  @override
  State<UpdateVehicleDocumentsScreen> createState() =>
      _UpdateVehicleDocumentsScreenState();
}

class _UpdateVehicleDocumentsScreenState
    extends State<UpdateVehicleDocumentsScreen> {
  DateTime? _rcExpiry;
  DateTime? _insuranceExpiry;
  DateTime? _pucExpiry;
  String? _rcFrontPath;
  bool _showErrors = false;
  bool _saving = false;

  bool get _pucExempt =>
      (widget.vehicle.fuelType ?? '').toLowerCase() == 'electric';

  @override
  void initState() {
    super.initState();
    _rcExpiry = DateTime.tryParse(widget.vehicle.rcExpiryDate ?? '');
    _insuranceExpiry = DateTime.tryParse(widget.vehicle.insuranceExpiryDate ?? '');
    _pucExpiry = DateTime.tryParse(widget.vehicle.pucExpiryDate ?? '');
  }

  bool get _missing =>
      _rcExpiry == null ||
      _insuranceExpiry == null ||
      (!_pucExempt && _pucExpiry == null);

  bool get _anyPast {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return [_rcExpiry, _insuranceExpiry, if (!_pucExempt) _pucExpiry]
        .any((d) => d != null && d.isBefore(today));
  }

  Future<void> _captureRc() async {
    final res = await pushTo(
      context,
      const CaptureScreen(
        title: 'RC Front',
        imageIcon: "assets/rc.png",
        description: 'RC — Front Side',
        expectedDocumentType: DocumentType.vehicleRc,
      ),
    );
    if (res != null && mounted) setState(() => _rcFrontPath = res.toString());
  }

  Future<void> _save() async {
    if (_saving || widget.vehicle.id == null) return;
    if (_missing) {
      setState(() => _showErrors = true);
      showCustomToast(context, 'please_add_document_expiry'.tr);
      return;
    }
    if (_anyPast) {
      showCustomToast(context, 'document_expired_renew'.tr);
      return;
    }
    setState(() => _saving = true);
    final result = await DocumentRenewalApiService().updateVehicleDocuments(
      vehicleId: widget.vehicle.id!,
      rcExpiryDate: formatExpiryDate(_rcExpiry)!,
      insuranceExpiryDate: formatExpiryDate(_insuranceExpiry)!,
      pucExpiryDate: _pucExempt ? null : formatExpiryDate(_pucExpiry),
      rcFrontPath: _rcFrontPath,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    showCustomToast(
      context,
      result.ok
          ? 'documents_updated'.tr
          : (result.message.isNotEmpty ? result.message : 'network_error'.tr),
    );
    if (result.ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
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
                      widget.vehicle.vehicleNumber ?? '',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Text(
                      'update_documents_hint'.tr,
                      style: TextStyle(fontSize: 12, color: HexColor("#607080")),
                    ),
                  ),
                  const SizedBox(height: 18),
                  ExpiryDateTile(
                    label: 'rc_expiry'.tr,
                    value: _rcExpiry,
                    showError: _showErrors,
                    onPicked: (d) => setState(() => _rcExpiry = d),
                  ),
                  ExpiryDateTile(
                    label: 'insurance_expiry'.tr,
                    value: _insuranceExpiry,
                    showError: _showErrors,
                    onPicked: (d) => setState(() => _insuranceExpiry = d),
                  ),
                  if (_pucExempt)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(15, 0, 15, 10),
                      child: Text(
                        'puc_not_needed_ev'.tr,
                        style: TextStyle(fontSize: 11, color: HexColor("#607080")),
                      ),
                    )
                  else
                    ExpiryDateTile(
                      label: 'puc_expiry'.tr,
                      value: _pucExpiry,
                      showError: _showErrors,
                      onPicked: (d) => setState(() => _pucExpiry = d),
                    ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.only(left: 18, bottom: 8),
                    child: Text(
                      'new_rc_photo_optional'.tr,
                      style: const TextStyle(
                          color: Colors.black, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  InkWell(
                    onTap: _captureRc,
                    child: Container(
                      height: 120,
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 15),
                      decoration: BoxDecoration(
                        border: Border.all(color: HexColor("#E1E6EF"), width: 1.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: _rcFrontPath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(9),
                              child: Image.file(File(_rcFrontPath!), fit: BoxFit.cover),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.photo_camera_outlined,
                                    color: AppColors.appColor, size: 28),
                                const SizedBox(height: 6),
                                Text('tap_to_add_photo'.tr,
                                    style: TextStyle(
                                        fontSize: 12, color: HexColor("#607080"))),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Same orange bar as My Vehicles.
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
            'update_documents'.tr,
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
