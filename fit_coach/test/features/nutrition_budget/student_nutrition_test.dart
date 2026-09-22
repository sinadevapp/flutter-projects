import 'package:drift/drift.dart' show Value;
import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:fit_coach/core/database/test_database.dart';
import 'package:fit_coach/features/nutrition_budget/presentation/student_nutrition_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_app.dart';

void main() {
  late AppDatabase db;
  late int studentId;

  setUp(() async {
    db = createTestDatabase();
    studentId = await db.insertUser(
      UsersCompanion.insert(name: 'علی', role: UserRole.student),
    );
  });
  tearDown(() => db.close());

  /// Goal index 1 is `Goal.maintain` — 0 is `lose`, which raises protein.
  Future<void> saveProfile({int goal = 1}) => db.saveNutritionTarget(
        NutritionTargetsCompanion.insert(
          studentId: Value(studentId),
          sex: 0,
          age: 30,
          heightCm: 180,
          weightKg: 80,
          activity: 2,
          goal: goal,
        ),
      );

  Future<void> pumpStudent(
    WidgetTester tester, {
    Locale locale = testLocale,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: testApp(
          home: StudentNutritionScreen(studentId: studentId),
          locale: locale,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  testWidgets('a student with no profile is told to ask their coach',
      (tester) async {
    await pumpStudent(tester);

    // The student cannot set this up themselves — it is the coach's input.
    expect(find.text('هنوز برنامه غذایی برایت تنظیم نشده'), findsOneWidget);
    expect(find.text('ثبت پروفایل'), findsNothing);
    expect(find.text('ویرایش پروفایل'), findsNothing);

    await unmount(tester);
  });

  testWidgets('a student sees their daily targets read-only', (tester) async {
    await saveProfile();
    await pumpStudent(tester);

    // Same numbers the coach sees: 1780 BMR, 2759 TDEE, 144 g protein.
    expect(find.text('کالری روزانه'), findsOneWidget);
    expect(find.text('پروتئین روزانه'), findsOneWidget);
    expect(find.textContaining('۲۷۵۹'), findsWidgets);
    expect(find.textContaining('۱۴۴'), findsWidgets);

    // Read-only: nothing here edits the profile.
    expect(find.text('ویرایش پروفایل'), findsNothing);
    expect(find.text('ثبت پروفایل'), findsNothing);

    await unmount(tester);
  });

  testWidgets('the student sees the same costed plan the coach does',
      (tester) async {
    final lentils = (await db.getAllFoods()).firstWhere((f) => f.name == 'عدس');
    await db.updateFoodPrice(lentils.id, 100000);
    await saveProfile();

    await pumpStudent(tester);

    // Knowing what to buy is the point — the student is the one shopping.
    expect(find.text('ارزان‌ترین راه پروتئین'), findsOneWidget);
    expect(find.textContaining('عدس'), findsWidgets);

    await unmount(tester);
  });

  testWidgets('with no prices the student is told to ask the coach',
      (tester) async {
    await saveProfile();
    await pumpStudent(tester);

    expect(find.text('برای محاسبه، قیمت مواد غذایی را وارد کنید'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('the student screen works in English too', (tester) async {
    await saveProfile();
    await pumpStudent(tester, locale: const Locale('en'));

    expect(find.text('Daily protein'), findsOneWidget);
    expect(find.textContaining('144'), findsWidgets);
    expect(find.textContaining('۱۴۴'), findsNothing);

    await unmount(tester);
  });
}
