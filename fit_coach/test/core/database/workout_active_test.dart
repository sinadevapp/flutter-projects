import 'dart:io';

import 'package:drift/native.dart';
import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/test_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late int studentId;
  late int planId;
  late int squatId;
  late int benchId;

  setUp(() async {
    db = createTestDatabase();
    studentId = await db.insertUser(
      UsersCompanion.insert(name: 'علی', role: UserRole.student),
    );
    planId = await db.insertWorkoutPlan(
      WorkoutPlansCompanion.insert(studentId: studentId, title: 'برنامه حجم'),
    );
    squatId = await db.insertExercise(
      ExercisesCompanion.insert(
        planId: planId,
        name: 'اسکوات',
        sets: 2,
        reps: 10,
      ),
    );
    benchId = await db.insertExercise(
      ExercisesCompanion.insert(
        planId: planId,
        name: 'پرس سینه',
        sets: 3,
        reps: 8,
      ),
    );
  });

  tearDown(() => db.close());

  test('a started workout becomes the student\'s active session', () async {
    expect(await db.getActiveWorkoutSession(studentId), isNull);

    final sessionId = await db.startWorkoutSession(
      planId: planId,
      studentId: studentId,
      weekNumber: 1,
      dayNumber: 1,
    );

    final active = await db.getActiveWorkoutSession(studentId);
    expect(active!.id, sessionId);
    expect(active.planId, planId);
    expect(active.finishedAt, isNull);
  });

  test('logging sets records them in order against the workout', () async {
    final sessionId = await db.startWorkoutSession(
      planId: planId,
      studentId: studentId,
      weekNumber: 1,
      dayNumber: 1,
    );

    await db.logSet(sessionId: sessionId, exerciseId: squatId, setNumber: 1);
    await db.logSet(sessionId: sessionId, exerciseId: squatId, setNumber: 2);
    await db.logSet(sessionId: sessionId, exerciseId: benchId, setNumber: 1);

    final logs = await db.getSetLogs(sessionId);
    expect(logs.length, 3);
    expect(logs.map((l) => l.setNumber).toList(), [1, 2, 1]);
    expect(logs.map((l) => l.exerciseId).toList(), [squatId, squatId, benchId]);
  });

  test(
    'an unfinished workout is still there after reopening the database',
    () async {
      final dir = Directory.systemTemp.createTempSync('fit_coach_workout');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/workout.sqlite');

      // Fresh database on disk: the coach's plan, then the student starts.
      final first = AppDatabase(executor: NativeDatabase(file));
      final student = await first.insertUser(
        UsersCompanion.insert(name: 'علی', role: UserRole.student),
      );
      final plan = await first.insertWorkoutPlan(
        WorkoutPlansCompanion.insert(studentId: student, title: 'برنامه حجم'),
      );
      final squat = await first.insertExercise(
        ExercisesCompanion.insert(
          planId: plan,
          name: 'اسکوات',
          sets: 4,
          reps: 10,
        ),
      );
      final session = await first.startWorkoutSession(
        planId: plan,
        studentId: student,
        weekNumber: 1,
        dayNumber: 1,
      );
      await first.logSet(sessionId: session, exerciseId: squat, setNumber: 1);
      await first.logSet(sessionId: session, exerciseId: squat, setNumber: 2);
      await first.close();

      // The app was killed mid-workout and is launched again.
      final second = AppDatabase(executor: NativeDatabase(file));
      addTearDown(second.close);

      final resumed = await second.getActiveWorkoutSession(student);
      expect(resumed, isNotNull);
      expect(resumed!.id, session);
      expect((await second.getSetLogs(resumed.id)).length, 2);
    },
  );

  test(
    'a finished workout is not resumed, and a new one can be started',
    () async {
      final first = await db.startWorkoutSession(
        planId: planId,
        studentId: studentId,
        weekNumber: 1,
        dayNumber: 1,
      );
      await db.logSet(sessionId: first, exerciseId: squatId, setNumber: 1);
      await db.finishWorkoutSession(first);

      expect(await db.getActiveWorkoutSession(studentId), isNull);

      final second = await db.startWorkoutSession(
        planId: planId,
        studentId: studentId,
        weekNumber: 1,
        dayNumber: 1,
      );
      expect(second, isNot(first));
      expect((await db.getActiveWorkoutSession(studentId))!.id, second);

      // The finished workout's history is intact.
      expect((await db.getSetLogs(first)).length, 1);
      expect(await db.getSetLogs(second), isEmpty);
    },
  );
}
