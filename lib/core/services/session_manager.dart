// lib/core/services/session_manager.dart

import 'dart:math';

import '../data/supabase_db.dart';
import '../models/attention_state.dart';
import 'realtime_broadcast.dart';

/// Manages session lifecycle — ID generation, Supabase sync, and realtime broadcast.
///
/// Single source of truth for the active session. Coordinates:
///   - Session ID generation (6-char, no-confusion charset)
///   - Supabase session insert/update
///   - Realtime broadcast start/stop (for teacher live monitoring)
///   - Attention snapshot sampling during session
class SessionManager {
  SessionManager._();
  static final instance = SessionManager._();

  static const _codeLength = 6;
  static const _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no I/O/0/1
  static final _random = Random.secure();

  String? _activeSessionId;
  String? _activeStudentId;
  // ignore: unused_field
  String? _activeTopicId;
  DateTime? _sessionStartTime;

  // Snapshot sampling state
  final List<Map<String, dynamic>> _snapshots = [];
  AttentionLevel? _lastLevel;
  int _ticksSinceLastSnapshot = 0;
  int _driftCount = 0;
  double _focusSum = 0;
  double _focusMin = 1.0;
  double _focusMax = 0.0;
  int _focusCount = 0;

  /// The currently active session ID, or null if no session is running.
  String? get activeSessionId => _activeSessionId;

  /// Whether a session is currently active.
  bool get hasActiveSession => _activeSessionId != null;

  /// Start a new session: generate code, insert to Supabase, start broadcast.
  ///
  /// Returns the 6-char session code.
  Future<String> startSession({
    required String studentId,
    required String topicId,
    required String topicName,
    required String subject,
    int? totalSections,
  }) async {
    final sessionId = _generateCode();
    _activeSessionId = sessionId;
    _activeStudentId = studentId;
    _activeTopicId = topicId;
    _sessionStartTime = DateTime.now();

    // Reset stats
    _snapshots.clear();
    _lastLevel = null;
    _ticksSinceLastSnapshot = 0;
    _driftCount = 0;
    _focusSum = 0;
    _focusMin = 1.0;
    _focusMax = 0.0;
    _focusCount = 0;

    // Insert session to Supabase
    try {
      await SupabaseDb.instance.insertSession(
        sessionId: sessionId,
        studentId: studentId,
        topicId: topicId,
        topicName: topicName,
        subject: subject,
        totalSections: totalSections,
      );
    } catch (e) {
      // Supabase unavailable — session still works locally
    }

    // Start realtime broadcast for teacher monitoring
    try {
      await RealtimeBroadcast.instance.startPublishing(sessionId);
    } catch (e) {
      // Broadcast unavailable — local session still works
    }

    return sessionId;
  }

  /// Record calibration baseline for the active session.
  Future<void> recordBaseline({
    required double baselineRatio,
    double? delta,
    double? theta,
    double? alpha,
    double? beta,
    double? gamma,
  }) async {
    if (_activeSessionId == null || _activeStudentId == null) return;

    try {
      await SupabaseDb.instance.insertBaseline(
        sessionId: _activeSessionId!,
        studentId: _activeStudentId!,
        baselineRatio: baselineRatio,
        delta: delta,
        theta: theta,
        alpha: alpha,
        beta: beta,
        gamma: gamma,
      );

      // Also update session with baseline
      // (session table has baseline_ratio column for quick access)
    } catch (e) {
      // Supabase unavailable
    }
  }

