// lib/teacher/screens/teacher_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/data/supabase_db.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Teacher dashboard — list of all students with performance overview.
///
/// Shows all student profiles from Supabase, their session count,
/// average focus, and status. Tapping a student navigates to their
/// detail view. Active sessions show a "LIVE" badge.
class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _activeSessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      // Get all student profiles
      final studentsRaw = await SupabaseDb.instance.allStudentProfiles();

      // Get active sessions to show LIVE badges
      final sessionsRaw = await SupabaseDb.instance.allActiveSessions();

      if (mounted) {
        setState(() {
          _students = studentsRaw;
          _activeSessions = sessionsRaw;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _activeSessionCode(String studentId) {
    for (final s in _activeSessions) {
      if (s['student_id'] == studentId) return s['id'] as String?;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      child: _students.isEmpty ? _buildEmptyState() : _buildStudentList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 64,
                color: AppColors.outline.withValues(alpha: 0.4)),
            const SizedBox(height: 20),
            const Text(
              'NO STUDENTS YET',
              style: TextStyle(
                fontFamily: 'Consolas',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 3.0,
                color: AppColors.outline,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Students will appear here once they\ncreate a profile and start sessions.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Georgia',
                fontStyle: FontStyle.italic,
                fontSize: 15,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            _buildJoinCodeSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildJoinCodeSection() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Text(
            'QUICK JOIN',
            style: TextStyle(
              fontFamily: 'Consolas',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 3.0,
              color: AppColors.outline,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Have a session code? Enter it to monitor live.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 13,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          _JoinCodeInput(onJoin: (code) => context.go('/teacher/monitor/$code')),
        ],
      ),
    );
  }

  Widget _buildStudentList() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Students',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 28,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_students.length} student${_students.length == 1 ? '' : 's'} '
                      '· ${_activeSessions.length} active now',
                      style: TextStyle(
                        fontFamily: 'Segoe UI',
                        fontSize: 13,
                        color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
                // Quick join button
                OutlinedButton.icon(
                  onPressed: () => _showJoinDialog(context),
                  icon: const Icon(Icons.add_link, size: 16),
                  label: const Text('JOIN CODE'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Student cards
            ..._students.map((student) {
              final studentId = student['id'] as String;
              final activeCode = _activeSessionCode(studentId);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _StudentCard(
                  student: student,
                  activeSessionCode: activeCode,
                  onTap: () => context.go('/teacher/student/$studentId'),
                  onLiveMonitor: activeCode != null
                      ? () => context.go('/teacher/monitor/$activeCode')
                      : null,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showJoinDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        title: const Text('Join Live Session',
            style: TextStyle(fontFamily: 'Georgia', color: AppColors.onSurface)),
        content: SizedBox(
          width: 300,
          child: _JoinCodeInput(onJoin: (code) {
            Navigator.of(ctx).pop();
            context.go('/teacher/monitor/$code');
          }),
        ),
      ),
    );
  }
}

// ============================================================
// Student Card
// ============================================================

class _StudentCard extends StatefulWidget {
  const _StudentCard({
    required this.student,
    required this.onTap,
    this.activeSessionCode,
    this.onLiveMonitor,
  });

  final Map<String, dynamic> student;
  final String? activeSessionCode;
  final VoidCallback onTap;
  final VoidCallback? onLiveMonitor;

  @override
  State<_StudentCard> createState() => _StudentCardState();
}

class _StudentCardState extends State<_StudentCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final name = widget.student['name'] as String? ?? 'Unknown';
    final gradeLevel = widget.student['grade_level'] as String?;
    final createdAt = widget.student['created_at'] as String?;
    final isActive = widget.activeSessionCode != null;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.surfaceContainerHigh
                : AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(
              color: isActive
                  ? AppColors.focused.withValues(alpha: 0.4)
                  : AppColors.outlineVariant.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive
                      ? AppColors.focused.withValues(alpha: 0.15)
                      : AppColors.surfaceContainerHighest,
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontFamily: 'Segoe UI',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isActive ? AppColors.focused : AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Name + info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontFamily: 'Segoe UI',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurface,
                          ),
                        ),
                        if (isActive) ...[
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.focused.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'LIVE',
                              style: TextStyle(
                                fontFamily: 'Consolas',
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2.0,
                                color: AppColors.focused,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (gradeLevel != null) gradeLevel,
                        if (createdAt != null)
                          'Joined ${_formatDate(createdAt)}',
                      ].join(' · '),
                      style: TextStyle(
                        fontFamily: 'Segoe UI',
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),

              // Live monitor button
              if (isActive)
                TextButton.icon(
                  onPressed: widget.onLiveMonitor,
                  icon: const Icon(Icons.monitor_heart, size: 16, color: AppColors.focused),
                  label: const Text(
                    'MONITOR',
                    style: TextStyle(
                      fontFamily: 'Consolas',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: AppColors.focused,
                    ),
                  ),
                ),

              // Arrow
              Icon(Icons.chevron_right, size: 20,
                  color: AppColors.outline.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inDays == 0) return 'today';
      if (diff.inDays == 1) return 'yesterday';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.month}/${dt.day}/${dt.year}';
    } catch (_) {
      return '';
    }
  }
}

// ============================================================
// Join Code Input (reusable)
// ============================================================

class _JoinCodeInput extends StatefulWidget {
  const _JoinCodeInput({required this.onJoin});
  final void Function(String code) onJoin;

  @override
  State<_JoinCodeInput> createState() => _JoinCodeInputState();
}

class _JoinCodeInputState extends State<_JoinCodeInput> {
  final _controller = TextEditingController();
  String? _error;

  void _submit() {
    final code = _controller.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _error = 'Code must be 6 characters');
      return;
    }
    setState(() => _error = null);
    widget.onJoin(code);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            style: const TextStyle(
              fontFamily: 'Consolas',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 6.0,
              color: AppColors.primary,
            ),
            decoration: InputDecoration(
              hintText: 'ABC123',
              hintStyle: TextStyle(
                fontFamily: 'Consolas',
                fontSize: 18,
                letterSpacing: 6.0,
                color: AppColors.surfaceContainerHighest,
              ),
              counterText: '',
              errorText: _error,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
          child: const Text('JOIN',
              style: TextStyle(fontFamily: 'Segoe UI', fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
