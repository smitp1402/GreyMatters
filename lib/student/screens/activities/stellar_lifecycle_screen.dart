// lib/student/screens/activities/stellar_lifecycle_screen.dart

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

const _cosmicDust = Color(0xFF4A5CA8);
const _protostarGlow = Color(0xFFFFA955);
const _fusionBlue = Color(0xFF9EC4FF);
const _fusionYellow = Color(0xFFFFD36E);
const _fusionViolet = Color(0xFFD29FFF);
const _fusionRed = Color(0xFFFF5D2E);
const _spaceBlack = Color(0xFF05070F);

enum _Phase {
  nebula,
  protostar,
  ignition,       // brief flash transition from protostar to star/mass pick
  massChoice,
  mainSequenceLow,
  mainSequenceHigh,
  mainSequenceSuper,
  collapseLow,    // planetary nebula event
  collapseHigh,   // supernova event
  collapseSuper,  // hypernova event
  whiteDwarf,
  neutronStar,
  blackHole,
}

enum _MassChoice { low, high, superm }

/// Stellar Lifecycle — push cosmic dust into a protostar, ignite fusion,
/// choose a mass, drive the star through its main sequence with a slider,
/// then trigger the finale to watch it die. Mass picks the endgame:
/// white dwarf (via planetary nebula), neutron star (via supernova), or
/// black hole (via hypernova). Mass picker is revisitable.
class StellarLifecycleScreen extends StatefulWidget {
  final String subject;
  final String topicId;
  final int sectionIndex;
  final VoidCallback onComplete;

  const StellarLifecycleScreen({
    super.key,
    required this.subject,
    required this.topicId,
    required this.sectionIndex,
    required this.onComplete,
  });

  @override
  State<StellarLifecycleScreen> createState() => _StellarLifecycleScreenState();
}

