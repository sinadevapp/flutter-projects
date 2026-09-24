import 'package:fit_coach/core/widgets/states.dart';
import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:fit_coach/core/database/plan_providers.dart';
import 'package:fit_coach/core/l10n/l10n_extension.dart';
import 'package:fit_coach/l10n/app_localizations.dart';
import 'package:fit_coach/core/theme/app_theme.dart';
import 'package:fit_coach/core/schedule/exercise_schedule.dart';
import 'package:fit_coach/core/utils/date_format.dart';
import 'package:fit_coach/core/database/workout_providers.dart';
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

  final _weight = TextEditingController();
  final _reps = TextEditingController();

  /// Which movement these fields were filled from.
  ///
  /// Refilled once per movement rather than once per set: the coach's number
  /// seeds set 1, and whatever the student then lifts carries forward to set
  /// 2 — which is what actually happens in a gym, and re-typing 82.5 three
  /// times is not a feature.
  int? _seededForExercise;

  @override
  void dispose() {
    _weight.dispose();
    _reps.dispose();
    super.dispose();
  }

  void _seedFrom(Exercise movement) {
    if (_seededForExercise == movement.id) return;
    _seededForExercise = movement.id;

    final target = movement.targetWeightKg;
    _weight.text = target == null
        ? ''
        : target == target.truncateToDouble()
            ? target.toStringAsFixed(0)
            : target.toString();
    _reps.text = movement.reps.toString();
  }

  /// Parses a weight field: empty or unparseable means "no load recorded".
  ///
  /// Garbage is not stored as a number, because a bad keystroke becoming
  /// "82 kg" in the history would be worse than leaving the set unmeasured.
  double? _enteredWeight() => double.tryParse(_weight.text.trim());

  int? _enteredReps() => int.tryParse(_reps.text.trim());

  Future<void> _logSet(int exerciseId, int setNumber) async {
    await ref.read(appDatabaseProvider).logSet(
          sessionId: widget.sessionId,
          exerciseId: exerciseId,
          setNumber: setNumber,
          weightKg: _enteredWeight(),
          reps: _enteredReps(),
        );
    // A short buzz on logging, so the tap registers without looking.
    await HapticFeedback.lightImpact();
    if (mounted) setState(() => _resting = true);
  }

  Future<void> _finish() async {
    await ref.read(appDatabaseProvider).finishWorkoutSession(widget.sessionId);
  }

  /// What this student managed last time they trained [movement].
  ///
  /// The number that decides what goes on the bar now — not the plan's guess.
  /// Shown quietly under the load fields, and *absent* rather than reading
  /// zero when there is no history: there is no last time to show, and
  /// "آخرین بار: ۰" would be inventing one.
  Widget _lastPerformed(
    Exercise movement,
    AppLocalizations l10n,
    Locale locale,
  ) {
    final perf = ref.watch(lastPerformanceProvider(movement.id)).value;
    if (perf == null || perf.reps == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        perf.hasLoad
            ? l10n.lastTime(
                localizeNumber(locale, perf.weightKg!),
                localizeNumber(locale, perf.reps!),
              )
            : l10n.lastTimeNoLoad(localizeNumber(locale, perf.reps!)),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final exercises = ref.watch(planExercisesProvider(widget.plan.id));
    final logs = ref.watch(setLogsProvider(widget.sessionId));
    final session = ref.watch(workoutSessionProvider(widget.sessionId));

    // The session row says which day this is, and it is read first on purpose:
    // deriving the day from anything else would land on the wrong day after
    // the app is killed mid-workout. Until it loads there is nothing honest
    // to show, so the plan as a whole is not flashed.
    return session.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => const Scaffold(body: ErrorState()),
      data: (row) {
        // The id does not resolve — there is no day to show, and guessing one
        // would render a workout that is not happening.
        if (row == null) {
          return const Scaffold(body: ErrorState());
        }
        return Scaffold(
          appBar: AppBar(title: Text(widget.plan.title)),
          body: exercises.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => const ErrorState(),
            data: (list) => logs.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => const ErrorState(),
              data: (logs) => _body(
                exercisesForDay(list, row.weekNumber, row.dayNumber),
                logs,
                row,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _body(
    List<Exercise> exercises,
    List<SetLog> logs,
    WorkoutSession session,
  ) {
    final locale = Localizations.localeOf(context);
    final l10n = context.l10n;
    final progress = WorkoutProgress(exercises: exercises, logs: logs);
    final current = progress.currentExercise;

    if (current == null) {
      // The day is done. The summary is shown before finishing so the student
      // sees what they did; finishing writes the end time on the way out.
      //
      // Only this day's movements are counted — the summary describes one
      // session's work, not the whole week's.
      return WorkoutSummaryView(
        summary: WorkoutSummary.from(
          session: session,
          logs: logs,
          exercises: exercises,
        ),
        onDone: () async {
          await _finish();
          if (mounted) Navigator.of(context).pop();
        },
      );
    }

    // Seed the load fields once per movement — see `_seededForExercise`.
    _seedFrom(current);

    return Column(
      children: [
        if (_resting)
          RestTimerView(
            total: kDefaultRest,
            onFinished: () => setState(() => _resting = false),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.pagePadding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The movement name dominates: this screen is glanced at from
                // arm's length, between sets.
                Text(
                  current.name,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.setOf(
                    localizeNumber(locale, progress.currentSetNumber),
                    localizeNumber(locale, current.sets),
                  ),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                // A bare bar would not say how far along the workout is, so
                // the fraction is always shown as text beside it. RTL makes it
                // fill from the right without any extra work.
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  child: LinearProgressIndicator(
                    value: progress.totalSets == 0
                        ? 0
                        : progress.completedSets / progress.totalSets,
                    minHeight: 8,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.setsProgress(
                    localizeNumber(locale, progress.completedSets),
                    localizeNumber(locale, progress.totalSets),
                  ),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                // The attempt, not the prescription: what they actually
                // lifted and actually managed. Filled from the plan for set 1
                // and carried across the rest of the movement.
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _weight,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          labelText: l10n.weightLabel,
                          prefixIcon: const Icon(Icons.fitness_center),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _reps,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          labelText: l10n.repsLabel,
                          prefixIcon: const Icon(Icons.repeat),
                        ),
                      ),
                    ),
                  ],
                ),
                _lastPerformed(current, l10n, locale),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () =>
                      _logSet(current.id, progress.currentSetNumber),
                  icon: const Icon(Icons.check),
                  label: Text(l10n.completeSet),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
