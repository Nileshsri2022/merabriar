import 'package:flutter/material.dart';

import '../../config/app_theme.dart';

/// Type of error being shown to the user.
enum ErrorSeverity { warning, error, offline, empty }

/// A premium, animated error state widget for consistent error display.
class ErrorStateWidget extends StatelessWidget {
  final String title;
  final String message;
  final ErrorSeverity severity;
  final VoidCallback? onRetry;
  final IconData? icon;

  const ErrorStateWidget({
    super.key,
    required this.title,
    required this.message,
    this.severity = ErrorSeverity.error,
    this.onRetry,
    this.icon,
  });

  /// Factory for connection errors.
  factory ErrorStateWidget.connection({VoidCallback? onRetry}) {
    return ErrorStateWidget(
      title: 'Connection Error',
      message:
          'Unable to reach the server.\nPlease check your internet connection.',
      severity: ErrorSeverity.offline,
      icon: Icons.cloud_off_rounded,
      onRetry: onRetry,
    );
  }

  /// Factory for message load failure.
  factory ErrorStateWidget.loadFailed({
    required String what,
    VoidCallback? onRetry,
  }) {
    return ErrorStateWidget(
      title: 'Failed to load $what',
      message: 'Something went wrong.\nPlease try again.',
      severity: ErrorSeverity.error,
      icon: Icons.error_outline_rounded,
      onRetry: onRetry,
    );
  }

  /// Factory for empty states.
  factory ErrorStateWidget.empty({
    required String title,
    required String message,
    IconData? icon,
  }) {
    return ErrorStateWidget(
      title: title,
      message: message,
      severity: ErrorSeverity.empty,
      icon: icon ?? Icons.inbox_rounded,
    );
  }

  Color get _color {
    switch (severity) {
      case ErrorSeverity.warning:
        return AppTheme.warning;
      case ErrorSeverity.error:
        return AppTheme.danger;
      case ErrorSeverity.offline:
        return const Color(0xFF6C757D);
      case ErrorSeverity.empty:
        return AppTheme.brandGreen;
    }
  }

  IconData get _icon {
    return icon ??
        (severity == ErrorSeverity.warning
            ? Icons.warning_rounded
            : severity == ErrorSeverity.offline
                ? Icons.cloud_off_rounded
                : Icons.error_outline_rounded);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon circle
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 500),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: child,
                );
              },
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _icon,
                  size: 40,
                  color: _color.withOpacity(0.7),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Title
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 10 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            // Message
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: child,
                );
              },
              child: Text(
                message,
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // Retry button
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 16 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// An inline error banner for non-blocking errors (e.g., send failures).
class InlineErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onDismiss;
  final VoidCallback? onRetry;

  const InlineErrorBanner({
    super.key,
    required this.message,
    this.onDismiss,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.danger.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.danger.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppTheme.danger, fontSize: 13),
            ),
          ),
          if (onRetry != null)
            GestureDetector(
              onTap: onRetry,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.refresh, color: AppTheme.danger, size: 18),
              ),
            ),
          if (onDismiss != null)
            GestureDetector(
              onTap: onDismiss,
              child: const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.close, color: AppTheme.danger, size: 18),
              ),
            ),
        ],
      ),
    );
  }
}
