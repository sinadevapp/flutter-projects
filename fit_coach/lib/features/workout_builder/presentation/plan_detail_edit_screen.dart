import 'package:fit_coach/core/widgets/states.dart';
import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:fit_coach/core/database/plan_providers.dart';
import 'package:fit_coach/core/l10n/category_label.dart';
import 'package:fit_coach/core/l10n/l10n_extension.dart';
import 'package:fit_coach/core/schedule/exercise_schedule.dart';
import 'package:fit_coach/core/utils/date_format.dart';
import 'package:fit_coach/features/workout_active/presentation/active_workout_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The coach's editing view of one plan: rename it, correct or remove its
/// movements, and start it the way the student would.
///
/// Every edit goes straight to the database — there is no draft state to lose,
/// which matches how the rest of the app already behaves.
class PlanDetailEditScreen extends ConsumerWidget {
  const PlanDetailEditScreen({super.key, required this.plan});

  final WorkoutPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercises = ref.watch(planExercisesProvider(plan.id));
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(plan.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.drive_file_rename_outline),
            tooltip: l10n.renamePlan,
            onPressed: () => _rename(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.deletePlan,
            onPressed: () => _deletePlan(context, ref),
          ),
        ],
      ),
      body: exercises.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const ErrorState(),
        data: (list) => list.isEmpty
            ? Center(child: Text(l10n.planHasNoMovements))
            : _grouped(context, ref, list),
      ),
      floatingActionButton: list(context, ref, exercises.value ?? const []),
    );
  }

  /// Movements grouped under their week and day, each showing its category.
  ///
  /// Grouped the same way the student's view reads them, so the coach edits
  /// in the order the program actually runs.
  Widget _grouped(BuildContext context, WidgetRef ref, List<Exercise> list) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final items = <Widget>[];
    int? lastWeek;

    for (final (week, day) in daysOf(list)) {
      if (lastWeek != week) {
        lastWeek = week;
        items.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              l10n.weekLabel(localizeNumber(locale, week)),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        );
      }
      items.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            l10n.dayLabel(localizeNumber(locale, day)),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
      for (final exercise in exercisesForDay(list, week, day)) {
        items.add(
          ListTile(
            title: Text(exercise.name),
            // The category is what tells a coach scanning the week which body
            // part a movement belongs to, without reading every name.
            subtitle: Text(
              categoryLabel(l10n, exercise.category),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            trailing: Text(
              l10n.setsXReps(
                localizeNumber(locale, exercise.sets),
                localizeNumber(locale, exercise.reps),
              ),
            ),
            onTap: () => _editMovement(context, ref, exercise),
            onLongPress: () => _deleteMovement(context, ref, exercise),
          ),
        );
      }
    }

    return ListView(children: items);
  }

  /// The start button, disabled until the plan has something to perform.
  Widget? list(BuildContext context, WidgetRef ref, List<Exercise> exercises) {
    if (exercises.isEmpty) return null;
    return FloatingActionButton.extended(
      onPressed: () => _start(context, ref),
      label: Text(context.l10n.startWorkout),
      icon: const Icon(Icons.play_arrow),
    );
  }

  /// Opens the program from the top — week 1 day 1 — as it did before weeks
  /// existed.
  ///
  /// The coach does not train here, so this is a review of how the program
  /// opens. The student picks the day to train from their own screen.
  Future<void> _start(BuildContext context, WidgetRef ref) async {
    final sessionId = await ref
        .read(appDatabaseProvider)
        .startWorkoutSession(
          planId: plan.id,
          studentId: plan.studentId,
          weekNumber: 1,
          dayNumber: 1,
        );
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActiveWorkoutScreen(sessionId: sessionId, plan: plan),
      ),
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    // The dialog owns its controller: disposing it here would run while the
    // dialog is still animating out, and the field would read a disposed one.
    final title = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initialTitle: plan.title),
    );

    if (title == null) return;
    if (title.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.planTitleRequired)));
      }
      return;
    }

    await ref.read(appDatabaseProvider).renamePlan(plan.id, title);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.planRenamed)));
    }
  }

  Future<void> _deletePlan(BuildContext context, WidgetRef ref) async {
    // Deleting a plan takes its logged workouts with it, so this asks first —
    // it is the one edit in the app that cannot be undone.
    final confirmed = await _confirm(
      context,
      title: context.l10n.deletePlan,
      message: context.l10n.deletePlanConfirm(plan.title),
    );
    if (!confirmed || !context.mounted) return;

    await ref.read(appDatabaseProvider).deletePlan(plan.id);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.planDeleted)));
      Navigator.of(context).pop();
    }
  }

  Future<void> _editMovement(
    BuildContext context,
    WidgetRef ref,
    Exercise exercise,
  ) async {
    final result = await showDialog<(String, int, int)>(
      context: context,
      builder: (_) => _MovementDialog(exercise: exercise),
    );
    if (result == null || !context.mounted) return;

    final (name, sets, reps) = result;
    await ref
        .read(appDatabaseProvider)
        .updateExercise(exercise.id, name: name, sets: sets, reps: reps);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.movementUpdated)));
    }
  }

  Future<void> _deleteMovement(
    BuildContext context,
    WidgetRef ref,
    Exercise exercise,
  ) async {
    final confirmed = await _confirm(
      context,
      title: context.l10n.deleteMovement,
      message: context.l10n.deleteMovementConfirm(exercise.name),
    );
    if (!confirmed || !context.mounted) return;

    await ref.read(appDatabaseProvider).deleteExercise(exercise.id);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.movementDeleted)));
    }
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final answer = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    return answer ?? false;
  }
}

/// Asks for a new plan title.
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initialTitle});

  final String initialTitle;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialTitle,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AlertDialog(
      title: Text(l10n.renamePlan),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(labelText: l10n.planTitleLabel),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

/// Edits one movement's name, sets and reps.
class _MovementDialog extends StatefulWidget {
  const _MovementDialog({required this.exercise});

  final Exercise exercise;

  @override
  State<_MovementDialog> createState() => _MovementDialogState();
}

class _MovementDialogState extends State<_MovementDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.exercise.name,
  );
  late final TextEditingController _sets = TextEditingController(
    text: widget.exercise.sets.toString(),
  );
  late final TextEditingController _reps = TextEditingController(
    text: widget.exercise.reps.toString(),
  );

  @override
  void dispose() {
    _name.dispose();
    _sets.dispose();
    _reps.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    final sets = int.tryParse(_sets.text.trim());
    final reps = int.tryParse(_reps.text.trim());

    // Leave the dialog open on nonsense rather than storing it.
    if (name.isEmpty ||
        sets == null ||
        reps == null ||
        sets <= 0 ||
        reps <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.invalidNumber)));
      return;
    }
    Navigator.of(context).pop((name, sets, reps));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AlertDialog(
      title: Text(l10n.editMovement),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            decoration: InputDecoration(labelText: l10n.movementNameLabel),
          ),
          TextField(
            controller: _sets,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: l10n.setsLabel),
          ),
          TextField(
            controller: _reps,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: l10n.repsLabel),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.save)),
      ],
    );
  }
}
