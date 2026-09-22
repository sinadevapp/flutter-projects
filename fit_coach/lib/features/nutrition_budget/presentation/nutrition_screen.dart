import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:fit_coach/core/l10n/l10n_extension.dart';
import 'package:fit_coach/core/utils/date_format.dart';
import 'package:fit_coach/features/nutrition_budget/application/food_providers.dart';
import 'package:fit_coach/features/nutrition_budget/application/target_providers.dart';
import 'package:fit_coach/features/nutrition_budget/domain/food_cost.dart';
import 'package:fit_coach/features/nutrition_budget/domain/nutrition_target.dart';
import 'package:fit_coach/features/nutrition_budget/domain/protein_plan.dart';
import 'package:fit_coach/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The coach's view of one student's nutrition: their profile, the daily
/// targets it implies, and the cheapest ways to hit the protein target.
///
/// Until a food price is entered the costing cannot be done, so the plan says
/// so rather than showing an empty or zero-cost list.
class NutritionScreen extends ConsumerWidget {
  const NutritionScreen({super.key, required this.student});

  final User student;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(nutritionProfileProvider(student.id));
    final targets = ref.watch(nutritionTargetsProvider(student.id));

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.studentNutrition(student.name))),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (row) => row == null
            ? _EmptyState(student: student)
            : _TargetsView(student: student, targets: targets!),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.student});

  final User student;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(l10n.noProfileYet),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => _openProfileSheet(context, student),
            child: Text(l10n.setProfile),
          ),
        ],
      ),
    );
  }
}

class _TargetsView extends ConsumerWidget {
  const _TargetsView({required this.student, required this.targets});

  final User student;
  final NutritionTarget targets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final foods = ref.watch(rankedFoodsProvider).value ?? const [];

    String digits(num value) => localizeNumber(locale, value.round());

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _TargetTile(label: l10n.bmr, value: l10n.kcalUnit(digits(targets.bmr))),
        _TargetTile(label: l10n.tdee, value: l10n.kcalUnit(digits(targets.tdee))),
        _TargetTile(
          label: l10n.dailyCalories,
          value: l10n.kcalUnit(digits(targets.calories)),
        ),
        const Divider(),
        _TargetTile(
          label: l10n.dailyProtein,
          value: l10n.gramUnit(digits(targets.proteinG)),
        ),
        _TargetTile(
          label: l10n.dailyCarbs,
          value: l10n.gramUnit(digits(targets.carbsG)),
        ),
        _TargetTile(
          label: l10n.dailyFat,
          value: l10n.gramUnit(digits(targets.fatG)),
        ),
        const SizedBox(height: 24),
        Text(
          l10n.proteinPlanTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        _ProteinPlan(targetG: targets.proteinG, foods: foods),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: () => _openProfileSheet(context, student),
          child: Text(l10n.editProfile),
        ),
      ],
    );
  }
}

class _ProteinPlan extends StatelessWidget {
  const _ProteinPlan({required this.targetG, required this.foods});

  final double targetG;
  final List<FoodItem> foods;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);

    final options = proteinPlan(targetG: targetG, foods: foods);

    // No priced food means no plan: a costing feature that quietly shows
    // nothing would look broken rather than ask for the missing input.
    if (options.isEmpty) {
      return Text(l10n.proteinPlanEmpty);
    }

    return Column(
      children: [
        for (final option in options)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              l10n.planOption(
                localizeNumber(locale, option.grams.round()),
                option.food.name,
              ),
            ),
            subtitle: Text(
              l10n.planKcal(localizeNumber(locale, option.kcal.round())),
            ),
            trailing: Text(
              l10n.planCost(localizeNumber(locale, option.cost.round())),
            ),
          ),
      ],
    );
  }
}

class _TargetTile extends StatelessWidget {
  const _TargetTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        trailing: Text(
          value,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
}

/// Opens the profile form as a modal sheet.
Future<void> _openProfileSheet(BuildContext context, User student) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ProfileSheet(student: student),
  );
}

