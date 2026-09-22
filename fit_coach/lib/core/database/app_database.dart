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

/// A food the coach budgets around.
///
/// Prices are *user data*, not constants: they move with the Iranian market,
/// so the coach edits them and every ranking follows. [updatedAt] records when
/// a price was last touched, so a stale price is visible rather than silent.
///
/// The generated row class is [FoodRow], not `FoodItem`: the feature's pure
/// domain type already owns that name.
@DataClassName('FoodRow')
class FoodItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();

  /// Macros per 100 g, the unit on every Iranian nutrition label. These are
  /// facts about the food and are seeded; they do not change with the market.
  RealColumn get proteinPer100g => real()();
  RealColumn get kcalPer100g => real()();

  /// Toman per kilogram, or **null until the coach enters it**.
  ///
  /// Prices are the coach's own market reading, so the app ships none of its
  /// own: a guessed price is worse than a blank one, because a blank one asks
  /// to be filled in.
  IntColumn get pricePerKg => integer().nullable()();

  /// When the price was last entered. Meaningless while [pricePerKg] is null.
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
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
    FoodItems,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Platform-appropriate connection:
  /// native (Android/Windows) uses the bundled sqlite3,
  /// web uses the WASM build via web/sqlite3.wasm + web/drift_worker.js.
  AppDatabase({QueryExecutor? executor})
      : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 7;

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
          if (from < 7) {
            await m.createTable(foodItems);
            await _seedFoods();
          }
        },
        // A *fresh* install never runs onUpgrade, so the seed has to happen
        // here as well as in the `from < 7` branch. Both paths run exactly
        // once per database, so the coach can still delete every food and
        // have it stay deleted.
        onCreate: (m) async {
          await m.createAll();
          await _seedFoods();
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Starting set of Iranian staples, with macros but **no prices**.
  ///
  /// Only what a nutrition label states for free: protein and energy per
  /// 100 g. Prices stay blank on purpose — a price invented by the app is
  /// worse than no price, because it looks like a fact the coach can trust.
  /// Blank prices ask to be filled in, and the coach is the one who knows
  /// what things cost in their own market.
  Future<void> _seedFoods() => batch((b) {
        b.insertAll(foodItems, [
          FoodItemsCompanion.insert(
            name: 'سینه مرغ',
            proteinPer100g: 31,
            kcalPer100g: 165,
          ),
          FoodItemsCompanion.insert(
            name: 'تخم مرغ',
            proteinPer100g: 13,
            kcalPer100g: 155,
          ),
          FoodItemsCompanion.insert(
            name: 'عدس',
            proteinPer100g: 25,
            kcalPer100g: 350,
          ),
          FoodItemsCompanion.insert(
            name: 'نخود',
            proteinPer100g: 19,
            kcalPer100g: 364,
          ),
          FoodItemsCompanion.insert(
            name: 'لوبیا قرمز',
            proteinPer100g: 24,
            kcalPer100g: 333,
          ),
          FoodItemsCompanion.insert(
            name: 'ماست',
            proteinPer100g: 3.5,
            kcalPer100g: 59,
          ),
          FoodItemsCompanion.insert(
            name: 'پنیر',
            proteinPer100g: 14,
            kcalPer100g: 260,
          ),
          FoodItemsCompanion.insert(
            name: 'شیر',
            proteinPer100g: 3.4,
            kcalPer100g: 61,
          ),
          FoodItemsCompanion.insert(
            name: 'برنج',
            proteinPer100g: 7,
            kcalPer100g: 360,
          ),
          FoodItemsCompanion.insert(
            name: 'پروتئین وی',
            proteinPer100g: 80,
            kcalPer100g: 400,
          ),
        ]);
      });

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

  Future<int> insertFood(FoodItemsCompanion entry) =>
      into(foodItems).insert(entry);

  Future<FoodRow?> getFood(int id) =>
      (select(foodItems)..where((f) => f.id.equals(id))).getSingleOrNull();

  /// Every food, in a stable order.
  ///
  /// Deliberately *not* sorted by cost here: ranking is domain logic
  /// ([rankByProteinCost], unit-tested on its own), and writing it twice would
  /// let the two copies drift apart.
  Future<List<FoodRow>> getAllFoods() =>
      (select(foodItems)..orderBy([(f) => OrderingTerm.asc(f.id)])).get();

  /// Sets — or clears — a food's price. [updatedAt] moves with it.
  ///
  /// Passing null blanks the price rather than zeroing it: the coach may not
  /// know today's price, and 0 would read as "free".
  Future<void> updateFoodPrice(int id, int? pricePerKg) =>
      (update(foodItems)..where((f) => f.id.equals(id))).write(
        FoodItemsCompanion(
          pricePerKg: Value(pricePerKg),
          updatedAt: Value(DateTime.now()),
        ),
      );

  /// Removes every food. The seed is not re-applied, so an empty list sticks.
  Future<void> deleteAllFoods() => delete(foodItems).go();
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
