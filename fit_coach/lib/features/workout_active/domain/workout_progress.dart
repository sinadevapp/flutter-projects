import 'package:fit_coach/core/database/app_database.dart';

/// Where the student is inside one workout.
///
/// Pure domain logic: derived only from the plan's movements and the sets
/// already logged. No widgets and no database calls, so the rules can be unit
/// tested directly and the UI just renders the result.
class WorkoutProgress {
  const WorkoutProgress({required this.exercises, required this.logs});

  /// The plan's movements, in display order.
  final List<Exercise> exercises;

  /// Sets completed so far in this workout.
  final List<SetLog> logs;

  int completedSetsFor(int exerciseId) =>
      logs.where((log) => log.exerciseId == exerciseId).length;

  int get totalSets => exercises.fold(0, (sum, e) => sum + e.sets);

  int get completedSets => logs.length;

  /// The movement being performed now, or null when the workout is done.
  Exercise? get currentExercise {
    for (final exercise in exercises) {
      if (completedSetsFor(exercise.id) < exercise.sets) return exercise;
    }
    return null;
  }

  /// 1-based number of the set to perform next (0 when finished).
  int get currentSetNumber {
    final exercise = currentExercise;
    if (exercise == null) return 0;
    return completedSetsFor(exercise.id) + 1;
  }

  bool get isComplete => currentExercise == null;
}
