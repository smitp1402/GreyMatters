// lib/core/config/tts_phrase_bank.dart

import '../models/element_data.dart';

/// Registry of every static phrase the app speaks.
///
/// On app startup, [TtsService] walks `allPhrases` and fires parallel
/// OpenRouter calls to synthesize each one, caching the returned audio
/// bytes in memory. At playback time the app looks up the ID and plays
/// the cached bytes — no network round-trip.
///
/// Add a new phrase here, use `TtsService.instance.speak(id)` at the
/// callsite, and it automatically benefits from the prefetch cache.
///
/// Dynamic phrases (e.g. session code readout, which embeds a random
/// 6-char code) can't be prefetched — leave those on `flutter_tts` as
/// a live fallback until we find a good way to compose them.
abstract final class TtsPhraseBank {
  // ── Keys used by screens to look up phrases ────────────────────

  static const String crownSearch = 'crown.search';
  static const String crownConnected = 'crown.connected';
  static const String calibrationPrepare = 'calibration.prepare';
  static const String calibrationBegin = 'calibration.begin';
  static const String calibrationComplete = 'calibration.complete';
  static const String mnemonicPeriod12 = 'mnemonic.period_1_2';

  /// Per-element phrase ID. Symbol is the 1-2 char atomic symbol
  /// (H, He, Li, …, Og). Uppercase-sensitive to match `allElements`.
  static String element(String symbol) => 'element.$symbol';

  // ── Canonical phrase text ─────────────────────────────────────

  static const Map<String, String> _staticPhrases = <String, String>{
    crownSearch: "Let's connect your headset",
    crownConnected: 'Neural link established. Preparing calibration.',
    calibrationPrepare: 'Prepare for calibration. Sit comfortably and relax.',
    calibrationBegin:
        'Focus on the dot. Breathe normally. Calibration begins now.',
    calibrationComplete: 'Calibration complete. Baseline established.',
    mnemonicPeriod12:
        'Happy Henry Likes Beer But Could Not Obtain Food Nearby.',
  };

  /// Returns every phrase the prefetcher should synthesize. Keys are
  /// the phrase IDs used by `TtsService.speak(id)`; values are the
  /// text sent to the TTS API.
  static Map<String, String> allPhrases() {
    final result = <String, String>{..._staticPhrases};
    for (final e in allElements) {
      result[element(e.symbol)] = e.name;
    }
    return result;
  }

  /// Fallback text for when a cache miss happens — lets the fallback
  /// path (`flutter_tts.speak`) still say something sensible.
  static String? textFor(String id) => allPhrases()[id];
}
