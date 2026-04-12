// lib/core/widgets/error_state.dart

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Full-screen error / connection-lost state widget.
///
/// Shows an icon, a headline message, an optional detail string, and a
/// retry button. Used when the Crown connection drops, the WebSocket
/// disconnects, or any unrecoverable error is encountered.
class ErrorState extends StatelessWidget {
  final String message;
  final String? detail;
  final VoidCallback? onRetry;
  final IconData icon;

  const ErrorState({
    super.key,
    required this.message,
    this.detail,
    this.onRetry,
    this.icon = Icons.error_outline,
  });

  /// Convenience constructor for Crown connection lost.
  const ErrorState.connectionLost({super.key, this.onRetry})
      : message = 'Connection lost',
        detail = 'Check that the Neurosity Crown is powered on and on the same WiFi network.',
        icon = Icons.bluetooth_disabled;

  /// Convenience constructor for WebSocket disconnect.
  const ErrorState.daemonDisconnected({super.key, this.onRetry})
      : message = 'EEG daemon disconnected',
        detail = 'The Python daemon is not running. Reconnecting automatically...',
        icon = Icons.cable;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppColors.error.withOpacity(0.7)),
            const SizedBox(height: AppSpacing.lg),
            Text(
              message,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
            if (detail != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                detail!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
