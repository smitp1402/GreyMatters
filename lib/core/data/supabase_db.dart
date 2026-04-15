// lib/core/data/supabase_db.dart

import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase data access layer for GreyMatters.
///
/// Maps to the schema in supabase/migrations/001_full_schema.sql.
/// Tables: profiles, sessions, attention_snapshots, interventions, baselines, teacher_monitors
/// Views: student_topic_stats, student_summary, intervention_efficacy, teacher_student_overview
class SupabaseDb {
  SupabaseDb._();
  static final instance = SupabaseDb._();

  SupabaseClient get _client => Supabase.instance.client;

  // ── Profiles ────────────────────────────────────────────────

  /// Create or update a profile by device_id.
  Future<Map<String, dynamic>> upsertProfile({
    required String deviceId,
    required String name,
    required String role,
    String? gradeLevel,
    String? avatarUrl,
    List<String> subjects = const [],
  }) async {
    final data = await _client.from('profiles').upsert(
      {
        'device_id': deviceId,
        'name': name,
        'role': role,
        'grade_level': gradeLevel,
        'avatar_url': avatarUrl,
        'subjects': subjects,
      },
      onConflict: 'device_id',
    ).select().single();
    return data;
  }

  /// Get profile by device_id. Returns null if not found.
  Future<Map<String, dynamic>?> profileByDeviceId(String deviceId) async {
    return await _client
        .from('profiles')
        .select()
        .eq('device_id', deviceId)
        .maybeSingle();
  }

  /// Get profile by UUID.
  Future<Map<String, dynamic>?> profileById(String id) async {
    return await _client
        .from('profiles')
        .select()
        .eq('id', id)
        .maybeSingle();
  }

  // ── Sessions ────────────────────────────────────────────────

  /// Insert a new session at session start.
  Future<void> insertSession({
    required String sessionId,
    required String studentId,
    required String topicId,
    required String topicName,
    required String subject,
    int? totalSections,
    double? baselineRatio,
  }) async {
    await _client.from('sessions').insert({
      'id': sessionId,
      'student_id': studentId,
      'topic_id': topicId,
      'topic_name': topicName,
      'subject': subject,
      'total_sections': totalSections,
      'baseline_ratio': baselineRatio,
      'status': 'active',
    });
  }

  /// Update session with final stats when it ends.
  Future<void> endSession({
    required String sessionId,
    required double avgFocusScore,
    double? minFocusScore,
    double? maxFocusScore,
    required int driftCount,
    required int interventionCount,
    required int sectionsCompleted,
    required int durationSec,
  }) async {
    await _client.from('sessions').update({
      'ended_at': DateTime.now().toUtc().toIso8601String(),
      'avg_focus_score': avgFocusScore,
      'min_focus_score': minFocusScore,
      'max_focus_score': maxFocusScore,
      'drift_count': driftCount,
      'intervention_count': interventionCount,
      'sections_completed': sectionsCompleted,
      'duration_sec': durationSec,
      'status': 'completed',
    }).eq('id', sessionId);
  }

  /// Mark session as abandoned (e.g., app closed mid-session).
  Future<void> abandonSession(String sessionId) async {
    await _client.from('sessions').update({
      'ended_at': DateTime.now().toUtc().toIso8601String(),
      'status': 'abandoned',
    }).eq('id', sessionId);
  }

  /// Get active session by ID (for teacher joining).
  Future<Map<String, dynamic>?> activeSessionById(String sessionId) async {
    return await _client
        .from('sessions')
        .select('*, profiles!sessions_student_id_fkey(name)')
        .eq('id', sessionId)
        .eq('status', 'active')
        .maybeSingle();
  }

