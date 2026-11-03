import 'package:flutter/material.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

/// The sender at pickup or the receiver at the drop, when the customer named
/// someone else (client decision, 2026-11-04): their number is shown in full
/// and tapping calls it directly. The customer's own number arrives masked
/// and keeps going through the masked call button, so [phoneOf] returns ''
/// for it and the row is hidden.
class ContactCallRow extends StatelessWidget {
  final String label;
  final String name;
  final String phone;

  const ContactCallRow({
    super.key,
    required this.label,
    required this.name,
    required this.phone,
  });

  /// A callable third-party number from a booking contact, or '' when it is
  /// missing or masked (the customer's own).
  static String phoneOf(dynamic raw) {
    final text = (raw ?? '').toString().trim();
    if (text.isEmpty || text.toUpperCase().contains('X')) return '';
    final digits = text.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 10 ? digits.substring(digits.length - 10) : '';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.appColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.appColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.person_outline, size: 20, color: AppColors.appColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF364B63))),
                Text(
                  [name, phone].where((s) => s.isNotEmpty).join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF132235)),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => launchUrl(Uri(scheme: 'tel', path: phone)),
            icon: Icon(Icons.call, size: 18, color: AppColors.appColor),
            label: Text('Call',
                style: TextStyle(
                    color: AppColors.appColor, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
