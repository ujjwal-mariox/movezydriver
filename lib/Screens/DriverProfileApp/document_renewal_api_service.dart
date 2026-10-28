import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:movezy_driver_app/ApiUrls/api_urls.dart';
import 'package:movezy_driver_app/Utils/PrefsManager/prefs_manager.dart';

/// Outcome of a renewal call: the server's own message either way, so the
/// screen can show exactly why a date was refused ("Insurance has already
/// expired…", "PUC expiry date is required.").
class RenewalResult {
  final bool ok;
  final String message;
  const RenewalResult(this.ok, this.message);
}

/// Partner-side renewals of expiring documents (backend
/// document-expiry.service): the licence from Profile, a vehicle's RC /
/// insurance / PUC from My Vehicles. Both apply at once.
class DocumentRenewalApiService {
  Future<RenewalResult> _send(http.MultipartRequest request) async {
    request.headers['Authorization'] = 'Bearer ${Prefs.accessToken}';
    try {
      final response = await request.send();
      final body = await response.stream.bytesToString();
      Map<String, dynamic> decoded = {};
      try {
        decoded = body.isNotEmpty ? json.decode(body) as Map<String, dynamic> : {};
      } catch (_) {}
      final message = decoded['message']?.toString() ?? '';
      return RenewalResult(response.statusCode == 200, message);
    } catch (_) {
      return const RenewalResult(false, '');
    }
  }

  /// New licence photo (required) + new expiry date (YYYY-MM-DD).
  Future<RenewalResult> renewLicence({
    required String photoPath,
    required String expiryDate,
  }) async {
    final request = http.MultipartRequest('PUT', Uri.parse(ApiUrls.renewLicenceUrl));
    request.fields['expiryDate'] = expiryDate;
    request.files.add(await http.MultipartFile.fromPath(
      'frontImage',
      photoPath,
      contentType: MediaType('image', 'jpeg'),
    ));
    return _send(request);
  }

  /// New RC / insurance / PUC dates, and optionally a photo of a renewed RC.
  /// [pucExpiryDate] is null for electric vehicles (exempt).
  Future<RenewalResult> updateVehicleDocuments({
    required String vehicleId,
    required String rcExpiryDate,
    required String insuranceExpiryDate,
    String? pucExpiryDate,
    String? rcFrontPath,
  }) async {
    final request = http.MultipartRequest(
      'PUT',
      Uri.parse(ApiUrls.vehicleDocumentsUrl(vehicleId)),
    );
    request.fields.addAll({
      'rcExpiryDate': rcExpiryDate,
      'insuranceExpiryDate': insuranceExpiryDate,
      if (pucExpiryDate != null) 'pucExpiryDate': pucExpiryDate,
    });
    if (rcFrontPath != null) {
      request.files.add(await http.MultipartFile.fromPath(
        'rcFrontImage',
        rcFrontPath,
        contentType: MediaType('image', 'jpeg'),
      ));
    }
    return _send(request);
  }
}
