import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

enum NetworkStatus { online, weak, offline }

/// A persistent network indicator widget that shows Online/Weak/Offline status.
/// Place this at the top of your main scaffold or as an overlay.
class NetworkIndicator extends StatefulWidget {
  const NetworkIndicator({super.key});

  @override
  State<NetworkIndicator> createState() => _NetworkIndicatorState();
}

class _NetworkIndicatorState extends State<NetworkIndicator> {
  NetworkStatus _status = NetworkStatus.online;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _checkNetwork();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _checkNetwork());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkNetwork() async {
    try {
      final stopwatch = Stopwatch()..start();
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      stopwatch.stop();

      if (!mounted) return;

      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        // If lookup took > 2 seconds, consider it weak
        setState(() {
          _status = stopwatch.elapsedMilliseconds > 2000
              ? NetworkStatus.weak
              : NetworkStatus.online;
        });
      } else {
        setState(() => _status = NetworkStatus.offline);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = NetworkStatus.offline);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Don't show anything when online
    if (_status == NetworkStatus.online) return const SizedBox.shrink();

    final isOffline = _status == NetworkStatus.offline;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: isOffline ? const Color(0xFFDC2626) : const Color(0xFFF59E0B),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isOffline ? Icons.cloud_off : Icons.signal_wifi_statusbar_connected_no_internet_4,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              isOffline
                  ? 'you_are_offline'.tr
                  : 'weak_network'.tr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
