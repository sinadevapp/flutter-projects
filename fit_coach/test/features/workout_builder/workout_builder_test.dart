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

  testWidgets('tapping a student opens their plan list with an empty state',
      (tester) async {
    await pumpCoachHub(tester);

    await tester.tap(find.text('علی'));
    await tester.pumpAndSettle();

    expect(find.text('هنوز برنامه‌ای ساخته نشده'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('saving a plan with one exercise stores both and lists the plan',
      (tester) async {
    final db = await pumpCoachHub(tester);

    await tester.tap(find.text('علی'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('برنامه جدید'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'برنامه حجم');
    await tester.enterText(find.byType(TextField).at(1), 'اسکوات');
    await tester.enterText(find.byType(TextField).at(2), '4');
    await tester.enterText(find.byType(TextField).at(3), '10');

    await tester.tap(find.widgetWithText(FilledButton, 'ذخیره'));
    await tester.pumpAndSettle();

    // Back on the student's plan list, with the new plan visible.
    expect(find.text('برنامه حجم'), findsOneWidget);

    final plans = await db.getPlansForStudent(1);
    expect(plans.length, 1);
    final exercises = await db.getExercisesForPlan(plans.first.id);
    expect(exercises.length, 1);
    expect(exercises.first.name, 'اسکوات');
    expect(exercises.first.sets, 4);
    expect(exercises.first.reps, 10);

    await unmount(tester);
  });

  testWidgets('a plan without a title is rejected and stores nothing',
      (tester) async {
    final db = await pumpCoachHub(tester);

    await tester.tap(find.text('علی'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('برنامه جدید'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'ذخیره'));
    await tester.pumpAndSettle();

    expect(find.text('عنوان برنامه را وارد کنید'), findsOneWidget);
    expect(await db.getPlansForStudent(1), isEmpty);

    await unmount(tester);
  });
}
