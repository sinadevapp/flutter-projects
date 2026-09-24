import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:fit_coach/core/database/test_database.dart';
import 'package:fit_coach/features/coach_hub/presentation/coach_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_app.dart';

void main() {
  Future<AppDatabase> pumpCoachHub(WidgetTester tester) async {
    final db = createTestDatabase();
    addTearDown(db.close);
    await db.insertUser(
      UsersCompanion.insert(name: 'علی', role: UserRole.student),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: testApp(home: const CoachHubScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return db;
  }

  /// Unmounts inside fake-async so drift stream disposal timers fire.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  /// Presses save, scrolling to it first.
  ///
  /// The form carries weeks and days now, so save sits below the fold — the
  /// same scroll a coach has to perform. `ensureVisible` follows because
  /// `scrollUntilVisible` can leave the button flush against the viewport
  /// edge, where a tap dispatches outside the canvas and quietly misses;
  /// a missing tap looks exactly like a validation that never ran.
  Future<void> save(WidgetTester tester) async {
    final button = find.widgetWithText(FilledButton, 'ذخیره');
    await tester.scrollUntilVisible(
      button,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('tapping a student opens their plan list with an empty state', (
    tester,
  ) async {
    await pumpCoachHub(tester);

    await tester.tap(find.text('علی'));
    await tester.pumpAndSettle();

    expect(find.text('هنوز برنامه‌ای ساخته نشده'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets(
    'saving a plan with one exercise stores both and lists the plan',
    (tester) async {
      final db = await pumpCoachHub(tester);

      await tester.tap(find.text('علی'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('برنامه جدید'));
      await tester.pumpAndSettle();

      // Title, then the optional length, then the movement: name, sets, reps.
      await tester.enterText(find.byType(TextField).at(0), 'برنامه حجم');
      await tester.enterText(find.byType(TextField).at(1), '6');
      await tester.enterText(find.byType(TextField).at(2), 'اسکوات');
      await tester.enterText(find.byType(TextField).at(3), '4');
      await tester.enterText(find.byType(TextField).at(4), '10');

      await save(tester);

      // Back on the student's plan list, with the new plan visible.
      expect(find.text('برنامه حجم'), findsOneWidget);

      final plans = await db.getPlansForStudent(1);
      expect(plans.length, 1);
      // The optional length the coach typed reaches the row.
      expect(plans.first.durationWeeks, 6);

      final exercises = await db.getExercisesForPlan(plans.first.id);
      expect(exercises.length, 1);
      expect(exercises.first.name, 'اسکوات');
      expect(exercises.first.sets, 4);
      expect(exercises.first.reps, 10);
      // Nothing was said about the slot, so it is the program's first day.
      expect(exercises.first.weekNumber, 1);
      expect(exercises.first.dayNumber, 1);
      expect(exercises.first.category, ExerciseCategory.compound);

      await unmount(tester);
    },
  );

  testWidgets('a plan without a title is rejected and stores nothing', (
    tester,
  ) async {
    final db = await pumpCoachHub(tester);

    await tester.tap(find.text('علی'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('برنامه جدید'));
    await tester.pumpAndSettle();

    await save(tester);

    final plans = await db.getPlansForStudent(1);
    expect(find.text('عنوان برنامه را وارد کنید'), findsOneWidget);
    expect(plans, isEmpty);

    await unmount(tester);
  });

  testWidgets('the coach reaches a student\'s nutrition from their page', (
    tester,
  ) async {
    await pumpCoachHub(tester);

    await tester.tap(find.text('علی'));
    await tester.pumpAndSettle();

    // The entry point lives on the student's own page, beside their plans: a
    // coach working with one student should not have to leave it to set their
    // nutrition up.
    await tester.tap(find.byTooltip('تغذیه'));
    await tester.pumpAndSettle();

    expect(find.text('تغذیه علی'), findsOneWidget);
    expect(find.text('هنوز پروفایل تغذیه ثبت نشده'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets(
    'the coach reaches a student\'s training history from their page',
    (tester) async {
      final db = await pumpCoachHub(tester);

      await tester.tap(find.text('علی'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('پیشرفت'));
      await tester.pumpAndSettle();

      // Framed around the student: "my progress" would be wrong for the coach.
      expect(find.text('پیشرفت علی'), findsWidgets);
      expect(find.text('پیشرفت من'), findsNothing);
      expect(find.text('هنوز تمرینی ثبت نشده'), findsOneWidget);

      await unmount(tester);
      expect(db, isNotNull);
    },
  );
}
