import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

import '../../config/app_theme.dart';

/// Status of network connectivity.
enum ConnectivityStatus { online, offline, checking }

/// A mixin that provides connectivity monitoring to any StatefulWidget.
///
/// Widgets using this mixin can access [connectivityStatus] and override
/// [onConnectivityChanged] to react to connectivity changes.
mixin ConnectivityMixin<T extends StatefulWidget> on State<T> {
  ConnectivityStatus _connectivityStatus = ConnectivityStatus.checking;
  Timer? _connectivityTimer;

  ConnectivityStatus get connectivityStatus => _connectivityStatus;
  bool get isOffline => _connectivityStatus == ConnectivityStatus.offline;
  bool get isOnline => _connectivityStatus == ConnectivityStatus.online;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _connectivityTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _checkConnectivity(),
    );
  }

  @override
  void dispose() {
    _connectivityTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        _updateStatus(ConnectivityStatus.online);
      } else {
        _updateStatus(ConnectivityStatus.offline);
      }
    } catch (_) {
      _updateStatus(ConnectivityStatus.offline);
    }
  }

  void _updateStatus(ConnectivityStatus newStatus) {
    if (!mounted) return;
    if (_connectivityStatus != newStatus) {
      setState(() => _connectivityStatus = newStatus);
      onConnectivityChanged(newStatus);
    }
  }

  /// Override this to react to connectivity changes.
  void onConnectivityChanged(ConnectivityStatus status) {}

  /// Force a connectivity re-check.
  Future<void> recheckConnectivity() => _checkConnectivity();
}

/// Animated offline banner that slides in/out.
class ConnectivityBanner extends StatelessWidget {
  final bool isOffline;
  final VoidCallback? onRetry;

  const ConnectivityBanner({
    super.key,
    required this.isOffline,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      offset: isOffline ? Offset.zero : const Offset(0, -1),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: isOffline ? 1.0 : 0.0,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.danger.withOpacity(0.95),
                  const Color(0xFFD63384).withOpacity(0.95),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.danger.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  const Icon(Icons.wifi_off_rounded,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'No internet connection',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (onRetry != null)
                    GestureDetector(
                      onTap: onRetry,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Retry',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A wrapper that adds an offline banner to any screen.
class ConnectivityWrapper extends StatefulWidget {
  final Widget child;

  const ConnectivityWrapper({super.key, required this.child});

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper>
    with ConnectivityMixin {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ConnectivityBanner(
          isOffline: isOffline,
          onRetry: recheckConnectivity,
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}
