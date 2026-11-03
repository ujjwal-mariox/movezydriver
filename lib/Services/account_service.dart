import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:movezy_driver_app/ApiUrls/api_urls.dart';
import 'package:movezy_driver_app/Utils/PrefsManager/prefs_manager.dart';

/// What stands in the way of deleting the account, and what would be lost.
class DeletionCheck {
  final List<String> blockers;
  final double walletBalance;
  final double coinBalance;
  final int graceDays;

  const DeletionCheck({
    required this.blockers,
    required this.walletBalance,
    required this.coinBalance,
    required this.graceDays,
  });
}

class EmergencyContact {
  final String id;
  final String name;
  final String phone;

  /// PARENT, SPOUSE, SIBLING, FRIEND or OTHER.
  final String relationship;

  const EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.relationship,
  });
}

/// Account deletion and emergency contacts. Every call reports failure as a
/// message to show, never throws.
class AccountService {
  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${Prefs.getString('access_token')}',
      };

  static const _timeout = Duration(seconds: 20);

  /// Server text when there is one, else [fallback].
  static String _message(http.Response res, String fallback) {
    try {
      final m = json.decode(res.body)['message']?.toString() ?? '';
      return m.isNotEmpty ? m : fallback;
    } catch (_) {
      return fallback;
    }
  }

  static Future<DeletionCheck?> deletionCheck() async {
    try {
      final res = await http
          .get(Uri.parse(ApiUrls.driverAccountDeletionUrl), headers: _headers)
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      final d = json.decode(res.body)['data'] as Map? ?? {};
      return DeletionCheck(
        blockers: [for (final b in (d['blockers'] as List? ?? [])) b.toString()],
        walletBalance: (d['walletBalance'] as num?)?.toDouble() ?? 0,
        coinBalance: (d['coinBalance'] as num?)?.toDouble() ?? 0,
        graceDays: (d['graceDays'] as num?)?.toInt() ?? 30,
      );
    } catch (_) {
      return null;
    }
  }

  /// Schedules the deletion. Returns (true, confirmation) or (false, reason).
  static Future<(bool, String)> requestDeletion() async {
    try {
      final res = await http
          .post(Uri.parse(ApiUrls.driverAccountDeletionUrl), headers: _headers)
          .timeout(_timeout);
      final ok = res.statusCode == 200 && json.decode(res.body)['code'] == 1;
      return (
        ok,
        _message(res, ok ? 'Your account will be deleted.' : 'Could not delete the account. Try again.'),
      );
    } catch (_) {
      return (false, 'Could not reach Movezy. Check your connection and try again.');
    }
  }

  static Future<List<EmergencyContact>?> contacts() async {
    try {
      final res = await http
          .get(Uri.parse(ApiUrls.driverEmergencyContactsUrl), headers: _headers)
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      final list = json.decode(res.body)['data'] as List? ?? [];
      return [
        for (final c in list)
          if (c is Map)
            EmergencyContact(
              id: c['_id']?.toString() ?? '',
              name: c['name']?.toString() ?? '',
              phone: c['phone']?.toString() ?? '',
              relationship: c['relationship']?.toString() ?? 'OTHER',
            ),
      ];
    } catch (_) {
      return null;
    }
  }

  /// Returns null on success, else the message to show.
  static Future<String?> addContact({
    required String name,
    required String phone,
    required String relationship,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse(ApiUrls.driverEmergencyContactsUrl),
            headers: _headers,
            body: json.encode({
              'name': name,
              'phone': phone,
              'relationship': relationship,
            }),
          )
          .timeout(_timeout);
      if (res.statusCode == 200 || res.statusCode == 201) return null;
      return _message(res, 'Could not add the contact. Try again.');
    } catch (_) {
      return 'Could not reach Movezy. Check your connection and try again.';
    }
  }

  static Future<bool> deleteContact(String id) async {
    try {
      final res = await http
          .delete(Uri.parse('${ApiUrls.driverEmergencyContactsUrl}/$id'), headers: _headers)
          .timeout(_timeout);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
