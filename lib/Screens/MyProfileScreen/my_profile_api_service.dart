import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:movezy_driver_app/ApiUrls/api_urls.dart';
import 'package:movezy_driver_app/Screens/MyProfileScreen/Model/driver_profile_bundle.dart';
import 'package:movezy_driver_app/Utils/PrefsManager/prefs_manager.dart';

class MyProfileApiService {
  Future<DriverProfileBundle> getProfileBundle() async {
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${Prefs.accessToken}',
    };

    final responses = await Future.wait([
      http.get(Uri.parse(ApiUrls.driverProfileUrl), headers: headers),
      http.get(Uri.parse(ApiUrls.driverDetailsUrl), headers: headers),
    ]);

    final profileResponse = responses[0];
    final detailsResponse = responses[1];

    if (profileResponse.statusCode < 200 || profileResponse.statusCode >= 300) {
      throw Exception('Unable to load profile');
    }
    if (detailsResponse.statusCode < 200 || detailsResponse.statusCode >= 300) {
      throw Exception('Unable to load driver details');
    }

    final profileJson = jsonDecode(profileResponse.body) as Map<String, dynamic>;
    final detailsJson = jsonDecode(detailsResponse.body) as Map<String, dynamic>;

    return DriverProfileBundle.fromResponses(
      profileJson: profileJson,
      detailsJson: detailsJson,
    );
  }

  Future<String> uploadProfilePhoto(File imageFile) async {
    final request = http.MultipartRequest(
      'PUT',
      Uri.parse(ApiUrls.driverProfilePhotoUrl),
    );

    request.headers['Authorization'] = 'Bearer ${Prefs.accessToken}';

    final bytes = await imageFile.readAsBytes();
    final mediaType = _imageMediaType(imageFile.path);
    final ext = _imageExtension(imageFile.path);

    request.files.add(
      http.MultipartFile.fromBytes(
        'photo',
        bytes,
        filename: 'profile_photo$ext',
        contentType: mediaType,
      ),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body['message']?.toString() ?? 'Unable to update profile photo');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = Map<String, dynamic>.from((body['data'] ?? {}) as Map);
    return data['profilePhoto']?.toString() ?? '';
  }

  MediaType _imageMediaType(String path) {
    final normalized = path.toLowerCase();
    if (normalized.endsWith('.png')) return MediaType('image', 'png');
    if (normalized.endsWith('.webp')) return MediaType('image', 'webp');
    if (normalized.endsWith('.heic')) return MediaType('image', 'heic');
    if (normalized.endsWith('.heif')) return MediaType('image', 'heif');
    return MediaType('image', 'jpeg');
  }

  String _imageExtension(String path) {
    final normalized = path.toLowerCase();
    if (normalized.endsWith('.png')) return '.png';
    if (normalized.endsWith('.webp')) return '.webp';
    if (normalized.endsWith('.heic')) return '.heic';
    if (normalized.endsWith('.heif')) return '.heif';
    return '.jpg';
  }
}
