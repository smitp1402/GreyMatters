// lib/core/data/database.dart

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'session_dao.dart';
import 'intervention_dao.dart';

part 'database.g.dart';

// ---------------------------------------------------------------------------
// Table definitions
// ---------------------------------------------------------------------------

/// Learning sessions — one row per "Start Session" tap.
class Sessions extends Table {
  TextColumn get sessionId => text().withLength(min: 6, max: 6)();
  TextColumn get studentName => text()();
  TextColumn get topic => text()();
  TextColumn get subject => text()(); // 'Biology' | 'Chemistry'
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  RealColumn get avgFocusScore => real().withDefault(const Constant(0.0))();
  IntColumn get interventionCount =>
      integer().withDefault(const Constant(0))();
  IntColumn get lessonsCompleted =>
      integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {sessionId};
}

/// Intervention events — one row per RL rescue triggered during a session.
class Interventions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sessionId =>
      text().references(Sessions, #sessionId)();
  DateTimeColumn get triggeredAt => dateTime()();
  IntColumn get driftDurationSec => integer()(); // seconds drifting before trigger
  TextColumn get formatShown => text()(); // flashcard|video|simulation|voice|gesture|curiosity_bomb|draw
  BoolColumn get recovered => boolean().withDefault(const Constant(false))();
  RealColumn get reward => real().withDefault(const Constant(0.0))(); // +1 or -1
}

/// Personal EEG baselines — one row per student, updated at each session start.
class Baselines extends Table {
  TextColumn get studentName => text()();
  RealColumn get baselineIndex => real()(); // (theta+alpha)/beta at calibration
  RealColumn get theta => real()();
  RealColumn get alpha => real()();
  RealColumn get beta => real()();
  RealColumn get gamma => real()();
  DateTimeColumn get calibratedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {studentName};
}

// ---------------------------------------------------------------------------
// Database class
// ---------------------------------------------------------------------------

@DriftDatabase(tables: [Sessions, Interventions, Baselines])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Bump this when the schema changes. Drift handles migrations.
  @override
  int get schemaVersion => 1;

  /// Expose DAOs as getters for convenient access.
  SessionDao get sessionDao => SessionDao(this);
  InterventionDao get interventionDao => InterventionDao(this);

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) => m.createAll(),
      );
}

/// Open a native SQLite connection at the app's documents directory.
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'neurolearn.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
