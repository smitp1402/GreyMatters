// lib/student/screens/debug_stream_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/services/attention_stream.dart';
import '../../core/models/attention_state.dart';

/// Screen 2 — Live debug stream showing all data from daemon WebSocket.
///
/// Four panels: raw JSON terminal, band power bars, focus gauge, timeline chart.
/// Proves the Crown → daemon → Flutter pipeline is working end-to-end.
class DebugStreamScreen extends StatefulWidget {
  const DebugStreamScreen({super.key});

  @override
  State<DebugStreamScreen> createState() => _DebugStreamScreenState();
}

class _DebugStreamScreenState extends State<DebugStreamScreen> {
  StreamSubscription<AttentionState>? _sub;
  final List<AttentionState> _history = [];
  final List<String> _rawMessages = [];
  int _messageCount = 0;
  DateTime? _lastMessageTime;
  double _avgLatency = 0;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _sub = AttentionStream.instance.stream.listen(_onMessage);
  }

  void _onMessage(AttentionState state) {
    if (!mounted) return;

    final now = DateTime.now();
    if (_lastMessageTime != null) {
      final latency = now.difference(_lastMessageTime!).inMilliseconds.toDouble();
      _avgLatency = _avgLatency * 0.8 + latency * 0.2; // exponential moving average
    }
    _lastMessageTime = now;

    setState(() {
      _messageCount++;
      _history.add(state);
      if (_history.length > 60) _history.removeAt(0);

      // Format raw JSON for display
      final jsonStr = _formatJson(state);
      _rawMessages.add(jsonStr);
      if (_rawMessages.length > 10) _rawMessages.removeAt(0);
    });

    // Auto-scroll JSON terminal
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatJson(AttentionState state) {
    return '{"session_id":"${state.sessionId}",'
        '"focus_score":${state.focusScore.toStringAsFixed(3)},'
        '"theta":${state.theta.toStringAsFixed(4)},'
        '"alpha":${state.alpha.toStringAsFixed(4)},'
        '"beta":${state.beta.toStringAsFixed(4)},'
        '"gamma":${state.gamma.toStringAsFixed(4)},'
        '"level":"${state.level.name}",'
        '"timestamp":${state.timestamp.millisecondsSinceEpoch}}';
  }

  @override
  void dispose() {
    _sub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final latest = _history.isNotEmpty ? _history.last : null;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          // Top bar
          _buildTopBar(),
          // Panels
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // 2x2 grid on desktop, vertical on narrow
                  if (constraints.maxWidth > 800) {
                    return Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Expanded(child: _buildJsonTerminal()),
                              const SizedBox(height: 12),
                              Expanded(child: _buildFocusGauge(latest)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            children: [
                              Expanded(child: _buildBandBars(latest)),
                              const SizedBox(height: 12),
                              Expanded(child: _buildTimeline()),
                            ],
                          ),
                        ),
                      ],
                    );
                  }
                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        SizedBox(height: 250, child: _buildJsonTerminal()),
                        const SizedBox(height: 12),
                        SizedBox(height: 200, child: _buildBandBars(latest)),
                        const SizedBox(height: 12),
                        SizedBox(height: 200, child: _buildFocusGauge(latest)),
                        const SizedBox(height: 12),
                        SizedBox(height: 200, child: _buildTimeline()),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          // Bottom bar
          _buildBottomBar(),
        ],
      ),
    );
  }

  // ── Top Bar ──────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: AppColors.surfaceContainer,
      child: Row(
        children: [
          const Text(
            'LIVE NEURAL STREAM',
            style: TextStyle(
              fontFamily: 'Consolas',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.0,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 20),
          // Connection dot
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _messageCount > 0 ? AppColors.focused : AppColors.outline,
              boxShadow: _messageCount > 0
                  ? [BoxShadow(color: AppColors.focused.withValues(alpha: 0.5), blurRadius: 6)]
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _messageCount > 0 ? 'CONNECTED' : 'WAITING...',
            style: TextStyle(
              fontFamily: 'Consolas',
              fontSize: 10,
              letterSpacing: 1.5,
              color: _messageCount > 0 ? AppColors.focused : AppColors.outline,
            ),
          ),
          const Spacer(),
          if (_history.isNotEmpty)
            Text(
              'SID: ${_history.last.sessionId}',
              style: const TextStyle(
                fontFamily: 'Consolas',
                fontSize: 11,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          const SizedBox(width: 20),
          Text(
            '$_messageCount msg',
            style: const TextStyle(
              fontFamily: 'Consolas',
              fontSize: 11,
              color: AppColors.outline,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '${_avgLatency.round()}ms avg',
            style: const TextStyle(
              fontFamily: 'Consolas',
              fontSize: 11,
              color: AppColors.outline,
            ),
          ),
        ],
      ),
    );
  }

  // ── Panel 1: Raw JSON Terminal ──────────────────────────────────────

  Widget _buildJsonTerminal() {
    return _Panel(
      title: 'RAW JSON STREAM',
      child: Container(
        color: const Color(0xFF0A0A0A),
        child: _rawMessages.isEmpty
            ? const Center(
                child: Text(
                  'Waiting for data...',
                  style: TextStyle(
                    fontFamily: 'Consolas',
                    fontSize: 12,
                    color: AppColors.outline,
                  ),
                ),
              )
            : ListView.builder(
                controller: _scrollController,
                itemCount: _rawMessages.length,
                padding: const EdgeInsets.all(10),
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _JsonLine(
                    index: _messageCount - _rawMessages.length + i + 1,
                    json: _rawMessages[i],
                  ),
                ),
              ),
      ),
    );
  }

  // ── Panel 2: Band Power Bars ────────────────────────────────────────

  Widget _buildBandBars(AttentionState? state) {
    return _Panel(
      title: 'BAND POWERS',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _BandBar(label: 'THETA', value: state?.theta ?? 0, color: AppColors.theta, hz: '4-8 Hz'),
            _BandBar(label: 'ALPHA', value: state?.alpha ?? 0, color: AppColors.alpha, hz: '8-13 Hz'),
            _BandBar(label: 'BETA', value: state?.beta ?? 0, color: AppColors.beta, hz: '13-30 Hz'),
            _BandBar(label: 'GAMMA', value: state?.gamma ?? 0, color: AppColors.gamma, hz: '30-45 Hz'),
          ],
        ),
      ),
    );
  }

  // ── Panel 3: Focus Gauge ────────────────────────────────────────────

  Widget _buildFocusGauge(AttentionState? state) {
    final focus = state?.focusScore ?? 0.0;
    final level = state?.level ?? AttentionLevel.focused;

    final Color gaugeColor;
    switch (level) {
      case AttentionLevel.focused:
        gaugeColor = AppColors.focused;
      case AttentionLevel.drifting:
        gaugeColor = AppColors.drifting;
      case AttentionLevel.lost:
        gaugeColor = AppColors.lost;
    }

    return _Panel(
      title: 'FOCUS SCORE',
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: focus,
                      strokeWidth: 8,
                      backgroundColor: AppColors.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(gaugeColor),
                    ),
                  ),
                  Text(
                    '${(focus * 100).round()}%',
                    style: TextStyle(
                      fontFamily: 'Consolas',
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: gaugeColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: gaugeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Text(
                level.name.toUpperCase(),
                style: TextStyle(
                  fontFamily: 'Consolas',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.0,
                  color: gaugeColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Panel 4: Timeline Chart ─────────────────────────────────────────

  Widget _buildTimeline() {
    return _Panel(
      title: 'FOCUS TIMELINE (60s)',
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: _history.isEmpty
            ? const Center(
                child: Text(
                  'Collecting data...',
                  style: TextStyle(
                    fontFamily: 'Consolas',
                    fontSize: 12,
                    color: AppColors.outline,
                  ),
                ),
              )
            : CustomPaint(
                painter: _TimelinePainter(history: _history),
                size: Size.infinite,
              ),
      ),
    );
  }

  // ── Bottom Bar ──────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: AppColors.surfaceContainer,
      child: Row(
        children: [
          TextButton(
            onPressed: () => context.go('/student/connect'),
            child: const Text(
              '← BACK',
              style: TextStyle(
                fontFamily: 'Segoe UI',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
                color: AppColors.outline,
              ),
            ),
          ),
          const Spacer(),
          Text(
            '$_messageCount messages received',
            style: const TextStyle(
              fontFamily: 'Consolas',
              fontSize: 11,
              color: AppColors.outline,
            ),
          ),
          const SizedBox(width: 24),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryContainer],
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context.go('/student/calibrate'),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  child: Text(
                    'PROCEED TO CALIBRATION',
                    style: TextStyle(
                      fontFamily: 'Segoe UI',
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 2.0,
                      color: AppColors.onPrimary,
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
}

// ============================================================
// Shared sub-widgets
// ============================================================

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.outlineVariant, width: 0.5),
              ),
            ),
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: 'Consolas',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
                color: AppColors.outline,
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _JsonLine extends StatelessWidget {
  const _JsonLine({required this.index, required this.json});
  final int index;
  final String json;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontFamily: 'Consolas', fontSize: 11, height: 1.4),
        children: [
          TextSpan(
            text: '${index.toString().padLeft(4)} ',
            style: TextStyle(color: AppColors.outline.withValues(alpha: 0.4)),
          ),
          // Colorize JSON keys and values
          ..._colorizeJson(json),
        ],
      ),
    );
  }

  List<TextSpan> _colorizeJson(String raw) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'"(\w+)"\s*:\s*("[^"]*"|-?[\d.]+)');

    int lastEnd = 0;
    for (final match in regex.allMatches(raw)) {
      // Text before match
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: raw.substring(lastEnd, match.start),
          style: const TextStyle(color: AppColors.onSurfaceVariant),
        ));
      }

      // Key
      spans.add(TextSpan(
        text: '"${match.group(1)}"',
        style: const TextStyle(color: AppColors.primary),
      ));
      spans.add(const TextSpan(text: ':', style: TextStyle(color: AppColors.onSurfaceVariant)));

      // Value
      final value = match.group(2)!;
      final isString = value.startsWith('"');
      spans.add(TextSpan(
        text: value,
        style: TextStyle(color: isString ? AppColors.tertiary : AppColors.onSurface),
      ));

      lastEnd = match.end;
    }

    if (lastEnd < raw.length) {
      spans.add(TextSpan(
        text: raw.substring(lastEnd),
        style: const TextStyle(color: AppColors.onSurfaceVariant),
      ));
    }

    return spans;
  }
}

