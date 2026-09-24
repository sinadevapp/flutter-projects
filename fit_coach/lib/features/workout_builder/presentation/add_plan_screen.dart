import 'package:fit_coach/app/navigate.dart';
import 'package:drift/drift.dart' show Value;
import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:fit_coach/core/l10n/category_label.dart';
import 'package:fit_coach/core/l10n/l10n_extension.dart';
import 'package:fit_coach/core/utils/date_format.dart';
import 'package:fit_coach/core/nutrition/target_providers.dart';
import 'package:fit_coach/core/nutrition/nutrition_target.dart';
import 'package:fit_coach/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One editable movement row.
///
/// Nothing is written until the coach presses save: the draft lives here so
/// adding a week and backing one out costs nothing.
class _ExerciseDraft {
  _ExerciseDraft({ExerciseCategory? category})
    : category = category ?? ExerciseCategory.compound;

  final name = TextEditingController();
  final sets = TextEditingController();
  final reps = TextEditingController();
  ExerciseCategory category;

  /// A new row with the same contents.
  ///
  /// Copying the *movement*, not just its category: "add week 2" means
  /// "week 2 is week 1 again, with the numbers changed", and a copy that
  /// arrives blank would have the coach retype the whole program.
  _ExerciseDraft copy() {
    final clone = _ExerciseDraft()..category = category;
    clone.name.text = name.text;
    clone.sets.text = sets.text;
    clone.reps.text = reps.text;
    return clone;
  }

  void dispose() {
    name.dispose();
    sets.dispose();
    reps.dispose();
  }
}

/// One training day: movements in the order they will be performed.
///
/// Carries a name and a rest flag as well, because both belong to the *day*
/// rather than to its movements — a rest day's movements are none.
class _DayDraft {
  _DayDraft({
    this.title,
    this.isRest = false,
    List<_ExerciseDraft>? exercises,
  }) : exercises = exercises ?? [_ExerciseDraft()];

  /// The coach's own name for the day; null until they give it one, in which
  /// case the screen falls back to `l10n.dayLabel(n)`.
  String? title;

  /// Planned rest: nothing to perform, and nothing to ask the coach for.
  bool isRest;

  final List<_ExerciseDraft> exercises;

  /// A new day with the same name, rest flag and movements.
  ///
  /// Copying all three is what makes "add week" a real copy: a coach who
  /// labelled week 1's days should not label week 2 again, and a rest day
  /// should still be a rest day in week 3.
  _DayDraft copy() => _DayDraft(
        title: title,
        isRest: isRest,
        exercises: [for (final e in exercises) e.copy()],
      );

  void dispose() {
    for (final e in exercises) {
      e.dispose();
    }
  }
}

/// One week of the program.
class _WeekDraft {
  final days = <_DayDraft>[_DayDraft()];

  void dispose() {
    for (final d in days) {
      d.dispose();
    }
  }
}

/// Coach form: write a program — weeks, days, and categorized movements — for
/// one student.
///
/// Everything is optional except the title and at least one named movement.
/// The nutrition link points at the student's own profile rather than storing
/// a second copy of the numbers here: one place owns those figures.
class AddPlanScreen extends ConsumerStatefulWidget {
  const AddPlanScreen({super.key, required this.student});

  final User student;

  @override
  ConsumerState<AddPlanScreen> createState() => _AddPlanScreenState();
}