class _StellarLifecycleScreenState extends State<StellarLifecycleScreen>
    with TickerProviderStateMixin {
  _Phase _phase = _Phase.nebula;
  _MassChoice? _mass;
  _MassChoice? _hoveredMass;

  // Slider-driven lifecycle position (0.0 = zero-age main sequence, 1.0 = end of life)
  double _lifePhase = 0.0;
  // Heat slider value in protostar phase (0.0 = cold cloud, 1.0 = fusion threshold)
  double _heat = 0.0;

  late final AnimationController _ambient;   // background drift / pulse
  late final AnimationController _event;     // supernova / planetary nebula
  late final AnimationController _ignition;  // protostar → star ignition flash
  late final AnimationController _birthIn;   // slow nebula → protostar fade-in (3s)

  // Smoothly animated display size for the mass-choice preview star.
  double _displayedStarSize = 60.0;

  @override
  void initState() {
    super.initState();
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _event = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    );
    _event.addStatusListener((status) {
      if (status != AnimationStatus.completed || !mounted) return;
      switch (_mass) {
        case _MassChoice.low:
          _advance(_Phase.whiteDwarf);
        case _MassChoice.high:
          _advance(_Phase.neutronStar);
        case _MassChoice.superm:
          _advance(_Phase.blackHole);
        case null:
          break;
      }
    });
    _ignition = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _ignition.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _advance(_Phase.massChoice);
      }
    });
    _birthIn = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _birthIn.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ambient.dispose();
    _event.dispose();
    _ignition.dispose();
    _birthIn.dispose();
    super.dispose();
  }

  void _igniteStar() {
    setState(() => _phase = _Phase.ignition);
    _ignition.forward(from: 0.0);
  }

  void _onNebulaFormed() {
    _advance(_Phase.protostar);
    _birthIn.forward(from: 0.0);
  }

  void _advance(_Phase next) {
    setState(() {
      _phase = next;
      if (next == _Phase.mainSequenceLow ||
          next == _Phase.mainSequenceHigh ||
          next == _Phase.mainSequenceSuper) {
        _lifePhase = 0.0;
      }
      if (next == _Phase.protostar) {
        _heat = 0.0;
      }
      if (next == _Phase.massChoice) {
        _hoveredMass = null;
      }
    });
  }

  void _chooseMass(_MassChoice choice) {
    setState(() {
      _mass = choice;
      _lifePhase = 0.0;
    });
    switch (choice) {
      case _MassChoice.low:
        _advance(_Phase.mainSequenceLow);
      case _MassChoice.high:
        _advance(_Phase.mainSequenceHigh);
      case _MassChoice.superm:
        _advance(_Phase.mainSequenceSuper);
    }
  }

  void _triggerFinale() {
    switch (_mass) {
      case _MassChoice.low:
        _startEvent(_Phase.collapseLow);
      case _MassChoice.high:
        _startEvent(_Phase.collapseHigh);
      case _MassChoice.superm:
        _startEvent(_Phase.collapseSuper);
      case null:
        break;
    }
  }

  void _startEvent(_Phase p) {
    setState(() => _phase = p);
    _event.forward(from: 0.0);
  }

  void _returnToMassPicker() {
    setState(() {
      _mass = null;
      _lifePhase = 0.0;
    });
    _event.reset();
    _advance(_Phase.massChoice);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          colors: [Color(0xFF0D1026), _spaceBlack],
          radius: 1.2,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(),
              const SizedBox(height: 24),
              Expanded(child: _stage()),
              const SizedBox(height: 16),
              _controls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'LIFE OF A STAR',
          style: TextStyle(
            fontFamily: 'Consolas',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 3.5,
            color: AppColors.primary,
          ),
        ),
        Text(
          _phaseLabel(_phase),
          style: const TextStyle(
            fontFamily: 'Consolas',
            fontSize: 11,
            letterSpacing: 2.0,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _stage() {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (_phase == _Phase.nebula)
          _NebulaInteractive(onFormed: _onNebulaFormed)
        else
          AnimatedBuilder(
            animation: Listenable.merge([_ambient, _event, _ignition, _birthIn]),
            builder: (_, __) {
              // Smoothly ease the mass-preview star size toward its target.
              final target = switch (_hoveredMass) {
                _MassChoice.low    => 38.0,
                _MassChoice.high   => 130.0,
                _MassChoice.superm => 260.0,
                null => 60.0,
              };
              _displayedStarSize += (target - _displayedStarSize) * 0.15;
              return CustomPaint(
                size: Size.infinite,
                painter: _StarPainter(
                  phase: _phase,
                  mass: _mass,
                  hoveredMass: _hoveredMass,
                  massPreviewSize: _displayedStarSize,
                  lifePhase: _lifePhase,
                  heat: _heat,
                  ambient: _ambient.value,
                  eventProgress: _event.value,
                  ignitionProgress: _ignition.value,
                  birthProgress: _birthIn.value,
                ),
              );
            },
          ),
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: _descriptionCard(),
        ),
      ],
    );
  }

  Widget _descriptionCard() {
    final (title, body) = _copy();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontSize: 13.5,
              color: AppColors.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _controls() {
    switch (_phase) {
      case _Phase.nebula:
        return _hint('MOVE YOUR CURSOR THROUGH THE DUST — GUIDE IT TO THE CENTER');
      case _Phase.protostar:
        if (_birthIn.value < 0.98) {
          return _hint('A PROTOSTAR FORMS …');
        }
        return _heatControls();
      case _Phase.ignition:
        return _hint('FUSION IGNITED · A STAR IS BORN');
      case _Phase.massChoice:
        return _massPicker();
      case _Phase.mainSequenceLow:
      case _Phase.mainSequenceHigh:
      case _Phase.mainSequenceSuper:
        return _mainSequenceControls();
      case _Phase.collapseLow:
      case _Phase.collapseHigh:
      case _Phase.collapseSuper:
        return _hint(_eventHint(_phase));
      case _Phase.whiteDwarf:
      case _Phase.neutronStar:
      case _Phase.blackHole:
        return _finaleControls();
    }
  }

  Widget _singleButton({
    required String label,
    required VoidCallback onTap,
    Color accent = AppColors.primary,
  }) {
    return SizedBox(
      height: 54,
      child: Material(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Segoe UI',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
                color: accent,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _massPicker() {
    return Row(
      children: [
        Expanded(child: _massCard(_MassChoice.low,    'SUN-LIKE', '0.5–1 M☉',  _fusionYellow)),
        const SizedBox(width: 10),
        Expanded(child: _massCard(_MassChoice.high,   'MASSIVE',  '8–25 M☉',   _fusionBlue)),
        const SizedBox(width: 10),
        Expanded(child: _massCard(_MassChoice.superm, 'SUPER',    '25+ M☉',    _fusionViolet)),
      ],
    );
  }

  Widget _massCard(_MassChoice choice, String label, String range, Color accent) {
    final isHovered = _hoveredMass == choice;
    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredMass = choice),
      onExit: (_) => setState(() {
        if (_hoveredMass == choice) _hoveredMass = null;
      }),
      child: Material(
        color: accent.withValues(alpha: isHovered ? 0.20 : 0.10),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: InkWell(
          onTap: () => _chooseMass(choice),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 78,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                color: accent.withValues(alpha: isHovered ? 1.0 : 0.5),
                width: isHovered ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Segoe UI',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.0,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  range,
                  style: const TextStyle(
                    fontFamily: 'Consolas',
                    fontSize: 11,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _heatControls() {
    final ready = _heat >= 0.98;
    // Protostar color hints at temperature — shifts from red to orange to white.
    final heatColor = Color.lerp(
      const Color(0xFFAA4020),
      Colors.white,
      _heat,
    )!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
            activeTrackColor: heatColor,
            inactiveTrackColor: AppColors.surfaceContainerHighest,
            thumbColor: Colors.white,
            overlayColor: heatColor.withValues(alpha: 0.15),
          ),
          child: Slider(
            value: _heat,
            onChanged: (v) => setState(() => _heat = v),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '1000 K',
              style: TextStyle(
                fontFamily: 'Consolas',
                fontSize: 10,
                letterSpacing: 2.0,
                color: AppColors.outline.withValues(alpha: 0.8),
              ),
            ),
            Text(
              'CORE TEMPERATURE',
              style: TextStyle(
                fontFamily: 'Consolas',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
                color: heatColor,
              ),
            ),
            Text(
              '10 M K',
              style: TextStyle(
                fontFamily: 'Consolas',
                fontSize: 10,
                letterSpacing: 2.0,
                color: AppColors.outline.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _singleButton(
          label: ready ? 'IGNITE FUSION' : 'RAISE CORE TEMPERATURE',
          accent: ready ? _protostarGlow : AppColors.outline,
          onTap: ready ? _igniteStar : () {},
        ),
      ],
    );
  }

  Widget _mainSequenceControls() {
    final canTrigger = _lifePhase >= 0.95;
    final finaleLabel = switch (_mass) {
      _MassChoice.low    => 'SHED OUTER LAYERS',
      _MassChoice.high   => 'TRIGGER SUPERNOVA',
      _MassChoice.superm => 'COLLAPSE TO SINGULARITY',
      null => 'TRIGGER FINALE',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
            activeTrackColor: _massAccent(),
            inactiveTrackColor: AppColors.surfaceContainerHighest,
            thumbColor: Colors.white,
            overlayColor: _massAccent().withValues(alpha: 0.15),
          ),
          child: Slider(
            value: _lifePhase,
            onChanged: (v) => setState(() => _lifePhase = v),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ZAMS',
              style: TextStyle(
                fontFamily: 'Consolas',
                fontSize: 10,
                letterSpacing: 2.0,
                color: AppColors.outline.withValues(alpha: 0.8),
              ),
            ),
            Text(
              _lifeStageName(_mass, _lifePhase),
              style: TextStyle(
                fontFamily: 'Consolas',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
                color: _massAccent(),
              ),
            ),
            Text(
              'DEATH',
              style: TextStyle(
                fontFamily: 'Consolas',
                fontSize: 10,
                letterSpacing: 2.0,
                color: AppColors.outline.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _singleButton(
          label: canTrigger ? finaleLabel : 'DRAG TO END OF LIFE',
          accent: canTrigger ? _massAccent() : AppColors.outline,
          onTap: canTrigger ? _triggerFinale : () {},
        ),
      ],
    );
  }

  Widget _finaleControls() {
    return Row(
      children: [
        Expanded(
          child: _singleButton(
            label: 'CHOOSE DIFFERENT MASS',
            accent: AppColors.onSurfaceVariant,
            onTap: _returnToMassPicker,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _singleButton(
            label: 'FINISH',
            accent: AppColors.primary,
            onTap: widget.onComplete,
          ),
        ),
      ],
    );
  }

  Widget _hint(String text) {
    return Container(
      height: 54,
      alignment: Alignment.center,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Consolas',
          fontSize: 11,
          letterSpacing: 2.0,
          color: AppColors.outline.withValues(alpha: 0.85),
        ),
      ),
    );
  }

  Color _massAccent() => switch (_mass) {
        _MassChoice.low    => _fusionYellow,
        _MassChoice.high   => _fusionBlue,
        _MassChoice.superm => _fusionViolet,
        null => AppColors.primary,
      };

  String _phaseLabel(_Phase p) => switch (p) {
        _Phase.nebula              => 'PHASE · NEBULA',
        _Phase.protostar           => 'PHASE · PROTOSTAR',
        _Phase.ignition            => 'PHASE · IGNITION',
        _Phase.massChoice          => 'PHASE · MASS SELECTION',
        _Phase.mainSequenceLow     => 'PHASE · MAIN SEQUENCE (LOW)',
        _Phase.mainSequenceHigh    => 'PHASE · MAIN SEQUENCE (HIGH)',
        _Phase.mainSequenceSuper   => 'PHASE · MAIN SEQUENCE (SUPER)',
        _Phase.collapseLow         => 'EVENT · PLANETARY NEBULA',
        _Phase.collapseHigh        => 'EVENT · SUPERNOVA',
        _Phase.collapseSuper       => 'EVENT · HYPERNOVA',
        _Phase.whiteDwarf          => 'FINALE · WHITE DWARF',
        _Phase.neutronStar         => 'FINALE · NEUTRON STAR',
        _Phase.blackHole           => 'FINALE · BLACK HOLE',
      };

  String _eventHint(_Phase p) => switch (p) {
        _Phase.collapseLow   => 'OUTER LAYERS DRIFTING AWAY …',
        _Phase.collapseHigh  => 'CORE COLLAPSE · SUPERNOVA …',
        _Phase.collapseSuper => 'CORE COLLAPSE · HYPERNOVA …',
        _ => '',
      };

  String _lifeStageName(_MassChoice? mass, double t) {
    if (mass == _MassChoice.low) {
      if (t < 0.20) return 'ZERO-AGE MAIN SEQUENCE';
      if (t < 0.60) return 'MAIN SEQUENCE';
      if (t < 0.85) return 'SUBGIANT';
      if (t < 0.98) return 'RED GIANT';
      return 'PLANETARY NEBULA IMMINENT';
    }
    if (mass == _MassChoice.high) {
      if (t < 0.30) return 'BLUE MAIN SEQUENCE';
      if (t < 0.70) return 'BRIGHT GIANT';
      if (t < 0.90) return 'RED SUPERGIANT';
      if (t < 0.98) return 'IRON CORE';
      return 'SUPERNOVA IMMINENT';
    }
    if (mass == _MassChoice.superm) {
      if (t < 0.25) return 'O-TYPE MAIN SEQUENCE';
      if (t < 0.60) return 'WOLF-RAYET';
      if (t < 0.90) return 'LUMINOUS BLUE VARIABLE';
      if (t < 0.98) return 'IRON CORE';
      return 'HYPERNOVA IMMINENT';
    }
    return '—';
  }

  (String, String) _copy() {
    switch (_phase) {
      case _Phase.nebula:
        return (
          'Nebula',
          'A cold cloud of hydrogen and cosmic dust drifts through space. '
              'Guide the particles together with your cursor to begin '
              'gravitational collapse.',
        );
      case _Phase.protostar:
        return (
          'Protostar',
          'The core is compressing. Drag the temperature up toward the '
              'fusion threshold near 10 million K — then ignite.',
        );
      case _Phase.ignition:
        return (
          'Ignition',
          'Hydrogen fusion begins. Energy floods outward. Gravity and '
              'radiation reach equilibrium — a star is born.',
        );
      case _Phase.massChoice:
        return (
          'Choose Stellar Mass',
          'Mass decides everything — brightness, lifespan, and how the star '
              'dies. Hover an option to preview its size.',
        );
      case _Phase.mainSequenceLow:
      case _Phase.mainSequenceHigh:
      case _Phase.mainSequenceSuper:
        return _mainSequenceCopy();
      case _Phase.collapseLow:
        return (
          'Planetary Nebula',
          'The outer envelope drifts off into space as a glowing shell. '
              'What remains at the center will become a white dwarf.',
        );
      case _Phase.collapseHigh:
        return (
          'Supernova',
          'Core-collapse. In the flash, an entire galaxy can be outshone. '
              'Heavier elements scatter outward into space.',
        );
      case _Phase.collapseSuper:
        return (
          'Hypernova',
          'An even more violent collapse. Gravity wins completely — '
              'light itself will not escape.',
        );
      case _Phase.whiteDwarf:
        return (
          'White Dwarf',
          'An Earth-sized ember. Fusion has stopped. It will cool quietly '
              'for trillions of years.',
        );
      case _Phase.neutronStar:
        return (
          'Neutron Star',
          'The core collapsed into a city-sized sphere of pure neutrons. '
              'A teaspoon of this material weighs a billion tons.',
        );
      case _Phase.blackHole:
        return (
          'Black Hole',
          'Gravity has won completely. Beyond the event horizon, not even '
              'light escapes.',
        );
    }
  }

  (String, String) _mainSequenceCopy() {
    final t = _lifePhase;
    final stage = _lifeStageName(_mass, t);
    final body = switch (_mass) {
      _MassChoice.low when t < 0.20   => 'Steady hydrogen fusion has just begun. The star is stable and will stay this way for roughly 10 billion years.',
      _MassChoice.low when t < 0.60   => 'The bulk of the star\'s life. Hydrogen slowly converts to helium in the core.',
      _MassChoice.low when t < 0.85   => 'Core hydrogen is running out. The star brightens and expands slightly.',
      _MassChoice.low when t < 0.98   => 'Hydrogen is exhausted. The envelope swells to hundreds of times the Sun\'s radius and cools to red.',
      _MassChoice.low                  => 'Outer layers are about to be expelled. A white dwarf will remain behind.',

      _MassChoice.high when t < 0.30  => 'Brilliant and hot — fusing hydrogen at an enormous rate. Lifespan: only a few million years.',
      _MassChoice.high when t < 0.70  => 'Still burning through hydrogen, but faster. The envelope glows blue-white.',
      _MassChoice.high when t < 0.90  => 'Core fusion moves on to helium, carbon, and heavier elements. The star swells and reddens.',
      _MassChoice.high when t < 0.98  => 'Iron accumulates. Fusing iron costs energy instead of releasing it. Collapse is inevitable.',
      _MassChoice.high                 => 'Core collapse is moments away. Supernova follows.',

      _MassChoice.superm when t < 0.25 => 'A blazing O-type star. Extremely hot, extremely short-lived — a few million years at most.',
      _MassChoice.superm when t < 0.60 => 'Stellar winds strip away the outer envelope. Core fusion accelerates.',
      _MassChoice.superm when t < 0.90 => 'The star cycles between blue and red supergiant as the envelope puffs and contracts.',
      _MassChoice.superm when t < 0.98 => 'The iron core exceeds the Tolman–Oppenheimer–Volkoff limit. Even neutron degeneracy cannot stop gravity.',
      _MassChoice.superm                => 'Hypernova imminent. The core collapses directly into a black hole.',
      null => '',
    };
    return (stage, body);
  }
}

/// Paints star/space visuals per phase.
class _StarPainter extends CustomPainter {
  final _Phase phase;
  final _MassChoice? mass;
  final _MassChoice? hoveredMass;
  final double massPreviewSize;
  final double lifePhase;
  final double heat;
  final double ambient;
  final double eventProgress;
  final double ignitionProgress;
  final double birthProgress;

  _StarPainter({
    required this.phase,
    required this.mass,
    required this.hoveredMass,
    required this.massPreviewSize,
    required this.lifePhase,
    required this.heat,
    required this.ambient,
    required this.eventProgress,
    required this.ignitionProgress,
    required this.birthProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    _backgroundStars(canvas, size);

    switch (phase) {
      case _Phase.nebula:
        // Handled by the interactive nebula widget.
        break;
      case _Phase.protostar:
        _paintProtostar(canvas, center);
      case _Phase.ignition:
        _paintIgnition(canvas, center);
      case _Phase.massChoice:
        _paintMassChoice(canvas, center);
      case _Phase.mainSequenceLow:
        _paintMainSequence(canvas, center, _fusionYellow, baseCoreR: 56, baseGlowR: 78, maxSwell: 2.8);
      case _Phase.mainSequenceHigh:
        _paintMainSequence(canvas, center, _fusionBlue, baseCoreR: 70, baseGlowR: 96, maxSwell: 1.8);
      case _Phase.mainSequenceSuper:
        _paintMainSequence(canvas, center, _fusionViolet, baseCoreR: 84, baseGlowR: 118, maxSwell: 1.5);
      case _Phase.collapseLow:
        _paintPlanetaryNebula(canvas, center, eventProgress);
      case _Phase.collapseHigh:
        _paintSupernova(canvas, center, _fusionBlue, eventProgress, isHyper: false);
      case _Phase.collapseSuper:
        _paintSupernova(canvas, center, _fusionViolet, eventProgress, isHyper: true);
      case _Phase.whiteDwarf:
        _paintPoint(canvas, center, Colors.white, 14, 42);
      case _Phase.neutronStar:
        _paintPoint(canvas, center, _fusionBlue, 10, 64 + 10 * math.sin(ambient * math.pi * 4));
      case _Phase.blackHole:
        _paintBlackHole(canvas, center);
    }
  }

  void _backgroundStars(Canvas canvas, Size size) {
    // Horsehead-style emission nebula backdrop — bright ionized regions in
    // H-alpha red, OIII teal, SII orange; overlaid by dark molecular clouds
    // that create silhouette contrast.

    // Bright emission regions (alpha, blur, position, color, radius)
    final emissions = <(Offset, Color, double, double)>[
      // Deep H-alpha red — dominant, upper-left
      (Offset(size.width * 0.22, size.height * 0.28), const Color(0xFFE83A5C), 260, 0.45),
      // Magenta/pink — upper-right
      (Offset(size.width * 0.80, size.height * 0.22), const Color(0xFFC93A8C), 220, 0.38),
      // OIII teal — lower-right (cool contrast)
      (Offset(size.width * 0.85, size.height * 0.78), const Color(0xFF3AC8BC), 230, 0.34),
      // SII orange — lower-left
      (Offset(size.width * 0.15, size.height * 0.78), const Color(0xFFE8983A), 210, 0.36),
      // Soft central cyan wash
      (Offset(size.width * 0.5,  size.height * 0.45), const Color(0xFF5ACAE0), 320, 0.18),
      // Extra H-alpha pocket — center-top area behind the star/BH
      (Offset(size.width * 0.55, size.height * 0.35), const Color(0xFFFF5A7A), 200, 0.30),
    ];
    for (final (pos, color, r, alpha) in emissions) {
      canvas.drawCircle(
        pos,
        r,
        Paint()
          ..color = color.withValues(alpha: alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 90),
      );
    }

    // Dark dust / molecular clouds — silhouettes dampening color where they
    // overlap the emission regions. Gives the "Horsehead" contrast.
    final dust = <(Offset, double, double)>[
      (Offset(size.width * 0.38, size.height * 0.52), 140, 0.55),
      (Offset(size.width * 0.65, size.height * 0.58), 120, 0.48),
      (Offset(size.width * 0.30, size.height * 0.35), 90,  0.40),
      (Offset(size.width * 0.72, size.height * 0.40), 100, 0.42),
    ];
    for (final (pos, r, alpha) in dust) {
      canvas.drawCircle(
        pos,
        r,
        Paint()
          ..color = const Color(0xFF050716).withValues(alpha: alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60),
      );
    }

    // Starfield — more stars, more brightness variety
    final rng = math.Random(7);
    final dimStar = Paint()..color = Colors.white.withValues(alpha: 0.40);
    final midStar = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.4);
    final brightStar = Paint()
      ..color = Colors.white
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8);
    for (int i = 0; i < 110; i++) {
      final dx = rng.nextDouble() * size.width;
      final dy = rng.nextDouble() * size.height;
      final r = rng.nextDouble() * 1.4 + 0.3;
      final tier = i % 13 == 0 ? brightStar : (i % 5 == 0 ? midStar : dimStar);
      canvas.drawCircle(Offset(dx, dy), r, tier);
    }
  }

  void _paintProtostar(Canvas canvas, Offset c) {
    // Birth grow-in — eased scale + alpha from 0 to 1 over the first 3 sec.
    // After birthProgress reaches 1, visuals are purely heat-driven.
    final birthEased = Curves.easeOutCubic.transform(birthProgress.clamp(0.0, 1.0));
    final birthScale = 0.15 + 0.85 * birthEased;
    final birthAlpha = birthEased;

    final pulse = 1.0 + (0.06 + 0.05 * heat) * math.sin(ambient * math.pi * 2);
    final hot = Color.lerp(const Color(0xFFAA4020), Colors.white, heat)!;
    final glowColor = Color.lerp(const Color(0xFF803020), _protostarGlow, heat)!;
    final coreR = (22 + 18 * heat) * pulse * birthScale;
    final glowR = (55 + 55 * heat) * pulse * birthScale;

    canvas.drawCircle(
      c,
      glowR * 1.6,
      Paint()
        ..color = glowColor.withValues(alpha: (0.10 + 0.25 * heat) * birthAlpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50),
    );
    canvas.drawCircle(
      c,
      glowR,
      Paint()
        ..color = glowColor.withValues(alpha: (0.3 + 0.35 * heat) * birthAlpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28),
    );
    canvas.drawCircle(
      c,
      coreR,
      Paint()..color = hot.withValues(alpha: birthAlpha),
    );
    if (heat > 0.1) {
      canvas.drawCircle(
        c,
        coreR * 0.55,
        Paint()
          ..color = Colors.white.withValues(alpha: (0.55 + 0.4 * heat) * birthAlpha),
      );
    }
  }

  void _paintIgnition(Canvas canvas, Offset c) {
    // A short, bright burst: bright flash peaks mid-animation, then settles
    // into a generic main-sequence-looking star that will hand off to the
    // mass picker.
    final t = ignitionProgress;
    final flash = math.sin(t.clamp(0.0, 1.0) * math.pi); // 0 → 1 → 0

    // Soft flash halo over the whole center area
    canvas.drawCircle(
      c,
      220 * flash + 30,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85 * flash)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60),
    );

    // Settled star growing in as flash fades
    final settle = t.clamp(0.0, 1.0);
    final coreR = 55 * settle;
    final glowR = 95 * settle;
    canvas.drawCircle(
      c,
      glowR * 1.4,
      Paint()
        ..color = _fusionYellow.withValues(alpha: 0.18 * settle)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 45),
    );
    canvas.drawCircle(
      c,
      glowR,
      Paint()
        ..color = _fusionYellow.withValues(alpha: 0.32 * settle)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
    );
    canvas.drawCircle(
      c,
      coreR,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.white, _fusionYellow],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: coreR)),
    );
  }

  void _paintMassChoice(Canvas canvas, Offset c) {
    // Smoothly-animated display size from parent (eases between mass hovers).
    final r = massPreviewSize;
    final color = switch (hoveredMass) {
      _MassChoice.low    => _fusionYellow,
      _MassChoice.high   => _fusionBlue,
      _MassChoice.superm => _fusionViolet,
      null => _fusionYellow,
    };

    final glowR = r * 1.6;
    final pulse = 1.0 + 0.04 * math.sin(ambient * math.pi * 4);

    // Scale reference — faint silhouettes of the smaller mass classes so the
    // student can see the actual size jump between Sun / Massive / Super.
    // Relative radii follow the main-sequence ratios (1 : 3.4 : 6.8).
    const refSun = 38.0;
    const refMassive = 130.0;
    if (hoveredMass == _MassChoice.superm || hoveredMass == _MassChoice.high) {
      canvas.drawCircle(
        c,
        refSun,
        Paint()
          ..color = _fusionYellow.withValues(alpha: 0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
      );
    }
    if (hoveredMass == _MassChoice.superm) {
      canvas.drawCircle(
        c,
        refMassive,
        Paint()
          ..color = _fusionBlue.withValues(alpha: 0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
      );
    }

    // Corona
    canvas.drawCircle(
      c,
      glowR * 1.55 * pulse,
      Paint()
        ..color = color.withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60),
    );
    // Outer glow
    canvas.drawCircle(
      c,
      glowR * pulse,
      Paint()
        ..color = color.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 38),
    );
    // Body
    final bodyRect = Rect.fromCircle(center: c, radius: r * pulse);
    canvas.drawCircle(
      c,
      r * pulse,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.95),
            color,
            Color.lerp(color, Colors.black, 0.35)!,
          ],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(bodyRect),
    );
  }

  // ── Main sequence with detailed star rendering ─────────────────────
  void _paintMainSequence(
    Canvas canvas,
    Offset c,
    Color baseColor, {
    required double baseCoreR,
    required double baseGlowR,
    required double maxSwell,
  }) {
    // Size grows (quadratically) with lifePhase; color shifts toward red.
    final swell = 1.0 + math.pow(lifePhase, 2.2).toDouble() * (maxSwell - 1.0);
    final color = Color.lerp(baseColor, _fusionRed, math.pow(lifePhase, 1.6).toDouble() * 0.85)!;
    final coreR = baseCoreR * swell;
    final glowR = baseGlowR * swell;
    final pulse = 1.0 + (0.04 + 0.08 * lifePhase) * math.sin(ambient * math.pi * 4);

    // Outer corona
    final corona = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);
    canvas.drawCircle(c, glowR * 1.55 * pulse, corona);

    // Mid glow
    final glow = Paint()
      ..color = color.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
    canvas.drawCircle(c, glowR * pulse, glow);

    // Solar flares — arcs looping from the limb, fading in/out
    _paintFlares(canvas, c, coreR * pulse, color);

    // Star body with radial gradient (hot white core → saturated → cooler rim)
    final bodyRect = Rect.fromCircle(center: c, radius: coreR * pulse);
    final bodyGrad = RadialGradient(
      colors: [
        Colors.white.withValues(alpha: 0.95),
        color,
        Color.lerp(color, Colors.black, 0.35)!,
      ],
      stops: const [0.0, 0.6, 1.0],
    );
    final bodyPaint = Paint()..shader = bodyGrad.createShader(bodyRect);
    canvas.drawCircle(c, coreR * pulse, bodyPaint);

    // Sunspots (dark patches that drift over the surface)
    _paintSunspots(canvas, c, coreR * pulse, color);

    // Lifecycle progress ring — shows slider position
    final ringRect = Rect.fromCircle(center: c, radius: baseGlowR * maxSwell + 22);
    final ringBg = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final ringFg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(ringRect, -math.pi / 2, math.pi * 2, false, ringBg);
    canvas.drawArc(ringRect, -math.pi / 2, math.pi * 2 * lifePhase, false, ringFg);
  }

  void _paintSunspots(Canvas canvas, Offset c, double radius, Color starColor) {
    final rng = math.Random(23);
    final spotColor = Color.lerp(starColor, Colors.black, 0.7)!;
    for (int i = 0; i < 4; i++) {
      final seedAngle = i * 1.57;
      // Longitude cycles with ambient (rotation); latitude wobbles
      final lon = math.cos(ambient * math.pi * 2 * 0.6 + seedAngle);
      if (lon < -0.25) continue; // hidden on far side
      final lat = math.sin(ambient * math.pi * 2 * 0.4 + seedAngle * 0.7) * 0.55;
      final sx = c.dx + lon * radius * 0.82;
      final sy = c.dy + lat * radius * 0.78;
      final spotR = radius * (0.07 + 0.04 * rng.nextDouble() + 0.02 * i);
      final visibility = ((lon + 0.25) / 0.25).clamp(0.0, 1.0);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(sx, sy),
          width: spotR * 2.1,
          height: spotR * 1.5,
        ),
        Paint()..color = spotColor.withValues(alpha: 0.55 * visibility),
      );
    }
  }

  void _paintFlares(Canvas canvas, Offset c, double radius, Color color) {
    // Five fixed flare "slots" at different angles, each with its own
    // fade cycle so they bloom in and out at different times.
    for (int i = 0; i < 5; i++) {
      final baseAngle = (i / 5.0) * math.pi * 2 + ambient * math.pi * 0.5;
      final phaseOffset = i * 1.3;
      final fadeRaw = math.sin(ambient * math.pi * 2 + phaseOffset).abs();
      final fade = math.max(0.0, fadeRaw - 0.35) / 0.65;
      if (fade <= 0) continue;

      final origin = c + Offset(math.cos(baseAngle) * radius, math.sin(baseAngle) * radius);
      final outward = Offset(math.cos(baseAngle), math.sin(baseAngle));
      final perp = Offset(-outward.dy, outward.dx);
      final archHeight = radius * (0.3 + 0.15 * math.sin(phaseOffset * 2));
      final footLen = radius * 0.28;

      final start = origin;
      final end = origin + perp * footLen;
      final control = origin + outward * archHeight + perp * (footLen * 0.5);

      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);

      final flarePaint = Paint()
        ..color = color.withValues(alpha: 0.75 * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.3
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawPath(path, flarePaint);
    }
  }

  // ── Finale events ────────────────────────────────────────────────
  void _paintPlanetaryNebula(Canvas canvas, Offset c, double t) {
    // Gentle shedding: pulse → expanding shell + dust → white dwarf emerges
    if (t < 0.25) {
      // Last pulse as a red giant
      final pulse = 1.0 + 0.25 * math.sin(ambient * math.pi * 6);
      final corona = Paint()
        ..color = _fusionRed.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);
      canvas.drawCircle(c, 170 * pulse, corona);
      final glow = Paint()
        ..color = _fusionRed.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
      canvas.drawCircle(c, 120 * pulse, glow);
      canvas.drawCircle(c, 72 * pulse,
          Paint()..color = Color.lerp(_fusionRed, _protostarGlow, 0.4)!);
    } else {
      final s = ((t - 0.25) / 0.75).clamp(0.0, 1.0);
      final maxR = 380.0;
      final shellR = 90 + maxR * s;
      final shellAlpha = (1.0 - s * 0.75).clamp(0.0, 1.0);

      // Outer shell ring
      canvas.drawCircle(
        c,
        shellR,
        Paint()
          ..color = _fusionRed.withValues(alpha: 0.32 * shellAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 42 * (1.0 - s * 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
      );
      // Inner shell
      canvas.drawCircle(
        c,
        shellR * 0.65,
        Paint()
          ..color = _protostarGlow.withValues(alpha: 0.36 * shellAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 22 * (1.0 - s * 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
      );

      // Drifting dust particles
      final rng = math.Random(67);
      for (int i = 0; i < 50; i++) {
        final a = rng.nextDouble() * math.pi * 2;
        final d = shellR * (0.5 + rng.nextDouble() * 0.7);
        final p = c + Offset(math.cos(a) * d, math.sin(a) * d);
        canvas.drawCircle(
          p,
          1 + rng.nextDouble() * 1.7,
          Paint()
            ..color = _protostarGlow.withValues(alpha: 0.55 * shellAlpha)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
        );
      }

      // White dwarf emerging at center (from t=0.55)
      if (t > 0.55) {
        final e = ((t - 0.55) / 0.45).clamp(0.0, 1.0);
        canvas.drawCircle(
          c,
          24 * e,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.55)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
        );
        canvas.drawCircle(c, 10 * e, Paint()..color = Colors.white);
      }
    }
  }

  void _paintSupernova(Canvas canvas, Offset c, Color starColor, double t,
      {required bool isHyper}) {
    // 0.00-0.12: dim/flicker
    // 0.12-0.22: blinding flash
    // 0.22-0.85: shockwave + debris + remnant emerges
    // 0.85-1.00: fade
    if (t < 0.12) {
      final flicker = 0.4 + 0.3 * math.sin(ambient * math.pi * 10);
      canvas.drawCircle(
        c,
        80,
        Paint()
          ..color = starColor.withValues(alpha: flicker)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24),
      );
      canvas.drawCircle(c, 42, Paint()..color = starColor);
    } else if (t < 0.24) {
      final fl = (t - 0.12) / 0.12;
      final brightness = math.sin(fl * math.pi); // 0 → 1 → 0
      final r = 80 + 260 * brightness;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.85 * brightness)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 70),
      );
      canvas.drawCircle(
        c,
        80 * brightness + 40,
        Paint()..color = Colors.white.withValues(alpha: brightness),
      );
    } else if (t < 0.95) {
      final sw = ((t - 0.24) / 0.71).clamp(0.0, 1.0);
      final maxR = (isHyper ? 620.0 : 500.0);
      final ringR = maxR * math.pow(sw, 0.7).toDouble();
      final ringAlpha = (1.0 - sw).clamp(0.0, 1.0);

      // Shockwave ring
      canvas.drawCircle(
        c,
        ringR,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.7 * ringAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.5, 6 * ringAlpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );

      // Hot inner glow riding inside the shock
      canvas.drawCircle(
        c,
        ringR * 0.55,
        Paint()
          ..color = starColor.withValues(alpha: 0.55 * ringAlpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40),
      );

      // Debris / ejecta — particles scattered outward with some dispersion
      final rng = math.Random(51);
      for (int i = 0; i < 70; i++) {
        final a = rng.nextDouble() * math.pi * 2;
        final speed = 0.35 + rng.nextDouble() * 0.7;
        final d = ringR * speed;
        final px = c.dx + math.cos(a) * d;
        final py = c.dy + math.sin(a) * d;
        final pColor = i % 4 == 0 ? Colors.white : starColor;
        canvas.drawCircle(
          Offset(px, py),
          1.3 + rng.nextDouble() * 2.2,
          Paint()
            ..color = pColor.withValues(alpha: 0.75 * ringAlpha)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
        );
      }

      // Remnant emerges at center from t=0.5
      if (t > 0.5) {
        final e = ((t - 0.5) / 0.45).clamp(0.0, 1.0);
        if (isHyper) {
          // Black hole forming — dark disk + faint ring
          final diskR = 34 * e;
          canvas.drawCircle(
            c,
            diskR * 1.8,
            Paint()
              ..shader = SweepGradient(
                colors: [
                  _fusionViolet.withValues(alpha: 0.0),
                  _fusionViolet.withValues(alpha: 0.45 * e),
                  Colors.white.withValues(alpha: 0.3 * e),
                  _fusionViolet.withValues(alpha: 0.45 * e),
                  _fusionViolet.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
                transform: GradientRotation(ambient * math.pi * 2),
              ).createShader(Rect.fromCircle(center: c, radius: diskR * 1.8)),
          );
          canvas.drawCircle(c, diskR, Paint()..color = _spaceBlack);
          canvas.drawCircle(
            c,
            diskR + 1,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.5 * e)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1,
          );
        } else {
          // Neutron star forming — tight bright blue point
          canvas.drawCircle(
            c,
            22 * e,
            Paint()
              ..color = _fusionBlue.withValues(alpha: 0.9)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
          );
          canvas.drawCircle(c, 7 * e, Paint()..color = Colors.white);
        }
      }
    }
  }

  void _paintPoint(Canvas canvas, Offset c, Color color, double coreR, double glowR) {
    final glow = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
    canvas.drawCircle(c, glowR, glow);
    canvas.drawCircle(c, coreR, Paint()..color = color);
  }

  void _paintBlackHole(Canvas canvas, Offset c) {
    const shadowR = 46.0;
    const diskInner = shadowR * 1.9;
    const diskOuter = shadowR * 4.4;
    const tiltY = 0.14;               // thinner / more edge-on equatorial band
    const lensedYTop = 1.30;          // top loop arches higher
    const lensedYBottom = 1.20;       // bottom loop now clearly curves under

    // Ambient warm haze — gives the disk atmosphere.
    canvas.drawCircle(
      c,
      diskOuter * 1.5,
      Paint()
        ..color = const Color(0xFFFF7A38).withValues(alpha: 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 90),
    );

    // 1. Front flat band — thin, translucent equatorial slice.
    final frontPath = _frontBandPath(c, diskInner, diskOuter, tiltY);
    _paintDiskRegion(canvas, frontPath, fullAlpha: 0.55, equatorAnchor: c);
    _paintFlowBands(canvas, frontPath, c, diskOuter, speed: 1.0);

    // 2. Event horizon shadow.
    canvas.drawCircle(c, shadowR, Paint()..color = _spaceBlack);

    // 3. Bottom lens loop — drawn AFTER shadow so the curve wraps under.
    final bottomPath = _lensedLoopPath(c, diskInner, diskOuter, lensedYBottom, flipVertical: true);
    _paintDiskRegion(canvas, bottomPath, fullAlpha: 0.65, equatorAnchor: c);
    _paintFlowBands(canvas, bottomPath, c, diskOuter, speed: 0.85);

    // 4. Top lens loop — signature halo over the shadow.
    final topPath = _lensedLoopPath(c, diskInner, diskOuter, lensedYTop, flipVertical: false);
    _paintDiskRegion(canvas, topPath, fullAlpha: 0.8, equatorAnchor: c);
    _paintFlowBands(canvas, topPath, c, diskOuter, speed: 0.85);

    // 5. Photon ring — thin bright ring hugging the shadow. Pulses subtly.
    final ringPulse = 1.0 + 0.04 * math.sin(ambient * math.pi * 4);
    canvas.drawCircle(
      c,
      shadowR * 1.08 * ringPulse,
      Paint()
        ..color = const Color(0xFFFFE4A8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    // Einstein halo — softer outer ring
    canvas.drawCircle(
      c,
      shadowR * 1.20 * ringPulse,
      Paint()
        ..color = const Color(0xFFFFA955).withValues(alpha: 0.40)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  // ── Disk helpers ─────────────────────────────────────────────────

  /// Build the path for a lensed loop (curved halo above or below the shadow).
  Path _lensedLoopPath(Offset c, double inner, double outer, double heightFactor,
      {required bool flipVertical}) {
    final dir = flipVertical ? 1.0 : -1.0;
    final outerPeakY = c.dy + dir * outer * heightFactor;
    final innerPeakY = c.dy + dir * inner * heightFactor;
    return Path()
      ..moveTo(c.dx - outer, c.dy)
      ..cubicTo(
        c.dx - outer * 0.55, outerPeakY,
        c.dx + outer * 0.55, outerPeakY,
        c.dx + outer, c.dy,
      )
      ..lineTo(c.dx + inner, c.dy)
      ..cubicTo(
        c.dx + inner * 0.55, innerPeakY,
        c.dx - inner * 0.55, innerPeakY,
        c.dx - inner, c.dy,
      )
      ..close();
  }

  /// Build the path for the flat equatorial band — a lower-half-ring shape.
  Path _frontBandPath(Offset c, double inner, double outer, double tilt) {
    final outerRect = Rect.fromCenter(center: c, width: outer * 2, height: outer * tilt * 2);
    final innerRect = Rect.fromCenter(center: c, width: inner * 2, height: inner * tilt * 2);
    final ring = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(outerRect)
      ..addOval(innerRect);
    final lowerHalf = Path()
      ..addRect(Rect.fromLTRB(c.dx - outer, c.dy, c.dx + outer, c.dy + outer * tilt + 6));
    return Path.combine(PathOperation.intersect, ring, lowerHalf);
  }

  /// Paints a disk region with a wispy, layered appearance — diffuse haze,
  /// main colored fill, and a bright inner rim.
  void _paintDiskRegion(
    Canvas canvas,
    Path path, {
    required double fullAlpha,
    required Offset equatorAnchor,
  }) {
    // Haze pass — large blur, low alpha, so the disk has atmosphere
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFF9A44).withValues(alpha: 0.22 * fullAlpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    // Gradient: brightest at the equator edge of the path, dims away from it
    final bounds = path.getBounds();
    final equatorAtTop = (bounds.top - equatorAnchor.dy).abs() <
        (bounds.bottom - equatorAnchor.dy).abs();

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: equatorAtTop ? Alignment.topCenter : Alignment.bottomCenter,
          end: equatorAtTop ? Alignment.bottomCenter : Alignment.topCenter,
          colors: [
            const Color(0xFFFFE4A8).withValues(alpha: 0.78 * fullAlpha),
            const Color(0xFFFFB06A).withValues(alpha: 0.60 * fullAlpha),
            const Color(0xFFFF7A38).withValues(alpha: 0.40 * fullAlpha),
            const Color(0xFF5A200A).withValues(alpha: 0.10 * fullAlpha),
          ],
          stops: const [0.0, 0.35, 0.75, 1.0],
        ).createShader(bounds),
    );

    // Bright rim on the equator-side edge — makes the inner boundary glow
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.22 * fullAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  /// Overlays rotating sweep-gradient bright bands inside a given disk path,
  /// making the disk look like flowing plasma. The bands rotate around the
  /// black hole center, offset by ambient.
  void _paintFlowBands(Canvas canvas, Path path, Offset c, double radius,
      {required double speed}) {
    canvas.save();
    canvas.clipPath(path);
    final paint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0,
        endAngle: math.pi * 2,
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.28),
          Colors.transparent,
          Colors.white.withValues(alpha: 0.14),
          Colors.transparent,
          Colors.white.withValues(alpha: 0.20),
          Colors.transparent,
          Colors.white.withValues(alpha: 0.10),
          Colors.transparent,
        ],
        stops: const [0.0, 0.08, 0.18, 0.30, 0.45, 0.58, 0.72, 0.85, 1.0],
        transform: GradientRotation(ambient * math.pi * 2 * speed),
      ).createShader(Rect.fromCircle(center: c, radius: radius))
      ..blendMode = BlendMode.plus;
    canvas.drawCircle(c, radius * 2, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StarPainter old) =>
      old.phase != phase ||
      old.mass != mass ||
      old.hoveredMass != hoveredMass ||
      old.massPreviewSize != massPreviewSize ||
      old.lifePhase != lifePhase ||
      old.heat != heat ||
      old.ambient != ambient ||
      old.eventProgress != eventProgress ||
      old.ignitionProgress != ignitionProgress ||
      old.birthProgress != birthProgress;
}

