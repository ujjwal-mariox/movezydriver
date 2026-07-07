import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:custom_image_crop/custom_image_crop.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class RectangleCropScreen extends StatefulWidget {
  final String title;
  final File file;

  const RectangleCropScreen({
    required this.title,
    super.key,
    required this.file,
  });

  @override
  State<RectangleCropScreen> createState() => _RectangleCropScreenState();
}

class _RectangleCropScreenState extends State<RectangleCropScreen> {
  late CustomImageCropController controller;
  CustomCropShape _currentShape = CustomCropShape.Ratio;
  CustomImageFit _imageFit = CustomImageFit.fillCropSpace;
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _radiusController = TextEditingController();
  double _width = 16;
  double _height = 9;
  double _radius = 4;
  bool cropLoader = false;

  @override
  void initState() {
    super.initState();
    controller = CustomImageCropController();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _changeCropShape(CustomCropShape newShape) {
    setState(() {
      _currentShape = newShape;
    });
  }

  void _changeImageFit(CustomImageFit imageFit) {
    setState(() {
      _imageFit = imageFit;
    });
  }

  void _updateRatio() {
    setState(() {
      if (_widthController.text.isNotEmpty) {
        _width = double.tryParse(_widthController.text) ?? 16;
      }
      if (_heightController.text.isNotEmpty) {
        _height = double.tryParse(_heightController.text) ?? 9;
      }
      if (_radiusController.text.isNotEmpty) {
        _radius = double.tryParse(_radiusController.text) ?? 4;
      }
    });
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;

    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(widget.file.path);
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          toolbarHeight: 55,
          leadingWidth: 50,
          leading: GestureDetector(
            onTap: () {
              Navigator.of(context).pop(widget.file.path);
            },
            child: Container(
              padding: const EdgeInsets.only(left: 25, top: 8, bottom: 8, right: 4),
              child: Icon(Icons.clear_sharp),
            )
          ),
          centerTitle: true,
          title: Text(
            "Crop Image",
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
              fontWeight: FontWeight.w500,
              fontSize: 15,
            ),
          ),
          actions: [
            InkWell(
              onTap: () async {
                if (cropLoader == false) {
                  setState(() {
                    cropLoader = true;
                  });

                  final memoryImage = await controller.onCropImage();
                  if (memoryImage != null) {
                    File imageFile = await saveMemoryImageToFile(memoryImage);

                    Navigator.of(context).pop(imageFile.path);
                  }

                  setState(() {
                    cropLoader = false;
                  });
                }
              },
              child: Container(
                width: 70,
                height: 32,
                margin: EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    color: isDarkMode ? Colors.white : Colors.black),
                child: Center(
                  child: Text(
                    "Done",
                    style: TextStyle(
                      color: isDarkMode ? Colors.black : Colors.white,
                      fontWeight: FontWeight.w400,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: CustomImageCrop(
                    cropController: controller,
                    image: FileImage(widget.file),
                    shape: _currentShape,
                    ratio: _currentShape == CustomCropShape.Ratio
                        ? Ratio(width: _width, height: _height)
                        : null,
                    canRotate: true,
                    canMove: true,
                    canScale: true,
                    borderRadius:
                        _currentShape == CustomCropShape.Ratio ? _radius : 0,
                    customProgressIndicator: const CupertinoActivityIndicator(),
                    outlineColor: Colors.red,
                    imageFit: _imageFit,
                    imageFilter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom),
              ],
            ),
            if (cropLoader == true)
              CircularProgressIndicator()
          ],
        ),
      ),
    );
  }

  Widget getShapeIcon(CustomCropShape shape) {
    switch (shape) {
      case CustomCropShape.Circle:
        return const Icon(Icons.circle_outlined);
      case CustomCropShape.Square:
        return const Icon(Icons.square_outlined);
      case CustomCropShape.Ratio:
        return const Icon(Icons.crop_16_9_outlined);
    }
  }

  Future<File> saveMemoryImageToFile(MemoryImage memoryImage) async {
    // Convert MemoryImage to Uint8List
    Uint8List bytes = memoryImage.bytes;

    Directory tempDir = await getTemporaryDirectory();

    // Get the temporary directory
    String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    String filePath = '${tempDir.path}/cropped_image_$timestamp.png';

    // Write bytes to a file
    File file = File(filePath);
    await file.writeAsBytes(bytes);

    return file;
  }
}

extension CustomImageFitExtension on CustomImageFit {
  String get label {
    switch (this) {
      case CustomImageFit.fillCropSpace:
        return 'Fill crop space';
      case CustomImageFit.fitCropSpace:
        return 'Fit crop space';
      case CustomImageFit.fillCropHeight:
        return 'Fill crop height';
      case CustomImageFit.fillCropWidth:
        return 'Fill crop width';
      case CustomImageFit.fillVisibleSpace:
        return 'Fill visible space';
      case CustomImageFit.fitVisibleSpace:
        return 'Fit visible space';
      case CustomImageFit.fillVisibleHeight:
        return 'Fill visible height';
      case CustomImageFit.fillVisibleWidth:
        return 'Fill visible width';
    }
  }
}
