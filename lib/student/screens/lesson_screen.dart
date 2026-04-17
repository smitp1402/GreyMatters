// lib/student/screens/lesson_screen.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
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

  // Debug
  bool _debugExpanded = false;
  bool _eegDebugVisible = false;

  // Latest state + rolling buffer of readings (parallel to _recentScores) for
  // the EEG debug overlay: shows ratio + verdict per window.
  AttentionState? _latestState;
  final List<AttentionState> _recentReadings = [];

  // Session
  final _sessionStart = DateTime.now();
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

  // Drift trigger (new rule):
  //   1. Keep the last 10 seconds of focus scores (1Hz broadcast → 10 values).
  //   2. Each tick, compute the rolling 10s average.
  //   3. Classify that average against the daemon's lost_threshold.
  //   4. If the average stays in the Lost zone for 20 consecutive seconds,
  //      switch content (launch an intervention).
  //   5. Any tick where the average is NOT in Lost resets the counter.
  //
  // This replaces the old "5 of 10 drift labels + 4s confirm" rule. Drifting
  // no longer triggers anything — only sustained Lost on the smoothed average.
  static const int _driftWindowSize = 10;
  static const int _sustainedLostThresholdSec = 20;
  final List<double> _recentScores = [];
  int _lostStreakSeconds = 0;

  void _startPacingEngine() {
    _attentionSub = AttentionStream.instance.stream.listen((state) {
      if (!mounted) return;
      _currentLevel = state.level;
      _latestState = state;

      // Broadcast to Supabase Realtime for teacher monitoring (always on).
      SessionManager.instance.onAttentionState(state);

      // Drift detection runs only during session content, not during an
      // active intervention activity. The activity has its own UI flow and
      // EEG readings there shouldn't feed the pacing engine.
      if (_showingIntervention) {
        if (_eegDebugVisible) setState(() {});
        return;
      }

      // Rolling window of focus scores (1Hz → 10 entries = 10 seconds).
      _recentScores.add(state.focusScore);
      _recentReadings.add(state);
      if (_recentScores.length > _driftWindowSize) {
        _recentScores.removeAt(0);
        _recentReadings.removeAt(0);
      }

      // Need a full window before the classifier can fire.
      if (_recentScores.length < _driftWindowSize) {
        if (_eegDebugVisible) setState(() {});
        return;
      }

      final avg = _recentScores.reduce((a, b) => a + b) / _recentScores.length;
      final inLost = avg < state.lostThreshold;

      if (inLost) {
        _lostStreakSeconds++;
        if (!_paused && _lostStreakSeconds >= _sustainedLostThresholdSec) {
          _onSustainedLost();
        }
      } else {
        _lostStreakSeconds = 0;
        if (_paused) _onFocusRecovered();
      }

      if (_eegDebugVisible) setState(() {});
    });
  }

  void _onSustainedLost() {
    if (_paused) return;
    setState(() {
      _paused = true;
      _driftSeconds = _lostStreakSeconds;
    });
    _pauseAnim.forward();
    _launchIntervention();
  }

  void _launchIntervention() {
    _interventionEngine.start(
      driftDurationSec: _driftSeconds,
      topicId: widget.topicId,
      subject: _topic?.subject ?? '',
    );
    final format = _interventionEngine.selectNextFormat();
    setState(() { _showingIntervention = true; _currentFormat = format; });
  }

  void _onInterventionComplete() {
    final recovered = _currentLevel == AttentionLevel.focused;
    _interventionEngine.reportResult(_currentFormat!, recovered);
    if (!recovered && _interventionEngine.hasMoreFormats) {
      final next = _interventionEngine.selectNextFormat();
      setState(() => _currentFormat = next);
    } else {
      _onFocusRecovered();
    }
  }

  void _onFocusRecovered() {
    _driftTimer?.cancel();
    _pauseAnim.reverse();
    _interventionEngine.reset();
    _recentScores.clear();
    _lostStreakSeconds = 0;
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
          if (_showingIntervention && _currentFormat != null)
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

          // Debug FAB
          _buildDebugFab(),

          // EEG debug overlay
          if (_eegDebugVisible) _buildEegDebugPanel(),
        ],
      ),
    );
  }

  // ── Debug FAB ───────────────────────────────────────────────

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

          // EEG debug toggle button
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FloatingActionButton.small(
              heroTag: 'eeg_debug_toggle',
              onPressed: () =>
                  setState(() => _eegDebugVisible = !_eegDebugVisible),
              backgroundColor: _eegDebugVisible
                  ? AppColors.focused
                  : AppColors.surfaceContainerHighest,
              foregroundColor: _eegDebugVisible
                  ? AppColors.onPrimary
                  : AppColors.outline,
              child: Icon(
                _eegDebugVisible ? Icons.waves : Icons.graphic_eq,
                size: 18,
              ),
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

  // ── EEG Debug Panel ──────────────────────────────────────
  //
  // Lives behind the EEG toggle FAB. Shows, per-window:
  //   • the β/(α+θ) ratio that produced the verdict
  //   • the level (focused / drifting / lost) as a coloured chip
  //   • thresholds from calibration, so you can eyeball why each
  //     window was classified the way it was
  // Plus aggregate drift count vs confirm threshold and the
  // "will trigger?" verdict that decides whether an intervention fires.

  Widget _buildEegDebugPanel() {
    final state = _latestState;
    final windowAvg = _recentScores.isEmpty
        ? null
        : _recentScores.reduce((a, b) => a + b) / _recentScores.length;
    final avgInLost =
        windowAvg != null && state != null && windowAvg < state.lostThreshold;
    final willTrigger = _lostStreakSeconds >= _sustainedLostThresholdSec;

    return Positioned(
      left: 16,
      bottom: 16,
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: AppColors.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.graphic_eq, size: 14, color: AppColors.focused),
                const SizedBox(width: 8),
                const Text(
                  'EEG DEBUG',
                  style: TextStyle(
                    fontFamily: 'Consolas',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.0,
                    color: AppColors.focused,
                  ),
                ),
                const Spacer(),
                Text(
                  _levelLabel(_currentLevel),
                  style: TextStyle(
                    fontFamily: 'Consolas',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: _levelColor(_currentLevel),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Focus score with horizontal bar (compact view)
            _buildFocusScoreBar(state),
            const SizedBox(height: 10),

            // B/T and T/A ratios (compact)
            _debugKV('B/T RATIO',
                state == null ? '—' : state.betaTheta.toStringAsFixed(3)),
            _debugKV('T/A RATIO',
                state == null ? '—' : state.thetaAlpha.toStringAsFixed(3)),
            const SizedBox(height: 10),

            // 5-band mini strip: d, t, a, b, g
            _buildBandStrip(state),
            const SizedBox(height: 10),

            // Detailed ratio + thresholds (kept from original)
            _debugKV('RATIO β/(α+θ)',
                state == null ? '—' : state.betaAlphaTheta.toStringAsFixed(3)),
            _debugKV('ALPHA (8-12 Hz)',
                state == null ? '—' : state.alpha.toStringAsFixed(3)),
            _debugKV('BETA  (12-30 Hz)',
                state == null ? '—' : state.beta.toStringAsFixed(3)),
            _debugKV('THETA (4-8 Hz)',
                state == null ? '—' : state.theta.toStringAsFixed(3)),
            _debugKV(
              'THRESHOLDS',
              state == null
                  ? '—'
                  : 'F≥${state.focusedThreshold.toStringAsFixed(2)}  '
                      'L<${state.lostThreshold.toStringAsFixed(2)}',
            ),
            _debugKV('BASELINE',
                state == null ? '—' : state.baselineRatio.toStringAsFixed(3)),

            const SizedBox(height: 10),
            Text(
              'ROLLING WINDOW [${_recentScores.length}/$_driftWindowSize]',
              style: TextStyle(
                fontFamily: 'Consolas',
                fontSize: 9,
                letterSpacing: 2.0,
                color: AppColors.outline.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 6),

            // Compact squares strip (visual summary, like image 2)
            _buildWindowSquares(),
            const SizedBox(height: 8),

            // Per-window ratio + verdict (detailed, oldest → newest)
            _buildWindowChips(),

            const SizedBox(height: 10),
            _debugKV(
              'WINDOW AVG',
              windowAvg == null ? '—' : windowAvg.toStringAsFixed(3),
              valueColor: avgInLost ? AppColors.lost : AppColors.onSurface,
            ),
            _debugKV(
              'LOST STREAK',
              '${_lostStreakSeconds}s / ${_sustainedLostThresholdSec}s',
            ),
            _debugKV(
              'INTERVENTION',
              _showingIntervention && _currentFormat != null
                  ? _currentFormat!.toUpperCase()
                  : 'none',
              valueColor: _showingIntervention
                  ? AppColors.drifting
                  : AppColors.onSurface,
            ),
            _debugKV(
              'WILL TRIGGER?',
              willTrigger
                  ? 'YES — avg in Lost for ${_sustainedLostThresholdSec}s'
                  : 'NO — need ${_sustainedLostThresholdSec - _lostStreakSeconds}s more',
              valueColor: willTrigger ? AppColors.lost : AppColors.focused,
            ),
          ],
        ),
      ),
    );
  }

  Widget _debugKV(String k, String v, {Color? valueColor}) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Text(
              k,
              style: TextStyle(
                fontFamily: 'Consolas',
                fontSize: 10,
                letterSpacing: 1.5,
                color: AppColors.outline.withValues(alpha: 0.7),
              ),
            ),
            const Spacer(),
            Text(
              v,
              style: TextStyle(
                fontFamily: 'Consolas',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: valueColor ?? AppColors.onSurface,
              ),
            ),
          ],
        ),
      );

  // Focus score % + big horizontal bar (compact view, from image 2).
  Widget _buildFocusScoreBar(AttentionState? s) {
    final score = s?.focusScore ?? 0;
    final pct = (score * 100).round();
    final color = _levelColor(_currentLevel);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'FOCUS SCORE',
              style: TextStyle(
                fontFamily: 'Consolas',
                fontSize: 10,
                letterSpacing: 1.5,
                color: AppColors.outline.withValues(alpha: 0.7),
              ),
            ),
            const Spacer(),
            Text(
              s == null ? '—' : '$pct%',
              style: const TextStyle(
                fontFamily: 'Consolas',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 10,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: score),
              duration: const Duration(milliseconds: 400),
              builder: (_, v, __) => LinearProgressIndicator(
                value: v.clamp(0.0, 1.0),
                backgroundColor: AppColors.surfaceContainerLowest,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 5-band mini strip: d, t, a, b, g (compact view, from image 2).
  Widget _buildBandStrip(AttentionState? s) {
    final entries = [
      ('d', s?.delta ?? 0, AppColors.delta),
      ('t', s?.theta ?? 0, AppColors.theta),
      ('a', s?.alpha ?? 0, AppColors.alpha),
      ('b', s?.beta ?? 0, AppColors.beta),
      ('g', s?.gamma ?? 0, AppColors.gamma),
    ];
    final maxVal = entries.map((e) => e.$2).fold<double>(1e-6, (m, v) => v > m ? v : m);
    return Row(
      children: entries.map((e) {
        final label = e.$1;
        final val = e.$2;
        final color = e.$3;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Consolas',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: SizedBox(
                    height: 6,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: val / maxVal),
                      duration: const Duration(milliseconds: 400),
                      builder: (_, v, __) => LinearProgressIndicator(
                        value: v.clamp(0.0, 1.0),
                        backgroundColor: AppColors.surfaceContainerLowest,
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  s == null ? '—' : val.toStringAsFixed(2),
                  style: TextStyle(
                    fontFamily: 'Consolas',
                    fontSize: 10,
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // Small colored squares — one per window slot (compact view).
  // Each slot is classified independently against the daemon's thresholds so
  // the strip is a visual aid; actual trigger decisions use the average.
  Widget _buildWindowSquares() {
    final state = _latestState;
    return Row(
      children: List.generate(_driftWindowSize, (i) {
        final filled = i < _recentScores.length;
        final level = (filled && state != null)
            ? _classifyScore(_recentScores[i], state)
            : null;
        final color =
            level != null ? _levelColor(level) : AppColors.outline;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Container(
              height: 20,
              decoration: BoxDecoration(
                color: filled ? color.withValues(alpha: 0.25) : Colors.transparent,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: color.withValues(alpha: filled ? 0.7 : 0.2),
                  width: 1.5,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  AttentionLevel _classifyScore(double score, AttentionState state) {
    if (score < state.lostThreshold) return AttentionLevel.lost;
    if (score >= state.focusedThreshold) return AttentionLevel.focused;
    return AttentionLevel.drifting;
  }

  Widget _buildWindowChips() {
    if (_recentReadings.isEmpty) {
      return Text(
        'waiting for stream…',
        style: TextStyle(
          fontFamily: 'Consolas',
          fontSize: 10,
          color: AppColors.outline.withValues(alpha: 0.5),
        ),
      );
    }

    final labelStyle = TextStyle(
      fontFamily: 'Consolas',
      fontSize: 9,
      letterSpacing: 1.2,
      color: AppColors.outline.withValues(alpha: 0.6),
    );

    // Label column on the left — metric names stacked vertically.
    final labelColumn = Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(height: 14, child: Text('#', style: labelStyle)),
          SizedBox(height: 16, child: Text('β/(α+θ)', style: labelStyle)),
          SizedBox(height: 14, child: Text('α', style: labelStyle)),
          SizedBox(height: 14, child: Text('β', style: labelStyle)),
          SizedBox(height: 14, child: Text('θ', style: labelStyle)),
          SizedBox(height: 18, child: Text('STATE', style: labelStyle)),
        ],
      ),
    );

    // One column per reading (#1 leftmost → #N rightmost).
    final slotColumns = <Widget>[
      for (int i = 0; i < _recentReadings.length; i++)
        Expanded(child: _buildWindowSlot(i, _recentReadings[i])),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        labelColumn,
        Expanded(child: Row(children: slotColumns)),
      ],
    );
  }

  Widget _buildWindowSlot(int index, AttentionState r) {
    final color = _levelColor(r.level);
    final bandStyle = TextStyle(
      fontFamily: 'Consolas',
      fontSize: 9,
      color: AppColors.onSurfaceVariant.withValues(alpha: 0.85),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Column(
        children: [
          SizedBox(
            height: 14,
            child: Text(
              '#${index + 1}',
              style: TextStyle(
                fontFamily: 'Consolas',
                fontSize: 9,
                color: AppColors.outline.withValues(alpha: 0.5),
              ),
            ),
          ),
          SizedBox(
            height: 16,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                r.betaAlphaTheta.toStringAsFixed(2),
                style: const TextStyle(
                  fontFamily: 'Consolas',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 14,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(r.alpha.toStringAsFixed(2), style: bandStyle),
            ),
          ),
          SizedBox(
            height: 14,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(r.beta.toStringAsFixed(2), style: bandStyle),
            ),
          ),
          SizedBox(
            height: 14,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(r.theta.toStringAsFixed(2), style: bandStyle),
            ),
          ),
          SizedBox(
            height: 18,
            child: Container(
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: color.withValues(alpha: 0.4)),
              ),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(
                      _levelLabel(r.level).substring(0, 3),
                      style: TextStyle(
                        fontFamily: 'Consolas',
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _levelLabel(AttentionLevel l) => switch (l) {
        AttentionLevel.focused => 'FOCUSED',
        AttentionLevel.drifting => 'DRIFTING',
        AttentionLevel.lost => 'LOST',
      };

  Color _levelColor(AttentionLevel l) => switch (l) {
        AttentionLevel.focused => AppColors.focused,
        AttentionLevel.drifting => AppColors.drifting,
        AttentionLevel.lost => AppColors.lost,
      };

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
    // Parse start time to seconds for YouTube URL
    final startParts = video.startTime.split(':');
    final startSec = startParts.length == 2
        ? int.tryParse(startParts[0])! * 60 + int.tryParse(startParts[1])!
        : 0;
    final youtubeUrl = 'https://www.youtube.com/watch?v=${video.youtubeId}&t=${startSec}s';
    final thumbUrl = 'https://img.youtube.com/vi/${video.youtubeId}/hqdefault.jpg';

    return Container(
      margin: const EdgeInsets.only(bottom: 28),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // YouTube thumbnail with play button
          GestureDetector(
            onTap: () => launchUrl(Uri.parse(youtubeUrl), mode: LaunchMode.externalApplication),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Thumbnail
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    thumbUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.surfaceContainerLowest,
                      child: const Center(
                        child: Icon(Icons.play_circle_outline, size: 64, color: AppColors.outline),
                      ),
                    ),
                  ),
                ),
                // Play button overlay
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.lost.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 12),
                    ],
                  ),
                  child: const Icon(Icons.play_arrow, size: 36, color: Colors.white),
                ),
                // Duration badge
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(video.duration,
                        style: const TextStyle(fontFamily: 'Consolas', fontSize: 11, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
          // Video info
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.play_circle, size: 14, color: AppColors.lost.withValues(alpha: 0.7)),
                    const SizedBox(width: 6),
                    Text('VIDEO', style: TextStyle(fontFamily: 'Consolas', fontSize: 10,
                        fontWeight: FontWeight.w700, letterSpacing: 3.0, color: AppColors.outline)),
                    const Spacer(),
                    Text('${video.startTime} → ${video.endTime}',
                        style: TextStyle(fontFamily: 'Consolas', fontSize: 10,
                            color: AppColors.outline.withValues(alpha: 0.5))),
                  ],
                ),
                const SizedBox(height: 8),
                Text(video.title, style: const TextStyle(fontFamily: 'Segoe UI',
                    fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
                if (video.description != null) ...[
                  const SizedBox(height: 4),
                  Text(video.description!, style: TextStyle(fontFamily: 'Georgia',
                      fontSize: 13, color: AppColors.onSurfaceVariant.withValues(alpha: 0.7))),
                ],
              ],
            ),
          ),
        ],
      ),
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

