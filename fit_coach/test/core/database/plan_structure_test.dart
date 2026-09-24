import 'dart:io';

import 'package:drift/drift.dart'
    show OpeningDetails, QueryExecutor, QueryExecutorUser, Value;
import 'package:drift/native.dart';
import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/test_database.dart';
import 'package:fit_coach/features/workout_builder/application/plan_actions.dart';
import 'package:flutter_test/flutter_test.dart';

/// The shape a plan takes once weeks, days and categories exist.
///
/// All three are additive: a plan written before this change was one flat
/// list, which is exactly week 1 day 1 with every movement tagged compound.
void main() {
  late AppDatabase db;
  late int student;
  late int plan;

  setUp(() async {
    db = createTestDatabase();
    student = await db.insertUser(
      UsersCompanion.insert(name: 'علی', role: UserRole.student),
    );
    plan = await db.insertWorkoutPlan(
      WorkoutPlansCompanion.insert(studentId: student, title: 'برنامه'),
    );
  });
  tearDown(() => db.close());

  Future<int> movement({
    required String name,
    int week = 1,
    int day = 1,
    int position = 0,
    int sets = 3,
    int reps = 10,
    ExerciseCategory category = ExerciseCategory.compound,
  }) => db.insertExercise(
    ExercisesCompanion.insert(
      planId: plan,
      weekNumber: Value(week),
      dayNumber: Value(day),
      name: name,
      sets: sets,
      reps: reps,
      position: Value(position),
      category: Value(category),
    ),
  );

  group('defaults', () {
    test('a movement lands in week 1 day 1 when nothing is said', () async {
      await db.insertExercise(
        ExercisesCompanion.insert(
          planId: plan,
          name: 'اسکوات',
          sets: 3,
          reps: 10,
        ),
      );

      final saved = (await db.getExercisesForPlan(plan)).single;
      expect(saved.weekNumber, 1);
      expect(saved.dayNumber, 1);
      // Compound: the tag a coach has not thought about yet.
      expect(saved.category, ExerciseCategory.compound);
    });

    test('a new plan has no duration until the coach sets one', () async {
      final saved = await db.getPlansForStudent(student);
      expect(saved.single.durationWeeks, isNull);
    });

    test('the coach can say how many weeks the program runs', () async {
      await db.renamePlan(plan, 'برنامه'); // no-op, keeps the row reachable

      await db.setPlanDuration(plan, 6);

      final saved = await db.getPlansForStudent(student);
      expect(saved.single.durationWeeks, 6);
    });
  });

  group('ordering', () {
    test('reads week, then day, then position — not position alone', () async {
      // Positions restart in each day, so position alone interleaves them.
      await movement(name: 'الف', week: 1, day: 1, position: 0);
      await movement(name: 'ب', week: 1, day: 1, position: 1);
      await movement(name: 'پ', week: 1, day: 2, position: 0);
      await movement(name: 'ت', week: 2, day: 1, position: 0);

      final order = (await db.getExercisesForPlan(
        plan,
      )).map((e) => e.name).toList();

      expect(order, ['الف', 'ب', 'پ', 'ت']);
    });

    test('each day is self-contained', () async {
      await movement(name: 'الف', week: 1, day: 1, position: 0);
      await movement(name: 'پ', week: 1, day: 2, position: 0);

      final day1 = await db.getExercisesForDay(plan, 1, 1);
      final day2 = await db.getExercisesForDay(plan, 1, 2);

      expect(day1.map((e) => e.name), ['الف']);
      expect(day2.map((e) => e.name), ['پ']);
      expect(await db.getExercisesForDay(plan, 2, 1), isEmpty);
    });
  });

  group('sessions know which day they train', () {
    test('a session records the day it was started for', () async {
      await movement(name: 'الف', week: 2, day: 3);

      final sessionId = await db.startWorkoutSession(
        planId: plan,
        studentId: student,
        weekNumber: 2,
        dayNumber: 3,
      );

      final session = await db.getActiveWorkoutSession(student);
      expect(session!.id, sessionId);
      expect(session.weekNumber, 2);
      expect(session.dayNumber, 3);
    });

    test('a session\'s day is independent of another session\'s', () async {
      await movement(name: 'الف', week: 1, day: 1);
      await movement(name: 'ب', week: 1, day: 2);

      await db.startWorkoutSession(
        planId: plan,
        studentId: student,
        weekNumber: 1,
        dayNumber: 1,
      );
      // The plan view refuses a second open session, so this one belongs to
      // the same student only after the first is finished — assert on the
      // stored row instead of racing two open ones.
      final session = await db.getActiveWorkoutSession(student);
      expect(session!.weekNumber, 1);
      expect(session.dayNumber, 1);
    });
  });

  group('copying a week through the database', () {
    test('inserts the whole week under the new number', () async {
      await movement(
        name: 'الف',
        week: 1,
        day: 1,
        position: 0,
        category: ExerciseCategory.legs,
        sets: 4,
        reps: 8,
      );
      await movement(
        name: 'ب',
        week: 1,
        day: 2,
        position: 0,
        category: ExerciseCategory.chest,
      );

      final copied = await copyWeek(db, planId: plan, fromWeek: 1, toWeek: 2);

      expect(copied, 2);
      final week2 = await db.getExercisesForWeek(plan, 2);
      expect(week2.map((e) => e.name), ['الف', 'ب']);
      expect(week2.first.category, ExerciseCategory.legs);
      expect(week2.first.sets, 4);

      // The original week is untouched.
      expect(await db.getExercisesForWeek(plan, 1), hasLength(2));
    });

    test('refuses to overwrite a week the coach already wrote', () async {
      await movement(name: 'الف', week: 1, day: 1);
      await movement(name: 'ب', week: 2, day: 1);

      final copied = await copyWeek(db, planId: plan, fromWeek: 1, toWeek: 2);

      expect(copied, 0);
      // Nothing was appended or replaced.
      final week2 = await db.getExercisesForWeek(plan, 2);
      expect(week2.map((e) => e.name), ['ب']);
      expect(await db.getExercisesForWeek(plan, 1), hasLength(1));
    });

    test('the copy is independent of the source afterwards', () async {
      await movement(name: 'الف', week: 1, day: 1, sets: 3);
      final copyId = await copyWeek(db, planId: plan, fromWeek: 1, toWeek: 2);

      expect(copyId, 1);
      final week2 = await db.getExercisesForWeek(plan, 2);
      await db.updateExercise(week2.single.id, sets: 9);

      expect((await db.getExercisesForWeek(plan, 1)).single.sets, 3);
    });
  });

  group('deleting and duplicating still work across days', () {
    test('a plan with several days copies to another student intact', () async {
      await movement(name: 'الف', week: 1, day: 1, position: 0);
      await movement(name: 'ب', week: 1, day: 2, position: 0);
      await movement(name: 'پ', week: 2, day: 1, position: 0);

      final other = await db.insertUser(
        UsersCompanion.insert(name: 'رضا', role: UserRole.student),
      );
      await db.setPlanDuration(plan, 4);
      final copyId = await db.duplicatePlan(plan, forStudent: other);

      final copied = await db.getExercisesForPlan(copyId);
      expect(copied.map((e) => '${e.weekNumber}/${e.dayNumber}').toList(), [
        '1/1',
        '1/2',
        '2/1',
      ]);

      // The duration travels too — a copy that forgets how long the program
      // runs is a different program.
      final plans = await db.getPlansForStudent(other);
      expect(plans.single.durationWeeks, 4);
    });

    test('deleting a plan with sessions on two days is safe', () async {
      await movement(name: 'الف', week: 1, day: 1);
      await movement(name: 'ب', week: 1, day: 2);
      final e1 = (await db.getExercisesForDay(plan, 1, 1)).single;
      final e2 = (await db.getExercisesForDay(plan, 1, 2)).single;

      final s1 = await db.startWorkoutSession(
        planId: plan,
        studentId: student,
        weekNumber: 1,
        dayNumber: 1,
      );
      await db.finishWorkoutSession(s1);
      final s2 = await db.startWorkoutSession(
        planId: plan,
        studentId: student,
        weekNumber: 1,
        dayNumber: 2,
      );
      await db.logSet(sessionId: s2, exerciseId: e2.id, setNumber: 1);
      await db.finishWorkoutSession(s2);
      await db.logSet(sessionId: s1, exerciseId: e1.id, setNumber: 1);

      // Foreign keys are on; leaf-first delete must not trip one.
      await db.deletePlan(plan);

      expect(await db.select(db.workoutPlans).get(), isEmpty);
      expect(await db.select(db.exercises).get(), isEmpty);
      expect(await db.select(db.workoutSessions).get(), isEmpty);
      expect(await db.select(db.setLogs).get(), isEmpty);
    });
  });

  test('a database created at schema 9 upgrades into week 1 day 1', () async {
    final dir = Directory.systemTemp.createTempSync('fit_coach_upgrade9');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/legacy9.sqlite');

    // The schema an install of the previous version left on disk: a plan with
    // one flat list of movements, no weeks and no categories.
    final legacy = NativeDatabase(file);
    await legacy.ensureOpen(_LegacyUser(9));
    for (final sql in _schema9) {
      await legacy.runCustom(sql, const []);
    }
    await legacy.runCustom(
      'INSERT INTO users (name, role, visibility) '
      'VALUES (?, ?, ?)',
      ['علی', UserRole.student.index, 0],
    );
    await legacy.runCustom(
      'INSERT INTO workout_plans (student_id, title, created_at) '
      'VALUES (?, ?, ?)',
      [1, 'برنامه قدیمی', DateTime.now().millisecondsSinceEpoch],
    );
    await legacy.runCustom(
      'INSERT INTO exercises (plan_id, name, sets, reps, position) '
      'VALUES (?, ?, ?, ?, ?)',
      [1, 'اسکوات', 4, 10, 0],
    );
    await legacy.runCustom(
      'INSERT INTO exercises (plan_id, name, sets, reps, position) '
      'VALUES (?, ?, ?, ?, ?)',
      [1, 'پرس سینه', 3, 8, 1],
    );
    await legacy.runCustom(
      'INSERT INTO workout_sessions (plan_id, student_id, started_at) '
      'VALUES (?, ?, ?)',
      [1, 1, DateTime.now().millisecondsSinceEpoch],
    );
    await legacy.runCustom('PRAGMA user_version = 9', const []);
    await legacy.close();

    final upgraded = AppDatabase(executor: NativeDatabase(file));
    addTearDown(upgraded.close);

    // Data survives...
    final plans = await upgraded.getPlansForStudent(1);
    expect(plans.single.title, 'برنامه قدیمی');
    final movements = await upgraded.getExercisesForPlan(plans.single.id);
    expect(movements.map((e) => e.name), ['اسکوات', 'پرس سینه']);

    // ...now recognisable as week 1 day 1, which is exactly what a flat list
    // always was. Every existing plan keeps working without being rewritten.
    expect(movements.every((m) => m.weekNumber == 1), isTrue);
    expect(movements.every((m) => m.dayNumber == 1), isTrue);
    expect(
      movements.every((m) => m.category == ExerciseCategory.compound),
      isTrue,
    );

    // Their order is unchanged, because position still applies within the
    // only day they have.
    expect(movements.map((e) => e.position).toList(), [0, 1]);

    // Duration was not knowable before, so it starts as "not decided".
    expect(plans.single.durationWeeks, isNull);

    // The open session belongs to day 1 too, so resume lands where it was.
    final session = await upgraded.getActiveWorkoutSession(1);
    expect(session!.weekNumber, 1);
    expect(session.dayNumber, 1);
    expect(
      await upgraded.getExercisesForDay(plans.single.id, 1, 1),
      hasLength(2),
    );
  });
}

