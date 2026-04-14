// lib/core/widgets/focus_gauge.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/attention_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Circular gauge that displays the current [focusScore] (0.0–1.0).
///
/// Used in both the student HUD and the teacher monitor. The arc colour
/// changes based on [AttentionLevel]: green (focused), amber (drifting),
/// red (lost).
class FocusGauge extends StatelessWidget {
  final double focusScore;
  final AttentionLevel level;
  final double size;

  const FocusGauge({
    super.key,
    required this.focusScore,
    required this.level,
    this.size = 80,
  });

  Color get _color => switch (level) {
        AttentionLevel.focused => AppColors.focused,
        AttentionLevel.drifting => AppColors.drifting,
        AttentionLevel.lost => AppColors.lost,
      };

  @override
  Widget build(BuildContext context) {
    final percentage = (focusScore * 100).round();
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GaugePainter(
          progress: focusScore.clamp(0.0, 1.0),
          color: _color,
        ),
        child: Center(
          child: Text(
            '$percentage%',
            style: TextStyle(
              fontSize: size * 0.22,
              fontWeight: FontWeight.bold,
              color: _color,
            ),
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double progress;
  final Color color;

  _GaugePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - AppSpacing.xs;
    const startAngle = -math.pi / 2; // 12 o'clock
    final sweepAngle = 2 * math.pi * progress;

    // Background track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      2 * math.pi,
      false,
      Paint()
        ..color = color.withOpacity(0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );

    // Progress arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.progress != progress || old.color != color;
}
