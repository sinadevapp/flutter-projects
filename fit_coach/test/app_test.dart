import 'package:fit_coach/app/fit_coach_app.dart';
import 'package:fit_coach/app/router.dart';
import 'package:fit_coach/core/database/test_database.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app builds with Material 3 theme and renders its start screen',
      (tester) async {
    final db = createTestDatabase();
    addTearDown(db.close);
    // The primary language, so assertions read in Persian.
    await db.setLocaleCode('fa');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const FitCoachApp(),
      ),
    );
    // First frame(s): active-user lookup is async.
    await tester.pump();
    await tester.pump();

    // Material 3 is enabled
    final context = tester.element(find.byType(Navigator).first);
    final theme = Theme.of(context);
    expect(theme.useMaterial3, isTrue);

    // Router renders a screen (role picker for a fresh DB).
    expect(find.text('نقش خود را انتخاب کنید'), findsOneWidget);
  });

  test('router exposes the home route at /', () {
    final router = buildAppRouter();
    expect(router.routeInformationProvider.value.uri.toString(), '/');
  });
}
