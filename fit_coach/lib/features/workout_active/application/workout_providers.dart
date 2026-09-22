// Full drift import: the `&` operator on boolean expressions comes from an
// extension exported by drift.dart.
import 'package:drift/drift.dart';
import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The student's unfinished workout, if any — drives the "resume" button and
/// survives the app being closed mid-workout.
final activeWorkoutProvider =
    StreamProvider.autoDispose.family<WorkoutSession?, int>((ref, studentId) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.workoutSessions)
        ..where((s) => s.studentId.equals(studentId) & s.finishedAt.isNull())
        ..orderBy([(s) => OrderingTerm.desc(s.startedAt)])
        ..limit(1))
      .watchSingleOrNull();
});

/// One workout session by id.
///
/// The active workout screen is handed an id, but the end-of-workout summary
/// needs the session's real `startedAt` to time it honestly — deriving the
/// start from the first logged set would understate a workout where the
/// student logged the first set minutes after starting.
final workoutSessionProvider =
    StreamProvider.autoDispose.family<WorkoutSession?, int>((ref, sessionId) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.workoutSessions)
        ..where((s) => s.id.equals(sessionId)))
      .watchSingleOrNull();
});

/// Sets logged so far in one workout, oldest first.
final setLogsProvider =
    StreamProvider.autoDispose.family<List<SetLog>, int>((ref, sessionId) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.setLogs)
        ..where((l) => l.sessionId.equals(sessionId))
        ..orderBy([(l) => OrderingTerm.asc(l.id)]))
      .watch();
});
