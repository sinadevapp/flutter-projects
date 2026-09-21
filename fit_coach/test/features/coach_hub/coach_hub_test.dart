import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:fit_coach/core/database/test_database.dart';
import 'package:fit_coach/features/coach_hub/presentation/coach_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = createTestDatabase();
  });

  tearDown(() async {
    // Close DB inside a fake-async-safe window; drift's watch() streams
    // hold timers that must be cancelled before invariants are checked.
    db.close();
  });

  testWidgets('coach hub greets the coach by name and shows empty state',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: CoachHubScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('مربی'), findsOneWidget);
    expect(find.text('هنوز شاگردی اضافه نشده'), findsOneWidget);

    // Unmount while still inside fake-async so riverpod's provider disposal
    // (which cancels drift stream timers) runs in a controlled zone.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle(); // fire zero-duration timers from stream disposal
  });

  testWidgets('students added to the database appear in the list',
      (tester) async {
    await db.insertUser(
      UsersCompanion.insert(name: 'Ali', role: UserRole.student),
    );
    await db.insertUser(
      UsersCompanion.insert(name: 'Reza', role: UserRole.student),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: CoachHubScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ali'), findsOneWidget);
    expect(find.text('Reza'), findsOneWidget);
    expect(find.text('هنوز شاگردی اضافه نشده'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle(); // fire zero-duration timers from stream disposal
  });
}
