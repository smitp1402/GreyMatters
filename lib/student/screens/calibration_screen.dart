// lib/student/screens/calibration_screen.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/services/websocket_client.dart';

/// Screen 3 — 30-second baseline calibration.
///
/// Student focuses on a fixation dot while the daemon records EEG and
/// computes their personal baseline_index. Matches Stitch calibration design.
class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({super.key});

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

enum _CalibrationPhase { preparing, recording, complete }

class _CalibrationScreenState extends State<CalibrationScreen>
    with TickerProviderStateMixin {
  static const _duration = 30; // seconds

  _CalibrationPhase _phase = _CalibrationPhase.preparing;
  int _secondsRemaining = _duration;
  Timer? _timer;
  double _baselineValue = 1.0;

  late final AnimationController _dotPulse;
  late final AnimationController _ringExpand;
  late final AnimationController _completeAnim;
  final FlutterTts _tts = FlutterTts();

  @override
  void initState() {
    super.initState();

    _dotPulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _ringExpand = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _duration),
    );

    _completeAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _initTts();
    // Don't auto-start — show preparation screen first
    _speakPrep();
  }

  Future<void> _speakPrep() async {
    await Future.delayed(const Duration(milliseconds: 500));
    await _tts.speak("Prepare for calibration. Sit comfortably and relax.");
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.4);
    await _tts.setPitch(0.8);
  }

  void _startCalibration() async {
    setState(() {
      _phase = _CalibrationPhase.recording;
      _secondsRemaining = _duration;
    });

    _ringExpand.forward();
    await _tts.speak("Focus on the dot. Breathe normally. Calibration begins now.");

    // Send calibrate command to daemon
    WebSocketClient.instance.send('{"command":"calibrate","duration":$_duration}');

    // Countdown timer
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _secondsRemaining--;
      });

      if (_secondsRemaining <= 0) {
        timer.cancel();
        _onComplete();
      }
    });
  }

  void _onComplete() async {
    setState(() {
      _phase = _CalibrationPhase.complete;
      _baselineValue = 1.0 + (Random().nextDouble() * 0.5); // simulated
    });

    _completeAnim.forward();
    await _tts.speak("Calibration complete. Baseline established.");

    // Auto-advance after 2 seconds
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      context.go('/student/session-ready');
    }
  }

  void _abort() {
    _timer?.cancel();
    _ringExpand.stop();
    context.go('/student/debug-stream');
  }

  @override
  void dispose() {
    _timer?.cancel();
    _dotPulse.dispose();
    _ringExpand.dispose();
    _completeAnim.dispose();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Row(
        children: [
          // Main calibration area
          Expanded(
            flex: 3,
            child: _buildCalibrationArea(),
          ),
          // Side panel (desktop only)
          if (isDesktop)
            SizedBox(
              width: 280,
              child: _buildSidePanel(),
            ),
        ],
      ),
    );
  }

  Widget _buildCalibrationArea() {
    if (_phase == _CalibrationPhase.preparing) {
      return _buildPreparationView();
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Timer
          if (_phase == _CalibrationPhase.recording)
            Text(
              '${(_secondsRemaining ~/ 60).toString().padLeft(2, '0')}:${(_secondsRemaining % 60).toString().padLeft(2, '0')}',
              style: const TextStyle(
                fontFamily: 'Consolas',
                fontSize: 48,
                fontWeight: FontWeight.w300,
                color: AppColors.onSurface,
                letterSpacing: 4.0,
              ),
            ),

          if (_phase == _CalibrationPhase.complete)
            AnimatedBuilder(
              animation: _completeAnim,
              builder: (_, __) => Opacity(
                opacity: _completeAnim.value,
                child: const Text(
                  'CALIBRATION COMPLETE',
                  style: TextStyle(
                    fontFamily: 'Consolas',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3.0,
                    color: AppColors.focused,
                  ),
                ),
              ),
            ),

          const SizedBox(height: 8),

          // Status label
          if (_phase == _CalibrationPhase.recording)
            const Text(
              'RECORDING BASELINE',
              style: TextStyle(
                fontFamily: 'Consolas',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 3.0,
                color: AppColors.outline,
              ),
            ),

          const SizedBox(height: 40),

          // Fixation dot with progress ring
          SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Progress ring
                if (_phase == _CalibrationPhase.recording)
                  AnimatedBuilder(
                    animation: _ringExpand,
                    builder: (_, __) => SizedBox(
                      width: 180,
                      height: 180,
                      child: CircularProgressIndicator(
                        value: _ringExpand.value,
                        strokeWidth: 2,
                        backgroundColor: AppColors.outlineVariant.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                  ),

                // Expanding concentric rings
                if (_phase == _CalibrationPhase.recording)
                  AnimatedBuilder(
                    animation: _ringExpand,
                    builder: (_, __) {
                      final rings = <Widget>[];
                      for (int i = 0; i < 3; i++) {
                        final progress = (_ringExpand.value + i * 0.15) % 1.0;
                        rings.add(
                          Container(
                            width: 40 + progress * 140,
                            height: 40 + progress * 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.1 * (1 - progress)),
                                width: 0.5,
                              ),
                            ),
                          ),
                        );
                      }
                      return Stack(alignment: Alignment.center, children: rings);
                    },
                  ),

                // Complete checkmark
                if (_phase == _CalibrationPhase.complete)
                  AnimatedBuilder(
                    animation: _completeAnim,
                    builder: (_, __) => Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.focused.withValues(alpha: 0.15 * _completeAnim.value),
                        border: Border.all(
                          color: AppColors.focused.withValues(alpha: _completeAnim.value),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.check,
                        color: AppColors.focused.withValues(alpha: _completeAnim.value),
                        size: 36,
                      ),
                    ),
                  ),

                // Center fixation dot
                if (_phase == _CalibrationPhase.recording)
                  AnimatedBuilder(
                    animation: _dotPulse,
                    builder: (_, __) => Container(
                      width: 8 + _dotPulse.value * 2,
                      height: 8 + _dotPulse.value * 2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 10 + _dotPulse.value * 8,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 48),

          // Instruction text
          if (_phase == _CalibrationPhase.recording)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                children: [
                  const Text(
                    'Focus on the center point to calibrate your\nbaseline attention.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontStyle: FontStyle.italic,
                      fontSize: 18,
                      color: AppColors.onSurface,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Maintain a relaxed gaze. Minimal blinking and physical stillness\n'
                    'will ensure the precision of the neural feedback loop.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 14,
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

          // Baseline result
          if (_phase == _CalibrationPhase.complete) ...[
            const SizedBox(height: 16),
            Text(
              'Baseline Index: ${_baselineValue.toStringAsFixed(2)}',
              style: const TextStyle(
                fontFamily: 'Consolas',
                fontSize: 14,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreparationView() {
    return Center(
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Brain icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.1),
                ),
                child: const Icon(
                  Icons.psychology,
                  size: 44,
                  color: AppColors.primary,
                ),
              ),

              const SizedBox(height: 28),

              const Text(
                'BASELINE CALIBRATION',
                style: TextStyle(
                  fontFamily: 'Consolas',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4.0,
                  color: AppColors.primary,
                ),
              ),

              const SizedBox(height: 16),

              Text(
                'We need to learn your unique brain signature',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontStyle: FontStyle.italic,
                  fontSize: 20,
                  color: AppColors.onSurface,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'Everyone\'s brain waves are different. This 30-second calibration '
                'records your personal baseline so the system can accurately detect '
                'when your focus drifts during a session.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 15,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 36),

              // Instructions
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  border: Border.all(
                    color: AppColors.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'WHAT TO DO',
                      style: TextStyle(
                        fontFamily: 'Consolas',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 3.0,
                        color: AppColors.outline,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _instructionRow(
                      Icons.chair,
                      'Sit comfortably',
                      'Keep your body still and relaxed',
                    ),
                    const SizedBox(height: 16),
                    _instructionRow(
                      Icons.visibility,
                      'Focus on the dot',
                      'A small dot will appear — gaze at it steadily',
                    ),
                    const SizedBox(height: 16),
                    _instructionRow(
                      Icons.air,
                      'Breathe normally',
                      'Don\'t hold your breath or breathe heavily',
                    ),
                    const SizedBox(height: 16),
                    _instructionRow(
                      Icons.do_not_touch,
                      'Minimize blinking',
                      'Try to blink as little as possible for 30 seconds',
                    ),
                    const SizedBox(height: 16),
                    _instructionRow(
                      Icons.timer,
                      '30 seconds',
                      'The calibration takes exactly 30 seconds',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // Begin button
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryContainer],
                  ),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _startCalibration,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 48, vertical: 20),
                      child: Text(
                        'BEGIN CALIBRATION',
                        style: TextStyle(
                          fontFamily: 'Segoe UI',
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          letterSpacing: 3.0,
                          color: AppColors.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              TextButton(
                onPressed: () => context.go('/student/session-ready'),
                child: const Text(
                  'SKIP CALIBRATION (DEV)',
                  style: TextStyle(
                    fontFamily: 'Segoe UI',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
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

  Widget _instructionRow(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Segoe UI',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 13,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSidePanel() {
    return Container(
      color: AppColors.surfaceContainerHigh,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 48),

          const Text(
            'ACTIVE PRESET',
            style: TextStyle(
              fontFamily: 'Consolas',
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.0,
              color: AppColors.outline,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Theta Wave Induction',
            style: TextStyle(
              fontFamily: 'Segoe UI',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),

          const SizedBox(height: 32),

          const Text(
            'CONFIGURATION',
            style: TextStyle(
              fontFamily: 'Consolas',
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.0,
              color: AppColors.outline,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Cognitive Sanctuary V3',
            style: TextStyle(
              fontFamily: 'Segoe UI',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface,
            ),
          ),

          const SizedBox(height: 32),

          const Text(
            'DURATION',
            style: TextStyle(
              fontFamily: 'Consolas',
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.0,
              color: AppColors.outline,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '30 seconds',
            style: TextStyle(
              fontFamily: 'Segoe UI',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface,
            ),
          ),

          const Spacer(),

          // Abort button
          if (_phase == _CalibrationPhase.recording)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _abort,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.outlineVariant),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  '✕  ABORT CALIBRATION',
                  style: TextStyle(
                    fontFamily: 'Segoe UI',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: AppColors.outline,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
