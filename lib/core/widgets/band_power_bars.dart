// lib/core/widgets/band_power_bars.dart

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Horizontal bar chart showing the four EEG band powers: θ α β γ.
///
/// Each value should be normalised 0.0–1.0. Used in the student focus HUD
/// and the teacher live monitor.
class BandPowerBars extends StatelessWidget {
  final double theta;
  final double alpha;
  final double beta;
  final double gamma;
  final double barHeight;

  const BandPowerBars({
    super.key,
    required this.theta,
    required this.alpha,
    required this.beta,
    required this.gamma,
    this.barHeight = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Bar(label: 'θ', value: theta, color: AppColors.theta, height: barHeight),
        const SizedBox(width: AppSpacing.sm),
        _Bar(label: 'α', value: alpha, color: AppColors.alpha, height: barHeight),
        const SizedBox(width: AppSpacing.sm),
        _Bar(label: 'β', value: beta, color: AppColors.beta, height: barHeight),
        const SizedBox(width: AppSpacing.sm),
        _Bar(label: 'γ', value: gamma, color: AppColors.gamma, height: barHeight),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final double height;

  const _Bar({
    required this.label,
    required this.value,
    required this.color,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              minHeight: height,
              backgroundColor: color.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}
