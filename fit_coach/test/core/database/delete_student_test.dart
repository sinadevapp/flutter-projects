import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/test_database.dart';
import 'package:flutter_test/flutter_test.dart';

/// Removing one student.
///
/// Everything the student produced hangs off them through foreign keys, so
/// this has to run leaf-first inside one transaction — the same shape as
/// [AppDatabase.deleteAllUsers], but leaving everyone else's data alone.
void main() {
  late AppDatabase db;
  late int ali;
  late int reza;

  setUp(() async {
    db = createTestDatabase();
    ali = await db.insertUser(
      UsersCompanion.insert(name: 'علی', role: UserRole.student),
    );
    reza = await db.insertUser(
      UsersCompanion.insert(name: 'رضا', role: UserRole.student),
    );
  });
  tearDown(() => db.close());

  Future<int> planFor(int studentId) => db.insertWorkoutPlan(
        WorkoutPlansCompanion.insert(studentId: studentId, title: 'برنامه'),
      );

  /// A complete trail for one student: plan, movement, trained session.
  Future<({int plan, int session})> train(int studentId) async {
    final plan = await planFor(studentId);
    final movement = await db.insertExercise(
      ExercisesCompanion.insert(
        planId: plan,
        name: 'اسکوات',
        sets: 3,
        reps: 10,
        weekNumber: const Value(1),
        dayNumber: const Value(1),
      ),
    );
    final session = await db.startWorkoutSession(
      planId: plan,
      studentId: studentId,
      weekNumber: 1,
      dayNumber: 1,
    );
    await db.logSet(sessionId: session, exerciseId: movement, setNumber: 1);
    await db.finishWorkoutSession(session);
    await db.saveNutritionTarget(
      NutritionTargetsCompanion.insert(
        studentId: Value(studentId),
        sex: 0,
        age: 30,
        heightCm: 180,
        weightKg: 80,
        activity: 2,
        goal: 1,
      ),
    );
    return (plan: plan, session: session);
  }

  test('deleting a student removes their row', () async {
    await db.deleteStudent(ali);

    final names = (await db.getAllUsers()).map((u) => u.name).toList();
    expect(names, ['رضا']);
    // `getUser` reads a single row, so a deleted student has none — which is
    // the behaviour, not an accident to paper over.
    expect(names, isNot(contains('علی')));
  });

  test('everything they produced goes with them', () async {
    await train(ali);

    await db.deleteStudent(ali);

    // Foreign keys are on, so an orphan anywhere would have thrown rather
    // than silently leaving a row behind.
    expect(await db.select(db.workoutPlans).get(), isEmpty);
    expect(await db.select(db.exercises).get(), isEmpty);
    expect(await db.select(db.workoutSessions).get(), isEmpty);
    expect(await db.select(db.setLogs).get(), isEmpty);
    expect(await db.select(db.nutritionTargets).get(), isEmpty);
  });

  test('other students are untouched', () async {
    await train(ali);
    final other = await train(reza);

    await db.deleteStudent(ali);

    expect((await db.getAllUsers()).map((u) => u.name).toList(), ['رضا']);
    expect(
      (await db.getPlansForStudent(reza)).map((p) => p.id).toList(),
      [other.plan],
    );
    expect(
      (await db.select(db.workoutSessions).get())
          .map((s) => s.id)
          .toList(),
      [other.session],
    );
    expect(
      (await db.select(db.setLogs).get()).map((l) => l.sessionId).toList(),
      [other.session],
    );
    expect(await db.getNutritionTarget(reza), isNotNull);
  });

  test('a student\'s sign-in row goes too, but not the coach\'s', () async {
    await db.setActiveRole(UserRole.student, studentId: ali);

    expect(await db.getActiveStudentId(), ali);

    await db.deleteStudent(ali);

    // The device was signed in as them — it must fall back to the picker
    // rather than keep pointing at a row that no longer exists.
    expect(await db.getActiveStudentId(), isNull);

    await db.setActiveRole(UserRole.coach);
    await db.deleteStudent(reza);
    expect(await db.getActiveRole(), UserRole.coach);
  });

  test('deleting an open (unfinished) session is safe', () async {
    final plan = await planFor(ali);
    final session = await db.startWorkoutSession(
      planId: plan,
      studentId: ali,
      weekNumber: 1,
      dayNumber: 1,
    );
    expect(await db.getActiveWorkoutSession(ali), isNotNull);

    await db.deleteStudent(ali);

    expect(await db.getActiveWorkoutSession(ali), isNull);
    expect(await db.select(db.workoutSessions).get(), isEmpty);
    expect(session, isPositive);
  });

  test('deleting a student who has no plans is safe', () async {
    await db.deleteStudent(ali);

    expect(await db.getAllUsers(), hasLength(1));
    expect(await db.select(db.workoutPlans).get(), isEmpty);
  });

  test("a student's photo and type go with the row", () async {
    await db.updateStudentPhoto(ali, Uint8List.fromList([1, 2, 3]));
    await db.updateStudentVisibility(ali, StudentVisibility.public);

    await db.deleteStudent(ali);

    // There is no dangling avatar: the bytes lived on the row itself.
    final remaining = await db.getAllUsers();
    expect(remaining.single.name, 'رضا');
    expect(remaining.single.photo, isNull);
    expect(remaining.single.visibility, StudentVisibility.private);
  });
}
