import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';

/// YYYY-MM-DD, the shape the backend stores and the admin edits.
String? formatExpiryDate(DateTime? d) => d == null
    ? null
    : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Date picker for a document's expiry. Starts at today: an expired document
/// can't be registered, only renewed (the server refuses past dates too).
/// Brand orange, not the default Material purple.
Future<DateTime?> pickExpiryDate(BuildContext context, DateTime? current) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final initial = current != null && !current.isBefore(today) ? current : today;
  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: today,
    lastDate: DateTime(now.year + 20, 12, 31),
    builder: (context, child) => Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.light(
          primary: AppColors.appColor,
          onPrimary: Colors.white,
          onSurface: Colors.black87,
        ),
      ),
      child: child!,
    ),
  );
}

/// One mandatory expiry date: label with a red asterisk, the picked date (or
/// "Select date"), and a red outline + message when the form was submitted
/// without it. A stored date that has already passed shows in red as expired.
class ExpiryDateTile extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onPicked;
  final bool showError;
  final EdgeInsetsGeometry margin;

  const ExpiryDateTile({
    super.key,
    required this.label,
    required this.value,
    required this.onPicked,
    this.showError = false,
    this.margin = const EdgeInsets.only(left: 15, right: 15, bottom: 10),
  });

  @override
  Widget build(BuildContext context) {
    final missing = showError && value == null;
    final now = DateTime.now();
    final expired =
        value != null && value!.isBefore(DateTime(now.year, now.month, now.day));
    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () async {
              final picked = await pickExpiryDate(context, value);
              if (picked != null) onPicked(picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(
                  color: missing ? Colors.red : HexColor("#E1E6EF"),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.event_outlined, size: 18, color: HexColor("#607080")),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(TextSpan(children: [
                      TextSpan(
                        text: label,
                        style: TextStyle(fontSize: 13, color: HexColor("#607080")),
                      ),
                      const TextSpan(
                        text: ' *',
                        style: TextStyle(fontSize: 13, color: Colors.red),
                      ),
                    ])),
                  ),
                  Text(
                    value == null
                        ? 'select_date'.tr
                        : expired
                            ? '${formatExpiryDate(value)} · ${'expired'.tr}'
                            : formatExpiryDate(value)!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: value == null
                          ? AppColors.appColor
                          : expired
                              ? Colors.red
                              : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (missing)
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 4),
              child: Text(
                'expiry_date_required'.tr,
                style: const TextStyle(fontSize: 11, color: Colors.red),
              ),
            ),
        ],
      ),
    );
  }
}
