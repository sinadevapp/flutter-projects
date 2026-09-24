import 'package:drift/drift.dart'
    show OpeningDetails, QueryExecutor, QueryExecutorUser, Value;
import 'package:drift/native.dart';
import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/test_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

/// What was actually lifted, as opposed to what the plan asked for.
///
/// Until now a set recorded only *that* it happened, so the app could not say
/// how much the student lifted, could not show a personal record, and had no
/// progression to offer on the next set. The plan's `sets`/`reps` are the
/// prescription; these are the attempt.
void main() {
  late AppDatabase db;
  late int student;
  late int plan;
  late int squat;
  late int session;

  setUp(() async {
    db = createTestDatabase();
    student = await db.insertUser(
      UsersCompanion.insert(name: 'علی', role: UserRole.student),
    );
    plan = await db.insertWorkoutPlan(
      WorkoutPlansCompanion.insert(studentId: student, title: 'برنامه'),
    );
    squat = await db.insertExercise(
      ExercisesCompanion.insert(
        planId: plan,
        name: 'اسکوات',
        sets: 4,
        reps: 10,
        targetWeightKg: const Value(80),
      ),
    );
    session = await db.startWorkoutSession(
      planId: plan,
      studentId: student,
      weekNumber: 1,
      dayNumber: 1,
    );
  });
  tearDown(() => db.close());

  test('a movement can carry the weight the coach prescribed', () async {
    final movement = (await db.getExercisesForPlan(plan)).single;

    expect(movement.targetWeightKg, 80);
  });

  test('no prescribed weight is normal — bodyweight needs none', () async {
    final pullUp = await db.insertExercise(
      ExercisesCompanion.insert(planId: plan, name: 'بارفیکس', sets: 3, reps: 8),
    );

    expect((await db.getExercisesForPlan(plan)).last.id, pullUp);
    final saved = (await db.getExercisesForPlan(plan)).last;
    expect(saved.targetWeightKg, isNull);
  });

  test('a logged set records what was lifted', () async {
    await db.logSet(
      sessionId: session,
      exerciseId: squat,
      setNumber: 1,
      weightKg: 82.5,
      reps: 10,
    );

    final log = (await db.getSetLogs(session)).single;
    expect(log.weightKg, 82.5);
    expect(log.repsPerformed, 10);
    // The movement still records the prescription — history does not rewrite
    // what the coach wrote.
    expect((await db.getExercisesForPlan(plan)).single.targetWeightKg, 80);
  });

  test('a set logged without a load still stores, as nulls', () async {
    await db.logSet(sessionId: session, exerciseId: squat, setNumber: 1);

    final log = (await db.getSetLogs(session)).single;
    expect(log.weightKg, isNull);
    expect(log.repsPerformed, isNull);
    // An earlier version of the app logged sets with no load at all, so null
    // has to remain a real state rather than a failure.
    expect(log.completedAt, isNotNull);
  });

  test('missing a rep is recordable — the attempt is the truth', () async {
    await db.logSet(
      sessionId: session,
      exerciseId: squat,
      setNumber: 1,
      weightKg: 82.5,
      reps: 7,
    );

    final log = (await db.getSetLogs(session)).single;
    expect(log.repsPerformed, 7);
    expect((await db.getExercisesForPlan(plan)).single.reps, 10,
        reason: 'the prescription must not be rewritten by the attempt');
  });

  test('every logged set of a session keeps its own load', () async {
    await db.logSet(
      sessionId: session,
      exerciseId: squat,
      setNumber: 1,
      weightKg: 80,
      reps: 10,
    );
    await db.logSet(
      sessionId: session,
      exerciseId: squat,
      setNumber: 2,
      weightKg: 77.5,
      reps: 8,
    );

    final logs = await db.getSetLogs(session);
    expect(logs.map((l) => l.setNumber).toList(), [1, 2]);
    expect(logs.map((l) => l.weightKg).toList(), [80, 77.5]);
    expect(logs.map((l) => l.repsPerformed).toList(), [10, 8]);
  });

  test('editing a prescribed weight does not touch what was lifted', () async {
    await db.logSet(
      sessionId: session,
      exerciseId: squat,
      setNumber: 1,
      weightKg: 82.5,
      reps: 10,
    );

    await db.updateExercise(squat, targetWeightKg: const Value(85));

    expect((await db.getExercisesForPlan(plan)).single.targetWeightKg, 85);
    expect((await db.getSetLogs(session)).single.weightKg, 82.5);
  });

  test('clearing the prescribed weight means bodyweight, not 0', () async {
    await db.updateExercise(squat, targetWeightKg: const Value(null));

    // "No prescription" is a real answer: a pull-up has no load, and 0 would
    // mean the empty bar alone — a different statement entirely.
    expect((await db.getExercisesForPlan(plan)).single.targetWeightKg, isNull);
  });

  test('omitting the parameter leaves the prescription alone', () async {
    await db.updateExercise(squat, targetWeightKg: const Value(85));
    await db.updateExercise(squat, name: 'اسکوات وزنه');

    final movement = (await db.getExercisesForPlan(plan)).single;
    expect(movement.name, 'اسکوات وزنه');
    expect(movement.targetWeightKg, 85);
  });

  test('a database created at schema 11 gains the load columns', () async {
    final dir = Directory.systemTemp.createTempSync('fit_load');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/legacy11.sqlite');

    final legacy = NativeDatabase(file);
    await legacy.ensureOpen(_LegacyUser(11));
    for (final sql in _schema11) {
      await legacy.runCustom(sql, const []);
    }
    await legacy.runCustom(
      'INSERT INTO users (name, role) VALUES (?, ?)',
      ['علی', UserRole.student.index],
    );
    await legacy.runCustom(
      'INSERT INTO workout_plans (student_id, title, created_at) VALUES (?,?,?)',
      [1, 'برنامه', DateTime.now().millisecondsSinceEpoch],
    );
    await legacy.runCustom(
      'INSERT INTO exercises (plan_id, name, sets, reps, position, '
      'week_number, day_number, category) VALUES (?,?,?,?,?,?,?,?)',
      [1, 'اسکوات', 4, 10, 0, 1, 1, 6],
    );
    await legacy.runCustom(
      'INSERT INTO workout_sessions (plan_id, student_id, started_at) '
      'VALUES (?,?,?)',
      [1, 1, DateTime.now().millisecondsSinceEpoch],
    );
    // A set logged before this change: no load, because there was nowhere to
    // put it. It must stay readable rather than break the upgrade.
    await legacy.runCustom(
      'INSERT INTO set_logs (session_id, exercise_id, set_number, completed_at) '
      'VALUES (?,?,?,?)',
      [1, 1, 1, DateTime.now().millisecondsSinceEpoch],
    );
    await legacy.runCustom('PRAGMA user_version = 11', const []);
    await legacy.close();

    final upgraded = AppDatabase(executor: NativeDatabase(file));
    addTearDown(upgraded.close);

    final logs = await upgraded.getSetLogs(1);
    expect(logs.single.weightKg, isNull);
    expect(logs.single.repsPerformed, isNull);

    expect((await upgraded.getExercisesForPlan(1)).single.targetWeightKg,
        isNull);

    // And the new columns are usable straight away.
    final session = (await upgraded.getPlansForStudent(1)).single.id;
    expect(session, 1);
    await upgraded.logSet(
      sessionId: 1,
      exerciseId: 1,
      setNumber: 2,
      weightKg: 90,
      reps: 8,
    );
    final after = await upgraded.getSetLogs(1);
    expect(after.last.weightKg, 90);
    expect(after.last.repsPerformed, 8);
  });
}

