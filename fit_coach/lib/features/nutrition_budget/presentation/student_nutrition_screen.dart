import 'package:fit_coach/core/l10n/l10n_extension.dart';
import 'package:fit_coach/features/nutrition_budget/application/food_providers.dart';
import 'package:fit_coach/core/nutrition/target_providers.dart';
import 'package:fit_coach/features/nutrition_budget/domain/food_cost.dart';
import 'package:fit_coach/features/nutrition_budget/presentation/nutrition_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the student sees: their daily targets and what to buy to hit them.
///
/// Read-only on purpose. The profile is the coach's input, so there is no edit
/// affordance here — a student changing their own target would silently
/// diverge from the plan their coach wrote.
class StudentNutritionScreen extends ConsumerWidget {
  const StudentNutritionScreen({super.key, required this.studentId});

  final int studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targets = ref.watch(nutritionTargetsProvider(studentId));
    final foods = ref.watch(rankedFoodsProvider).value ?? const <FoodItem>[];

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.nutrition)),
      body: targets == null
          ? Center(child: Text(context.l10n.noStudentNutritionYet))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TargetsSection(targets: targets),
                const SizedBox(height: 24),
                ProteinPlanSection(
                  targetG: targets.proteinG,
                  foods: foods,
                ),
              ],
            ),
    );
  }
}
