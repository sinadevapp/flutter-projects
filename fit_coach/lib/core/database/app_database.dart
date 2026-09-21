import 'package:drift/drift.dart';
// NOTE: do NOT import drift/native.dart or drift/wasm.dart here —
// this file is shared across native and web; dart:ffi breaks dart2js.
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Role of a user inside the coaching platform.
enum UserRole { coach, student }

/// Users table: coaches and students of the platform.
///
/// Phase 1 is local-only; a sync layer can map this to a backend later.
class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get role => intEnum<UserRole>()();
}

/// A training plan a coach builds for one student.
class WorkoutPlans extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get studentId => integer().references(Users, #id)();
  TextColumn get title => text().withLength(min: 1, max: 100)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// One movement inside a training plan (e.g. squat, 4 sets of 10).
class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get planId => integer().references(WorkoutPlans, #id)();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get sets => integer()();
  IntColumn get reps => integer()();

  /// Display order inside the plan.
  IntColumn get position => integer().withDefault(const Constant(0))();
}

@DriftDatabase(tables: [Users, WorkoutPlans, Exercises])
class AppDatabase extends _$AppDatabase {
  /// Platform-appropriate connection:
  /// native (Android/Windows) uses the bundled sqlite3,
  /// web uses the WASM build via web/sqlite3.wasm + web/drift_worker.js.
  AppDatabase({QueryExecutor? executor})
      : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(workoutPlans);
            await m.createTable(exercises);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Future<int> insertUser(UsersCompanion entry) => into(users).insert(entry);

  Future<List<User>> getAllUsers() => select(users).get();

  Future<int> deleteAllUsers() => delete(users).go();

  Future<int> insertWorkoutPlan(WorkoutPlansCompanion entry) =>
      into(workoutPlans).insert(entry);

  Future<int> insertExercise(ExercisesCompanion entry) =>
      into(exercises).insert(entry);

  Future<List<WorkoutPlan>> getPlansForStudent(int studentId) =>
      (select(workoutPlans)
            ..where((p) => p.studentId.equals(studentId))
            ..orderBy([(p) => OrderingTerm.desc(p.createdAt)]))
          .get();

  Future<List<Exercise>> getExercisesForPlan(int planId) =>
      (select(exercises)
            ..where((e) => e.planId.equals(planId))
            ..orderBy([(e) => OrderingTerm.asc(e.position)]))
          .get();
}

QueryExecutor _openConnection() {
  return driftDatabase(
    name: 'fit_coach',
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  );
}
