import 'package:drift/drift.dart' show Value;
import 'package:fit_coach/core/database/app_database.dart';

/// Reading and extending a plan's week/day structure.
///
/// Lives in `core/` rather than in `workout_builder` because **two features**
/// need the same answer: the authoring screen groups movements by day to
/// write them, and the execution screen groups them by day to run them. A
/// copy in each feature would mean "which movements belong to day (2,1)" could
/// be written twice and disagree — and that is exactly the kind of thing that
/// quietly logs a workout under the wrong day.
///
/// Which days a plan has, as `(week, day)` pairs in authoring order.
///
/// Derived, not stored: a day exists only because movements sit in it. Order
/// is week then day regardless of how the rows arrived, so the schedule on
/// screen never depends on insertion order.
List<(int, int)> daysOf(List<Exercise> exercises) {
  final seen = <(int, int)>{};
  for (final exercise in exercises) {
    seen.add((exercise.weekNumber, exercise.dayNumber));
  }
  return [for (final day in seen) day]..sort((a, b) {
    if (a.$1 != b.$1) return a.$1.compareTo(b.$1);
    return a.$2.compareTo(b.$2);
  });
}

/// The movements of one day, in display order.
///
/// Day first, position second. Positions restart in every day, so ordering by
/// position alone would interleave day 1 into day 2.
List<Exercise> exercisesForDay(List<Exercise> exercises, int week, int day) => [
  for (final exercise in exercises)
    if (exercise.weekNumber == week && exercise.dayNumber == day) exercise,
]..sort((a, b) => a.position.compareTo(b.position));

/// Every movement of one week, in day then position order.
List<Exercise> exercisesForWeek(List<Exercise> exercises, int week) =>
    [
      for (final exercise in exercises)
        if (exercise.weekNumber == week) exercise,
    ]..sort((a, b) {
      if (a.dayNumber != b.dayNumber) {
        return a.dayNumber.compareTo(b.dayNumber);
      }
      return a.position.compareTo(b.position);
    });

/// The week the coach should write next: the first one with nothing in it.
///
/// Starting at 1 and walking forward means a hole left in the middle is
/// filled next, which is what a coach who skipped a week expects.
int nextWeekToAuthor(List<Exercise> exercises) {
  var week = 1;
  while (exercisesForWeek(exercises, week).isNotEmpty) {
    week++;
  }
  return week;
}

/// Whether [toWeek] can be filled by copying [fromWeek].
///
/// Refuses an empty source, a destination the coach has already written, and
/// copying a week onto itself. Merging into a filled week would destroy what
/// is already there, and doubling a week by accident is worse than doing
/// nothing.
bool canCopyWeek(
  List<Exercise> source, {
  required int fromWeek,
  required int toWeek,
}) {
  if (fromWeek == toWeek) return false;
  if (exercisesForWeek(source, fromWeek).isEmpty) return false;
  return exercisesForWeek(source, toWeek).isEmpty;
}

/// Movements of [fromWeek] relabelled for [toWeek], ready to insert.
///
/// Returns the companions rather than writing them: this is pure planning, and
/// the database decides when and whether to commit.
///
/// This is how real programs get written — one template, then small edits per
/// week. Day, order, category, sets and reps all carry over, because copying
/// the *structure* is the whole point; the coach edits the numbers afterwards.
List<ExercisesCompanion> copyWeekForward({
  required int planId,
  required List<Exercise> source,
  required int fromWeek,
  required int toWeek,
}) {
  if (fromWeek == toWeek) return const [];

  return [
    for (final exercise in exercisesForWeek(source, fromWeek))
      ExercisesCompanion.insert(
        planId: planId,
        weekNumber: Value(toWeek),
        dayNumber: Value(exercise.dayNumber),
        name: exercise.name,
        sets: exercise.sets,
        reps: exercise.reps,
        category: Value(exercise.category),
        position: Value(exercise.position),
      ),
  ];
}
