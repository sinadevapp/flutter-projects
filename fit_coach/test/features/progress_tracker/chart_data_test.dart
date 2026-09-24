import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/features/progress_tracker/domain/workout_stats.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Exercise exercise(int id, String name, int reps) => Exercise(
  id: id,
  planId: 1,
  name: name,
  sets: 3,
  reps: reps,
  position: id,
  weekNumber: 1,
  dayNumber: 1,
  category: ExerciseCategory.compound,
);

SetLog log(int id, int exerciseId, DateTime at) => SetLog(
  id: id,
  sessionId: 1,
  exerciseId: exerciseId,
  setNumber: 1,
  completedAt: at,
);

WorkoutSession session(int id, DateTime? finishedAt) => WorkoutSession(
  id: id,
  planId: 1,
  studentId: 1,
  startedAt: DateTime(2026, 9, 21),
  finishedAt: finishedAt,
  weekNumber: 1,
  dayNumber: 1,
);

/// Chart data is derived in the domain, never in `build()`, so the shape the
/// charts render is unit-testable without pumping a widget.
void main() {
  const fa = Locale('fa');

  final exercises = [exercise(1, 'اسکوات', 10), exercise(2, 'پرس سینه', 8)];

  test('an empty history produces no chart points', () {
    const stats = WorkoutStats(sessions: [], logs: [], exercises: []);

    expect(stats.weeklyVolumeSeries(fa), isEmpty);
    expect(stats.movementVolumeSeries(), isEmpty);
  });

  group('weekly volume series', () {
    test('is oldest first, because a trend reads left to right', () {
      final stats = WorkoutStats(
        sessions: [session(1, DateTime(2026, 9, 21))],
        logs: [
          // Newest week.
          log(1, 1, DateTime(2026, 9, 21)),
          // A week earlier.
          log(2, 1, DateTime(2026, 9, 12)),
          log(3, 1, DateTime(2026, 9, 13)),
        ],
        exercises: exercises,
      );

      final series = stats.weeklyVolumeSeries(fa);

      // weeklyVolume() returns newest first for the list UI; a chart needs the
      // opposite, and reversing in the widget would be logic in build().
      expect(series, hasLength(2));
      expect(series.first.weekStart, DateTime(2026, 9, 12));
      expect(series.first.value, 2);
      expect(series.last.weekStart, DateTime(2026, 9, 19));
      expect(series.last.value, 1);
    });

    test('agrees with the list the screen already shows', () {
      final stats = WorkoutStats(
        sessions: [session(1, DateTime(2026, 9, 21))],
        logs: [
          log(1, 1, DateTime(2026, 9, 21)),
          log(2, 1, DateTime(2026, 9, 12)),
        ],
        exercises: exercises,
      );

      final list = stats.weeklyVolume(fa);
      final series = stats.weeklyVolumeSeries(fa);

      // Same data, opposite order: the chart and the list must never disagree.
      expect(
        series.map((p) => p.weekStart).toList(),
        list.reversed.map((w) => w.weekStart).toList(),
      );
      expect(
        series.map((p) => p.value).toList(),
        list.reversed.map((w) => w.sets).toList(),
      );
    });
  });

  group('movement volume series', () {
    test('is busiest first, and carries the label the chart draws', () {
      final stats = WorkoutStats(
        sessions: [session(1, DateTime(2026, 9, 21))],
        logs: [
          log(1, 1, DateTime(2026, 9, 21)),
          log(2, 1, DateTime(2026, 9, 21)),
          log(3, 2, DateTime(2026, 9, 21)),
        ],
        exercises: exercises,
      );

      final series = stats.movementVolumeSeries();

      expect(series.map((p) => p.label).toList(), ['اسکوات', 'پرس سینه']);
      // Two squat sets x 10 reps = 20, one bench set x 8 = 8.
      expect(series.map((p) => p.value).toList(), [20, 8]);
    });

    test('agrees with the list the screen already shows', () {
      final stats = WorkoutStats(
        sessions: [session(1, DateTime(2026, 9, 21))],
        logs: [
          log(1, 1, DateTime(2026, 9, 21)),
          log(2, 2, DateTime(2026, 9, 21)),
        ],
        exercises: exercises,
      );

      expect(
        stats.movementVolumeSeries().map((p) => p.label).toList(),
        stats.volumeByMovement().map((e) => e.key).toList(),
      );
    });
  });

  test('chart points carry a label for the axis', () {
    final stats = WorkoutStats(
      sessions: [session(1, DateTime(2026, 9, 21))],
      logs: [log(1, 1, DateTime(2026, 9, 21))],
      exercises: exercises,
    );

    // The week point carries its start date so the axis can format it through
    // the locale helpers rather than the chart guessing at a calendar.
    final point = stats.weeklyVolumeSeries(fa).single;
    expect(point.weekStart, isA<DateTime>());
    expect(point.value, 1);
  });
}
