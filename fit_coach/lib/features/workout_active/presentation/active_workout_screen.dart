import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:fit_coach/core/database/plan_providers.dart';
import 'package:fit_coach/core/l10n/l10n_extension.dart';
import 'package:fit_coach/core/utils/date_format.dart';
import 'package:fit_coach/features/workout_active/application/workout_providers.dart';
import 'package:fit_coach/features/workout_active/domain/workout_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The workout in progress: which movement, which set, and the way to log it.
///
/// Every tap writes to the database immediately, so closing the app at any
/// point loses nothing — reopening lands back on the same set.
class ActiveWorkoutScreen extends ConsumerWidget {
  const ActiveWorkoutScreen({
    super.key,
    required this.sessionId,
    required this.plan,
  });

  final int sessionId;
  final WorkoutPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercises = ref.watch(planExercisesProvider(plan.id));
    final logs = ref.watch(setLogsProvider(sessionId));

    return Scaffold(
      appBar: AppBar(title: Text(plan.title)),
      body: exercises.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) => logs.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (logs) => _body(
            context,
            ref,
            WorkoutProgress(exercises: list, logs: logs),
          ),
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    WorkoutProgress progress,
  ) {
    final locale = Localizations.localeOf(context);
    final l10n = context.l10n;
    final current = progress.currentExercise;

    if (current == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.workoutComplete),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                await ref
                    .read(appDatabaseProvider)
                    .finishWorkoutSession(sessionId);
                if (context.mounted) Navigator.of(context).pop();
              },
              child: Text(l10n.finishWorkout),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(current.name, style: Theme.of(context).textTheme.headlineSmall),
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
            onPressed: () => ref.read(appDatabaseProvider).logSet(
                  sessionId: sessionId,
                  exerciseId: current.id,
                  setNumber: progress.currentSetNumber,
                ),
            child: Text(l10n.completeSet),
          ),
        ],
      ),
    );
  }
}
