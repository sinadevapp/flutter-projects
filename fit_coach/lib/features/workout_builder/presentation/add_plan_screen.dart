import 'package:drift/drift.dart' show Value;
import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:fit_coach/core/l10n/category_label.dart';
import 'package:fit_coach/core/l10n/l10n_extension.dart';
import 'package:fit_coach/core/utils/date_format.dart';
import 'package:fit_coach/features/nutrition_budget/application/target_providers.dart';
import 'package:fit_coach/features/nutrition_budget/domain/nutrition_target.dart';
import 'package:fit_coach/features/nutrition_budget/presentation/nutrition_screen.dart';
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
class _DayDraft {
  final exercises = <_ExerciseDraft>[_ExerciseDraft()];

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
    final source = _weeks.last;
    final clone = _WeekDraft();
    clone.days.clear();
    for (final day in source.days) {
      final dayClone = _DayDraft();
      dayClone.exercises.clear();
      for (final movement in day.exercises) {
        dayClone.exercises.add(movement.copy());
      }
      clone.days.add(dayClone);
    }
    setState(() => _weeks.add(clone));
  }

  void _addDay(int weekIndex) {
    setState(() => _weeks[weekIndex].days.add(_DayDraft()));
  }

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
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n.dayLabel(localizeNumber(locale, d + 1)),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
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
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => NutritionScreen(student: widget.student),
          ),
        ),
      ),
    );
  }

  Widget _exerciseRow(_ExerciseDraft draft) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Column(
        children: [
          TextField(
            controller: draft.name,
            decoration: InputDecoration(
              labelText: l10n.movementNameLabel,
              border: const OutlineInputBorder(),
            ),
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
