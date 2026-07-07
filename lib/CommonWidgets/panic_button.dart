import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:movezy_driver_app/ApiUrls/api_urls.dart';
import 'package:movezy_driver_app/Utils/PrefsManager/prefs_manager.dart';

/// A dedicated Panic Button widget for use during active trips.
/// Long-press to activate emergency alert.
class PanicButton extends StatefulWidget {
  /// Booking ID for the active trip (optional — SOS works without it).
  final String? bookingId;
  final VoidCallback? onActivate;

  const PanicButton({super.key, this.bookingId, this.onActivate});

  @override
  State<PanicButton> createState() => _PanicButtonState();
}

class _PanicButtonState extends State<PanicButton> with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _onPanicActivated() async {
    // Strong vibration pattern
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 100), () => HapticFeedback.heavyImpact());
    Future.delayed(const Duration(milliseconds: 200), () => HapticFeedback.heavyImpact());

    widget.onActivate?.call();

    if (!mounted) return;

    // Show a "sending…" dialog immediately, then update it with the REAL result
    // so the driver knows whether the alert actually reached the server.
    final sent = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SosDialog(send: _sendSosAlert),
    );

    // If it failed, the dialog already told the driver; nothing else to do here.
    if (sent == null) return;
  }

  /// Sends the SOS alert. Returns true only if the server accepted it, so the
  /// UI can show honest success/failure feedback (was: fire-and-forget, and it
  /// silently aborted whenever GPS failed — the alert looked "sent" but wasn't).
  Future<bool> _sendSosAlert() async {
    try {
      // Best-effort live location; if that fails, fall back to the LAST KNOWN
      // position so a GPS glitch doesn't kill the emergency alert entirely.
      Position? position;
      try {
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          await Geolocator.requestPermission();
        }
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (_) {
        position = null;
      }
      position ??= await Geolocator.getLastKnownPosition();

      if (position == null) {
        // No location at all — server rejects (0,0), so don't pretend it sent.
        return false;
      }

      final response = await http.post(
        Uri.parse(ApiUrls.sosTriggerUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Prefs.accessToken}',
        },
        body: jsonEncode({
          'location': {
            'lat': position.latitude,
            'lng': position.longitude,
          },
          if (widget.bookingId != null && widget.bookingId!.isNotEmpty)
            'bookingId': widget.bookingId,
        }),
      ).timeout(const Duration(seconds: 12));

      final body = jsonDecode(response.body);
      // ResponseMiddleware wraps as { code, message, data }; code:1 = success.
      return response.statusCode == 200 &&
          (body['code'] == 1 || body['success'] == true);
    } catch (e) {
      debugPrint('SOS network call failed: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulseValue = _pulseController.value;
        return GestureDetector(
          onLongPress: () {
            setState(() => _isPressed = true);
            _onPanicActivated();
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) setState(() => _isPressed = false);
            });
          },
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFDC2626),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.3 + pulseValue * 0.2),
                  blurRadius: 12 + pulseValue * 6,
                  spreadRadius: pulseValue * 3,
                ),
              ],
            ),
            child: AnimatedScale(
              scale: _isPressed ? 0.9 : 1.0,
              duration: const Duration(milliseconds: 100),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.emergency, color: Colors.white, size: 22),
                  Text(
                    'SOS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Emergency dialog that shows a live "sending…" state, then the real result of
/// the SOS call, always offering a direct Call 112 action.
class _SosDialog extends StatefulWidget {
  final Future<bool> Function() send;
  const _SosDialog({required this.send});

  @override
  State<_SosDialog> createState() => _SosDialogState();
}

class _SosDialogState extends State<_SosDialog> {
  bool _loading = true;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final ok = await widget.send();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _success = ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFDC2626);
    String message;
    if (_loading) {
      message = 'Sending emergency alert…';
    } else if (_success) {
      message =
          'Emergency alert sent. Your live location has been shared with the Movezy safety team. If you are in danger, call 112 now.';
    } else {
      message =
          'Could not send the alert (no network or location). Please call 112 directly.';
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.emergency, color: red, size: 28),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Emergency Alert',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_loading) ...[
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: red),
            ),
            const SizedBox(width: 12),
          ] else ...[
            Icon(_success ? Icons.check_circle : Icons.error_outline,
                color: _success ? Colors.green : red, size: 20),
            const SizedBox(width: 10),
          ],
          Expanded(child: Text(message, style: const TextStyle(height: 1.4))),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, _success),
          child: const Text('Close'),
        ),
        ElevatedButton.icon(
          onPressed: () async {
            final dialer = Uri(scheme: 'tel', path: '112');
            if (await canLaunchUrl(dialer)) {
              await launchUrl(dialer);
            }
          },
          icon: const Icon(Icons.phone, size: 18),
          label: const Text('Call 112'),
          style: ElevatedButton.styleFrom(
            backgroundColor: red,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
