import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:movezy_driver_app/AppNavigation/app_navigation.dart';
import 'package:movezy_driver_app/CommonWidgets/app_bar.dart';
import 'package:movezy_driver_app/Screens/SupportChat/support_chat_service.dart';
import 'package:movezy_driver_app/Screens/SupportChat/support_ticket_thread_screen.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';

/// Lists the driver's support tickets and lets them open a two-way chat with
/// support, or start a new ticket. Replaces the old fake "Live Chat" bot.
class SupportTicketsScreen extends StatefulWidget {
  const SupportTicketsScreen({super.key});

  @override
  State<SupportTicketsScreen> createState() => _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends State<SupportTicketsScreen> {
  final _service = SupportChatService();
  List<SupportTicket> _tickets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final tickets = await _service.getTickets();
    if (!mounted) return;
    setState(() {
      _tickets = tickets;
      _loading = false;
    });
  }

  Future<void> _openThread(SupportTicket t) async {
    await pushTo(
      context,
      SupportTicketThreadScreen(ticketId: t.ticketId, subject: t.subject),
    );
    _load(); // refresh statuses after returning
  }

  Future<void> _newTicket() async {
    final result = await showDialog<_NewTicketData>(
      context: context,
      builder: (_) => const _NewTicketDialog(),
    );
    if (result == null) return;

    final ticketId = await _service.createTicket(
      category: result.category,
      subject: result.subject,
      message: result.message,
    );
    if (!mounted) return;
    if (ticketId != null) {
      await _load();
      // Jump straight into the new thread.
      await pushTo(
        context,
        SupportTicketThreadScreen(
            ticketId: ticketId, subject: result.subject),
      );
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not create ticket. Try again.'),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newTicket,
        backgroundColor: AppColors.appColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New ticket', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          commonAppBar(
            height: 100,
            context: context,
            child: Container(
              padding: const EdgeInsets.only(top: 47),
              child: Row(
                children: [
                  const SizedBox(width: 5),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.only(left: 16),
                      width: 40,
                      height: 35,
                      alignment: Alignment.center,
                      child: const Icon(Icons.arrow_back_ios,
                          color: Colors.white),
                    ),
                  ),
                  const Text(
                    'Support',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(color: AppColors.appColor))
                : _tickets.isEmpty
                    ? _empty()
                    : RefreshIndicator(
                        color: AppColors.appColor,
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _tickets.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) => _ticketCard(_tickets[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _empty() {
    return ListView(
      children: [
        const SizedBox(height: 120),
        const Icon(Icons.support_agent, size: 64, color: Colors.grey),
        const SizedBox(height: 12),
        const Center(
          child: Text('No support tickets yet',
              style: TextStyle(color: Colors.grey, fontSize: 15)),
        ),
        const SizedBox(height: 6),
        const Center(
          child: Text('Tap "New ticket" to chat with support',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        ),
      ],
    );
  }

  Widget _ticketCard(SupportTicket t) {
    return InkWell(
      onTap: () => _openThread(t),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.appColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.support_agent, color: AppColors.appColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${t.ticketId}  ·  ${_time(t.lastMessageAt ?? t.createdAt)}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            _statusChip(t.status),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    Color c;
    switch (status) {
      case 'RESOLVED':
      case 'CLOSED':
        c = Colors.green;
        break;
      case 'WAITING_FOR_USER':
        c = Colors.orange;
        break;
      case 'IN_PROGRESS':
        c = Colors.blue;
        break;
      default:
        c = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style:
            TextStyle(fontSize: 10, color: c, fontWeight: FontWeight.w600),
      ),
    );
  }

  String _time(DateTime? d) {
    if (d == null) return '';
    return DateFormat('dd MMM, HH:mm').format(d);
  }
}

class _NewTicketData {
  final String category;
  final String subject;
  final String message;
  _NewTicketData(this.category, this.subject, this.message);
}

class _NewTicketDialog extends StatefulWidget {
  const _NewTicketDialog();

  @override
  State<_NewTicketDialog> createState() => _NewTicketDialogState();
}

class _NewTicketDialogState extends State<_NewTicketDialog> {
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  String _category = 'other';

  static const _categories = [
    'payment',
    'booking',
    'account',
    'vehicle',
    'other',
  ];

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('New support ticket',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: _categories
                  .map((c) => DropdownMenuItem(
                      value: c, child: Text(c[0].toUpperCase() + c.substring(1))))
                  .toList(),
              onChanged: (v) => setState(() => _category = v ?? 'other'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _subjectController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'Subject', hintText: 'Brief summary'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _messageController,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Message',
                hintText: 'Describe your issue',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final subject = _subjectController.text.trim();
            final message = _messageController.text.trim();
            if (subject.isEmpty || message.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Please fill subject and message.'),
              ));
              return;
            }
            Navigator.pop(
                context, _NewTicketData(_category, subject, message));
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.appColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Create'),
        ),
      ],
    );
  }
}
