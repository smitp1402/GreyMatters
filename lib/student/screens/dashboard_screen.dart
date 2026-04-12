// lib/student/screens/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/data/database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../widgets/topic_card.dart';

/// Home dashboard — topics prioritized by attention performance.
///
/// Shows all topics sorted by worst focus score first. Cards display
/// topic name, subject, last session stats, and "Start Session" button.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch all sessions to compute topic priorities
    final sessionsAsync = ref.watch(allSessionsProvider);

    return sessionsAsync.when(
      data: (sessions) {
        final prioritizedTopics = _prioritizeTopics(sessions);

        if (prioritizedTopics.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: prioritizedTopics.length,
          itemBuilder: (context, index) {
            final topic = prioritizedTopics[index];
            return TopicCard(
              topic: topic,
              priority: index + 1,
              onStartSession: () => _startSession(context, topic),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('Error loading dashboard: $error'),
      ),
    );
  }

  List<TopicPriority> _prioritizeTopics(List<Session> sessions) {
    // Group sessions by topic and compute average focus
    final topicStats = <String, TopicStats>{};

    for (final session in sessions) {
      final key = '${session.subject}:${session.topic}';
      final existing = topicStats[key];

      if (existing != null) {
        // Update running average
        final newCount = existing.sessionCount + 1;
        final newAvgFocus = (existing.avgFocus * existing.sessionCount + session.avgFocusScore) / newCount;
        final newDriftCount = existing.totalDriftCount + session.interventionCount;

        topicStats[key] = TopicStats(
          subject: session.subject,
          topic: session.topic,
          avgFocus: newAvgFocus,
          sessionCount: newCount,
          totalDriftCount: newDriftCount,
          lastSessionAt: session.startedAt.isAfter(existing.lastSessionAt) ? session.startedAt : existing.lastSessionAt,
        );
      } else {
        topicStats[key] = TopicStats(
          subject: session.subject,
          topic: session.topic,
          avgFocus: session.avgFocusScore,
          sessionCount: 1,
          totalDriftCount: session.interventionCount,
          lastSessionAt: session.startedAt,
        );
      }
    }

    // Sort by worst focus score first, then by most recent
    final sorted = topicStats.values.toList()
      ..sort((a, b) {
        final focusCompare = a.avgFocus.compareTo(b.avgFocus);
        if (focusCompare != 0) return focusCompare;
        return b.lastSessionAt.compareTo(a.lastSessionAt);
      });

    return sorted.map((stats) => TopicPriority(
      subject: stats.subject,
      topic: stats.topic,
      avgFocus: stats.avgFocus,
      sessionCount: stats.sessionCount,
      totalDriftCount: stats.totalDriftCount,
    )).toList();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.school,
              size: 64,
              color: AppColors.primary.withOpacity(0.5),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Welcome to NeuroLearn!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Start your first learning session to see personalized topic recommendations.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startSession(BuildContext context, TopicPriority topic) {
    // TODO: Navigate to session start flow
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Starting session for ${topic.topic}')),
    );
  }
}

/// Topic statistics for prioritization.
class TopicStats {
  final String subject;
  final String topic;
  final double avgFocus;
  final int sessionCount;
  final int totalDriftCount;
  final DateTime lastSessionAt;

  const TopicStats({
    required this.subject,
    required this.topic,
    required this.avgFocus,
    required this.sessionCount,
    required this.totalDriftCount,
    required this.lastSessionAt,
  });
}

/// Prioritized topic data for display.
class TopicPriority {
  final String subject;
  final String topic;
  final double avgFocus;
  final int sessionCount;
  final int totalDriftCount;

  const TopicPriority({
    required this.subject,
    required this.topic,
    required this.avgFocus,
    required this.sessionCount,
    required this.totalDriftCount,
  });

  String get statusText {
    if (avgFocus >= 0.8) return 'Strong';
    if (avgFocus >= 0.6) return 'In Progress';
    return 'Needs Work';
  }

  Color get statusColor {
    if (avgFocus >= 0.8) return AppColors.focused;
    if (avgFocus >= 0.6) return AppColors.drifting;
    return AppColors.lost;
  }
}

/// Provider for all sessions from database.
final allSessionsProvider = StreamProvider<List<Session>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.sessionDao.watchAllSessions();
});

/// Provider for app database instance.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('Database provider not initialized');
});