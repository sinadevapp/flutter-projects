import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/schedule/exercise_schedule.dart';

/// Copies one week of a plan onto another, returning how many movements
/// landed.
///
/// The orchestration lives here rather than in `AppDatabase` on purpose:
/// deciding *whether* a copy may happen is domain policy, and `core/` must
/// never import a feature to reach it. The database only reads and writes
/// rows; this is where the two meet.
///
/// Returns 0 when the copy is refused — an empty source, the same week
/// twice, or a destination the coach has already written. Appending over an
/// existing week would silently double it.
Future<int> copyWeek(
  AppDatabase db, {
  required int planId,
  required int fromWeek,
  required int toWeek,
}) => db.transaction(() async {
  final movements = await db.getExercisesForPlan(planId);

  if (!canCopyWeek(movements, fromWeek: fromWeek, toWeek: toWeek)) {
    return 0;
  }

  final copies = copyWeekForward(
    planId: planId,
    source: movements,
    fromWeek: fromWeek,
    toWeek: toWeek,
  );
  for (final copy in copies) {
    await db.insertExercise(copy);
  }
  return copies.length;
});
