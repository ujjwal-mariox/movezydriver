import 'package:flutter_tts/flutter_tts.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Voice/TTS service for announcing key events to drivers
/// Helps drivers stay informed without looking at the screen
class VoiceService extends GetxService {
  static const String _voiceEnabledKey = 'voice_announcements_enabled';
  static const String _voiceVolumeKey = 'voice_volume';
  static const String _voicePitchKey = 'voice_pitch';
  static const String _voiceSpeedKey = 'voice_speed';
  static const String _voiceLanguageKey = 'voice_language';

  late FlutterTts _flutterTts;
  SharedPreferences? _prefs;

  // Observables for settings
  final RxBool isEnabled = true.obs;
  final RxDouble volume = 1.0.obs;
  final RxDouble pitch = 1.0.obs;
  final RxDouble speechRate = 0.5.obs;
  final RxString language = 'en-IN'.obs;
  final RxBool isSpeaking = false.obs;

  // Available languages for driver app
  final List<String> availableLanguages = [
    'en-IN', // English (India)
    'en-US', // English (US)
    'hi-IN', // Hindi
    'ta-IN', // Tamil
    'te-IN', // Telugu
    'kn-IN', // Kannada
    'ml-IN', // Malayalam
    'mr-IN', // Marathi
    'bn-IN', // Bengali
    'gu-IN', // Gujarati
    'pa-IN', // Punjabi
  ];

  Future<VoiceService> init() async {
    _flutterTts = FlutterTts();
    _prefs = await SharedPreferences.getInstance();
    
    await _loadSettings();
    await _configureTts();
    
    return this;
  }

  Future<void> _loadSettings() async {
    isEnabled.value = _prefs?.getBool(_voiceEnabledKey) ?? true;
    volume.value = _prefs?.getDouble(_voiceVolumeKey) ?? 1.0;
    pitch.value = _prefs?.getDouble(_voicePitchKey) ?? 1.0;
    speechRate.value = _prefs?.getDouble(_voiceSpeedKey) ?? 0.5;
    language.value = _prefs?.getString(_voiceLanguageKey) ?? 'en-IN';
  }

  Future<void> _configureTts() async {
    await _flutterTts.setVolume(volume.value);
    await _flutterTts.setPitch(pitch.value);
    await _flutterTts.setSpeechRate(speechRate.value);
    await _flutterTts.setLanguage(language.value);
    
    // Set up callbacks
    _flutterTts.setStartHandler(() {
      isSpeaking.value = true;
    });
    
    _flutterTts.setCompletionHandler(() {
      isSpeaking.value = false;
    });
    
    _flutterTts.setErrorHandler((msg) {
      isSpeaking.value = false;
      print('TTS Error: $msg');
    });
  }

  // ============ Settings Methods ============

  Future<void> setEnabled(bool enabled) async {
    isEnabled.value = enabled;
    await _prefs?.setBool(_voiceEnabledKey, enabled);
  }

  Future<void> setVolume(double vol) async {
    volume.value = vol.clamp(0.0, 1.0);
    await _prefs?.setDouble(_voiceVolumeKey, volume.value);
    await _flutterTts.setVolume(volume.value);
  }

  Future<void> setPitch(double p) async {
    pitch.value = p.clamp(0.5, 2.0);
    await _prefs?.setDouble(_voicePitchKey, pitch.value);
    await _flutterTts.setPitch(pitch.value);
  }

  Future<void> setSpeechRate(double rate) async {
    speechRate.value = rate.clamp(0.1, 1.0);
    await _prefs?.setDouble(_voiceSpeedKey, speechRate.value);
    await _flutterTts.setSpeechRate(speechRate.value);
  }

  Future<void> setLanguage(String lang) async {
    if (availableLanguages.contains(lang)) {
      language.value = lang;
      await _prefs?.setString(_voiceLanguageKey, lang);
      await _flutterTts.setLanguage(lang);
    }
  }

  // ============ Announcement Methods ============

  /// Generic speak method
  Future<void> speak(String text) async {
    if (!isEnabled.value || text.isEmpty) return;
    
    // Stop any current speech
    await _flutterTts.stop();
    
    // Speak the new text
    await _flutterTts.speak(text);
  }

