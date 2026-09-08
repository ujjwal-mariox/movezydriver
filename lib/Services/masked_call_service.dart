import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:movezy_driver_app/ApiUrls/api_urls.dart';
import 'package:movezy_driver_app/Utils/PrefsManager/prefs_manager.dart';
import 'package:url_launcher/url_launcher.dart';

/// Calls the customer WITHOUT ever holding their number.
///
/// The server bridges the call through the platform's telephony number, so
/// both handsets only see Movezy's number ("proxy calling"). When the bridge
/// is not configured the server may hand back a number to dial directly —
/// the app never decides that on its own.
class MaskedCallService {
  MaskedCallService._();

  static Future<void> callCustomer(BuildContext context, String bookingId) async {
    if (bookingId.isEmpty) return;
    Fluttertoast.showToast(msg: 'Connecting your call…');
    try {
      final res = await http
          .post(
            Uri.parse(ApiUrls.driverCallCustomerUrl(bookingId)),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${Prefs.accessToken}',
            },
          )
          .timeout(const Duration(seconds: 20));
      final body = jsonDecode(res.body);
      final data = body is Map ? (body['data'] ?? {}) : {};
      final mode = (data is Map ? data['mode'] : null)?.toString() ?? '';
      final message = (data is Map ? data['message'] : null)?.toString() ??
          (body is Map ? body['message']?.toString() : null) ??
          '';

      switch (mode) {
        case 'BRIDGE':
          // The provider rings this phone first, then connects the customer.
          Fluttertoast.showToast(
            msg: message.isNotEmpty
                ? message
                : "You'll receive a call in a moment — answer to be connected.",
            toastLength: Toast.LENGTH_LONG,
          );
          return;
        case 'DIRECT':
          final number = (data is Map ? data['number'] : null)?.toString() ?? '';
          if (number.isEmpty) {
            Fluttertoast.showToast(msg: 'Customer number unavailable');
            return;
          }
          final uri = Uri(scheme: 'tel', path: number);
          if (!await launchUrl(uri)) {
            Fluttertoast.showToast(msg: 'Could not open the dialer');
          }
          return;
        default:
          Fluttertoast.showToast(
            msg: message.isNotEmpty
                ? message
                : 'Calling is unavailable right now. Please use chat.',
            toastLength: Toast.LENGTH_LONG,
          );
      }
    } catch (_) {
      Fluttertoast.showToast(msg: 'Could not place the call. Please try chat.');
    }
  }
}
