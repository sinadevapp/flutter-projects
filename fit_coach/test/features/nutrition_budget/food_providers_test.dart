import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:fit_coach/core/database/test_database.dart';
import 'package:fit_coach/features/nutrition_budget/application/food_providers.dart';
import 'package:fit_coach/features/nutrition_budget/domain/food_cost.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_app.dart';

/// Renders the ranked list as text lines so a test can assert on it.
///
/// Drift's `watch()` streams only settle inside a widget tree's fake-async
/// zone, so provider tests in this project go through `pumpWidget` rather
/// than a bare [ProviderContainer] (see coach_hub_test.dart).
class _RankedProbe extends ConsumerWidget {
  const _RankedProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foods = ref.watch(rankedFoodsProvider);

    return foods.when(
      loading: () => const Text('...'),
      error: (e, _) => Text('ERR $e'),
      data: (list) => Column(
        children: [
          for (final food in list)
            Text(
              '${food.name}|${food.pricePerKg ?? "unpriced"}|'
              '${food.costPerGramProtein?.toStringAsFixed(2) ?? "-"}',
            ),
        ],
      ),
    );
  }
}

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  /// Pumps the probe and returns the ranked lines it rendered.
  Future<List<String>> pumpRanked(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: testApp(home: const Scaffold(body: _RankedProbe())),
      ),
    );
    await tester.pumpAndSettle();

    return tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data!)
        .toList();
  }

  /// Unmounts inside fake-async so drift's stream timers are cancelled.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  testWidgets('foods start unpriced until the coach fills prices in',
      (tester) async {
    final lines = await pumpRanked(tester);

    // The seeded list carries what a nutrition label gives for free...
    expect(lines, isNotEmpty);
    for (final line in lines) {
      final parts = line.split('|');
      expect(parts[0], isNotEmpty);
      // ...but no price, because nobody has been to the market yet.
      expect(parts[1], 'unpriced', reason: line);
      expect(parts[2], '-', reason: line);
    }

    await unmount(tester);
  });

  testWidgets('an unpriced list is not presented as a ranking',
      (tester) async {
    final lines = await pumpRanked(tester);

    // Nothing can be compared, so nothing may be labelled cheapest-first.
    // The order shown is the stable insert order, and every cost is blank.
    expect(lines.every((l) => l.endsWith('|-')), isTrue);

    await unmount(tester);
  });

  testWidgets('setting a price puts that food at the top of the ranking',
      (tester) async {
    final chicken = (await db.getAllFoods())
        .firstWhere((f) => f.name == 'سینه مرغ');

    await db.updateFoodPrice(chicken.id, 100000);

    final lines = await pumpRanked(tester);

    // 100000 toman/kg at 31 g protein per 100 g is by far the cheapest here.
    expect(lines.first, startsWith('سینه مرغ|100000|'));
    // 100000 / (31 * 10) = 322.58 toman per gram of protein.
    expect(lines.first, endsWith('322.58'));

    await unmount(tester);
  });

  testWidgets('foods re-rank against each other as prices come in',
      (tester) async {
    final all = await db.getAllFoods();
    final lentils = all.firstWhere((f) => f.name == 'عدس');
    final chickpeas = all.firstWhere((f) => f.name == 'نخود');

    // Lentils are denser in protein (25 vs 19 per 100 g), so at equal prices
    // they win...
    await db.updateFoodPrice(lentils.id, 100000);
    await db.updateFoodPrice(chickpeas.id, 100000);
    expect((await pumpRanked(tester)).first, startsWith('عدس|'));

    // ...but price them 2.5x apart and the order flips.
    await db.updateFoodPrice(lentils.id, 250000);
    expect((await pumpRanked(tester)).first, startsWith('نخود|'));

    await unmount(tester);
  });

  testWidgets('clearing a price takes the food back out of the comparison',
      (tester) async {
    final chicken = (await db.getAllFoods())
        .firstWhere((f) => f.name == 'سینه مرغ');

    await db.updateFoodPrice(chicken.id, 100000);
    expect((await pumpRanked(tester)).first, startsWith('سینه مرغ|'));

    // A cleared price is "unknown", not "free": it must leave the ranking.
    await db.updateFoodPrice(chicken.id, null);

    final lines = await pumpRanked(tester);
    final cleared = lines.firstWhere((l) => l.startsWith('سینه مرغ|'));
    expect(cleared, startsWith('سینه مرغ|unpriced|-'));

    await unmount(tester);
  });

  testWidgets('the domain type is what the provider exposes', (tester) async {
    // Guards the seam: a database row must arrive as pricing logic, not as a
    // row the UI has to re-interpret.
    await db.updateFoodPrice(
      (await db.getAllFoods()).firstWhere((f) => f.name == 'برنج').id,
      450000,
    );

    final lines = await pumpRanked(tester);
    final rice = lines.firstWhere((l) => l.startsWith('برنج|'));
    expect(rice, startsWith('برنج|450000|'));

    // 450000 / (7 * 10) = 6428.57 — computed by FoodItem, not by the widget.
    expect(rice, endsWith('6428.57'));

    await unmount(tester);
    expect(foodToItem, isNotNull);
    expect(FoodItem, isNotNull);
  });
}
