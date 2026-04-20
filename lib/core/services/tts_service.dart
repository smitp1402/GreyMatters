// lib/core/services/tts_service.dart

import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;

import '../config/tts_phrase_bank.dart';

/// One-place TTS entry point for the whole app.
///
/// Strategy:
/// - At startup, [prefetchAll] walks every phrase in [TtsPhraseBank] and
///   fires parallel OpenRouter `/audio/speech` calls with a bounded
///   concurrency (so we don't DDoS ourselves). The returned MP3 bytes
///   are cached in memory, keyed by phrase ID.
/// - [speak] looks up the ID and plays cached bytes via `audioplayers`
///   — no network round-trip, no platform-voice drift.
/// - If the ID isn't cached (still in-flight, failed to fetch, or dynamic
///   phrase), it falls back to `flutter_tts.speak(text)` so the user
///   still hears something. No hard dependency on cloud TTS succeeding.
///
/// Instantiate once at app startup, call `prefetchAll()` without
/// awaiting — it fills the cache in the background while the user
/// navigates the first screens.
class TtsService {
  TtsService._();
  static final instance = TtsService._();

  // Direct to OpenAI — OpenRouter's TTS routing for the newer
  // gpt-4o-mini-tts model isn't currently wired (listed but returns
  // "no endpoints found that support the requested output modalities"
  // on their chat-completions path). Direct gives us real MP3 bytes
  // in a single POST with no streaming/PCM-wrapping complexity.
  static const _endpoint = 'https://api.openai.com/v1/audio/speech';
  // How many speech calls we allow in flight at once. OpenAI will
  // accept bursts but being a good citizen costs nothing.
  static const int _maxConcurrency = 6;

  final Map<String, Uint8List> _cache = <String, Uint8List>{};
  final Set<String> _inFlight = <String>{};

  // AudioPlayer is lazy-initialized. On Flutter Web, the audioplayers
  // platform channel init can fail (MissingPluginException) before any
  // call to .play() — if the web plugin registration didn't pick up the
  // new dep yet. By deferring construction to first use, we let the
  // app boot even when audioplayers is broken; playback falls through
  // to flutter_tts via the catch block in `speak`.
  AudioPlayer? _player;
  AudioPlayer _audioPlayer() => _player ??= AudioPlayer();

  // Live fallback when the cloud cache misses or the API key is absent.
  final FlutterTts _fallback = FlutterTts();
  bool _fallbackReady = false;

  bool _prefetchStarted = false;
  bool _prefetchDone = false;
  int _successCount = 0;
  int _failureCount = 0;

  /// True once [prefetchAll] has finished (successful or not).
  bool get isReady => _prefetchDone;

  /// How many phrases were successfully cached.
  int get cachedCount => _successCount;

  /// How many phrases failed to fetch (fall back to flutter_tts on play).
  int get failedCount => _failureCount;

  /// Safe access to a dotenv value. When `dotenv.load()` fails (missing
  /// asset, parse error, web-bundle dotfile issue), the global `dotenv`
  /// singleton is uninitialized and `maybeGet` throws `NotInitializedError`.
  /// This wrapper treats every such failure as "value absent".
  String _envGet(String key, [String fallback = '']) {
    try {
      final value = dotenv.maybeGet(key);
      return value == null || value.isEmpty ? fallback : value;
    } catch (_) {
      return fallback;
    }
  }

  /// Ensure the flutter_tts fallback is configured once.
  Future<void> _ensureFallback() async {
    if (_fallbackReady) return;
    try {
      await _fallback.setLanguage('en-US');
      await _fallback.setSpeechRate(0.5);
      await _fallback.setPitch(1.0);
    } catch (e) {
      // Some platforms throw on setLanguage when no TTS engine — ignore.
      debugPrint('[TtsService] flutter_tts setup warning: $e');
    }
    _fallbackReady = true;
  }

