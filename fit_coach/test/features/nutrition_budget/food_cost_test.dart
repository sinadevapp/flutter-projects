import 'package:fit_coach/features/nutrition_budget/domain/food_cost.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Prices are entered by the coach from their own local market, so they are
  // optional: a food with macros but no price is still a valid food.
  const lentils = FoodItem(
    name: 'عدس',
    proteinPer100g: 25,
    kcalPer100g: 350,
    pricePerKg: 100000,
  );
  const egg = FoodItem(
    name: 'تخم مرغ',
    proteinPer100g: 13,
    kcalPer100g: 155,
    pricePerKg: 120000,
  );
  const chicken = FoodItem(
    name: 'سینه مرغ',
    proteinPer100g: 31,
    kcalPer100g: 165,
    pricePerKg: 350000,
  );
  const whey = FoodItem(
    name: 'پروتئین وی',
    proteinPer100g: 80,
    kcalPer100g: 400,
    pricePerKg: 2500000,
  );

  test('cost per gram of protein accounts for both price and density', () {
    // 1 kg of egg holds 130 g of protein, so 120000 / 130.
    expect(egg.costPerGramProtein, closeTo(120000 / 130, 0.01));
    expect(chicken.costPerGramProtein, closeTo(350000 / 310, 0.01));
  });

  test('cheaper per kilo does not mean cheaper protein', () {
    // Egg costs a third of chicken per kilo, and is also the cheaper protein.
    expect(egg.pricePerKg, lessThan(chicken.pricePerKg!));
    expect(egg.costPerGramProtein, lessThan(chicken.costPerGramProtein!));

    // A denser food can cost far more per kilo and still win per gram: whey is
    // ~7x chicken by weight, but ~2.8x by protein.
    expect(whey.pricePerKg, greaterThan(chicken.pricePerKg! * 7));
    expect(
      whey.costPerGramProtein! / chicken.costPerGramProtein!,
      closeTo(2.8, 0.05),
    );
  });

  test('kcal per gram of protein exposes lean vs fatty sources', () {
    expect(egg.kcalPerGramProtein, closeTo(155 / 13, 0.01));
    expect(chicken.kcalPerGramProtein, closeTo(165 / 31, 0.01));
    // Chicken is the leaner way to buy protein.
    expect(chicken.kcalPerGramProtein, lessThan(egg.kcalPerGramProtein!));
  });

  test('grams and cost to reach a daily protein target', () {
    // 160 g of protein from egg needs 160 / 0.13 = ~1231 g of egg, which is
    // 1.231 kg at 120000 toman per kilo.
    expect(egg.gramsForProtein(160), closeTo(160 / 0.13, 0.01));
    expect(egg.costForProtein(160), closeTo(160 / 0.13 * 120, 0.01));
  });

  test('a food with no protein is not a protein source', () {
    const oil = FoodItem(
      name: 'روغن',
      proteinPer100g: 0,
      kcalPer100g: 884,
      pricePerKg: 200000,
    );

    expect(oil.costPerGramProtein, isNull);
    expect(oil.kcalPerGramProtein, isNull);
    expect(oil.gramsForProtein(160), isNull);
    expect(oil.costForProtein(160), isNull);
  });

  group('a food the coach has not priced yet', () {
    const unpriced = FoodItem(
      name: 'سینه مرغ',
      proteinPer100g: 31,
      kcalPer100g: 165,
    );

    test('has no cost, but still reports what it costs nothing to know', () {
      expect(unpriced.pricePerKg, isNull);
      expect(unpriced.costPerGramProtein, isNull);
      expect(unpriced.costForProtein(160), isNull);

      // How much you would need to eat does not depend on the price, so this
      // still works — and is useful while the coach is gathering prices.
      expect(unpriced.gramsForProtein(160), closeTo(160 / 0.31, 0.01));
      expect(unpriced.kcalPerGramProtein, closeTo(165 / 31, 0.01));
    });

    test('a free price is still a price, not a missing one', () {
      const freebie = FoodItem(
        name: 'نمونه رایگان',
        proteinPer100g: 10,
        kcalPer100g: 100,
        pricePerKg: 0,
      );

      expect(freebie.costPerGramProtein, 0);
      expect(freebie.costForProtein(160), 0);
    });
  });

  test('ranking puts the cheapest protein first', () {
    final ranked = rankByProteinCost([whey, egg, chicken, lentils]);

    expect(ranked.map((f) => f.name).toList(), [
      'عدس', // 100000 / 250 = 400
      'تخم مرغ', // 923
      'سینه مرغ', // 1129
      'پروتئین وی', // 3125
    ]);
  });

  test('raising a price re-ranks the list', () {
    expect(rankByProteinCost([whey, egg, chicken, lentils]).last.name,
        'پروتئین وی');

    // The coach edits the chicken price upward. At 1.2M/kg its protein costs
    // more than whey's, so it drops to last place.
    const pricierChicken = FoodItem(
      name: 'سینه مرغ',
      proteinPer100g: 31,
      kcalPer100g: 165,
      pricePerKg: 1200000,
    );
    final after = rankByProteinCost([whey, egg, pricierChicken, lentils]);

    expect(after.last.name, 'سینه مرغ');
    expect(after.first.name, 'عدس');
  });

  test('foods that cannot be compared sink to the bottom', () {
    const oil = FoodItem(
      name: 'روغن',
      proteinPer100g: 0,
      kcalPer100g: 884,
      pricePerKg: 200000,
    );
    const unpriced = FoodItem(
      name: 'نخود',
      proteinPer100g: 19,
      kcalPer100g: 364,
    );

    final ranked = rankByProteinCost([oil, unpriced, egg, chicken]);

    // No protein and no price are both "not comparable" — and neither may be
    // mistaken for costing zero.
    expect(ranked.take(2).map((f) => f.name).toList(), ['تخم مرغ', 'سینه مرغ']);
    expect(ranked.skip(2).map((f) => f.name).toSet(), {'روغن', 'نخود'});
  });

  test('untouched foods keep the order they were given in', () {
    const a = FoodItem(name: 'الف', proteinPer100g: 10, kcalPer100g: 100);
    const b = FoodItem(name: 'ب', proteinPer100g: 10, kcalPer100g: 100);
    const c = FoodItem(name: 'پ', proteinPer100g: 10, kcalPer100g: 100);

    expect(
      rankByProteinCost([a, b, c]).map((f) => f.name).toList(),
      ['الف', 'ب', 'پ'],
    );
  });
}
