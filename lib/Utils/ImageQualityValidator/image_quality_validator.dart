import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

class ImageQualityResult {
  final bool isAcceptable;
  final bool isBlurry;
  final bool isTooDark;
  final String message;

  ImageQualityResult({
    required this.isAcceptable,
    this.isBlurry = false,
    this.isTooDark = false,
    this.message = '',
  });
}

class ImageQualityValidator {
  /// Validates image quality by checking for blur and darkness.
  /// Returns an [ImageQualityResult] indicating whether the image is acceptable.
  static Future<ImageQualityResult> validate(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) {
        return ImageQualityResult(
          isAcceptable: false,
          message: 'Unable to process image',
        );
      }

      // Resize for faster processing
      final resized = img.copyResize(image, width: 200);

      final isDark = _isTooDark(resized);
      final isBlurry = _isBlurry(resized);

      if (isDark && isBlurry) {
        return ImageQualityResult(
          isAcceptable: false,
          isTooDark: true,
          isBlurry: true,
          message: 'Image is too dark and blurry. Please retake in better lighting.',
        );
      }
      if (isDark) {
        return ImageQualityResult(
          isAcceptable: false,
          isTooDark: true,
          message: 'Image is too dark. Please retake in better lighting.',
        );
      }
      if (isBlurry) {
        return ImageQualityResult(
          isAcceptable: false,
          isBlurry: true,
          message: 'Image is blurry. Please hold steady and retake.',
        );
      }

      return ImageQualityResult(isAcceptable: true);
    } catch (e) {
      // If validation fails, allow the image through rather than blocking
      return ImageQualityResult(isAcceptable: true);
    }
  }

  /// Checks if the image is too dark by computing average brightness.
  /// Threshold: average brightness < 40 out of 255 is considered too dark.
  static bool _isTooDark(img.Image image) {
    double totalBrightness = 0;
    int pixelCount = 0;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();
        // Perceived brightness formula
        final brightness = (0.299 * r + 0.587 * g + 0.114 * b);
        totalBrightness += brightness;
        pixelCount++;
      }
    }

    final avgBrightness = totalBrightness / pixelCount;
    return avgBrightness < 40;
  }

  /// Checks if the image is blurry using Laplacian variance.
  /// A low variance indicates a blurry image.
  static bool _isBlurry(img.Image image) {
    // Convert to grayscale
    final grayscale = img.grayscale(image);

    // Laplacian kernel
    final List<List<int>> kernel = [
      [0, 1, 0],
      [1, -4, 1],
      [0, 1, 0],
    ];

    double sum = 0;
    double sumSq = 0;
    int count = 0;

    for (int y = 1; y < grayscale.height - 1; y++) {
      for (int x = 1; x < grayscale.width - 1; x++) {
        double laplacian = 0;
        for (int ky = -1; ky <= 1; ky++) {
          for (int kx = -1; kx <= 1; kx++) {
            final pixel = grayscale.getPixel(x + kx, y + ky);
            final intensity = pixel.r.toDouble();
            laplacian += intensity * kernel[ky + 1][kx + 1];
          }
        }
        sum += laplacian;
        sumSq += laplacian * laplacian;
        count++;
      }
    }

    final mean = sum / count;
    final variance = (sumSq / count) - (mean * mean);

    // Threshold: variance below 100 is considered blurry
    return variance < 100;
  }

  /// Shows a dialog informing the user about image quality issues.
  static Future<void> showQualityDialog(
    BuildContext context,
    ImageQualityResult result,
  ) async {
    String title = 'Image Quality Issue';
    IconData icon = Icons.warning_amber_rounded;
    Color iconColor = Colors.orange;

    if (result.isTooDark) {
      icon = Icons.brightness_low;
      iconColor = Colors.amber;
    }
    if (result.isBlurry) {
      icon = Icons.blur_on;
      iconColor = Colors.red;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: Text(
          result.message,
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Retake',
              style: TextStyle(
                color: Color(0xFFFF6200),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
