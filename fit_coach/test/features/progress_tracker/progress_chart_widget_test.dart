import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:fit_coach/core/database/test_database.dart';
import 'package:fit_coach/features/progress_tracker/domain/workout_stats.dart';
import 'package:fit_coach/features/progress_tracker/presentation/progress_charts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_app.dart';

/// The charts only draw what the domain hands them, so these tests are about
/// rendering and locale — the arithmetic is covered in chart_data_test.dart.
void main() {
  ChartPoint week(int day, int sets) =>
      ChartPoint.forWeek(weekStart: DateTime(2026, 9, day), value: sets);

  ChartPoint movement(String label, int reps) =>
      ChartPoint.forLabel(label: label, value: reps);

  testWidgets('the weekly chart draws a line chart', (tester) async {
    await tester.pumpWidget(
      testApp(
        home: Scaffold(
          body: WeeklyVolumeChart(
            points: [week(5, 3), week(12, 5), week(19, 2)],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LineChart), findsOneWidget);

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    final spots = chart.data.lineBarsData.single.spots;

    // Oldest first, so a trend reads left to right.
    expect(spots.map((s) => s.y).toList(), [3.0, 5.0, 2.0]);
  });

  testWidgets('the movement chart draws a bar chart, busiest first', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        home: Scaffold(
          body: MovementVolumeChart(
            points: [movement('اسکوات', 20), movement('پرس سینه', 8)],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BarChart), findsOneWidget);

    final chart = tester.widget<BarChart>(find.byType(BarChart));
    final bars = chart.data.barGroups.map((g) => g.barRods.single.toY);

    expect(bars.toList(), [20.0, 8.0]);
  });

  testWidgets('axis numbers are Persian in Persian', (tester) async {
    await tester.pumpWidget(
      testApp(
        home: Scaffold(
          body: MovementVolumeChart(points: [movement('اسکوات', 20)]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 20 prints as ۲۰ on the axis, like every other number in the app.
    expect(find.text('۲۰'), findsWidgets);
    expect(find.text('20'), findsNothing);
  });

  testWidgets('axis numbers are plain in English', (tester) async {
    await tester.pumpWidget(
      testApp(
        home: Scaffold(
          body: MovementVolumeChart(points: [movement('Squat', 20)]),
        ),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('20'), findsWidgets);
    expect(find.text('۲۰'), findsNothing);
  });

  testWidgets('a single point still draws and still labels its axis', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        home: Scaffold(body: WeeklyVolumeChart(points: [week(19, 3)])),
      ),
    );
    await tester.pumpAndSettle();

    // One week of history must not produce an axis-less or crashing chart.
    expect(find.byType(LineChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty series draws nothing rather than an empty frame', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        home: const Scaffold(body: WeeklyVolumeChart(points: [])),
      ),
    );
    await tester.pumpAndSettle();

    // The screen already shows "no history yet"; a bare axis frame would be
    // noise under it.
    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets('the screen renders both charts with real data', (tester) async {
    final db = createTestDatabase();
    addTearDown(db.close);

    final studentId = await db.insertUser(
      UsersCompanion.insert(name: 'علی', role: UserRole.student),
    );
    final planId = await db.insertWorkoutPlan(
      WorkoutPlansCompanion.insert(studentId: studentId, title: 'برنامه'),
    );
    final squatId = await db.insertExercise(
      ExercisesCompanion.insert(
        planId: planId,
        name: 'اسکوات',
        sets: 2,
        reps: 10,
      ),
    );
    final sessionId = await db.startWorkoutSession(
      planId: planId,
      studentId: studentId,
      weekNumber: 1,
      dayNumber: 1,
    );
    for (var i = 1; i <= 2; i++) {
      await db.logSet(sessionId: sessionId, exerciseId: squatId, setNumber: i);
    }
    await db.finishWorkoutSession(sessionId);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: testApp(
          home: Scaffold(
            body: Builder(builder: (context) => const SizedBox.shrink()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The domain feeding the charts reflects the logged workout: two squat
    // sets x 10 reps = 20 reps of volume.
    final stats = WorkoutStats(
      sessions: await db.select(db.workoutSessions).get(),
      logs: await db.select(db.setLogs).get(),
      exercises: await db.select(db.exercises).get(),
    );
    expect(stats.movementVolumeSeries().single.value, 20);
    expect(stats.movementVolumeSeries().single.label, 'اسکوات');
    expect(stats.weeklyVolumeSeries(testLocale), hasLength(1));

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
