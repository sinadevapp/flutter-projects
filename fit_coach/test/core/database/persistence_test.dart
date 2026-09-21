import 'dart:io';

import 'package:drift/drift.dart' show OpeningDetails, QueryExecutor, QueryExecutorUser;
import 'package:drift/native.dart';
import 'package:fit_coach/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('students and plans survive closing and reopening the database',
      () async {
    final dir = Directory.systemTemp.createTempSync('fit_coach_persist');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/fit_coach.sqlite');

    final first = AppDatabase(executor: NativeDatabase(file));
    final studentId = await first.insertUser(
      UsersCompanion.insert(name: 'علی', role: UserRole.student),
    );
    final planId = await first.insertWorkoutPlan(
      WorkoutPlansCompanion.insert(studentId: studentId, title: 'برنامه حجم'),
    );
    await first.insertExercise(ExercisesCompanion.insert(
      planId: planId,
      name: 'اسکوات',
      sets: 4,
      reps: 10,
    ));
    await first.close();

    // A brand-new connection to the same file: this is what hot restart /
    // reopening the app does.
    final second = AppDatabase(executor: NativeDatabase(file));
    addTearDown(second.close);

    expect((await second.getAllUsers()).map((u) => u.name), ['علی']);
    final plans = await second.getPlansForStudent(studentId);
    expect(plans.single.title, 'برنامه حجم');
    expect((await second.getExercisesForPlan(plans.single.id)).single.name,
        'اسکوات');
  });

  test('a database created at schema 2 upgrades without losing data', () async {
    final dir = Directory.systemTemp.createTempSync('fit_coach_upgrade');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/legacy.sqlite');

    // The schema an older install of the app left on disk.
    final legacy = NativeDatabase(file);
    await legacy.ensureOpen(_NoopUser());
    await legacy.runCustom(
      'CREATE TABLE users (id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'name TEXT NOT NULL, role INTEGER NOT NULL)',
      const [],
    );
    await legacy.runCustom(
      'CREATE TABLE workout_plans (id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'student_id INTEGER NOT NULL REFERENCES users(id), '
      'title TEXT NOT NULL, created_at INTEGER NOT NULL)',
      const [],
    );
    await legacy.runCustom(
      'CREATE TABLE exercises (id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'plan_id INTEGER NOT NULL REFERENCES workout_plans(id), '
      'name TEXT NOT NULL, sets INTEGER NOT NULL, reps INTEGER NOT NULL, '
      'position INTEGER NOT NULL DEFAULT 0)',
      const [],
    );
    await legacy.runCustom('INSERT INTO users (name, role) VALUES (?, ?)',
        ['علی', UserRole.student.index]);
    await legacy.runCustom('PRAGMA user_version = 2', const []);
    await legacy.close();

    // Opening with the current code must run the migration, not crash.
    final upgraded = AppDatabase(executor: NativeDatabase(file));
    addTearDown(upgraded.close);

    expect((await upgraded.getAllUsers()).map((u) => u.name), ['علی']);
    expect(await upgraded.getActiveRole(), isNull);
    await upgraded.setActiveRole(UserRole.coach);
    expect(await upgraded.getActiveRole(), UserRole.coach);
  });
  test('a database created at schema 3 upgrades and can store a student id',
      () async {
    final dir = Directory.systemTemp.createTempSync('fit_coach_upgrade3');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/legacy3.sqlite');

    // Schema 3: sessions existed, but without the student_id column.
    final legacy = NativeDatabase(file);
    await legacy.ensureOpen(_NoopUser());
    await legacy.runCustom(
      'CREATE TABLE users (id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'name TEXT NOT NULL, role INTEGER NOT NULL)',
      const [],
    );
    await legacy.runCustom(
      'CREATE TABLE workout_plans (id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'student_id INTEGER NOT NULL REFERENCES users(id), '
      'title TEXT NOT NULL, created_at INTEGER NOT NULL)',
      const [],
    );
    await legacy.runCustom(
      'CREATE TABLE exercises (id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'plan_id INTEGER NOT NULL REFERENCES workout_plans(id), '
      'name TEXT NOT NULL, sets INTEGER NOT NULL, reps INTEGER NOT NULL, '
      'position INTEGER NOT NULL DEFAULT 0)',
      const [],
    );
    await legacy.runCustom(
      'CREATE TABLE sessions (id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'role INTEGER NOT NULL)',
      const [],
    );
    await legacy.runCustom('PRAGMA user_version = 3', const []);
    await legacy.close();

    final upgraded = AppDatabase(executor: NativeDatabase(file));
    addTearDown(upgraded.close);

    final studentId = await upgraded.insertUser(
      UsersCompanion.insert(name: 'علی', role: UserRole.student),
    );
    await upgraded.setActiveRole(UserRole.student, studentId: studentId);

    expect(await upgraded.getActiveRole(), UserRole.student);
    expect(await upgraded.getActiveStudentId(), studentId);
  });
}

/// The legacy connection only needs to open; no query callbacks are used.
class _NoopUser implements QueryExecutorUser {
  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}

  @override
  int get schemaVersion => 4;
}
