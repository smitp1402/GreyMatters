// lib/core/services/demo_attention_controller.dart

import '../models/attention_state.dart';
import 'attention_stream.dart';

/// Keyboard-driven attention state source for presentation/demo mode.
///
/// When [FeatureFlags.useEegTrigger] is off, the Crown is bypassed and
/// this controller generates [AttentionState] snapshots directly into
/// [AttentionStream] — one per spacebar press. Downstream widgets (HUD,
/// teacher monitor, session recorder) consume the same stream they'd
/// consume from the real daemon, so no other code has to know we're
/// faking it.
///
/// The cycle is: focused → drifting → lost → focused → …
///
/// Typical use:
/// - On startup: call [emitInitial] once so the connection screen
///   receives a frame and advances past "searching".
/// - On spacebar: call [cycleState] which advances by one and emits.
/// - On session change: call [setSessionId] so emitted states carry
///   the right session ID.
class DemoAttentionController {
  DemoAttentionController._();
  static final instance = DemoAttentionController._();

  // The cycle order matches what a student would actually experience:
  // engaged first, then drift, then lost, then back to engaged.
  static const _cycle = <AttentionLevel>[
    AttentionLevel.focused,
    AttentionLevel.drifting,
    AttentionLevel.lost,
  ];

  int _index = 0;
  String _sessionId = 'demo';

  /// Current level (synchronous read for any debug UI that wants it).
  AttentionLevel get currentLevel => _cycle[_index];

  /// Set the session ID that future emitted states will carry.
  /// The session-code / debug-stream screens call this on mount.
  void setSessionId(String id) {
    _sessionId = id;
  }

  /// Emit the current level without advancing — used on startup so the
  /// crown-connection screen's "first message received" gate fires.
  void emitInitial() => _emitCurrent();

  /// Advance to the next level and emit. Called by the spacebar shortcut.
  /// Logs to debugPrint in debug builds so you can see it fire from the
  /// console while presenting.
  void cycleState() {
    _index = (_index + 1) % _cycle.length;
    _emitCurrent();
  }

  /// Reset to focused without emitting. Used on session boundary.
  void reset() {
    _index = 0;
  }

  void _emitCurrent() {
    final level = _cycle[_index];

    // Band power proportions that roughly track the level. Not real EEG —
    // just plausible-looking numbers so dashboards showing band bars
    // don't all show identical values across states.
    final double delta, theta, alpha, beta, gamma, focusScore;
    switch (level) {
      case AttentionLevel.focused:
        delta = 0.10;
        theta = 0.15;
        alpha = 0.20;
        beta = 0.45;
        gamma = 0.10;
        focusScore = 0.85;
      case AttentionLevel.drifting:
        delta = 0.15;
        theta = 0.30;
        alpha = 0.25;
        beta = 0.25;
        gamma = 0.05;
        focusScore = 0.50;
      case AttentionLevel.lost:
        delta = 0.25;
        theta = 0.40;
        alpha = 0.20;
        beta = 0.10;
        gamma = 0.05;
        focusScore = 0.15;
    }

    final state = AttentionState(
      sessionId: _sessionId,
      focusScore: focusScore,
      delta: delta,
      theta: theta,
      alpha: alpha,
      beta: beta,
      gamma: gamma,
      level: level,
      timestamp: DateTime.now(),
      // Ratios derived from the band values above so they're internally
      // consistent — higher β/θ for focused, lower for lost.
      thetaAlpha: theta / alpha,
      betaTheta: beta / theta,
      betaAlphaTheta: beta / (alpha + theta),
      // All 8 Crown channels at "good" quality (85%) so the connection
      // screen's dot indicator shows green across the board.
      signalQuality: const <String, double>{
        'CP3': 85.0,
        'C3': 85.0,
        'F5': 85.0,
        'PO3': 85.0,
        'PO4': 85.0,
        'F6': 85.0,
        'C4': 85.0,
        'CP4': 85.0,
      },
    );

    AttentionStream.instance.emit(state);
  }
}
