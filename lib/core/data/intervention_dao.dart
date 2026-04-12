// lib/core/data/intervention_dao.dart

import 'package:drift/drift.dart';
import 'database.dart';

part 'intervention_dao.g.dart';

/// Data-access object for the [Interventions] table.
///
/// Records every RL rescue event: what format was shown, how long the student
/// drifted before trigger, whether attention recovered, and the reward signal.
@DriftAccessor(tables: [Interventions])
class InterventionDao extends DatabaseAccessor<AppDatabase>
    with _$InterventionDaoMixin {
  InterventionDao(super.db);

  /// Insert a new intervention event.
  Future<void> insertIntervention(InterventionsCompanion entry) =>
      into(interventions).insert(entry);

  /// Get all interventions for a session (used by session summary screen).
  Future<List<Intervention>> interventionsForSession(String sessionId) =>
      (select(interventions)
            ..where((t) => t.sessionId.equals(sessionId))
            ..orderBy([(t) => OrderingTerm.asc(t.triggeredAt)]))
          .get();

  /// Get all interventions for a student across all sessions.
  /// Used by the RL agent to learn format preferences.
  Future<List<Intervention>> allInterventionsForStudent(
      String studentName) async {
    final query = select(interventions).join([
      innerJoin(
        db.sessions,
        db.sessions.sessionId.equalsExp(interventions.sessionId),
      ),
    ])
      ..where(db.sessions.studentName.equals(studentName))
      ..orderBy([OrderingTerm.desc(interventions.triggeredAt)]);

    final rows = await query.get();
    return rows.map((row) => row.readTable(interventions)).toList();
  }

  /// Count interventions per format for a student (used by bandit agent).
  /// Returns a map like {'flashcard': 12, 'video': 8, 'simulation': 15}.
  Future<Map<String, int>> formatCountsForStudent(
      String studentName) async {
    final all = await allInterventionsForStudent(studentName);
    final counts = <String, int>{};
    for (final i in all) {
      counts[i.formatShown] = (counts[i.formatShown] ?? 0) + 1;
    }
    return counts;
  }

  /// Average reward per format for a student (used by bandit agent).
  /// Returns a map like {'flashcard': -0.3, 'simulation': 0.8}.
  Future<Map<String, double>> avgRewardPerFormat(
      String studentName) async {
    final all = await allInterventionsForStudent(studentName);
    final totals = <String, double>{};
    final counts = <String, int>{};
    for (final i in all) {
      totals[i.formatShown] = (totals[i.formatShown] ?? 0) + i.reward;
      counts[i.formatShown] = (counts[i.formatShown] ?? 0) + 1;
    }
    return totals.map((k, v) => MapEntry(k, v / counts[k]!));
  }

  /// Update an intervention (e.g. set recovered + reward after 60 s check).
  Future<void> updateIntervention(InterventionsCompanion entry) =>
      (update(interventions)..where((t) => t.id.equals(entry.id.value)))
          .write(entry);
}
