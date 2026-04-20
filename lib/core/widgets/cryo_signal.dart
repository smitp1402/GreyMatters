// lib/core/widgets/cryo_signal.dart
//
// Signature accents for the "Cryo-Lattice" theme. Thin cyan lines and
// glow halos that identify a surface as primary / focused / live.

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Horizontal "signal line" — the thin cyan trace that sits above or
/// below a primary element to suggest transmission / data feed.
///
/// Usage:
///   const CryoSignalLine()                              // default 64-px line
///   CryoSignalLine(width: 120, color: AppColors.focused)
class CryoSignalLine extends StatelessWidget {
  final double width;
  final double thickness;
  final Color color;
  final double glowBlur;

  const CryoSignalLine({
    super.key,
    this.width = 64,
    this.thickness = 1.5,
    this.color = AppColors.tertiary,
    this.glowBlur = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: thickness,
      decoration: BoxDecoration(
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.6),
            blurRadius: glowBlur,
          ),
        ],
      ),
    );
  }
}

/// A label chip designed as a thin-bordered capsule — reads like a status
/// indicator on an instrument panel. No fill by default; add `filled: true`
/// for high-emphasis moments.
class CryoStatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;
  final IconData? icon;

  const CryoStatusPill({
    super.key,
    required this.label,
    this.color = AppColors.tertiary,
    this.filled = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.18) : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'Consolas',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.5,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// A full-bleed "instrument panel" background: obsidian gradient with a
/// subtle horizontal scanline texture. Place behind any Scaffold body for
/// ambient depth.
class CryoBackdrop extends StatelessWidget {
  final Widget child;
  final double scanlineOpacity;

  const CryoBackdrop({
    super.key,
    required this.child,
    this.scanlineOpacity = 0.04,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.gradientTop,
            AppColors.gradientMid,
            AppColors.gradientBottom,
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Scanlines — extremely subtle horizontal ridges for instrument feel.
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _ScanlinePainter(opacity: scanlineOpacity),
              ),
            ),
          ),
          // Ambient cyan edge-glow at upper left and lower right.
          Positioned(
            top: -120,
            left: -120,
            child: Container(
              width: 360,
              height: 360,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppColors.primaryGlow, Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -140,
            right: -140,
            child: Container(
              width: 420,
              height: 420,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppColors.accentGlow, Colors.transparent],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _ScanlinePainter extends CustomPainter {
  final double opacity;
  const _ScanlinePainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: opacity)
      ..strokeWidth = 0.5;
    const step = 3.0;
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScanlinePainter old) => old.opacity != opacity;
}

/// Wrap a child in a container with a subtle cyan halo for primary
/// attention surfaces. Use sparingly — only on the one thing per view
/// that deserves to pulse.
class CryoGlowPanel extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final Color color;
  final double intensity;

  const CryoGlowPanel({
    super.key,
    required this.child,
    this.borderRadius = 12,
    this.color = AppColors.tertiary,
    this.intensity = 0.3,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: intensity),
            blurRadius: 24,
            spreadRadius: -2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: child,
      ),
    );
  }
}
