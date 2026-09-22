import 'package:drift/drift.dart' show Value;
import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:fit_coach/core/database/test_database.dart';
import 'package:fit_coach/features/nutrition_budget/presentation/nutrition_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_app.dart';

void main() {
  late AppDatabase db;
  late User student;

  setUp(() async {
    db = createTestDatabase();
    final id = await db.insertUser(
      UsersCompanion.insert(name: 'علی', role: UserRole.student),
    );
    student = (await db.getAllUsers()).firstWhere((u) => u.id == id);
  });
  tearDown(() => db.close());

  Future<void> pumpScreen(
    WidgetTester tester, {
    Locale locale = testLocale,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: testApp(
          home: NutritionScreen(student: student),
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

  /// Fills the profile form and saves it.
  Future<void> enterProfile(WidgetTester tester) async {
    await tester.enterText(find.byKey(const Key('field_age')), '30');
    await tester.enterText(find.byKey(const Key('field_height')), '180');
    await tester.enterText(find.byKey(const Key('field_weight')), '80');
    await tester.tap(find.text('ذخیره'));
    await tester.pumpAndSettle();
  }

  testWidgets('a student with no profile is asked for one', (tester) async {
    await pumpScreen(tester);

    expect(find.text('تغذیه علی'), findsOneWidget);
    expect(find.text('هنوز پروفایل تغذیه ثبت نشده'), findsOneWidget);
    expect(find.text('ثبت پروفایل'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('saving a profile shows the estimated targets', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('ثبت پروفایل'));
    await tester.pumpAndSettle();
    await enterProfile(tester);

    // Mifflin-St Jeor for a 30 y/o man, 180 cm, 80 kg: 1780 kcal BMR.
    // Moderate activity (x1.55) -> 2759 kcal TDEE, and maintaining means the
    // calorie target is the same 2759. Persian digits throughout.
    expect(find.text('سوخت‌وساز پایه'), findsOneWidget);
    expect(find.textContaining('۱۷۸۰'), findsWidgets);
    expect(find.textContaining('۲۷۵۹'), findsWidgets);

    // Protein at 1.8 g/kg of bodyweight = 144 g.
    expect(find.text('پروتئین روزانه'), findsOneWidget);
    expect(find.textContaining('۱۴۴'), findsWidgets);

    await unmount(tester);
  });

  testWidgets('the profile is stored, not just displayed', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('ثبت پروفایل'));
    await tester.pumpAndSettle();
    await enterProfile(tester);

    final saved = await db.getNutritionTarget(student.id);
    expect(saved, isNotNull);
    expect(saved!.age, 30);
    expect(saved.heightCm, 180);
    expect(saved.weightKg, 80);

    await unmount(tester);
  });

  testWidgets('an invalid field is rejected and nothing is stored',
      (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('ثبت پروفایل'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('field_age')), 'سی');
    await tester.enterText(find.byKey(const Key('field_height')), '180');
    await tester.enterText(find.byKey(const Key('field_weight')), '80');
    await tester.tap(find.text('ذخیره'));
    await tester.pumpAndSettle();

    expect(await db.getNutritionTarget(student.id), isNull);

    await unmount(tester);
  });

  testWidgets('with no priced food the plan asks for prices', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('ثبت پروفایل'));
    await tester.pumpAndSettle();
    await enterProfile(tester);

    // Nothing has a price yet, so there is nothing to cost.
    expect(find.text('ارزان‌ترین راه پروتئین'), findsOneWidget);
    expect(find.text('برای محاسبه، قیمت مواد غذایی را وارد کنید'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('priced food turns the plan into costed options', (tester) async {
    final lentils = (await db.getAllFoods()).firstWhere((f) => f.name == 'عدس');
    await db.updateFoodPrice(lentils.id, 100000);

    await pumpScreen(tester);
    await tester.tap(find.text('ثبت پروفایل'));
    await tester.pumpAndSettle();
    await enterProfile(tester);

    // Protein target 144 g from lentils: 144 / 0.25 = 576 g, which is 0.576 kg
    // at 100000 toman/kg = 57600 toman.
    expect(find.textContaining('عدس'), findsWidgets);
    expect(find.textContaining('۵۷۶'), findsWidgets);

    await unmount(tester);
  });

  testWidgets('an existing profile opens straight to the targets',
      (tester) async {
    await db.saveNutritionTarget(
      NutritionTargetsCompanion.insert(
        studentId: Value(student.id),
        sex: 0,
        age: 30,
        heightCm: 180,
        weightKg: 80,
        activity: 2,
        goal: 0,
      ),
    );

    await pumpScreen(tester);

    expect(find.text('سوخت‌وساز پایه'), findsOneWidget);
    expect(find.text('هنوز پروفایل تغذیه ثبت نشده'), findsNothing);

    await unmount(tester);
  });

  testWidgets('the screen works in English too', (tester) async {
    await db.saveNutritionTarget(
      NutritionTargetsCompanion.insert(
        studentId: Value(student.id),
        sex: 0,
        age: 30,
        heightCm: 180,
        weightKg: 80,
        activity: 2,
        goal: 0,
      ),
    );

    await pumpScreen(tester, locale: const Locale('en'));

    expect(find.text('Nutrition for علی'), findsOneWidget);
    expect(find.text('Basal metabolic rate'), findsOneWidget);
    // Plain digits in English, not Persian ones.
    expect(find.textContaining('1780'), findsWidgets);
    expect(find.textContaining('۱۷۸۰'), findsNothing);

    await unmount(tester);
  });
}
