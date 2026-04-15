// lib/student/screens/activities/synthetic_alchemist_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../../core/models/element_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

// Teal accent used throughout the cyberpunk UI
const _teal = Color(0xFF26A69A);
const _amber = Color(0xFFFFA000);
const _gridLineColor = Color(0x0ABDC1D7);

// Section-specific recap sentences from the spec
const _recaps = [
  'The elements you just tapped are in order of atomic number — the same principle Mendeleev used to build the table.',
  'Each period you crossed contains a full set of families — from the reactive alkali metal on the left to the unreactive noble gas on the right.',
  'Every step right you tapped added one proton — that is exactly why atomic radius decreases across a period.',
  'Every element you caught has the same tile structure — atomic number top left, mass bottom, symbol centre. Always the same.',
];

/// Synthetic Alchemist — falling-element game intervention.
///
/// Elements fall one at a time in atomic number order (H, He, Li...).
/// Student taps to catch each element. TTS speaks the element name.
/// 60-second time limit. Score persists across sessions.
class SyntheticAlchemistScreen extends StatefulWidget {
  final String subject;
  final String topicId;
  final int sectionIndex;
  final VoidCallback onComplete;

  const SyntheticAlchemistScreen({
    super.key,
    required this.subject,
    required this.topicId,
    required this.sectionIndex,
    required this.onComplete,
  });

  @override
  State<SyntheticAlchemistScreen> createState() =>
      _SyntheticAlchemistScreenState();
}

