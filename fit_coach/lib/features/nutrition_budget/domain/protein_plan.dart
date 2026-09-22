import 'food_cost.dart';

/// How many options a coach is shown. Enough to choose between, few enough to
/// read at a glance.
const int kMaxPlanOptions = 5;

/// One way to reach a protein target with a single food.
class ProteinOption {
  const ProteinOption({
    required this.food,
    required this.grams,
    required this.cost,
  });

  final FoodItem food;

  /// How much of [food] the student would eat, in grams.
  final double grams;

  /// What that costs, in toman.
  final double cost;

  /// Toman per gram of protein — the same figure as the food list, carried
  /// here so an option ranks the same way it was chosen.
  double get costPerGramProtein => cost / (grams * food.proteinPer100g / 100);

  /// Calories that come along with the protein.
  double get kcal => grams * food.kcalPer100g / 100;
}

/// The cheapest ways to hit [targetG] grams of protein from [foods].
///
/// Cheapest *per gram of protein* comes first, which is what makes the list
/// useful: it answers "what should this student buy?" rather than "what costs
/// least per kilo?". Foods without a price are skipped — they cannot be
/// costed, and a plan that quietly ignores money would defeat the feature.
///
/// At most [kMaxPlanOptions] are returned.
List<ProteinOption> proteinPlan({
  required double targetG,
  required List<FoodItem> foods,
}) {
  if (targetG <= 0) return const [];

  final options = <ProteinOption>[];
  for (final food in rankByProteinCost(foods)) {
    if (!food.isPriced) continue;
    final grams = food.gramsForProtein(targetG);
    final cost = food.costForProtein(targetG);
    if (grams == null || cost == null) continue;
    options.add(ProteinOption(food: food, grams: grams, cost: cost));
    if (options.length == kMaxPlanOptions) break;
  }
  return options;
}
