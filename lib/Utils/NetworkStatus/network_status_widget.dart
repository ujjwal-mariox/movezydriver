import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Network status indicator that shows Online/Weak/Offline status
/// Should be placed in the app bar or as an overlay
class NetworkStatusWidget extends StatefulWidget {
  final bool showAlways;
  final bool compact;
  
  const NetworkStatusWidget({
    super.key,
    this.showAlways = true,
    this.compact = false,
  });

  @override
  State<NetworkStatusWidget> createState() => _NetworkStatusWidgetState();
}

class _NetworkStatusWidgetState extends State<NetworkStatusWidget> {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  NetworkStatus _status = NetworkStatus.online;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _subscription = _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    _onConnectivityChanged(results);
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    if (!mounted) return;
    
    NetworkStatus newStatus;
    if (results.contains(ConnectivityResult.none)) {
      newStatus = NetworkStatus.offline;
    } else if (results.contains(ConnectivityResult.mobile)) {
      // Could check signal strength for weak connection
      newStatus = NetworkStatus.online;
    } else if (results.contains(ConnectivityResult.wifi)) {
      newStatus = NetworkStatus.online;
    } else {
      newStatus = NetworkStatus.weak;
    }

    if (newStatus != _status) {
      setState(() => _status = newStatus);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Don't show if online and not showAlways
    if (_status == NetworkStatus.online && !widget.showAlways) {
      return const SizedBox.shrink();
    }

    final config = _getStatusConfig();
    
    if (widget.compact) {
      return Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: config.color,
          shape: BoxShape.circle,
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: config.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: config.color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, color: config.color, size: 14),
          const SizedBox(width: 4),
          Text(
            config.label,
            style: TextStyle(
              color: config.color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  _StatusConfig _getStatusConfig() {
    switch (_status) {
      case NetworkStatus.online:
        return _StatusConfig(
          color: const Color(0xFF1F8B4C),
          icon: Icons.wifi,
          label: 'Online',
        );
      case NetworkStatus.weak:
        return _StatusConfig(
          color: const Color(0xFFF59E0B),
          icon: Icons.signal_wifi_statusbar_connected_no_internet_4,
          label: 'Weak',
        );
      case NetworkStatus.offline:
        return _StatusConfig(
          color: const Color(0xFFE02D3C),
          icon: Icons.wifi_off,
          label: 'Offline',
        );
    }
  }
}

enum NetworkStatus { online, weak, offline }

class _StatusConfig {
  final Color color;
  final IconData icon;
  final String label;

  _StatusConfig({
    required this.color,
    required this.icon,
    required this.label,
  });
}

/// Global network banner that shows connection issues
class NetworkBanner extends StatefulWidget {
  final Widget child;
  
  const NetworkBanner({super.key, required this.child});

  @override
  State<NetworkBanner> createState() => _NetworkBannerState();
}

class _NetworkBannerState extends State<NetworkBanner> {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isOffline = false;
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _subscription = _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    _onConnectivityChanged(results);
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    if (!mounted) return;
    
    final offline = results.contains(ConnectivityResult.none);
    if (offline != _isOffline) {
      setState(() {
        _isOffline = offline;
        if (offline) {
          _isRetrying = true;
          // Auto retry indicator
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted && _isOffline) {
              setState(() => _isRetrying = false);
            }
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Offline banner
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: _isOffline ? 40 : 0,
          width: double.infinity,
          color: const Color(0xFFE02D3C),
          child: _isOffline
              ? Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        _isRetrying
                            ? 'Network issue detected. We are retrying...'
                            : 'You are offline',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_isRetrying) ...[
                        const SizedBox(width: 8),
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              : null,
        ),
        // Main content
        Expanded(child: widget.child),
      ],
    );
  }
}