  /// Kick off the background synthesis pass over every phrase in the
  /// bank. Idempotent: calling again is a no-op once started.
  ///
  /// Returns a Future that resolves when the full batch completes,
  /// but you usually don't await it — fire and forget from main().
  Future<void> prefetchAll() async {
    if (_prefetchStarted) return;
    _prefetchStarted = true;

    final apiKey = _envGet('OPENAI_API_KEY');
    if (apiKey.isEmpty) {
      debugPrint(
        '[TtsService] OPENAI_API_KEY missing — skipping prefetch, '
        'everything falls back to flutter_tts.',
      );
      _prefetchDone = true;
      return;
    }

    final model = _envGet('OPENAI_TTS_MODEL', 'gpt-4o-mini-tts');
    final voice = _envGet('OPENAI_TTS_VOICE', 'verse');

    final entries = TtsPhraseBank.allPhrases().entries.toList();
    debugPrint(
      '[TtsService] Prefetching ${entries.length} phrases '
      '(model=$model voice=$voice, concurrency=$_maxConcurrency)...',
    );

    // Bounded-concurrency worker pool. Dart doesn't have a built-in
    // Semaphore, but a list of "slots" with Completers is enough here.
    final iterator = entries.iterator;
    final workers = List<Future<void>>.generate(_maxConcurrency, (_) async {
      while (true) {
        // Atomic pull of the next entry — iterator.moveNext isn't
        // thread-safe in the rare pathological case, but Dart is
        // single-threaded so this is fine.
        if (!iterator.moveNext()) return;
        final entry = iterator.current;
        await _fetchOne(
          id: entry.key,
          text: entry.value,
          apiKey: apiKey,
          model: model,
          voice: voice,
        );
      }
    });

    await Future.wait(workers);
    _prefetchDone = true;
    debugPrint(
      '[TtsService] Prefetch complete: '
      '$_successCount cached, $_failureCount failed.',
    );
  }

