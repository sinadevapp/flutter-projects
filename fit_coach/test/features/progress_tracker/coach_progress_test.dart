import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:fit_coach/core/database/test_database.dart';
import 'package:fit_coach/features/progress_tracker/presentation/progress_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_app.dart';

/// The coach's view of a student's history.
///
/// Same screen and same providers as the student's own view — only the framing
/// differs, because "my progress" is wrong when a coach is reading it.
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

  /// Logs one finished workout for [studentId].
  Future<void> train(int studentId, {required int sets, int reps = 10}) async {
    final planId = await db.insertWorkoutPlan(
      WorkoutPlansCompanion.insert(studentId: studentId, title: 'برنامه'),
    );
    final exerciseId = await db.insertExercise(
      ExercisesCompanion.insert(
        planId: planId,
        name: 'اسکوات',
        sets: sets,
        reps: reps,
      ),
    );
    final sessionId = await db.startWorkoutSession(
      planId: planId,
      studentId: studentId,
      weekNumber: 1,
      dayNumber: 1,
    );
    for (var i = 1; i <= sets; i++) {
      await db.logSet(
        sessionId: sessionId,
        exerciseId: exerciseId,
        setNumber: i,
      );
    }
    await db.finishWorkoutSession(sessionId);
  }

  Future<void> pumpCoachView(
    WidgetTester tester, {
    required int studentId,
    required String studentName,
    Locale locale = testLocale,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: testApp(
          home: ProgressScreen.forCoach(
            studentId: studentId,
            studentName: studentName,
          ),
          locale: locale,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  testWidgets('the coach view is framed around the student, not the reader', (
    tester,
  ) async {
    await train(ali, sets: 3);
    await pumpCoachView(tester, studentId: ali, studentName: 'علی');

    // "My progress" would be wrong — this is the coach reading Ali's history.
    expect(find.text('پیشرفت علی'), findsOneWidget);
    expect(find.text('پیشرفت من'), findsNothing);

    await unmount(tester);
  });

  testWidgets('the coach sees the same figures the student does', (
    tester,
  ) async {
    await train(ali, sets: 3);

    await pumpCoachView(tester, studentId: ali, studentName: 'علی');
    expect(find.text('۳'), findsWidgets); // three sets, Persian digit
    expect(find.text('اسکوات'), findsOneWidget);

    // And the student's own view of the same data agrees.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: testApp(home: ProgressScreen(studentId: ali)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('پیشرفت من'), findsOneWidget);
    expect(find.text('اسکوات'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets("one student's history never leaks into another's", (
    tester,
  ) async {
    await train(ali, sets: 3);
    await train(reza, sets: 1);

    await pumpCoachView(tester, studentId: reza, studentName: 'رضا');

    // Reza did one set; Ali's three must not appear.
    expect(find.text('۱'), findsWidgets);
    expect(find.text('۳'), findsNothing);

    await unmount(tester);
  });

  testWidgets('a student who has not trained shows an empty state', (
    tester,
  ) async {
    await pumpCoachView(tester, studentId: ali, studentName: 'علی');

    expect(find.text('هنوز تمرینی ثبت نشده'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('an unfinished workout does not count as completed', (
    tester,
  ) async {
    final planId = await db.insertWorkoutPlan(
      WorkoutPlansCompanion.insert(studentId: ali, title: 'برنامه'),
    );
    final exerciseId = await db.insertExercise(
      ExercisesCompanion.insert(
        planId: planId,
        name: 'اسکوات',
        sets: 3,
        reps: 10,
      ),
    );
    final sessionId = await db.startWorkoutSession(
      planId: planId,
      studentId: ali,
      weekNumber: 1,
      dayNumber: 1,
    );
    await db.logSet(sessionId: sessionId, exerciseId: exerciseId, setNumber: 1);
    // Deliberately not finished — the student is still mid-workout.

    await pumpCoachView(tester, studentId: ali, studentName: 'علی');

    // The set shows, but it is not a completed workout yet.
    expect(find.text('۰'), findsWidgets);

    await unmount(tester);
  });

  testWidgets('the coach view works in English too', (tester) async {
    await train(ali, sets: 3);
    await pumpCoachView(
      tester,
      studentId: ali,
      studentName: 'علی',
      locale: const Locale('en'),
    );

    expect(find.text('Progress for علی'), findsOneWidget);
    expect(find.text('3'), findsWidgets);
    expect(find.text('۳'), findsNothing);

    await unmount(tester);
  });
}
