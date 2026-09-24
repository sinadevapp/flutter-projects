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

void main() {
  const fa = Locale('fa');
  const en = Locale('en');

  final exercises = [exercise(1, 'اسکوات', 10), exercise(2, 'پرس سینه', 8)];

  test('an empty history reports nothing', () {
    const stats = WorkoutStats(sessions: [], logs: [], exercises: []);

    expect(stats.hasHistory, isFalse);
    expect(stats.completedWorkouts, 0);
    expect(stats.totalSets, 0);
    expect(stats.volumeByMovement(), isEmpty);
    expect(stats.weeklyVolume(fa), isEmpty);
  });

  test('only finished sessions count as completed workouts', () {
    final stats = WorkoutStats(
      sessions: [
        session(1, DateTime(2026, 9, 21)),
        session(2, null), // still in progress
      ],
      logs: const [],
      exercises: exercises,
    );

    expect(stats.completedWorkouts, 1);
  });

  test('volume is the reps performed per movement, busiest first', () {
    final stats = WorkoutStats(
      sessions: [session(1, DateTime(2026, 9, 21))],
      logs: [
        log(1, 1, DateTime(2026, 9, 21)),
        log(2, 1, DateTime(2026, 9, 21)),
        log(3, 2, DateTime(2026, 9, 21)),
      ],
      exercises: exercises,
    );

    // Two squat sets × 10 reps, one bench set × 8 reps.
    // (MapEntry has no ==, so compare keys and values.)
    final volume = stats.volumeByMovement();
    expect(volume.map((e) => e.key).toList(), ['اسکوات', 'پرس سینه']);
    expect(volume.map((e) => e.value).toList(), [20, 8]);
  });

  test('weekly volume groups by the language week, newest first', () {
    final stats = WorkoutStats(
      sessions: [session(1, DateTime(2026, 9, 21))],
      logs: [
        // Monday 21 Sep and Sunday 20 Sep: same Persian week (starts Sat 19).
        log(1, 1, DateTime(2026, 9, 21)),
        log(2, 1, DateTime(2026, 9, 20)),
        // A week earlier.
        log(3, 1, DateTime(2026, 9, 12)),
      ],
      exercises: exercises,
    );

    final weeks = stats.weeklyVolume(fa);
    expect(weeks.length, 2);
    expect(weeks.first.weekStart, DateTime(2026, 9, 19));
    expect(weeks.first.sets, 2);
    expect(weeks.last.weekStart, DateTime(2026, 9, 12));
    expect(weeks.last.sets, 1);

    // In English the Sunday falls in the previous week (weeks start Monday).
    final enWeeks = stats.weeklyVolume(en);
    expect(enWeeks.length, 3);
    expect(enWeeks.first.weekStart, DateTime(2026, 9, 21));
    expect(enWeeks.first.sets, 1);
  });
}