  /// Stop current speech
  Future<void> stop() async {
    await _flutterTts.stop();
  }

  // ============ Pre-built Announcements ============

  /// Announce new order received
  Future<void> announceNewOrder({
    required String pickupArea,
    required double fare,
    required double distance,
  }) async {
    final message = 'New booking alert! '
        'Pickup from $pickupArea. '
        'Distance ${distance.toStringAsFixed(1)} kilometers. '
        'Fare ${fare.toStringAsFixed(0)} rupees.';
    await speak(message);
  }

  /// Announce order accepted
  Future<void> announceOrderAccepted({
    required String customerName,
    required String pickupAddress,
  }) async {
    final message = 'Order accepted! '
        'Customer $customerName. '
        'Proceed to pickup at $pickupAddress.';
    await speak(message);
  }

  /// Announce trip started
  Future<void> announceTripStarted({
    required String dropAddress,
    required double estimatedTime,
  }) async {
    final minutes = estimatedTime.toInt();
    final message = 'Trip started! '
        'Heading to $dropAddress. '
        'Estimated time $minutes minutes.';
    await speak(message);
  }

  /// Announce trip completed
  Future<void> announceTripCompleted({
    required double fare,
    required String paymentMode,
    double? tip,
  }) async {
    String message = 'Trip completed! '
        'Total fare ${fare.toStringAsFixed(0)} rupees. '
        'Payment mode $paymentMode.';
    
    if (tip != null && tip > 0) {
      message += ' You received a tip of ${tip.toStringAsFixed(0)} rupees!';
    }
    
    await speak(message);
  }

  /// Announce document upload success
  Future<void> announceDocumentUploaded({
    required String documentType,
  }) async {
    final message = '$documentType uploaded successfully!';
    await speak(message);
  }

  /// Announce earnings update
  Future<void> announceEarningsUpdate({
    required double todayEarnings,
    required int tripsCompleted,
  }) async {
    final message = 'Today\'s earnings update. '
        '${todayEarnings.toStringAsFixed(0)} rupees earned. '
        '$tripsCompleted trips completed.';
    await speak(message);
  }

  /// Announce navigation instruction
  Future<void> announceNavigation(String instruction) async {
    await speak(instruction);
  }

  /// Announce going online/offline
  Future<void> announceOnlineStatus(bool isOnline) async {
    final message = isOnline 
        ? 'You are now online. You will receive bookings.'
        : 'You are now offline. You will not receive new bookings.';
    await speak(message);
  }

  /// Announce rating received
  Future<void> announceRatingReceived({
    required double rating,
    String? feedback,
  }) async {
    String message = 'You received a ${rating.toStringAsFixed(1)} star rating!';
    
    if (rating >= 4.5) {
      message += ' Great job!';
    } else if (rating < 3.0) {
      message += ' Try to improve your service.';
    }
    
    await speak(message);
  }

  /// Announce network status change
  Future<void> announceNetworkStatus(bool isOnline) async {
    final message = isOnline 
        ? 'Network connection restored.'
        : 'Network connection lost. Some features may not work.';
    await speak(message);
  }

  /// Announce order cancellation
  Future<void> announceOrderCancelled({
    required String reason,
    bool byCustomer = true,
  }) async {
    final message = byCustomer
        ? 'Order cancelled by customer. Reason: $reason.'
        : 'Order has been cancelled. Reason: $reason.';
    await speak(message);
  }

  /// Test voice settings
  Future<void> testVoice() async {
    await speak('Voice announcements are enabled. This is how you will hear updates.');
  }

  @override
  void onClose() {
    _flutterTts.stop();
    super.onClose();
  }
}

/// Language display names
String getLanguageDisplayName(String code) {
  switch (code) {
    case 'en-IN': return 'English (India)';
    case 'en-US': return 'English (US)';
    case 'hi-IN': return 'Hindi';
    case 'ta-IN': return 'Tamil';
    case 'te-IN': return 'Telugu';
    case 'kn-IN': return 'Kannada';
    case 'ml-IN': return 'Malayalam';
    case 'mr-IN': return 'Marathi';
    case 'bn-IN': return 'Bengali';
    case 'gu-IN': return 'Gujarati';
    case 'pa-IN': return 'Punjabi';
    default: return code;
  }
}
