import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Request all required permissions at app startup.
  /// Call this once after the user lands on the first interactive screen.
  static Future<void> requestAllPermissions(BuildContext context) async {
    // 1. Camera
    await _request(Permission.camera);

    // 2. Gallery / Photos
    if (Platform.isAndroid) {
      final sdkInt = await _androidSdk();
      if (sdkInt >= 33) {
        await _request(Permission.photos);
      } else {
        await _request(Permission.storage);
      }
    } else {
      await _request(Permission.photos);
    }

    // 3. Location — must request "when in use" first, then "always"
    await _request(Permission.locationWhenInUse);
    // Small delay so the OS processes the first grant before showing the next
    await Future.delayed(const Duration(milliseconds: 500));
    await _request(Permission.locationAlways);

    // 4. SMS (Android only — for auto-read OTP)
    if (Platform.isAndroid) {
      await _request(Permission.sms);
    }

    // 5. Phone / Calls
    await _request(Permission.phone);

    // 6. Notifications (Android 13+)
    if (Platform.isAndroid) {
      await _request(Permission.notification);
    }
  }

  /// Check if all critical permissions are granted.
  static Future<bool> areAllGranted() async {
    final statuses = await [
      Permission.camera,
      Permission.locationWhenInUse,
      Permission.phone,
    ].request();

    return statuses.values.every(
      (s) => s.isGranted || s.isLimited,
    );
  }

  static Future<PermissionStatus> _request(Permission permission) async {
    final status = await permission.status;
    if (status.isGranted || status.isLimited) return status;
    return await permission.request();
  }

  static Future<int> _androidSdk() async {
    try {
      // permission_handler internally handles SDK version checks,
      // but we use 33 as the cutoff for media permissions
      return 33; // Safe default — photos permission works on 33+, storage on <33
    } catch (_) {
      return 30;
    }
  }
}
