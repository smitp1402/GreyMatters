// lib/core/models/attention_state.dart
// FROZEN — do not change without agreement from BOTH Smit and Felipe

/// Cognitive attention level derived from EEG band power ratios.
enum AttentionLevel { focused, drifting, lost }

/// A single attention reading emitted by the EEG daemon every ~1 second.
///
/// The daemon computes [focusScore] from the beta/theta ratio — the
/// FDA-validated EEG marker for sustained attention — normalised against
/// a 30-second calibration baseline captured at session start.
///
/// Signal processing pipeline (daemon side):
///   1. All 8 Crown channels filtered (2-45 Hz bandpass + 50/60 Hz notch)
///   2. Welch PSD → 5 band powers (delta, theta, alpha, beta, gamma)
///   3. Median across channels (robust to single noisy electrode)
///   4. beta/theta ratio normalised against calibration baseline
///
/// Classification thresholds (on normalised beta/theta):
///   focused  → ratio ≥ 1.0× baseline
///   drifting → ratio 0.5–1.0× baseline (2 consecutive windows)
///   lost     → ratio < 0.5× baseline   (2 consecutive windows)
class AttentionState {
  final String sessionId;
  final double focusScore; // 0.0 – 1.0 (1 = fully focused)
  final double delta; // 2–4 Hz band power (normalised proportion)
  final double theta; // 4–8 Hz band power
  final double alpha; // 8–12 Hz band power
  final double beta; // 12–30 Hz band power
  final double gamma; // 30–45 Hz band power
  final AttentionLevel level;
  final DateTime timestamp;

  // Focus ratios (raw, not normalised)
  final double thetaAlpha; // theta / alpha — higher = drowsy/drifting
  final double betaTheta; // beta / theta — higher = focused (primary metric)
  final double betaAlphaTheta; // beta / (alpha + theta) — higher = engaged

  // Per-channel signal quality (0-100%), keyed by channel label
  final Map<String, double> signalQuality;

  const AttentionState({
    required this.sessionId,
    required this.focusScore,
    required this.delta,
    required this.theta,
    required this.alpha,
    required this.beta,
    required this.gamma,
    required this.level,
    required this.timestamp,
    required this.thetaAlpha,
    required this.betaTheta,
    required this.betaAlphaTheta,
    required this.signalQuality,
  });

  /// Deserialise from WebSocket JSON emitted by the Python daemon.
  factory AttentionState.fromJson(Map<String, dynamic> j) => AttentionState(
        sessionId: j['session_id'] as String,
        focusScore: (j['focus_score'] as num).toDouble(),
        delta: (j['delta'] as num?)?.toDouble() ?? 0.0,
        theta: (j['theta'] as num).toDouble(),
        alpha: (j['alpha'] as num).toDouble(),
        beta: (j['beta'] as num).toDouble(),
        gamma: (j['gamma'] as num).toDouble(),
        level: AttentionLevel.values.byName(j['level'] as String),
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          ((j['timestamp'] as num).toDouble() * 1000).toInt(),
        ),
        thetaAlpha: (j['theta_alpha'] as num?)?.toDouble() ?? 0.0,
        betaTheta: (j['beta_theta'] as num?)?.toDouble() ?? 0.0,
        betaAlphaTheta: (j['beta_alpha_theta'] as num?)?.toDouble() ?? 0.0,
        signalQuality: (j['signal_quality'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, (v as num).toDouble()),
            ) ??
            const {},
      );

  /// Serialise to JSON (used for local persistence and Supabase sync).
  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'focus_score': focusScore,
        'delta': delta,
        'theta': theta,
        'alpha': alpha,
        'beta': beta,
        'gamma': gamma,
        'level': level.name,
        'timestamp': timestamp.millisecondsSinceEpoch / 1000,
        'theta_alpha': thetaAlpha,
        'beta_theta': betaTheta,
        'beta_alpha_theta': betaAlphaTheta,
        'signal_quality': signalQuality,
      };

  @override
  String toString() =>
      'AttentionState(session=$sessionId, focus=$focusScore, level=$level, β/θ=$betaTheta)';
}
