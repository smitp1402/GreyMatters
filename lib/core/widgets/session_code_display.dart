// lib/core/widgets/session_code_display.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Displays a 6-character session code in large spaced letters.
///
/// The teacher enters this code on their device to subscribe to the
/// student's live AttentionStream.
///
/// Tapping the code copies it to the clipboard.
class SessionCodeDisplay extends StatelessWidget {
  final String code;

  const SessionCodeDisplay({super.key, required this.code});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: code));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session code copied'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.3),
          ),
        ),
        child: Text(
          code.toUpperCase().split('').join('  '),
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            letterSpacing: 4,
            fontFamily: 'monospace',
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}
