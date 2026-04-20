// lib/student/screens/lesson_screen.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../../core/config/feature_flags.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/models/attention_state.dart';
import '../../core/models/topic.dart';
import '../../core/services/attention_stream.dart';
import '../../core/services/session_manager.dart';
import '../widgets/periodic_table_diagram.dart';
import 'interventions/intervention_engine.dart';

/// Lesson screen — full lesson renderer following the doc structure:
/// text → diagram → video → callout → checkpoint per section.
/// Sidebar with section locking (unlock via checkpoint).
/// Focus HUD at bottom, pacing engine pauses on drift.
class LessonScreen extends StatefulWidget {
  final String subject;
  final String topicId;
  const LessonScreen({super.key, required this.subject, required this.topicId});

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen>
    with SingleTickerProviderStateMixin {
  Topic? _topic;
  bool _loading = true;
  int _currentSectionIndex = 0;

  // Section locking: index of highest unlocked section
  int _unlockedUpTo = 0;
  // Checkpoint state per section
  final Map<int, bool> _checkpointCompleted = {};
  int? _selectedOption;
  bool? _checkpointCorrect;

  // Pacing
  bool _paused = false;
  AttentionLevel _currentLevel = AttentionLevel.focused;
  StreamSubscription<AttentionState>? _attentionSub;
  int _driftSeconds = 0;
  Timer? _driftTimer;

  // Interventions
  final _interventionEngine = InterventionEngine();
  bool _showingIntervention = false;
  String? _currentFormat;
  bool _showingGoodJob = false;
  // Cooldown: ignore EEG readings for 5s after transitions to prevent flapping.
  DateTime? _cooldownUntil;

  // Debug
  bool _debugExpanded = false;
  bool _debugPanelOpen = false;
  AttentionState? _latestState;

  // Session
  final _sessionStart = DateTime.now();
  int _driftCount = 0;
  final _scrollController = ScrollController();
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

  String? _loadError;

  Future<void> _loadTopic() async {
    try {
      final jsonStr = await rootBundle.loadString(
        'assets/curriculum/${widget.subject}/${widget.topicId}/lesson.json',
      );
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      setState(() {
        _topic = Topic.fromJson(json);
        _loading = false;
      });
    } catch (e, stack) {
      debugPrint('Failed to load topic: $e');
      debugPrint('$stack');
      setState(() {
        _loading = false;
        _loadError = e.toString();
      });
    }
  }

  // Rolling window for drift detection — prevents false triggers from
  // momentary dips. Drift is confirmed only when 5+ of the last 10
  // readings are below threshold (drifting or lost).
  static const int _driftWindowSize = 10;
  static const int _driftConfirmCount = 5;
  final List<AttentionLevel> _recentLevels = [];
  bool _driftConfirmed = false;

  // Dev overwrite — spacebar cycle index for FeatureFlags.useEegTrigger=false.
  // Press Space on the lesson to advance: focused → drifting → lost → focused.
  // Nothing else in the app touches this; it's lesson-local state.
  static const List<AttentionLevel> _demoCycle = <AttentionLevel>[
    AttentionLevel.focused,
    AttentionLevel.drifting,
    AttentionLevel.lost,
  ];
  int _demoCycleIndex = 0;

  void _startPacingEngine() {
    _attentionSub = AttentionStream.instance.stream.listen((state) {
      if (!mounted) return;
      _currentLevel = state.level;
      _latestState = state;

      // Rebuild when debug panel is open so it shows live data
      if (_debugPanelOpen) setState(() {});

      // Broadcast to Supabase Realtime for teacher monitoring
      SessionManager.instance.onAttentionState(state);

      // Dev overwrite: when the EEG trigger is off, EEG readings from
      // the daemon are consumed (so HUD + session recording still see
      // them) but they do NOT drive drift detection. The spacebar handler
      // below is the sole trigger path in this mode. This stays true
      // even if the Crown is connected + calibrated.
      if (!FeatureFlags.useEegTrigger) {
        return;
      }

      // Skip window updates during cooldown after transitions
      if (_cooldownUntil != null && DateTime.now().isBefore(_cooldownUntil!)) {
        return;
      }
      _cooldownUntil = null;

      // Maintain rolling window of last N readings
      _recentLevels.add(state.level);
      if (_recentLevels.length > _driftWindowSize) {
        _recentLevels.removeAt(0);
      }

      // Count how many of the last N readings are drifting or lost
      final driftCount = _recentLevels
          .where((l) => l == AttentionLevel.drifting || l == AttentionLevel.lost)
          .length;

      if (!_paused && driftCount >= _driftConfirmCount) {
        _driftConfirmed = true;
        _onDriftDetected();
      }
      if (_paused &&
          !_showingIntervention &&
          driftCount < _driftConfirmCount &&
          state.level == AttentionLevel.focused) {
        _driftConfirmed = false;
        _onFocusRecovered();
      }

      // Periodic table: if attention recovers mid-intervention, show
      // "Good job!" and resume the lesson immediately.
      if (_showingIntervention &&
          widget.topicId == 'periodic_table' &&
          !_showingGoodJob &&
          driftCount < _driftConfirmCount &&
          state.level == AttentionLevel.focused) {
        _showGoodJobAndResume();
      }
    });
  }

  /// Keyboard handler for the lesson screen. Advances the demo cycle
  /// (focused → drifting → lost → focused) and routes to the shared
  /// drift/recovery handler. No-op when the EEG trigger is active —
  /// in that case the real stream drives state and space does nothing
  /// here (it's also consumed so Flutter's default button activation
  /// on Space doesn't fire randomly while reading a lesson).
  void _onLessonSpacebar() {
    if (FeatureFlags.useEegTrigger) return;
    _demoCycleIndex = (_demoCycleIndex + 1) % _demoCycle.length;
    final next = _demoCycle[_demoCycleIndex];
    _handleDemoAttention(next);
  }

  /// Dev-overwrite path — responds to a single spacebar press by
  /// bypassing ONLY the 5-of-10 rolling-window barrier. The rest of the
  /// drift flow (pause, 4-second sustain timer, then intervention) runs
  /// normally so the presentation still shows the drift screen / countdown
  /// / intervention sequence the way the real EEG pipeline would.
  void _handleDemoAttention(AttentionLevel level) {
    final isDrift = level == AttentionLevel.drifting ||
        level == AttentionLevel.lost;

    if (isDrift) {
      // If we're already paused (entered drift on a previous press, now
      // press took us from drifting → lost), don't restart the timer —
      // let the existing 4s countdown continue toward intervention. The
      // current level display will update naturally on the next rebuild.
      if (_paused || _showingIntervention) return;

      // Pre-fill the rolling window so any debug panel looking at the
      // count displays the "enough drift samples" state consistently.
      _recentLevels
        ..clear()
        ..addAll(List<AttentionLevel>.filled(_driftConfirmCount, level));
      _driftConfirmed = true;
      // Run the normal drift-detected path — same pause, same 4s timer,
      // same intervention launch. The "drift screen" UX is preserved.
      _onDriftDetected();
    } else {
      // level == focused → recover, mirroring the normal focused-recovery
      // path (closes intervention, clears window, sets a cooldown).
      if (_paused || _showingIntervention) {
        _onFocusRecovered();
      }
    }
  }

  void _onDriftDetected() {
    if (_paused) return; // Already in drift state
    setState(() { _paused = true; _driftCount++; _driftSeconds = 0; });
    _pauseAnim.forward();
    _driftTimer?.cancel();
    _driftTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _driftSeconds++);
      if (_driftSeconds >= 4 && !_showingIntervention && !_interventionEngine.isActive) {
        _launchIntervention();
      }
    });
  }

  void _launchIntervention() {
    // For periodic_table, always launch the custom activity directly
    // (bypasses RL agent without removing it).
    debugPrint('[INTERVENTION] topicId="${widget.topicId}" → ${widget.topicId == 'periodic_table' ? 'ACTIVITY' : 'RL agent'}');
    if (widget.topicId == 'periodic_table') {
      _recentLevels.clear();
      _cooldownUntil = DateTime.now().add(const Duration(seconds: 5));
      setState(() { _showingIntervention = true; _currentFormat = 'activity'; });
      return;
    }

    _interventionEngine.start(
      driftDurationSec: _driftSeconds,
      topicId: widget.topicId,
      subject: _topic?.subject ?? '',
    );
    final format = _interventionEngine.selectNextFormat();
    setState(() { _showingIntervention = true; _currentFormat = format; });
  }

  void _onInterventionComplete() {
    // For periodic_table, skip cascade — go straight back to lesson.
    if (widget.topicId == 'periodic_table') {
      _onFocusRecovered();
      return;
    }

    final recovered = _currentLevel == AttentionLevel.focused;
    _interventionEngine.reportResult(_currentFormat!, recovered);
    if (!recovered && _interventionEngine.hasMoreFormats) {
      final next = _interventionEngine.selectNextFormat();
      setState(() => _currentFormat = next);
    } else {
      _onFocusRecovered();
    }
  }

  void _showGoodJobAndResume() {
    setState(() { _showingGoodJob = true; _showingIntervention = false; _currentFormat = null; });
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _showingGoodJob = false);
      _onFocusRecovered();
    });
  }

  void _onFocusRecovered() {
    _driftTimer?.cancel();
    _pauseAnim.reverse();
    _interventionEngine.reset();
    _recentLevels.clear();
    _cooldownUntil = DateTime.now().add(const Duration(seconds: 5));
    _driftConfirmed = false;
    setState(() { _paused = false; _showingIntervention = false; _currentFormat = null; });
  }

  void _debugForceIntervention(String format) {
    setState(() {
      _showingIntervention = true;
      _currentFormat = format;
      _paused = false;
      _debugExpanded = false;
    });
  }

  void _debugDismissIntervention() {
    _interventionEngine.reset();
    setState(() {
      _showingIntervention = false;
      _currentFormat = null;
      _paused = false;
    });
  }

  void _goToSection(int index) {
    if (index > _unlockedUpTo) return;
    setState(() {
      _currentSectionIndex = index;
      _selectedOption = null;
      _checkpointCorrect = null;
    });
    _scrollController.animateTo(0,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  void _onCheckpointAnswer(int optionIndex) {
    final cp = _topic!.sections[_currentSectionIndex].checkpoint;
    if (cp == null) return;
    final correct = optionIndex == cp.correctIndex;
    setState(() {
      _selectedOption = optionIndex;
      _checkpointCorrect = correct;
    });
    if (correct) {
      setState(() {
        _checkpointCompleted[_currentSectionIndex] = true;
        if (_currentSectionIndex + 1 > _unlockedUpTo &&
            _currentSectionIndex + 1 < _topic!.sections.length) {
          _unlockedUpTo = _currentSectionIndex + 1;
        }
      });
    }
  }

  void _nextSection() {
    if (_topic != null && _currentSectionIndex < _topic!.sections.length - 1) {
      _goToSection(_currentSectionIndex + 1);
    } else {
      context.go('/student/session-end');
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
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text('Failed to load topic: ${widget.topicId}',
                style: const TextStyle(color: AppColors.onSurface)),
            if (_loadError != null) ...[
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Text(_loadError!,
                    style: TextStyle(color: AppColors.outline, fontSize: 12, fontFamily: 'Consolas'),
                    textAlign: TextAlign.center),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/student'),
              child: const Text('BACK TO DASHBOARD'),
            ),
          ]),
        ),
      );
    }

    final topic = _topic!;
    final section = topic.sections[_currentSectionIndex];
    final progress = (_currentSectionIndex + (_checkpointCompleted.containsKey(_currentSectionIndex) ? 1 : 0)) / topic.sections.length;

    // Scoped spacebar binding — only active while this lesson screen is
    // built. Goes away on navigation, so it can't affect any other screen.
    // Also overrides Flutter's default button activation on Space for
    // widgets inside the lesson (buttons still activate on Enter).
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.space): _onLessonSpacebar,
      },
      child: Focus(
        autofocus: true,
        child: _buildLessonScaffold(topic, section, progress),
      ),
    );
  }

  Widget _buildLessonScaffold(Topic topic, Section section, double progress) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          Column(
            children: [
              _buildTopBar(topic, progress),
              Expanded(
                child: Row(
                  children: [
                    _buildSidebar(topic),
                    Expanded(child: _buildContent(section)),
                  ],
                ),
              ),
            ],
          ),
          if (_showingGoodJob)
            Container(
              color: AppColors.surface,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.celebration, size: 64, color: AppColors.focused),
                    const SizedBox(height: 16),
                    Text('Good job!',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: AppColors.focused,
                        fontFamily: 'Consolas',
                      )),
                    const SizedBox(height: 8),
                    Text('Your focus is back — resuming lesson...',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.outline,
                        fontFamily: 'Consolas',
                      )),
                  ],
                ),
              ),
            )
          else if (_showingIntervention && _currentFormat != null)
            Container(
              color: AppColors.surface,
              child: InterventionEngine.buildFormatScreen(
                format: _currentFormat!,
                subject: widget.subject,
                topicId: widget.topicId,
                sectionIndex: _currentSectionIndex,
                onComplete: _onInterventionComplete,
              ),
            )
          else if (_paused)
            _buildPauseOverlay(section),

          // Debug EEG panel
          if (_debugPanelOpen) _buildDebugPanel(),

          // Debug FAB
          _buildDebugFab(),
        ],
      ),
    );
  }

  // ── Debug EEG Panel ─────────────────────────────────────────

  Widget _buildDebugPanel() {
    final s = _latestState;
    final driftCount = _recentLevels
        .where((l) => l == AttentionLevel.drifting || l == AttentionLevel.lost)
        .length;
    final windowSize = _recentLevels.length;
    final threshold = _driftConfirmCount;

    final Color levelColor;
    switch (_currentLevel) {
      case AttentionLevel.focused:
        levelColor = AppColors.focused;
      case AttentionLevel.drifting:
        levelColor = AppColors.drifting;
      case AttentionLevel.lost:
        levelColor = AppColors.lost;
    }

    return Positioned(
      left: 16,
      bottom: 16,
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: levelColor.withValues(alpha: 0.4)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: levelColor),
                ),
                const SizedBox(width: 8),
                Text('EEG DEBUG',
                  style: TextStyle(fontFamily: 'Consolas', fontSize: 11,
                    fontWeight: FontWeight.w700, letterSpacing: 2, color: AppColors.outline)),
                const Spacer(),
                Text(_currentLevel.name.toUpperCase(),
                  style: TextStyle(fontFamily: 'Consolas', fontSize: 12,
                    fontWeight: FontWeight.w700, color: levelColor)),
              ],
            ),
            const SizedBox(height: 12),

            // Focus score bar
            _debugRow('FOCUS SCORE', s != null ? '${(s.focusScore * 100).toStringAsFixed(1)}%' : '--'),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: s?.focusScore ?? 0,
                minHeight: 8,
                backgroundColor: AppColors.surfaceContainerLowest,
                valueColor: AlwaysStoppedAnimation(levelColor),
              ),
            ),
            const SizedBox(height: 12),

            // Band powers
            if (s != null) ...[
              _debugRow('B/T RATIO', s.betaTheta.toStringAsFixed(3)),
              _debugRow('T/A RATIO', s.thetaAlpha.toStringAsFixed(3)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _debugBand('d', s.delta, AppColors.outline),
                  _debugBand('t', s.theta, AppColors.lost),
                  _debugBand('a', s.alpha, AppColors.drifting),
                  _debugBand('b', s.beta, AppColors.focused),
                  _debugBand('g', s.gamma, AppColors.primary),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Drift detection state
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ROLLING WINDOW  [$windowSize/$_driftWindowSize]',
                    style: TextStyle(fontFamily: 'Consolas', fontSize: 9,
                      fontWeight: FontWeight.w700, letterSpacing: 1.5, color: AppColors.outline)),
                  const SizedBox(height: 6),
                  Row(
                    children: List.generate(_driftWindowSize, (i) {
                      if (i >= _recentLevels.length) {
                        return _windowDot(AppColors.surfaceContainerLowest);
                      }
                      final l = _recentLevels[i];
                      final c = l == AttentionLevel.focused
                          ? AppColors.focused
                          : l == AttentionLevel.drifting
                              ? AppColors.drifting
                              : AppColors.lost;
                      return _windowDot(c);
                    }),
                  ),
                  const SizedBox(height: 8),
                  _debugRow('DRIFT COUNT', '$driftCount / $threshold'),
                  _debugRow('DRIFT TIMER', _paused ? '${_driftSeconds}s (>=4 triggers)' : 'inactive'),
                  _debugRow('INTERVENTION', _showingIntervention ? 'ACTIVE ($_currentFormat)' : 'none'),
                  _debugRow('WILL TRIGGER?',
                    driftCount >= threshold
                        ? 'YES - threshold met'
                        : 'NO - need ${threshold - driftCount} more',
                    valueColor: driftCount >= threshold ? AppColors.lost : AppColors.focused),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _debugRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontFamily: 'Consolas', fontSize: 10,
            color: AppColors.outline, letterSpacing: 0.5)),
          Text(value, style: TextStyle(fontFamily: 'Consolas', fontSize: 10,
            fontWeight: FontWeight.w700, color: valueColor ?? AppColors.onSurface)),
        ],
      ),
    );
  }

  Widget _debugBand(String label, double value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: TextStyle(fontFamily: 'Consolas', fontSize: 9,
            fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0).toDouble(),
              minHeight: 4,
              backgroundColor: AppColors.surfaceContainerLowest,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          Text(value.toStringAsFixed(2),
            style: TextStyle(fontFamily: 'Consolas', fontSize: 8, color: AppColors.outline)),
        ],
      ),
    );
  }

  Widget _windowDot(Color color) {
    return Expanded(
      child: Container(
        height: 14,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }

  // ── Debug FAB ─────────────────────────────────────────────────

  Widget _buildDebugFab() {
    const formats = [
      ('flashcard', Icons.style, 'Flashcard'),
      ('gesture', Icons.pan_tool, 'Gesture'),
      ('voice', Icons.mic, 'Voice'),
      ('simulation', Icons.drag_indicator, 'Simulation'),
      ('activity', Icons.science, 'Alchemist'),
    ];

    return Positioned(
      right: 16,
      bottom: 100,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Back to lesson button (visible during intervention)
          if (_showingIntervention)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FloatingActionButton.extended(
                heroTag: 'debug_back',
                onPressed: _debugDismissIntervention,
                backgroundColor: AppColors.lost,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('BACK TO LESSON',
                    style: TextStyle(fontFamily: 'Consolas', fontSize: 11,
                        fontWeight: FontWeight.w700, letterSpacing: 1.5)),
              ),
            ),

          // Format buttons (visible when expanded)
          if (_debugExpanded)
            ...formats.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FloatingActionButton.extended(
                    heroTag: 'debug_${f.$1}',
                    onPressed: () => _debugForceIntervention(f.$1),
                    backgroundColor: AppColors.surfaceContainerHigh,
                    foregroundColor: AppColors.primary,
                    icon: Icon(f.$2, size: 18),
                    label: Text(f.$3,
                        style: const TextStyle(fontFamily: 'Consolas',
                            fontSize: 11, fontWeight: FontWeight.w700,
                            letterSpacing: 1.5)),
                  ),
                )),

          // Live EEG debug panel toggle
          if (_debugExpanded)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FloatingActionButton.extended(
                heroTag: 'debug_panel',
                onPressed: () => setState(() => _debugPanelOpen = !_debugPanelOpen),
                backgroundColor: _debugPanelOpen
                    ? AppColors.focused
                    : AppColors.surfaceContainerHigh,
                foregroundColor: _debugPanelOpen
                    ? Colors.white
                    : AppColors.primary,
                icon: Icon(_debugPanelOpen ? Icons.visibility_off : Icons.visibility, size: 18),
                label: Text(_debugPanelOpen ? 'Hide EEG' : 'Show EEG',
                    style: const TextStyle(fontFamily: 'Consolas', fontSize: 11,
                        fontWeight: FontWeight.w700, letterSpacing: 1.5)),
              ),
            ),

          // Main toggle button
          FloatingActionButton.small(
            heroTag: 'debug_toggle',
            onPressed: () => setState(() => _debugExpanded = !_debugExpanded),
            backgroundColor: _debugExpanded
                ? AppColors.primary
                : AppColors.surfaceContainerHighest,
            foregroundColor: _debugExpanded
                ? AppColors.onPrimary
                : AppColors.outline,
            child: Icon(_debugExpanded ? Icons.close : Icons.bug_report, size: 20),
          ),
        ],
      ),
    );
  }

  // ── Top Bar ──────────────────────────────────────────────

  Widget _buildTopBar(Topic topic, double progress) {
    final elapsed = DateTime.now().difference(_sessionStart);
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: AppColors.surfaceContainer,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 20, color: AppColors.outline),
            onPressed: () => context.go('/student'),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(topic.subject.toUpperCase(),
                  style: const TextStyle(fontFamily: 'Consolas', fontSize: 9,
                      fontWeight: FontWeight.w700, letterSpacing: 2.0, color: AppColors.primary)),
              Text(topic.name,
                  style: const TextStyle(fontFamily: 'Segoe UI', fontSize: 14,
                      fontWeight: FontWeight.w600, color: AppColors.onSurface)),
            ],
          ),
          const SizedBox(width: 20),
          // Progress bar
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Text('Progress', style: TextStyle(fontFamily: 'Consolas',
                        fontSize: 9, color: AppColors.outline.withValues(alpha: 0.6))),
                    const Spacer(),
                    Text('${(progress * 100).round()}%', style: TextStyle(fontFamily: 'Consolas',
                        fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.focused)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.surfaceContainerHighest,
                    valueColor: const AlwaysStoppedAnimation(AppColors.focused),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Text(
            '${elapsed.inMinutes.toString().padLeft(2, '0')}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}',
            style: const TextStyle(fontFamily: 'Consolas', fontSize: 14, color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  // ── Sidebar ──────────────────────────────────────────────

  Widget _buildSidebar(Topic topic) {
    return Container(
      width: 220,
      color: AppColors.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(topic.subject.toUpperCase(),
                    style: TextStyle(fontFamily: 'Consolas', fontSize: 9,
                        fontWeight: FontWeight.w700, letterSpacing: 2.0,
                        color: AppColors.outline.withValues(alpha: 0.6))),
                const SizedBox(height: 4),
                Text(topic.name,
                    style: const TextStyle(fontFamily: 'Segoe UI', fontSize: 14,
                        fontWeight: FontWeight.w600, color: AppColors.onSurface)),
              ],
            ),
          ),
          // Progress bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: (_unlockedUpTo + (_checkpointCompleted.containsKey(_unlockedUpTo) ? 1 : 0)) / topic.sections.length,
                backgroundColor: AppColors.surfaceContainerHighest,
                valueColor: const AlwaysStoppedAnimation(AppColors.focused),
                minHeight: 4,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Section list
          Expanded(
            child: ListView.builder(
              itemCount: topic.sections.length,
              padding: EdgeInsets.zero,
              itemBuilder: (_, i) {
                final s = topic.sections[i];
                final isActive = i == _currentSectionIndex;
                final isLocked = i > _unlockedUpTo;
                final isCompleted = _checkpointCompleted.containsKey(i);

                return InkWell(
                  onTap: isLocked ? null : () => _goToSection(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.secondaryContainer.withValues(alpha: 0.2)
                          : Colors.transparent,
                      border: Border(
                        left: BorderSide(
                          color: isActive ? AppColors.primary : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Opacity(
                      opacity: isLocked ? 0.4 : 1.0,
                      child: Row(
                        children: [
                          // Status icon
                          if (isCompleted)
                            const Icon(Icons.check_circle, size: 14, color: AppColors.focused)
                          else if (isLocked)
                            const Icon(Icons.lock, size: 14, color: AppColors.outline)
                          else
                            Icon(Icons.circle_outlined, size: 14,
                                color: isActive ? AppColors.primary : AppColors.outline),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.title,
                                    style: TextStyle(
                                      fontFamily: 'Georgia', fontSize: 13,
                                      color: isActive ? AppColors.primary : AppColors.onSurfaceVariant,
                                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                                    )),
                                if (s.subtitle != null)
                                  Text(s.subtitle!,
                                      style: TextStyle(fontFamily: 'Consolas', fontSize: 9,
                                          color: AppColors.outline.withValues(alpha: 0.5))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Content ──────────────────────────────────────────────

  Widget _buildContent(Section section) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section title
            Text(section.title,
                style: const TextStyle(fontFamily: 'Georgia', fontSize: 28,
                    fontWeight: FontWeight.w600, color: AppColors.onSurface, height: 1.3)),
            if (section.subtitle != null) ...[
              const SizedBox(height: 4),
              Text(section.subtitle!,
                  style: TextStyle(fontFamily: 'Consolas', fontSize: 11,
                      color: AppColors.outline.withValues(alpha: 0.6))),
            ],
            const SizedBox(height: 28),

            // Paragraphs
            ...section.paragraphs.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Text(p,
                      style: const TextStyle(fontFamily: 'Georgia', fontSize: 16,
                          color: AppColors.onSurfaceVariant, height: 1.8, letterSpacing: 0.2)),
                )),

            // Key terms
            if (section.keyTerms.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: section.keyTerms.map((t) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(t, style: const TextStyle(fontFamily: 'Segoe UI',
                          fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.primary)),
                    )).toList(),
              ),
              const SizedBox(height: 24),
            ],

            // Diagram
            if (section.diagram != null) _buildDiagram(section.diagram!),

            // Video
            if (section.video != null) _buildVideo(section.video!),

            // Callout
            if (section.callout != null) _buildCallout(section.callout!),

            // Checkpoint
            if (section.checkpoint != null) _buildCheckpoint(section.checkpoint!),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagram(DiagramSpec diagram) {
    return Container(
      margin: const EdgeInsets.only(bottom: 28),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schema, size: 16, color: AppColors.primary.withValues(alpha: 0.7)),
              const SizedBox(width: 8),
              Text('DIAGRAM', style: TextStyle(fontFamily: 'Consolas', fontSize: 10,
                  fontWeight: FontWeight.w700, letterSpacing: 3.0, color: AppColors.outline)),
            ],
          ),
          const SizedBox(height: 12),
          Text(diagram.title, style: const TextStyle(fontFamily: 'Segoe UI',
              fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
          const SizedBox(height: 16),

          // Render diagram by type
          _buildDiagramWidget(diagram.type),

          const SizedBox(height: 12),
          Text(diagram.description, style: TextStyle(fontFamily: 'Georgia',
              fontSize: 13, color: AppColors.onSurfaceVariant.withValues(alpha: 0.7), height: 1.5)),
          if (diagram.interactiveHint != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.touch_app, size: 14, color: AppColors.primary.withValues(alpha: 0.5)),
                const SizedBox(width: 6),
                Text(diagram.interactiveHint!, style: TextStyle(fontFamily: 'Consolas',
                    fontSize: 10, fontStyle: FontStyle.italic, color: AppColors.primary.withValues(alpha: 0.5))),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDiagramWidget(String type) {
    switch (type) {
      case 'periodic_table':
        return const PeriodicTableDiagram();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildVideo(VideoEmbed video) {
    return _InlineYouTubePlayer(
      key: ValueKey('${video.youtubeId}_${video.startTime}_${video.endTime}'),
      video: video,
    );
  }

  Widget _buildCallout(CalloutBox callout) {
    final Color accentColor;
    final IconData icon;
    final String label;
    switch (callout.type) {
      case 'did_you_know':
        accentColor = AppColors.tertiary; icon = Icons.lightbulb; label = 'DID YOU KNOW?';
      case 'real_world':
        accentColor = AppColors.focused; icon = Icons.public; label = 'REAL WORLD';
      case 'remember':
        accentColor = AppColors.primary; icon = Icons.bookmark; label = 'REMEMBER THIS';
      case 'common_mistake':
        accentColor = AppColors.lost; icon = Icons.warning_amber; label = 'COMMON MISTAKE';
      default:
        accentColor = AppColors.primary; icon = Icons.info; label = 'NOTE';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 28),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border(left: BorderSide(color: accentColor, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accentColor),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontFamily: 'Consolas', fontSize: 10,
                  fontWeight: FontWeight.w700, letterSpacing: 3.0, color: accentColor)),
            ],
          ),
          const SizedBox(height: 12),
          Text(callout.content, style: TextStyle(fontFamily: 'Georgia',
              fontSize: 15, color: AppColors.onSurface.withValues(alpha: 0.9), height: 1.6)),
        ],
      ),
    );
  }

  Widget _buildCheckpoint(Checkpoint cp) {
    final answered = _selectedOption != null;
    final completed = _checkpointCompleted.containsKey(_currentSectionIndex);

    return Container(
      margin: const EdgeInsets.only(bottom: 28),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: completed ? AppColors.focused.withValues(alpha: 0.3) : AppColors.outlineVariant.withValues(alpha: 0.2),
          width: completed ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(completed ? Icons.check_circle : Icons.quiz, size: 16,
                  color: completed ? AppColors.focused : AppColors.primary),
              const SizedBox(width: 8),
              Text(completed ? 'CHECKPOINT COMPLETE' : 'QUICK CHECK',
                  style: TextStyle(fontFamily: 'Consolas', fontSize: 10,
                      fontWeight: FontWeight.w700, letterSpacing: 3.0,
                      color: completed ? AppColors.focused : AppColors.outline)),
            ],
          ),
          const SizedBox(height: 16),
          Text(cp.question, style: const TextStyle(fontFamily: 'Georgia',
              fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.onSurface, height: 1.4)),
          const SizedBox(height: 16),
          // Options
          ...List.generate(cp.options.length, (i) {
            final isSelected = _selectedOption == i;
            final isCorrect = i == cp.correctIndex;
            Color optionColor = AppColors.surfaceContainerLow;
            Color textColor = AppColors.onSurfaceVariant;

            if (answered) {
              if (isCorrect) {
                optionColor = AppColors.focused.withValues(alpha: 0.15);
                textColor = AppColors.focused;
              } else if (isSelected && !_checkpointCorrect!) {
                optionColor = AppColors.lost.withValues(alpha: 0.15);
                textColor = AppColors.lost;
              }
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: optionColor,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                child: InkWell(
                  onTap: answered && _checkpointCorrect! ? null : () => _onCheckpointAnswer(i),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        if (answered && isCorrect)
                          const Icon(Icons.check_circle, size: 18, color: AppColors.focused)
                        else if (answered && isSelected)
                          const Icon(Icons.cancel, size: 18, color: AppColors.lost)
                        else
                          Icon(Icons.radio_button_unchecked, size: 18,
                              color: AppColors.outline.withValues(alpha: 0.4)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(cp.options[i], style: TextStyle(
                              fontFamily: 'Georgia', fontSize: 14, color: textColor)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          // Feedback
          if (answered) ...[
            const SizedBox(height: 12),
            Text(
              _checkpointCorrect! ? cp.onCorrect : cp.onWrong,
              style: TextStyle(
                fontFamily: 'Georgia', fontSize: 14, fontStyle: FontStyle.italic,
                color: _checkpointCorrect! ? AppColors.focused : AppColors.drifting,
                height: 1.5,
              ),
            ),
          ],
          // Next section button (after correct answer)
          if (completed) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _nextSection,
              child: Text(
                _currentSectionIndex < (_topic?.sections.length ?? 1) - 1
                    ? 'CONTINUE TO NEXT SECTION'
                    : 'COMPLETE LESSON',
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Pause Overlay ────────────────────────────────────────

  Widget _buildPauseOverlay(Section section) {
    return AnimatedBuilder(
      animation: _pauseAnim,
      builder: (_, __) => Opacity(
        opacity: _pauseAnim.value,
        child: Container(
          color: AppColors.surface.withValues(alpha: 0.9),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _currentLevel == AttentionLevel.lost ? Icons.warning_amber : Icons.pause_circle_outline,
                  size: 64,
                  color: _currentLevel == AttentionLevel.lost ? AppColors.lost : AppColors.drifting,
                ),
                const SizedBox(height: 20),
                Text(
                  _currentLevel == AttentionLevel.lost ? 'FOCUS LOST' : 'ATTENTION DRIFTING',
                  style: TextStyle(fontFamily: 'Consolas', fontSize: 18, fontWeight: FontWeight.w700,
                      letterSpacing: 3.0,
                      color: _currentLevel == AttentionLevel.lost ? AppColors.lost : AppColors.drifting),
                ),
                const SizedBox(height: 10),
                const Text('Content paused. Refocus to continue.',
                    style: TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic,
                        fontSize: 16, color: AppColors.onSurfaceVariant)),
                const SizedBox(height: 6),
                Text('Drifting for $_driftSeconds seconds',
                    style: const TextStyle(fontFamily: 'Consolas', fontSize: 12, color: AppColors.outline)),
                if (section.recapOnReturn != null) ...[
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Text(section.recapOnReturn!,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: 'Georgia', fontSize: 14,
                            fontStyle: FontStyle.italic, color: AppColors.primary.withValues(alpha: 0.7))),
                  ),
                ],
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: _onFocusRecovered,
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.outlineVariant)),
                  child: const Text('RESUME MANUALLY',
                      style: TextStyle(fontFamily: 'Segoe UI', fontSize: 12,
                          fontWeight: FontWeight.w600, letterSpacing: 2.0, color: AppColors.outline)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// ============================================================
// Inline YouTube player — shows the thumbnail as a click-to-play
// poster, then mounts an embedded iframe in the same area. No
// external window. startTime/endTime on VideoEmbed are NOT passed
// to the player — they are drift-trigger markers the pacing engine
// uses elsewhere — so the student can watch the full video freely.
// ============================================================

class _InlineYouTubePlayer extends StatefulWidget {
  final VideoEmbed video;
  const _InlineYouTubePlayer({super.key, required this.video});

  @override
  State<_InlineYouTubePlayer> createState() => _InlineYouTubePlayerState();
}

class _InlineYouTubePlayerState extends State<_InlineYouTubePlayer> {
  YoutubePlayerController? _controller;
  bool _isPlaying = false;

  void _beginPlayback() {
    setState(() {
      _controller = YoutubePlayerController(
        params: const YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
          strictRelatedVideos: true,
          showVideoAnnotations: false,
          enableCaption: false,
        ),
      )..loadVideoById(videoId: widget.video.youtubeId);
      _isPlaying = true;
    });
  }

  @override
  void dispose() {
    _controller?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 28),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.25)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _isPlaying && _controller != null
                ? YoutubePlayer(controller: _controller!, aspectRatio: 16 / 9)
                : _Thumbnail(
                    youtubeId: widget.video.youtubeId,
                    duration: widget.video.duration,
                    onPlay: _beginPlayback,
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.play_circle,
                        size: 14, color: AppColors.tertiary.withValues(alpha: 0.85)),
                    const SizedBox(width: 6),
                    const Text('VIDEO',
                        style: TextStyle(
                          fontFamily: 'Consolas',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3.0,
                          color: AppColors.outline,
                        )),
                    const Spacer(),
                    // Drift-trigger window — shown for reference, not
                    // applied to playback.
                    Icon(Icons.bolt,
                        size: 10,
                        color: AppColors.tertiary.withValues(alpha: 0.7)),
                    const SizedBox(width: 4),
                    Text(
                      'DRIFT WINDOW · ${widget.video.startTime} → ${widget.video.endTime}',
                      style: TextStyle(
                        fontFamily: 'Consolas',
                        fontSize: 10,
                        letterSpacing: 1.5,
                        color: AppColors.outline.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(widget.video.title,
                    style: const TextStyle(
                      fontFamily: 'Segoe UI',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface,
                    )),
                if (widget.video.description != null) ...[
                  const SizedBox(height: 4),
                  Text(widget.video.description!,
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 13,
                        color: AppColors.onSurfaceVariant.withValues(alpha: 0.75),
                      )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Click-to-play thumbnail poster. Shows YouTube's hqdefault image with
/// a cyan play button and a duration badge. On tap, the parent swaps in
/// the live iframe player.
class _Thumbnail extends StatelessWidget {
  final String youtubeId;
  final String duration;
  final VoidCallback onPlay;

  const _Thumbnail({
    required this.youtubeId,
    required this.duration,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final thumbUrl = 'https://img.youtube.com/vi/$youtubeId/hqdefault.jpg';
    return GestureDetector(
      onTap: onPlay,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Thumbnail image — falls back to a filler icon if the image
          // network request fails (e.g., offline).
          Positioned.fill(
            child: Image.network(
              thumbUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: AppColors.surfaceContainerLowest,
                child: const Center(
                  child: Icon(Icons.play_circle_outline,
                      size: 64, color: AppColors.outline),
                ),
              ),
            ),
          ),
          // Dark vignette so the play button reads cleanly.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.10),
                    Colors.black.withValues(alpha: 0.45),
                  ],
                ),
              ),
            ),
          ),
          // Cyan play button with glow.
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppColors.tertiary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentGlowStrong,
                  blurRadius: 32,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.play_arrow,
                size: 40, color: AppColors.onTertiary),
          ),
          // Duration badge, bottom-right.
          Positioned(
            bottom: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: AppColors.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                duration,
                style: const TextStyle(
                  fontFamily: 'Consolas',
                  fontSize: 11,
                  letterSpacing: 0.5,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
