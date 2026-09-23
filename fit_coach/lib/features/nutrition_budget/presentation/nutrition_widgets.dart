import 'package:fit_coach/core/l10n/l10n_extension.dart';
import 'package:fit_coach/core/utils/date_format.dart';
import 'package:fit_coach/core/utils/money_format.dart';
import 'package:fit_coach/features/nutrition_budget/domain/food_cost.dart';
import 'package:fit_coach/features/nutrition_budget/domain/nutrition_target.dart';
import 'package:fit_coach/features/nutrition_budget/domain/protein_plan.dart';
import 'package:flutter/material.dart';

/// Shared pieces of the nutrition screens.
///
/// The coach and the student see the same numbers — only the buttons differ —
/// so the rendering lives here and neither feature has to import the other's
/// presentation code.

/// One labelled figure.
class TargetTile extends StatelessWidget {
  const TargetTile({super.key, required this.label, required this.value});

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

/// The daily energy and macro figures, in the language's own digits.
class TargetsSection extends StatelessWidget {
  const TargetsSection({super.key, required this.targets});

  final NutritionTarget targets;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);

    String digits(num value) => localizeNumber(locale, value.round());

    return Column(
      children: [
        TargetTile(label: l10n.bmr, value: l10n.kcalUnit(digits(targets.bmr))),
        TargetTile(label: l10n.tdee, value: l10n.kcalUnit(digits(targets.tdee))),
        TargetTile(
          label: l10n.dailyCalories,
          value: l10n.kcalUnit(digits(targets.calories)),
        ),
        const Divider(),
        TargetTile(
          label: l10n.dailyProtein,
          value: l10n.gramUnit(digits(targets.proteinG)),
        ),
        TargetTile(
          label: l10n.dailyCarbs,
          value: l10n.gramUnit(digits(targets.carbsG)),
        ),
        TargetTile(
          label: l10n.dailyFat,
          value: l10n.gramUnit(digits(targets.fatG)),
        ),
      ],
    );
  }
}

/// The cheapest ways to reach the protein target, or a prompt for the missing
/// prices.
///
/// No priced food means no plan: a costing feature that quietly shows nothing
/// would look broken rather than ask for the input it needs.
class ProteinPlanSection extends StatelessWidget {
  const ProteinPlanSection({
    super.key,
    required this.targetG,
    required this.foods,
  });

  final double targetG;
  final List<FoodItem> foods;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);

    final options = proteinPlan(targetG: targetG, foods: foods);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.proteinPlanTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (options.isEmpty)
          Text(l10n.proteinPlanEmpty)
        else
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
              // Money goes through the money formatter, not the plain number
              // one: these are millions of toman, and "۲۵۰۰۰۰۰" is unreadable
              // at a glance.
              trailing: Text(
                formatToman(
                  locale,
                  l10n.toman,
                  l10n.scaleThousand,
                  l10n.scaleMillion,
                  option.cost,
                ),
              ),
            ),
      ],
    );
  }
}
