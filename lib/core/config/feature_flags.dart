// lib/core/config/feature_flags.dart

/// Central registry of compile-time feature flags.
///
/// Flags use `bool.fromEnvironment` / `String.fromEnvironment` so they can be
/// overridden at build time without editing source:
///
///     flutter run -d chrome --dart-define=USE_EEG_TRIGGER=true
abstract final class FeatureFlags {
  /// When true, the EEG stream drives drift detection in the lesson screen
  /// (normal path — 5-of-10 rolling window + 4s sustain → intervention).
  ///
  /// When false (default), the lesson screen IGNORES the EEG stream for
  /// drift decisions and instead uses the spacebar as the sole trigger.
  /// The EEG stream still flows through normally — the HUD, session
  /// recording, and every other consumer see real (or mock) Crown data.
  /// This stays true even if the Crown is connected and calibrated —
  /// the flag gates the trigger, not the stream.
  ///
  /// Meant as a dev overwrite while the Crown's dry-electrode contact
  /// isn't reliable enough for a real trigger. Connection + calibration
  /// screens are untouched; only the lesson's drift logic changes.
  ///
  /// Override: `flutter run ... --dart-define=USE_EEG_TRIGGER=true`
  static const bool useEegTrigger = bool.fromEnvironment(
    'USE_EEG_TRIGGER',
    defaultValue: false,
  );
}
