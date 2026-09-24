import 'package:fit_coach/app/fit_coach_app.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:fit_coach/core/database/test_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The real coaching journey, end to end through the UI:
/// pick the coach role, add a student, build a plan for them, leave the coach
/// area and come back — everything the coach created must still be there.
void main() {
  testWidgets('student and plan survive leaving the coach area and returning', (
    tester,
  ) async {
    final db = createTestDatabase();
    addTearDown(db.close);
    // The primary language, so assertions read in Persian.
    await db.setLocaleCode('fa');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const FitCoachApp(),
      ),
    );
    await tester.pump();
    await tester.pump();

    // 1. Become the coach.
    await tester.tap(find.widgetWithText(FilledButton, 'مربی'));
    await tester.pump();
    await tester.pump();

    // 2. Add a student. The form returns to the list on its own — the coach
    // added the student in order to see them there, so having to navigate back
    // would be asking for something they already asked for.
    await tester.tap(find.byTooltip('افزودن شاگرد'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'علی');
    await tester.tap(find.widgetWithText(FilledButton, 'ذخیره'));
    await tester.pumpAndSettle();
    expect(
      find.byType(BackButton),
      findsNothing,
      reason: 'the add-student form closes itself after saving',
    );
    expect(find.text('علی'), findsOneWidget);

    // 3. Build a plan for that student.
    await tester.tap(find.text('علی'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('برنامه جدید'));
    await tester.pumpAndSettle();
    // Title, then the optional length, then the movement's name/sets/reps.
    await tester.enterText(find.byType(TextField).at(0), 'برنامه حجم');
    await tester.enterText(find.byType(TextField).at(1), '4');
    await tester.enterText(find.byType(TextField).at(2), 'اسکوات');
    await tester.enterText(find.byType(TextField).at(3), '4');
    await tester.enterText(find.byType(TextField).at(4), '10');
    // The form now carries weeks and days, so save is below the fold.
    final saveButton = find.widgetWithText(FilledButton, 'ذخیره');
    await tester.scrollUntilVisible(
      saveButton,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    expect(find.text('برنامه حجم'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // 4. Leave the coach area and come back.
    await tester.tap(find.byTooltip('تغییر نقش'));
    await tester.pumpAndSettle();
    expect(find.text('نقش خود را انتخاب کنید'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'مربی'));
    await tester.pump();
    await tester.pump();

    // 5. The coach's data is still there.
    expect(find.text('علی'), findsOneWidget);
    await tester.tap(find.text('علی'));
    await tester.pumpAndSettle();
    expect(find.text('برنامه حجم'), findsOneWidget);

    final students = await db.getAllUsers();
    expect(students.length, 1);
    final plans = await db.getPlansForStudent(students.single.id);
    expect(plans.single.title, 'برنامه حجم');

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