class _BandBar extends StatelessWidget {
  const _BandBar({
    required this.label,
    required this.value,
    required this.color,
    required this.hz,
  });
  final String label;
  final double value;
  final Color color;
  final String hz;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Consolas',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 16,
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
        const SizedBox(width: 8),
        SizedBox(
          width: 44,
          child: Text(
            (value * 100).round().toString().padLeft(3) + '%',
            style: const TextStyle(
              fontFamily: 'Consolas',
              fontSize: 11,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        SizedBox(
          width: 56,
          child: Text(
            hz,
            style: TextStyle(
              fontFamily: 'Consolas',
              fontSize: 9,
              color: AppColors.outline.withValues(alpha: 0.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({required this.history});
  final List<AttentionState> history;

  @override
  void paint(Canvas canvas, Size size) {
    if (history.isEmpty) return;

    // Draw zone backgrounds
    final zonePaint = Paint()..style = PaintingStyle.fill;

    // Lost zone (bottom third)
    zonePaint.color = AppColors.lost.withValues(alpha: 0.05);
    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.66, size.width, size.height * 0.34), zonePaint);

    // Drifting zone (middle third)
    zonePaint.color = AppColors.drifting.withValues(alpha: 0.03);
    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.33, size.width, size.height * 0.33), zonePaint);

    // Draw grid lines
    final gridPaint = Paint()
      ..color = AppColors.outlineVariant.withValues(alpha: 0.15)
      ..strokeWidth = 0.5;

    for (int i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Draw focus line
    if (history.length < 2) return;

    final path = Path();
    for (int i = 0; i < history.length; i++) {
      final x = (i / 59) * size.width; // 60-second window
      final y = size.height * (1 - history[i].focusScore);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Determine color from latest level
    final Color lineColor;
    switch (history.last.level) {
      case AttentionLevel.focused:
        lineColor = AppColors.focused;
      case AttentionLevel.drifting:
        lineColor = AppColors.drifting;
      case AttentionLevel.lost:
        lineColor = AppColors.lost;
    }

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, linePaint);

    // Draw current point
    final lastX = ((history.length - 1) / 59) * size.width;
    final lastY = size.height * (1 - history.last.focusScore);
    canvas.drawCircle(
      Offset(lastX, lastY),
      4,
      Paint()..color = lineColor,
    );
    canvas.drawCircle(
      Offset(lastX, lastY),
      7,
      Paint()
        ..color = lineColor.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_TimelinePainter old) => true;
}
