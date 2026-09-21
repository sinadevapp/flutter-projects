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
