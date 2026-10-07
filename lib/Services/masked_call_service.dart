import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:movezy_driver_app/ApiUrls/api_urls.dart';
import 'package:movezy_driver_app/Utils/PrefsManager/prefs_manager.dart';

/// Calls the other party through the platform caller ID.
/// If bridging fails, numbers stay hidden and chat remains available.
class MaskedCallService {
  MaskedCallService._();

  static Future<void> callCustomer(
    BuildContext context,
    String bookingId,
  ) async {
    if (bookingId.isEmpty) return;
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
      final accepted =
          res.statusCode == 200 &&
          body is Map &&
          body['success'] != false &&
          body['code'] != 0 &&
          data is Map &&
          (data['callId']?.toString().isNotEmpty ?? false);
      final message =
          (data is Map ? data['message'] : null)?.toString() ??
          (body is Map ? body['message']?.toString() : null) ??
          '';

      switch (mode) {
        case 'BRIDGE':
          if (!accepted) {
            Fluttertoast.showToast(
              msg: 'The call could not be started. Please use chat.',
            );
            return;
          }
          // The provider rings this phone first, then connects the customer.
          Fluttertoast.showToast(
            msg: message.isNotEmpty
                ? message
                : "You'll receive a call in a moment — answer to be connected.",
            toastLength: Toast.LENGTH_LONG,
          );
          return;
        default:
          Fluttertoast.showToast(
            msg: mode == 'UNAVAILABLE' && message.isNotEmpty
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