  /// All sessions for a student, newest first.
  Future<List<Map<String, dynamic>>> sessionsForStudent(String studentId) async {
    final data = await _client
        .from('sessions')
        .select()
        .eq('student_id', studentId)
        .order('started_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  // ── Attention Snapshots ─────────────────────────────────────

  /// Batch insert sampled attention snapshots after session ends.
  Future<void> insertSnapshots(List<Map<String, dynamic>> snapshots) async {
    if (snapshots.isEmpty) return;
    await _client.from('attention_snapshots').insert(snapshots);
  }

  /// Get snapshots for a session (for focus timeline).
  Future<List<Map<String, dynamic>>> snapshotsForSession(String sessionId) async {
    final data = await _client
        .from('attention_snapshots')
        .select()
        .eq('session_id', sessionId)
        .order('recorded_at', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  // ── Interventions ───────────────────────────────────────────

  /// Insert intervention when triggered.
  Future<Map<String, dynamic>> insertIntervention({
    required String sessionId,
    required String studentId,
    required String format,
    required String triggerLevel,
    int? driftDurationSec,
    double? focusBefore,
  }) async {
    final data = await _client.from('interventions').insert({
      'session_id': sessionId,
      'student_id': studentId,
      'format': format,
      'trigger_level': triggerLevel,
      'drift_duration_sec': driftDurationSec,
      'focus_before': focusBefore,
    }).select().single();
    return data;
  }

  /// Update intervention with outcome after recovery measurement.
  Future<void> completeIntervention({
    required String interventionId,
    required bool recovered,
    required double reward,
    double? focusAfter,
  }) async {
    await _client.from('interventions').update({
      'recovered': recovered,
      'reward': reward,
      'focus_after': focusAfter,
      'completed_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', interventionId);
  }

  /// All interventions for a session.
  Future<List<Map<String, dynamic>>> interventionsForSession(String sessionId) async {
    final data = await _client
        .from('interventions')
        .select()
        .eq('session_id', sessionId)
        .order('triggered_at', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Watch interventions for a session in realtime (teacher feed).
  Stream<List<Map<String, dynamic>>> watchInterventions(String sessionId) {
    return _client
        .from('interventions')
        .stream(primaryKey: ['id'])
        .eq('session_id', sessionId)
        .order('triggered_at', ascending: true);
  }

  // ── Baselines ───────────────────────────────────────────────

  /// Insert calibration baseline.
  Future<void> insertBaseline({
    required String sessionId,
    required String studentId,
    required double baselineRatio,
    double? delta,
    double? theta,
    double? alpha,
    double? beta,
    double? gamma,
  }) async {
    await _client.from('baselines').insert({
      'session_id': sessionId,
      'student_id': studentId,
      'baseline_ratio': baselineRatio,
      'delta': delta,
      'theta': theta,
      'alpha': alpha,
      'beta': beta,
      'gamma': gamma,
    });
  }

  /// Latest baseline for a student.
  Future<Map<String, dynamic>?> latestBaseline(String studentId) async {
    final data = await _client
        .from('baselines')
        .select()
        .eq('student_id', studentId)
        .order('calibrated_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return data;
  }

  // ── Teacher Monitors ────────────────────────────────────────

  /// Record that a teacher joined a session.
  Future<void> joinSession({
    required String teacherId,
    required String sessionId,
    required String studentId,
  }) async {
    await _client.from('teacher_monitors').upsert(
      {
        'teacher_id': teacherId,
        'session_id': sessionId,
        'student_id': studentId,
      },
      onConflict: 'teacher_id,session_id',
    );
  }

  /// Record that a teacher left a session.
  Future<void> leaveSession({
    required String teacherId,
    required String sessionId,
  }) async {
    await _client.from('teacher_monitors').update({
      'left_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('teacher_id', teacherId).eq('session_id', sessionId);
  }

  // ── Profile Queries ──────────────────────────────────────────

  /// All student profiles (for teacher dashboard).
  Future<List<Map<String, dynamic>>> allStudentProfiles() async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('role', 'student')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  /// All currently active sessions (for showing LIVE badges).
  Future<List<Map<String, dynamic>>> allActiveSessions() async {
    final data = await _client
        .from('sessions')
        .select()
        .eq('status', 'active');
    return List<Map<String, dynamic>>.from(data);
  }

  // ── Computed Views (read-only) ──────────────────────────────

  /// Student dashboard: per-topic stats.
  Future<List<Map<String, dynamic>>> studentTopicStats(String studentId) async {
    final data = await _client
        .from('student_topic_stats')
        .select()
        .eq('student_id', studentId);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Student summary for header greeting.
  Future<Map<String, dynamic>?> studentSummary(String studentId) async {
    return await _client
        .from('student_summary')
        .select()
        .eq('student_id', studentId)
        .maybeSingle();
  }

  /// Intervention efficacy — best format per topic.
  Future<List<Map<String, dynamic>>> interventionEfficacy(String studentId) async {
    final data = await _client
        .from('intervention_efficacy')
        .select()
        .eq('student_id', studentId)
        .eq('format_rank', 1);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Teacher's student overview — all students they've monitored.
  Future<List<Map<String, dynamic>>> teacherStudentOverview(String teacherId) async {
    final data = await _client
        .from('teacher_student_overview')
        .select()
        .eq('teacher_id', teacherId)
        .order('last_monitored_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }
}
