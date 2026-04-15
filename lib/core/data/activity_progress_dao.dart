// lib/core/data/activity_progress_dao.dart

import 'package:drift/drift.dart';
import 'database.dart';

part 'activity_progress_dao.g.dart';

/// Data-access object for the [ActivityProgressTable].
///
/// Tracks persistent scores for topic-specific activities like
/// Synthetic Alchemist. Scores accumulate across all sessions.
@DriftAccessor(tables: [ActivityProgressTable])
class ActivityProgressDao extends DatabaseAccessor<AppDatabase>
    with _$ActivityProgressDaoMixin {
  ActivityProgressDao(super.db);

  /// Get current total score for an activity+student combo.
  /// Returns 0 if no row exists.
  Future<int> getScore(String activityId, String studentName) async {
    final query = select(activityProgressTable)
      ..where((t) =>
          t.activityId.equals(activityId) &
          t.studentName.equals(studentName));
    final row = await query.getSingleOrNull();
    return row?.totalScore ?? 0;
  }

  /// Increment the total score by [amount] and update lastPlayedAt.
  /// Creates a new row if none exists (upsert).
  Future<void> incrementScore(
    String activityId,
    String studentName,
    int amount,
  ) async {
    final query = select(activityProgressTable)
      ..where((t) =>
          t.activityId.equals(activityId) &
          t.studentName.equals(studentName));
    final existing = await query.getSingleOrNull();

    if (existing != null) {
      (update(activityProgressTable)
            ..where((t) => t.id.equals(existing.id)))
          .write(ActivityProgressTableCompanion(
        totalScore: Value(existing.totalScore + amount),
        lastPlayedAt: Value(DateTime.now()),
      ));
    } else {
      into(activityProgressTable).insert(ActivityProgressTableCompanion.insert(
        activityId: activityId,
        studentName: studentName,
        totalScore: Value(amount),
        lastPlayedAt: DateTime.now(),
      ));
    }
  }
}
