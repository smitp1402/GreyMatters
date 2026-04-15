// lib/teacher/screens/student_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/data/supabase_db.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Teacher view of a specific student's performance.
///
/// Shows: profile info, per-topic stats (from student_topic_stats view),
/// session history, intervention efficacy, and overall summary.
class StudentDetailScreen extends StatefulWidget {
  final String studentId;

  const StudentDetailScreen({super.key, required this.studentId});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _topicStats = [];
  List<Map<String, dynamic>> _sessions = [];
  List<Map<String, dynamic>> _efficacy = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        SupabaseDb.instance.profileById(widget.studentId),
        SupabaseDb.instance.studentSummary(widget.studentId),
        SupabaseDb.instance.studentTopicStats(widget.studentId),
        SupabaseDb.instance.sessionsForStudent(widget.studentId),
        SupabaseDb.instance.interventionEfficacy(widget.studentId),
      ]);

      if (mounted) {
        setState(() {
          _profile = results[0] as Map<String, dynamic>?;
          _summary = results[1] as Map<String, dynamic>?;
          _topicStats = (results[2] as List<Map<String, dynamic>>?) ?? [];
          _sessions = (results[3] as List<Map<String, dynamic>>?) ?? [];
          _efficacy = (results[4] as List<Map<String, dynamic>>?) ?? [];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: _buildAppBar('Loading...'),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final name = _profile?['name'] as String? ?? 'Unknown Student';

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: _buildAppBar(name),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProfileHeader(name),
                const SizedBox(height: 32),
                _buildOverviewCards(),
                const SizedBox(height: 32),
                _buildTopicPerformance(),
                const SizedBox(height: 32),
                _buildInterventionEfficacy(),
                const SizedBox(height: 32),
                _buildSessionHistory(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(String title) {
    return AppBar(
      backgroundColor: AppColors.surface,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppColors.outline),
        onPressed: () => context.go('/teacher'),
      ),
      title: Text(title,
          style: const TextStyle(
            fontFamily: 'Segoe UI', fontWeight: FontWeight.w700,
            fontSize: 18, color: AppColors.primary,
          )),
    );
  }

  Widget _buildProfileHeader(String name) {
    final gradeLevel = _profile?['grade_level'] as String?;
    final subjects = List<String>.from(_profile?['subjects'] ?? []);
    final totalSessions = (_summary?['total_sessions'] as num?)?.toInt() ?? 0;
    final avgFocus = (_summary?['overall_avg_focus'] as num?)?.toDouble();

    return Row(
      children: [
        // Avatar
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withValues(alpha: 0.15),
          ),
          child: Center(
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                fontFamily: 'Segoe UI', fontSize: 32,
                fontWeight: FontWeight.w700, color: AppColors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(
                    fontFamily: 'Georgia', fontSize: 28, color: AppColors.onSurface,
                  )),
              const SizedBox(height: 4),
              Text(
                [
                  if (gradeLevel != null) gradeLevel,
                  if (subjects.isNotEmpty) subjects.join(', '),
                  '$totalSessions sessions',
                  if (avgFocus != null) 'Avg focus: ${(avgFocus * 100).round()}%',
                ].join(' · '),
                style: TextStyle(
                  fontFamily: 'Segoe UI', fontSize: 13,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewCards() {
    final totalSessions = (_summary?['total_sessions'] as num?)?.toInt() ?? 0;
    final avgFocus = (_summary?['overall_avg_focus'] as num?)?.toDouble() ?? 0;
    final weakest = _summary?['weakest_topic'] as String?;
    final bestToday = _summary?['best_subject_today'] as String?;

    return Row(
      children: [
        Expanded(child: _StatCard(
          label: 'TOTAL SESSIONS', value: '$totalSessions',
          color: AppColors.primary,
        )),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(
          label: 'AVG FOCUS', value: '${(avgFocus * 100).round()}%',
          color: avgFocus >= 0.7 ? AppColors.focused : avgFocus >= 0.5 ? AppColors.drifting : AppColors.lost,
        )),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(
          label: 'WEAKEST TOPIC', value: weakest ?? 'N/A',
          color: AppColors.lost,
        )),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(
          label: 'BEST TODAY', value: bestToday ?? 'N/A',
          color: AppColors.focused,
        )),
      ],
    );
  }

  Widget _buildTopicPerformance() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Topic Performance',
            style: TextStyle(fontFamily: 'Georgia', fontSize: 22, color: AppColors.onSurface)),
        const SizedBox(height: 16),
        if (_topicStats.isEmpty)
          Text('No completed sessions yet',
              style: TextStyle(fontFamily: 'Georgia', fontSize: 14,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.5)))
        else
          ..._topicStats.map((t) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _TopicRow(data: t),
          )),
      ],
    );
  }

  Widget _buildInterventionEfficacy() {
    if (_efficacy.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Best Intervention Formats',
            style: TextStyle(fontFamily: 'Georgia', fontSize: 22, color: AppColors.onSurface)),
        const SizedBox(height: 16),
        ..._efficacy.map((e) {
          final format = e['format'] as String? ?? '?';
          final recovery = ((e['recovery_rate'] as num?)?.toDouble() ?? 0) * 100;
          final timesUsed = (e['times_used'] as num?)?.toInt() ?? 0;
          final topicId = e['topic_id'] as String? ?? '';

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Row(
                children: [
                  Icon(_formatIcon(format), size: 20, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${format.toUpperCase()} — $topicId',
                      style: const TextStyle(
                        fontFamily: 'Segoe UI', fontSize: 13,
                        fontWeight: FontWeight.w600, color: AppColors.onSurface,
                      ),
                    ),
                  ),
                  Text('${recovery.round()}% recovery',
                      style: TextStyle(
                        fontFamily: 'Consolas', fontSize: 12,
                        color: recovery >= 70 ? AppColors.focused : AppColors.drifting,
                      )),
                  const SizedBox(width: 16),
                  Text('$timesUsed uses',
                      style: const TextStyle(
                        fontFamily: 'Consolas', fontSize: 11, color: AppColors.outline,
                      )),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSessionHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Session History (${_sessions.length})',
            style: const TextStyle(fontFamily: 'Georgia', fontSize: 22, color: AppColors.onSurface)),
        const SizedBox(height: 16),
        if (_sessions.isEmpty)
          Text('No sessions recorded',
              style: TextStyle(fontFamily: 'Georgia', fontSize: 14,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.5)))
        else
          ..._sessions.take(20).map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _SessionRow(session: s),
          )),
      ],
    );
  }

  IconData _formatIcon(String format) => switch (format) {
    'flashcard' => Icons.style,
    'simulation' => Icons.science,
    'gesture' => Icons.gesture,
    'voice' => Icons.mic,
    'video' => Icons.play_circle,
    'curiosity_bomb' => Icons.lightbulb,
    _ => Icons.help_outline,
  };
}

