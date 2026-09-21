import 'package:fit_coach/app/fit_coach_app.dart';
import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:fit_coach/core/database/test_database.dart';
import 'package:fit_coach/features/coach_hub/presentation/coach_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester, AppDatabase db) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const FitCoachApp(),
      ),
    );
    // First frames: the active-user lookup is async.
    await tester.pump();
    await tester.pump();
  }

  /// Unmounts the tree inside fake-async so the drift watch stream's
  /// disposal timer fires (see flutter-development skill).
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  testWidgets('choosing the coach role opens the coach dashboard',
      (tester) async {
    final db = createTestDatabase();
    addTearDown(db.close);
    await pumpApp(tester, db);

    await tester.tap(find.widgetWithText(FilledButton, 'مربی'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(CoachHubScreen), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('choosing the student role opens the student home',
      (tester) async {
    final db = createTestDatabase();
    addTearDown(db.close);
    await pumpApp(tester, db);

    await tester.tap(find.widgetWithText(FilledButton, 'شاگرد'));
    await tester.pump();
    await tester.pump();

    expect(find.text('شاگرد'), findsOneWidget);
    expect(find.byType(CoachHubScreen), findsNothing);

    await unmount(tester);
  });

  testWidgets('a persisted session skips the role picker on launch',
      (tester) async {
    final db = createTestDatabase();
    addTearDown(db.close);
    await db.setActiveRole(UserRole.coach);

    await pumpApp(tester, db);

    expect(find.byType(CoachHubScreen), findsOneWidget);
    expect(find.text('نقش خود را انتخاب کنید'), findsNothing);

    await unmount(tester);
  });

  testWidgets('switching role returns to the role picker', (tester) async {
    final db = createTestDatabase();
    addTearDown(db.close);
    await pumpApp(tester, db);

    await tester.tap(find.widgetWithText(FilledButton, 'مربی'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(CoachHubScreen), findsOneWidget);

    await tester.tap(find.byTooltip('تغییر نقش'));
    await tester.pump();
    await tester.pump();

    expect(find.text('نقش خود را انتخاب کنید'), findsOneWidget);

    await unmount(tester);
  });
}
