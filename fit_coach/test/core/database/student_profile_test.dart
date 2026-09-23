import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart'
    show OpeningDetails, QueryExecutor, QueryExecutorUser;
import 'package:drift/native.dart';
import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/test_database.dart';
import 'package:flutter_test/flutter_test.dart';

/// A stand-in for a picked photo: the picker stores bytes, so any bytes do.
Uint8List fakePhoto([int seed = 7]) =>
    Uint8List.fromList(List.generate(64, (i) => (i + seed) & 0xff));

void main() {
  group('student profile columns', () {
    test('a new student defaults to private and photo-less', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final id = await db.insertUser(
        UsersCompanion.insert(name: 'سینا', role: UserRole.student),
      );

      final student = await db.getUser(id);
      // No photo is the normal case: the UI falls back to the default icon.
      expect(student.photo, isNull);
      expect(student.visibility, StudentVisibility.private);
    });

    test('a chosen photo round-trips byte for byte', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final id = await db.insertUser(
        UsersCompanion.insert(name: 'سینا', role: UserRole.student),
      );
      final bytes = fakePhoto();

      await db.updateStudentPhoto(id, bytes);

      final student = await db.getUser(id);
      expect(student.photo, bytes,
          reason: 'compressed bytes must survive the round trip');
      // The student is still the same student.
      expect(student.name, 'سینا');
      expect(student.visibility, StudentVisibility.private);
    });

    test('removing a photo blanks it rather than leaving stale bytes',
        () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final id = await db.insertUser(
        UsersCompanion.insert(name: 'سینا', role: UserRole.student),
      );
      await db.updateStudentPhoto(id, fakePhoto());
      expect((await db.getUser(id)).photo, isNotNull);

      await db.updateStudentPhoto(id, null);

      // Null means "no photo" and falls back to the default icon; leaving the
      // old bytes would show a photo the coach thought they removed.
      expect((await db.getUser(id)).photo, isNull);
    });

    test('the coach can set public and private per student', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final id = await db.insertUser(
        UsersCompanion.insert(name: 'سینا', role: UserRole.student),
      );
      expect((await db.getUser(id)).visibility, StudentVisibility.private);

      await db.updateStudentVisibility(id, StudentVisibility.public);
      expect((await db.getUser(id)).visibility, StudentVisibility.public);

      await db.updateStudentVisibility(id, StudentVisibility.private);
      expect((await db.getUser(id)).visibility, StudentVisibility.private);
    });

    test('editing one student never touches another', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final ali = await db.insertUser(
        UsersCompanion.insert(name: 'علی', role: UserRole.student),
      );
      final reza = await db.insertUser(
        UsersCompanion.insert(name: 'رضا', role: UserRole.student),
      );

      await db.updateStudentVisibility(reza, StudentVisibility.public);
      await db.updateStudentPhoto(reza, fakePhoto());

      final aliRow = await db.getUser(ali);
      expect(aliRow.visibility, StudentVisibility.private);
      expect(aliRow.photo, isNull);

      final rezaRow = await db.getUser(reza);
      expect(rezaRow.visibility, StudentVisibility.public);
      expect(rezaRow.photo, isNotNull);
    });
  });

  test('a database created at schema 8 upgrades and gains a profile',
      () async {
    final dir = Directory.systemTemp.createTempSync('fit_coach_upgrade8');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/legacy8.sqlite');

    // The schema an install of the previous version left on disk. Every table
    // matters: `onUpgrade` only runs on a database that already has them, and
    // drift verifies the whole schema after migrating.
    final legacy = NativeDatabase(file);
    await legacy.ensureOpen(_LegacyUser(8));
    for (final sql in _schema8) {
      await legacy.runCustom(sql, const []);
    }
    await legacy.runCustom('INSERT INTO users (name, role) VALUES (?, ?)',
        ['علی', UserRole.student.index]);
    await legacy.runCustom('PRAGMA user_version = 8', const []);
    await legacy.close();

    final upgraded = AppDatabase(executor: NativeDatabase(file));
    addTearDown(upgraded.close);

    // Existing data survives, with sensible defaults for the new columns.
    final students = await upgraded.getAllUsers();
    expect(students.map((s) => s.name), ['علی']);
    expect(students.single.visibility, StudentVisibility.private);
    expect(students.single.photo, isNull);

    // And the new columns are usable right away.
    await upgraded.updateStudentVisibility(
        students.single.id, StudentVisibility.public);
    await upgraded.updateStudentPhoto(students.single.id, fakePhoto(3));

    final reloaded = await upgraded.getUser(students.single.id);
    expect(reloaded.visibility, StudentVisibility.public);
    expect(reloaded.photo, fakePhoto(3));
    expect(reloaded.name, 'علی');
  });
}

/// Every table a schema-8 install already had, in the exact shape Drift emits.
/// Columns that schema 9 adds (`photo`, `visibility`) are deliberately absent —
/// that is what the migration has to add.
const _schema8 = [
  'CREATE TABLE users (id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'name TEXT NOT NULL CHECK (length(name) >= 1 AND length(name) <= 100), '
      'role INTEGER NOT NULL)',
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
  // Added in schema 7.
  'CREATE TABLE food_items (id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'name TEXT NOT NULL CHECK (length(name) >= 1 AND length(name) <= 100), '
      'protein_per100g REAL NOT NULL, kcal_per100g REAL NOT NULL, '
      'price_per_kg INTEGER NULL, updated_at INTEGER NOT NULL '
      "DEFAULT (CURRENT_TIMESTAMP))",
  // Added in schema 8.
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
