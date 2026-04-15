// lib/teacher/screens/live_monitor_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/models/attention_state.dart';
import '../../core/services/attention_stream.dart';
import '../../core/services/realtime_broadcast.dart';

/// Teacher live monitor — real-time focus data for a specific student session.
///
/// Shows: focus gauge, band power bars, attention level, session timer,
/// intervention event feed, and focus timeline chart.
class LiveMonitorScreen extends StatefulWidget {
  final String sessionCode;

  const LiveMonitorScreen({super.key, required this.sessionCode});

  @override
  State<LiveMonitorScreen> createState() => _LiveMonitorScreenState();
}

class _LiveMonitorScreenState extends State<LiveMonitorScreen> {
  StreamSubscription<AttentionState>? _localSub;
  StreamSubscription<AttentionState>? _realtimeSub;
  AttentionState? _latest;
  final List<AttentionState> _history = [];
  final List<_InterventionEvent> _interventionEvents = [];
  int _messageCount = 0;
  final _startTime = DateTime.now();
  bool _sessionEnded = false;
  Timer? _noDataTimer;

  @override
  void initState() {
    super.initState();

    // Primary: Supabase Realtime Broadcast (works across any network)
    _connectRealtime();

    // Fallback: local WebSocket stream (same machine / same WiFi)
    _localSub = AttentionStream.instance.stream.listen(_onData);

    // Detect session end: no data for 15 seconds
    _resetNoDataTimer();
  }

  Future<void> _connectRealtime() async {
    try {
      await RealtimeBroadcast.instance.subscribeToSession(widget.sessionCode);
      _realtimeSub = RealtimeBroadcast.instance.stream.listen(_onData);
    } catch (_) {
      // Realtime unavailable — fall back to local stream
    }
  }

  void _onData(AttentionState state) {
    if (!mounted) return;
    _resetNoDataTimer();

    final prevLevel = _latest?.level;

    setState(() {
      _latest = state;
      _messageCount++;
      _history.add(state);
      if (_history.length > 120) _history.removeAt(0);

      // Detect intervention events (level transitions)
      if (prevLevel == AttentionLevel.focused &&
          (state.level == AttentionLevel.drifting || state.level == AttentionLevel.lost)) {
        _interventionEvents.add(_InterventionEvent(
          time: DateTime.now(),
          level: state.level,
          focusScore: state.focusScore,
        ));
      }
    });
  }

  void _resetNoDataTimer() {
    _noDataTimer?.cancel();
    _noDataTimer = Timer(const Duration(seconds: 15), () {
      if (mounted) setState(() => _sessionEnded = true);
    });
  }

