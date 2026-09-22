import 'dart:io';

import 'package:drift/drift.dart'
    show OpeningDetails, QueryExecutor, QueryExecutorUser, Value;
import 'package:drift/native.dart';
import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/test_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late int studentId;

  setUp(() async {
    db = createTestDatabase();
    studentId = await db.insertUser(
      UsersCompanion.insert(name: 'علی', role: UserRole.student),
    );
  });
  tearDown(() => db.close());

  NutritionTargetsCompanion profile({
    int? forStudent,
    int age = 30,
    double weightKg = 80,
    int goal = 0,
  }) =>
      NutritionTargetsCompanion.insert(
        studentId: Value(forStudent ?? studentId),
        sex: 0,
        age: age,
        heightCm: 180,
        weightKg: weightKg,
        activity: 2,
        goal: goal,
        updatedAt: Value(DateTime(2026, 9, 22)),
      );

  test('a student with no profile has none stored', () async {
    expect(await db.getNutritionTarget(studentId), isNull);
  });

  test('a profile round-trips with every field', () async {
    await db.saveNutritionTarget(profile());

    final saved = await db.getNutritionTarget(studentId);
    expect(saved, isNotNull);
    expect(saved!.studentId, studentId);
    expect(saved.sex, 0);
    expect(saved.age, 30);
    expect(saved.heightCm, 180);
    expect(saved.weightKg, 80);
    expect(saved.activity, 2);
    expect(saved.goal, 0);
  });

  test('saving twice replaces the profile rather than adding a second',
      () async {
    await db.saveNutritionTarget(profile(weightKg: 80));
    await db.saveNutritionTarget(profile(weightKg: 75));

    final saved = await db.getNutritionTarget(studentId);
    expect(saved!.weightKg, 75);

    // One profile per student: the table must not grow a history of them.
    final all = await db.select(db.nutritionTargets).get();
    expect(all, hasLength(1));
  });

  test('each student keeps their own profile', () async {
    final other = await db.insertUser(
      UsersCompanion.insert(name: 'رضا', role: UserRole.student),
    );
    await db.saveNutritionTarget(profile(weightKg: 80));
    await db.saveNutritionTarget(profile(forStudent: other, weightKg: 65));

    expect((await db.getNutritionTarget(studentId))!.weightKg, 80);
    expect((await db.getNutritionTarget(other))!.weightKg, 65);
  });

  test('deleting a student takes their profile with them', () async {
    await db.saveNutritionTarget(profile());

    // FK enforcement is on, so this must cascade or fail cleanly — either
    // way the coach resetting their data must not trip a constraint error.
    await db.deleteAllUsers();

    expect(await db.getAllUsers(), isEmpty);
    expect(await db.getNutritionTarget(studentId), isNull);
  });

  test('a database created at schema 7 upgrades and gains nutrition targets',
      () async {
    final dir = Directory.systemTemp.createTempSync('fit_coach_upgrade7');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/legacy7.sqlite');

    final legacy = NativeDatabase(file);
    await legacy.ensureOpen(_LegacyUser(7));
    for (final sql in _schema7) {
      await legacy.runCustom(sql, const []);
    }
    await legacy.runCustom('INSERT INTO users (name, role) VALUES (?, ?)',
        ['علی', UserRole.student.index]);
    await legacy.runCustom('PRAGMA user_version = 7', const []);
    await legacy.close();

    final upgraded = AppDatabase(executor: NativeDatabase(file));
    addTearDown(upgraded.close);

    // The coach's existing data survives. Note the legacy table was created
    // empty and no seed re-runs here: `from < 7` is not taken on a schema-7
    // database, and re-seeding on every open would undo a deliberate delete.
    expect((await upgraded.getAllUsers()).map((u) => u.name), ['علی']);

    // ...and the new table is usable against the student who was already there.
    final id = (await upgraded.getAllUsers()).single.id;
    await upgraded.saveNutritionTarget(
      NutritionTargetsCompanion.insert(
        studentId: Value(id),
        sex: 0,
        age: 30,
        heightCm: 180,
        weightKg: 80,
        activity: 2,
        goal: 0,
        updatedAt: Value(DateTime(2026, 9, 22)),
      ),
    );
    expect((await upgraded.getNutritionTarget(id))!.weightKg, 80);
  });
}

/// The tables a schema-7 install already had, in the exact shape Drift emits.
const _schema7 = [
  'CREATE TABLE users (id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'name TEXT NOT NULL, role INTEGER NOT NULL)',
  'CREATE TABLE workout_plans (id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'student_id INTEGER NOT NULL REFERENCES users(id), '
      'title TEXT NOT NULL, created_at INTEGER NOT NULL)',
  'CREATE TABLE exercises (id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'plan_id INTEGER NOT NULL REFERENCES workout_plans(id), '
      'name TEXT NOT NULL, sets INTEGER NOT NULL, reps INTEGER NOT NULL, '
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
      'name TEXT NOT NULL, protein_per100g REAL NOT NULL, '
      'kcal_per100g REAL NOT NULL, price_per_kg INTEGER NULL, '
      'updated_at INTEGER NOT NULL)',
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
