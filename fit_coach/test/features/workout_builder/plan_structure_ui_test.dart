import 'package:drift/drift.dart' show Value;
import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:fit_coach/core/database/test_database.dart';
import 'package:fit_coach/features/coach_hub/presentation/coach_hub_screen.dart';
import 'package:fit_coach/features/student_hub/presentation/student_plan_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_app.dart';

/// Authoring and reading a program that spans weeks and days.
///
/// The domain rules live in `exercise_schedule_test.dart` and
/// `plan_structure_test.dart`; these cover only what the screens do with them.
void main() {
  late AppDatabase db;
  late int student;

  setUp(() async {
    db = createTestDatabase();
    student = await db.insertUser(
      UsersCompanion.insert(name: 'علی', role: UserRole.student),
    );
  });
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: testApp(home: child),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  /// Brings [finder] into view — and therefore into the tree.
  ///
  /// `ListView` builds its children lazily, so a control below the fold does
  /// not exist yet and no finder can see it. This is the same scroll the
  /// coach performs.
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  /// Opens the authoring form as the coach would.
  Future<void> openAddPlan(WidgetTester tester) async {
    await pump(tester, const CoachHubScreen());
    await tester.tap(find.text('علی'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('برنامه جدید'));
    await tester.pumpAndSettle();
  }

  /// Fills the nth movement row (0-based) by position in the form.
  Future<void> fillMovement(
    WidgetTester tester,
    int index,
    String name, {
    String sets = '4',
    String reps = '10',
  }) async {
    final offset = 2 + index * 3;
    await tester.enterText(find.byType(TextField).at(offset), name);
    await tester.enterText(find.byType(TextField).at(offset + 1), sets);
    await tester.enterText(find.byType(TextField).at(offset + 2), reps);
  }

  Future<void> savePlan(WidgetTester tester) async {
    final button = find.widgetWithText(FilledButton, 'ذخیره');
    await scrollTo(tester, button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  group('authoring weeks', () {
    testWidgets('the form opens with one week and one day', (tester) async {
      await openAddPlan(tester);

      expect(find.text('هفته ۱'), findsOneWidget);
      expect(find.text('روز ۱'), findsOneWidget);
      // The next week is offered as a copy of this one, not as a blank.
      await scrollTo(tester, find.text('افزودن هفته ۲'));
      expect(find.text('افزودن هفته ۲'), findsOneWidget);

      await unmount(tester);
    });

    testWidgets('adding a week copies the movements written so far', (
      tester,
    ) async {
      await openAddPlan(tester);
      await tester.enterText(find.byType(TextField).at(0), 'برنامه اول');
      await fillMovement(tester, 0, 'اسکوات');

      await scrollTo(tester, find.text('افزودن هفته ۲'));
      await tester.tap(find.text('افزودن هفته ۲'));
      await tester.pumpAndSettle();
      // Week 2 is appended below the fold, so it has to be brought into view
      // before it exists — the copy is what proves the button worked.
      await scrollTo(tester, find.text('هفته ۲'));
      expect(find.text('هفته ۲'), findsOneWidget);
      // Scrolling to the end builds the whole form, so both copies exist.
      await scrollTo(tester, find.widgetWithText(FilledButton, 'ذخیره'));
      expect(find.text('اسکوات'), findsNWidgets(2));

      await savePlan(tester);

      final plans = await db.getPlansForStudent(student);
      final movements = await db.getExercisesForPlan(plans.single.id);
      expect(
        movements.map((m) => m.weekNumber).toList(),
        [1, 2],
        reason: 'the copy must land in week 2, not overwrite week 1',
      );
      expect(movements.map((m) => m.name).toSet(), {'اسکوات'});

      await unmount(tester);
    });

    testWidgets('adding a day opens a second slot without copying', (
      tester,
    ) async {
      await openAddPlan(tester);
      await tester.enterText(find.byType(TextField).at(0), 'برنامه اول');
      await fillMovement(tester, 0, 'اسکوات');

      await scrollTo(tester, find.text('افزودن روز'));
      await tester.tap(find.text('افزودن روز'));
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('روز ۲'));
      expect(find.text('روز ۲'), findsOneWidget);

      // Deliberately leave day 2 empty: unlike "add week", adding a day must
      // not duplicate movements, or the coach would delete what they just
      // copied. Splitting movements across days is covered by the database
      // and domain tests — ListView's lazy children make typing into a row
      // below the fold an unreliable way to check it here.
      await savePlan(tester);

      final plans = await db.getPlansForStudent(student);
      final movements = await db.getExercisesForPlan(plans.single.id);
      expect(
        movements.map((m) => '${m.weekNumber}/${m.dayNumber}').toList(),
        ['1/1'],
        reason: 'the untouched day 2 must contribute nothing',
      );

      await unmount(tester);
    });

    testWidgets('a movement keeps the category the coach picked', (
      tester,
    ) async {
      await openAddPlan(tester);
      await tester.enterText(find.byType(TextField).at(0), 'برنامه اول');
      await fillMovement(tester, 0, 'اسکوات');

      await scrollTo(tester, find.text('ترکیبی'));
      await tester.tap(find.text('ترکیبی'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('پا'));
      await tester.pumpAndSettle();

      await savePlan(tester);

      final plans = await db.getPlansForStudent(student);
      final movement = (await db.getExercisesForPlan(plans.single.id)).single;
      expect(movement.category, ExerciseCategory.legs);

      await unmount(tester);
    });

    testWidgets('the length field reaches the plan, and stays optional', (
      tester,
    ) async {
      await openAddPlan(tester);
      await tester.enterText(find.byType(TextField).at(0), 'برنامه اول');
      await fillMovement(tester, 0, 'اسکوات');
      await savePlan(tester);

      final plans = await db.getPlansForStudent(student);
      expect(plans.single.durationWeeks, isNull);

      await unmount(tester);

      await openAddPlan(tester);
      await tester.enterText(find.byType(TextField).at(0), 'برنامه دوم');
      await tester.enterText(find.byType(TextField).at(1), '8');
      await fillMovement(tester, 0, 'لانج');
      await savePlan(tester);

      final all = await db.getPlansForStudent(student);
      expect(all.firstWhere((p) => p.title == 'برنامه دوم').durationWeeks, 8);

      await unmount(tester);
    });
  });

  group('the student reads the same structure', () {
    /// A plan with two days in week 1 and one in week 2.
    Future<int> seedProgram() async {
      final planId = await db.insertWorkoutPlan(
        WorkoutPlansCompanion.insert(
          studentId: student,
          title: 'برنامه اول',
          durationWeeks: const Value(2),
        ),
      );
      Future<void> move(String name, int week, int day, int pos) =>
          db.insertExercise(
            ExercisesCompanion.insert(
              planId: planId,
              weekNumber: Value(week),
              dayNumber: Value(day),
              position: Value(pos),
              name: name,
              sets: 3,
              reps: 10,
            ),
          );
      await move('اسکوات', 1, 1, 0);
      await move('پرس سینه', 1, 2, 0);
      await move('لانج', 2, 1, 0);
      return planId;
    }

    testWidgets('weeks and days are labelled, and each day can be started', (
      tester,
    ) async {
      await seedProgram();
      final plan = (await db.getPlansForStudent(student)).single;

      await pump(tester, PlanDetailScreen(plan: plan));

      // The week is printed once; the days are the actionable units.
      expect(find.text('هفته ۱'), findsOneWidget);
      expect(find.text('هفته ۲'), findsOneWidget);
      expect(find.text('روز ۱'), findsWidgets);
      expect(find.text('روز ۲'), findsWidgets);
      expect(find.text('اسکوات'), findsOneWidget);
      expect(find.text('لانج'), findsOneWidget);

      // Two days in week 1 and one in week 2 — three chances to start.
      expect(find.text('شروع تمرین'), findsNWidgets(3));

      await unmount(tester);
    });

    testWidgets('starting a day opens only that day', (tester) async {
      await seedProgram();
      final plan = (await db.getPlansForStudent(student)).single;

      await pump(tester, PlanDetailScreen(plan: plan));

      // Week 2's movement, so a mix-up with day 1 would be visible.
      final week2 = find.ancestor(
        of: find.text('لانج'),
        matching: find.byType(Card),
      );
      await tester.tap(
        find.descendant(of: week2, matching: find.text('شروع تمرین')),
      );
      await tester.pumpAndSettle();

      final session = await db.getActiveWorkoutSession(student);
      expect(session, isNotNull);
      expect(session!.weekNumber, 2);
      expect(session.dayNumber, 1);
      // Only that day's movements are on screen — not day 1 of week 1.
      expect(find.text('لانج'), findsOneWidget);
      expect(find.text('اسکوات'), findsNothing);

      await unmount(tester);
    });

    testWidgets('the day already running offers to resume, others do not', (
      tester,
    ) async {
      await seedProgram();
      final plan = (await db.getPlansForStudent(student)).single;
      await db.startWorkoutSession(
        planId: plan.id,
        studentId: student,
        weekNumber: 1,
        dayNumber: 1,
      );

      await pump(tester, PlanDetailScreen(plan: plan));

      // One day can be running. The others say so instead of quietly resuming
      // the wrong day, which is what the old single button did.
      expect(find.text('ادامه تمرین'), findsOneWidget);
      expect(find.text('ابتدا تمرین قبلی را پایان ده'), findsNWidgets(2));
      expect(find.text('شروع تمرین'), findsNothing);

      await unmount(tester);
    });
  });
}
