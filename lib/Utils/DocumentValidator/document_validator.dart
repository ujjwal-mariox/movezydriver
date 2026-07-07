import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

enum DocumentType {
  aadhaar,
  pan,
  drivingLicense,
  selfie,
  vehicleRc,
  any,
}

class DocumentValidationResult {
  final bool isValid;
  final DocumentType detectedType;
  final String message;

  DocumentValidationResult({
    required this.isValid,
    required this.detectedType,
    this.message = '',
  });
}

class DocumentValidator {
  static final _textRecognizer = TextRecognizer();

  // Keywords that identify each document type (front + back sides)
  static const _aadhaarKeywords = [
    'aadhaar',
    'uidai',
    'unique identification',
    'government of india',
    'enrolment',
    'vid',
    'male',
    'female',
    'dob',
    'year of birth',
    // Back side keywords
    'address',
    'pin code',
    'pincode',
    's/o',
    'd/o',
    'w/o',
    'c/o',
  ];

  static const _panKeywords = [
    'permanent account number',
    'income tax',
    'pan',
    'dept',
    'father',
    'govt. of india',
  ];

  static const _drivingLicenseKeywords = [
    'driving licence',
    'driving license',
    'transport',
    'motor vehicle',
    'class of vehicle',
    'lmv',
    'mcwg',
    'validity',
    'rto',
  ];

  static const _vehicleRcKeywords = [
    'registration certificate',
    'registering authority',
    'chassis',
    'engine',
    'fuel type',
    'owner name',
    'rto',
    'form 23',
  ];

