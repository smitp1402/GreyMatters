// lib/student/screens/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/data/supabase_db.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/services/profile_manager.dart';

/// Home dashboard — powered by Supabase computed views.
///
/// Queries `student_summary` for header greeting and
/// `student_topic_stats` for attention-prioritized topic cards.
/// Falls back to hardcoded placeholder content when no session data exists.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _topicStats = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final studentId = ProfileManager.instance.profileId;
    if (studentId == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final results = await Future.wait([
        SupabaseDb.instance.studentSummary(studentId),
        SupabaseDb.instance.studentTopicStats(studentId),
      ]);

      if (mounted) {
        setState(() {
          _summary = results[0] as Map<String, dynamic>?;
          _topicStats = (results[1] as List<Map<String, dynamic>>?) ?? [];
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
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 48),
              _buildTodaysFocus(context),
              const SizedBox(height: 48),
              _buildBottomSection(context),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final name = _summary?['name'] as String? ?? ProfileManager.instance.name ?? 'Scholar';
    final bestSubject = _summary?['best_subject_today'] as String?;
    final tagline = bestSubject != null
        ? 'YOUR FOCUS IS PEAKING IN ${bestSubject.toUpperCase()} TODAY.'
        : 'START A SESSION TO SEE YOUR FOCUS INSIGHTS.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome back, $name.',
          style: const TextStyle(
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
          tagline,
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
    // Sort by worst focus first (attention-priority)
    final needsWork = _topicStats.where((t) =>
        t['mastery_status'] == 'needs_work' || t['mastery_status'] == 'review_priority'
    ).toList()
      ..sort((a, b) => ((a['avg_focus'] as num?) ?? 0).compareTo((b['avg_focus'] as num?) ?? 0));

    // If no session data yet, show default cards
    final hasData = _topicStats.isNotEmpty;

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

        if (!hasData)
          _buildEmptyState()
        else
          _buildFocusGrid(context, needsWork),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(Icons.psychology, size: 48, color: AppColors.primary.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          const Text(
            'Start your first session to see focus insights',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontStyle: FontStyle.italic,
              fontSize: 18,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a topic from the library to begin learning',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 14,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFocusGrid(BuildContext context, List<Map<String, dynamic>> needsWork) {
    // Primary card: worst topic or first available
    final primary = needsWork.isNotEmpty ? needsWork.first : _topicStats.first;
    final secondary = needsWork.length > 1 ? needsWork[1]
        : _topicStats.length > 1 ? _topicStats[1] : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 700 && secondary != null) {
          return SizedBox(
            height: 380,
            child: Row(
              children: [
                Expanded(flex: 7, child: _TopicFocusCard(data: primary, isPrimary: true)),
                const SizedBox(width: 24),
                Expanded(flex: 5, child: _TopicFocusCard(data: secondary, isPrimary: false)),
              ],
            ),
          );
        }
        return Column(
          children: [
            SizedBox(height: 300, child: _TopicFocusCard(data: primary, isPrimary: true)),
            if (secondary != null) ...[
              const SizedBox(height: 16),
              SizedBox(height: 260, child: _TopicFocusCard(data: secondary, isPrimary: false)),
            ],
          ],
        );
      },
    );
  }

  Widget _buildBottomSection(BuildContext context) {
    // Strong topics: mastered or strong status
    final strongTopics = _topicStats.where((t) =>
        t['mastery_status'] == 'mastered' || t['mastery_status'] == 'strong'
    ).toList();

    // Continue: find topic with incomplete progress
    final continueTopics = _topicStats.where((t) {
      final completed = (t['last_sections_completed'] as int?) ?? 0;
      final total = (t['last_total_sections'] as int?) ?? 0;
      return total > 0 && completed < total;
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 700) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: _buildContinueSection(context, continueTopics)),
              const SizedBox(width: 48),
              Expanded(child: _buildStrongTopics(context, strongTopics)),
            ],
          );
        }
        return Column(
          children: [
            _buildContinueSection(context, continueTopics),
            const SizedBox(height: 32),
            _buildStrongTopics(context, strongTopics),
          ],
        );
      },
    );
  }

  Widget _buildContinueSection(BuildContext context, List<Map<String, dynamic>> topics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Continue where you left off',
          style: TextStyle(fontFamily: 'Georgia', fontSize: 22, color: AppColors.onSurface),
        ),
        const SizedBox(height: 20),
        if (topics.isEmpty)
          Text(
            'No sessions in progress',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontStyle: FontStyle.italic,
              fontSize: 14,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          )
        else
          ...topics.take(2).map((t) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ContinueCard(data: t),
          )),
      ],
    );
  }

  Widget _buildStrongTopics(BuildContext context, List<Map<String, dynamic>> topics) {
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
        if (topics.isEmpty)
          Text(
            'Complete more sessions to build mastery',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontStyle: FontStyle.italic,
              fontSize: 14,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          )
        else
          ...topics.take(3).map((t) {
            final consistency = ((t['consistency_score'] as num?)?.toDouble() ?? 0) * 100;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _StrongTopicItem(
                name: t['topic_name'] as String? ?? 'Unknown',
                status: t['mastery_status'] as String? ?? 'strong',
                percent: consistency.round(),
                label: 'Consistency',
              ),
            );
          }),
      ],
    );
  }
}

