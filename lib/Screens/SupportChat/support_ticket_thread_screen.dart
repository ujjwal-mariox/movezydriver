import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:intl/intl.dart';
import 'package:movezy_driver_app/CommonWidgets/app_bar.dart';
import 'package:movezy_driver_app/Screens/SupportChat/support_chat_service.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';

/// A two-way support conversation for one ticket. Loads history via REST and
/// receives admin replies live via socket.
class SupportTicketThreadScreen extends StatefulWidget {
  final String ticketId; // human TKT... id used by the API
  final String subject;

  const SupportTicketThreadScreen({
    super.key,
    required this.ticketId,
    this.subject = 'Support',
  });

  @override
  State<SupportTicketThreadScreen> createState() =>
      _SupportTicketThreadScreenState();
}

class _SupportTicketThreadScreenState extends State<SupportTicketThreadScreen> {
  final _service = SupportChatService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  SupportSocket? _socket;

  List<SupportMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
    _socket = SupportSocket(onMessage: _onLiveMessage)..connect();
  }

  @override
  void dispose() {
    _socket?.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final msgs = await _service.getMessages(widget.ticketId);
    if (!mounted) return;
    setState(() {
      _messages = msgs;
      _loading = false;
    });
    _scrollToBottom();
  }

  void _onLiveMessage(String ticketId, SupportMessage msg) {
    // Only append replies for THIS ticket.
    if (ticketId != widget.ticketId) return;
    if (msg.id != null && _messages.any((m) => m.id == msg.id)) return;
    if (!mounted) return;
    setState(() => _messages = [..._messages, msg]);
    _scrollToBottom();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);

    // Optimistically show the driver's message.
    final optimistic = SupportMessage(
      senderType: 'DRIVER',
      message: text,
      createdAt: DateTime.now(),
    );
    setState(() {
      _messages = [..._messages, optimistic];
      _controller.clear();
    });
    _scrollToBottom();

    final ok = await _service.reply(widget.ticketId, text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not send. Check your connection and retry.'),
        backgroundColor: Colors.red,
      ));
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.subject,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Support · ${widget.ticketId}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(color: AppColors.appColor))
                : _messages.isEmpty
                    ? const Center(
                        child: Text('No messages yet',
                            style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) => _bubble(_messages[i]),
                      ),
          ),
          _input(),
        ],
      ),
    );
  }

  Widget _bubble(SupportMessage msg) {
    final isMe = msg.isMe;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            const Padding(
              padding: EdgeInsets.only(left: 4, top: 4),
              child: Text('Support',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                      fontWeight: FontWeight.w600)),
            ),
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxWidth: 300),
            decoration: BoxDecoration(
              color: isMe ? AppColors.appColor : Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              msg.message,
              style: TextStyle(
                  fontSize: 15, color: isMe ? Colors.white : Colors.black87),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 6, right: 6, top: 3),
            child: Text(
              DateFormat('dd MMM, HH:mm').format(msg.createdAt),
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _input() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey, width: 0.3)),
        color: Colors.white,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Type a message to support...',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                ),
              ),
            ),
            GestureDetector(
              onTap: _send,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: HexColor('#35B255'),
                ),
                child: const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
