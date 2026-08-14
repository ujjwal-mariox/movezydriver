import 'dart:convert';
import 'package:movezy_driver_app/CommonWidgets/app_bar.dart';
import 'package:movezy_driver_app/CommonWidgets/button_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:movezy_driver_app/ApiUrls/api_urls.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';
import 'package:movezy_driver_app/Utils/PrefsManager/prefs_manager.dart';
import 'package:http/http.dart' as http;

class DriverInstructionsScreen extends StatefulWidget {
  const DriverInstructionsScreen({super.key});

  @override
  State<DriverInstructionsScreen> createState() => _DriverInstructionsScreenState();
}

class _DriverInstructionsScreenState extends State<DriverInstructionsScreen> {
  bool agreed = false;
  bool _loading = true;
  bool _submitting = false;
  List<_InstructionItem> items = [];

  @override
  void initState() {
    super.initState();
    _fetchInstructions();
  }

  Future<void> _fetchInstructions() async {
    try {
      final response = await http.get(
        Uri.parse(ApiUrls.driverInstructionsUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Prefs.accessToken}',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        final data = body['data'] as List<dynamic>? ?? [];
        setState(() {
          items = data.map((e) => _InstructionItem(
            icon: e['icon']?.toString() ?? '📋',
            text: e['text']?.toString() ?? '',
          )).toList();
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  /// Record the acknowledgment server-side (sets
  /// driver.instructionsAcknowledgedAt), then close. Previously "Agree" only
  /// popped the screen and never called the endpoint, and the checkbox was
  /// never enforced.
  Future<void> _acknowledge() async {
    if (_submitting) return;
    if (!agreed) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please tick the checkbox to confirm you have read the instructions.'),
      ));
      return;
    }
    setState(() => _submitting = true);
    try {
      final response = await http.post(
        Uri.parse(ApiUrls.driverInstructionsAcknowledgeUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Prefs.accessToken}',
        },
      ).timeout(const Duration(seconds: 20));

      final body = json.decode(response.body);
      final ok = response.statusCode == 200 &&
          (body['code'] == 1 || body['success'] == true);
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Instructions acknowledged.'),
          backgroundColor: Colors.green,
        ));
        Navigator.pop(context);
      } else {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not record acknowledgment. Try again.'),
          backgroundColor: Colors.red,
        ));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Network error. Try again.'),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          commonAppBar(
              height : 100,
              context : context,
              child: Container(
                padding: const EdgeInsets.only(top: 50),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    InkWell(
                      onTap: ()
                      {
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: EdgeInsets.only(left: 16),
                        width: 40,
                        height: 35,
                        alignment: Alignment.center,
                        child: Image.asset("assets/back_arrow.png", color: Colors.white,),
                      ),
                    ),

                    SizedBox(width: 8,),

                    Text(
                      "Driver Instructions",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    Spacer(),

                  ],
                ),
              )
          ),

          // Top spacing
          const SizedBox(height: 18),

          // Intro text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Please read the instructions carefully before starting your rides or deliveries.',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Cards list in an Expanded scroll area
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                    ? Center(child: Text('no_instructions'.tr))
                    : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var item in items) ...[
                    InstructionCard(item: item),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 6),

                  // checkbox line
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const SizedBox(width: 6),
                      Checkbox(
                        value: agreed,
                        onChanged: (v) => setState(() => agreed = v ?? false),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4)),
                        activeColor: const Color(0xFF2F6BED),
                      ),
                      Text(
                        'I have read and understood all instructions',
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),

          // Bottom green Agree button (full width with safe margin)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 0),
            child: ButtonWidget(
              text: _submitting ? 'Submitting...' : 'Agree',
              onTap: _acknowledge,
              // Visually reflect that the checkbox gates the action.
              backgroundColor: agreed
                  ? AppColors.appColor
                  : AppColors.appColor.withValues(alpha: 0.45),
            ),
          ),

          SizedBox(height: 20,)
        ],
      ),
    );
  }
}

class InstructionCard extends StatelessWidget {
  final _InstructionItem item;
  const InstructionCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final cardColor = Colors.white;
    final iconColor = const Color(0xFF2F6BED);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HexColor("#E1E6EF")),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      child: Row(
        children: [
          // icon circle
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: _icon(iconColor)),
          ),

          const SizedBox(width: 14),

          // text
          Expanded(
            child: Text(
              item.text,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF111827),
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
  /// The design's line icons, chosen by the semantic key stored on the record.
  ///
  /// The card used to render `item.icon` as raw TEXT, so it could only ever show
  /// an emoji — the seeded record held "🚕" and the design's blue clock / car /
  /// parcel / card / phone glyphs were unreachable. Admins can still type an
  /// emoji (the field is free text in the admin panel), so anything unrecognised
  /// falls through to rendering it as text rather than vanishing.
  static const Map<String, IconData> _glyphs = {
    'clock': Icons.access_time,
    'time': Icons.access_time,
    'vehicle': Icons.directions_car,
    'car': Icons.directions_car,
    'parcel': Icons.inventory_2,
    'package': Icons.inventory_2,
    'payment': Icons.credit_card,
    'cashless': Icons.credit_card,
    'call': Icons.phone,
    'phone': Icons.phone,
  };

  Widget _icon(Color color) {
    final glyph = _glyphs[item.icon.trim().toLowerCase()];
    if (glyph != null) return Icon(glyph, size: 26, color: color);
    // Not a known key — show whatever the admin entered (usually an emoji).
    return Text(item.icon, style: const TextStyle(fontSize: 26));
  }
}

class _InstructionItem {
  final String icon;
  final String text;
  const _InstructionItem({required this.icon, required this.text});
}