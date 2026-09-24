
import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:fit_coach/core/database/test_database.dart';
import 'package:fit_coach/core/database/workout_providers.dart';
import 'package:fit_coach/features/workout_active/presentation/active_workout_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_app.dart';

/// What this student last did for a movement.
///
/// The number the student needs most while standing at the bar: not the plan's
/// guess, but what they actually managed last time, and when. It is also what
/// a coach wants when writing the next week.
void main() {
  late AppDatabase db;
  late int student;
  late int plan;
  late int squat;
  late int bench;

  setUp(() async {
    db = createTestDatabase();
    student = await db.insertUser(
      UsersCompanion.insert(name: 'علی', role: UserRole.student),
    );
    plan = await db.insertWorkoutPlan(
      WorkoutPlansCompanion.insert(studentId: student, title: 'برنامه'),
    );
    squat = await db.insertExercise(
      ExercisesCompanion.insert(planId: plan, name: 'اسکوات', sets: 3, reps: 10),
    );
    bench = await db.insertExercise(
      ExercisesCompanion.insert(planId: plan, name: 'پرس سینه', sets: 3, reps: 8),
    );
  });
  tearDown(() => db.close());

  /// One finished session with a single set in it.
  ///
  /// Returns the timestamp the row actually carries, read back — so a test
  /// asserting on "when" proves the read path rather than the parameter it
  /// passed in. The `at` argument exists only to document intent; two sessions
  /// written in the same millisecond would otherwise look identical.
  Future<DateTime> train({
    required int exerciseId,
    double? weightKg,
    int? reps,
  }) async {
    final sessionId = await db.startWorkoutSession(
      planId: plan,
      studentId: student,
      weekNumber: 1,
      dayNumber: 1,
    );
    await db.logSet(
      sessionId: sessionId,
      exerciseId: exerciseId,
      setNumber: 1,
      weightKg: weightKg,
      reps: reps,
    );
    await db.finishWorkoutSession(sessionId);
    final logged = await db.getSetLogs(sessionId);
    return logged.first.completedAt;
  }

  Future<LastPerformance?> last(int exerciseId) async {
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    return container.read(lastPerformanceProvider(exerciseId).future);
  }

  test('nothing trained yet is null, not an error', () async {
    expect(await last(squat), isNull);
  });

  test('reports the most recent session, not the first', () async {
    await train(
      exerciseId: squat,
      weightKg: 75,
      reps: 8,
    );
    await train(
      exerciseId: squat,
      weightKg: 82.5,
      reps: 7,
    );

    final found = (await last(squat))!;
    expect(found.weightKg, 82.5);
    expect(found.reps, 7);
  });

  test('is scoped to its own movement', () async {
    await train(
      exerciseId: squat,
      weightKg: 80,
      reps: 10,
    );
    await train(
      exerciseId: bench,
      weightKg: 50,
      reps: 8,
    );

    // Two movements trained on the same day must not bleed into each other.
    expect((await last(squat))!.weightKg, 80);
    expect((await last(bench))!.weightKg, 50);
    expect((await last(squat))!.reps, 10);
  });

  test('a set with no recorded load still tells you the reps', () async {
    await train(
      exerciseId: squat,
      weightKg: null,
      reps: 8,
    );

    final found = (await last(squat))!;
    expect(found.weightKg, isNull);
    expect(found.reps, 8);
    expect(found.hasLoad, isFalse);
  });

  test('when did it happen', () async {
    final when = await train(
      exerciseId: squat,
      weightKg: 80,
      reps: 10,
    );

    // The stored clock, not the parameter — `train` does not write `at`, it
    // returns what the row says, so this asserts the read path.
    expect((await last(squat))!.at, when);
  });

  group('on screen', () {
    Future<void> pumpWorkout(WidgetTester tester) async {
      final planRow = (await db.getPlansForStudent(student)).single;
      final sessionId = await db.startWorkoutSession(
        planId: plan,
        studentId: student,
        weekNumber: 1,
        dayNumber: 1,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: testApp(
            home: ActiveWorkoutScreen(
              sessionId: sessionId,
              plan: planRow,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows what was lifted last time, in Persian digits', (
      tester,
    ) async {
      await train(
        exerciseId: squat,
        weightKg: 82.5,
        reps: 7,
      );

      await pumpWorkout(tester);

      expect(find.textContaining('آخرین بار'), findsOneWidget);
      expect(find.textContaining('۸۲.۵'), findsOneWidget);
      expect(find.textContaining('۷'), findsWidgets);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets('says nothing when there is no history yet', (tester) async {
      await pumpWorkout(tester);

      // A quiet absence, not "0 kg" — there is no last time to show.
      expect(find.textContaining('آخرین بار'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  });
}
