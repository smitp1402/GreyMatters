// lib/student/screens/library_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Curated Knowledge library — all topics organized by subject.
///
/// Matches the Stitch curated_knowledge_visual_library design:
/// - "Curated Knowledge" header with subject filter tabs
/// - Two-column grid of topic cards with gradient image areas
/// - Each card: focus %, topic name, description, session time, status
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _filter = 'All';

  // Static topic data for all available topics
  static const _allTopics = [
    _TopicData(
      id: 'periodic_table',
      name: 'Periodic Table',
      description: 'Elemental trends and electronegativity.',
      subject: 'Chemistry',
      focusPercent: 54,
      sessionTime: '10m session',
      status: 'Low Persistence',
      statusIcon: Icons.priority_high,
      statusColor: AppColors.error,
      gradientStart: Color(0xFF1a3a2a),
      gradientEnd: Color(0xFF0e1e15),
    ),
    _TopicData(
      id: 'chemical_bonding',
      name: 'Chemical Bonding',
      description: 'Ionic and covalent electrostatic interactions.',
      subject: 'Chemistry',
      focusPercent: 91,
      sessionTime: '15m session',
      status: 'Elite Depth',
      statusIcon: Icons.trending_up,
      statusColor: AppColors.primary,
      gradientStart: Color(0xFF2a2a1a),
      gradientEnd: Color(0xFF1e1e0e),
    ),
    _TopicData(
      id: 'cell_structure',
      name: 'Cell Structure',
      description: 'Functional anatomy of the microscopic unit.',
      subject: 'Biology',
      focusPercent: 88,
      sessionTime: '45m session',
      status: 'Mastered',
      statusIcon: Icons.trending_up,
      statusColor: AppColors.primary,
      gradientStart: Color(0xFF1a2a3a),
      gradientEnd: Color(0xFF0e1520),
    ),
    _TopicData(
      id: 'dna_replication',
      name: 'DNA Replication',
      description: 'Molecular synthesis and error correction.',
      subject: 'Biology',
      focusPercent: 94,
      sessionTime: '1h 10m session',
      status: 'High Flow',
      statusIcon: Icons.bolt,
      statusColor: AppColors.tertiary,
      gradientStart: Color(0xFF2a1a2a),
      gradientEnd: Color(0xFF1e0e1e),
    ),
    _TopicData(
      id: 'cell_division',
      name: 'Cell Division',
      description: 'Mitosis and meiosis cycle mechanics.',
      subject: 'Biology',
      focusPercent: 62,
      sessionTime: '32m session',
      status: 'Review Needed',
      statusIcon: Icons.priority_high,
      statusColor: AppColors.tertiary,
      gradientStart: Color(0xFF1a2a1a),
      gradientEnd: Color(0xFF0e1e0e),
    ),
    _TopicData(
      id: 'covalent_bonds',
      name: 'Covalent Bonds',
      description: 'Electron sharing and hybrid orbital theory.',
      subject: 'Chemistry',
      focusPercent: 82,
      sessionTime: '42m session',
      status: 'Stable',
      statusIcon: Icons.trending_up,
      statusColor: AppColors.primary,
      gradientStart: Color(0xFF2a2a2a),
      gradientEnd: Color(0xFF1a1a1a),
    ),
  ];

  List<_TopicData> get _filteredTopics {
    if (_filter == 'All') return _allTopics;
    return _allTopics.where((t) => t.subject == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final biology = _filteredTopics.where((t) => t.subject == 'Biology').toList();
    final chemistry = _filteredTopics.where((t) => t.subject == 'Chemistry').toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header + filter
            _buildHeader(),
            const SizedBox(height: 40),

            // Two-column grid
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 700 && _filter == 'All') {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Biology column
                      Expanded(child: _buildSubjectColumn('BIOLOGY', biology)),
                      const SizedBox(width: 32),
                      // Chemistry column
                      Expanded(child: _buildSubjectColumn('CHEMISTRY', chemistry)),
                    ],
                  );
                }
                // Single column for filtered or narrow
                return _buildSubjectColumn(
                  _filter == 'All' ? null : _filter.toUpperCase(),
                  _filteredTopics,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CLINICAL LEARNING RESOURCES',
                style: TextStyle(
                  fontFamily: 'Segoe UI',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.0,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Curated Knowledge',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 44,
                  fontWeight: FontWeight.w500,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
        ),
        // Filter tabs
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Row(
            children: ['All', 'Biology', 'Chemistry'].map((f) {
              final isActive = _filter == f;
              return GestureDetector(
                onTap: () => setState(() => _filter = f),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.surfaceContainerHighest
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm + 2),
                  ),
                  child: Text(
                    f,
                    style: TextStyle(
                      fontFamily: 'Segoe UI',
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      color: isActive ? AppColors.primary : AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectColumn(String? sectionTitle, List<_TopicData> topics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (sectionTitle != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                sectionTitle,
                style: const TextStyle(
                  fontFamily: 'Segoe UI',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3.0,
                  color: AppColors.primary,
                ),
              ),
              Text(
                '${topics.length} MODULES AVAILABLE',
                style: TextStyle(
                  fontFamily: 'Segoe UI',
                  fontSize: 11,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(color: AppColors.outlineVariant.withValues(alpha: 0.1)),
          const SizedBox(height: 24),
        ],
        ...topics.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: _TopicCard(topic: t),
            )),
      ],
    );
  }
}

// ============================================================
// Topic Card (library grid item)
// ============================================================

class _TopicCard extends StatefulWidget {
  const _TopicCard({required this.topic});
  final _TopicData topic;

  @override
  State<_TopicCard> createState() => _TopicCardState();
}

class _TopicCardState extends State<_TopicCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.topic;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => context.go('/student/lesson/${t.id}'),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            border: Border.all(
              color: _hovered
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : AppColors.outlineVariant.withValues(alpha: 0.1),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image area with gradient
              Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [t.gradientStart, t.gradientEnd],
                  ),
                ),
                child: Stack(
                  children: [
                    // Gradient overlay to bottom
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 80,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              AppColors.surfaceContainerLow,
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Focus metric badge
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          border: Border.all(
                            color: AppColors.outlineVariant.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '${t.focusPercent}%',
                              style: TextStyle(
                                fontFamily: 'Segoe UI',
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: t.focusPercent >= 80
                                    ? AppColors.primary
                                    : t.focusPercent >= 60
                                        ? AppColors.tertiary
                                        : AppColors.error,
                              ),
                            ),
                            const Text(
                              'LAST FOCUS',
                              style: TextStyle(
                                fontFamily: 'Segoe UI',
                                fontSize: 8,
                                letterSpacing: 1.0,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Subject icon
                    Positioned(
                      top: 16,
                      left: 16,
                      child: Icon(
                        t.subject == 'Biology' ? Icons.biotech : Icons.science,
                        size: 24,
                        color: AppColors.onSurface.withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                ),
              ),
              // Content area
              Container(
                color: AppColors.surfaceContainerLow,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.name,
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 22,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t.description,
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontStyle: FontStyle.italic,
                        fontSize: 14,
                        color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Divider(
                      color: AppColors.outlineVariant.withValues(alpha: 0.05),
                      height: 1,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 14,
                            color: AppColors.onSurfaceVariant.withValues(alpha: 0.6)),
                        const SizedBox(width: 6),
                        Text(
                          t.sessionTime,
                          style: TextStyle(
                            fontFamily: 'Segoe UI',
                            fontSize: 12,
                            color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(t.statusIcon, size: 14, color: t.statusColor),
                        const SizedBox(width: 4),
                        Text(
                          t.status,
                          style: TextStyle(
                            fontFamily: 'Segoe UI',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: t.statusColor,
                          ),
                        ),
                        const Spacer(),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: _hovered ? 1.0 : 0.0,
                          child: const Icon(Icons.arrow_forward,
                              size: 16, color: AppColors.onSurfaceVariant),
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
    );
  }
}

// ============================================================
// Data model for static topic list
// ============================================================

class _TopicData {
  final String id, name, description, subject, sessionTime, status;
  final int focusPercent;
  final IconData statusIcon;
  final Color statusColor, gradientStart, gradientEnd;

  const _TopicData({
    required this.id,
    required this.name,
    required this.description,
    required this.subject,
    required this.focusPercent,
    required this.sessionTime,
    required this.status,
    required this.statusIcon,
    required this.statusColor,
    required this.gradientStart,
    required this.gradientEnd,
  });
}
