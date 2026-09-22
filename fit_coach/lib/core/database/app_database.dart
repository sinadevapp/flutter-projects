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

/// Which role the device is currently acting as.
///
/// This is *session* state, deliberately separate from [Users]: switching role
/// must never touch the coach's students or their plans. Empty table = nobody
/// is signed in, so the role picker shows.
///
/// When the role is [UserRole.student], [studentId] is the student record this
/// device is acting as (phase 1 has no real login, so the student picks their
/// own name once).
class Sessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get role => intEnum<UserRole>()();
  IntColumn get studentId => integer().nullable().references(Users, #id)();
}

/// One performed workout: opened when the student starts training and closed
/// with [finishedAt]. An open row (finishedAt == null) is the workout in
/// progress — it lives on disk so closing the app mid-workout resumes it.
class WorkoutSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get planId => integer().references(WorkoutPlans, #id)();
  IntColumn get studentId => integer().references(Users, #id)();
  DateTimeColumn get startedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get finishedAt => dateTime().nullable()();
}

/// One completed set inside a [WorkoutSessions] row.
class SetLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId => integer().references(WorkoutSessions, #id)();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  IntColumn get setNumber => integer()();
  DateTimeColumn get completedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

/// App-wide preferences that must survive a restart.
///
/// One row, like [Sessions]. [locale] is a language code ('fa', 'en');
/// null means "follow the device".
class AppSettings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get locale => text().nullable()();
}

@DriftDatabase(
  tables: [
    Users,
    WorkoutPlans,
    Exercises,
    Sessions,
    WorkoutSessions,
    SetLogs,
    AppSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Platform-appropriate connection:
  /// native (Android/Windows) uses the bundled sqlite3,
  /// web uses the WASM build via web/sqlite3.wasm + web/drift_worker.js.
  AppDatabase({QueryExecutor? executor})
      : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(workoutPlans);
            await m.createTable(exercises);
          }
          if (from < 3) {
            // Created with the current definition, student_id included.
            await m.createTable(sessions);
          }
          if (from == 3) {
            // Only an install that already had schema-3 sessions lacks the
            // column — a from<3 upgrade just created the table complete.
            await customStatement(
              'ALTER TABLE sessions ADD COLUMN student_id INTEGER '
              'REFERENCES users(id)',
            );
          }
          if (from < 5) {
            await m.createTable(workoutSessions);
            await m.createTable(setLogs);
          }
          if (from < 6) {
            await m.createTable(appSettings);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Future<int> insertUser(UsersCompanion entry) => into(users).insert(entry);

  Future<List<User>> getAllUsers() => select(users).get();

  /// Resets the local identity: drops every user *and* everything that hangs
  /// off them (plans, exercises) — deleting users first would trip the
  /// `workout_plans.studentId` foreign key. One transaction so a failure
  /// leaves the database untouched.
  Future<void> deleteAllUsers() => transaction(() async {
        await delete(exercises).go();
        await delete(workoutPlans).go();
        await delete(users).go();
      });

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

  /// The role this device is acting as, or null when nobody is signed in.
  Future<UserRole?> getActiveRole() async {
    final rows = await select(sessions).get();
    return rows.isEmpty ? null : rows.first.role;
  }

  /// The student record the signed-in student is acting as (null for coaches).
  Future<int?> getActiveStudentId() async {
    final rows = await select(sessions).get();
    return rows.isEmpty ? null : rows.first.studentId;
  }

  /// Signs in; replaces any previous session.
  Future<void> setActiveRole(UserRole role, {int? studentId}) =>
      transaction(() async {
        await delete(sessions).go();
        await into(sessions).insert(
          SessionsCompanion.insert(role: role, studentId: Value(studentId)),
        );
      });

  /// Signs out. Students and plans are untouched.
  Future<void> clearActiveRole() => delete(sessions).go();

  /// Opens a workout session for [studentId] on [planId].
  Future<int> startWorkoutSession({
    required int planId,
    required int studentId,
  }) =>
      into(workoutSessions).insert(
        WorkoutSessionsCompanion.insert(
          planId: planId,
          studentId: studentId,
        ),
      );

  /// The student's unfinished workout, if any — the one to resume on launch.
  Future<WorkoutSession?> getActiveWorkoutSession(int studentId) async {
    final rows = await (select(workoutSessions)
          ..where((s) => s.studentId.equals(studentId) & s.finishedAt.isNull())
          ..orderBy([(s) => OrderingTerm.desc(s.startedAt)])
          ..limit(1))
        .get();
    return rows.isEmpty ? null : rows.first;
  }

  /// Records one finished set.
  Future<int> logSet({
    required int sessionId,
    required int exerciseId,
    required int setNumber,
  }) =>
      into(setLogs).insert(
        SetLogsCompanion.insert(
          sessionId: sessionId,
          exerciseId: exerciseId,
          setNumber: setNumber,
        ),
      );

  /// Every set logged so far in one workout, oldest first.
  Future<List<SetLog>> getSetLogs(int sessionId) =>
      (select(setLogs)
            ..where((l) => l.sessionId.equals(sessionId))
            ..orderBy([(l) => OrderingTerm.asc(l.id)]))
          .get();

  /// Closes the workout.
  Future<void> finishWorkoutSession(int sessionId) =>
      (update(workoutSessions)..where((s) => s.id.equals(sessionId))).write(
        WorkoutSessionsCompanion(finishedAt: Value(DateTime.now())),
      );

  /// The saved language code ('fa'/'en'), or null to follow the device.
  Future<String?> getLocaleCode() async {
    final rows = await select(appSettings).get();
    return rows.isEmpty ? null : rows.first.locale;
  }

  /// Remembers the chosen language.
  Future<void> setLocaleCode(String? code) => transaction(() async {
        await delete(appSettings).go();
        await into(appSettings).insert(
          AppSettingsCompanion.insert(locale: Value(code)),
        );
      });
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
