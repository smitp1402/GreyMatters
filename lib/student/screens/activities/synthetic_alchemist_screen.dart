// lib/student/screens/activities/synthetic_alchemist_screen.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/config/tts_phrase_bank.dart';
import '../../../core/models/element_data.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

// Teal accent used throughout the cyberpunk UI
const _teal = Color(0xFF26A69A);
const _amber = Color(0xFFFFA000);
const _gridLineColor = Color(0x0ABDC1D7);

// Period 1 + 2 mnemonic, indexed by atomic-number − 1 (matches allElements).
// Only the first ten elements have a word; taps on atomic numbers beyond
// this list simply leave the mnemonic bar unlit.
const _mnemonicWords = <String>[
  'Happy',   // H   — Hydrogen
  'Henry',   // He  — Helium
  'Likes',   // Li  — Lithium
  'Beer',    // Be  — Beryllium
  'But',     // B   — Boron
  'Could',   // C   — Carbon
  'Not',     // N   — Nitrogen
  'Obtain',  // O   — Oxygen
  'Food',    // F   — Fluorine
  'Nearby',  // Ne  — Neon
];

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
  /// Which element index to start from (resumes across interventions).
  final int startIndex;
  /// How many elements to tap before the activity ends.
  final int targetTaps;
  /// Called when game ends, reports how many elements were tapped total.
  final ValueChanged<int>? onProgress;

  const SyntheticAlchemistScreen({
    super.key,
    required this.subject,
    required this.topicId,
    required this.sectionIndex,
    required this.onComplete,
    this.startIndex = 0,
    this.targetTaps = 10,
    this.onProgress,
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
  late int _currentIndex;
  int _sessionScore = 0;
  int _totalScore = 0;
  int _remainingSeconds = 60;
  bool _tapped = false;   // true during teal glow (0.3s)
  bool _missed = false;   // true during amber flash (0.3s)
  bool _gameOver = false;
  Timer? _countdownTimer;
  double _dropX = 0.5; // normalized horizontal position (0.0 to 1.0)
  final _rng = Random();

  // Mnemonic highlight: which word (index into _mnemonicWords) is glowing
  // right now and in what color. −1 index means no glow. The color is
  // captured at tap time from the element's family so the word shines in
  // the same hue as the falling tile the student just caught.
  int _mnemonicGlowIndex = -1;
  Color _mnemonicGlowColor = _amber; // seeded, overwritten per tap
  Timer? _mnemonicTimer;

  // Finale: after the last mnemonic element (Neon / "Nearby") is tapped,
  // the mnemonic animates to the center of the screen while TTS reads
  // the full sentence, then we advance to the recap screen.
  bool _showingFinale = false;

  // TTS — shared prefetch service; no per-screen setup needed.
  final TtsService _tts = TtsService.instance;

  ChemicalElement get _currentElement => allElements[_currentIndex];
  ChemicalElement? get _nextElement =>
      _currentIndex + 1 < allElements.length ? allElements[_currentIndex + 1] : null;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.startIndex;

    _fallController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );
    _fallController.addStatusListener(_onFallComplete);
    _dropX = _rng.nextDouble();
    _fallController.forward();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remainingSeconds--);
      if (_remainingSeconds <= 0) _endGame(showRecap: true);
    });
  }

  void _onFallComplete(AnimationStatus status) {
    if (status != AnimationStatus.completed || _gameOver) return;
    // Element reached bottom without being tapped — miss
    setState(() => _missed = true);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted || _gameOver) return;
      setState(() {
        _missed = false;
        _dropX = _rng.nextDouble();
      });
      _fallController.reset();
      _fallController.forward();
    });
  }

  void _onTap() {
    if (_tapped || _missed || _gameOver || _showingFinale) return;

    // Element is clickable anywhere during its fall

    // Remember whether this tap covers the final mnemonic word ("Nearby" /
    // Neon / atomic #10). Captured BEFORE the async increment so the
    // post-delay branch knows to run the finale instead of the normal
    // recap path.
    final isFinalMnemonicElement =
        _currentIndex == _mnemonicWords.length - 1;

    // Correct tap — play the pre-fetched element audio by atomic symbol.
    // Cache miss falls back to flutter_tts inside TtsService. The final
    // mnemonic element handles its own TTS sequencing (awaits completion
    // before the finale overlay) so we skip the fire-and-forget speak
    // here in that branch.
    setState(() => _tapped = true);
    if (!isFinalMnemonicElement) {
      _tts.speak(TtsPhraseBank.element(_currentElement.symbol));
    }
    _sessionScore++;

    // Light up the matching mnemonic word in the color of the element's
    // family so the word shares the hue of the tile the student caught.
    // Guarded against out-of-range so taps on elements beyond Neon
    // (atomic # 10) don't crash.
    if (_currentIndex < _mnemonicWords.length) {
      _mnemonicTimer?.cancel();
      setState(() {
        _mnemonicGlowIndex = _currentIndex;
        _mnemonicGlowColor = familyColor(_currentElement.family);
      });
      _mnemonicTimer = Timer(const Duration(milliseconds: 1800), () {
        if (!mounted) return;
        setState(() => _mnemonicGlowIndex = -1);
      });
    }

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted || _gameOver) return;
      setState(() {
        _tapped = false;
        _currentIndex++;
        _dropX = _rng.nextDouble();
      });

      // When the student completes the period 1+2 mnemonic (just tapped
      // "Nearby" / Neon), run the centered-mnemonic finale instead of
      // going straight to the recap. The finale speaks the full sentence
      // via TTS and then hands off to the normal recap path.
      if (isFinalMnemonicElement) {
        _showMnemonicFinale();
        return;
      }

      if (_currentIndex >= allElements.length ||
          _sessionScore >= widget.targetTaps) {
        _endGame(showRecap: true);
        return;
      }

      _fallController.reset();
      _fallController.forward();
    });
  }

  /// Triggered after the last mnemonic element is caught. First speaks
  /// the element's name (Neon) and waits for the clip to finish, so the
  /// student hears the final tile's label before the game view is
  /// replaced. Then animates the mnemonic to the centre of the screen,
  /// scales it up, and speaks the full sentence. The student advances
  /// to the recap screen by tapping NEXT in the overlay — no time
  /// pressure, they can re-read the mapping as long as they want.
  Future<void> _showMnemonicFinale() async {
    // Freeze the falling-element game during the finale so nothing
    // visually competes with the centered mnemonic. The fall animation
    // keeps the just-caught Neon visible where it was.
    _fallController.stop();
    _countdownTimer?.cancel();
    _mnemonicTimer?.cancel();

    // 1) Speak "Neon" first and wait for the clip to end. The element
    //    is cached from the startup prefetch so this plays instantly
    //    and resolves when playback completes. The index was already
    //    incremented by the _onTap post-delay block, so the last
    //    mnemonic element's symbol is `_mnemonicWords.length - 1`.
    final lastIdx = _mnemonicWords.length - 1;
    if (lastIdx < allElements.length) {
      await _tts.speakAndWait(TtsPhraseBank.element(allElements[lastIdx].symbol));
    }

    if (!mounted) return;

    // 2) Bring up the finale overlay.
    setState(() {
      _showingFinale = true;
      // Clear the single-word glow — the centered overlay renders ALL
      // words at full brightness while the sentence plays.
      _mnemonicGlowIndex = -1;
    });

    // 3) Speak the full mnemonic. `speak()` is fire-and-forget on the
    //    audio bus; the student controls when to leave the finale via
    //    the NEXT button in `_buildFinaleNextButton`.
    await _tts.speak(TtsPhraseBank.mnemonicPeriod12);
  }

  void _endGame({bool showRecap = false}) {
    if (_gameOver) return;
    _gameOver = true;
    _countdownTimer?.cancel();
    _fallController.stop();
    _totalScore += _sessionScore;
    widget.onProgress?.call(_currentIndex);

    if (showRecap) {
      setState(() {}); // trigger rebuild to show recap
    } else {
      widget.onComplete();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _mnemonicTimer?.cancel();
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
      child: Stack(
        children: [
          CustomPaint(
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
                _buildMnemonicBar(),
              ],
            ),
          ),
          // Mnemonic finale overlay — always mounted so the fade in/out
          // animates implicitly; IgnorePointer blocks interaction when
          // hidden so it doesn't trap taps during gameplay.
          IgnorePointer(
            ignoring: !_showingFinale,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOut,
              opacity: _showingFinale ? 1.0 : 0.0,
              child: _buildMnemonicFinaleOverlay(),
            ),
          ),
        ],
      ),
    );
  }

  /// Full-screen scrim + centered, scaled-up mnemonic. Appears on top
  /// of the game when `_showingFinale` is true. Each word is rendered
  /// in its element's family color, with the element's atomic symbol
  /// shown beneath so the student sees the mapping explicitly (Happy→H,
  /// Henry→He, etc.). A NEXT button lets them advance to the recap when
  /// they're ready rather than being rushed through on a timer.
  Widget _buildMnemonicFinaleOverlay() {
    return Container(
      color: AppColors.surface.withValues(alpha: 0.94),
      alignment: Alignment.center,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.7, end: 1.0),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, scale, child) {
          return Transform.scale(scale: scale, child: child);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'MNEMONIC UNLOCKED',
                style: TextStyle(
                  fontFamily: 'Consolas',
                  fontSize: 13,
                  letterSpacing: 4.0,
                  fontWeight: FontWeight.w700,
                  color: _teal.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 28),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.start,
                spacing: 22,
                runSpacing: 18,
                children: [
                  for (int i = 0; i < _mnemonicWords.length; i++)
                    _buildFinaleWord(_mnemonicWords[i], i),
                ],
              ),
              const SizedBox(height: 44),
              _buildFinaleNextButton(),
            ],
          ),
        ),
      ),
    );
  }

  /// Word + element symbol + full element name stack, all in the
  /// element's family color. Renders three lines: the mnemonic word
  /// big and glowing; the symbol (H, He, …) as a mid-size label;
  /// the full name (Hydrogen, Helium, …) smaller + italic underneath.
  Widget _buildFinaleWord(String word, int index) {
    // Period 1+2 elements align 1-to-1 with mnemonic indices (H at 0,
    // He at 1, …, Ne at 9). Out-of-range falls back to amber just in
    // case the mnemonic list grows ahead of the elements list.
    final hasElement = index < allElements.length;
    final color = hasElement
        ? familyColor(allElements[index].family)
        : _amber;
    final symbol = hasElement ? allElements[index].symbol : '';
    final name = hasElement ? allElements[index].name : '';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          word,
          style: TextStyle(
            fontFamily: 'Consolas',
            fontSize: 38,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.0,
            color: color,
            shadows: [
              Shadow(color: color.withValues(alpha: 0.55), blurRadius: 22),
              Shadow(color: color.withValues(alpha: 0.25), blurRadius: 44),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Atomic symbol — mid-size label in the same family color.
        Text(
          symbol,
          style: TextStyle(
            fontFamily: 'Consolas',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: color.withValues(alpha: 0.75),
          ),
        ),
        const SizedBox(height: 2),
        // Full element name — serif italic, smaller still, so it reads
        // as the expanded-form caption under the symbol.
        Text(
          name,
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 13,
            fontStyle: FontStyle.italic,
            color: color.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }

  /// "NEXT" button at the bottom of the finale. Taps advance to the
  /// standard recap screen via `_endGame(showRecap: true)`. Wrapped in
  /// `IgnorePointer`-free space (the overlay's IgnorePointer already
  /// releases taps when `_showingFinale` is true).
  Widget _buildFinaleNextButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (_gameOver) return;
          _endGame(showRecap: true);
        },
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: _teal, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: _teal.withValues(alpha: 0.25),
                blurRadius: 20,
              ),
            ],
          ),
          child: Text(
            'NEXT  →',
            style: TextStyle(
              fontFamily: 'Consolas',
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 4.0,
              color: _teal,
            ),
          ),
        ),
      ),
    );
  }

  // ── Mnemonic Bar ─────────────────────────────────────────
  //
  // Always-visible reminder of the period 1 + 2 mnemonic across the
  // bottom of the game screen. Each word corresponds to an element by
  // atomic number (Happy=H, Henry=He, …, Nearby=Ne). When the student
  // taps an element that has a mapping (first 10), the matching word
  // glows amber briefly so they build the H→Happy association
  // implicitly while catching.
  Widget _buildMnemonicBar() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: _teal.withValues(alpha: 0.3))),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 4,
        children: [
          for (int i = 0; i < _mnemonicWords.length; i++)
            _buildMnemonicWord(_mnemonicWords[i], i == _mnemonicGlowIndex),
        ],
      ),
    );
  }

  Widget _buildMnemonicWord(String word, bool glow) {
    final highlight = _mnemonicGlowColor;
    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 250),
      style: TextStyle(
        fontFamily: 'Consolas',
        fontSize: 20,
        fontWeight: glow ? FontWeight.w800 : FontWeight.w600,
        letterSpacing: 1.4,
        color: glow
            ? highlight
            : AppColors.onSurfaceVariant.withValues(alpha: 0.6),
        shadows: glow
            ? [
                Shadow(color: highlight.withValues(alpha: 0.65), blurRadius: 18),
                Shadow(color: highlight.withValues(alpha: 0.35), blurRadius: 32),
              ]
            : const <Shadow>[],
      ),
      child: Text(word),
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
                  final maxLeft = constraints.maxWidth - tileSize;
                  return Positioned(
                    top: top,
                    left: _dropX * maxLeft,
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
