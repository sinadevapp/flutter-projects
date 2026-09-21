import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:fit_coach/core/database/plan_providers.dart';
import 'package:fit_coach/core/utils/persian_digits.dart';
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
    final current = progress.currentExercise;

    if (current == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('تمرین تمام شد'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                await ref
                    .read(appDatabaseProvider)
                    .finishWorkoutSession(sessionId);
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('پایان تمرین'),
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
          Text('ست ${fa(progress.currentSetNumber)} از ${fa(current.sets)}'),
          const SizedBox(height: 8),
          Text('${fa(progress.completedSets)} از ${fa(progress.totalSets)} ست'),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => ref.read(appDatabaseProvider).logSet(
                  sessionId: sessionId,
                  exerciseId: current.id,
                  setNumber: progress.currentSetNumber,
                ),
            child: const Text('ست تمام'),
          ),
        ],
      ),
    );
  }
}
