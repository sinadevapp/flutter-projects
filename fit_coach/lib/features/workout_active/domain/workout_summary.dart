import 'package:fit_coach/core/database/app_database.dart';

/// One movement's contribution to a finished workout.
class MovementSummary {
  const MovementSummary({
    required this.name,
    required this.sets,
    required this.reps,
  });

  final String name;
  final int sets;
  final int reps;
}

/// What a student sees after finishing: how long it took and how much they did.
///
/// Pure, like [WorkoutProgress]: derived from rows the database already holds,
/// with no widgets and no queries.
class WorkoutSummary {
  const WorkoutSummary({
    required this.duration,
    required this.totalSets,
    required this.totalReps,
    required this.plannedSets,
    required List<MovementSummary> movements,
  }) : _movements = movements;

  /// From start to finish, or to the last logged set if still open.
  final Duration duration;

  final int totalSets;
  final int totalReps;

  /// How many sets the plan asked for, to say whether the workout was complete.
  final int plannedSets;

  final List<MovementSummary> _movements;

  bool get hasWork => totalSets > 0;

  bool get isComplete => plannedSets > 0 && totalSets >= plannedSets;

  /// Per-movement totals, in the order the plan lists them.
  List<MovementSummary> movementBreakdown() => _movements;

  /// Builds the summary from a session, its logs, and the plan's movements.
  static WorkoutSummary from({
    required WorkoutSession session,
    required List<SetLog> logs,
    required List<Exercise> exercises,
  }) {
    final byId = {for (final exercise in exercises) exercise.id: exercise};

    final setsPerMovement = <int, int>{};
    final repsPerMovement = <int, int>{};
    for (final log in logs) {
      setsPerMovement[log.exerciseId] =
          (setsPerMovement[log.exerciseId] ?? 0) + 1;

      final exercise = byId[log.exerciseId];
      if (exercise == null) continue;
      // The attempt wins over the prescription. A set logged without a rep
      // count — every set logged before that column existed — falls back to
      // the plan's number, which is the only figure available for it.
      repsPerMovement[log.exerciseId] =
          (repsPerMovement[log.exerciseId] ?? 0) +
          (log.repsPerformed ?? exercise.reps);
    }

    final movements = <MovementSummary>[];
    for (final exercise in exercises) {
      final sets = setsPerMovement[exercise.id] ?? 0;
      // A movement that was never performed is left out entirely — listing it
      // with zero would misrepresent what happened.
      if (sets == 0) continue;
      movements.add(MovementSummary(
        name: exercise.name,
        sets: sets,
        reps: repsPerMovement[exercise.id] ?? 0,
      ));
    }

    return WorkoutSummary(
      duration: _durationOf(session, logs),
      totalSets: logs.length,
      totalReps: movements.fold(0, (sum, m) => sum + m.reps),
      plannedSets: exercises.fold(0, (sum, e) => sum + e.sets),
      movements: movements,
    );
  }

  /// Time from start to the finish, or to the last logged set while open.
  ///
  /// An open workout deliberately does *not* fall back to "now": that would
  /// make the duration grow on every rebuild, which reads as broken.
  static Duration _durationOf(WorkoutSession session, List<SetLog> logs) {
    final finished = session.finishedAt;
    if (finished != null) return finished.difference(session.startedAt);
    if (logs.isEmpty) return Duration.zero;

    final last = logs
        .map((log) => log.completedAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    final span = last.difference(session.startedAt);
    return span.isNegative ? Duration.zero : span;
  }
}
