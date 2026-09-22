import 'package:drift/drift.dart' show OrderingTerm;
import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:fit_coach/features/nutrition_budget/domain/food_cost.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A stored [FoodRow] as the pricing domain sees it.
///
/// The two types stay separate on purpose: [FoodRow] is a database row,
/// [FoodItem] is pricing logic that must stay testable without a database.
FoodItem foodToItem(FoodRow row) => FoodItem(
      id: row.id,
      name: row.name,
      proteinPer100g: row.proteinPer100g,
      kcalPer100g: row.kcalPer100g,
      pricePerKg: row.pricePerKg,
    );

/// The stored foods, in insertion order.
///
/// Stable order on purpose: a coach editing prices must not have rows jump
/// around under their finger. Ranking is a separate, derived view.
Stream<List<FoodRow>> _foodRows(AppDatabase db) =>
    (db.select(db.foodItems)..orderBy([(f) => OrderingTerm.asc(f.id)])).watch();

/// Every food, cheapest gram of protein first — re-ranked live as prices
/// change.
///
/// Ranking runs through [rankByProteinCost] rather than SQL so the rules live
/// in exactly one place: the same place the unit tests exercise. Foods the
/// coach has not priced sink to the bottom rather than reading as free.
final rankedFoodsProvider = StreamProvider<List<FoodItem>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return _foodRows(db).map(
    (rows) => rankByProteinCost(rows.map(foodToItem).toList()),
  );
});

/// Live list of every food, unpriced ones included.
///
/// The price-list screen uses this: a coach entering prices needs to see all
/// of them, not just the ones that already have a price.
final allFoodsProvider = StreamProvider<List<FoodRow>>((ref) {
  return _foodRows(ref.watch(appDatabaseProvider));
});
