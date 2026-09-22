import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:fit_coach/core/database/test_database.dart';
import 'package:fit_coach/features/nutrition_budget/presentation/food_prices_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_app.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  Future<void> pumpScreen(
    WidgetTester tester, {
    Locale locale = testLocale,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: testApp(home: const FoodPricesScreen(), locale: locale),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Unmounts inside fake-async so drift's stream timers are cancelled.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  testWidgets('foods are listed with their macros and no price yet',
      (tester) async {
    await pumpScreen(tester);

    expect(find.text('قیمت مواد غذایی'), findsOneWidget);
    // Every seeded food has macros but a blank price, so the screen must say
    // so rather than showing a misleading zero.
    expect(find.text('عدس'), findsOneWidget);
    expect(find.text('سینه مرغ'), findsOneWidget);
    expect(find.text('قیمت وارد نشده'), findsWidgets);

    await unmount(tester);
  });

  testWidgets('entering a price shows the cost per gram of protein',
      (tester) async {
    await pumpScreen(tester);

    // Tap the row for lentils (100000 toman/kg, 25 g protein per 100 g).
    await tester.tap(find.text('عدس'));
    await tester.pumpAndSettle();

    expect(find.text('قیمت عدس'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '100000');
    await tester.tap(find.text('ذخیره'));
    await tester.pumpAndSettle();

    // 100000 / (25 * 10) = 400 toman per gram of protein, in Persian digits.
    expect(find.textContaining('۴۰۰'), findsWidgets);

    await unmount(tester);
  });

  testWidgets('a saved price survives reopening the screen', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('عدس'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '100000');
    await tester.tap(find.text('ذخیره'));
    await tester.pumpAndSettle();

    // Persisted, not just held in widget state.
    final lentils = (await db.getAllFoods()).firstWhere((f) => f.name == 'عدس');
    expect(lentils.pricePerKg, 100000);

    await unmount(tester);
  });

  testWidgets('an invalid price is rejected and nothing is stored',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('عدس'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'سلام');
    await tester.tap(find.text('ذخیره'));
    await tester.pumpAndSettle();

    final lentils = (await db.getAllFoods()).firstWhere((f) => f.name == 'عدس');
    expect(lentils.pricePerKg, isNull);

    await unmount(tester);
  });

  testWidgets('an empty price clears it rather than storing zero',
      (tester) async {
    await db.updateFoodPrice(
      (await db.getAllFoods()).firstWhere((f) => f.name == 'عدس').id,
      100000,
    );
    await pumpScreen(tester);

    await tester.tap(find.text('عدس'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('ذخیره'));
    await tester.pumpAndSettle();

    final lentils = (await db.getAllFoods()).firstWhere((f) => f.name == 'عدس');
    // Blank means "I don't know", which is not the same as free.
    expect(lentils.pricePerKg, isNull);

    await unmount(tester);
  });

  testWidgets('the screen works in English too', (tester) async {
    await pumpScreen(tester, locale: const Locale('en'));

    expect(find.text('Food prices'), findsOneWidget);
    expect(find.text('No price entered'), findsWidgets);
    expect(find.text('قیمت وارد نشده'), findsNothing);

    await unmount(tester);
  });
}
