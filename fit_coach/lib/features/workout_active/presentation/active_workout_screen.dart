import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:fit_coach/core/database/plan_providers.dart';
import 'package:fit_coach/core/l10n/l10n_extension.dart';
import 'package:fit_coach/core/utils/date_format.dart';
import 'package:fit_coach/features/workout_active/application/workout_providers.dart';
import 'package:fit_coach/features/workout_active/domain/workout_progress.dart';
import 'package:fit_coach/features/workout_active/domain/workout_summary.dart';
import 'package:fit_coach/features/workout_active/presentation/rest_timer_view.dart';
import 'package:fit_coach/features/workout_active/presentation/workout_summary_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How long the student rests between sets.
///
/// A per-workout default for now; making it configurable per plan is a later
/// step, and [RestTimerView] already takes whatever length it is given.
const Duration kDefaultRest = Duration(seconds: 90);

/// The workout in progress: which movement, which set, and the way to log it.
///
/// Every tap writes to the database immediately, so closing the app at any
/// point loses nothing — reopening lands back on the same set.
class ActiveWorkoutScreen extends ConsumerStatefulWidget {
  const ActiveWorkoutScreen({
    super.key,
    required this.sessionId,
    required this.plan,
  });

  final int sessionId;
  final WorkoutPlan plan;

  @override
  ConsumerState<ActiveWorkoutScreen> createState() =>
      _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends ConsumerState<ActiveWorkoutScreen> {
  /// Rest is an *event* between sets, not a state the workout is in: it is
  /// shown for one rest and then gone, so the student is never stuck looking
  /// at a finished timer.
  bool _resting = false;

  Future<void> _logSet(int exerciseId, int setNumber) async {
    await ref.read(appDatabaseProvider).logSet(
          sessionId: widget.sessionId,
          exerciseId: exerciseId,
          setNumber: setNumber,
        );
    // A short buzz on logging, so the tap registers without looking.
    await HapticFeedback.lightImpact();
    if (mounted) setState(() => _resting = true);
  }

  Future<void> _finish() async {
    await ref
        .read(appDatabaseProvider)
        .finishWorkoutSession(widget.sessionId);
  }

  @override
  Widget build(BuildContext context) {
    final exercises = ref.watch(planExercisesProvider(widget.plan.id));
    final logs = ref.watch(setLogsProvider(widget.sessionId));
    final session = ref.watch(workoutSessionProvider(widget.sessionId));

    return Scaffold(
      appBar: AppBar(title: Text(widget.plan.title)),
      body: exercises.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) => logs.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (logs) => _body(list, logs, session.value),
        ),
      ),
    );
  }

  Widget _body(
    List<Exercise> exercises,
    List<SetLog> logs,
    WorkoutSession? session,
  ) {
    final locale = Localizations.localeOf(context);
    final l10n = context.l10n;
    final progress = WorkoutProgress(exercises: exercises, logs: logs);
    final current = progress.currentExercise;

    if (current == null) {
      // The plan is done. The summary is shown before finishing so the student
      // sees what they did; finishing writes the end time on the way out.
      //
      // The duration is measured from the session's real start. Until it has
      // loaded, the summary still renders — an unknown start is reported as
      // zero rather than guessed at from the first logged set.
      return WorkoutSummaryView(
        summary: WorkoutSummary.from(
          session: session ??
              WorkoutSession(
                id: widget.sessionId,
                planId: widget.plan.id,
                studentId: widget.plan.studentId,
                startedAt: logs.isEmpty ? DateTime.now() : logs.first.completedAt,
                finishedAt: DateTime.now(),
              ),
          logs: logs,
          exercises: exercises,
        ),
        onDone: () async {
          await _finish();
          if (mounted) Navigator.of(context).pop();
        },
      );
    }

    return Column(
      children: [
        if (_resting)
          RestTimerView(
            total: kDefaultRest,
            onFinished: () => setState(() => _resting = false),
          ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  current.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.setOf(
                    localizeNumber(locale, progress.currentSetNumber),
                    localizeNumber(locale, current.sets),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.setsProgress(
                    localizeNumber(locale, progress.completedSets),
                    localizeNumber(locale, progress.totalSets),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () =>
                      _logSet(current.id, progress.currentSetNumber),
                  child: Text(l10n.completeSet),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

}
