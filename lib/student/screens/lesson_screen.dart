// lib/student/screens/lesson_screen.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/models/attention_state.dart';
import '../../core/models/topic.dart';
import '../../core/services/attention_stream.dart';
import '../widgets/focus_hud.dart';
import 'interventions/intervention_engine.dart';

/// Lesson screen — full-screen content renderer with HUD and pacing engine.
///
/// Displays topic content in a low-stimulation design (dark bg, serif font).
/// Pacing engine listens to AttentionStream and pauses content on drift/lost,
/// resumes on recovery to focused.
class LessonScreen extends StatefulWidget {
  final String topicId;

  const LessonScreen({super.key, required this.topicId});

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen>
    with SingleTickerProviderStateMixin {
  Topic? _topic;
  bool _loading = true;
  int _currentSectionIndex = 0;

  // Pacing engine state
  bool _paused = false;
  AttentionLevel _currentLevel = AttentionLevel.focused;
  StreamSubscription<AttentionState>? _attentionSub;
  int _driftSeconds = 0;
  Timer? _driftTimer;

  // Intervention engine
  final _interventionEngine = InterventionEngine();
  bool _showingIntervention = false;
  String? _currentFormat;

  // Session tracking
  final _sessionStart = DateTime.now();
  int _driftCount = 0;

  // Scroll
  final _scrollController = ScrollController();

  // Pause overlay animation
  late final AnimationController _pauseAnim;

  @override
  void initState() {
    super.initState();
    _pauseAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadTopic();
    _startPacingEngine();
  }

  Future<void> _loadTopic() async {
    try {
      final jsonStr = await rootBundle.loadString(
        'assets/curriculum/${widget.topicId}.json',
      );
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      setState(() {
        _topic = Topic.fromJson(json);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _startPacingEngine() {
    _attentionSub = AttentionStream.instance.stream.listen((state) {
      if (!mounted) return;

      final previousLevel = _currentLevel;
      _currentLevel = state.level;

      // Transition to drifting/lost → pause
      if (!_paused &&
          (state.level == AttentionLevel.drifting ||
              state.level == AttentionLevel.lost)) {
        _onDriftDetected();
      }

      // Transition back to focused → resume
      if (_paused && state.level == AttentionLevel.focused) {
        _onFocusRecovered();
      }
    });
  }

  void _onDriftDetected() {
    setState(() {
      _paused = true;
      _driftCount++;
      _driftSeconds = 0;
    });
    _pauseAnim.forward();

    // Track drift duration
    _driftTimer?.cancel();
    _driftTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _driftSeconds++);

      // After 4 seconds of drift, launch intervention
      if (_driftSeconds >= 4 && !_showingIntervention && !_interventionEngine.isActive) {
        _launchIntervention();
      }
    });
  }

  void _launchIntervention() {
    _interventionEngine.start(
      driftDurationSec: _driftSeconds,
      topicId: widget.topicId,
      subject: _topic?.subject ?? '',
    );

    final format = _interventionEngine.selectNextFormat();
    setState(() {
      _showingIntervention = true;
      _currentFormat = format;
    });
  }

  void _onInterventionComplete() {
    // Check if attention recovered (simplified — check current level)
    final recovered = _currentLevel == AttentionLevel.focused;
    _interventionEngine.reportResult(_currentFormat!, recovered);

    if (!recovered && _interventionEngine.hasMoreFormats) {
      // Cascade to next format
      final nextFormat = _interventionEngine.selectNextFormat();
      setState(() => _currentFormat = nextFormat);
    } else {
      // Either recovered or exhausted all formats — resume
      _onFocusRecovered();
    }
  }

  void _onFocusRecovered() {
    _driftTimer?.cancel();
    _pauseAnim.reverse();
    _interventionEngine.reset();

    setState(() {
      _paused = false;
      _showingIntervention = false;
      _currentFormat = null;
    });
  }

  void _nextSection() {
    if (_topic != null && _currentSectionIndex < _topic!.sections.length - 1) {
      setState(() => _currentSectionIndex++);
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      // All sections complete → session end
      context.go('/student');
    }
  }

  void _prevSection() {
    if (_currentSectionIndex > 0) {
      setState(() => _currentSectionIndex--);
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _attentionSub?.cancel();
    _driftTimer?.cancel();
    _scrollController.dispose();
    _pauseAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_topic == null) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                'Failed to load topic: ${widget.topicId}',
                style: const TextStyle(color: AppColors.onSurface),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/student'),
                child: const Text('BACK TO DASHBOARD'),
              ),
            ],
          ),
        ),
      );
    }

    final topic = _topic!;
    final section = topic.sections[_currentSectionIndex];

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          // Main content
          Column(
            children: [
              // Top bar
              _buildTopBar(topic),

              // Content area
              Expanded(
                child: _buildContentArea(topic, section),
              ),

              // Focus HUD
              const FocusHud(),
            ],
          ),

          // Intervention or pause overlay
          if (_showingIntervention && _currentFormat != null)
            Container(
              color: AppColors.surface,
              child: InterventionEngine.buildFormatScreen(
                format: _currentFormat!,
                topicId: widget.topicId,
                onComplete: _onInterventionComplete,
              ),
            )
          else if (_paused)
            _buildPauseOverlay(),
        ],
      ),
    );
  }

  Widget _buildTopBar(Topic topic) {
    final elapsed = DateTime.now().difference(_sessionStart);
    final minutes = elapsed.inMinutes;
    final seconds = elapsed.inSeconds % 60;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: AppColors.surfaceContainer,
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 20, color: AppColors.outline),
            onPressed: () => context.go('/student'),
          ),

          const SizedBox(width: 12),

          // Topic info
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  topic.name.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Segoe UI',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.0,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  'Section ${_currentSectionIndex + 1} of ${topic.sections.length} · ${topic.subject}',
                  style: const TextStyle(
                    fontFamily: 'Consolas',
                    fontSize: 10,
                    color: AppColors.outline,
                  ),
                ),
              ],
            ),
          ),

          // Session timer
          Text(
            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
            style: const TextStyle(
              fontFamily: 'Consolas',
              fontSize: 14,
              color: AppColors.onSurfaceVariant,
            ),
          ),

          const SizedBox(width: 16),

          // Drift counter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _driftCount > 0
                  ? AppColors.drifting.withValues(alpha: 0.15)
                  : AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$_driftCount drifts',
              style: TextStyle(
                fontFamily: 'Consolas',
                fontSize: 11,
                color: _driftCount > 0 ? AppColors.drifting : AppColors.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentArea(Topic topic, Section section) {
    return Row(
      children: [
        // Left sidebar — section navigation
        Container(
          width: 220,
          color: AppColors.surfaceContainerLow,
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'SECTIONS',
                  style: TextStyle(
                    fontFamily: 'Consolas',
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3.0,
                    color: AppColors.outline,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...List.generate(topic.sections.length, (i) {
                final isActive = i == _currentSectionIndex;
                final s = topic.sections[i];
                return InkWell(
                  onTap: () {
                    setState(() => _currentSectionIndex = i);
                    _scrollController.animateTo(0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.secondaryContainer.withValues(alpha: 0.3)
                          : Colors.transparent,
                      border: Border(
                        left: BorderSide(
                          color: isActive ? AppColors.primary : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Text(
                      s.title,
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 13,
                        color: isActive ? AppColors.primary : AppColors.onSurfaceVariant,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),

        // Main content
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section title
                  Text(
                    section.title,
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface,
                      height: 1.3,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Content paragraphs
                  ...section.content.split('\n\n').map(
                    (paragraph) => Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Text(
                        paragraph.trim(),
                        style: const TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 16,
                          color: AppColors.onSurfaceVariant,
                          height: 1.8,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),

                  // Key terms
                  if (section.keyTerms.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(
                          color: AppColors.outlineVariant.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'KEY TERMS',
                            style: TextStyle(
                              fontFamily: 'Consolas',
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 3.0,
                              color: AppColors.outline,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: section.keyTerms.map((term) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  term,
                                  style: const TextStyle(
                                    fontFamily: 'Segoe UI',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.primary,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 40),

                  // Navigation buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_currentSectionIndex > 0)
                        TextButton.icon(
                          onPressed: _prevSection,
                          icon: const Icon(Icons.arrow_back, size: 16),
                          label: const Text('Previous Section'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.outline,
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                      ElevatedButton(
                        onPressed: _nextSection,
                        child: Text(
                          _currentSectionIndex < topic.sections.length - 1
                              ? 'CONTINUE TO NEXT SECTION'
                              : 'COMPLETE LESSON',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPauseOverlay() {
    return AnimatedBuilder(
      animation: _pauseAnim,
      builder: (_, __) => Opacity(
        opacity: _pauseAnim.value,
        child: Container(
          color: AppColors.surface.withValues(alpha: 0.85),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Attention icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (_currentLevel == AttentionLevel.lost
                            ? AppColors.lost
                            : AppColors.drifting)
                        .withValues(alpha: 0.15),
                  ),
                  child: Icon(
                    _currentLevel == AttentionLevel.lost
                        ? Icons.warning_amber
                        : Icons.pause_circle_outline,
                    size: 40,
                    color: _currentLevel == AttentionLevel.lost
                        ? AppColors.lost
                        : AppColors.drifting,
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  _currentLevel == AttentionLevel.lost
                      ? 'FOCUS LOST'
                      : 'ATTENTION DRIFTING',
                  style: TextStyle(
                    fontFamily: 'Consolas',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3.0,
                    color: _currentLevel == AttentionLevel.lost
                        ? AppColors.lost
                        : AppColors.drifting,
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  'Content paused. Refocus to continue.',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontStyle: FontStyle.italic,
                    fontSize: 16,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Drifting for $_driftSeconds seconds',
                  style: const TextStyle(
                    fontFamily: 'Consolas',
                    fontSize: 12,
                    color: AppColors.outline,
                  ),
                ),

                const SizedBox(height: 32),

                // Manual resume button (fallback)
                OutlinedButton(
                  onPressed: _onFocusRecovered,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.outlineVariant),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text(
                    'RESUME MANUALLY',
                    style: TextStyle(
                      fontFamily: 'Segoe UI',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2.0,
                      color: AppColors.outline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