// ─────────────────────────────────────────────────────────────────────
// Interactive nebula — cursor-attractor particle dust.
// Phase advances when enough dust has collapsed near the center.
// ─────────────────────────────────────────────────────────────────────

class _DustParticle {
  Offset pos;
  Offset vel;
  final double radius;
  final double brightness;
  _DustParticle({required this.pos, required this.vel, required this.radius, required this.brightness});
}

class _NebulaInteractive extends StatefulWidget {
  final VoidCallback onFormed;
  const _NebulaInteractive({required this.onFormed});

  @override
  State<_NebulaInteractive> createState() => _NebulaInteractiveState();
}

enum _BirthStage { gathering, swirling, flashing, done }

class _NebulaInteractiveState extends State<_NebulaInteractive>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  final List<_DustParticle> _particles = [];
  Offset? _cursor;
  Size _size = Size.zero;
  double _collapseProgress = 0.0;
  _BirthStage _birth = _BirthStage.gathering;
  double _birthT = 0.0; // time-in-stage, seconds

  // Physics / interaction knobs
  static const double _cursorGravity = 520.0;
  static const double _cursorRadius = 180.0;
  static const double _damping = 0.985;
  static const double _maxSpeed = 380.0;
  static const double _corePackRadius = 48.0;
  static const double _formThresholdRatio = 0.55;

  // Birth sequence knobs
  static const double _swirlDurationSec = 2.0;
  static const double _flashDurationSec = 0.7;
  static const double _swirlCenterGravity = 1400.0;
  static const double _swirlTangential = 1100.0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _ensureParticles(Size size) {
    if (size == _size && _particles.isNotEmpty) return;
    _size = size;
    _particles.clear();
    final center = Offset(size.width / 2, size.height / 2);
    final maxReach = math.min(size.width, size.height) * 0.5;
    final minStart = maxReach * 0.7;
    final maxStart = maxReach * 1.1;
    final rng = math.Random(131);
    for (int i = 0; i < 90; i++) {
      final angle = rng.nextDouble() * math.pi * 2;
      final dist = minStart + rng.nextDouble() * (maxStart - minStart);
      final pos = center + Offset(math.cos(angle) * dist, math.sin(angle) * dist);
      final tangent = Offset(-math.sin(angle), math.cos(angle));
      final vel = tangent * (10 + rng.nextDouble() * 14);
      _particles.add(_DustParticle(
        pos: pos,
        vel: vel,
        radius: 1.4 + rng.nextDouble() * 2.2,
        brightness: 0.35 + rng.nextDouble() * 0.5,
      ));
    }
  }

  void _tick(Duration now) {
    if (_birth == _BirthStage.done || _size == Size.zero) {
      _last = now;
      return;
    }
    final dt = _last == Duration.zero
        ? 1 / 60
        : math.min(0.05, (now - _last).inMicroseconds / 1e6);
    _last = now;

    final center = Offset(_size.width / 2, _size.height / 2);

    switch (_birth) {
      case _BirthStage.gathering:
        _stepGathering(dt, center);
        if (_collapseProgress >= _formThresholdRatio) {
          _birth = _BirthStage.swirling;
          _birthT = 0.0;
          _cursor = null; // lock out further user pushes
        }
      case _BirthStage.swirling:
        _stepSwirling(dt, center);
        _birthT += dt;
        if (_birthT >= _swirlDurationSec) {
          _birth = _BirthStage.flashing;
          _birthT = 0.0;
        }
      case _BirthStage.flashing:
        _birthT += dt;
        if (_birthT >= _flashDurationSec) {
          _birth = _BirthStage.done;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onFormed();
          });
        }
      case _BirthStage.done:
        break;
    }

    if (mounted) setState(() {});
  }

  void _stepGathering(double dt, Offset center) {
    int inCore = 0;
    for (final p in _particles) {
      if (_cursor != null) {
        final toCursor = _cursor! - p.pos;
        final dCursor = toCursor.distance;
        if (dCursor < _cursorRadius && dCursor > 1) {
          final falloff = 1.0 - (dCursor / _cursorRadius);
          final cAccel = toCursor / dCursor * (_cursorGravity * falloff);
          p.vel += cAccel * dt;
        }
      }
      p.vel *= _damping;
      final speed = p.vel.distance;
      if (speed > _maxSpeed) p.vel = p.vel / speed * _maxSpeed;
      p.pos += p.vel * dt;
      if ((p.pos - center).distance < _corePackRadius) inCore++;
    }
    _collapseProgress = (inCore / _particles.length).clamp(0.0, 1.0);
  }

  void _stepSwirling(double dt, Offset center) {
    // Strong pull to center + tangential force for visible spiral.
    for (final p in _particles) {
      final toCenter = center - p.pos;
      final d = toCenter.distance;
      if (d > 1) {
        // Inward gravity
        p.vel += toCenter / d * _swirlCenterGravity * dt;
        // Tangential component (perpendicular to radius, counter-clockwise)
        final tangent = Offset(-toCenter.dy, toCenter.dx) / d;
        p.vel += tangent * _swirlTangential * dt;
      }
      p.vel *= 0.93; // heavier damping during swirl to keep motion controlled
      final speed = p.vel.distance;
      if (speed > _maxSpeed * 1.5) p.vel = p.vel / speed * _maxSpeed * 1.5;
      p.pos += p.vel * dt;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        _ensureParticles(size);
        return MouseRegion(
          onHover: (e) => setState(() => _cursor = e.localPosition),
          onExit: (_) => setState(() => _cursor = null),
          cursor: SystemMouseCursors.precise,
          child: GestureDetector(
            onPanUpdate: (d) => setState(() => _cursor = d.localPosition),
            onPanEnd: (_) => setState(() => _cursor = null),
            onPanCancel: () => setState(() => _cursor = null),
            child: CustomPaint(
              size: size,
              painter: _NebulaPainter(
                particles: _particles,
                cursor: _cursor,
                collapse: _collapseProgress,
                birth: _birth,
                birthT: _birthT,
                swirlDuration: _swirlDurationSec,
                flashDuration: _flashDurationSec,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NebulaPainter extends CustomPainter {
  final List<_DustParticle> particles;
  final Offset? cursor;
  final double collapse;
  final _BirthStage birth;
  final double birthT;
  final double swirlDuration;
  final double flashDuration;

  _NebulaPainter({
    required this.particles,
    required this.cursor,
    required this.collapse,
    required this.birth,
    required this.birthT,
    required this.swirlDuration,
    required this.flashDuration,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final rng = math.Random(7);
    final starPaint = Paint()..color = Colors.white.withValues(alpha: 0.35);
    for (int i = 0; i < 60; i++) {
      final dx = rng.nextDouble() * size.width;
      final dy = rng.nextDouble() * size.height;
      final r = rng.nextDouble() * 1.4 + 0.3;
      canvas.drawCircle(Offset(dx, dy), r, starPaint);
    }

    if (collapse > 0.05) {
      final glow = Paint()
        ..color = _protostarGlow.withValues(alpha: 0.08 + 0.32 * collapse)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 + 36 * collapse);
      canvas.drawCircle(center, 30 + 50 * collapse, glow);
    }

    for (final p in particles) {
      final paint = Paint()
        ..color = _cosmicDust.withValues(alpha: p.brightness)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
      canvas.drawCircle(p.pos, p.radius, paint);
    }

    // Cursor "hand" — visible only during the gathering stage.
    if (cursor != null && birth == _BirthStage.gathering) {
      final ringPaint = Paint()
        ..color = _protostarGlow.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);
      canvas.drawCircle(cursor!, _NebulaInteractiveState._cursorRadius, ringPaint);

      final innerGlow = Paint()
        ..color = _protostarGlow.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
      canvas.drawCircle(cursor!, 28, innerGlow);

      final core = Paint()..color = Colors.white.withValues(alpha: 0.75);
      canvas.drawCircle(cursor!, 3, core);
    }

    // Flash burst during the flashing stage — expanding white disk that fades.
    if (birth == _BirthStage.flashing) {
      final t = (birthT / flashDuration).clamp(0.0, 1.0);
      final brightness = math.sin(t * math.pi); // 0 → 1 → 0
      final radius = 40 + 260 * t;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.85 * brightness)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50),
      );
      canvas.drawCircle(
        center,
        60 * brightness + 20,
        Paint()..color = Colors.white.withValues(alpha: brightness),
      );
      // Soft orange aftermath
      canvas.drawCircle(
        center,
        40 + 80 * t,
        Paint()
          ..color = _protostarGlow.withValues(alpha: 0.5 * (1.0 - t))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NebulaPainter old) => true;
}
