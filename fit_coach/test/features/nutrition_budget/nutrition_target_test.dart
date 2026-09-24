import 'package:fit_coach/core/nutrition/nutrition_target.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The worked example used throughout: a 30 year old man, 180 cm, 80 kg,
  // training moderately. His Mifflin-St Jeor BMR is
  //   10*80 + 6.25*180 - 5*30 + 5 = 1780 kcal,
  // and moderate activity (x1.55) puts maintenance at 2759 kcal.
  const profile = NutritionProfile(
    sex: Sex.male,
    age: 30,
    heightCm: 180,
    weightKg: 80,
    activity: ActivityLevel.moderate,
    goal: Goal.maintain,
  );

  test('BMR follows Mifflin-St Jeor', () {
    expect(estimateTargets(profile).bmr, closeTo(1780, 0.01));
  });

  test('a man and a woman of the same size differ by the sex constant', () {
    final man = estimateTargets(profile);
    final woman = estimateTargets(
      const NutritionProfile(
        sex: Sex.female,
        age: 30,
        heightCm: 180,
        weightKg: 80,
        activity: ActivityLevel.moderate,
        goal: Goal.maintain,
      ),
    );

    // +5 for men, -161 for women.
    expect(man.bmr - woman.bmr, closeTo(166, 0.01));
  });

  test('activity level scales BMR into TDEE', () {
    expect(estimateTargets(profile).tdee, closeTo(1780 * 1.55, 0.01));
    expect(
      estimateTargets(
        const NutritionProfile(
          sex: Sex.male,
          age: 30,
          heightCm: 180,
          weightKg: 80,
          activity: ActivityLevel.sedentary,
          goal: Goal.maintain,
        ),
      ).tdee,
      closeTo(1780 * 1.2, 0.01),
    );
  });

  test('the goal moves calories away from maintenance', () {
    NutritionTarget forGoal(Goal goal) => estimateTargets(
          NutritionProfile(
            sex: Sex.male,
            age: 30,
            heightCm: 180,
            weightKg: 80,
            activity: ActivityLevel.moderate,
            goal: goal,
          ),
        );

    final maintain = forGoal(Goal.maintain);
    expect(maintain.calories, closeTo(maintain.tdee, 0.01));

    // Cutting is a deficit, bulking a surplus.
    expect(forGoal(Goal.lose).calories, lessThan(maintain.calories));
    expect(forGoal(Goal.gain).calories, greaterThan(maintain.calories));
  });

  test('cutting raises the protein target per kilo of bodyweight', () {
    NutritionTarget forGoal(Goal goal) => estimateTargets(
          NutritionProfile(
            sex: Sex.male,
            age: 30,
            heightCm: 180,
            weightKg: 80,
            activity: ActivityLevel.moderate,
            goal: goal,
          ),
        );

    // Protein is prescribed per kg of bodyweight, and protecting muscle in a
    // deficit needs more of it than maintaining or bulking does.
    final cutting = forGoal(Goal.lose).proteinG;
    final maintaining = forGoal(Goal.maintain).proteinG;
    final bulking = forGoal(Goal.gain).proteinG;

    expect(cutting, greaterThan(maintaining));
    expect(maintaining, greaterThan(bulking));
    expect(maintaining, closeTo(1.8 * 80, 0.01));
  });

  test('the macro split adds up to the calorie target', () {
    final target = estimateTargets(profile);

    // Protein and carbs are 4 kcal/g, fat is 9.
    final fromMacros =
        target.proteinG * 4 + target.carbsG * 4 + target.fatG * 9;
    expect(fromMacros, closeTo(target.calories, 0.01));
  });

  test('a heavier student gets higher targets', () {
    final lighter = estimateTargets(profile);
    final heavier = estimateTargets(
      const NutritionProfile(
        sex: Sex.male,
        age: 30,
        heightCm: 180,
        weightKg: 95,
        activity: ActivityLevel.moderate,
        goal: Goal.maintain,
      ),
    );

    expect(heavier.bmr, greaterThan(lighter.bmr));
    expect(heavier.proteinG, greaterThan(lighter.proteinG));
  });

  test('an older student burns less at the same size', () {
    final younger = estimateTargets(profile);
    final older = estimateTargets(
      const NutritionProfile(
        sex: Sex.male,
        age: 50,
        heightCm: 180,
        weightKg: 80,
        activity: ActivityLevel.moderate,
        goal: Goal.maintain,
      ),
    );

    expect(older.bmr, lessThan(younger.bmr));
  });
}