  Future<void> _fetchOne({
    required String id,
    required String text,
    required String apiKey,
    required String model,
    required String voice,
  }) async {
    if (_cache.containsKey(id) || _inFlight.contains(id)) return;
    _inFlight.add(id);
    try {
      final resp = await http.post(
        Uri.parse(_endpoint),
        headers: <String, String>{
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{
          'model': model,
          'input': text,
          'voice': voice,
          'response_format': 'mp3',
        }),
      );

      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        _cache[id] = resp.bodyBytes;
        _successCount++;
      } else {
        _failureCount++;
        debugPrint(
          '[TtsService] Fetch failed id=$id status=${resp.statusCode} '
          'body=${resp.body.length > 200 ? '${resp.body.substring(0, 200)}…' : resp.body}',
        );
      }
    } catch (e) {
      _failureCount++;
      debugPrint('[TtsService] Fetch error id=$id: $e');
    } finally {
      _inFlight.remove(id);
    }
  }

  /// Play the cached audio for [phraseId]. If not cached (still fetching,
  /// fetch failed, or ID not in bank), falls back to the platform TTS
  /// speaking whatever text is registered for the ID — or nothing, if
  /// the ID is unknown and no override text was passed.
  ///
  /// [overrideText] lets dynamic content (session code readout, etc.) go
  /// through this single service — there's no cache to hit, but the
  /// platform fallback will speak the passed string.
  Future<void> speak(String phraseId, {String? overrideText}) async {
    final bytes = _cache[phraseId];
    if (bytes != null) {
      try {
        final player = _audioPlayer();
        // Stop any currently-playing clip so successive speak() calls
        // don't overlap (same semantic as flutter_tts.speak replacing
        // the current utterance).
        await player.stop();
        await player.play(BytesSource(bytes, mimeType: 'audio/mpeg'));
        return;
      } catch (e) {
        debugPrint('[TtsService] Playback error for $phraseId: $e');
        // Fall through to fallback path.
      }
    }

    await _ensureFallback();
    final text = overrideText ?? TtsPhraseBank.textFor(phraseId);
    if (text == null || text.isEmpty) {
      debugPrint('[TtsService] No text for id=$phraseId and no override');
      return;
    }
    try {
      await _fallback.stop();
      await _fallback.speak(text);
    } catch (e) {
      debugPrint('[TtsService] Fallback speak error: $e');
    }
  }

  /// Speak [phraseId] AND block until playback ends.
  ///
  /// Used when the UI needs to sequence a "say this, then do that" flow
  /// (e.g. say the last element's name, then fade in the mnemonic finale
  /// overlay). Regular [speak] is fire-and-forget and will return while
  /// audio is still playing — that's fine for most screens but wrong
  /// when the next visual step depends on the clip finishing.
  ///
  /// Completion detection uses `onPlayerStateChanged` rather than
  /// `onPlayerComplete` because the latter is unreliable on Flutter Web
  /// with `BytesSource` (HTML5 Audio's `ended` event doesn't always
  /// fire for blob URLs). We subscribe BEFORE calling `play()` to avoid
  /// racing the state transition.
  ///
  /// Falls back to flutter_tts with a rough word-count-based dwell when
  /// there's no cache entry (first-session misses, fetch failures).
  Future<void> speakAndWait(String phraseId, {String? overrideText}) async {
    final bytes = _cache[phraseId];
    if (bytes == null) {
      debugPrint(
        '[TtsService] speakAndWait: no cache for "$phraseId" '
        '(cached=${_cache.length}, prefetchDone=$_prefetchDone) '
        '— falling back to flutter_tts',
      );
    } else {
      try {
        final player = _audioPlayer();
        debugPrint(
          '[TtsService] speakAndWait "$phraseId" (${bytes.length} bytes)...',
        );

        // Subscribe BEFORE play() so we never miss a fast completed transition.
        final completer = Completer<void>();
        bool playStarted = false;
        late final StreamSubscription<PlayerState> sub;
        sub = player.onPlayerStateChanged.listen((state) {
          if (state == PlayerState.playing) {
            playStarted = true;
          } else if (playStarted &&
              (state == PlayerState.completed ||
                  state == PlayerState.stopped)) {
            if (!completer.isCompleted) completer.complete();
          }
        });

        try {
          await player.play(BytesSource(bytes, mimeType: 'audio/mpeg'));
          // Defensive timeout: some web browsers + blob URL combos never
          // emit a terminal state. Keeps the UI from stalling forever.
          await completer.future.timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint(
                '[TtsService] speakAndWait "$phraseId": '
                'timed out waiting for state=completed; proceeding',
              );
            },
          );
        } finally {
          await sub.cancel();
        }
        return;
      } catch (e) {
        debugPrint(
          '[TtsService] speakAndWait playback error for "$phraseId": $e '
          '— falling back to flutter_tts',
        );
      }
    }

    await _ensureFallback();
    final text = overrideText ?? TtsPhraseBank.textFor(phraseId);
    if (text == null || text.isEmpty) return;
    try {
      await _fallback.stop();
      await _fallback.speak(text);
      // Rough estimate so the caller's sequencing still holds even
      // without a completion callback: ~180 ms per word, clamped.
      final words = text.split(RegExp(r'\s+')).length;
      final ms = (words * 180).clamp(500, 6000);
      await Future<void>.delayed(Duration(milliseconds: ms));
    } catch (e) {
      debugPrint('[TtsService] speakAndWait fallback error: $e');
    }
  }

  /// Stop any currently-playing audio (both cloud + fallback).
  Future<void> stop() async {
    final p = _player;
    if (p != null) {
      try {
        await p.stop();
      } catch (_) {}
    }
    if (_fallbackReady) {
      try {
        await _fallback.stop();
      } catch (_) {}
    }
  }

  /// Free resources — call on app shutdown if you care.
  Future<void> dispose() async {
    final p = _player;
    if (p != null) {
      try {
        await p.dispose();
      } catch (_) {}
    }
    try {
      await _fallback.stop();
    } catch (_) {}
  }
}