// ============================================================
// Stat Card
// ============================================================

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                fontFamily: 'Consolas', fontSize: 9,
                fontWeight: FontWeight.w700, letterSpacing: 2.0,
                color: AppColors.outline,
              )),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                fontFamily: 'Segoe UI', fontSize: 22,
                fontWeight: FontWeight.w700, color: color,
              ),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ============================================================
// Topic Row
// ============================================================

class _TopicRow extends StatelessWidget {
  const _TopicRow({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final topicName = data['topic_name'] as String? ?? 'Unknown';
    final subject = data['subject'] as String? ?? '';
    final avgFocus = ((data['avg_focus'] as num?)?.toDouble() ?? 0) * 100;
    final totalSessions = (data['total_sessions'] as num?)?.toInt() ?? 0;
    final totalDrifts = (data['total_drifts'] as num?)?.toInt() ?? 0;
    final status = data['mastery_status'] as String? ?? 'not_started';
    final statusColor = _statusColor(status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          // Status dot
          Container(
            width: 10, height: 10,
            decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor),
          ),
          const SizedBox(width: 14),
          // Topic info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(topicName,
                    style: const TextStyle(
                      fontFamily: 'Segoe UI', fontSize: 15,
                      fontWeight: FontWeight.w600, color: AppColors.onSurface,
                    )),
                const SizedBox(height: 2),
                Text('$subject · $totalSessions sessions · $totalDrifts drifts',
                    style: TextStyle(
                      fontFamily: 'Segoe UI', fontSize: 11,
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                    )),
              ],
            ),
          ),
          // Focus score
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${avgFocus.round()}%',
                  style: TextStyle(
                    fontFamily: 'Consolas', fontSize: 20,
                    fontWeight: FontWeight.w700, color: statusColor,
                  )),
              Text(status.toUpperCase().replaceAll('_', ' '),
                  style: TextStyle(
                    fontFamily: 'Consolas', fontSize: 9,
                    fontWeight: FontWeight.w700, letterSpacing: 1.0,
                    color: statusColor,
                  )),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) => switch (status) {
    'mastered' => AppColors.focused,
    'strong' => AppColors.focused,
    'review_priority' => AppColors.drifting,
    'needs_work' => AppColors.lost,
    _ => AppColors.outline,
  };
}

