import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:fit_coach/core/database/plan_providers.dart';
import 'package:fit_coach/core/l10n/l10n_extension.dart';
import 'package:fit_coach/core/theme/app_theme.dart';
import 'package:fit_coach/core/widgets/states.dart';
import 'package:fit_coach/features/nutrition_budget/presentation/student_nutrition_screen.dart';
import 'package:fit_coach/features/progress_tracker/presentation/progress_screen.dart';
import 'package:fit_coach/core/utils/date_format.dart';
import 'package:fit_coach/features/auth/presentation/switch_role_button.dart';
import 'package:fit_coach/features/workout_active/application/workout_providers.dart';
import 'package:fit_coach/features/workout_active/presentation/active_workout_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the student sees: the plans their coach built for them.
class StudentPlanScreen extends ConsumerWidget {
  const StudentPlanScreen({super.key, required this.studentId});

  final int studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(plansForStudentProvider(studentId));

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.myPlans),
        actions: [
          IconButton(
            icon: const Icon(Icons.restaurant),
            tooltip: context.l10n.nutrition,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => StudentNutritionScreen(studentId: studentId),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.insights),
            tooltip: context.l10n.myProgress,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProgressScreen(studentId: studentId),
              ),
            ),
          ),
          const SwitchRoleButton(),
        ],
      ),
      body: plans.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const ErrorState(),
        data: (list) => list.isEmpty
            // Nothing the student can do from here — the plan is the coach's
            // to write — so this explains rather than offering an action.
            ? EmptyState(
                icon: Icons.fitness_center,
                message: context.l10n.noPlansForMe,
                hint: context.l10n.noPlansHintStudent,
              )
            : ListView.separated(
                padding: const EdgeInsets.all(AppTheme.pagePadding),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.fitness_center),
                    title: Text(
                      list[i].title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PlanDetailScreen(plan: list[i]),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

/// The movements of one plan, and the way to start (or resume) training it.
class PlanDetailScreen extends ConsumerWidget {
  const PlanDetailScreen({super.key, required this.plan});

  final WorkoutPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercises = ref.watch(planExercisesProvider(plan.id));
    // An unfinished workout on this plan means the student is mid-session.
    final active = ref.watch(activeWorkoutProvider(plan.studentId));

    return Scaffold(
      appBar: AppBar(title: Text(plan.title)),
      body: exercises.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const ErrorState(),
        data: (list) => list.isEmpty
            ? Center(child: Text(context.l10n.planHasNoMovements))
            : ListView(
                children: [
                  for (final exercise in list)
                    ListTile(
                      title: Text(exercise.name),
                      trailing: Text(
                        context.l10n.setsXReps(
                          localizeNumber(
                            Localizations.localeOf(context),
                            exercise.sets,
                          ),
                          localizeNumber(
                            Localizations.localeOf(context),
                            exercise.reps,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
      floatingActionButton: active.when(
        loading: () => null,
        error: (_, __) => null,
        data: (session) => FloatingActionButton.extended(
          onPressed: () => _start(context, ref, session),
          label: Text(session == null ? context.l10n.startWorkout : context.l10n.resumeWorkout),
          icon: const Icon(Icons.play_arrow),
        ),
      ),
    );
  }

  /// Resumes the open session, or opens a new one, then shows the workout.
  Future<void> _start(
    BuildContext context,
    WidgetRef ref,
    WorkoutSession? session,
  ) async {
    final sessionId = session?.id ??
        await ref.read(appDatabaseProvider).startWorkoutSession(
              planId: plan.id,
              studentId: plan.studentId,
            );
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActiveWorkoutScreen(sessionId: sessionId, plan: plan),
      ),
    );
  }
}
