// lib/student/screens/session_end_screen.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Session end summary screen — shows stats after a learning session.
///
/// Displays: topic name, duration, avg focus %, intervention count,
/// most effective format, and a color-coded focus timeline bar.
class SessionEndScreen extends StatefulWidget {
  final String topicName;
  final Duration duration;
  final double avgFocusScore;
  final int interventionCount;
  final String? mostEffectiveFormat;
  final int driftCount;
  final List<_FocusSegment> focusTimeline;

  const SessionEndScreen({
    super.key,
    required this.topicName,
    required this.duration,
    required this.avgFocusScore,
    required this.interventionCount,
    this.mostEffectiveFormat,
    required this.driftCount,
    required this.focusTimeline,
  });

  /// Create with default/demo data for testing.
  factory SessionEndScreen.demo() {
    final rng = Random();
    final segments = List.generate(60, (i) {
      if (i < 25) return _FocusSegment.focused;
      if (i < 35) return _FocusSegment.drifting;
      if (i < 40) return _FocusSegment.lost;
      if (i < 55) return _FocusSegment.focused;
      return rng.nextBool() ? _FocusSegment.focused : _FocusSegment.drifting;
    });

    return SessionEndScreen(
      topicName: 'The Periodic Table',
      duration: const Duration(minutes: 8, seconds: 42),
      avgFocusScore: 0.72,
      interventionCount: 3,
      mostEffectiveFormat: 'Flashcard',
      driftCount: 5,
      focusTimeline: segments,
    );
  }

  @override
  State<SessionEndScreen> createState() => _SessionEndScreenState();
}

class _SessionEndScreenState extends State<SessionEndScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeIn;

  @override
  void initState() {
    super.initState();
    _fadeIn = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _fadeIn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focusPercent = (widget.avgFocusScore * 100).round();
    final minutes = widget.duration.inMinutes;
    final seconds = widget.duration.inSeconds % 60;

    final Color focusColor;
    final String focusLabel;
    if (widget.avgFocusScore >= 0.8) {
      focusColor = AppColors.focused;
      focusLabel = 'EXCELLENT FOCUS';
    } else if (widget.avgFocusScore >= 0.6) {
      focusColor = AppColors.primary;
      focusLabel = 'GOOD SESSION';
    } else if (widget.avgFocusScore >= 0.4) {
      focusColor = AppColors.drifting;
      focusLabel = 'KEEP PRACTICING';
    } else {
      focusColor = AppColors.lost;
      focusLabel = 'NEEDS IMPROVEMENT';
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: AnimatedBuilder(
        animation: _fadeIn,
        builder: (_, child) => Opacity(opacity: _fadeIn.value, child: child),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                children: [
                  // Header icon
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: focusColor.withValues(alpha: 0.12),
                    ),
                    child: Icon(
                      widget.avgFocusScore >= 0.6
                          ? Icons.check_circle_outline
                          : Icons.refresh,
                      size: 40,
                      color: focusColor,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Status label
                  Text(
                    focusLabel,
                    style: TextStyle(
                      fontFamily: 'Consolas',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4.0,
                      color: focusColor,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Session Complete',
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontStyle: FontStyle.italic,
                      fontSize: 32,
                      color: AppColors.onSurface,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    widget.topicName,
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 16,
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Stats grid
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                      border: Border.all(
                        color: AppColors.outlineVariant.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Big focus score
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 80,
                              height: 80,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 80,
                                    height: 80,
                                    child: CircularProgressIndicator(
                                      value: widget.avgFocusScore,
                                      strokeWidth: 6,
                                      backgroundColor: AppColors.surfaceContainerLowest,
                                      valueColor: AlwaysStoppedAnimation(focusColor),
                                    ),
                                  ),
                                  Text(
                                    '$focusPercent%',
                                    style: TextStyle(
                                      fontFamily: 'Consolas',
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: focusColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 24),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'AVG FOCUS SCORE',
                                  style: TextStyle(
                                    fontFamily: 'Consolas',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 2.0,
                                    color: AppColors.outline,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$focusPercent% average across session',
                                  style: const TextStyle(
                                    fontFamily: 'Georgia',
                                    fontSize: 14,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),
                        Divider(color: AppColors.outlineVariant.withValues(alpha: 0.1)),
                        const SizedBox(height: 20),

                        // Stat rows
                        Row(
                          children: [
                            Expanded(
                              child: _StatItem(
                                icon: Icons.timer,
                                label: 'DURATION',
                                value: '${minutes}m ${seconds}s',
                              ),
                            ),
                            Expanded(
                              child: _StatItem(
                                icon: Icons.warning_amber,
                                label: 'DRIFT COUNT',
                                value: '${widget.driftCount}',
                                valueColor: widget.driftCount > 3 ? AppColors.drifting : null,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: _StatItem(
                                icon: Icons.psychology,
                                label: 'INTERVENTIONS',
                                value: '${widget.interventionCount}',
                              ),
                            ),
                            Expanded(
                              child: _StatItem(
                                icon: Icons.star,
                                label: 'BEST FORMAT',
                                value: widget.mostEffectiveFormat ?? 'None',
                                valueColor: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Focus timeline
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                      border: Border.all(
                        color: AppColors.outlineVariant.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'FOCUS TIMELINE',
                              style: TextStyle(
                                fontFamily: 'Consolas',
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 3.0,
                                color: AppColors.outline,
                              ),
                            ),
                            Row(
                              children: [
                                _legendDot(AppColors.focused, 'Focused'),
                                const SizedBox(width: 12),
                                _legendDot(AppColors.drifting, 'Drifting'),
                                const SizedBox(width: 12),
                                _legendDot(AppColors.lost, 'Lost'),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Timeline bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            height: 24,
                            child: Row(
                              children: widget.focusTimeline.map((seg) {
                                final Color color;
                                switch (seg) {
                                  case _FocusSegment.focused:
                                    color = AppColors.focused;
                                  case _FocusSegment.drifting:
                                    color = AppColors.drifting;
                                  case _FocusSegment.lost:
                                    color = AppColors.lost;
                                }
                                return Expanded(
                                  child: Container(color: color),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '0:00',
                              style: TextStyle(
                                fontFamily: 'Consolas',
                                fontSize: 10,
                                color: AppColors.outline.withValues(alpha: 0.5),
                              ),
                            ),
                            Text(
                              '${minutes}:${seconds.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontFamily: 'Consolas',
                                fontSize: 10,
                                color: AppColors.outline.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Done button
                  SizedBox(
                    width: double.infinity,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryContainer],
                        ),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => context.go('/student'),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: Center(
                              child: Text(
                                'RETURN TO DASHBOARD',
                                style: TextStyle(
                                  fontFamily: 'Segoe UI',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  letterSpacing: 3.0,
                                  color: AppColors.onPrimary,
                                ),
                              ),
                            ),
                          ),
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

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Consolas',
            fontSize: 9,
            color: AppColors.outline.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

enum _FocusSegment { focused, drifting, lost }

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Consolas',
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
                color: AppColors.outline.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Segoe UI',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppColors.onSurface,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
