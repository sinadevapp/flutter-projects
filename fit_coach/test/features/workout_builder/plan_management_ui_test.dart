import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:fit_coach/core/database/test_database.dart';
import 'package:fit_coach/features/coach_hub/presentation/coach_hub_screen.dart';
import 'package:fit_coach/features/workout_builder/presentation/plan_detail_edit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_app.dart';

/// Editing plans from the coach's side: rename, correct a movement, remove a
/// movement, delete a plan, copy one to another student.
void main() {
  late AppDatabase db;
  late int ali;

  setUp(() async {
    db = createTestDatabase();
    ali = await db.insertUser(
      UsersCompanion.insert(name: 'علی', role: UserRole.student),
    );
  });
  tearDown(() => db.close());

  Future<int> makePlan({String title = 'برنامه حجم'}) async {
    final planId = await db.insertWorkoutPlan(
      WorkoutPlansCompanion.insert(studentId: ali, title: title),
    );
    await db.insertExercise(ExercisesCompanion.insert(
      planId: planId,
      name: 'اسکوات',
      sets: 4,
      reps: 10,
    ));
    return planId;
  }

  Future<WorkoutPlan> planById(int id) async =>
      (await db.getPlansForStudent(ali)).firstWhere((p) => p.id == id);

  Future<void> pumpCoachHub(WidgetTester tester) async {
    await db.setLocaleCode('fa');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: testApp(home: const CoachHubScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  testWidgets('a movement can be edited from the plan screen', (tester) async {
    final planId = await makePlan();
    await pumpCoachHub(tester);

    await tester.tap(find.text('علی'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('برنامه حجم'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('اسکوات'));
    await tester.pumpAndSettle();

    // Correct the sets from 4 to 5 and save.
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(1), '5');
    await tester.tap(find.widgetWithText(FilledButton, 'ذخیره'));
    await tester.pumpAndSettle();

    expect((await db.getExercisesForPlan(planId)).single.sets, 5);

    await unmount(tester);
  });

  testWidgets('an edit with nonsense values is rejected', (tester) async {
    final planId = await makePlan();
    await pumpCoachHub(tester);

    await tester.tap(find.text('علی'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('برنامه حجم'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('اسکوات'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(1), 'سی');
    await tester.tap(find.widgetWithText(FilledButton, 'ذخیره'));
    await tester.pumpAndSettle();

    // Nothing stored: the dialog stays open rather than writing a bad value.
    expect((await db.getExercisesForPlan(planId)).single.sets, 4);
    expect(find.byType(AlertDialog), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('long-pressing a movement asks before removing it',
      (tester) async {
    final planId = await makePlan();
    await pumpCoachHub(tester);

    await tester.tap(find.text('علی'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('برنامه حجم'));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('اسکوات'));
    await tester.pumpAndSettle();

    // Cancelling must not delete anything.
    await tester.tap(find.text('انصراف'));
    await tester.pumpAndSettle();
    expect(await db.getExercisesForPlan(planId), hasLength(1));

    await tester.longPress(find.text('اسکوات'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'حذف'));
    await tester.pumpAndSettle();

    expect(await db.getExercisesForPlan(planId), isEmpty);

    await unmount(tester);
  });

  testWidgets('deleting a plan asks first and then removes it', (tester) async {
    await makePlan();
    await pumpCoachHub(tester);

    await tester.tap(find.text('علی'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('برنامه حجم'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('حذف برنامه'));
    await tester.pumpAndSettle();

    // The confirmation names the plan, because this also deletes its history.
    expect(find.textContaining('برنامه حجم'), findsWidgets);
    await tester.tap(find.text('انصراف'));
    await tester.pumpAndSettle();
    expect(await db.getPlansForStudent(ali), hasLength(1));

    await tester.tap(find.byTooltip('حذف برنامه'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'حذف'));
    await tester.pumpAndSettle();

    expect(await db.getPlansForStudent(ali), isEmpty);
    // And the coach is returned to the list rather than a dead screen.
    expect(find.text('هنوز برنامه‌ای ساخته نشده'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('renaming a plan keeps its movements', (tester) async {
    final planId = await makePlan();
    await pumpCoachHub(tester);

    await tester.tap(find.text('علی'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('برنامه حجم'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('تغییر نام برنامه'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'برنامه قدرتی');
    await tester.tap(find.widgetWithText(FilledButton, 'ذخیره'));
    await tester.pumpAndSettle();

    expect((await planById(planId)).title, 'برنامه قدرتی');
    expect(await db.getExercisesForPlan(planId), hasLength(1));

    await unmount(tester);
  });

  testWidgets('a plan can be copied to another student', (tester) async {
    final planId = await makePlan();
    await db.insertUser(
      UsersCompanion.insert(name: 'رضا', role: UserRole.student),
    );
    await pumpCoachHub(tester);

    await tester.tap(find.text('علی'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('کپی برای شاگرد دیگر'));
    await tester.pumpAndSettle();

    // The coach picks who receives the copy.
    await tester.tap(find.text('رضا'));
    await tester.pumpAndSettle();

    final reza = (await db.getAllUsers()).firstWhere((u) => u.name == 'رضا');
    final rezaPlans = await db.getPlansForStudent(reza.id);
    expect(rezaPlans, hasLength(1));
    expect(rezaPlans.single.title, 'برنامه حجم');
    // Movements came along, and the original is untouched.
    expect(await db.getExercisesForPlan(rezaPlans.single.id), hasLength(1));
    expect(await db.getExercisesForPlan(planId), hasLength(1));

    await unmount(tester);
  });

  testWidgets('copying with no other students says so', (tester) async {
    await makePlan();
    await pumpCoachHub(tester);

    await tester.tap(find.text('علی'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('کپی برای شاگرد دیگر'));
    await tester.pumpAndSettle();

    expect(find.text('شاگرد دیگری وجود ندارد'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('the edit screen works in English too', (tester) async {
    final planId = await makePlan();
    final plan = (await db.getPlansForStudent(ali))
        .firstWhere((p) => p.id == planId);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: testApp(
          home: PlanDetailEditScreen(plan: plan),
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('برنامه حجم'), findsOneWidget);
    expect(find.byTooltip('Rename plan'), findsOneWidget);
    expect(find.byTooltip('Delete plan'), findsOneWidget);

    await unmount(tester);
  });
}
