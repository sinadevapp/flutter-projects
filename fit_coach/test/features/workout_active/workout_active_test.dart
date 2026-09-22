import 'package:drift/drift.dart' show Value;
import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:fit_coach/core/database/test_database.dart';
import 'package:fit_coach/features/student_hub/presentation/student_plan_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_app.dart';

void main() {
  late AppDatabase db;
  late WorkoutPlan plan;

  setUp(() async {
    db = createTestDatabase();
    final studentId = await db.insertUser(
      UsersCompanion.insert(name: 'علی', role: UserRole.student),
    );
    final planId = await db.insertWorkoutPlan(
      WorkoutPlansCompanion.insert(studentId: studentId, title: 'برنامه حجم'),
    );
    await db.insertExercise(ExercisesCompanion.insert(
      planId: planId,
      name: 'اسکوات',
      sets: 2,
      reps: 10,
    ));
    await db.insertExercise(ExercisesCompanion.insert(
      planId: planId,
      name: 'پرس سینه',
      sets: 3,
      reps: 8,
      position: Value(1),
    ));
    plan = (await db.getPlansForStudent(studentId)).single;
  });

  tearDown(() => db.close());

  Future<void> pumpPlan(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: testApp(home: PlanDetailScreen(plan: plan)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  testWidgets('starting a workout shows the first movement and set',
      (tester) async {
    await pumpPlan(tester);

    expect(find.text('شروع تمرین'), findsOneWidget);
    await tester.tap(find.text('شروع تمرین'));
    await tester.pumpAndSettle();

    expect(find.text('اسکوات'), findsOneWidget);
    expect(find.text('ست ۱ از ۲'), findsOneWidget);
    expect(find.text('۰ از ۵ ست'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('finishing a set advances the set, then the movement',
      (tester) async {
    await pumpPlan(tester);
    await tester.tap(find.text('شروع تمرین'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ست تمام'));
    await tester.pumpAndSettle();
    expect(find.text('ست ۲ از ۲'), findsOneWidget);

    await tester.tap(find.text('ست تمام'));
    await tester.pumpAndSettle();
    expect(find.text('پرس سینه'), findsOneWidget);
    expect(find.text('ست ۱ از ۳'), findsOneWidget);
    expect(find.text('۲ از ۵ ست'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('after the last set the workout can be finished and is closed',
      (tester) async {
    await pumpPlan(tester);
    await tester.tap(find.text('شروع تمرین'));
    await tester.pumpAndSettle();

    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('ست تمام'));
      await tester.pumpAndSettle();
    }

    expect(find.text('پایان تمرین'), findsOneWidget);
    await tester.tap(find.text('پایان تمرین'));
    await tester.pumpAndSettle();

    // Back on the plan, and the workout is closed with all sets recorded.
    expect(find.text('شروع تمرین'), findsOneWidget);
    final active = await db.getActiveWorkoutSession(plan.studentId);
    expect(active, isNull);
    final finished = await db.getSetLogs(1);
    expect(finished.length, 5);

    await unmount(tester);
  });

  testWidgets('an interrupted workout is resumed from where it stopped',
      (tester) async {
    await pumpPlan(tester);
    await tester.tap(find.text('شروع تمرین'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ست تمام'));
    await tester.pumpAndSettle();
    expect(find.text('ست ۲ از ۲'), findsOneWidget);

    // The app is closed mid-workout and opened again.
    await unmount(tester);
    await pumpPlan(tester);

    expect(find.text('ادامه تمرین'), findsOneWidget);
    await tester.tap(find.text('ادامه تمرین'));
    await tester.pumpAndSettle();

    expect(find.text('اسکوات'), findsOneWidget);
    expect(find.text('ست ۲ از ۲'), findsOneWidget);
    expect(find.text('۱ از ۵ ست'), findsOneWidget);

    await unmount(tester);
  });
}
