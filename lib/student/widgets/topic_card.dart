// lib/student/widgets/topic_card.dart

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../screens/dashboard_screen.dart';

/// Card displaying a topic with attention stats and start button.
///
/// Shows topic name, subject, focus score, drift count, status badge,
/// and "Start Session" button. Used in both dashboard and library.
class TopicCard extends StatelessWidget {
  final TopicPriority topic;
  final int? priority;
  final VoidCallback onStartSession;

  const TopicCard({
    super.key,
    required this.topic,
    this.priority,
    required this.onStartSession,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with priority and subject
            Row(
              children: [
                if (priority != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Text(
                      '#$priority',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Text(
                  topic.subject.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: topic.statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Text(
                    topic.statusText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: topic.statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Topic title
            Text(
              topic.topic,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Stats row
            Row(
              children: [
                _StatChip(
                  icon: Icons.visibility,
                  label: '${(topic.avgFocus * 100).round()}% focus',
                  color: topic.statusColor,
                ),
                const SizedBox(width: AppSpacing.md),
                _StatChip(
                  icon: Icons.warning,
                  label: '${topic.totalDriftCount} drifts',
                  color: AppColors.drifting,
                ),
                const SizedBox(width: AppSpacing.md),
                _StatChip(
                  icon: Icons.play_circle,
                  label: '${topic.sessionCount} sessions',
                  color: AppColors.outline,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Start button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onStartSession,
                child: const Text('Start Session'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: AppSpacing.xxs),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}