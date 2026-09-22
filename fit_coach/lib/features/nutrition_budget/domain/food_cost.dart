/// One food, with its macros per 100 g and — optionally — what it costs.
///
/// Macros come from the nutrition label and do not change; the price is the
/// coach's own local market reading, which is why it is nullable: a food with
/// no price yet is a normal state, not an error.
class FoodItem {
  const FoodItem({
    this.id,
    required this.name,
    required this.proteinPer100g,
    required this.kcalPer100g,
    this.pricePerKg,
  });

  /// Database row id, when this came from storage. Null for a value built in
  /// memory (a preview, a test fixture).
  final int? id;

  final String name;
  final double proteinPer100g;
  final double kcalPer100g;

  /// Toman per kilogram, or null until the coach enters it.
  ///
  /// Zero is a *price* — a genuine freebie — and is deliberately distinct from
  /// null.
  final int? pricePerKg;

  bool get isPriced => pricePerKg != null;

  /// Toman per gram of protein — the headline comparison.
  ///
  /// A kilo holds `proteinPer100g * 10` grams of protein, so this is the price
  /// divided by that. Null when there is no price to divide, or when the food
  /// carries no protein at all.
  double? get costPerGramProtein {
    final price = pricePerKg;
    if (price == null || proteinPer100g <= 0) return null;
    return price / (proteinPer100g * 10);
  }

  /// How many calories ride along with each gram of protein.
  ///
  /// Separates lean sources from fatty ones: two foods can cost the same per
  /// gram of protein and still be very different to eat. Independent of price.
  double? get kcalPerGramProtein {
    if (proteinPer100g <= 0) return null;
    return kcalPer100g / proteinPer100g;
  }

  /// How much of this food is needed to hit [targetG] grams of protein.
  ///
  /// Also independent of price — useful while the coach is still gathering
  /// prices.
  double? gramsForProtein(double targetG) {
    if (proteinPer100g <= 0) return null;
    return targetG / (proteinPer100g / 100);
  }

  /// What that amount costs, in toman. Null until the food is priced.
  double? costForProtein(double targetG) {
    final grams = gramsForProtein(targetG);
    final price = pricePerKg;
    if (grams == null || price == null) return null;
    return grams * price / 1000;
  }
}

/// Orders foods by how cheap their protein is, cheapest first.
///
/// Foods that cannot be compared — no price, or no protein — sink to the
/// bottom rather than being treated as free. Ranking uses a stable sort, so
/// foods that tie, and the unranked tail, keep the order they arrived in.
List<FoodItem> rankByProteinCost(List<FoodItem> foods) {
  final indexed = foods.indexed.toList()
    ..sort((a, b) {
      final costA = a.$2.costPerGramProtein;
      final costB = b.$2.costPerGramProtein;
      if (costA == null || costB == null) {
        // Both unranked, or the left one is: fall back to input order.
        if (costA == null && costB == null) return a.$1.compareTo(b.$1);
        return costA == null ? 1 : -1;
      }
      final byCost = costA.compareTo(costB);
      return byCost != 0 ? byCost : a.$1.compareTo(b.$1);
    });
  return indexed.map((e) => e.$2).toList();
}
