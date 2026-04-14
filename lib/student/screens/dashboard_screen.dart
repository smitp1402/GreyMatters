// lib/student/screens/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Home dashboard — "Welcome back, Scholar" with attention-first topic cards.
///
/// Matches the Stitch student_dashboard_home_tab design:
/// - Hero greeting
/// - Today's Focus bento grid (large + secondary card)
/// - Continue where you left off
/// - Strong topics
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(context),
            const SizedBox(height: 48),

            // Today's Focus
            _buildTodaysFocus(context),
            const SizedBox(height: 48),

            // Continue + Strong Topics
            _buildBottomSection(context),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Welcome back, Scholar.',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontStyle: FontStyle.italic,
            fontSize: 44,
            fontWeight: FontWeight.w400,
            color: AppColors.onSurface,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'YOUR FOCUS IS PEAKING IN BIOLOGY AND CHEMISTRY TODAY.',
          style: TextStyle(
            fontFamily: 'Segoe UI',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.5,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildTodaysFocus(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Today\'s Focus',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 24,
                color: AppColors.onSurface,
              ),
            ),
            Text(
              'ATTENTION-FIRST VIEW',
              style: TextStyle(
                fontFamily: 'Segoe UI',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
                color: AppColors.tertiary,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.tertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Bento grid
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 700) {
              return SizedBox(
                height: 380,
                child: Row(
                  children: [
                    // Large feature card (7/12)
                    Expanded(
                      flex: 7,
                      child: _FocusCard(
                        topic: 'The Periodic Table',
                        description: 'Elemental trends and electronegativity.',
                        focusPercent: 54,
                        statusLabel: 'NEEDS WORK',
                        statusColor: AppColors.error,
                        metricLabel: 'AVG FOCUS',
                        metricColor: AppColors.primary,
                        topicId: 'periodic_table',
                        hasResumeButton: true,
                        lastSession: '2h ago',
                        gradientColors: [
                          AppColors.primary.withValues(alpha: 0.1),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Secondary card (5/12)
                    Expanded(
                      flex: 5,
                      child: _FocusCard(
                        topic: 'Chemical Bonding',
                        description: 'Electron sharing and molecular orbital overlaps in organic structures.',
                        focusPercent: 58,
                        statusLabel: 'REVIEW PRIORITY',
                        statusColor: AppColors.tertiary,
                        metricLabel: 'RETENTION',
                        metricColor: AppColors.tertiary,
                        topicId: 'chemical_bonding',
                        hasProgressBar: true,
                      ),
                    ),
                  ],
                ),
              );
            }
            // Mobile: stacked
            return Column(
              children: [
                SizedBox(
                  height: 300,
                  child: _FocusCard(
                    topic: 'The Periodic Table',
                    description: 'Elemental trends and electronegativity.',
                    focusPercent: 54,
                    statusLabel: 'NEEDS WORK',
                    statusColor: AppColors.error,
                    metricLabel: 'AVG FOCUS',
                    metricColor: AppColors.primary,
                    topicId: 'periodic_table',
                    hasResumeButton: true,
                    lastSession: '2h ago',
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 260,
                  child: _FocusCard(
                    topic: 'Chemical Bonding',
                    description: 'Electron sharing and molecular orbital overlaps.',
                    focusPercent: 58,
                    statusLabel: 'REVIEW PRIORITY',
                    statusColor: AppColors.tertiary,
                    metricLabel: 'RETENTION',
                    metricColor: AppColors.tertiary,
                    topicId: 'chemical_bonding',
                    hasProgressBar: true,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildBottomSection(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 700) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: _buildContinueSection(context)),
              const SizedBox(width: 48),
              Expanded(child: _buildStrongTopics(context)),
            ],
          );
        }
        return Column(
          children: [
            _buildContinueSection(context),
            const SizedBox(height: 32),
            _buildStrongTopics(context),
          ],
        );
      },
    );
  }

  Widget _buildContinueSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Continue where you left off',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 22,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 20),
        // Continue card
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.2)),
          ),
          padding: const EdgeInsets.all(4),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
            padding: const EdgeInsets.all(20),
            child: InkWell(
              onTap: () => context.go('/student/lesson/periodic_table'),
              child: Row(
                children: [
                  // Thumbnail
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(Icons.science, size: 36,
                            color: AppColors.primary.withValues(alpha: 0.4)),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(8),
                          child: const Icon(Icons.play_circle,
                              size: 28, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'The Periodic Table',
                              style: TextStyle(
                                fontFamily: 'Georgia',
                                fontSize: 20,
                                color: AppColors.onSurface,
                              ),
                            ),
                            Text(
                              '25% COMPLETED',
                              style: TextStyle(
                                fontFamily: 'Segoe UI',
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Element groups, periodic trends, and reading the table.',
                          style: TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 14,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.timer, size: 14,
                                color: AppColors.outline.withValues(alpha: 0.6)),
                            const SizedBox(width: 4),
                            Text(
                              '8 MINS REMAINING',
                              style: TextStyle(
                                fontFamily: 'Segoe UI',
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                                color: AppColors.outline,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStrongTopics(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Strong topics',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 22,
            color: AppColors.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 20),
        _StrongTopicItem(
          name: 'Cell Structure',
          status: 'Mastered',
          percent: 94,
          label: 'Consistency',
        ),
        const SizedBox(height: 12),
        _StrongTopicItem(
          name: 'DNA Replication',
          status: 'Mastered',
          percent: 89,
          label: 'Consistency',
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: Text(
              'VIEW MASTERY MAP',
              style: TextStyle(
                fontFamily: 'Segoe UI',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// Focus Card (bento grid item)
// ============================================================

class _FocusCard extends StatefulWidget {
  const _FocusCard({
    required this.topic,
    required this.description,
    required this.focusPercent,
    required this.statusLabel,
    required this.statusColor,
    required this.metricLabel,
    required this.metricColor,
    required this.topicId,
    this.hasResumeButton = false,
    this.hasProgressBar = false,
    this.lastSession,
    this.gradientColors,
  });

  final String topic, description, statusLabel, metricLabel, topicId;
  final int focusPercent;
  final Color statusColor, metricColor;
  final bool hasResumeButton, hasProgressBar;
  final String? lastSession;
  final List<Color>? gradientColors;

  @override
  State<_FocusCard> createState() => _FocusCardState();
}

class _FocusCardState extends State<_FocusCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => context.go('/student/lesson/${widget.topicId}'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.surfaceContainerHigh
                : AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          ),
          child: Stack(
            children: [
              // Gradient overlay
              if (widget.gradientColors != null)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: widget.gradientColors!,
                      ),
                    ),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: status + metric
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: widget.statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            widget.statusLabel,
                            style: TextStyle(
                              fontFamily: 'Segoe UI',
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                              color: widget.statusColor,
                            ),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${widget.focusPercent}%',
                              style: TextStyle(
                                fontFamily: 'Segoe UI',
                                fontSize: 36,
                                fontWeight: FontWeight.w300,
                                color: widget.metricColor,
                              ),
                            ),
                            Text(
                              widget.metricLabel,
                              style: TextStyle(
                                fontFamily: 'Segoe UI',
                                fontSize: 10,
                                letterSpacing: 1.0,
                                color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Topic title + description
                    Text(
                      widget.topic,
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 32,
                        color: AppColors.onSurface,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.description,
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontStyle: FontStyle.italic,
                        fontSize: 16,
                        color: AppColors.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),

                    // Resume button
                    if (widget.hasResumeButton) ...[
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () =>
                                context.go('/student/lesson/${widget.topicId}'),
                            icon: const Icon(Icons.play_arrow, size: 16),
                            label: const Text('Resume Session'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.onPrimary,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                            ),
                          ),
                          if (widget.lastSession != null) ...[
                            const SizedBox(width: 16),
                            Text(
                              'Last session: ${widget.lastSession}',
                              style: const TextStyle(
                                fontFamily: 'Segoe UI',
                                fontSize: 12,
                                color: AppColors.outline,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],

                    // Progress bar
                    if (widget.hasProgressBar) ...[
                      const SizedBox(height: 24),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          height: 6,
                          child: LinearProgressIndicator(
                            value: widget.focusPercent / 100,
                            backgroundColor: AppColors.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation<Color>(widget.metricColor),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Strong Topic Item
// ============================================================

class _StrongTopicItem extends StatefulWidget {
  const _StrongTopicItem({
    required this.name,
    required this.status,
    required this.percent,
    required this.label,
  });
  final String name, status, label;
  final int percent;

  @override
  State<_StrongTopicItem> createState() => _StrongTopicItemState();
}

class _StrongTopicItemState extends State<_StrongTopicItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _hovered
              ? AppColors.surfaceContainerHigh
              : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        ),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: _hovered ? 1.0 : 0.4,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 18,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.check_circle,
                          size: 14, color: AppColors.secondaryContainer),
                      const SizedBox(width: 6),
                      Text(
                        widget.status.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'Segoe UI',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${widget.percent}%',
                    style: const TextStyle(
                      fontFamily: 'Segoe UI',
                      fontSize: 20,
                      color: AppColors.secondary,
                    ),
                  ),
                  Text(
                    widget.label.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'Segoe UI',
                      fontSize: 8,
                      letterSpacing: 1.0,
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
