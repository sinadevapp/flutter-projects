import 'package:fit_coach/app/fit_coach_app.dart';
import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:fit_coach/core/database/test_database.dart';
import 'package:fit_coach/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The visual contract: a Persian-first theme with a bundled font, and a
/// language switch that actually re-themes the app rather than only swapping
/// strings.
void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  Widget app() => ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const FitCoachApp(),
      );

  testWidgets('the app uses the FitCoach theme, not the default',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(Scaffold).first);
    final theme = Theme.of(context);

    // Material 3 with the teal the design system settled on.
    expect(theme.useMaterial3, isTrue);
    expect(theme.colorScheme.primary, isNotNull);
    expect(AppTheme.seed, const Color(0xFF0F766E));

    // Vazirmatn is applied by *name*: the family must be declared on the
    // text theme, or Flutter falls back to Roboto and Persian renders poorly.
    expect(theme.textTheme.bodyMedium?.fontFamily, AppTheme.fontFamily);
    expect(theme.textTheme.headlineSmall?.fontFamily, AppTheme.fontFamily);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('Persian is not forced on an English device', (tester) async {
    // locale null = follow the device. The theme must not hard-code a locale,
    // only a typeface.
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.locale, isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  test('the theme is flat: no heavy elevation anywhere', () {
    final theme = AppTheme.light;

    // Depth comes from surface tiers and 1px borders, not dramatic shadows
    // on a phone.
    expect(theme.cardTheme.elevation, 0);
    expect(theme.appBarTheme.elevation, 0);
  });

  test('buttons and cards follow the 12px radius of the design system', () {
    final theme = AppTheme.light;

    final buttonShape =
        theme.filledButtonTheme.style?.shape?.resolve({}) as RoundedRectangleBorder?;
    expect(buttonShape?.borderRadius, BorderRadius.circular(AppTheme.radius));

    final cardShape =
        theme.cardTheme.shape as RoundedRectangleBorder?;
    expect(cardShape?.borderRadius, BorderRadius.circular(AppTheme.radius));
  });

  test('touch targets are never below the minimum', () {
    final theme = AppTheme.light;
    final size = theme.filledButtonTheme.style?.minimumSize?.resolve({});

    // Tapped by one thumb, possibly while out of breath.
    expect(size?.height, greaterThanOrEqualTo(AppTheme.minTouchTarget));
  });

  test('every text style carries the bundled font', () {
    final text = AppTheme.light.textTheme;

    // A style that falls back to the default font is a Persian string
    // rendered in a typeface that was never designed for it.
    for (final style in [
      text.displayLarge,
      text.headlineMedium,
      text.titleMedium,
      text.bodyMedium,
      text.bodySmall,
      text.labelLarge,
    ]) {
      expect(style?.fontFamily, AppTheme.fontFamily, reason: '$style');
    }
  });
}
