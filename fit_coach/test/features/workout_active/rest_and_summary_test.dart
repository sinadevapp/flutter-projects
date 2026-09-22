import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/features/workout_active/domain/workout_summary.dart';
import 'package:fit_coach/features/workout_active/presentation/rest_timer_view.dart';
import 'package:fit_coach/features/workout_active/presentation/workout_summary_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_app.dart';

/// The rest timer and the end-of-workout summary.
///
/// The arithmetic lives in the domain (rest_timer_test, workout_summary_test);
/// these cover the rendering and the interaction.
void main() {
  group('rest timer view', () {
    testWidgets('counts down and reports the seconds left', (tester) async {
      await tester.pumpWidget(
        testApp(
          home: const Scaffold(
            body: RestTimerView(total: Duration(seconds: 5)),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('استراحت'), findsOneWidget);
      expect(find.text('۵'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      expect(find.text('۳'), findsOneWidget);

      // Let the periodic ticker stop before the test ends.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets('calls onFinished once when the rest runs out', (tester) async {
      var finishes = 0;
      await tester.pumpWidget(
        testApp(
          home: Scaffold(
            body: RestTimerView(
              total: const Duration(seconds: 2),
              onFinished: () => finishes++,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));

      expect(finishes, 1);
      expect(find.text('استراحت تمام شد'), findsOneWidget);

      // The ticker must not keep firing after the rest is over.
      await tester.pump(const Duration(seconds: 5));
      expect(finishes, 1);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets('skipping ends the rest at once', (tester) async {
      var finishes = 0;
      await tester.pumpWidget(
        testApp(
          home: Scaffold(
            body: RestTimerView(
              total: const Duration(seconds: 90),
              onFinished: () => finishes++,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('رد کردن'));
      await tester.pump();

      expect(finishes, 1);
      expect(find.text('استراحت تمام شد'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets('pausing stops the countdown, resuming continues it',
        (tester) async {
      await tester.pumpWidget(
        testApp(
          home: const Scaffold(
            body: RestTimerView(total: Duration(seconds: 90)),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      await tester.tap(find.text('توقف'));
      await tester.pump();
      final frozen = tester.widget<Text>(find.byType(Text).at(1)).data;

      await tester.pump(const Duration(seconds: 5));
      // Time passing while paused must not burn the rest down.
      expect(tester.widget<Text>(find.byType(Text).at(1)).data, frozen);

      await tester.tap(find.text('ادامه'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(tester.widget<Text>(find.byType(Text).at(1)).data, isNot(frozen));

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  });

  group('workout summary view', () {
    WorkoutSummary summary({required bool complete}) => WorkoutSummary.from(
          session: WorkoutSession(
            id: 1,
            planId: 1,
            studentId: 1,
            startedAt: DateTime(2026, 9, 22, 18),
            finishedAt: DateTime(2026, 9, 22, 19, 15),
          ),
          logs: [
            SetLog(
              id: 1,
              sessionId: 1,
              exerciseId: 1,
              setNumber: 1,
              completedAt: DateTime(2026, 9, 22, 18, 5),
            ),
            if (complete)
              SetLog(
                id: 2,
                sessionId: 1,
                exerciseId: 1,
                setNumber: 2,
                completedAt: DateTime(2026, 9, 22, 18, 10),
              ),
          ],
          exercises: [
            Exercise(
              id: 1,
              planId: 1,
              name: 'اسکوات',
              // Two sets asked for, so `complete` decides whether it is done.
              sets: 2,
              reps: 10,
              position: 1,
            ),
          ],
        );

    testWidgets('a complete workout says so and shows the totals',
        (tester) async {
      await tester.pumpWidget(
        testApp(
          home: Scaffold(
            body: WorkoutSummaryView(
              summary: summary(complete: true),
              onDone: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('خلاصه تمرین'), findsOneWidget);
      expect(find.text('تمرین کامل شد'), findsOneWidget);
      // 1 h 15 min, 2 sets, 20 reps — all in Persian digits.
      expect(find.text('۱ ساعت و ۱۵ دقیقه'), findsOneWidget);
      expect(find.text('۲۰'), findsOneWidget);
      expect(find.text('اسکوات'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets('a workout cut short says that plainly', (tester) async {
      await tester.pumpWidget(
        testApp(
          home: Scaffold(
            body: WorkoutSummaryView(
              summary: summary(complete: false),
              onDone: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // A partial workout must not look like a finished one.
      expect(find.text('تمرین ناتمام'), findsOneWidget);
      expect(find.text('تمرین کامل شد'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets('it works in English too', (tester) async {
      await tester.pumpWidget(
        testApp(
          home: Scaffold(
            body: WorkoutSummaryView(
              summary: summary(complete: true),
              onDone: () {},
            ),
          ),
          locale: const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Workout summary'), findsOneWidget);
      expect(find.text('1 h 15 min'), findsOneWidget);
      expect(find.text('۲۰'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets('finishing calls back so the screen can close', (tester) async {
      var done = 0;
      await tester.pumpWidget(
        testApp(
          home: Scaffold(
            body: WorkoutSummaryView(
              summary: summary(complete: true),
              onDone: () => done++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'پایان تمرین'));
      await tester.pumpAndSettle();
      expect(done, 1);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  });
}
