import 'package:drift/drift.dart' show OrderingTerm;
import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Live stream of one student's training plans.
///
/// Shared read model: the coach manages a student's plans, and the student
/// reads the same rows from their own side.
final plansForStudentProvider =
    StreamProvider.autoDispose.family<List<WorkoutPlan>, int>((ref, studentId) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.workoutPlans)
        ..where((p) => p.studentId.equals(studentId))
        ..orderBy([(p) => OrderingTerm.desc(p.createdAt)]))
      .watch();
});

/// Live stream of the movements of one plan, in display order.
final planExercisesProvider =
    StreamProvider.autoDispose.family<List<Exercise>, int>((ref, planId) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.exercises)
        ..where((e) => e.planId.equals(planId))
        ..orderBy([(e) => OrderingTerm.asc(e.position)]))
      .watch();
});

/// Live stream of a plan's days, in program order.
///
/// Reads the `plan_days` table rather than deriving from the movements: a
/// rest day has no movements and would otherwise be invisible — and its
/// whole point is that it exists.
///
/// Shared read model: the coach names days while authoring, the student
/// reads the same name afterwards.
final planDaysProvider =
    StreamProvider.autoDispose.family<List<PlanDay>, int>((ref, planId) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.planDays)
        ..where((d) => d.planId.equals(planId))
        ..orderBy([
          (d) => OrderingTerm.asc(d.weekNumber),
          (d) => OrderingTerm.asc(d.dayNumber),
        ]))
      .watch();
});