/// Every table a schema-11 install already had.
const _schema11 = [
  'CREATE TABLE users (id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'name TEXT NOT NULL CHECK (length(name) >= 1 AND length(name) <= 100), '
      'role INTEGER NOT NULL, photo BLOB NULL, '
      'visibility INTEGER NOT NULL DEFAULT 0)',
  'CREATE TABLE workout_plans (id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'student_id INTEGER NOT NULL REFERENCES users(id), '
      'title TEXT NOT NULL CHECK (length(title) >= 1 AND length(title) <= 100), '
      'created_at INTEGER NOT NULL, duration_weeks INTEGER NULL)',
  'CREATE TABLE exercises (id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'plan_id INTEGER NOT NULL REFERENCES workout_plans(id), '
      'name TEXT NOT NULL CHECK (length(name) >= 1 AND length(name) <= 100), '
      'sets INTEGER NOT NULL, reps INTEGER NOT NULL, '
      'position INTEGER NOT NULL DEFAULT 0, '
      'week_number INTEGER NOT NULL DEFAULT 1, '
      'day_number INTEGER NOT NULL DEFAULT 1, '
      'category INTEGER NOT NULL DEFAULT 6)',
  'CREATE TABLE sessions (id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'role INTEGER NOT NULL, student_id INTEGER NULL REFERENCES users(id))',
  // `started_at` likewise defaults in the real DDL, so it defaults here.
  'CREATE TABLE workout_sessions (id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'plan_id INTEGER NOT NULL REFERENCES workout_plans(id), '
      'student_id INTEGER NOT NULL REFERENCES users(id), '
      'started_at INTEGER NOT NULL, '
      'finished_at INTEGER NULL, '
      'week_number INTEGER NOT NULL DEFAULT 1, '
      'day_number INTEGER NOT NULL DEFAULT 1)',
  // `completed_at` needs *a* default: drift's `logSet` omits it and expects
  // the column to fill itself, so with none the insert supplies NULL and
  // fails NOT NULL.
  //
  // The value is deliberately not the real DDL's timestamp expression. That
  // expression makes SQLite reject the CREATE outright here ("default value …
  // is not constant"), and reading it back would need drift's own DateTime
  // decoding of it. What this fixture owes the test is a schema drift can
  // write to and read from — not a copy of how drift spells its default.
  'CREATE TABLE set_logs (id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'session_id INTEGER NOT NULL REFERENCES workout_sessions(id), '
      'exercise_id INTEGER NOT NULL REFERENCES exercises(id), '
      'set_number INTEGER NOT NULL, completed_at INTEGER NOT NULL '
      'DEFAULT 0)',
  'CREATE TABLE app_settings (id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'locale TEXT NULL)',
  'CREATE TABLE plan_days (id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'plan_id INTEGER NOT NULL REFERENCES workout_plans(id), '
      'week_number INTEGER NOT NULL, day_number INTEGER NOT NULL, '
      'title TEXT NULL, is_rest_day INTEGER NOT NULL DEFAULT 0)',
  'CREATE TABLE food_items (id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'name TEXT NOT NULL CHECK (length(name) >= 1 AND length(name) <= 100), '
      'protein_per100g REAL NOT NULL, kcal_per100g REAL NOT NULL, '
      'price_per_kg INTEGER NULL, updated_at INTEGER NOT NULL '
      'DEFAULT 0)',
  'CREATE TABLE nutrition_targets (student_id INTEGER PRIMARY KEY '
      'REFERENCES users(id), sex INTEGER NOT NULL, age INTEGER NOT NULL, '
      'height_cm REAL NOT NULL, weight_kg REAL NOT NULL, '
      'activity INTEGER NOT NULL, goal INTEGER NOT NULL, '
      'protein_g REAL NOT NULL, carbs_g REAL NOT NULL, fat_g REAL NOT NULL, '
      'calorie_target INTEGER NOT NULL, updated_at INTEGER NOT NULL '
      'DEFAULT 0)',
];

class _LegacyUser implements QueryExecutorUser {
  _LegacyUser(this.version);

  final int version;

  @override
  Future<void> beforeOpen(
      QueryExecutor executor, OpeningDetails details) async {}

  @override
  int get schemaVersion => version;
}
