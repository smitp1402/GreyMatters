// lib/core/data/session_dao.dart

import 'package:drift/drift.dart';
import 'database.dart';

part 'session_dao.g.dart';

/// Data-access object for the [Sessions] table.
///
/// Provides CRUD operations for learning sessions.
@DriftAccessor(tables: [Sessions])
class SessionDao extends DatabaseAccessor<AppDatabase>
    with _$SessionDaoMixin {
  SessionDao(super.db);

  /// Insert a new session row.
  Future<void> insertSession(SessionsCompanion entry) =>
      into(sessions).insert(entry);

  /// Get all sessions, most recent first.
  Future<List<Session>> allSessions() =>
      (select(sessions)..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
          .get();

  /// Get a single session by its 6-char code.
  Future<Session?> sessionById(String id) =>
      (select(sessions)..where((t) => t.sessionId.equals(id)))
          .getSingleOrNull();

  /// Get all sessions for a specific student.
  Future<List<Session>> sessionsForStudent(String name) =>
      (select(sessions)
            ..where((t) => t.studentName.equals(name))
            ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
          .get();

  /// Get sessions for a specific topic (used by home dashboard to rank topics).
  Future<List<Session>> sessionsForTopic(String topic) =>
      (select(sessions)
            ..where((t) => t.topic.equals(topic))
            ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
          .get();

  /// Update a session (e.g. set endedAt, avgFocusScore at session end).
  Future<void> updateSession(SessionsCompanion entry) =>
      (update(sessions)
            ..where((t) => t.sessionId.equals(entry.sessionId.value)))
          .write(entry);

  /// Watch all sessions as a reactive stream (rebuilds UI on changes).
  Stream<List<Session>> watchAllSessions() =>
      (select(sessions)..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
          .watch();
}