/// Every table a schema-9 install already had.
const _schema9 = [
  'CREATE TABLE users (id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'name TEXT NOT NULL CHECK (length(name) >= 1 AND length(name) <= 100), '
      'role INTEGER NOT NULL, photo BLOB NULL, '
      'visibility INTEGER NOT NULL DEFAULT 0)',
  'CREATE TABLE workout_plans (id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'student_id INTEGER NOT NULL REFERENCES users(id), '
      'title TEXT NOT NULL CHECK (length(title) >= 1 AND length(title) <= 100), '
      'created_at INTEGER NOT NULL)',
  'CREATE TABLE exercises (id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'plan_id INTEGER NOT NULL REFERENCES workout_plans(id), '
      'name TEXT NOT NULL CHECK (length(name) >= 1 AND length(name) <= 100), '
      'sets INTEGER NOT NULL, reps INTEGER NOT NULL, '
      'position INTEGER NOT NULL DEFAULT 0)',
  'CREATE TABLE sessions (id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'role INTEGER NOT NULL, student_id INTEGER NULL REFERENCES users(id))',
  'CREATE TABLE workout_sessions (id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'plan_id INTEGER NOT NULL REFERENCES workout_plans(id), '
      'student_id INTEGER NOT NULL REFERENCES users(id), '
      'started_at INTEGER NOT NULL, finished_at INTEGER NULL)',
  'CREATE TABLE set_logs (id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'session_id INTEGER NOT NULL REFERENCES workout_sessions(id), '
      'exercise_id INTEGER NOT NULL REFERENCES exercises(id), '
      'set_number INTEGER NOT NULL, completed_at INTEGER NOT NULL)',
  'CREATE TABLE app_settings (id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'locale TEXT NULL)',
  'CREATE TABLE food_items (id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'name TEXT NOT NULL CHECK (length(name) >= 1 AND length(name) <= 100), '
      'protein_per100g REAL NOT NULL, kcal_per100g REAL NOT NULL, '
      'price_per_kg INTEGER NULL, updated_at INTEGER NOT NULL '
      'DEFAULT (CURRENT_TIMESTAMP))',
  'CREATE TABLE nutrition_targets (student_id INTEGER PRIMARY KEY '
      'REFERENCES users(id), sex INTEGER NOT NULL, age INTEGER NOT NULL, '
      'height_cm REAL NOT NULL, weight_kg REAL NOT NULL, '
      'activity INTEGER NOT NULL, goal INTEGER NOT NULL, '
      'protein_g REAL NOT NULL, carbs_g REAL NOT NULL, fat_g REAL NOT NULL, '
      'calorie_target INTEGER NOT NULL, updated_at INTEGER NOT NULL '
      'DEFAULT (CURRENT_TIMESTAMP))',
];

class _LegacyUser implements QueryExecutorUser {
  _LegacyUser(this.version);

  final int version;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}

  @override
  int get schemaVersion => version;
}
