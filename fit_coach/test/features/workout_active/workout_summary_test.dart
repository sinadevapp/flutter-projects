import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/features/workout_active/domain/workout_progress.dart';
import 'package:fit_coach/features/workout_active/domain/workout_summary.dart';
import 'package:flutter_test/flutter_test.dart';

Exercise exercise(int id, String name, int sets, int reps) => Exercise(
  id: id,
  planId: 1,
  name: name,
  sets: sets,
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

WorkoutSession session({
  required DateTime startedAt,
  DateTime? finishedAt,
  int id = 1,
}) => WorkoutSession(
  id: id,
  planId: 1,
  studentId: 1,
  startedAt: startedAt,
  finishedAt: finishedAt,
  weekNumber: 1,
  dayNumber: 1,
);

/// What the student sees after finishing: how long it took, how much they did.
void main() {
  final exercises = [
    exercise(1, 'اسکوات', 3, 10),
    exercise(2, 'پرس سینه', 2, 8),
  ];

  test('a workout with nothing logged summarises as empty', () {
    final summary = WorkoutSummary.from(
      session: session(startedAt: DateTime(2026, 9, 22, 18)),
      logs: const [],
      exercises: exercises,
    );

    expect(summary.totalSets, 0);
    expect(summary.totalReps, 0);
    expect(summary.hasWork, isFalse);
    expect(summary.movementBreakdown(), isEmpty);
  });

  test('it counts the sets and reps actually performed', () {
    final summary = WorkoutSummary.from(
      session: session(
        startedAt: DateTime(2026, 9, 22, 18),
        finishedAt: DateTime(2026, 9, 22, 19),
      ),
      logs: [
        log(1, 1, DateTime(2026, 9, 22, 18, 5)),
        log(2, 1, DateTime(2026, 9, 22, 18, 10)),
        log(3, 1, DateTime(2026, 9, 22, 18, 15)),
        log(4, 2, DateTime(2026, 9, 22, 18, 20)),
      ],
      exercises: exercises,
    );

    // Four sets: three squats at 10 reps, one bench at 8.
    expect(summary.totalSets, 4);
    expect(summary.totalReps, 38);
    expect(summary.hasWork, isTrue);
  });

  test('the breakdown is per movement, in the order the plan lists them', () {
    final summary = WorkoutSummary.from(
      session: session(startedAt: DateTime(2026, 9, 22, 18)),
      logs: [
        log(1, 2, DateTime(2026, 9, 22, 18, 5)), // bench first, out of order
        log(2, 1, DateTime(2026, 9, 22, 18, 10)),
        log(3, 1, DateTime(2026, 9, 22, 18, 15)),
      ],
      exercises: exercises,
    );

    final breakdown = summary.movementBreakdown();
    expect(breakdown.map((m) => m.name).toList(), ['اسکوات', 'پرس سینه']);
    expect(breakdown.map((m) => m.sets).toList(), [2, 1]);
    expect(breakdown.map((m) => m.reps).toList(), [20, 8]);
  });

  test('movements that were never performed are left out', () {
    final summary = WorkoutSummary.from(
      session: session(startedAt: DateTime(2026, 9, 22, 18)),
      logs: [log(1, 1, DateTime(2026, 9, 22, 18, 5))],
      exercises: exercises,
    );

    // Only squats happened; listing bench with zero would overstate the plan.
    expect(summary.movementBreakdown().map((m) => m.name).toList(), ['اسکوات']);
  });

  test('duration runs from start to finish', () {
    final summary = WorkoutSummary.from(
      session: session(
        startedAt: DateTime(2026, 9, 22, 18),
        finishedAt: DateTime(2026, 9, 22, 19, 15),
      ),
      logs: [log(1, 1, DateTime(2026, 9, 22, 18, 5))],
      exercises: exercises,
    );

    expect(summary.duration, const Duration(hours: 1, minutes: 15));
  });

  test('an unfinished workout is timed up to its last logged set', () {
    final summary = WorkoutSummary.from(
      session: session(startedAt: DateTime(2026, 9, 22, 18)),
      logs: [
        log(1, 1, DateTime(2026, 9, 22, 18, 30)),
        log(2, 1, DateTime(2026, 9, 22, 18, 45)),
      ],
      exercises: exercises,
    );

    // Not finished: falling back to "now" would make the duration grow on
    // every rebuild. The last logged set is a stable, honest answer.
    expect(summary.duration, const Duration(minutes: 45));
  });

  test('a workout with no sets and no finish has no duration', () {
    final summary = WorkoutSummary.from(
      session: session(startedAt: DateTime(2026, 9, 22, 18)),
      logs: const [],
      exercises: exercises,
    );

    expect(summary.duration, Duration.zero);
  });

  test('completion says whether the whole plan was performed', () {
    final full = WorkoutSummary.from(
      session: session(
        startedAt: DateTime(2026, 9, 22, 18),
        finishedAt: DateTime(2026, 9, 22, 19),
      ),
      logs: [
        log(1, 1, DateTime(2026, 9, 22, 18, 5)),
        log(2, 1, DateTime(2026, 9, 22, 18, 10)),
        log(3, 1, DateTime(2026, 9, 22, 18, 15)),
        log(4, 2, DateTime(2026, 9, 22, 18, 20)),
        log(5, 2, DateTime(2026, 9, 22, 18, 25)),
      ],
      exercises: exercises,
    );

    // Plan asks for 3 + 2 = 5 sets.
    expect(full.plannedSets, 5);
    expect(full.isComplete, isTrue);

    final partial = WorkoutSummary.from(
      session: session(startedAt: DateTime(2026, 9, 22, 18)),
      logs: [log(1, 1, DateTime(2026, 9, 22, 18, 5))],
      exercises: exercises,
    );

    expect(partial.isComplete, isFalse);
  });

  test('the summary agrees with WorkoutProgress about the same session', () {
    final logs = [
      log(1, 1, DateTime(2026, 9, 22, 18, 5)),
      log(2, 1, DateTime(2026, 9, 22, 18, 10)),
    ];
    final sessionRow = session(startedAt: DateTime(2026, 9, 22, 18));

    final summary = WorkoutSummary.from(
      session: sessionRow,
      logs: logs,
      exercises: exercises,
    );
    final progress = WorkoutProgress(exercises: exercises, logs: logs);

    // Two different views of one workout must never disagree.
    expect(summary.totalSets, progress.completedSets);
    expect(summary.plannedSets, progress.totalSets);
  });
}