  /// Validates that the captured image matches the expected document type.
  /// For [DocumentType.selfie] and [DocumentType.any], no text validation is done.
  static Future<DocumentValidationResult> validate(
    File imageFile,
    DocumentType expectedType,
  ) async {
    // Selfie and 'any' type don't need text-based validation
    if (expectedType == DocumentType.selfie || expectedType == DocumentType.any) {
      return DocumentValidationResult(
        isValid: true,
        detectedType: expectedType,
      );
    }

    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      final fullText = recognizedText.text.toLowerCase();

      if (fullText.trim().isEmpty) {
        return DocumentValidationResult(
          isValid: false,
          detectedType: DocumentType.any,
          message: _getNoTextMessage(expectedType),
        );
      }

      final detectedType = _detectDocumentType(fullText);

      if (detectedType == expectedType) {
        return DocumentValidationResult(
          isValid: true,
          detectedType: detectedType,
        );
      }

      // Detected a DIFFERENT document type clearly — reject it
      if (detectedType != DocumentType.any) {
        return DocumentValidationResult(
          isValid: false,
          detectedType: detectedType,
          message: 'This looks like a ${_documentName(detectedType)}. '
              'Please upload your ${_documentName(expectedType)}.',
        );
      }

      // Could not confidently identify the document type.
      // This is common for back sides of documents (e.g. Aadhaar back has
      // address + QR code but no strong identifying keywords).
      // Allow it through — we only block when a DIFFERENT document is detected.
      return DocumentValidationResult(
        isValid: true,
        detectedType: expectedType,
      );
    } catch (e) {
      // If ML Kit fails, allow the image through
      return DocumentValidationResult(
        isValid: true,
        detectedType: expectedType,
      );
    }
  }

  static DocumentType _detectDocumentType(String text) {
    int aadhaarScore = _matchScore(text, _aadhaarKeywords);
    int panScore = _matchScore(text, _panKeywords);
    int dlScore = _matchScore(text, _drivingLicenseKeywords);
    int rcScore = _matchScore(text, _vehicleRcKeywords);

    // Need at least 2 keyword matches to be confident
    int maxScore = [aadhaarScore, panScore, dlScore, rcScore]
        .reduce((a, b) => a > b ? a : b);

    if (maxScore < 2) return DocumentType.any;

    if (maxScore == aadhaarScore) return DocumentType.aadhaar;
    if (maxScore == panScore) return DocumentType.pan;
    if (maxScore == dlScore) return DocumentType.drivingLicense;
    if (maxScore == rcScore) return DocumentType.vehicleRc;

    return DocumentType.any;
  }

  static int _matchScore(String text, List<String> keywords) {
    int score = 0;
    for (final keyword in keywords) {
      if (text.contains(keyword)) score++;
    }
    return score;
  }

  static String _documentName(DocumentType type) {
    switch (type) {
      case DocumentType.aadhaar:
        return 'Aadhaar Card';
      case DocumentType.pan:
        return 'PAN Card';
      case DocumentType.drivingLicense:
        return 'Driving License';
      case DocumentType.vehicleRc:
        return 'Vehicle RC';
      case DocumentType.selfie:
        return 'Selfie';
      case DocumentType.any:
        return 'Document';
    }
  }

  static String _getNoTextMessage(DocumentType expectedType) {
    return 'No text detected on the image. '
        'Please capture a clear photo of your ${_documentName(expectedType)}.';
  }

  /// Shows a dialog informing the user about document mismatch.
  static Future<void> showValidationDialog(
    BuildContext context,
    DocumentValidationResult result,
  ) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.document_scanner, color: Colors.red, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Wrong Document',
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

  /// Extracts useful data from a document image using OCR.
  /// Returns a map with extracted fields like 'name', 'number', 'vehicleNumber', etc.
  static Future<Map<String, String>> extractData(
    File imageFile,
    DocumentType documentType,
  ) async {
    final Map<String, String> extracted = {};

    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      final fullText = recognizedText.text;
      final lines = fullText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

      switch (documentType) {
        case DocumentType.aadhaar:
          _extractAadhaarData(lines, fullText, extracted);
          break;
        case DocumentType.pan:
          _extractPanData(lines, fullText, extracted);
          break;
        case DocumentType.drivingLicense:
          _extractDLData(lines, fullText, extracted);
          break;
        case DocumentType.vehicleRc:
          _extractRCData(lines, fullText, extracted);
          break;
        default:
          break;
      }
    } catch (e) {
      debugPrint('OCR extraction error: $e');
    }

    return extracted;
  }

  static void _extractAadhaarData(List<String> lines, String fullText, Map<String, String> result) {
    // Extract 12-digit Aadhaar number
    final aadhaarRegex = RegExp(r'\b\d{4}\s?\d{4}\s?\d{4}\b');
    final match = aadhaarRegex.firstMatch(fullText);
    if (match != null) {
      result['aadhaarNumber'] = match.group(0)!.replaceAll(' ', '');
    }

    // Extract name — typically the line before DOB or after "Government of India"
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      // Name is usually a line with only letters and spaces, at least 3 chars
      if (RegExp(r'^[A-Za-z\s]{3,}$').hasMatch(line) &&
          !line.toLowerCase().contains('government') &&
          !line.toLowerCase().contains('india') &&
          !line.toLowerCase().contains('male') &&
          !line.toLowerCase().contains('female') &&
          !line.toLowerCase().contains('aadhaar') &&
          !line.toLowerCase().contains('uidai')) {
        result['name'] = line;
        break;
      }
    }
  }

  static void _extractPanData(List<String> lines, String fullText, Map<String, String> result) {
    // PAN number: 5 letters + 4 digits + 1 letter
    final panRegex = RegExp(r'\b[A-Z]{5}\d{4}[A-Z]\b');
    final match = panRegex.firstMatch(fullText.toUpperCase());
    if (match != null) {
      result['panNumber'] = match.group(0)!;
    }

    // Extract name — line after "Name" or a line with all caps letters
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (RegExp(r'^[A-Z\s]{3,}$').hasMatch(line) &&
          !line.contains('INCOME') &&
          !line.contains('PERMANENT') &&
          !line.contains('INDIA') &&
          !line.contains('GOVT') &&
          !line.contains('DEPT')) {
        result['name'] = line;
        break;
      }
    }
  }

  static void _extractDLData(List<String> lines, String fullText, Map<String, String> result) {
    // DL number patterns vary by state, common format: XX-XXXXXXXXXX or XXXX-XXXXXXX
    final dlRegex = RegExp(r'\b[A-Z]{2}[-\s]?\d{2}[-\s]?\d{4,11}\b');
    final match = dlRegex.firstMatch(fullText.toUpperCase());
    if (match != null) {
      result['dlNumber'] = match.group(0)!;
    }

    // Extract name
    for (int i = 0; i < lines.length; i++) {
      final lower = lines[i].toLowerCase();
      if (lower.contains('name') && i + 1 < lines.length) {
        final nameLine = lines[i + 1].trim();
        if (nameLine.isNotEmpty && !RegExp(r'^\d').hasMatch(nameLine)) {
          result['name'] = nameLine;
          break;
        }
      }
    }
  }

  static void _extractRCData(List<String> lines, String fullText, Map<String, String> result) {
    // Vehicle registration number: XX-XX-XX-XXXX or XX XX XX XXXX
    final rcRegex = RegExp(r'\b[A-Z]{2}[-\s]?\d{1,2}[-\s]?[A-Z]{1,3}[-\s]?\d{1,4}\b');
    final match = rcRegex.firstMatch(fullText.toUpperCase());
    if (match != null) {
      result['vehicleNumber'] = match.group(0)!;
    }

    // Extract owner name
    for (int i = 0; i < lines.length; i++) {
      final lower = lines[i].toLowerCase();
      if ((lower.contains('owner') || lower.contains('name')) && i + 1 < lines.length) {
        final nameLine = lines[i + 1].trim();
        if (nameLine.isNotEmpty && !RegExp(r'^\d').hasMatch(nameLine)) {
          result['ownerName'] = nameLine;
          break;
        }
      }
    }

    // Extract vehicle type from text
    final textLower = fullText.toLowerCase();
    if (textLower.contains('motor cycle') || textLower.contains('two wheeler') || textLower.contains('2w')) {
      result['vehicleType'] = '2 Wheeler';
    } else if (textLower.contains('three wheeler') || textLower.contains('3w') || textLower.contains('auto')) {
      result['vehicleType'] = '3 Wheeler';
    } else if (textLower.contains('four wheeler') || textLower.contains('4w') || textLower.contains('car') || textLower.contains('truck') || textLower.contains('lcv') || textLower.contains('hcv')) {
      result['vehicleType'] = '4 Wheeler';
    }
  }

  /// Call this when the app is being disposed to free resources.
  static void dispose() {
    _textRecognizer.close();
  }
}
