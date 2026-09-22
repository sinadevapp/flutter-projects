import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:fit_coach/core/database/test_database.dart';
import 'package:fit_coach/features/coach_hub/presentation/add_student_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_app.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = createTestDatabase();
  });

  tearDown(() {
    db.close();
  });

  testWidgets('shows name field and save button in Persian',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: testApp(home: const AddStudentScreen()),
      ),
    );

    expect(find.text('افزودن شاگرد'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('ذخیره'), findsOneWidget);
  });

  testWidgets('entering a name and saving inserts a student row',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: testApp(home: const AddStudentScreen()),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Ali');
    await tester.tap(find.text('ذخیره'));
    await tester.pumpAndSettle();

    final students = await db.getAllUsers();
    expect(students.length, 1);
    expect(students.first.name, 'Ali');
    expect(students.first.role, UserRole.student);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('saving an empty name shows validation error, inserts nothing',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: testApp(home: const AddStudentScreen()),
      ),
    );

    await tester.tap(find.text('ذخیره'));
    await tester.pumpAndSettle();

    expect(find.text('نام را وارد کنید'), findsOneWidget);
    expect(await db.getAllUsers(), isEmpty);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
