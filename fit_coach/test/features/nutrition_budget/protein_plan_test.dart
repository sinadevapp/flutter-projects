import 'package:fit_coach/features/nutrition_budget/domain/food_cost.dart';
import 'package:fit_coach/features/nutrition_budget/domain/protein_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const egg = FoodItem(
    name: 'تخم مرغ',
    proteinPer100g: 13,
    kcalPer100g: 155,
    pricePerKg: 322222,
  );
  const chicken = FoodItem(
    name: 'سینه مرغ',
    proteinPer100g: 31,
    kcalPer100g: 165,
    pricePerKg: 650000,
  );
  const lentils = FoodItem(
    name: 'عدس',
    proteinPer100g: 25,
    kcalPer100g: 350,
    pricePerKg: 444444,
  );
  const whey = FoodItem(
    name: 'پروتئین وی',
    proteinPer100g: 80,
    kcalPer100g: 400,
    pricePerKg: 2500000,
  );

  test('a plan is empty when there is no target or no priced food', () {
    expect(proteinPlan(targetG: 0, foods: [egg]), isEmpty);
    expect(proteinPlan(targetG: 160, foods: []), isEmpty);
    // Unpriced foods cannot be costed, so they cannot be planned around.
    expect(
      proteinPlan(
        targetG: 160,
        foods: const [
          FoodItem(name: 'مرغ', proteinPer100g: 31, kcalPer100g: 165),
        ],
      ),
      isEmpty,
    );
  });

  test('a single-food option reports the grams and the cost', () {
    final plan = proteinPlan(targetG: 160, foods: [lentils]);

    expect(plan, hasLength(1));
    final option = plan.single;
    expect(option.food.name, 'عدس');
    // 160 g of protein at 25 g per 100 g needs 640 g of lentils.
    expect(option.grams, closeTo(640, 0.01));
    // 0.64 kg at 444444 toman/kg.
    expect(option.cost, closeTo(640 * 444444 / 1000, 0.01));
    // 444444 / 250 = 1777.8 toman per gram of protein.
    expect(option.costPerGramProtein, closeTo(1777.78, 0.01));
  });

  test('options come cheapest protein first — the whole point', () {
    final plan = proteinPlan(
      targetG: 160,
      foods: [whey, egg, chicken, lentils],
    );

    expect(plan.map((o) => o.food.name).toList(), [
      'عدس', // 1778 toman/g
      'سینه مرغ', // 2097
      'تخم مرغ', // 2479
      'پروتئین وی', // 3125
    ]);
  });

  test('a more expensive food can still be the cheaper plan to reach protein',
      () {
    // Lentils win on cost per gram, so they are the cheapest way to 160 g.
    final plan = proteinPlan(targetG: 160, foods: [lentils, whey]);
    expect(plan.first.food.name, 'عدس');
    expect(plan.first.cost, lessThan(plan.last.cost));
  });

  test('the plan is limited to the top options', () {
    final many = [
      for (var i = 0; i < 20; i++)
        FoodItem(
          name: 'غذا $i',
          proteinPer100g: 10,
          kcalPer100g: 100,
          pricePerKg: 100000 + i * 1000,
        ),
    ];

    // A coach needs a shortlist to choose from, not the whole food list.
    expect(proteinPlan(targetG: 160, foods: many), hasLength(kMaxPlanOptions));
    expect(proteinPlan(targetG: 160, foods: many).first.food.name, 'غذا 0');
  });

  test('fewer priced foods than the limit returns them all', () {
    final plan = proteinPlan(targetG: 160, foods: [egg, chicken]);
    expect(plan, hasLength(2));
  });

  test('targets are scaled honestly, not rounded into nonsense', () {
    // A small target over an expensive food must still cost correctly.
    final plan = proteinPlan(targetG: 50, foods: [whey]);
    expect(plan.single.grams, closeTo(62.5, 0.01));
    expect(plan.single.cost, closeTo(62.5 * 2500000 / 1000, 0.01));
  });
}
