// lib/core/models/attention_state.dart
// FROZEN — do not change without agreement from BOTH Smit and Felipe

/// Cognitive attention level derived from EEG band power ratios.
enum AttentionLevel { focused, drifting, lost }

/// A single attention reading emitted by the EEG daemon every ~1 second.
///
/// The daemon computes [focusScore] as a normalised attention index:
///   attention_index = (theta + alpha) / beta
///   normalised against personal baseline (30 s calibration at session start).
///
/// Classification thresholds:
///   focused  → index ≤ 1.5× baseline
///   drifting → index 1.5–2.2× baseline (2 consecutive windows)
///   lost     → index > 2.2× baseline   (2 consecutive windows)
class AttentionState {
  final String sessionId;
  final double focusScore; // 0.0 – 1.0 (1 = fully focused)
  final double theta; // 4–8 Hz band power
  final double alpha; // 8–13 Hz band power
  final double beta; // 13–30 Hz band power
  final double gamma; // 30–45 Hz band power
  final AttentionLevel level;
  final DateTime timestamp;

  const AttentionState({
    required this.sessionId,
    required this.focusScore,
    required this.theta,
    required this.alpha,
    required this.beta,
    required this.gamma,
    required this.level,
    required this.timestamp,
  });

  /// Deserialise from WebSocket JSON emitted by the Python daemon.
  ///
  /// Expected keys: session_id, focus_score, theta, alpha, beta, gamma,
  /// level ("focused" | "drifting" | "lost"), timestamp (unix seconds).
  factory AttentionState.fromJson(Map<String, dynamic> j) => AttentionState(
        sessionId: j['session_id'] as String,
        focusScore: (j['focus_score'] as num).toDouble(),
        theta: (j['theta'] as num).toDouble(),
        alpha: (j['alpha'] as num).toDouble(),
        beta: (j['beta'] as num).toDouble(),
        gamma: (j['gamma'] as num).toDouble(),
        level: AttentionLevel.values.byName(j['level'] as String),
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          ((j['timestamp'] as num).toDouble() * 1000).toInt(),
        ),
      );

  /// Serialise to JSON (used for local persistence and Supabase sync).
  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'focus_score': focusScore,
        'theta': theta,
        'alpha': alpha,
        'beta': beta,
        'gamma': gamma,
        'level': level.name,
        'timestamp': timestamp.millisecondsSinceEpoch / 1000,
      };

  @override
  String toString() =>
      'AttentionState(session=$sessionId, focus=$focusScore, level=$level)';
}
