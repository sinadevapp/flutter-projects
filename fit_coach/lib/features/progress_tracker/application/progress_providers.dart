import 'package:drift/drift.dart';
import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:fit_coach/features/progress_tracker/domain/workout_stats.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Every workout this student has done, finished or not.
final studentSessionsProvider = StreamProvider.autoDispose
    .family<List<WorkoutSession>, int>((ref, studentId) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.workoutSessions)
        ..where((s) => s.studentId.equals(studentId))
        ..orderBy([(s) => OrderingTerm.desc(s.startedAt)]))
      .watch();
});

/// Every set the student has logged, across all their workouts.
///
/// Joined in SQL so a student's history never pulls another student's rows.
final studentSetLogsProvider = StreamProvider.autoDispose
    .family<List<SetLog>, int>((ref, studentId) {
  final db = ref.watch(appDatabaseProvider);
  final query = db.select(db.setLogs).join([
    innerJoin(
      db.workoutSessions,
      db.workoutSessions.id.equalsExp(db.setLogs.sessionId),
    ),
  ])
    ..where(db.workoutSessions.studentId.equals(studentId));

  return query.watch().map(
        (rows) => rows.map((row) => row.readTable(db.setLogs)).toList(),
      );
});

/// The movements of every plan the student has been given.
final studentExercisesProvider = StreamProvider.autoDispose
    .family<List<Exercise>, int>((ref, studentId) {
  final db = ref.watch(appDatabaseProvider);
  final query = db.select(db.exercises).join([
    innerJoin(
      db.workoutPlans,
      db.workoutPlans.id.equalsExp(db.exercises.planId),
    ),
  ])
    ..where(db.workoutPlans.studentId.equals(studentId));

  return query.watch().map(
        (rows) => rows
            .map((row) => row.readTable(db.exercises))
            .toList()
          ..sort((a, b) => a.position.compareTo(b.position)),
      );
});

/// Combines the three streams above into the aggregate the UI renders.
///
/// Emits null while any part is still loading, so the screen can show one
/// spinner instead of nesting three `.when` blocks.
final studentStatsProvider = Provider.autoDispose
    .family<WorkoutStats?, int>((ref, studentId) {
  final sessions = ref.watch(studentSessionsProvider(studentId));
  final logs = ref.watch(studentSetLogsProvider(studentId));
  final exercises = ref.watch(studentExercisesProvider(studentId));

  if (!sessions.hasValue || !logs.hasValue || !exercises.hasValue) return null;

  return WorkoutStats(
    sessions: sessions.requireValue,
    logs: logs.requireValue,
    exercises: exercises.requireValue,
  );
});
