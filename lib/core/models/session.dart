// lib/core/models/session.dart
// FROZEN — do not change without agreement from BOTH Smit and Felipe

/// A learning session — one student, one topic, one Crown connection.
///
/// Created when the student taps "Start Session" and finalised when
/// the session ends (content complete or time limit reached).
class Session {
  final String sessionId; // 6-char code e.g. 'abc123'
  final String studentName;
  final String topic; // e.g. 'DNA Replication'
  final String subject; // 'Biology' | 'Chemistry'
  final DateTime startedAt;
  final DateTime? endedAt;
  final double avgFocusScore;
  final int interventionCount;
  final int lessonsCompleted;

  const Session({
    required this.sessionId,
    required this.studentName,
    required this.topic,
    required this.subject,
    required this.startedAt,
    this.endedAt,
    this.avgFocusScore = 0.0,
    this.interventionCount = 0,
    this.lessonsCompleted = 0,
  });

  /// Create a copy with updated fields (immutable update pattern).
  Session copyWith({
    DateTime? endedAt,
    double? avgFocusScore,
    int? interventionCount,
    int? lessonsCompleted,
  }) =>
      Session(
        sessionId: sessionId,
        studentName: studentName,
        topic: topic,
        subject: subject,
        startedAt: startedAt,
        endedAt: endedAt ?? this.endedAt,
        avgFocusScore: avgFocusScore ?? this.avgFocusScore,
        interventionCount: interventionCount ?? this.interventionCount,
        lessonsCompleted: lessonsCompleted ?? this.lessonsCompleted,
      );

  factory Session.fromJson(Map<String, dynamic> j) => Session(
        sessionId: j['session_id'] as String,
        studentName: j['student_name'] as String,
        topic: j['topic'] as String,
        subject: j['subject'] as String,
        startedAt: DateTime.parse(j['started_at'] as String),
        endedAt: j['ended_at'] != null
            ? DateTime.parse(j['ended_at'] as String)
            : null,
        avgFocusScore: (j['avg_focus_score'] as num?)?.toDouble() ?? 0.0,
        interventionCount: (j['intervention_count'] as num?)?.toInt() ?? 0,
        lessonsCompleted: (j['lessons_completed'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'student_name': studentName,
        'topic': topic,
        'subject': subject,
        'started_at': startedAt.toIso8601String(),
        'ended_at': endedAt?.toIso8601String(),
        'avg_focus_score': avgFocusScore,
        'intervention_count': interventionCount,
        'lessons_completed': lessonsCompleted,
      };

  @override
  String toString() =>
      'Session(id=$sessionId, student=$studentName, topic=$topic)';
}