class _AddPlanScreenState extends ConsumerState<AddPlanScreen> {
  final _title = TextEditingController();
  final _duration = TextEditingController();
  final _scroll = ScrollController();
  final List<_WeekDraft> _weeks = [_WeekDraft()];
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _duration.dispose();
    _scroll.dispose();
    for (final week in _weeks) {
      week.dispose();
    }
    super.dispose();
  }

  int get _nextWeekNumber => _weeks.length + 1;

  /// Copies the previous week into a new one.
  ///
  /// This is how real programs get written — one template, then small edits
  /// per week — so it is the button that matters more than an empty week.
  void _addWeekCopiedFromPrevious() {
    if (_weeks.isEmpty) return;
    final clone = _WeekDraft();
    clone.days.clear();
    // `copy()` brings the name, the rest flag and the movements — a week the
    // coach already laid out, not an empty shell with the right shape.
    for (final day in _weeks.last.days) {
      clone.days.add(day.copy());
    }
    setState(() => _weeks.add(clone));
  }

  void _addDay(int weekIndex) {
    setState(() => _weeks[weekIndex].days.add(_DayDraft()));
  }

  Future<void> _renameDay(int weekIndex, int dayIndex) async {
    final day = _weeks[weekIndex].days[dayIndex];
    // The dialog owns its controller: disposing one from here runs while the
    // dialog is still animating out, and the field then reads a disposed
    // controller.
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _DayNameDialog(initial: day.title),
    );
    if (name == null || !mounted) return;

    setState(() => day.title = name.trim().isEmpty ? null : name.trim());
  }

  void _toggleRest(int weekIndex, int dayIndex) {
    setState(() {
      final day = _weeks[weekIndex].days[dayIndex];
      day.isRest = !day.isRest;
      // Rest means nothing to perform, so asking for movements alongside it
      // would be contradictory. The rows are hidden rather than discarded, so
      // un-toggling brings back what was written.
    });
  }

  /// Offers this row's category from the library and fills the name with it.
  ///
  /// A list rather than an autocomplete so the field stays the single source
  /// of truth: `_save` reads `draft.name`, and a widget with its own internal
  /// controller would write there while the draft read here — two places for
  /// one name to disagree.
  Future<void> _pickMovement(_ExerciseDraft draft) async {
    final db = ref.read(appDatabaseProvider);
    final entries = await db.libraryFor(draft.category);
    if (!mounted) return;

    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: 360,
          child: entries.isEmpty
              ? Center(child: Text(context.l10n.noLibraryForCategory))
              : ListView.separated(
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (sheetContext, i) => ListTile(
                    title: Text(entries[i].name),
                    // The category matches the row's, so picking one also
                    // confirms the tag rather than contradicting it.
                    trailing: Text(
                      categoryLabel(context.l10n, entries[i].category),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                    onTap: () => Navigator.of(sheetContext).pop(entries[i].name),
                  ),
                ),
        ),
      ),
    );
    if (picked == null || !mounted) return;

    setState(() => draft.name.text = picked);
  }

  /// A day's heading: its name, tappable to change, and a rest switch.
  Widget _dayHeader(
    AppLocalizations l10n,
    ThemeData theme, {
    required String title,
    required bool isRest,
    required VoidCallback onRename,
    required VoidCallback onToggleRest,
  }) =>
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onRename,
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onToggleRest,
              icon: Icon(
                isRest ? Icons.nightlight_round : Icons.nights_stay_outlined,
                size: 18,
              ),
              label: Text(l10n.restDay),
            ),
          ],
        ),
      );

  Future<void> _save() async {
    final l10n = context.l10n;
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = l10n.planTitleRequired);
      // The message sits under the title field, which is now far above a
      // coach who just pressed save at the bottom of a long form — without
      // this they would see nothing happen at all.
      if (_scroll.hasClients) _scroll.jumpTo(0);
      return;
    }

    final duration = int.tryParse(_duration.text.trim());

    setState(() {
      _error = null;
      _saving = true;
    });

    final db = ref.read(appDatabaseProvider);
    final planId = await db.insertWorkoutPlan(
      WorkoutPlansCompanion.insert(
        studentId: widget.student.id,
        title: title,
        durationWeeks: Value(duration),
      ),
    );

    for (var w = 0; w < _weeks.length; w++) {
      final week = _weeks[w];
      for (var d = 0; d < week.days.length; d++) {
        final day = week.days[d];
        // Position restarts inside each day — it orders movements *within*
        // the day, not across the program.
        var position = 0;
        for (final movement in day.exercises) {
          final name = movement.name.text.trim();
          if (name.isEmpty) continue;
          await db.insertExercise(
            ExercisesCompanion.insert(
              planId: planId,
              weekNumber: Value(w + 1),
              dayNumber: Value(d + 1),
              name: name,
              sets: int.tryParse(movement.sets.text.trim()) ?? 0,
              reps: int.tryParse(movement.reps.text.trim()) ?? 0,
              category: Value(movement.category),
              position: Value(position++),
            ),
          );
        }

        // Persist the day itself, but only if the coach made it something:
        // named it, marked rest, or gave it work. An untouched day is not in
        // the program at all — which is how it behaved before days had rows,
        // and inventing an empty one would clutter the student's view.
        if (day.title != null || day.isRest || position > 0) {
          if (day.title != null) {
            await db.setDayTitle(
              planId,
              week: w + 1,
              day: d + 1,
              title: day.title,
            );
          }
          if (day.isRest) {
            await db.setDayRest(
              planId,
              week: w + 1,
              day: d + 1,
              isRest: true,
            );
          }
        }
      }
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final targets = ref.watch(nutritionTargetsProvider(widget.student.id));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.planForStudent(widget.student.name))),
      body: ListView(
        controller: _scroll,
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            decoration: InputDecoration(
              labelText: l10n.planTitleLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _duration,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n.durationWeeksLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 24),
          Text(l10n.nutritionForThisPlan, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          _nutritionTile(l10n, locale, targets),
          const SizedBox(height: 24),

          for (var w = 0; w < _weeks.length; w++) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.weekLabel(localizeNumber(locale, w + 1)),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _addDay(w),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.addDay),
                ),
              ],
            ),
            for (var d = 0; d < _weeks[w].days.length; d++) ...[
              _dayHeader(
                l10n,
                theme,
                title: _weeks[w].days[d].title ??
                    l10n.dayLabel(localizeNumber(locale, d + 1)),
                isRest: _weeks[w].days[d].isRest,
                onRename: () => _renameDay(w, d),
                onToggleRest: () => _toggleRest(w, d),
              ),
              if (_weeks[w].days[d].isRest)
                // A rest day has nothing to perform. Showing movement rows
                // under it would ask the coach to write a day they just said
                // was off.
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: Text(
                    l10n.restDayHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else ...[
                for (final movement in _weeks[w].days[d].exercises)
                  _exerciseRow(movement),
                OutlinedButton.icon(
                  onPressed: () => setState(
                    () => _weeks[w].days[d].exercises.add(_ExerciseDraft()),
                  ),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.addMovement),
                ),
              ],
            ],
            const SizedBox(height: 16),
          ],

          OutlinedButton.icon(
            onPressed: _addWeekCopiedFromPrevious,
            icon: const Icon(Icons.copy),
            label: Text(
              l10n.addWeek(localizeNumber(locale, _nextWeekNumber.toString())),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  /// The student's daily targets, or a prompt to set them.
  ///
  /// Read-through to the profile the student already owns — this screen does
  /// not keep a second copy of the numbers.
  Widget _nutritionTile(
    AppLocalizations l10n,
    Locale locale,
    NutritionTarget? targets,
  ) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.restaurant),
        title: Text(targets == null ? l10n.noProfileYet : l10n.setProfile),
        subtitle: targets == null
            ? null
            : Text(
                '${l10n.dailyProtein}: '
                '${l10n.gramUnit(localizeNumber(locale, targets.proteinG.round()))}'
                '  ·  '
                '${l10n.dailyCalories}: '
                '${l10n.kcalUnit(localizeNumber(locale, targets.calories.round()))}',
              ),
        trailing: const Icon(Icons.chevron_left),
        onTap: () => context.openCoachNutrition(widget.student),
      ),
    );
  }

  Widget _exerciseRow(_ExerciseDraft draft) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: draft.name,
                  decoration: InputDecoration(
                    labelText: l10n.movementNameLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: l10n.pickFromLibrary,
                onPressed: () => _pickMovement(draft),
                icon: const Icon(Icons.list_alt),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: draft.sets,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.setsLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: draft.reps,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.repsLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<ExerciseCategory>(
            value: draft.category,
            decoration: InputDecoration(
              labelText: l10n.categoryLabel,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final category in ExerciseCategory.values)
                DropdownMenuItem(
                  value: category,
                  child: Text(
                    categoryLabel(l10n, category),
                    // Keeps the label short enough for three columns beside
                    // it without ellipsising.
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => draft.category = value);
            },
          ),
        ],
      ),
    );
  }
}

/// Asks for a day's name.
///
/// Its own [State] so the [TextEditingController] is disposed with the dialog
/// — disposing from the caller races the closing animation.
class _DayNameDialog extends StatefulWidget {
  const _DayNameDialog({this.initial});

  final String? initial;

  @override
  State<_DayNameDialog> createState() => _DayNameDialogState();
}

class _DayNameDialogState extends State<_DayNameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AlertDialog(
      title: Text(l10n.dayNameLabel),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(labelText: l10n.dayNameHint),
        onSubmitted: (_) => _submit(),
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
