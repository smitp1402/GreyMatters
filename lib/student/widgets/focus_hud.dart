// lib/student/widgets/focus_hud.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/models/attention_state.dart';
import '../../core/services/attention_stream.dart';

/// Bottom HUD strip showing live focus gauge + band power bars.
///
/// Updates every 1 second from AttentionStream. Height ~80px.
/// Designed to sit at the bottom of the lesson screen.
class FocusHud extends StatefulWidget {
  const FocusHud({super.key});

  @override
  State<FocusHud> createState() => _FocusHudState();
}

class _FocusHudState extends State<FocusHud> {
  StreamSubscription<AttentionState>? _sub;
  AttentionState? _latest;

  @override
  void initState() {
    super.initState();
    _sub = AttentionStream.instance.stream.listen((state) {
      if (mounted) setState(() => _latest = state);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _latest;
    final focus = state?.focusScore ?? 0.0;
    final level = state?.level ?? AttentionLevel.focused;

    final Color levelColor;
    switch (level) {
      case AttentionLevel.focused:
        levelColor = AppColors.focused;
      case AttentionLevel.drifting:
        levelColor = AppColors.drifting;
      case AttentionLevel.lost:
        levelColor = AppColors.lost;
    }

    return Container(
      height: 80,
      clipBehavior: Clip.hardEdge,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        border: Border(
          top: BorderSide(
            color: levelColor.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
      ),
      child: Row(
        children: [
          // Focus gauge (circular)
          _FocusGaugeCompact(focus: focus, color: levelColor, level: level),
          const SizedBox(width: 20),

          // Divider
          Container(width: 1, height: 48, color: AppColors.outlineVariant.withValues(alpha: 0.3)),
          const SizedBox(width: 20),

          // Band power bars
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _BandRow(label: 'δ', value: state?.delta ?? 0, color: AppColors.delta),
                const SizedBox(height: 3),
                _BandRow(label: 'θ', value: state?.theta ?? 0, color: AppColors.theta),
                const SizedBox(height: 3),
                _BandRow(label: 'α', value: state?.alpha ?? 0, color: AppColors.alpha),
                const SizedBox(height: 3),
                _BandRow(label: 'β', value: state?.beta ?? 0, color: AppColors.beta),
                const SizedBox(height: 3),
                _BandRow(label: 'γ', value: state?.gamma ?? 0, color: AppColors.gamma),
              ],
            ),
          ),

          const SizedBox(width: 20),

          // Level label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: levelColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              level.name.toUpperCase(),
              style: TextStyle(
                fontFamily: 'Consolas',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
                color: levelColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusGaugeCompact extends StatelessWidget {
  const _FocusGaugeCompact({
    required this.focus,
    required this.color,
    required this.level,
  });
  final double focus;
  final Color color;
  final AttentionLevel level;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: focus),
              duration: const Duration(milliseconds: 500),
              builder: (_, v, __) => CircularProgressIndicator(
                value: v.clamp(0.0, 1.0),
                strokeWidth: 4,
                backgroundColor: AppColors.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          Text(
            '${(focus * 100).round()}',
            style: TextStyle(
              fontFamily: 'Consolas',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _BandRow extends StatelessWidget {
  const _BandRow({required this.label, required this.value, required this.color});
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 14,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Consolas',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 6,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: value),
                duration: const Duration(milliseconds: 500),
                builder: (_, v, __) => LinearProgressIndicator(
                  value: v.clamp(0.0, 1.0),
                  backgroundColor: AppColors.surfaceContainerLowest,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