// ============================================================
// Session Row
// ============================================================

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session});
  final Map<String, dynamic> session;

  @override
  Widget build(BuildContext context) {
    final topicName = session['topic_name'] as String? ?? 'Unknown';
    final avgFocus = ((session['avg_focus_score'] as num?)?.toDouble() ?? 0) * 100;
    final driftCount = (session['drift_count'] as num?)?.toInt() ?? 0;
    final interventionCount = (session['intervention_count'] as num?)?.toInt() ?? 0;
    final durationSec = (session['duration_sec'] as num?)?.toInt() ?? 0;
    final startedAt = session['started_at'] as String?;
    final status = session['status'] as String? ?? 'unknown';

    final durationMin = durationSec > 0 ? '${(durationSec / 60).ceil()}m' : '—';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        children: [
          // Status indicator
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: status == 'active' ? AppColors.focused
                  : status == 'completed' ? AppColors.primary
                  : AppColors.outline,
            ),
          ),
          const SizedBox(width: 12),
          // Topic
          Expanded(
            flex: 3,
            child: Text(topicName,
                style: const TextStyle(
                  fontFamily: 'Segoe UI', fontSize: 13,
                  fontWeight: FontWeight.w500, color: AppColors.onSurface,
                )),
          ),
          // Focus
          SizedBox(
            width: 60,
            child: Text('${avgFocus.round()}%',
                style: TextStyle(
                  fontFamily: 'Consolas', fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: avgFocus >= 70 ? AppColors.focused
                      : avgFocus >= 50 ? AppColors.drifting : AppColors.lost,
                )),
          ),
          // Drifts
          SizedBox(
            width: 70,
            child: Text('$driftCount drifts',
                style: const TextStyle(
                  fontFamily: 'Consolas', fontSize: 11, color: AppColors.outline,
                )),
          ),
          // Interventions
          SizedBox(
            width: 50,
            child: Text('$interventionCount int.',
                style: const TextStyle(
                  fontFamily: 'Consolas', fontSize: 11, color: AppColors.outline,
                )),
          ),
          // Duration
          SizedBox(
            width: 40,
            child: Text(durationMin,
                style: const TextStyle(
                  fontFamily: 'Consolas', fontSize: 11, color: AppColors.outline,
                )),
          ),
          // Date
          SizedBox(
            width: 80,
            child: Text(_formatDate(startedAt),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: 'Consolas', fontSize: 10,
                  color: AppColors.outline.withValues(alpha: 0.6),
                )),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}
