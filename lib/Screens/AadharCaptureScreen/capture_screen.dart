import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:image_picker/image_picker.dart';
import 'package:get/get.dart';
import 'package:movezy_driver_app/Screens/CropScreen/crop_screen.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';
import 'package:movezy_driver_app/Utils/ImageQualityValidator/image_quality_validator.dart';
import 'package:movezy_driver_app/Utils/DocumentValidator/document_validator.dart';

/// Configuration for a follow-up capture that happens immediately after the
/// current capture is submitted (e.g. front → back of Aadhaar in one flow).
class NextCaptureConfig {
  final String title;
  final String imageIcon;
  final String description;
  final DocumentType? expectedDocumentType;

  const NextCaptureConfig({
    required this.title,
    required this.imageIcon,
    required this.description,
    this.expectedDocumentType,
  });
}

class CaptureScreen extends StatefulWidget {
  final String title;
  final String imageIcon;
  final String description;
  final DocumentType? expectedDocumentType;

  /// If set, after the user submits the current capture, a second CaptureScreen
  /// opens automatically for the next image. The result returned will be a
  /// `List<String>` containing [firstPath, secondPath] instead of a single String.
  final NextCaptureConfig? nextCapture;

  const CaptureScreen({
    super.key,
    required this.title,
    required this.imageIcon,
    required this.description,
    this.expectedDocumentType,
    this.nextCapture,
  });

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  CameraController? _controller;
  List<CameraDescription>? cameras;
  XFile? capturedImage;
  bool _isValidating = false;
  bool _isFrontCamera = false;

  @override
  void initState() {
    super.initState();
    // Default to front camera for selfie
    _isFrontCamera = widget.expectedDocumentType == DocumentType.selfie;
    _initCamera();
  }

