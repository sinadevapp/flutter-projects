import 'package:drift/drift.dart' show Value;
import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:fit_coach/core/database/test_database.dart';
import 'package:fit_coach/core/widgets/plan_title.dart';
import 'package:fit_coach/features/student_hub/presentation/student_plan_screen.dart';
import 'package:fit_coach/features/workout_builder/presentation/plan_detail_edit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_app.dart';

/// The program's length, shown where the program is read.
///
/// `durationWeeks` was stored and then ignored — recorded but never read, so
/// the coach and the student could not see how long the program was meant to
/// run, only week by week as they scrolled.
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

  Future<WorkoutPlan> plan({int? weeks}) async {
    final planId = await db.insertWorkoutPlan(
      WorkoutPlansCompanion.insert(
        studentId: student,
        title: 'برنامه اول',
        durationWeeks: Value(weeks),
      ),
    );
    await db.insertExercise(
      ExercisesCompanion.insert(
        planId: planId,
        name: 'اسکوات',
        sets: 3,
        reps: 10,
        weekNumber: const Value(1),
        dayNumber: const Value(1),
      ),
    );
    return (await db.getPlansForStudent(student)).single;
  }

  Future<void> pumpPlan(
    WidgetTester tester,
    WorkoutPlan subject, {
    Locale locale = const Locale('fa'),
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: testApp(
          home: PlanDetailEditScreen(plan: subject),
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

  testWidgets('the length is shown when the coach gave one', (tester) async {
    await pumpPlan(tester, await plan(weeks: 8));

    // Beside the title, not replacing it: the name is what identifies it and
    // the length is a modifier on it.
    expect(find.text('برنامه اول'), findsOneWidget);
    expect(find.text('۸ هفته'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('nothing is shown when the length was left blank', (
    tester,
  ) async {
    await pumpPlan(tester, await plan());

    // An undecided length has no row to render — inventing "0 weeks" or
    // "open ended" would be saying something the coach never said.
    //
    // Checked on the widget rather than by text: the body legitimately says
    // «هفته ۱» for every week heading, so a text search for «هفته» would
    // match those and prove nothing.
    final heading = tester.widget<PlanAppBarTitle>(
      find.byType(PlanAppBarTitle),
    );
    expect(heading.durationWeeks, isNull);
    expect(find.text('برنامه اول'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('it reads as weeks in English too', (tester) async {
    await pumpPlan(
      tester,
      await plan(weeks: 6),
      locale: const Locale('en'),
    );

    expect(find.text('6 weeks'), findsOneWidget);
    expect(find.text('۶'), findsNothing);

    await unmount(tester);
  });

  testWidgets('one week is not shown as weeks', (tester) async {
    await pumpPlan(tester, await plan(weeks: 1));

    // The plural form on a singular number is the kind of thing a tester
    // spots and a user never forgets.
    expect(find.text('۱ هفته'), findsOneWidget);
    expect(find.text('۱ هفته‌ها'), findsNothing);

    await unmount(tester);
  });

  testWidgets('the student sees the length on their own copy of the plan', (
    tester,
  ) async {
    final subject = await plan(weeks: 6);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: testApp(home: PlanDetailScreen(plan: subject)),
      ),
    );
    await tester.pumpAndSettle();

    // The student is the one living the program — they need the length more
    // than the coach reviewing it does.
    expect(find.text('برنامه اول'), findsOneWidget);
    expect(find.text('۶ هفته'), findsOneWidget);

    await unmount(tester);
  });
}