  @override
  void dispose() {
    _localSub?.cancel();
    _realtimeSub?.cancel();
    RealtimeBroadcast.instance.unsubscribe();
    _noDataTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(_startTime);
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          // Top bar
          _buildTopBar(elapsed),

          // Session ended overlay
          if (_sessionEnded)
            Expanded(child: _buildSessionEnded())
          else if (_latest == null)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: 16),
                    Text(
                      'WAITING FOR DATA...',
                      style: TextStyle(
                        fontFamily: 'Consolas',
                        fontSize: 12,
                        letterSpacing: 3.0,
                        color: AppColors.outline,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar(Duration elapsed) {
    final level = _latest?.level;
    final Color statusColor;
    if (level == null) {
      statusColor = AppColors.outline;
    } else {
      switch (level) {
        case AttentionLevel.focused:
          statusColor = AppColors.focused;
        case AttentionLevel.drifting:
          statusColor = AppColors.drifting;
        case AttentionLevel.lost:
          statusColor = AppColors.lost;
      }
    }

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: AppColors.surfaceContainer,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 20, color: AppColors.outline),
            onPressed: () => context.go('/teacher'),
          ),
          const SizedBox(width: 12),
          const Text(
            'LIVE MONITOR',
            style: TextStyle(
              fontFamily: 'Consolas',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.0,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 16),
          // Session code badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              widget.sessionCode,
              style: const TextStyle(
                fontFamily: 'Consolas',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 4.0,
                color: AppColors.primary,
              ),
            ),
          ),
          const Spacer(),
          // Connection indicator
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _latest != null ? statusColor : AppColors.outline,
              boxShadow: _latest != null
                  ? [BoxShadow(color: statusColor.withValues(alpha: 0.5), blurRadius: 6)]
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _latest != null
                ? level!.name.toUpperCase()
                : 'CONNECTING',
            style: TextStyle(
              fontFamily: 'Consolas',
              fontSize: 10,
              letterSpacing: 1.5,
              color: _latest != null ? statusColor : AppColors.outline,
            ),
          ),
          const SizedBox(width: 24),
          // Timer
          Text(
            '${elapsed.inMinutes.toString().padLeft(2, '0')}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}',
            style: const TextStyle(
              fontFamily: 'Consolas',
              fontSize: 16,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Left: Focus gauge + band bars
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Expanded(child: _buildFocusPanel()),
                const SizedBox(height: 16),
                Expanded(child: _buildBandPanel()),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Right: Timeline + events
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Expanded(flex: 2, child: _buildTimelinePanel()),
                const SizedBox(height: 16),
                Expanded(flex: 1, child: _buildEventFeed()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox(height: 200, child: _buildFocusPanel()),
          const SizedBox(height: 16),
          SizedBox(height: 180, child: _buildBandPanel()),
          const SizedBox(height: 16),
          SizedBox(height: 200, child: _buildTimelinePanel()),
          const SizedBox(height: 16),
          SizedBox(height: 200, child: _buildEventFeed()),
        ],
      ),
    );
  }

  // ── Focus Gauge Panel ──────────────────────────────────────

  Widget _buildFocusPanel() {
    final focus = _latest?.focusScore ?? 0;
    final level = _latest?.level ?? AttentionLevel.focused;

    final Color color;
    switch (level) {
      case AttentionLevel.focused:
        color = AppColors.focused;
      case AttentionLevel.drifting:
        color = AppColors.drifting;
      case AttentionLevel.lost:
        color = AppColors.lost;
    }

    return _Panel(
      title: 'FOCUS SCORE',
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: focus),
                      duration: const Duration(milliseconds: 500),
                      builder: (_, v, __) => CircularProgressIndicator(
                        value: v.clamp(0.0, 1.0),
                        strokeWidth: 8,
                        backgroundColor: AppColors.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                  ),
                  Text(
                    '${(focus * 100).round()}%',
                    style: TextStyle(
                      fontFamily: 'Consolas',
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                level.name.toUpperCase(),
                style: TextStyle(
                  fontFamily: 'Consolas',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.0,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$_messageCount readings',
              style: const TextStyle(
                fontFamily: 'Consolas',
                fontSize: 10,
                color: AppColors.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Band Power Panel ───────────────────────────────────────

  Widget _buildBandPanel() {
    return _Panel(
      title: 'BAND POWERS',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _bandBar('THETA', _latest?.theta ?? 0, AppColors.theta, '4-8 Hz'),
            _bandBar('ALPHA', _latest?.alpha ?? 0, AppColors.alpha, '8-13 Hz'),
            _bandBar('BETA', _latest?.beta ?? 0, AppColors.beta, '13-30 Hz'),
            _bandBar('GAMMA', _latest?.gamma ?? 0, AppColors.gamma, '30-45 Hz'),
          ],
        ),
      ),
    );
  }

  Widget _bandBar(String label, double value, Color color, String hz) {
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(label,
              style: TextStyle(
                fontFamily: 'Consolas', fontSize: 10,
                fontWeight: FontWeight.w700, color: color,
              )),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 12,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: value),
                duration: const Duration(milliseconds: 500),
                builder: (_, v, __) => LinearProgressIndicator(
                  value: v.clamp(0.0, 1.0),
                  backgroundColor: AppColors.surfaceContainerLowest,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 36,
          child: Text('${(value * 100).round()}%',
              style: const TextStyle(
                fontFamily: 'Consolas', fontSize: 10,
                color: AppColors.onSurfaceVariant,
              )),
        ),
        SizedBox(
          width: 50,
          child: Text(hz,
              style: TextStyle(
                fontFamily: 'Consolas', fontSize: 9,
                color: AppColors.outline.withValues(alpha: 0.5),
              )),
        ),
      ],
    );
  }

  // ── Timeline Panel ─────────────────────────────────────────

  Widget _buildTimelinePanel() {
    return _Panel(
      title: 'FOCUS TIMELINE',
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: _history.length < 2
            ? const Center(
                child: Text('Collecting data...',
                    style: TextStyle(fontFamily: 'Consolas', fontSize: 12, color: AppColors.outline)),
              )
            : CustomPaint(
                painter: _TimelinePainter(history: _history),
                size: Size.infinite,
              ),
      ),
    );
  }

  // ── Event Feed ─────────────────────────────────────────────

  Widget _buildEventFeed() {
    return _Panel(
      title: 'INTERVENTION EVENTS',
      child: _interventionEvents.isEmpty
          ? Center(
              child: Text(
                'No interventions triggered yet',
                style: TextStyle(
                  fontFamily: 'Consolas', fontSize: 12,
                  color: AppColors.outline.withValues(alpha: 0.5),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _interventionEvents.length,
              itemBuilder: (_, i) {
                final event = _interventionEvents[_interventionEvents.length - 1 - i];
                final elapsed = event.time.difference(_startTime);
                final color = event.level == AttentionLevel.lost
                    ? AppColors.lost
                    : AppColors.drifting;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 6, height: 6,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${elapsed.inMinutes}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontFamily: 'Consolas', fontSize: 11,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        event.level == AttentionLevel.lost ? 'FOCUS LOST' : 'DRIFT DETECTED',
                        style: TextStyle(
                          fontFamily: 'Consolas', fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0, color: color,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'focus: ${(event.focusScore * 100).round()}%',
                        style: const TextStyle(
                          fontFamily: 'Consolas', fontSize: 10,
                          color: AppColors.outline,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildSessionEnded() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.stop_circle_outlined, size: 64, color: AppColors.outline),
          const SizedBox(height: 20),
          const Text(
            'SESSION ENDED',
            style: TextStyle(
              fontFamily: 'Consolas', fontSize: 18,
              fontWeight: FontWeight.w700, letterSpacing: 3.0,
              color: AppColors.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No data received for 15 seconds',
            style: TextStyle(
              fontFamily: 'Georgia', fontSize: 14,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '$_messageCount total readings · ${_interventionEvents.length} interventions',
            style: const TextStyle(
              fontFamily: 'Consolas', fontSize: 12, color: AppColors.outline,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => context.go('/teacher'),
            child: const Text('BACK TO JOIN'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Shared widgets
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
              border: Border(bottom: BorderSide(color: AppColors.outlineVariant, width: 0.5)),
            ),
            child: Text(title,
                style: const TextStyle(
                  fontFamily: 'Consolas', fontSize: 10,
                  fontWeight: FontWeight.w700, letterSpacing: 2.0,
                  color: AppColors.outline,
                )),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _InterventionEvent {
  final DateTime time;
  final AttentionLevel level;
  final double focusScore;
  const _InterventionEvent({required this.time, required this.level, required this.focusScore});
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({required this.history});
  final List<AttentionState> history;

  @override
  void paint(Canvas canvas, Size size) {
    if (history.length < 2) return;

    // Zone backgrounds
    final zonePaint = Paint()..style = PaintingStyle.fill;
    zonePaint.color = AppColors.lost.withValues(alpha: 0.05);
    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.66, size.width, size.height * 0.34), zonePaint);
    zonePaint.color = AppColors.drifting.withValues(alpha: 0.03);
    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.33, size.width, size.height * 0.33), zonePaint);

    // Grid
    final gridPaint = Paint()
      ..color = AppColors.outlineVariant.withValues(alpha: 0.15)
      ..strokeWidth = 0.5;
    for (int i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Line
    final maxPoints = 120;
    final path = Path();
    for (int i = 0; i < history.length; i++) {
      final x = (i / (maxPoints - 1)) * size.width;
      final y = size.height * (1 - history[i].focusScore);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final Color lineColor;
    switch (history.last.level) {
      case AttentionLevel.focused: lineColor = AppColors.focused;
      case AttentionLevel.drifting: lineColor = AppColors.drifting;
      case AttentionLevel.lost: lineColor = AppColors.lost;
    }

    canvas.drawPath(path, Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round);

    // Current dot
    final lastX = ((history.length - 1) / (maxPoints - 1)) * size.width;
    final lastY = size.height * (1 - history.last.focusScore);
    canvas.drawCircle(Offset(lastX, lastY), 4, Paint()..color = lineColor);
    canvas.drawCircle(Offset(lastX, lastY), 7, Paint()
      ..color = lineColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_TimelinePainter old) => true;
}