  Future<void> _initCamera() async {
    cameras = await availableCameras();
    if (cameras == null || cameras!.isEmpty) return;

    // Pick front or back camera
    CameraDescription selectedCamera = cameras!.first;
    if (_isFrontCamera) {
      selectedCamera = cameras!.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras!.first,
      );
    } else {
      selectedCamera = cameras!.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras!.first,
      );
    }

    _controller = CameraController(
      selectedCamera,
      ResolutionPreset.high,
      enableAudio: false,
    );
    await _controller!.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _switchCamera() async {
    if (cameras == null || cameras!.length < 2) return;

    _isFrontCamera = !_isFrontCamera;

    // Dispose current controller before creating a new one
    await _controller?.dispose();

    CameraDescription selectedCamera;
    if (_isFrontCamera) {
      selectedCamera = cameras!.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras!.first,
      );
    } else {
      selectedCamera = cameras!.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras!.first,
      );
    }

    _controller = CameraController(
      selectedCamera,
      ResolutionPreset.high,
      enableAudio: false,
    );
    await _controller!.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _captureImage() async {
    if (!_controller!.value.isInitialized) return;

    final image = await _controller!.takePicture();
    await _validateAndSetImage(image);
  }

  Future<void> _pickFromGallery() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image != null) {
      await _validateAndSetImage(image);
    }
  }

  Future<void> _validateAndSetImage(XFile image) async {
    setState(() => _isValidating = true);

    // Step 1: Check image quality (blur/darkness)
    final qualityResult = await ImageQualityValidator.validate(File(image.path));
    if (!qualityResult.isAcceptable) {
      setState(() => _isValidating = false);
      if (mounted) {
        await ImageQualityValidator.showQualityDialog(context, qualityResult);
      }
      return;
    }

    // Step 2: Validate document type if expected type is specified
    if (widget.expectedDocumentType != null) {
      final docResult = await DocumentValidator.validate(
        File(image.path),
        widget.expectedDocumentType!,
      );
      if (!docResult.isValid) {
        setState(() => _isValidating = false);
        if (mounted) {
          await DocumentValidator.showValidationDialog(context, docResult);
        }
        return;
      }
    }

    setState(() => _isValidating = false);

    setState(() {
      capturedImage = image;
    });
  }

  Future<void> _navigateToCropAndSubmit() async {
    if (capturedImage == null) return;

    final croppedPath = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => CropScreen(
          title: widget.title,
          file: File(capturedImage!.path),
        ),
      ),
    );

    if (croppedPath == null || !mounted) return;

    // If there's a next capture configured, open it immediately
    if (widget.nextCapture != null) {
      final nextConfig = widget.nextCapture!;
      final secondResult = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CaptureScreen(
            title: nextConfig.title,
            imageIcon: nextConfig.imageIcon,
            description: nextConfig.description,
            expectedDocumentType: nextConfig.expectedDocumentType,
          ),
        ),
      );

      if (secondResult != null && mounted) {
        // Return both paths as a List
        Navigator.pop(context, [croppedPath, secondResult as String]);
      }
    } else {
      // Single capture — return just the path
      Navigator.pop(context, croppedPath);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full-screen camera / captured image view
          Column(
            children: [
              // App bar
              Container(
                height: 97,
                padding: const EdgeInsets.only(top: 42),
                width: MediaQuery.of(context).size.width,
                decoration: BoxDecoration(
                  color: AppColors.appColor,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    InkWell(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: EdgeInsets.only(left: 16),
                        width: 40,
                        height: 35,
                        alignment: Alignment.center,
                        child: Image.asset("assets/back_arrow.png", color: Colors.white),
                      ),
                    ),
                    SizedBox(width: 11),
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Spacer()
                  ],
                ),
              ),

              // Camera preview or captured image — fills all available space
              Expanded(
                child: capturedImage != null
                    ? Image.file(
                        File(capturedImage!.path),
                        fit: BoxFit.contain,
                        width: double.infinity,
                      )
                    : (_controller != null && _controller!.value.isInitialized)
                        ? LayoutBuilder(
                            builder: (context, constraints) {
                              final cameraAspect = _controller!.value.aspectRatio;
                              return Center(
                                child: AspectRatio(
                                  aspectRatio: 1 / cameraAspect,
                                  child: CameraPreview(_controller!),
                                ),
                              );
                            },
                          )
                        : const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
              ),

              // Description + sample image (only when camera is live)
              if (capturedImage == null && widget.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 4),
                  child: Text(
                    widget.description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),

              // Bottom controls — capture mode
              if (capturedImage == null)
                Container(
                  height: 90,
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom > 0 ? 10 : 20),
                  decoration: BoxDecoration(
                    color: HexColor("#FFF0E6"),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Gallery button
                      IconButton(
                        onPressed: _pickFromGallery,
                        icon: Container(
                          height: 44,
                          width: 44,
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(200),
                          ),
                          child: Image.asset("assets/capture_icon.png"),
                        ),
                      ),

                      // Capture button
                      GestureDetector(
                        onTap: _captureImage,
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.deepOrange,
                              width: 3,
                            ),
                          ),
                          child: const Center(
                            child: CircleAvatar(
                              radius: 22,
                              backgroundColor: Colors.deepOrange,
                            ),
                          ),
                        ),
                      ),

                      // Camera switch button
                      IconButton(
                        onPressed: (cameras != null && cameras!.length > 1) ? _switchCamera : null,
                        icon: Container(
                          height: 44,
                          width: 44,
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(200),
                          ),
                          child: Icon(
                            Icons.cameraswitch_rounded,
                            color: (cameras != null && cameras!.length > 1) ? Colors.black87 : Colors.grey,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Bottom controls — preview mode (retake / submit)
              if (capturedImage != null)
                Container(
                  height: 90,
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom > 0 ? 10 : 20),
                  decoration: BoxDecoration(
                    color: HexColor("#FF6200").withOpacity(0.18),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(width: 20),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            capturedImage = null;
                            setState(() {});
                          },
                          child: Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: AppColors.appColor),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset("assets/re_take.png", height: 20),
                                SizedBox(width: 11),
                                Text('retake'.tr, style: TextStyle(color: AppColors.appColor, fontSize: 14, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 20),
                      Expanded(
                        child: InkWell(
                          onTap: _navigateToCropAndSubmit,
                          child: Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.appColor,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: AppColors.appColor),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset("assets/submit_icon.png", height: 20),
                                SizedBox(width: 11),
                                Text('submit'.tr, style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 20),
                    ],
                  ),
                ),
            ],
          ),

          // Validation loading overlay
          if (_isValidating)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Checking image quality...',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
