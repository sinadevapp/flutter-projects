import 'package:drift/drift.dart';
// NOTE: do NOT import drift/native.dart or drift/wasm.dart here —
// this file is shared across native and web; dart:ffi breaks dart2js.
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Role of a user inside the coaching platform.
enum UserRole { coach, student }

/// Private vs public student.
///
/// This is a **business grouping** the coach picks when registering someone —
/// one-to-one work versus group work — not a permission. Phase 1 shares
/// nothing at all, so today it only drives which tab a student appears under.
///
/// It still lives as a first-class column rather than a note in the UI
/// because a sync layer will want to ask exactly this question later.
enum StudentVisibility { private, public }

/// Users table: coaches and students of the platform.
///
/// Phase 1 is local-only; a sync layer can map this to a backend later.
class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get role => intEnum<UserRole>()();

  /// The coach's chosen photo, already compressed by the picker.
  ///
  /// Stored as **bytes, not a path**: a path means nothing on web, breaks
  /// when the sandbox moves, and needs deleting along with the student. A row
  /// that carries its own photo has none of those problems. Null is the normal
  /// case — the UI falls back to a default icon.
  BlobColumn get photo => blob().nullable()();

  /// [StudentVisibility], stored as its enum index. The SQL default is the raw
  /// index `0` (private) because drift's `withDefault` takes an `Expression`
  /// of the *column's* type — which for `intEnum` is still `int`.
  ///
  /// Defaults to private so a student registered in a hurry still lands under
  /// a tab that exists.
  IntColumn get visibility =>
      intEnum<StudentVisibility>().withDefault(const Constant(0))();
}

/// What a movement trains, so the coach can group a day's work.
///
/// Deliberately flat, mixing muscle group with `compound`: that is how the
/// question was asked, and a tag the coach cannot set is a tag the coach will
/// not set. Muscle group and compound-vs-isolation are genuinely two axes —
/// a back squat is both "legs" and "compound" — so splitting them is the
/// honest next step if the UI ever wants to filter on both at once.
///
/// Lives in `core/` beside [UserRole] because every feature that renders a
/// movement needs the tag, and features must not import each other.
enum ExerciseCategory { legs, chest, shoulders, back, arms, core, compound }

/// A training plan a coach builds for one student.
class WorkoutPlans extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get studentId => integer().references(Users, #id)();
  TextColumn get title => text().withLength(min: 1, max: 100)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// How many weeks the program runs. Null = not decided / open-ended.
  IntColumn get durationWeeks => integer().nullable()();
}