  /// Called every 1s with the latest AttentionState.
  /// Handles: broadcast to teacher, snapshot sampling, running stats.
  Future<void> onAttentionState(AttentionState state) async {
    if (_activeSessionId == null) return;

    // Broadcast to teacher via Supabase Realtime
    try {
      await RealtimeBroadcast.instance.publishAttentionState(state);
    } catch (_) {}

    // Update running stats
    _focusSum += state.focusScore;
    _focusCount++;
    if (state.focusScore < _focusMin) _focusMin = state.focusScore;
    if (state.focusScore > _focusMax) _focusMax = state.focusScore;

    // Count drift events (level transitions to drifting/lost)
    if (_lastLevel == AttentionLevel.focused &&
        (state.level == AttentionLevel.drifting || state.level == AttentionLevel.lost)) {
      _driftCount++;
    }
    _lastLevel = state.level;

    // Smart snapshot sampling:
    // - Every 10s during focused
    // - Every 1s during drifting/lost
    // - Always on level transitions
    _ticksSinceLastSnapshot++;
    final isTransition = _snapshots.isNotEmpty && _lastLevel != state.level;
    final shouldSample = isTransition ||
        (state.level != AttentionLevel.focused && _ticksSinceLastSnapshot >= 1) ||
        (_ticksSinceLastSnapshot >= 10) ||
        (_snapshots.isEmpty); // always capture first

    if (shouldSample) {
      _ticksSinceLastSnapshot = 0;
      _snapshots.add({
        'session_id': _activeSessionId,
        'focus_score': state.focusScore,
        'delta': state.delta,
        'theta': state.theta,
        'alpha': state.alpha,
        'beta': state.beta,
        'gamma': state.gamma,
        'level': state.level.name,
        'beta_theta': state.betaTheta,
        'theta_alpha': state.thetaAlpha,
        'beta_alpha_theta': state.betaAlphaTheta,
        'recorded_at': DateTime.now().toUtc().toIso8601String(),
      });
    }
  }

  /// Record an intervention trigger. Returns the intervention ID.
  Future<String?> recordIntervention({
    required String format,
    required String triggerLevel,
    int? driftDurationSec,
    double? focusBefore,
  }) async {
    if (_activeSessionId == null || _activeStudentId == null) return null;

    try {
      final data = await SupabaseDb.instance.insertIntervention(
        sessionId: _activeSessionId!,
        studentId: _activeStudentId!,
        format: format,
        triggerLevel: triggerLevel,
        driftDurationSec: driftDurationSec,
        focusBefore: focusBefore,
      );
      return data['id'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Record intervention outcome.
  Future<void> completeIntervention({
    required String interventionId,
    required bool recovered,
    required double reward,
    double? focusAfter,
  }) async {
    try {
      await SupabaseDb.instance.completeIntervention(
        interventionId: interventionId,
        recovered: recovered,
        reward: reward,
        focusAfter: focusAfter,
      );
    } catch (_) {}
  }

  /// End the current session: sync final stats + snapshots to Supabase.
  Future<void> endSession({int sectionsCompleted = 0}) async {
    if (_activeSessionId == null) return;

    final durationSec = _sessionStartTime != null
        ? DateTime.now().difference(_sessionStartTime!).inSeconds
        : 0;

    final avgFocus = _focusCount > 0 ? _focusSum / _focusCount : 0.0;

    // Update session in Supabase
    try {
      await SupabaseDb.instance.endSession(
        sessionId: _activeSessionId!,
        avgFocusScore: avgFocus,
        minFocusScore: _focusMin,
        maxFocusScore: _focusMax,
        driftCount: _driftCount,
        interventionCount: 0, // TODO: track intervention count
        sectionsCompleted: sectionsCompleted,
        durationSec: durationSec,
      );
    } catch (_) {}

    // Batch insert attention snapshots
    try {
      if (_snapshots.isNotEmpty) {
        await SupabaseDb.instance.insertSnapshots(_snapshots);
      }
    } catch (_) {}

    // Stop realtime broadcast
    try {
      await RealtimeBroadcast.instance.stopPublishing();
    } catch (_) {}

    // Reset state
    _activeSessionId = null;
    _activeStudentId = null;
    _activeTopicId = null;
    _sessionStartTime = null;
    _snapshots.clear();
  }

  /// Abandon session (app closed unexpectedly).
  Future<void> abandonSession() async {
    if (_activeSessionId == null) return;

    try {
      await SupabaseDb.instance.abandonSession(_activeSessionId!);
    } catch (_) {}

    try {
      await RealtimeBroadcast.instance.stopPublishing();
    } catch (_) {}

    _activeSessionId = null;
    _activeStudentId = null;
    _activeTopicId = null;
    _sessionStartTime = null;
    _snapshots.clear();
  }

  /// Generate a random 6-char code (no confusing chars).
  String _generateCode() => String.fromCharCodes(
        Iterable.generate(
          _codeLength,
          (_) => _codeChars.codeUnitAt(_random.nextInt(_codeChars.length)),
        ),
      );
}
