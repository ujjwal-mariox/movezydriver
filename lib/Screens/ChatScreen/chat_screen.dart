import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:movezy_driver_app/CommonWidgets/app_bar.dart';
import 'package:movezy_driver_app/Screens/ChatScreen/chat_service.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';
import 'package:movezy_driver_app/Utils/ImageQualityValidator/image_quality_validator.dart';
import 'package:movezy_driver_app/Screens/CropScreen/crop_screen.dart';

class ChatScreen extends StatefulWidget {
  final String bookingId;
  final String customerName;

  const ChatScreen({
    super.key,
    required this.bookingId,
    this.customerName = 'Movezy',
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late ChatService _chatService;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  bool _isSendingImage = false;

  @override
  void initState() {
    super.initState();
    _chatService = ChatService(bookingId: widget.bookingId);
    _chatService.loadHistory().then((_) {
      _scrollToBottom();
    });
    _chatService.connect();

    // Auto-scroll when new messages arrive
    _chatService.messages.addListener(_onNewMessage);
  }

  void _onNewMessage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _chatService.messages.removeListener(_onNewMessage);
    _chatService.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _chatService.sendMessage(text);
    _messageController.clear();
  }

  Future<void> _pickAndSendImage() async {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text('camera'.tr.isNotEmpty ? 'camera'.tr : 'Camera'),
              onTap: () {
                Navigator.pop(ctx);
                _sendImageFrom(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text('gallery'.tr.isNotEmpty ? 'gallery'.tr : 'Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _sendImageFrom(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendImageFrom(ImageSource source) async {
    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1024,
    );
    if (picked == null) return;

    // Validate image quality
    final qualityResult = await ImageQualityValidator.validate(File(picked.path));
    if (!qualityResult.isAcceptable) {
      if (mounted) {
        await ImageQualityValidator.showQualityDialog(context, qualityResult);
      }
      return;
    }

    // Navigate to crop screen
    if (!mounted) return;
    final croppedPath = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => CropScreen(
          title: 'Crop Image',
          file: File(picked.path),
        ),
      ),
    );
    if (croppedPath == null || !mounted) return;

    setState(() => _isSendingImage = true);
    await _chatService.sendImage(File(croppedPath));
    setState(() => _isSendingImage = false);
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      body: Column(
        children: [
          // App Bar
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
                      child: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    ),
                  ),
                  Text(
                    widget.customerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Messages List
          Expanded(
            child: ValueListenableBuilder<List<ChatMessage>>(
              valueListenable: _chatService.messages,
              builder: (context, msgs, _) {
                if (msgs.isEmpty) {
                  return Center(
                    child: Text(
                      'send_message'.tr,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: msgs.length,
                  itemBuilder: (context, index) {
                    final msg = msgs[index];
                    if (msg.isImage) {
                      return _ImageBubble(
                        imageUrl: msg.imageUrl ?? '',
                        isMe: msg.isMe,
                        time: DateFormat('HH:mm').format(msg.createdAt),
                      );
                    }
                    return _ChatBubble(
                      text: msg.message,
                      isMe: msg.isMe,
                      time: DateFormat('HH:mm').format(msg.createdAt),
                    );
                  },
                );
              },
            ),
          ),

          // Sending image indicator
          if (_isSendingImage)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: LinearProgressIndicator(),
            ),

          // Message Input
          _buildChatInput(),
        ],
      ),
    );
  }

  Widget _buildChatInput() {
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
            const SizedBox(width: 5),
            const Icon(Icons.emoji_emotions_outlined),
            const SizedBox(width: 9),
            Expanded(
              child: TextField(
                controller: _messageController,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'send_message'.tr,
                  hintStyle: const TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                ),
              ),
            ),
            Transform.rotate(
              angle: 0.5,
              child: IconButton(
                icon: const Icon(Icons.attach_file, color: Colors.grey),
                onPressed: _pickAndSendImage,
              ),
            ),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: HexColor('#35B255'),
                ),
                child: Transform.rotate(
                  angle: 5.5,
                  child: const Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 5),
          ],
        ),
      ),
    );
  }
}

// ─── Chat Bubble ───

class _ChatBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final String time;

  const _ChatBubble({
    required this.text,
    required this.isMe,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: isMe ? AppColors.appColor : const Color(0xFFF6F6F6),
              borderRadius: BorderRadius.circular(10),
            ),
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                color: isMe ? Colors.white : Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8),
            child: Text(
              time,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Image Bubble ───

class _ImageBubble extends StatelessWidget {
  final String imageUrl;
  final bool isMe;
  final String time;

  const _ImageBubble({
    required this.imageUrl,
    required this.isMe,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            constraints: const BoxConstraints(maxWidth: 200, maxHeight: 200),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imageUrl.startsWith('http')
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(
                        width: 150,
                        height: 150,
                        color: Colors.grey.shade200,
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      errorWidget: (_, _, _) => Container(
                        width: 150,
                        height: 150,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image),
                      ),
                    )
                  : Image.asset(imageUrl, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8),
            child: Text(
              time,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
