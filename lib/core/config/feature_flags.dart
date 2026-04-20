// lib/core/config/feature_flags.dart

/// Central registry of compile-time feature flags.
///
/// Flags use `bool.fromEnvironment` / `String.fromEnvironment` so they can be
/// overridden at build time without editing source:
///
///     flutter run -d chrome --dart-define=USE_EEG_TRIGGER=true
abstract final class FeatureFlags {
  /// When true (default off), Flutter opens a WebSocket to the EEG daemon
  /// and drives attention state from live Crown data. When false, the
  /// daemon is bypassed entirely: attention state is driven by pressing
  /// the spacebar, which cycles focused → drifting → lost → focused.
  ///
  /// Kept off until the Crown's dry-electrode contact is reliable enough
  /// to deliver real signal. Meant as a presentation cheat — the rest of
  /// the app (HUD, interventions, session recording) sees a normal
  /// `AttentionState` stream and doesn't care where the states come from.
  ///
  /// Override: `flutter run ... --dart-define=USE_EEG_TRIGGER=true`
  static const bool useEegTrigger = bool.fromEnvironment(
    'USE_EEG_TRIGGER',
    defaultValue: false,
  );
}
