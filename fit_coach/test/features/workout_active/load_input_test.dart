import 'package:drift/drift.dart' show Value;
import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:fit_coach/core/database/test_database.dart';
import 'package:fit_coach/features/workout_active/presentation/active_workout_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_app.dart';

/// Recording what the student actually lifted.
///
/// The plan says 4×10 at 80 kg; the attempt is whatever they manage. Until
/// these fields existed the app logged only that a set happened, so there was
/// nothing to show a personal record from and no load to plot.
void main() {
  late AppDatabase db;
  late int student;
  late int plan;
  late int sessionId;
  late int squatId;

  setUp(() async {
    db = createTestDatabase();
    student = await db.insertUser(
      UsersCompanion.insert(name: 'علی', role: UserRole.student),
    );
    plan = await db.insertWorkoutPlan(
      WorkoutPlansCompanion.insert(studentId: student, title: 'برنامه'),
    );
    squatId = await db.insertExercise(
      ExercisesCompanion.insert(
        planId: plan,
        name: 'اسکوات',
        sets: 3,
        reps: 10,
        targetWeightKg: const Value(80),
        // Second in the day, so a test can add a bodyweight movement before
        // it and exercise the blank-weight case without reseeding.
        position: const Value(1),
      ),
    );
    sessionId = await db.startWorkoutSession(
      planId: plan,
      studentId: student,
      weekNumber: 1,
      dayNumber: 1,
    );
  });
  tearDown(() => db.close());

  /// The plan as the screen receives it — read fresh, like the widget does.
  Future<WorkoutPlan> planRow() async =>
      (await db.getPlansForStudent(student)).single;

  Future<void> pumpWorkout(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: testApp(
          home: ActiveWorkoutScreen(
            sessionId: sessionId,
            plan: await planRow(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }


  testWidgets('the fields start from what the coach prescribed', (
    tester,
  ) async {
    await pumpWorkout(tester);

    final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields, hasLength(2));
    // Prefilled so a set that goes to plan needs no typing at all.
    expect(fields[0].controller?.text, '80');
    expect(fields[1].controller?.text, '10');

    await unmount(tester);
  });

  testWidgets('what was entered is what gets recorded', (tester) async {
    await pumpWorkout(tester);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '82.5');
    await tester.enterText(fields.at(1), '7');
    await tester.tap(find.text('ست تمام'));
    await tester.pumpAndSettle();

    final recorded = (await db.getSetLogs(sessionId)).single;
    expect(recorded.weightKg, 82.5);
    expect(recorded.repsPerformed, 7);
    expect(recorded.exerciseId, squatId);
    expect(recorded.setNumber, 1);

    await unmount(tester);
  });

  testWidgets('an untouched field keeps the prescription', (tester) async {
    await pumpWorkout(tester);

    await tester.tap(find.text('ست تمام'));
    await tester.pumpAndSettle();

    // Nothing typed, so the prescribed numbers are what happened — which is
    // what "prefilled" has to mean.
    final recorded = (await db.getSetLogs(sessionId)).single;
    expect(recorded.weightKg, 80);
    expect(recorded.repsPerformed, 10);

    await unmount(tester);
  });

  testWidgets('a bodyweight movement leaves the weight blank', (tester) async {
    // Default position 0 puts it before the squat, so this is the movement
    // on screen — the one with no prescribed load.
    await db.insertExercise(
      ExercisesCompanion.insert(planId: plan, name: 'بارفیکس', sets: 3, reps: 8),
    );
    await pumpWorkout(tester);

    final fields = find.byType(TextField);
    expect(tester.widget<TextField>(fields.first).controller?.text, '');
    expect(tester.widget<TextField>(fields.last).controller?.text, '8');

    await tester.tap(find.text('ست تمام'));
    await tester.pumpAndSettle();

    final recorded = (await db.getSetLogs(sessionId)).single;
    expect(recorded.weightKg, isNull, reason: 'no load was entered');
    expect(recorded.repsPerformed, 8);

    await unmount(tester);
  });

  testWidgets('garbage in a field does not break the set', (tester) async {
    await pumpWorkout(tester);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '---');
    await tester.enterText(fields.at(1), 'abc');
    await tester.tap(find.text('ست تمام'));
    await tester.pumpAndSettle();

    // The set still counts — it did happen — but no numbers were recorded
    // rather than the text being stored as though it were one.
    final recorded = (await db.getSetLogs(sessionId)).single;
    expect(recorded.setNumber, 1);
    expect(recorded.weightKg, isNull);
    expect(recorded.repsPerformed, isNull);

    await unmount(tester);
  });
}
