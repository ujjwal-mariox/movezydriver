import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:movezy_driver_app/AppNavigation/app_navigation.dart';
import 'package:movezy_driver_app/Screens/HelpSupportScreen/help_support_screen.dart';
import 'package:movezy_driver_app/CommonWidgets/app_bar.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  String? _selectedCategory;

  // Support categories with icons
  static const List<Map<String, dynamic>> _categories = [
    {'id': 'payment', 'labelKey': 'payment_not_received', 'icon': Icons.account_balance_wallet_outlined, 'color': Color(0xFF2575FC)},
    {'id': 'customer', 'labelKey': 'customer_not_answering', 'icon': Icons.phone_disabled_outlined, 'color': Color(0xFFF59E0B)},
    {'id': 'app', 'labelKey': 'app_not_working', 'icon': Icons.phonelink_erase_outlined, 'color': Color(0xFFEF4444)},
    {'id': 'accident', 'labelKey': 'accident_support', 'icon': Icons.warning_amber_rounded, 'color': Color(0xFFDC2626)},
    {'id': 'account', 'labelKey': 'account_query', 'icon': Icons.person_outline, 'color': Color(0xFF8B5CF6)},
  ];

  // FAQ data per category
  static const Map<String, List<Map<String, String>>> _faqData = {
    'payment': [
      // Was: "Payments are processed every Monday … within 24-48 hours."
      // There is no weekly payout run and no 24-48h guarantee anywhere in the
      // system: earnings are frozen on each completed booking, the driver has
      // to request a withdrawal, and an operator releases it from the admin
      // payout queue. The answer now describes that actual flow.
      {'q': 'When will I receive my payment?', 'a': 'Your earnings from a trip are added to your withdrawable balance as soon as the trip completes. Open My Wallet and tap Withdraw to request a payout to your registered bank account. Each request is reviewed and released by our payouts team, and you can follow its status in My Wallet.'},
      {'q': 'My payment amount seems incorrect', 'a': 'Check your trip details in History. If the fare doesn\'t match, raise a ticket with the Order ID and we will review it.'},
      {'q': 'How to add my bank account?', 'a': 'Go to Profile > Bank Details to add or update your bank account information.'},
    ],
    'customer': [
      {'q': 'Customer is not picking up calls', 'a': 'Wait for 5 minutes at the pickup location. If the customer doesn\'t respond, you can cancel the booking without penalty.'},
      {'q': 'Customer wants to change drop location', 'a': 'Accept the change only through the app. The fare will be recalculated automatically.'},
    ],
    'app': [
      {'q': 'App is crashing frequently', 'a': 'Clear the app cache and ensure you are using the latest version. If the issue persists, reinstall the app.'},
      {'q': 'Location is not updating', 'a': 'Check that GPS/Location permission is enabled. Also ensure battery optimization is disabled for this app.'},
      {'q': 'Cannot toggle online/offline', 'a': 'This may happen if your documents are under review. Check your approval status on the dashboard.'},
    ],
    'accident': [
      {'q': 'What to do in case of accident?', 'a': 'First ensure safety. Call emergency services if needed. Then tap the Panic Button in the app to notify our support team immediately.'},
      // A "Will insurance cover damages?" entry used to answer "Yes, all active
      // trips are covered under our partner insurance. File a claim within 24
      // hours…". No such driver cover or claims process exists: the only
      // insurance in the platform is an optional add-on a CUSTOMER can buy on a
      // booking to cover their goods. Rather than replace one invented answer
      // with another, the question is removed — a driver asking this needs a
      // real answer from support, which the ticket button below reaches.
    ],
    'account': [
      {'q': 'How to update my documents?', 'a': 'Go to Profile > My Documents to upload updated versions of your Aadhaar, PAN, DL, or RC.'},
      {'q': 'My account is suspended', 'a': 'Contact support with your driver ID. Suspension reasons are shown on your dashboard. Resolve the issue to get reactivated.'},
    ],
  };


  @override
  void dispose() {
    super.dispose();
  }

  // A _callSupport() helper used to live here and dialled
  // ApiUrls.supportPhoneNumber, which was the placeholder +91 1234567890.
  // There is no real helpline for the app to dial, so the "Call Us" control
  // was removed instead of pointing drivers at a stranger's number. Raising a
  // ticket (below) is the path that genuinely reaches Movezy support.

  /// Pick a screenshot from the gallery to attach to the ticket.


  /// Resolve what the driver typed in "Order ID" to a booking's ObjectId.
  ///
  /// The field's own hint asks for an order id, but what the driver sees
  /// everywhere in the app (trip summary, booking details, reviews) is
  /// `bookingNumber` — a short human code like MZ1233. The ticket endpoint runs
  /// `new Types.ObjectId(bookingId)` on whatever it is given, so any typed
  /// value threw a BSON cast error server-side and the whole submission came
  /// back as a generic failure. Now the typed value is matched against the
  /// driver's own bookings to find the real id; anything that can't be matched
  /// is carried in the message text instead of being sent as an ObjectId.

  /// Submit the ticket to the real support backend.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: Column(
        children: [
          commonAppBar(
            height: 100,
            context: context,
            child: Container(
              padding: const EdgeInsets.only(top: 50),
              child: Row(
                children: [
                  InkWell(
                    onTap: () {
                      if (_selectedCategory != null) {
                        setState(() => _selectedCategory = null);
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.only(left: 16),
                      width: 40, height: 35,
                      alignment: Alignment.center,
                      child: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    ),
                  ),
                  Text(
                    'help_support'.tr,
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
          Expanded(
            child: _selectedCategory != null
                ? _buildFaqList()
                : _buildCategoryList(),
          ),
        ],
      ),
    );
  }

  // --- CATEGORY SELECTION ---
  Widget _buildCategoryList() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('how_can_we_help'.tr, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('select_category_below'.tr, style: const TextStyle(fontSize: 14, color: Colors.black54)),
          const SizedBox(height: 20),

          ..._categories.map((cat) => _categoryTile(cat)),

          const SizedBox(height: 24),

          // Emergency banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626),
              borderRadius: BorderRadius.circular(16),
            ),
            child: InkWell(
              onTap: () {
                // Emergency — straight into the guided support flow, which
                // fast-paths emergencies to a human. This screen's own inline
                // ticket form is gone: it duplicated that flow with a second,
                // dumber route to the same endpoint.
                pushTo(context, const HelpSupportScreen());
              },
              child: Row(
                children: [
                  const Icon(Icons.emergency, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('emergency_question'.tr, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                        Text('get_immediate_support'.tr, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Raise ticket button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => pushTo(context, const HelpSupportScreen()),
              icon: const Icon(Icons.support_agent),
              label: Text('raise_support_ticket'.tr, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.appColor,
                side: BorderSide(color: AppColors.appColor, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryTile(Map<String, dynamic> cat) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => setState(() => _selectedCategory = cat['id']),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: (cat['color'] as Color).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(cat['icon'] as IconData, color: cat['color'] as Color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text((cat['labelKey'] as String).tr, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  // --- FAQ LIST for selected category ---
  Widget _buildFaqList() {
    final faqs = _faqData[_selectedCategory] ?? [];
    final catInfo = _categories.firstWhere((c) => c['id'] == _selectedCategory);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(catInfo['icon'] as IconData, color: catInfo['color'] as Color, size: 22),
              const SizedBox(width: 10),
              Text((catInfo['labelKey'] as String).tr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),

          if (faqs.isEmpty)
            Center(child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text('no_faqs_available'.tr, style: const TextStyle(color: Colors.black54)),
            )),

          ...faqs.map((faq) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6),
              ],
            ),
            child: Theme(
              data: ThemeData().copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                title: Text(faq['q']!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                children: [
                  Text(faq['a']!, style: const TextStyle(fontSize: 13, color: Colors.black54, height: 1.5)),
                ],
              ),
            ),
          )),

          const SizedBox(height: 24),

          // "Still need help?" button
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.appColor.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Text('still_need_help'.tr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('connect_support'.tr, style: const TextStyle(fontSize: 13, color: Colors.black54)),
                const SizedBox(height: 16),
                // "Call Us" used to sit beside this and dialled the placeholder
                // support number; with no real line to dial, raising a ticket
                // is the only control here and takes the full width.
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => pushTo(context, const HelpSupportScreen()),
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: Text('raise_a_ticket'.tr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.appColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- RAISE TICKET FORM ---
}
