import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:fit_coach/core/database/test_database.dart';
import 'package:fit_coach/features/coach_hub/presentation/coach_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_app.dart';

/// Picking a movement from the library instead of retyping its name.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = createTestDatabase();
    await db.insertUser(
      UsersCompanion.insert(name: 'علی', role: UserRole.student),
    );
  });
  tearDown(() => db.close());

  Future<void> openForm(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: testApp(home: const CoachHubScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('علی'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('برنامه جدید'));
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  Future<void> pick(WidgetTester tester) async {
    final button = find.byTooltip('انتخاب از کتابخانه');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('offers the movements of the row\'s own category', (
    tester,
  ) async {
    await openForm(tester);
    await pick(tester);

    // The row defaults to «ترکیبی», so the sheet offers that category only —
    // a compound row should not list five isolation machines.
    expect(find.text('ددلیفت'), findsOneWidget);
    expect(find.text('تمیز و پرس'), findsOneWidget);
    expect(find.text('اسکوات کامل'), findsOneWidget);
    expect(find.text('کرانچ'), findsNothing);

    await unmount(tester);
  });

  testWidgets('picking fills the movement name', (tester) async {
    await openForm(tester);
    await pick(tester);

    await tester.tap(find.text('ددلیفت'));
    await tester.pumpAndSettle();

    // The sheet is gone and the draft — the thing `_save` reads — holds it.
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.widgetWithText(TextField, 'ددلیفت'), findsOneWidget);

    await unmount(tester);
  });

  /// Brings [finder] into view — and therefore into the tree.
  ///
  /// The form is longer than the test viewport, so the category dropdown sits
  /// below the fold: tapping without this scrolls nothing and the tap lands
  /// outside the render tree.
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('changing the category changes what is offered', (
    tester,
  ) async {
    await openForm(tester);

    await scrollTo(tester, find.text('ترکیبی'));
    await tester.tap(find.text('ترکیبی'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('پا'));
    await tester.pumpAndSettle();

    await pick(tester);

    expect(find.text('اسکوات'), findsOneWidget);
    expect(find.text('لانج'), findsOneWidget);
    // Still only this category.
    expect(find.text('ددلیفت'), findsNothing);

    await unmount(tester);
  });

  testWidgets('the row can still be typed by hand', (tester) async {
    await openForm(tester);

    await tester.enterText(find.byType(TextField).first, 'حرکت دلخواه');
    await tester.pumpAndSettle();

    // The library is a shortcut, not a gate: a movement that does not exist
    // yet is still writable.
    expect(find.widgetWithText(TextField, 'حرکت دلخواه'), findsOneWidget);

    await unmount(tester);
  });
}
