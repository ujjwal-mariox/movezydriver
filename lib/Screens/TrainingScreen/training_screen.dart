import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:movezy_driver_app/ApiUrls/api_urls.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';
import 'package:movezy_driver_app/Utils/PrefsManager/prefs_manager.dart';

class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  List<Map<String, dynamic>> _materials = [];
  bool _loading = true;
  int _completedCount = 0;
  int _totalLessons = 0;
  Set<String> _completedIds = {};

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${Prefs.accessToken}',
  };

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    await Future.wait([_fetchMaterials(), _fetchProgress()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _fetchMaterials() async {
    try {
      final response = await http.get(
        Uri.parse(ApiUrls.driverTrainingUrl),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body['data'];
        if (data is List) {
          _materials = List<Map<String, dynamic>>.from(data);
        }
      }
    } catch (e) {
      debugPrint('Error fetching training materials: $e');
    }
  }

  Future<void> _fetchProgress() async {
    try {
      final response = await http.get(
        Uri.parse(ApiUrls.driverTrainingProgressUrl),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body['data'];
        if (data is Map) {
          _completedCount = (data['completedLessons'] ?? 0) as int;
          _totalLessons = (data['totalLessons'] ?? 0) as int;
        }
      }
    } catch (e) {
      debugPrint('Error fetching training progress: $e');
    }
  }

  Future<void> _markAsCompleted(String materialId, {String? moduleId}) async {
    if (_completedIds.contains(materialId)) return;
    _completedIds.add(materialId);
    try {
      // Training materials are flat (no module/lesson hierarchy in the model),
      // so the material id is the lesson; fall back to it for the module too.
      await http.post(
        Uri.parse(ApiUrls.driverTrainingCompleteUrl(
          moduleId ?? materialId,
          materialId,
        )),
        headers: _headers,
      );
      await _fetchProgress();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error marking lesson complete: $e');
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // App bar
          Container(
            height: 140,
            width: double.infinity,
            color: AppColors.appColor,
            child: Padding(
              padding: const EdgeInsets.only(top: 50),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 35,
                      alignment: Alignment.center,
                      margin: const EdgeInsets.only(left: 16),
                      child: Image.asset('assets/back_arrow.png', color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Training & Learning',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Content
          Container(
            margin: const EdgeInsets.only(top: 100),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(25),
                topRight: Radius.circular(25),
              ),
            ),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _materials.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'No training materials available yet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: Colors.black54),
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        color: AppColors.appColor,
                        onRefresh: _fetchData,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                          children: [
                            // Progress bar
                            if (_totalLessons > 0) ...[
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.appColor.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.appColor.withValues(alpha: 0.2)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Your Progress',
                                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                                        ),
                                        Text(
                                          '$_completedCount / $_totalLessons completed',
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: LinearProgressIndicator(
                                        value: _totalLessons > 0 ? _completedCount / _totalLessons : 0,
                                        minHeight: 8,
                                        backgroundColor: Colors.grey.shade200,
                                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.appColor),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            // Material cards
                            ...List.generate(_materials.length, (index) {
                              return Padding(
                                padding: EdgeInsets.only(bottom: index < _materials.length - 1 ? 14 : 0),
                                child: _MaterialCard(
                                  material: _materials[index],
                                  onTap: () => _onMaterialTap(_materials[index]),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  void _onMaterialTap(Map<String, dynamic> material) {
    final type = material['type'] ?? '';
    final url = material['url'] ?? '';
    final title = material['title'] ?? '';
    final id = material['_id']?.toString() ?? '';

    // Mark as completed when user views it
    if (id.isNotEmpty) {
      _markAsCompleted(id);
    }

    switch (type) {
      case 'video':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _InAppVideoPlayer(url: url, title: title),
          ),
        );
        break;
      case 'youtube':
      case 'document':
        _openUrl(url);
        break;
      case 'image':
        _showImageViewer(context, url, title);
        break;
    }
  }

  void _showImageViewer(BuildContext context, String url, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullImageViewer(url: url, title: title),
      ),
    );
  }
}

class _MaterialCard extends StatelessWidget {
  final Map<String, dynamic> material;
  final VoidCallback onTap;

  const _MaterialCard({required this.material, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final type = material['type'] ?? '';
    final title = material['title'] ?? '';
    final description = material['description'] ?? '';
    final thumbnailUrl = material['thumbnailUrl'] ?? '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail / Preview
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: _buildPreview(type, thumbnailUrl),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _TypeBadge(type: type),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(String type, String thumbnailUrl) {
    if (thumbnailUrl.isNotEmpty) {
      return Stack(
        alignment: Alignment.center,
        children: [
          CachedNetworkImage(
            imageUrl: thumbnailUrl,
            width: double.infinity,
            height: 180,
            fit: BoxFit.cover,
            placeholder: (_, _) => Container(
              height: 180,
              color: const Color(0xFFF3F4F6),
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            errorWidget: (_, _, _) => _placeholderBox(type),
          ),
          if (type == 'youtube' || type == 'video')
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
            ),
        ],
      );
    }

    return _placeholderBox(type);
  }

  Widget _placeholderBox(String type) {
    IconData icon;
    switch (type) {
      case 'youtube':
        icon = Icons.play_circle_outline;
        break;
      case 'video':
        icon = Icons.videocam_outlined;
        break;
      case 'image':
        icon = Icons.image_outlined;
        break;
      case 'document':
        icon = Icons.description_outlined;
        break;
      default:
        icon = Icons.article_outlined;
    }

    return Container(
      height: 140,
      width: double.infinity,
      color: const Color(0xFFF3F4F6),
      child: Icon(icon, size: 40, color: const Color(0xFF9CA3AF)),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    String label;
    Color bg;
    Color fg;

    switch (type) {
      case 'youtube':
        label = 'YouTube';
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        break;
      case 'video':
        label = 'Video';
        bg = const Color(0xFFF3E8FF);
        fg = const Color(0xFF7C3AED);
        break;
      case 'image':
        label = 'Image';
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF2563EB);
        break;
      case 'document':
        label = 'Document';
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
        break;
      default:
        label = type;
        bg = const Color(0xFFF3F4F6);
        fg = const Color(0xFF6B7280);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

class _InAppVideoPlayer extends StatefulWidget {
  final String url;
  final String title;

  const _InAppVideoPlayer({required this.url, required this.title});

  @override
  State<_InAppVideoPlayer> createState() => _InAppVideoPlayerState();
}

class _InAppVideoPlayerState extends State<_InAppVideoPlayer> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    try {
      await _videoController.initialize();
      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControlsOnInitialize: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.appColor,
          handleColor: AppColors.appColor,
          bufferedColor: AppColors.appColor.withValues(alpha: 0.3),
          backgroundColor: Colors.grey.shade300,
        ),
      );
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Video player error: $e');
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title, style: const TextStyle(fontSize: 15)),
      ),
      body: Center(
        child: _hasError
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.white54, size: 48),
                  const SizedBox(height: 12),
                  const Text('Unable to play video', style: TextStyle(color: Colors.white54)),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () async {
                      final uri = Uri.tryParse(widget.url);
                      if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
                    child: Text('Open in browser', style: TextStyle(color: AppColors.appColor)),
                  ),
                ],
              )
            : _chewieController != null
                ? Chewie(controller: _chewieController!)
                : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}

class _FullImageViewer extends StatelessWidget {
  final String url;
  final String title;

  const _FullImageViewer({required this.url, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title, style: const TextStyle(fontSize: 15)),
      ),
      body: Center(
        child: InteractiveViewer(
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,
            placeholder: (_, _) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            errorWidget: (_, _, _) => const Icon(
              Icons.broken_image,
              color: Colors.white54,
              size: 48,
            ),
          ),
        ),
      ),
    );
  }
}