// ============================================================
// Topic Focus Card (data-driven)
// ============================================================

class _TopicFocusCard extends StatefulWidget {
  const _TopicFocusCard({required this.data, required this.isPrimary});
  final Map<String, dynamic> data;
  final bool isPrimary;

  @override
  State<_TopicFocusCard> createState() => _TopicFocusCardState();
}

class _TopicFocusCardState extends State<_TopicFocusCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final topicName = d['topic_name'] as String? ?? 'Unknown';
    final subject = d['subject'] as String? ?? '';
    final topicId = d['topic_id'] as String? ?? '';
    final avgFocus = ((d['avg_focus'] as num?)?.toDouble() ?? 0) * 100;
    final status = d['mastery_status'] as String? ?? 'not_started';

    final statusLabel = _statusLabel(status);
    final statusColor = _statusColor(status);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => context.go('/student/lesson/$subject/$topicId'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.surfaceContainerHigh : AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontFamily: 'Segoe UI',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: statusColor,
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${avgFocus.round()}%',
                          style: TextStyle(
                            fontFamily: 'Segoe UI',
                            fontSize: 36,
                            fontWeight: FontWeight.w300,
                            color: statusColor,
                          ),
                        ),
                        Text(
                          'AVG FOCUS',
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
                Text(
                  topicName,
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: widget.isPrimary ? 32 : 24,
                    color: AppColors.onSurface,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subject.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'Segoe UI',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _statusLabel(String status) => switch (status) {
    'mastered' => 'MASTERED',
    'strong' => 'STRONG',
    'review_priority' => 'REVIEW PRIORITY',
    'needs_work' => 'NEEDS WORK',
    _ => 'NOT STARTED',
  };

  Color _statusColor(String status) => switch (status) {
    'mastered' => AppColors.focused,
    'strong' => AppColors.focused,
    'review_priority' => AppColors.tertiary,
    'needs_work' => AppColors.error,
    _ => AppColors.outline,
  };
}

// ============================================================
// Continue Card
// ============================================================

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final topicName = data['topic_name'] as String? ?? 'Unknown';
    final subject = data['subject'] as String? ?? '';
    final topicId = data['topic_id'] as String? ?? '';
    final completed = (data['last_sections_completed'] as int?) ?? 0;
    final total = (data['last_total_sections'] as int?) ?? 1;
    final progress = total > 0 ? completed / total : 0.0;

    return Container(
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
          onTap: () => context.go('/student/lesson/$subject/$topicId'),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.science, size: 28, color: AppColors.primary.withValues(alpha: 0.4)),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(6),
                      child: const Icon(Icons.play_circle, size: 20, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          topicName,
                          style: const TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 18,
                            color: AppColors.onSurface,
                          ),
                        ),
                        Text(
                          '${(progress * 100).round()}% COMPLETED',
                          style: const TextStyle(
                            fontFamily: 'Segoe UI',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: SizedBox(
                        height: 4,
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: AppColors.surfaceContainerHighest,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      ),
                    ),
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
          color: _hovered ? AppColors.surfaceContainerHigh : AppColors.surfaceContainerLow,
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
                      fontFamily: 'Georgia', fontSize: 18, color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.check_circle, size: 14, color: AppColors.secondaryContainer),
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
                      fontFamily: 'Segoe UI', fontSize: 20, color: AppColors.secondary,
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
