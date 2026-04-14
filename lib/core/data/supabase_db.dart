// lib/core/data/supabase_db.dart

import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase data access layer — replaces drift/SQLite for web.
///
/// Provides CRUD operations for sessions, interventions, and baselines
/// using Supabase Postgres via REST API.
class SupabaseDb {
  SupabaseDb._();
  static final instance = SupabaseDb._();

  SupabaseClient get _client => Supabase.instance.client;

  // ── Sessions ──────────────────────────────────────────────

  Future<void> insertSession({
    required String sessionId,
    required String studentName,
    required String topic,
    required String subject,
  }) async {
    await _client.from('sessions').insert({
      'session_id': sessionId,
      'student_name': studentName,
      'topic': topic,
      'subject': subject,
      'started_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> updateSession({
    required String sessionId,
    double? avgFocusScore,
    int? interventionCount,
    int? lessonsCompleted,
    DateTime? endedAt,
  }) async {
    final updates = <String, dynamic>{};
    if (avgFocusScore != null) updates['avg_focus_score'] = avgFocusScore;
    if (interventionCount != null) updates['intervention_count'] = interventionCount;
    if (lessonsCompleted != null) updates['lessons_completed'] = lessonsCompleted;
    if (endedAt != null) updates['ended_at'] = endedAt.toUtc().toIso8601String();

    if (updates.isNotEmpty) {
      await _client.from('sessions').update(updates).eq('session_id', sessionId);
    }
  }

  Future<List<Map<String, dynamic>>> allSessions() async {
    final data = await _client
        .from('sessions')
        .select()
        .order('started_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<Map<String, dynamic>?> sessionById(String sessionId) async {
    final data = await _client
        .from('sessions')
        .select()
        .eq('session_id', sessionId)
        .maybeSingle();
    return data;
  }

  Stream<List<Map<String, dynamic>>> watchSessions() {
    return _client
        .from('sessions')
        .stream(primaryKey: ['session_id'])
        .order('started_at', ascending: false);
  }

  // ── Interventions ─────────────────────────────────────────

  Future<void> insertIntervention({
    required String sessionId,
    required int driftDurationSec,
    required String formatShown,
  }) async {
    await _client.from('interventions').insert({
      'session_id': sessionId,
      'drift_duration_sec': driftDurationSec,
      'format_shown': formatShown,
      'triggered_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> updateIntervention({
    required int id,
    required bool recovered,
    required double reward,
  }) async {
    await _client.from('interventions').update({
      'recovered': recovered,
      'reward': reward,
    }).eq('id', id);
  }

  Future<List<Map<String, dynamic>>> interventionsForSession(String sessionId) async {
    final data = await _client
        .from('interventions')
        .select()
        .eq('session_id', sessionId)
        .order('triggered_at', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  Stream<List<Map<String, dynamic>>> watchInterventions(String sessionId) {
    return _client
        .from('interventions')
        .stream(primaryKey: ['id'])
        .eq('session_id', sessionId)
        .order('triggered_at', ascending: true);
  }

  // ── Baselines ─────────────────────────────────────────────

  Future<void> upsertBaseline({
    required String studentName,
    required double baselineIndex,
    required double theta,
    required double alpha,
    required double beta,
    required double gamma,
  }) async {
    await _client.from('baselines').upsert({
      'student_name': studentName,
      'baseline_index': baselineIndex,
      'theta': theta,
      'alpha': alpha,
      'beta': beta,
      'gamma': gamma,
      'calibrated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>?> baselineForStudent(String studentName) async {
    final data = await _client
        .from('baselines')
        .select()
        .eq('student_name', studentName)
        .maybeSingle();
    return data;
  }
}
