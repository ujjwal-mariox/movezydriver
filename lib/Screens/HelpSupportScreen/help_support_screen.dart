import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:movezy_driver_app/CommonWidgets/app_bar.dart';
import 'package:movezy_driver_app/Screens/SupportChat/support_chat_service.dart';
import 'package:movezy_driver_app/Screens/SupportChat/support_tickets_screen.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final SupportChatService _supportService = SupportChatService();
  bool _isTyping = false;
  bool _showSupportOptions = false;
  // Guards the ticket-creating actions so a double tap can't open two tickets.
  bool _raisingTicket = false;

  // Predefined bot responses based on keywords
  final Map<String, String> _botResponses = {
    'payment': 'payment_bot_response',
    'money': 'payment_bot_response',
    'not received': 'payment_bot_response',
    'cancel': 'cancel_bot_response',
    'cancellation': 'cancel_bot_response',
    'app': 'app_issue_bot_response',
    'crash': 'app_issue_bot_response',
    'not working': 'app_issue_bot_response',
    'accident': 'accident_bot_response',
    'emergency': 'accident_bot_response',
    'document': 'document_bot_response',
    'documents': 'document_bot_response',
    'upload': 'document_bot_response',
    'account': 'account_bot_response',
    'profile': 'account_bot_response',
    'suspend': 'account_bot_response',
    'location': 'location_bot_response',
    'gps': 'location_bot_response',
    'customer': 'customer_bot_response',
    'rider': 'customer_bot_response',
    'not answering': 'customer_bot_response',
  };

  // Quick action buttons
  final List<Map<String, dynamic>> _quickActions = [
    {'key': 'emergency', 'icon': Icons.emergency_outlined},
    {'key': 'payment_issue', 'icon': Icons.account_balance_wallet_outlined},
    {'key': 'app_problem', 'icon': Icons.phonelink_erase_outlined},
    {'key': 'document_help', 'icon': Icons.description_outlined},
    {'key': 'account_issue', 'icon': Icons.person_outline},
  ];

  // Bot field-collection state. After a category is identified the bot asks
  // a short series of questions (Order ID → date/time → payment type) and
  // packages the answers as context when escalating to a human.
  bool _collectingDetails = false;
  String? _currentCategory;
  int _detailsStep = 0;
  final Map<String, String> _collectedDetails = {};

  static const List<Map<String, String>> _detailsQuestions = [
    {'key': 'orderId', 'promptKey': 'bot_ask_order_id'},
    {'key': 'when', 'promptKey': 'bot_ask_when'},
    {'key': 'paymentType', 'promptKey': 'bot_ask_payment_type'},
  ];

  @override
  void initState() {
    super.initState();
    // Add initial greeting message
    Future.delayed(const Duration(milliseconds: 500), () {
      _addBotMessage('bot_greeting');
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addBotMessage(String messageKey) {
    setState(() {
      _messages.add(ChatMessage(
        text: messageKey.tr,
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
  }

  /// Post a bot bubble whose text is already final (not a translation key).
  void _addRawBotMessage(String text) {
    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
  }

  void _addUserMessage(String text) {
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _addUserMessage(text);
    _messageController.clear();

    // Show typing indicator
    setState(() => _isTyping = true);

    // Process message and respond
    Future.delayed(const Duration(milliseconds: 1200), () {
      setState(() => _isTyping = false);
      _processUserMessage(text);
    });
  }

  void _processUserMessage(String text) {
    // If the bot is in the middle of collecting details, route the message
    // into the next question slot instead of running keyword matching.
    if (_collectingDetails) {
      _captureDetailAnswer(text);
      return;
    }

    final lowerText = text.toLowerCase();

    // Emergency fast-path: skip the bot, route directly to human priority.
    if (lowerText.contains('emergency') ||
        lowerText.contains('accident') ||
        lowerText.contains('sos') ||
        lowerText.contains('urgent')) {
      _handleEmergencyEscalation();
      return;
    }

    String? responseKey;
    String? matchedCategory;

    for (final entry in _botResponses.entries) {
      if (lowerText.contains(entry.key)) {
        responseKey = entry.value;
        matchedCategory = entry.value;
        break;
      }
    }

    if (responseKey != null) {
      _addBotMessage(responseKey);
      // Start field collection for issue categories that benefit from context.
      if (matchedCategory == 'payment_bot_response' ||
          matchedCategory == 'cancel_bot_response' ||
          matchedCategory == 'app_issue_bot_response' ||
          matchedCategory == 'customer_bot_response') {
        _startDetailsCollection(matchedCategory!);
      }
    } else {
      _addBotMessage('bot_general_response');
    }

    // After a few messages, offer human support option
    if (_messages.where((m) => m.isUser).length >= 2 && !_showSupportOptions) {
      Future.delayed(const Duration(milliseconds: 800), () {
        setState(() => _showSupportOptions = true);
        _addBotMessage('bot_offer_support');
      });
    }
  }

  void _startDetailsCollection(String category) {
    _collectingDetails = true;
    _currentCategory = category;
    _detailsStep = 0;
    _collectedDetails.clear();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      _addBotMessage(_detailsQuestions[0]['promptKey']!);
    });
  }

  void _captureDetailAnswer(String text) {
    final question = _detailsQuestions[_detailsStep];
    _collectedDetails[question['key']!] = text;
    _detailsStep++;

    if (_detailsStep < _detailsQuestions.length) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (!mounted) return;
        _addBotMessage(_detailsQuestions[_detailsStep]['promptKey']!);
      });
      return;
    }

    // All answers captured — summarize and offer human escalation.
    _collectingDetails = false;
    final summary = _detailsQuestions
        .map((q) => '• ${q['key']}: ${_collectedDetails[q['key']!] ?? '-'}')
        .join('\n');
    setState(() {
      _messages.add(ChatMessage(
        text: '${'bot_details_captured'.tr}\n\n$summary',
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();

    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() => _showSupportOptions = true);
      _addBotMessage('bot_offer_support');
    });
  }

  /// The answers the bot collected, formatted for a ticket body. Empty string
  /// when nothing was collected — never filler.
  String get _detailsSummary => _collectedDetails.isEmpty
      ? ''
      : '\n\n${_detailsQuestions.where((q) => (_collectedDetails[q['key']!] ?? '').trim().isNotEmpty).map((q) => '• ${q['key']}: ${_collectedDetails[q['key']!]}').join('\n')}';

  /// The issue category the bot matched, if any, as a ticket-subject suffix.
  /// `_currentCategory` was previously written and never read.
  String _issueContext() {
    final category = _currentCategory;
    if (category == null || category.isEmpty) return '';
    // Keys look like "payment_bot_response" — the leading token is the topic.
    return ' (${category.split('_').first})';
  }

  /// The ticket category for a call-back escalation. Every escalation used to
  /// be filed under the literal category "Call Back", so the admin queue (and
  /// the server's priority derivation) saw no topic at all — a payment
  /// complaint and a general question both landed as MEDIUM "Call Back".
  /// The bot already knows the topic; put it on the ticket.
  String _ticketCategory() {
    switch (_currentCategory) {
      case 'payment_bot_response':
        return 'Payment Issue';
      case 'cancel_bot_response':
        return 'Trip Cancellation';
      case 'app_issue_bot_response':
        return 'App Problem';
      case 'customer_bot_response':
        return 'Customer Issue';
      default:
        return 'Call Back';
    }
  }

  Future<void> _handleEmergencyEscalation() async {
    HapticFeedback.heavyImpact();
    setState(() => _showSupportOptions = true);

    // This used to auto-dial ApiUrls.supportPhoneNumber, which was the
    // placeholder +91 1234567890 — a driver escalating an accident was sent to
    // a number that belongs to nobody. There is no real support line available
    // to the app, so the escalation now does the one thing that genuinely
    // reaches Movezy: it opens a support ticket on the driver's account, which
    // lands in the admin support queue and can be replied to in-app.
    if (_raisingTicket) return;
    setState(() => _raisingTicket = true);
    // Immediate acknowledgement so the tap isn't silent while the request is
    // in flight. It states what is happening, not what will happen.
    _addRawBotMessage('Raising an emergency support request…');

    final ticketId = await _supportService.createTicket(
      category: 'Emergency',
      subject: 'Emergency - driver needs urgent help${_issueContext()}',
      message:
          'Driver raised an emergency from Help & Support.$_detailsSummary',
    );

    if (!mounted) return;
    setState(() => _raisingTicket = false);

    if (ticketId != null) {
      _addRawBotMessage(
        'Emergency request raised — ticket $ticketId. It is in the support '
        'queue and replies arrive in Live Chat.\n\n'
        'If anyone is injured or in danger, contact your local emergency '
        'services now — do not wait for this ticket.',
      );
    } else {
      _addRawBotMessage(
        '${'ticket_submit_failed'.tr}\n\n'
        'If anyone is injured or in danger, contact your local emergency '
        'services now.',
      );
    }
  }

  void _handleQuickAction(String key) {
    _addUserMessage(key.tr);
    
    setState(() => _isTyping = true);
    Future.delayed(const Duration(milliseconds: 1000), () {
      setState(() => _isTyping = false);
      
      switch (key) {
        case 'emergency':
          _handleEmergencyEscalation();
          return;
        case 'payment_issue':
          _addBotMessage('payment_bot_response');
          _startDetailsCollection('payment_bot_response');
          break;
        case 'app_problem':
          _addBotMessage('app_issue_bot_response');
          _startDetailsCollection('app_issue_bot_response');
          break;
        case 'document_help':
          _addBotMessage('document_bot_response');
          break;
        case 'account_issue':
          _addBotMessage('account_bot_response');
          break;
      }
      
      // Show support options after quick action response
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!_showSupportOptions) {
          setState(() => _showSupportOptions = true);
          _addBotMessage('bot_offer_support');
        }
      });
    });
  }

  void _showSupportOptionsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'connect_with_support'.tr,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'support_available_time'.tr,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),

            // The "Call Support" option that used to head this list dialled
            // ApiUrls.supportPhoneNumber — a placeholder number. No real
            // helpline is published to the app, so the option is gone rather
            // than sending drivers to a dead line. The two options below both
            // reach the real support queue.

            // Live Chat Option — opens the REAL support ticket chat (was a
            // fake scripted bot that never reached a human).
            _buildSupportOption(
              icon: Icons.chat_bubble_outline,
              iconColor: AppColors.appColor,
              title: 'live_chat_support'.tr,
              subtitle: 'live_chat_desc'.tr,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SupportTicketsScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            // Call Back Option — raises a real ticket asking support to call
            // the driver back on their registered number.
            // The subtitle used to read "We'll call you within a few minutes",
            // an SLA nothing in the system backs; it now states only what the
            // action does. (Plain English: there is no translation key for this
            // sentence and the localisation files are outside this change.)
            _buildSupportOption(
              icon: Icons.phone_callback_outlined,
              iconColor: Colors.orange,
              title: 'call_back_support'.tr,
              subtitle: 'Ask support to call your registered number',
              onTap: () {
                Navigator.pop(context);
                _requestCallBack();
              },
            ),

            const SizedBox(height: 24),
            
            // Cancel button
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'maybe_later'.tr,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportOption({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  /// Raise a real "call back" ticket.
  ///
  /// This used to only print "A support agent will call you back shortly" into
  /// the chat. Nothing was sent anywhere — no ticket existed, so nobody was
  /// ever going to call. It now posts to the same support-ticket endpoint the
  /// FAQ form and Live Chat use, and reports the ticket id the server returned
  /// (or the failure), so the confirmation matches what actually happened.
  Future<void> _requestCallBack() async {
    if (_raisingTicket) return;
    setState(() => _raisingTicket = true);

    final ticketId = await _supportService.createTicket(
      category: _ticketCategory(),
      subject: 'Call back requested${_issueContext()}',
      message:
          'Driver requested a call back on their registered number.$_detailsSummary',
    );

    if (!mounted) return;
    setState(() => _raisingTicket = false);

    if (ticketId != null) {
      _addRawBotMessage(
        'Call back requested — ticket $ticketId. Support will call your '
        'registered number and can also reply in Live Chat.$_detailsSummary',
      );
    } else {
      _addRawBotMessage('ticket_submit_failed'.tr);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: Column(
        children: [
          // App Bar
          commonAppBar(
            height: 100,
            context: context,
            child: Container(
              padding: const EdgeInsets.only(top: 50),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.only(left: 16),
                      width: 40,
                      height: 35,
                      alignment: Alignment.center,
                      child: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    ),
                  ),
                  Text(
                    'help_support'.tr,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (_showSupportOptions)
                    IconButton(
                      onPressed: _showSupportOptionsSheet,
                      icon: const Icon(Icons.headset_mic_outlined, color: Colors.white),
                    ),
                ],
              ),
            ),
          ),

          // Chat Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isTyping && index == _messages.length) {
                  return _buildTypingIndicator();
                }
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),

          // Quick Actions (show only at the start)
          if (_messages.length <= 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'quick_help'.tr,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _quickActions.map((action) {
                      return ActionChip(
                        avatar: Icon(action['icon'] as IconData, size: 18, color: AppColors.appColor),
                        label: Text(
                          (action['key'] as String).tr,
                          style: GoogleFonts.poppins(fontSize: 13),
                        ),
                        onPressed: () => _handleQuickAction(action['key'] as String),
                        backgroundColor: AppColors.appColor.withValues(alpha: 0.08),
                        side: BorderSide(color: AppColors.appColor.withValues(alpha: 0.3)),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

          // Connect to Support Button (show after bot conversation).
          // The "Call" button that sat to the left of this dialled the
          // placeholder support number; with no real line to dial it is gone
          // and Live Support (real tickets + chat) takes the full width.
          if (_showSupportOptions)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showSupportOptionsSheet,
                icon: const Icon(Icons.support_agent, size: 18),
                label: Text('live_support'.tr, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.appColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

          // Message Input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'type_message'.tr,
                          hintStyle: GoogleFonts.poppins(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: (_) => _handleSendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.appColor,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _handleSendMessage,
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.appColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isUser ? AppColors.appColor : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(message.isUser ? 18 : 4),
                  bottomRight: Radius.circular(message.isUser ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message.text,
                style: GoogleFonts.poppins(
                  color: message.isUser ? Colors.white : Colors.black87,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (message.isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.appColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                _buildDot(1),
                _buildDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + (index * 200)),
      builder: (context, value, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.grey.shade400.withValues(alpha: 0.5 + (value * 0.5)),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}
