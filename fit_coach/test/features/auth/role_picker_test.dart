import 'package:fit_coach/app/router.dart';
import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/test_database.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:fit_coach/features/auth/presentation/role_picker_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('role picker shows coach and student choices',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: RolePickerScreen())),
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
        child: MaterialApp.router(routerConfig: buildAppRouter()),
      ),
    );
    await tester.pumpAndSettle();

    // No user yet -> role picker is shown at '/'.
    expect(find.byType(RolePickerScreen), findsOneWidget);

    await tester.tap(find.text('مربی'));
    await tester.pumpAndSettle();

    // Navigated past the gate to home.
    expect(find.byType(RolePickerScreen), findsNothing);
    expect(find.text('FitCoach'), findsWidgets);

    // Persistence verified: the picked user is in the database.
    final users = await db.getAllUsers();
    expect(users.length, 1);
    expect(users.first.role, UserRole.coach);
  });
}