/// One day of a plan, as the coach sees it: a name and whether it is rest.
///
/// Exercises keep their own `weekNumber` / `dayNumber`, so this table is the
/// *only* thing schema 11 adds — nothing existing changes shape.
///
/// It exists because of the one day that has no movements in it: a rest day.
/// Deriving days from their movements cannot describe an empty day, because
/// an empty day has nothing to describe it with. Days with no row yet are
/// days the coach has not reached.
///
/// The unique index is not decoration — it is what makes the upsert below
/// conflict instead of appending a second row for the same slot.
@DataClassName('PlanDay')
@TableIndex(
  name: 'plan_days_slot',
  unique: true,
  columns: {#planId, #weekNumber, #dayNumber},
)
class PlanDays extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get planId => integer().references(WorkoutPlans, #id)();
  IntColumn get weekNumber => integer()();
  IntColumn get dayNumber => integer()();

  /// The coach's own name for the day — «بالاتنه», «پا دست». Null = unnamed,
  /// which is the normal state for a day written out of order.
  TextColumn get title => text().nullable()();

  /// A planned rest day: exists, named or not, with nothing to perform.
  BoolColumn get isRestDay => boolean().withDefault(const Constant(false))();
}

/// One movement inside a training plan (e.g. squat, 4 sets of 10).
/// One movement, and the slot of the program it belongs to.
///
/// Week and day are *coordinates of the movement*, not tables of their own:
/// an exercise lives in week 2 day 3, and a day with no movements in it does
/// not exist. That is also what makes migration additive — three plain
/// columns, no new rows to create and none to move.
class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get planId => integer().references(WorkoutPlans, #id)();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get sets => integer()();
  IntColumn get reps => integer()();

  /// Kilos the coach prescribed, when they prescribed any.
  ///
  /// Nullable because plenty of movements have no load: a pull-up is
  /// bodyweight, and a beginner's squat may be the empty bar. It is the
  /// *prescription* — what a student actually lifted lives on the set log and
  /// is never rewritten by it.
  RealColumn get targetWeightKg => real().nullable()();

  /// 1-based week within the plan.
  IntColumn get weekNumber => integer().withDefault(const Constant(1))();

  /// 1-based day within its week.
  IntColumn get dayNumber => integer().withDefault(const Constant(1))();

  /// Index of [ExerciseCategory]; `6` = compound, the quiet default.
  IntColumn get category =>
      intEnum<ExerciseCategory>().withDefault(const Constant(6))();

  /// Display order **inside its own day**.
  ///
  /// Positions restart at 0 in every day, so reading them without first
  /// selecting the day interleaves one day into another.
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
/// A performed workout: one *day's* work, not the whole program.
class WorkoutSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get planId => integer().references(WorkoutPlans, #id)();
  IntColumn get studentId => integer().references(Users, #id)();
  DateTimeColumn get startedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get finishedAt => dateTime().nullable()();

  /// Which week this session trained — carried here so reopening the app
  /// lands on the same day it was started for.
  IntColumn get weekNumber => integer().withDefault(const Constant(1))();
  IntColumn get dayNumber => integer().withDefault(const Constant(1))();
}

/// One completed set inside a [WorkoutSessions] row.
class SetLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId => integer().references(WorkoutSessions, #id)();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  IntColumn get setNumber => integer()();

  /// Kilos actually lifted. Null where no load was recorded — bodyweight
  /// moves have none, and sets logged before this column existed have none
  /// either. Null is not zero: zero would mean the bar alone.
  RealColumn get weightKg => real().nullable()();

  /// Reps actually done, which is usually *not* the number the plan asked
  /// for. Null means "not recorded", not "zero".
  IntColumn get repsPerformed => integer().nullable()();
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

/// One student's nutrition profile — the inputs a daily target is estimated
/// from.
///
/// The enum values ([Sex], [ActivityLevel], [Goal]) live in the feature's pure
/// domain, and `core/` must not depend on a feature, so they are stored here
/// as plain ints. The feature converts at its own edge.
///
/// One row per student, so this carries no id of its own: [studentId] is both
/// the identity and the foreign key. Editing a profile replaces it rather than
/// accumulating history.
@DataClassName('NutritionTargetsRow')
class NutritionTargets extends Table {
  IntColumn get studentId =>
      integer().references(Users, #id, onDelete: KeyAction.cascade)();

  /// Index into the domain's `Sex` enum.
  IntColumn get sex => integer()();
  IntColumn get age => integer()();
  RealColumn get heightCm => real()();
  RealColumn get weightKg => real()();

  /// Index into the domain's `ActivityLevel` enum.
  IntColumn get activity => integer()();

  /// Index into the domain's `Goal` enum.
  IntColumn get goal => integer()();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {studentId};
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
    NutritionTargets,
    PlanDays,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Platform-appropriate connection:
  /// native (Android/Windows) uses the bundled sqlite3,
  /// web uses the WASM build via web/sqlite3.wasm + web/drift_worker.js.
  AppDatabase({QueryExecutor? executor}) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 12;

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
      if (from < 8) {
        await m.createTable(nutritionTargets);
      }
      // Both columns go on `users`, and **no earlier branch creates that
      // table** — `onUpgrade` only ever runs on a database that already
      // has it, since every table comes from `onCreate`.
      //
      // This is why the guard is `from < 9` and *not* the `from == 8` the
      // migration note in CLAUDE.md prescribes for column additions. That
      // narrower guard is only correct when an earlier branch's
      // `createTable` already emits the column (the `sessions.student_id`
      // case). Using `from == 8` here would skip the ALTER for anyone
      // upgrading from 6 or 7 and leave the app without the columns.
      if (from < 9) {
        await customStatement('ALTER TABLE users ADD COLUMN photo BLOB');
        await customStatement(
          'ALTER TABLE users ADD COLUMN visibility '
          'INTEGER NOT NULL DEFAULT 0',
        );
      }
      // Additive, with defaults chosen to mean *exactly what a flat list
      // already was*: week 1, day 1, compound. That is why no UPDATE is
      // needed — existing rows read correctly as soon as the columns
      // exist, and `duration_weeks` is NULL because the length of an old
      // program was never recorded anywhere.
      //
      // **The two inner guards are the whole trick.** `m.createTable` in
      // an earlier branch emits the table's *current* shape, so anyone
      // upgrading from 1–4 already got these columns for free from the
      // `from < 2` branch, and anyone from 1–4 got them on
      // `workout_sessions` from `from < 5`. A bare `from < 10` would then
      // run `ADD COLUMN` on top of an existing column and fail with
      // `duplicate column name` — the trap CLAUDE.md §7 documents, and the
      // one `persistence_test.dart` was written to catch.
      if (from < 10) {
        if (from >= 2) {
          await customStatement(
            'ALTER TABLE workout_plans ADD COLUMN duration_weeks '
            'INTEGER NULL',
          );
          await customStatement(
            'ALTER TABLE exercises ADD COLUMN week_number '
            'INTEGER NOT NULL DEFAULT 1',
          );
          await customStatement(
            'ALTER TABLE exercises ADD COLUMN day_number '
            'INTEGER NOT NULL DEFAULT 1',
          );
          await customStatement(
            'ALTER TABLE exercises ADD COLUMN category '
            'INTEGER NOT NULL DEFAULT 6',
          );
        }
        if (from >= 5) {
          await customStatement(
            'ALTER TABLE workout_sessions ADD COLUMN week_number '
            'INTEGER NOT NULL DEFAULT 1',
          );
          await customStatement(
            'ALTER TABLE workout_sessions ADD COLUMN day_number '
            'INTEGER NOT NULL DEFAULT 1',
          );
        }
      }
      // `plan_days` is created by no earlier branch, so unlike the guarded
      // ALTERs above a plain `from < 11` is correct: nothing can already have
      // emitted this table.
      //
      // Deliberately *after* `from < 10` — the backfill reads
      // `exercises.week_number`, which that branch is what adds.
      if (from < 11) {
        await m.createTable(planDays);
        await customStatement(
          'INSERT INTO plan_days (plan_id, week_number, day_number) '
          'SELECT DISTINCT plan_id, week_number, day_number '
          'FROM exercises',
        );
      }
      // Load recording. Both tables are created by an earlier branch's
      // `createTable`, which emits the *current* shape — so each ALTER is
      // gated on the version whose branch builds it, exactly as for schema
      // 10. Unguarded, these would fail with `duplicate column name` for
      // anyone upgrading from 1 or 4.
      if (from < 12) {
        if (from >= 2) {
          await customStatement(
            'ALTER TABLE exercises ADD COLUMN target_weight_kg REAL NULL',
          );
        }
        if (from >= 5) {
          await customStatement(
            'ALTER TABLE set_logs ADD COLUMN weight_kg REAL NULL',
          );
          await customStatement(
            'ALTER TABLE set_logs ADD COLUMN reps_performed INTEGER NULL',
          );
        }
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

  Future<User> getUser(int id) =>
      (select(users)..where((u) => u.id.equals(id))).getSingle();

  /// Stores the coach's chosen photo, or blanks it when [photo] is null.
  ///
  /// Null means "no photo yet", which the UI renders as the default icon —
  /// deliberately distinct from an empty photo that would decode to garbage.
  Future<void> updateStudentPhoto(int id, Uint8List? photo) => (update(
    users,
  )..where((u) => u.id.equals(id))).write(UsersCompanion(photo: Value(photo)));

  /// Moves a student between the private and public tabs.
  Future<void> updateStudentVisibility(int id, StudentVisibility visibility) =>
      (update(users)..where((u) => u.id.equals(id))).write(
        UsersCompanion(visibility: Value(visibility)),
      );

  /// Corrects a student's name. The column carries its own length check.
  Future<void> updateStudentName(int id, String name) => (update(
    users,
  )..where((u) => u.id.equals(id))).write(UsersCompanion(name: Value(name)));

  /// Resets the local identity: drops every user *and* everything that hangs
  /// off them (plans, exercises) — deleting users first would trip the
  /// `workout_plans.studentId` foreign key. One transaction so a failure
  /// leaves the database untouched.
  Future<void> deleteAllUsers() => transaction(() async {
    // Leaf-first, or the users delete trips a foreign key: set logs hang
    // off sessions and movements; sessions off plans and users; plans,
    // exercises and nutrition targets off users.
    await delete(setLogs).go();
    await delete(workoutSessions).go();
    await delete(exercises).go();
    await delete(planDays).go();
    await delete(workoutPlans).go();
    await delete(nutritionTargets).go();
    await delete(sessions).go();
    await delete(users).go();
  });

  /// Removes one student and everything they produced.
  ///
  /// Leaf-first inside one transaction, exactly like [deleteAllUsers] — but
  /// scoped, so the coach's other students survive. Deleting the user row
  /// first would trip `workout_plans.studentId` (code 787).
  ///
  /// Their sign-in row goes too: the device may be signed in *as* this
  /// student, and leaving it behind would point the session at a row that no
  /// longer exists.
  Future<void> deleteStudent(int id) => transaction(() async {
        // Resolve the ids first: these tables are about to change, and a
        // subquery re-read as it goes would be aiming at a moving target.
        final sessionIds = [
          for (final s in await (select(workoutSessions)
                ..where((s) => s.studentId.equals(id)))
              .get())
            s.id,
        ];
        final planIds = [
          for (final p in await (select(workoutPlans)
                ..where((p) => p.studentId.equals(id)))
              .get())
            p.id,
        ];
        final exerciseIds = [
          for (final e in await (select(exercises)
                ..where((e) => e.planId.isIn(planIds)))
              .get())
            e.id,
        ];

        // Set logs hang off two things: the session that recorded them and the
        // movement they were for. Clear both paths — a log left behind would
        // break whichever of the two is deleted first.
        if (sessionIds.isNotEmpty) {
          await (delete(setLogs)..where((l) => l.sessionId.isIn(sessionIds)))
              .go();
        }
        if (exerciseIds.isNotEmpty) {
          await (delete(setLogs)..where((l) => l.exerciseId.isIn(exerciseIds)))
              .go();
        }
        if (sessionIds.isNotEmpty) {
          await (delete(workoutSessions)..where((s) => s.id.isIn(sessionIds)))
              .go();
        }
        if (exerciseIds.isNotEmpty) {
          await (delete(exercises)..where((e) => e.id.isIn(exerciseIds)))
              .go();
        }
        if (planIds.isNotEmpty) {
          await (delete(planDays)..where((d) => d.planId.isIn(planIds))).go();
          await (delete(workoutPlans)..where((p) => p.id.isIn(planIds))).go();
        }

        await (delete(nutritionTargets)..where((t) => t.studentId.equals(id)))
            .go();
        await (delete(sessions)..where((s) => s.studentId.equals(id))).go();
        await (delete(users)..where((u) => u.id.equals(id))).go();
      });

  Future<int> insertWorkoutPlan(WorkoutPlansCompanion entry) =>
      into(workoutPlans).insert(entry);

  /// Writes a movement and records the day it belongs to.
  ///
  /// Both in one transaction: a movement without its day row would be a day
  /// the coach cannot name, and a day row without its movement would be a day
  /// that does not exist. Reading the row back rather than taking the slot
  /// from the companion means absent columns resolve to their real defaults.
  Future<int> insertExercise(ExercisesCompanion entry) => transaction(() async {
        final id = await into(exercises).insert(entry);
        final movement = await (select(
          exercises,
        )..where((e) => e.id.equals(id))).getSingle();
        await _ensureDay(
          movement.planId,
          week: movement.weekNumber,
          day: movement.dayNumber,
        );
        return id;
      });

  Future<List<WorkoutPlan>> getPlansForStudent(int studentId) =>
      (select(workoutPlans)
            ..where((p) => p.studentId.equals(studentId))
            ..orderBy([(p) => OrderingTerm.desc(p.createdAt)]))
          .get();

  /// Every day of a plan the coach has authored, in program order.
  ///
  /// Includes rest days, which have no movements and so cannot be reached
  /// through `exercises`. A day with no row has not been reached yet.
  Future<List<PlanDay>> getDays(int planId) =>
      (select(planDays)
            ..where((d) => d.planId.equals(planId))
            ..orderBy([
              (d) => OrderingTerm.asc(d.weekNumber),
              (d) => OrderingTerm.asc(d.dayNumber),
            ]))
          .get();

  /// Creates the day row if it is not there yet.
  ///
  /// Upsert rather than insert: naming a day that has been running for weeks
  /// must not append a duplicate slot. The unique index is what makes this
  /// conflict instead.
  Future<void> _ensureDay(
    int planId, {
    required int week,
    required int day,
  }) =>
      into(planDays).insert(
        PlanDaysCompanion.insert(
          planId: planId,
          weekNumber: week,
          dayNumber: day,
        ),
        // Not `insertOnConflictUpdate`: that resolves conflicts on the primary
        // key, so the unique (plan, week, day) index still fired and threw.
        // `insertOrIgnore` honours the index instead, and leaving an existing
        // row untouched is exactly what we want — a title or a rest flag set
        // weeks ago must survive the next movement being added.
        mode: InsertMode.insertOrIgnore,
      );

  /// Matches one day slot. Takes the table because drift's `where` hands back
  /// a callback over its own alias — a pre-built expression would resolve the
  /// columns against a table that is not in scope.
  static Expression<bool> _slot(
    $PlanDaysTable d,
    int planId,
    int week,
    int day,
  ) =>
      d.planId.equals(planId) &
      d.weekNumber.equals(week) &
      d.dayNumber.equals(day);

  /// Names a day, creating the row if this is its first movement.
  Future<void> setDayTitle(
    int planId, {
    required int week,
    required int day,
    String? title,
  }) async {
    await _ensureDay(planId, week: week, day: day);
    await (update(planDays)
          ..where((d) => _slot(d, planId, week, day)))
        .write(PlanDaysCompanion(title: Value(title)));
  }

  /// Marks a day as rest — or un-marks it, keeping the name either way.
  ///
  /// A rest day has no movements, so this is also the only way one comes into
  /// existence.
  Future<void> setDayRest(
    int planId, {
    required int week,
    required int day,
    required bool isRest,
  }) async {
    await _ensureDay(planId, week: week, day: day);
    await (update(planDays)
          ..where((d) => _slot(d, planId, week, day)))
        .write(PlanDaysCompanion(isRestDay: Value(isRest)));
  }

  /// Every movement of a plan, in program order: week, then day, then its
  /// place within that day.
  ///
  /// Position alone would be wrong here — it restarts at 0 in each day, so
  /// sorting by it would splice day 2 into day 1.
  Future<List<Exercise>> getExercisesForPlan(int planId) =>
      (select(exercises)
            ..where((e) => e.planId.equals(planId))
            ..orderBy([
              (e) => OrderingTerm.asc(e.weekNumber),
              (e) => OrderingTerm.asc(e.dayNumber),
              (e) => OrderingTerm.asc(e.position),
            ]))
          .get();

  /// The movements of one day, in display order.
  Future<List<Exercise>> getExercisesForDay(int planId, int week, int day) =>
      (select(exercises)
            ..where(
              (e) =>
                  e.planId.equals(planId) &
                  e.weekNumber.equals(week) &
                  e.dayNumber.equals(day),
            )
            ..orderBy([(e) => OrderingTerm.asc(e.position)]))
          .get();

  /// The movements of one whole week, in day then position order.
  Future<List<Exercise>> getExercisesForWeek(int planId, int week) =>
      (select(exercises)
            ..where((e) => e.planId.equals(planId) & e.weekNumber.equals(week))
            ..orderBy([
              (e) => OrderingTerm.asc(e.dayNumber),
              (e) => OrderingTerm.asc(e.position),
            ]))
          .get();

  /// Renames a plan. Its movements are untouched.
  Future<void> renamePlan(int planId, String title) =>
      (update(workoutPlans)..where((p) => p.id.equals(planId))).write(
        WorkoutPlansCompanion(title: Value(title)),
      );

  /// Corrects a movement. Anything not passed is left as it was.
  /// Corrects a movement. Anything not passed is left as it was.
  ///
  /// [targetWeightKg] takes a [Value] rather than a bare `double?` because
  /// this column distinguishes *no prescription* from *not asked*: `Value(80)`
  /// sets it, `const Value(null)` clears it (the movement is bodyweight), and
  /// the default `Value.absent()` leaves it alone. A plain `double?` could
  /// never say "clear it".
  Future<void> updateExercise(
    int exerciseId, {
    String? name,
    int? sets,
    int? reps,
    Value<double?> targetWeightKg = const Value.absent(),
  }) =>
      (update(exercises)..where((e) => e.id.equals(exerciseId))).write(
        ExercisesCompanion(
          name: name == null ? const Value.absent() : Value(name),
          sets: sets == null ? const Value.absent() : Value(sets),
          reps: reps == null ? const Value.absent() : Value(reps),
          targetWeightKg: targetWeightKg,
        ),
      );

  /// Removes a movement from its plan.
  ///
  /// Its logged sets are *kept*: they are what the student actually performed,
  /// and history outlives the plan being edited. The foreign key from
  /// `set_logs.exerciseId` would otherwise block this delete.
  Future<void> deleteExercise(int exerciseId) => transaction(() async {
    await (delete(setLogs)..where((l) => l.exerciseId.equals(exerciseId))).go();
    await (delete(exercises)..where((e) => e.id.equals(exerciseId))).go();
  });

  /// Deletes a plan, its movements, and everything performed against it.
  ///
  /// Leaf-first inside one transaction: sessions reference the plan, set logs
  /// reference both the sessions and the movements, and `PRAGMA foreign_keys`
  /// is on, so any other order trips a constraint (code 787).
  Future<void> deletePlan(int planId) => transaction(() async {
    final sessions = await (select(
      workoutSessions,
    )..where((s) => s.planId.equals(planId))).get();
    for (final session in sessions) {
      await (delete(
        setLogs,
      )..where((l) => l.sessionId.equals(session.id))).go();
    }
    await (delete(workoutSessions)..where((s) => s.planId.equals(planId))).go();

    final movements = await (select(
      exercises,
    )..where((e) => e.planId.equals(planId))).get();
    for (final movement in movements) {
      await (delete(
        setLogs,
      )..where((l) => l.exerciseId.equals(movement.id))).go();
    }
    await (delete(exercises)..where((e) => e.planId.equals(planId))).go();
    // Days reference the plan, so they go before it — leaf-first, same rule
    // as everything else in this transaction.
    await (delete(planDays)..where((d) => d.planId.equals(planId))).go();
    await (delete(workoutPlans)..where((p) => p.id.equals(planId))).go();
  });

  /// Copies a plan and its movements to [forStudent].
  ///
  /// Returns the new plan's id. Nothing performed against the original comes
  /// along — a copy is a fresh plan, not a history.
  Future<int> duplicatePlan(int planId, {required int forStudent}) =>
      transaction(() async {
        final source = await (select(
          workoutPlans,
        )..where((p) => p.id.equals(planId))).getSingle();
        final movements = await getExercisesForPlan(planId);

        final copyId = await insertWorkoutPlan(
          WorkoutPlansCompanion.insert(
            studentId: forStudent,
            title: source.title,
            durationWeeks: Value(source.durationWeeks),
          ),
        );
        for (final movement in movements) {
          // Week, day and category must come across too: copying only the
          // movement rows would collapse a multi-week program onto week 1 day
          // 1 and tag everything compound.
          await insertExercise(
            ExercisesCompanion.insert(
              planId: copyId,
              weekNumber: Value(movement.weekNumber),
              dayNumber: Value(movement.dayNumber),
              name: movement.name,
              sets: movement.sets,
              reps: movement.reps,
              category: Value(movement.category),
              position: Value(movement.position),
            ),
          );
        }
        // After the movements, so their auto-created rows are updated rather
        // than duplicated — and so rest days, which have no movement to create
        // them, come along too. Titles and rest flags are what make a copy
        // readable; without this a copy arrives unnamed and fully training.
        for (final day in await getDays(planId)) {
          await _ensureDay(
            copyId,
            week: day.weekNumber,
            day: day.dayNumber,
          );
          await (update(planDays)
                ..where((d) => _slot(d, copyId, day.weekNumber, day.dayNumber)))
              .write(PlanDaysCompanion(
            title: Value(day.title),
            isRestDay: Value(day.isRestDay),
          ));
        }

        return copyId;
      });

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
  /// Starts a session for **one day** of a plan.
  ///
  /// [weekNumber] and [dayNumber] are required rather than defaulting to 1 on
  /// purpose: a forgotten day would quietly log the workout under the wrong
  /// day and look fine until someone read their own history. Failing to
  /// compile is much better than that.
  Future<int> startWorkoutSession({
    required int planId,
    required int studentId,
    required int weekNumber,
    required int dayNumber,
  }) => into(workoutSessions).insert(
    WorkoutSessionsCompanion.insert(
      planId: planId,
      studentId: studentId,
      // Wrapped because the columns carry a default, and drift's `.insert`
      // therefore wants a `Value`.
      weekNumber: Value(weekNumber),
      dayNumber: Value(dayNumber),
    ),
  );

  /// Records how many weeks a program runs. Null means "not decided".
  Future<void> setPlanDuration(int planId, int? weeks) =>
      (update(workoutPlans)..where((p) => p.id.equals(planId))).write(
        WorkoutPlansCompanion(durationWeeks: Value(weeks)),
      );

  /// The student's unfinished workout, if any — the one to resume on launch.
  Future<WorkoutSession?> getActiveWorkoutSession(int studentId) async {
    final rows =
        await (select(workoutSessions)
              ..where(
                (s) => s.studentId.equals(studentId) & s.finishedAt.isNull(),
              )
              ..orderBy([(s) => OrderingTerm.desc(s.startedAt)])
              ..limit(1))
            .get();
    return rows.isEmpty ? null : rows.first;
  }

  /// Records one finished set.
  /// Records one completed set, and what it actually cost.
  ///
  /// [weightKg] and [reps] are the attempt, not the prescription: a student
  /// who was given 4×10 may well manage 82.5 kg for 7. Omitting them keeps
  /// the pre-existing behaviour — a set with no recorded load, which is how
  /// every set logged before this existed reads.
  Future<int> logSet({
    required int sessionId,
    required int exerciseId,
    required int setNumber,
    double? weightKg,
    int? reps,
  }) => into(setLogs).insert(
    SetLogsCompanion.insert(
      sessionId: sessionId,
      exerciseId: exerciseId,
      setNumber: setNumber,
      weightKg: Value(weightKg),
      repsPerformed: Value(reps),
    ),
  );

  /// The most recent set logged for [exerciseId], newest first.
  ///
  /// Ordered by row id rather than by timestamp: ids grow with insertion, so
  /// two sets written in the same millisecond still have an unambiguous
  /// winner, and a clock that happens to be wrong cannot reverse the answer.
  Future<SetLog?> latestSetLog(int exerciseId) =>
      (select(setLogs)
            ..where((l) => l.exerciseId.equals(exerciseId))
            ..orderBy([(l) => OrderingTerm.desc(l.id)])
            ..limit(1))
          .getSingleOrNull();

  Future<Exercise?> getExercise(int id) => (select(exercises)
        ..where((e) => e.id.equals(id)))
      .getSingleOrNull();

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
    await into(
      appSettings,
    ).insert(AppSettingsCompanion.insert(locale: Value(code)));
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

  /// One student's nutrition profile, or null before the coach has set one.
  Future<NutritionTargetsRow?> getNutritionTarget(int studentId) => (select(
    nutritionTargets,
  )..where((t) => t.studentId.equals(studentId))).getSingleOrNull();

  /// Stores a student's profile, replacing any they already had.
  ///
  /// `insertOnConflictUpdate` rather than a delete+insert: one row per student
  /// is the point, and this keeps the operation a single statement.
  Future<void> saveNutritionTarget(NutritionTargetsCompanion entry) =>
      into(nutritionTargets).insertOnConflictUpdate(entry);
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
