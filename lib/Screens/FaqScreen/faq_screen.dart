import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:movezy_driver_app/ApiUrls/api_urls.dart';
import 'package:movezy_driver_app/CommonWidgets/app_bar.dart';
import 'package:movezy_driver_app/Screens/SupportChat/support_chat_service.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  String? _selectedCategory;
  bool _showTicketForm = false;
  String? _ticketCategory;
  final _ticketDescController = TextEditingController();
  final _orderIdController = TextEditingController();
  final _supportService = SupportChatService();
  File? _screenshot;
  bool _submitting = false;

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
      {'q': 'When will I receive my payment?', 'a': 'Payments are processed every Monday. You will receive it in your linked bank account within 24-48 hours.'},
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
      {'q': 'Will insurance cover damages?', 'a': 'Yes, all active trips are covered under our partner insurance. File a claim within 24 hours with photos and police report if applicable.'},
    ],
    'account': [
      {'q': 'How to update my documents?', 'a': 'Go to Profile > My Documents to upload updated versions of your Aadhaar, PAN, DL, or RC.'},
      {'q': 'My account is suspended', 'a': 'Contact support with your driver ID. Suspension reasons are shown on your dashboard. Resolve the issue to get reactivated.'},
    ],
  };

  // Ticket categories
  static const List<String> _ticketCategories = [
    'Payment Issue',
    'Order Issue',
    'App Problem',
    'Emergency',
    'Other',
  ];

  @override
  void dispose() {
    _ticketDescController.dispose();
    _orderIdController.dispose();
    super.dispose();
  }

  /// Open the phone dialer with the support helpline.
  Future<void> _callSupport() async {
    final Uri phoneUri = Uri(scheme: 'tel', path: ApiUrls.supportPhoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('unable_to_place_call'.tr)),
        );
      }
    }
  }

  /// Pick a screenshot from the gallery to attach to the ticket.
  Future<void> _pickScreenshot() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (picked != null) {
        setState(() => _screenshot = File(picked.path));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('unable_to_pick_image'.tr)),
        );
      }
    }
  }

  /// Submit the ticket to the real support backend.
  Future<void> _submitTicket() async {
    if (_ticketCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('please_select_category'.tr)),
      );
      return;
    }
    final desc = _ticketDescController.text.trim();
    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('describe_issue'.tr)),
      );
      return;
    }

    setState(() => _submitting = true);
    // Fold the order id (and note about a screenshot) into the message body,
    // since the ticket API accepts a text message + optional bookingId.
    final orderId = _orderIdController.text.trim();
    final buffer = StringBuffer(desc);
    if (_screenshot != null) {
      buffer.write('\n\n[Screenshot attached by driver]');
    }

    final ticketId = await _supportService.createTicket(
      category: _ticketCategory!,
      subject: _ticketCategory!,
      message: buffer.toString(),
      bookingId: orderId.isNotEmpty ? orderId : null,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (ticketId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ticket_submitted'.tr)),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ticket_submit_failed'.tr)),
      );
    }
  }

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
                      if (_showTicketForm) {
                        setState(() => _showTicketForm = false);
                      } else if (_selectedCategory != null) {
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
                    _showTicketForm ? 'raise_a_ticket'.tr : 'help_support'.tr,
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
          Expanded(
            child: _showTicketForm
                ? _buildTicketForm()
                : _selectedCategory != null
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
                // Emergency - immediate escalation
                setState(() {
                  _showTicketForm = true;
                  _ticketCategory = 'Emergency';
                });
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
              onPressed: () => setState(() => _showTicketForm = true),
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
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _showTicketForm = true;
                            _ticketCategory = _selectedCategory == 'payment' ? 'Payment Issue'
                                : _selectedCategory == 'app' ? 'App Problem'
                                : _selectedCategory == 'accident' ? 'Emergency'
                                : 'Other';
                          });
                        },
                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                        label: Text('raise_a_ticket'.tr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.appColor,
                          side: BorderSide(color: AppColors.appColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _callSupport,
                        icon: const Icon(Icons.phone, size: 18),
                        label: Text('call_us'.tr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- RAISE TICKET FORM ---
  Widget _buildTicketForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('raise_a_ticket'.tr, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('team_reply_24h'.tr, style: const TextStyle(fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 20),

          // Category dropdown
          Text('category'.tr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonFormField<String>(
              decoration: const InputDecoration(border: InputBorder.none),
              hint: Text('select_category_hint'.tr, style: const TextStyle(fontSize: 14)),
              initialValue: _ticketCategory,
              items: _ticketCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (val) => setState(() => _ticketCategory = val),
            ),
          ),

          const SizedBox(height: 16),

          // Order ID (optional)
          Text('order_id'.tr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: TextField(
              controller: _orderIdController,
              decoration: InputDecoration(
                hintText: 'eg_order_id'.tr,
                hintStyle: const TextStyle(fontSize: 14, color: Colors.black38),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: InputBorder.none,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Description
          Text('describe_issue'.tr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: TextField(
              controller: _ticketDescController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'tell_us_what_happened'.tr,
                hintStyle: const TextStyle(fontSize: 14, color: Colors.black38),
                contentPadding: const EdgeInsets.all(16),
                border: InputBorder.none,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Attach screenshot
          InkWell(
            onTap: _pickScreenshot,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _screenshot != null ? AppColors.appColor : Colors.grey.shade300,
                    style: BorderStyle.solid),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_screenshot != null ? Icons.check_circle : Icons.attach_file,
                      color: _screenshot != null ? AppColors.appColor : Colors.grey.shade500, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _screenshot != null
                          ? _screenshot!.path.split(Platform.pathSeparator).last
                          : 'attach_screenshot_optional'.tr,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          color: _screenshot != null ? AppColors.appColor : Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Submit button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submitTicket,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.appColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 22, width: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : Text('submit_ticket'.tr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
