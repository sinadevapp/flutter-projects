import 'package:fit_coach/app/fit_coach_app.dart';
import 'package:fit_coach/app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('app builds with Material 3 theme and shows home page',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: FitCoachApp()),
    );
    await tester.pumpAndSettle();

    // Material 3 is enabled
    final context = tester.element(find.byType(Navigator).first);
    final theme = Theme.of(context);
    expect(theme.useMaterial3, isTrue);

    // Router lands on home: app title in AppBar and page title in body
    expect(find.text('FitCoach'), findsNWidgets(2));
  });

  test('router exposes the home route at /', () {
    final router = buildAppRouter();
    expect(router.routeInformationProvider.value.uri.toString(), '/');
  });
}
