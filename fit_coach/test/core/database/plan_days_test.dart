import 'dart:io';

import 'package:drift/drift.dart'
    show OpeningDetails, QueryExecutor, QueryExecutorUser, Value;
import 'package:drift/native.dart';
import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/test_database.dart';
import 'package:flutter_test/flutter_test.dart';

/// Days as their own rows: a title, and whether the coach planned rest.
///
/// Exercises still carry their own `weekNumber` / `dayNumber`, so nothing
/// about the existing shape changes. The table exists because a day with no
/// movements in it — the most common kind, a rest day — has nowhere else to
/// live.
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

  Future<int> movement({required String name, int week = 1, int day = 1}) =>
      db.insertExercise(ExercisesCompanion.insert(
        planId: plan,
        weekNumber: Value(week),
        dayNumber: Value(day),
        name: name,
        sets: 3,
        reps: 10,
      ));

  group('reading days', () {
    test('a plan with nothing in it has no days', () async {
      expect(await db.getDays(plan), isEmpty);
    });

    test('a day appears once its first movement is written', () async {
      await movement(name: 'الف');
      await movement(name: 'ب');

      final days = await db.getDays(plan);
      expect(days, hasLength(1));
      expect(days.single.weekNumber, 1);
      expect(days.single.dayNumber, 1);
      expect(days.single.title, isNull);
      expect(days.single.isRestDay, isFalse);
    });

    test('days are ordered week then day', () async {
      await movement(name: 'الف', week: 2, day: 1);
      await movement(name: 'ب', week: 1, day: 2);
      await movement(name: 'پ', week: 1, day: 1);

      final order = await db.getDays(plan);
      expect(
        order.map((d) => '${d.weekNumber}/${d.dayNumber}').toList(),
        ['1/1', '1/2', '2/1'],
      );
    });
  });

  group('naming a day', () {
    test('a title can be set on a day that has movements', () async {
      await movement(name: 'الف');

      await db.setDayTitle(plan, week: 1, day: 1, title: 'بالاتنه');

      expect((await db.getDays(plan)).single.title, 'بالاتنه');
    });

    test('the title belongs to the day, not to a movement', () async {
      await movement(name: 'الف');
      await movement(name: 'ب');

      await db.setDayTitle(plan, week: 1, day: 1, title: 'پا');

      // Every movement of that day reads the same title; the rows themselves
      // are unchanged.
      expect((await db.getDays(plan)).single.title, 'پا');
      expect(
        (await db.getExercisesForPlan(plan)).map((e) => e.name).toList(),
        ['الف', 'ب'],
      );
    });

    test('titling one day leaves its neighbours alone', () async {
      await movement(name: 'الف', day: 1);
      await movement(name: 'ب', day: 2);

      await db.setDayTitle(plan, week: 1, day: 1, title: 'بالاتنه');

      final days = await db.getDays(plan);
      expect(days[0].title, 'بالاتنه');
      expect(days[1].title, isNull);
    });

    test('a title can be cleared', () async {
      await movement(name: 'الف');
      await db.setDayTitle(plan, week: 1, day: 1, title: 'پا');

      await db.setDayTitle(plan, week: 1, day: 1, title: null);

      expect((await db.getDays(plan)).single.title, isNull);
    });
  });

  group('rest days', () {
    test('marking a day as rest creates it without any movements', () async {
      // This is the point: a rest day has nothing to hang off, which is why
      // it needs a row of its own rather than being derived from exercises.
      await db.setDayRest(plan, week: 1, day: 3, isRest: true);

      final day = (await db.getDays(plan)).single;
      expect(day.weekNumber, 1);
      expect(day.dayNumber, 3);
      expect(day.isRestDay, isTrue);
      expect(await db.getExercisesForPlan(plan), isEmpty);
    });

    test('a rest day can still carry a name', () async {
      await db.setDayRest(plan, week: 1, day: 3, isRest: true);
      await db.setDayTitle(plan, week: 1, day: 3, title: 'استراحت');

      final day = (await db.getDays(plan)).single;
      expect(day.isRestDay, isTrue);
      expect(day.title, 'استراحت');
    });

    test('un-resting a day keeps its title and movements', () async {
      await movement(name: 'الف');
      await db.setDayTitle(plan, week: 1, day: 1, title: 'پا');
      await db.setDayRest(plan, week: 1, day: 1, isRest: true);
      await db.setDayRest(plan, week: 1, day: 1, isRest: false);

      final day = (await db.getDays(plan)).single;
      expect(day.isRestDay, isFalse);
      expect(day.title, 'پا');
      expect(await db.getExercisesForPlan(plan), hasLength(1));
    });

    test('a rest day never has movements on it', () async {
      await db.setDayRest(plan, week: 1, day: 2, isRest: true);
      await movement(name: 'الف', day: 1);

      final restDays = (await db.getDays(plan)).where((d) => d.isRestDay);
      for (final day in restDays) {
        expect(
          await db.getExercisesForDay(plan, day.weekNumber, day.dayNumber),
          isEmpty,
        );
      }
    });
  });

  group('deleting', () {
    test('a plan takes its days with it', () async {
      await movement(name: 'الف');
      await db.setDayRest(plan, week: 1, day: 3, isRest: true);

      await db.deletePlan(plan);

      expect(await db.getDays(plan), isEmpty);
      expect(await db.select(db.planDays).get(), isEmpty);
    });

    test('other plans keep theirs', () async {
      final other = await db.insertWorkoutPlan(
        WorkoutPlansCompanion.insert(studentId: student, title: 'دیگر'),
      );
      await movement(name: 'الف');
      await db.insertExercise(ExercisesCompanion.insert(
        planId: other,
        name: 'لانج',
        sets: 3,
        reps: 10,
      ));

      await db.deletePlan(plan);

      expect((await db.getDays(other)).map((d) => d.title).toList(),
          [null]);
    });
  });

  group('migration', () {
    test('a database created at schema 10 gains day rows for its plans',
        () async {
      final dir = Directory.systemTemp.createTempSync('fit_plan_days');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/legacy10.sqlite');

      // A schema-10 install: weeks and days live on the movements, and there
      // is no row for a day at all.
      final legacy = NativeDatabase(file);
      await legacy.ensureOpen(_LegacyUser(10));
      for (final sql in _schema10) {
        await legacy.runCustom(sql, const []);
      }
      await legacy.runCustom(
        'INSERT INTO users (name, role) VALUES (?, ?)',
        ['علی', UserRole.student.index],
      );
      await legacy.runCustom(
        'INSERT INTO workout_plans (student_id, title, created_at) VALUES (?,?,?)',
        [1, 'برنامه قدیمی', DateTime.now().millisecondsSinceEpoch],
      );
      await legacy.runCustom(
        'INSERT INTO exercises (plan_id, name, sets, reps, position, '
        'week_number, day_number, category) VALUES (?,?,?,?,?,?,?,?)',
        [1, 'اسکوات', 4, 10, 0, 1, 1, ExerciseCategory.legs.index],
      );
      await legacy.runCustom(
        'INSERT INTO exercises (plan_id, name, sets, reps, position, '
        'week_number, day_number, category) VALUES (?,?,?,?,?,?,?,?)',
        [1, 'پرس سینه', 3, 8, 0, 1, 2, ExerciseCategory.chest.index],
      );
      await legacy.runCustom(
        'INSERT INTO exercises (plan_id, name, sets, reps, position, '
        'week_number, day_number, category) VALUES (?,?,?,?,?,?,?,?)',
        [1, 'لانج', 3, 12, 0, 2, 1, ExerciseCategory.legs.index],
      );
      await legacy.runCustom('PRAGMA user_version = 10', const []);
      await legacy.close();

      final upgraded = AppDatabase(executor: NativeDatabase(file));
      addTearDown(upgraded.close);

      // Nothing about the existing plan changed...
      final movements = await upgraded.getExercisesForPlan(1);
      expect(movements.map((m) => m.name).toList(),
          ['اسکوات', 'پرس سینه', 'لانج']);
      expect(movements.first.category, ExerciseCategory.legs);

      // ...but every distinct (week, day) now has a row of its own, unnamed
      // until the coach names it. That is what a flat list was hiding.
      final days = await upgraded.getDays(1);
      expect(
        days.map((d) => '${d.weekNumber}/${d.dayNumber}').toList(),
        ['1/1', '1/2', '2/1'],
      );
      expect(days.every((d) => d.title == null), isTrue);
      expect(days.every((d) => !d.isRestDay), isTrue);
    });
  });
}

/// Every table a schema-10 install already had.
const _schema10 = [
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
  'CREATE TABLE workout_sessions (id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'plan_id INTEGER NOT NULL REFERENCES workout_plans(id), '
      'student_id INTEGER NOT NULL REFERENCES users(id), '
      'started_at INTEGER NOT NULL, finished_at INTEGER NULL, '
      'week_number INTEGER NOT NULL DEFAULT 1, '
      'day_number INTEGER NOT NULL DEFAULT 1)',
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
      QueryExecutor executor, OpeningDetails details) async {}

  @override
  int get schemaVersion => version;
}
