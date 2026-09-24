import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:fit_coach/core/database/test_database.dart';
import 'package:fit_coach/core/database/workout_providers.dart';
import 'package:fit_coach/features/workout_active/domain/workout_progress.dart';
import 'package:fit_coach/features/workout_active/domain/workout_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_app.dart';

/// The active-workout screen is handed only a session id, but the summary
/// needs that session's real `startedAt` to time the workout honestly.
/// Deriving it from the first logged set would be wrong: the student may have
/// started the workout and logged the first set minutes later.
void main() {
  late AppDatabase db;
  late int sessionId;

  setUp(() async {
    db = createTestDatabase();
    final studentId = await db.insertUser(
      UsersCompanion.insert(name: 'علی', role: UserRole.student),
    );
    final planId = await db.insertWorkoutPlan(
      WorkoutPlansCompanion.insert(studentId: studentId, title: 'برنامه'),
    );
    await db.insertExercise(
      ExercisesCompanion.insert(
        planId: planId,
        name: 'اسکوات',
        sets: 2,
        reps: 10,
      ),
    );
    sessionId = await db.startWorkoutSession(
      planId: planId,
      studentId: studentId,
      weekNumber: 1,
      dayNumber: 1,
    );
  });
  tearDown(() => db.close());

  /// Renders the session the provider resolves, so a drift stream settles
  /// inside the widget tree's fake-async zone.
  Future<String?> pumpSessionLine(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    var text = '';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: testApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                final session = ref.watch(workoutSessionProvider(sessionId));
                return session.when(
                  loading: () => const Text('...'),
                  error: (e, _) => Text('ERR $e'),
                  data: (row) {
                    text = row == null ? 'none' : '${row.id}';
                    return Text(text);
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return text;
  }

  testWidgets('the session can be read back by id', (tester) async {
    final text = await pumpSessionLine(tester);
    expect(text, '$sessionId');

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('an unknown id resolves to null rather than throwing', (
    tester,
  ) async {
    sessionId = 9999;
    final text = await pumpSessionLine(tester);
    expect(text, 'none');

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  test('the real start time drives the summary, not the first set', () async {
    // A student who opens the workout and logs the first set a while later.
    final session = (await db.getActiveWorkoutSession(1))!;
    await db.logSet(sessionId: sessionId, exerciseId: 1, setNumber: 1);

    final logs = await db.getSetLogs(sessionId);
    final exercises = await db.select(db.exercises).get();

    final summary = WorkoutSummary.from(
      session: session,
      logs: logs,
      exercises: exercises,
    );

    // The duration starts at the session, so it can never be zero just
    // because the first set was logged immediately.
    expect(
      summary.duration,
      logs.single.completedAt.difference(session.startedAt),
    );
    expect(
      session.startedAt.isAfter(logs.single.completedAt),
      isFalse,
      reason: 'the session must start before its first logged set',
    );

    // And the plan is not yet complete, so the summary would say so.
    final progress = WorkoutProgress(exercises: exercises, logs: logs);
    expect(progress.isComplete, isFalse);
  });
}