class _SyntheticAlchemistScreenState extends State<SyntheticAlchemistScreen>
    with SingleTickerProviderStateMixin {
  // Animation
  late final AnimationController _fallController;

  // Game state
  int _currentIndex = 0;
  int _sessionScore = 0;
  int _totalScore = 0;
  int _remainingSeconds = 60;
  bool _tapped = false;   // true during teal glow (0.3s)
  bool _missed = false;   // true during amber flash (0.3s)
  bool _gameOver = false;
  Timer? _countdownTimer;

  // TTS
  final FlutterTts _tts = FlutterTts();

  ChemicalElement get _currentElement => allElements[_currentIndex];
  ChemicalElement? get _nextElement =>
      _currentIndex + 1 < allElements.length ? allElements[_currentIndex + 1] : null;

  @override
  void initState() {
    super.initState();
    _initTts();

    _fallController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _fallController.addStatusListener(_onFallComplete);
    _fallController.forward();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remainingSeconds--);
      if (_remainingSeconds <= 0) _endGame(showRecap: true);
    });
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
  }

  void _onFallComplete(AnimationStatus status) {
    if (status != AnimationStatus.completed || _gameOver) return;
    // Element reached bottom without being tapped — miss
    setState(() => _missed = true);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted || _gameOver) return;
      setState(() => _missed = false);
      _fallController.reset();
      _fallController.forward();
    });
  }

  void _onTap() {
    if (_tapped || _missed || _gameOver) return;

    // Check if element is in the interaction zone (bottom 25%)
    if (_fallController.value < 0.75) return;

    // Correct tap
    setState(() => _tapped = true);
    _tts.speak(_currentElement.name);
    _sessionScore++;

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted || _gameOver) return;
      setState(() {
        _tapped = false;
        _currentIndex++;
      });

      if (_currentIndex >= allElements.length) {
        _endGame(showRecap: true);
        return;
      }

      _fallController.reset();
      _fallController.forward();
    });
  }

  void _endGame({bool showRecap = false}) {
    if (_gameOver) return;
    _gameOver = true;
    _countdownTimer?.cancel();
    _fallController.stop();
    _totalScore += _sessionScore;

    if (showRecap) {
      setState(() {}); // trigger rebuild to show recap
    } else {
      widget.onComplete();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _fallController.dispose();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_gameOver) return _buildRecapScreen();
    return _buildGameScreen();
  }

  // ── Game Screen ──────────────────────────────────────────

  Widget _buildGameScreen() {
    return Container(
      color: AppColors.surface,
      child: CustomPaint(
        painter: _GridPainter(),
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: Row(
                children: [
                  _buildQueuePanel(),
                  Expanded(child: _buildPlayArea()),
                  _buildInfoPanel(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top Bar ──────────────────────────────────────────────

  Widget _buildTopBar() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _teal.withValues(alpha: 0.3))),
      ),
      child: Row(
        children: [
          const Text(
            'SYNTHETIC ALCHEMIST',
            style: TextStyle(
              fontFamily: 'Consolas',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 3.0,
              color: _teal,
            ),
          ),
          const Spacer(),
          // Timer
          Text(
            '${_remainingSeconds.toString().padLeft(2, '0')}s',
            style: TextStyle(
              fontFamily: 'Consolas',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _remainingSeconds <= 10 ? AppColors.lost : AppColors.onSurface,
            ),
          ),
          const SizedBox(width: 24),
          // Score
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('SCORE',
                  style: TextStyle(fontFamily: 'Consolas', fontSize: 8,
                      letterSpacing: 2.0, color: _teal.withValues(alpha: 0.6))),
              Text(
                (_totalScore + _sessionScore).toString().padLeft(4, '0'),
                style: const TextStyle(
                  fontFamily: 'Consolas',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _teal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Queue Panel (left sidebar) ───────────────────────────

  Widget _buildQueuePanel() {
    final next = _nextElement;
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.15))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('QUEUE',
              style: TextStyle(fontFamily: 'Consolas', fontSize: 9,
                  fontWeight: FontWeight.w700, letterSpacing: 2.0,
                  color: _teal.withValues(alpha: 0.6))),
          const SizedBox(height: 12),
          if (next != null) _buildMiniTile(next),
          const SizedBox(height: 8),
          Text('NEXT',
              style: TextStyle(fontFamily: 'Consolas', fontSize: 8,
                  letterSpacing: 2.0, color: AppColors.outline.withValues(alpha: 0.5))),
        ],
      ),
    );
  }

  Widget _buildMiniTile(ChemicalElement el) {
    final color = familyColor(el.family);
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('${el.atomicNumber}',
              style: TextStyle(fontFamily: 'Consolas', fontSize: 8,
                  color: color.withValues(alpha: 0.5))),
          Text(el.symbol,
              style: TextStyle(fontFamily: 'Consolas', fontSize: 18,
                  fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  // ── Info Panel (right sidebar) ───────────────────────────

  Widget _buildInfoPanel() {
    final el = _currentElement;
    final color = familyColor(el.family);
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.15))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('CURRENT ELEMENT',
              style: TextStyle(fontFamily: 'Consolas', fontSize: 9,
                  fontWeight: FontWeight.w700, letterSpacing: 2.0,
                  color: _teal.withValues(alpha: 0.6))),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Text(el.name.toUpperCase(),
                    style: TextStyle(fontFamily: 'Consolas', fontSize: 14,
                        fontWeight: FontWeight.w700, letterSpacing: 1.5, color: color)),
                const SizedBox(height: 4),
                Text('\u00b7 ${el.atomicNumber} \u00b7',
                    style: TextStyle(fontFamily: 'Consolas', fontSize: 20,
                        fontWeight: FontWeight.w700, color: AppColors.onSurface)),
                const SizedBox(height: 4),
                Text('${el.atomicMass} amu',
                    style: TextStyle(fontFamily: 'Consolas', fontSize: 10,
                        color: AppColors.outline.withValues(alpha: 0.6))),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Session progress
          Text('THIS SESSION',
              style: TextStyle(fontFamily: 'Consolas', fontSize: 8,
                  letterSpacing: 2.0, color: AppColors.outline.withValues(alpha: 0.5))),
          const SizedBox(height: 4),
          Text('$_sessionScore',
              style: const TextStyle(fontFamily: 'Consolas', fontSize: 28,
                  fontWeight: FontWeight.w700, color: _teal)),
          Text('caught',
              style: TextStyle(fontFamily: 'Consolas', fontSize: 10,
                  color: AppColors.outline.withValues(alpha: 0.5))),
        ],
      ),
    );
  }

  // ── Play Area ────────────────────────────────────────────

  Widget _buildPlayArea() {
    return GestureDetector(
      onTap: _onTap,
      behavior: HitTestBehavior.opaque,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final areaHeight = constraints.maxHeight;
          final tileSize = 80.0;
          final interactionZoneTop = areaHeight * 0.75;

          return Stack(
            children: [
              // Interaction zone strip
              Positioned(
                left: 0,
                right: 0,
                top: interactionZoneTop,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: (_tapped ? _teal : _missed ? _amber : _teal).withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    color: (_tapped ? _teal : _missed ? _amber : _teal).withValues(alpha: 0.04),
                  ),
                  child: Center(
                    child: Text(
                      'INTERACTION_ZONE_ACTIVE',
                      style: TextStyle(
                        fontFamily: 'Consolas',
                        fontSize: 9,
                        letterSpacing: 3.0,
                        color: _teal.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
              ),

              // Falling element tile
              AnimatedBuilder(
                animation: _fallController,
                builder: (_, __) {
                  final top = _fallController.value * (areaHeight - tileSize);
                  return Positioned(
                    top: top,
                    left: (constraints.maxWidth - tileSize) / 2,
                    child: _buildFallingTile(tileSize),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFallingTile(double size) {
    final el = _currentElement;
    final color = familyColor(el.family);

    Color borderColor;
    List<BoxShadow>? shadows;
    if (_tapped) {
      borderColor = _teal;
      shadows = [BoxShadow(color: _teal.withValues(alpha: 0.5), blurRadius: 20)];
    } else if (_missed) {
      borderColor = _amber;
      shadows = [BoxShadow(color: _amber.withValues(alpha: 0.3), blurRadius: 12)];
    } else {
      borderColor = color;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: shadows,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Top row: atomic number + atomic mass
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${el.atomicNumber}',
                    style: TextStyle(fontFamily: 'Consolas', fontSize: 8,
                        color: color.withValues(alpha: 0.6))),
                Text('${el.atomicMass}',
                    style: TextStyle(fontFamily: 'Consolas', fontSize: 7,
                        color: AppColors.outline.withValues(alpha: 0.4))),
              ],
            ),
          ),
          // Symbol (large, center)
          Text(el.symbol,
              style: TextStyle(fontFamily: 'Consolas', fontSize: 24,
                  fontWeight: FontWeight.w700, color: color)),
          // Name (small, bottom)
          Text(el.name.toUpperCase(),
              style: TextStyle(fontFamily: 'Consolas', fontSize: 6,
                  letterSpacing: 1.0, color: color.withValues(alpha: 0.6))),
        ],
      ),
    );
  }

  // ── Recap Screen ─────────────────────────────────────────

  Widget _buildRecapScreen() {
    final recap = widget.sectionIndex < _recaps.length
        ? _recaps[widget.sectionIndex]
        : _recaps[0];

    return Container(
      color: AppColors.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'SYNTHETIC ALCHEMIST',
                style: TextStyle(
                  fontFamily: 'Consolas',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3.0,
                  color: _teal,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                '$_sessionScore',
                style: const TextStyle(
                  fontFamily: 'Consolas',
                  fontSize: 64,
                  fontWeight: FontWeight.w700,
                  color: _teal,
                ),
              ),
              const Text(
                'ELEMENTS CAUGHT',
                style: TextStyle(
                  fontFamily: 'Consolas',
                  fontSize: 11,
                  letterSpacing: 3.0,
                  color: AppColors.outline,
                ),
              ),
              const SizedBox(height: 24),
              // Recap sentence
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Text(
                  recap,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                    color: AppColors.onSurfaceVariant,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: widget.onComplete,
                child: const Text('RETURN TO LESSON'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Grid Background Painter ────────────────────────────────

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _gridLineColor
      ..strokeWidth = 0.5;

    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
