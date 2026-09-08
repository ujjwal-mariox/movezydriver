import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:movezy_driver_app/ApiUrls/api_urls.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';
import 'package:movezy_driver_app/Utils/PrefsManager/prefs_manager.dart';

/// Tap-to-send lines above the chat box. Admin-managed on the server, so ops
/// can change the wording without an app release. Hidden while loading or
/// when the server has none.
class QuickRepliesBar extends StatefulWidget {
  final ValueChanged<String> onSend;
  const QuickRepliesBar({super.key, required this.onSend});

  @override
  State<QuickRepliesBar> createState() => _QuickRepliesBarState();
}

class _QuickRepliesBarState extends State<QuickRepliesBar> {
  static List<String>? _cached;
  List<String> _replies = _cached ?? const [];

  @override
  void initState() {
    super.initState();
    if (_cached == null) _load();
  }

  Future<void> _load() async {
    try {
      final res = await http.get(
        Uri.parse(ApiUrls.chatQuickRepliesUrl),
        headers: {'Authorization': 'Bearer ${Prefs.accessToken}'},
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return;
      final body = jsonDecode(res.body);
      final data = body is Map ? body['data'] : null;
      final list = data is Map ? data['replies'] : null;
      if (list is! List) return;
      final texts = list
          .map((e) => (e is Map ? e['text'] : e)?.toString() ?? '')
          .where((t) => t.isNotEmpty)
          .toList();
      _cached = texts;
      if (mounted) setState(() => _replies = texts);
    } catch (_) {
      // Chips are a convenience; typing still works.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_replies.isEmpty) return const SizedBox.shrink();
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _replies.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (_, i) => ActionChip(
            label: Text(
              _replies[i],
              style: TextStyle(fontSize: 12, color: AppColors.appColor, fontWeight: FontWeight.w500),
            ),
            backgroundColor: AppColors.appColor.withOpacity(0.08),
            side: BorderSide(color: AppColors.appColor.withOpacity(0.35)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onPressed: () => widget.onSend(_replies[i]),
          ),
        ),
      ),
    );
  }
}
