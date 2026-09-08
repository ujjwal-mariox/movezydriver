import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:movezy_driver_app/ApiUrls/api_urls.dart';
import 'package:movezy_driver_app/Screens/HelpSupportScreen/help_support_screen.dart';
import 'package:movezy_driver_app/Screens/TechnicianDashboard/dashboard_api_service.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

/// Help during a trip: call customer care, chat with support, or raise a
/// ticket with a real reason. The old in-trip icon silently filed a ticket
/// titled "Driver raised a ticket from the trip screen" with no way to say
/// what was wrong and no way to reach anyone.
const List<String> _ticketReasons = [
  'Customer not reachable',
  'Wrong pickup or drop address',
  'Goods do not match the booking',
  'Vehicle breakdown / accident',
  'Payment or fare issue',
  'Customer misbehaviour',
  'Other',
];

Future<void> showTripSupportSheet(
  BuildContext context, {
  required String bookingId,
  String screen = 'trip',
}) async {
  if (!ApiUrls.hasSupportPhone) {
    // Cheap refresh in case the admin set the number after app start.
    await ApiUrls.loadSupportContact();
  }
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) {
      Widget tile(IconData icon, String title, String subtitle, VoidCallback onTap, {Color? color}) {
        return ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (color ?? AppColors.appColor).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color ?? AppColors.appColor),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          onTap: onTap,
        );
      }

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Need help with this trip?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            if (ApiUrls.hasSupportPhone)
              tile(Icons.support_agent, 'Call customer care', ApiUrls.supportPhoneNumber, () async {
                Navigator.pop(ctx);
                final uri = Uri(scheme: 'tel', path: ApiUrls.supportPhoneNumber.replaceAll(' ', ''));
                if (!await launchUrl(uri)) {
                  Fluttertoast.showToast(msg: 'Could not open the dialer');
                }
              })
            else
              tile(Icons.support_agent, 'Call customer care', 'Helpline not published yet — use chat below', () {
                Fluttertoast.showToast(msg: 'The helpline number is not available yet. Please use chat.');
              }, color: Colors.grey),
            tile(Icons.chat_bubble_outline, 'Chat with support', 'Live support ticket chat', () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen()));
            }),
            tile(Icons.report_problem_outlined, 'Raise a ticket', 'Tell us what went wrong with this booking', () async {
              Navigator.pop(ctx);
              await _pickReasonAndRaise(context, bookingId, screen);
            }, color: Colors.orange),
            const SizedBox(height: 10),
          ],
        ),
      );
    },
  );
}

Future<void> _pickReasonAndRaise(BuildContext context, String bookingId, String screen) async {
  final reason = await showModalBottomSheet<String>(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text("What's the issue?", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          ..._ticketReasons.map(
            (r) => ListTile(
              dense: true,
              title: Text(r, style: const TextStyle(fontSize: 14)),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () => Navigator.pop(ctx, r),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (reason == null || !context.mounted) return;

  final resp = await DashboardApiService().raiseTicket(
    category: 'Order Issue',
    subject: '$reason — booking $bookingId',
    message: 'Driver reported "$reason" from the $screen screen.',
    bookingId: bookingId,
  );
  final ok = resp != null && (resp['code'] == 1 || resp['code'] == 200);
  Fluttertoast.showToast(
    msg: ok ? 'Ticket raised. Support will contact you.' : 'Could not raise ticket. Try again.',
  );
}
