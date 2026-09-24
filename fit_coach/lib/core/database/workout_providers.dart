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

/// What a student last did for one movement, and when.
///
/// Lives here rather than in a feature because both need it: the student reads
/// it mid-set, a coach reads it while writing next week. Features may not
/// import each other, so a read two of them share belongs in `core`.
class LastPerformance {
  const LastPerformance({
    required this.weightKg,
    required this.reps,
    required this.at,
  });

  /// Kilos lifted. Null for a bodyweight movement, or for a set logged
  /// before loads were recorded.
  final double? weightKg;

  /// Reps performed, falling back to what the plan asked when the set was
  /// logged without a count — the same rule [WorkoutSummary] uses.
  final int? reps;

  final DateTime at;

  bool get hasLoad => weightKg != null;
}

/// The most recent logged set for one movement, across every session.
///
/// Ordered by row id rather than by timestamp. Ids grow with insertion, so two
/// sets written in the same millisecond still have an unambiguous winner, and
/// a clock that happens to be wrong cannot reverse the answer.
final lastPerformanceProvider =
    FutureProvider.autoDispose.family<LastPerformance?, int>(
  (ref, exerciseId) async {
    final db = ref.watch(appDatabaseProvider);

    final log = await db.latestSetLog(exerciseId);
    if (log == null) return null;

    final movement = await db.getExercise(exerciseId);

    return LastPerformance(
      weightKg: log.weightKg,
      reps: log.repsPerformed ?? movement?.reps,
      at: log.completedAt,
    );
  },
);