/// Collects the inputs a target is estimated from.
///
/// Values are parsed on submit rather than on every keystroke: a field being
/// briefly invalid while it is typed is normal, and rejecting mid-typing would
/// fight the user.
class _ProfileSheet extends ConsumerStatefulWidget {
  const _ProfileSheet({required this.student});

  final User student;

  @override
  ConsumerState<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends ConsumerState<_ProfileSheet> {
  final _age = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();

  Sex _sex = Sex.male;
  ActivityLevel _activity = ActivityLevel.moderate;
  Goal _goal = Goal.maintain;

  @override
  void dispose() {
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final age = int.tryParse(_age.text.trim());
    final height = double.tryParse(_height.text.trim());
    final weight = double.tryParse(_weight.text.trim());

    if (age == null || height == null || weight == null || age <= 0 ||
        height <= 0 || weight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.invalidNumber)),
      );
      return;
    }

    await saveProfile(
      ref.read(appDatabaseProvider),
      widget.student.id,
      NutritionProfile(
        sex: _sex,
        age: age,
        heightCm: height,
        weightKg: weight,
        activity: _activity,
        goal: _goal,
      ),
    );

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _NumberField(key: const Key('field_age'), controller: _age, label: l10n.ageLabel),
            _NumberField(
              key: const Key('field_height'),
              controller: _height,
              label: l10n.heightLabel,
              allowDecimal: true,
            ),
            _NumberField(
              key: const Key('field_weight'),
              controller: _weight,
              label: l10n.weightLabel,
              allowDecimal: true,
            ),
            const SizedBox(height: 8),
            Text(l10n.sexLabel),
            SegmentedButton<Sex>(
              segments: [
                ButtonSegment(value: Sex.male, label: Text(l10n.male)),
                ButtonSegment(value: Sex.female, label: Text(l10n.female)),
              ],
              selected: {_sex},
              onSelectionChanged: (s) => setState(() => _sex = s.first),
            ),
            const SizedBox(height: 12),
            Text(l10n.activityLabel),
            DropdownButton<ActivityLevel>(
              value: _activity,
              isExpanded: true,
              onChanged: (v) => setState(() => _activity = v!),
              items: [
                for (final level in ActivityLevel.values)
                  DropdownMenuItem(
                    value: level,
                    child: Text(_activityLabel(l10n, level)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(l10n.goalLabel),
            SegmentedButton<Goal>(
              segments: [
                ButtonSegment(value: Goal.lose, label: Text(l10n.goalLose)),
                ButtonSegment(
                  value: Goal.maintain,
                  label: Text(l10n.goalMaintain),
                ),
                ButtonSegment(value: Goal.gain, label: Text(l10n.goalGain)),
              ],
              selected: {_goal},
              onSelectionChanged: (s) => setState(() => _goal = s.first),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: _submit, child: Text(l10n.save)),
          ],
        ),
      ),
    );
  }
}

String _activityLabel(AppLocalizations l10n, ActivityLevel level) =>
    switch (level) {
      ActivityLevel.sedentary => l10n.activitySedentary,
      ActivityLevel.light => l10n.activityLight,
      ActivityLevel.moderate => l10n.activityModerate,
      ActivityLevel.active => l10n.activityActive,
      ActivityLevel.veryActive => l10n.activityVeryActive,
    };

class _NumberField extends StatelessWidget {
  const _NumberField({
    super.key,
    required this.controller,
    required this.label,
    this.allowDecimal = false,
  });

  final TextEditingController controller;
  final String label;
  final bool allowDecimal;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: TextField(
          controller: controller,
          keyboardType:
              TextInputType.numberWithOptions(decimal: allowDecimal),
          inputFormatters: [
            if (allowDecimal)
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
            else
              FilteringTextInputFormatter.digitsOnly,
          ],
          decoration: InputDecoration(labelText: label),
        ),
      );
}
