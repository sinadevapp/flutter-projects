import 'package:fit_coach/app/router.dart';
import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/test_database.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:fit_coach/features/auth/presentation/role_picker_screen.dart';
import 'package:fit_coach/features/coach_hub/presentation/coach_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_app.dart';

void main() {
  testWidgets('role picker shows coach and student choices',
      (tester) async {
    // The language switcher reads the settings row, so a database is required.
    final db = createTestDatabase();
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: testApp(home: const RolePickerScreen()),
      ),
    );

    expect(find.text('نقش خود را انتخاب کنید'), findsOneWidget);
    expect(find.text('مربی'), findsOneWidget);
    expect(find.text('شاگرد'), findsOneWidget);
  });

  testWidgets(
      'router with no active user shows role picker; '
      'tapping a role saves the user and lands on home', (tester) async {
    // Shared in-memory DB so the test can verify persistence.
    final db = createTestDatabase();
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: testRouterApp(routerConfig: buildAppRouter()),
      ),
    );
    await tester.pumpAndSettle();

    // No user yet -> role picker is shown at '/'.
    expect(find.byType(RolePickerScreen), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'مربی'));
    await tester.pumpAndSettle();

    // Navigated past the gate to the coach dashboard.
    expect(find.byType(RolePickerScreen), findsNothing);
    expect(find.byType(CoachHubScreen), findsOneWidget);

    // Persistence verified: the session role is stored, and picking a role
    // does NOT create a user row (students are the coach's data, not session).
    expect(await db.getActiveRole(), UserRole.coach);
    expect(await db.getAllUsers(), isEmpty);

    // Unmount inside fake-async so the drift watch stream's disposal timer
    // fires before the test framework checks for pending timers.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
