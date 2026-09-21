import 'package:fit_coach/app/fit_coach_app.dart';
import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:fit_coach/core/database/test_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Student side of the journey: a student signs in, says which record is
/// theirs, and sees exactly the plan their coach built.
void main() {
  Future<AppDatabase> pumpApp(WidgetTester tester) async {
    final db = createTestDatabase();
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const FitCoachApp(),
      ),
    );
    await tester.pump();
    await tester.pump();
    return db;
  }

  Future<void> signIn(WidgetTester tester, String role) async {
    await tester.tap(find.widgetWithText(FilledButton, role));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('a student picks their record and sees their plan',
      (tester) async {
    final db = await pumpApp(tester);

    final ali = await db.insertUser(
      UsersCompanion.insert(name: 'علی', role: UserRole.student),
    );
    final reza = await db.insertUser(
      UsersCompanion.insert(name: 'رضا', role: UserRole.student),
    );
    final aliPlan = await db.insertWorkoutPlan(
      WorkoutPlansCompanion.insert(studentId: ali, title: 'برنامه حجم'),
    );
    await db.insertExercise(ExercisesCompanion.insert(
      planId: aliPlan,
      name: 'اسکوات',
      sets: 4,
      reps: 10,
    ));
    await db.insertWorkoutPlan(
      WorkoutPlansCompanion.insert(studentId: reza, title: 'برنامه رضا'),
    );

    await signIn(tester, 'شاگرد');

    // No record chosen yet -> the student says which one is theirs.
    expect(find.text('علی'), findsOneWidget);
    expect(find.text('رضا'), findsOneWidget);
    await tester.tap(find.text('علی'));
    await tester.pump();
    await tester.pump();

    // Only Ali's plan is visible, not Reza's.
    expect(find.text('برنامه حجم'), findsOneWidget);
    expect(find.text('برنامه رضا'), findsNothing);
    expect(await db.getActiveStudentId(), ali);
    expect(await db.getActiveRole(), UserRole.student);

    // Tapping the plan shows its movements.
    await tester.tap(find.text('برنامه حجم'));
    await tester.pumpAndSettle();
    expect(find.text('اسکوات'), findsOneWidget);
    expect(find.text('4 × 10'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('the chosen student survives a restart', (tester) async {
    final db = await pumpApp(tester);
    final ali = await db.insertUser(
      UsersCompanion.insert(name: 'علی', role: UserRole.student),
    );
    await db.insertWorkoutPlan(
      WorkoutPlansCompanion.insert(studentId: ali, title: 'برنامه حجم'),
    );
    await signIn(tester, 'شاگرد');
    await tester.tap(find.text('علی'));
    await tester.pump();
    await tester.pump();
    expect(find.text('برنامه حجم'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();

    // Same database, fresh widget tree: the session is read back from disk.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const FitCoachApp(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('برنامه‌های من'), findsOneWidget);
    expect(find.text('برنامه حجم'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
