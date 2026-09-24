import 'package:fit_coach/app/navigate.dart';
import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:fit_coach/core/database/plan_providers.dart';
import 'package:fit_coach/core/l10n/l10n_extension.dart';
import 'package:fit_coach/core/schedule/exercise_schedule.dart';
import 'package:fit_coach/core/theme/app_theme.dart';
import 'package:fit_coach/core/widgets/plan_title.dart';
import 'package:fit_coach/core/widgets/states.dart';
import 'package:fit_coach/core/utils/date_format.dart';
import 'package:fit_coach/core/widgets/switch_role_button.dart';
import 'package:fit_coach/core/database/workout_providers.dart';
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
            onPressed: () => context.openStudentNutrition(studentId),
          ),
          IconButton(
            icon: const Icon(Icons.insights),
            tooltip: context.l10n.myProgress,
            onPressed: () => context.openMyProgress(studentId),
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

/// The days of one plan, and the way to train each of them.
///
/// Grouped week → day rather than one flat list: a program spans several
/// weeks now, and a single scroll of every movement ever written says nothing
/// about what to do *today*.
///
/// Exactly one day can be running at a time. The day the open session belongs
/// to offers to resume; the others say so rather than quietly resuming
/// somewhere else — which is what the previous "start or resume" button did.
class PlanDetailScreen extends ConsumerWidget {
  const PlanDetailScreen({super.key, required this.plan});

  final WorkoutPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercises = ref.watch(planExercisesProvider(plan.id));
    // An unfinished workout on this plan means the student is mid-session.
    final active = ref.watch(activeWorkoutProvider(plan.studentId));

    return Scaffold(
      appBar: AppBar(
        title: PlanAppBarTitle(
          title: plan.title,
          durationWeeks: plan.durationWeeks,
        ),
      ),
      body: exercises.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const ErrorState(),
        data: (list) => active.when(
          // Until it is known whether something is running, every day would
          // offer to start — say nothing rather than offering twice.
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const ErrorState(),
          data: (session) => ref.watch(planDaysProvider(plan.id)).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const ErrorState(),
            data: (slots) {
              if (list.isEmpty && slots.isEmpty) {
                return Center(child: Text(context.l10n.planHasNoMovements));
              }

              final locale = Localizations.localeOf(context);
              final cards = <Widget>[];
              int? lastWeek;

              // From `plan_days`, not from the movements: a rest day has no
              // movements, and the day the student should *not* train is
              // exactly the one they need to see.
              for (final slot in slots) {
                // The week is printed once, where it starts — repeating it on
                // every day would bury the day itself.
                if (lastWeek != slot.weekNumber) {
                  lastWeek = slot.weekNumber;
                  cards.add(
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                      child: Text(
                        context.l10n
                            .weekLabel(localizeNumber(locale, slot.weekNumber)),
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  );
                }
                cards.add(
                  _DayCard(
                    day: slot.dayNumber,
                    title: slot.title,
                    isRestDay: slot.isRestDay,
                    movements: exercisesForDay(
                      list,
                      slot.weekNumber,
                      slot.dayNumber,
                    ),
                    isTheOpenSession:
                        session != null &&
                        session.weekNumber == slot.weekNumber &&
                        session.dayNumber == slot.dayNumber,
                    anotherSessionOpen: session != null,
                    onStart: () =>
                        _start(context, ref, slot.weekNumber, slot.dayNumber),
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.all(AppTheme.pagePadding),
                children: cards,
              );
            },
          ),
        ),
      ),
    );
  }

  /// Trains one day, resuming it first if that is the session already running.
  Future<void> _start(
    BuildContext context,
    WidgetRef ref,
    int week,
    int day,
  ) async {
    final db = ref.read(appDatabaseProvider);
    final open = await db.getActiveWorkoutSession(plan.studentId);

    // A day that is still running belongs to the day it started on. Resuming
    // it for a *different* day would write this day's sets into that one.
    final sessionId = open != null
        ? open.id
        : await db.startWorkoutSession(
            planId: plan.id,
            studentId: plan.studentId,
            weekNumber: week,
            dayNumber: day,
          );
    if (!context.mounted) return;
    await context.openActiveWorkout(sessionId: sessionId, plan: plan);
  }
}

/// One day: its header, its movements, and what starting it would do.
class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.day,
    required this.title,
    required this.isRestDay,
    required this.movements,
    required this.isTheOpenSession,
    required this.anotherSessionOpen,
    required this.onStart,
  });

  final int day;

  /// The coach's name for the day, null until they gave it one.
  final String? title;

  /// Planned rest: nothing to perform, so nothing to offer to start.
  final bool isRestDay;

  final List<Exercise> movements;

  /// This day *is* the one running right now.
  final bool isTheOpenSession;

  /// Some day is running — possibly this one, possibly another.
  final bool anotherSessionOpen;

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  title ?? l10n.dayLabel(localizeNumber(locale, day)),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isRestDay ? theme.colorScheme.tertiary : null,
                  ),
                ),
                if (isRestDay) ...[
                  const SizedBox(width: 8),
                  Text(
                    l10n.restDay,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.tertiary,
                    ),
                  ),
                ],
                if (isTheOpenSession) ...[
                  const SizedBox(width: 8),
                  // The one place a running workout is flagged, so the
                  // student can find it again after leaving the screen.
                  Icon(
                    Icons.play_circle,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            for (final movement in movements)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(movement.name),
                trailing: Text(
                  l10n.setsXReps(
                    localizeNumber(locale, movement.sets),
                    localizeNumber(locale, movement.reps),
                  ),
                ),
              ),
            const SizedBox(height: 4),
            if (isRestDay)
              // Nothing to offer: a rest day has no movements and no session
              // to start. Saying what it is beats an empty card.
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l10n.restDayHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else if (isTheOpenSession)
              FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow),
                label: Text(l10n.resumeWorkout),
              )
            else if (anotherSessionOpen)
              // Say why rather than silently doing the wrong thing: starting
              // here would resume the *other* day and log sets against it.
              OutlinedButton(
                onPressed: null,
                child: Text(l10n.finishPreviousFirst),
              )
            else
              FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow),
                label: Text(l10n.startWorkout),
              ),
          ],
        ),
      ),
    );
  }
}
