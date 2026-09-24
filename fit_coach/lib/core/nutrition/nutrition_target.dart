/// What the student wants out of the plan.
enum Goal { lose, maintain, gain }

enum Sex { male, female }

/// How much the student moves outside training, as a multiplier on BMR.
enum ActivityLevel {
  sedentary(1.2),
  light(1.375),
  moderate(1.55),
  active(1.725),
  veryActive(1.9);

  const ActivityLevel(this.factor);

  final double factor;
}

/// The numbers the coach enters about a student.
class NutritionProfile {
  const NutritionProfile({
    required this.sex,
    required this.age,
    required this.heightCm,
    required this.weightKg,
    required this.activity,
    required this.goal,
  });

  final Sex sex;
  final int age;
  final double heightCm;
  final double weightKg;
  final ActivityLevel activity;
  final Goal goal;
}

/// The daily targets that come out of a [NutritionProfile].
class NutritionTarget {
  const NutritionTarget({
    required this.bmr,
    required this.tdee,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  /// Resting burn, Mifflin-St Jeor.
  final double bmr;

  /// BMR scaled by how much the student moves.
  final double tdee;

  /// What to actually eat: [tdee] shifted by the goal.
  final double calories;

  final double proteinG;
  final double carbsG;
  final double fatG;
}

/// Grams of protein prescribed per kilo of bodyweight, per goal.
///
/// A deficit needs the most protein — that is what protects muscle while the
/// student is losing weight — so cutting is highest and bulking lowest.
double _proteinPerKg(Goal goal) => switch (goal) {
      Goal.lose => 2.2,
      Goal.maintain => 1.8,
      Goal.gain => 1.6,
    };

/// Calories relative to maintenance for each goal.
double _calorieFactor(Goal goal) => switch (goal) {
      Goal.lose => 0.80,
      Goal.maintain => 1.0,
      Goal.gain => 1.10,
    };

/// Estimates a student's daily calorie and macro targets.
///
/// Pure arithmetic over the profile — no widgets, no database — so the whole
/// calculation is unit-testable on its own.
NutritionTarget estimateTargets(NutritionProfile profile) {
  // Mifflin-St Jeor: the +5 / -161 term is the only sex-dependent part.
  final sexTerm = profile.sex == Sex.male ? 5.0 : -161.0;
  final bmr = 10 * profile.weightKg +
      6.25 * profile.heightCm -
      5 * profile.age +
      sexTerm;

  final tdee = bmr * profile.activity.factor;
  final calories = tdee * _calorieFactor(profile.goal);

  final proteinG = _proteinPerKg(profile.goal) * profile.weightKg;
  final proteinKcal = proteinG * 4;

  // Fat takes a quarter of the calories; carbs are whatever is left over, so
  // the macro split always adds back up to the calorie target.
  var fatKcal = calories * 0.25;
  var remaining = calories - proteinKcal - fatKcal;
  if (remaining < 0) {
    // Absurd ratio (very heavy student on a very low target): give carbs
    // nothing and take the difference out of fat, keeping the sum exact.
    fatKcal = (calories - proteinKcal).clamp(0, double.infinity);
    remaining = 0;
  }

  return NutritionTarget(
    bmr: bmr,
    tdee: tdee,
    calories: calories,
    proteinG: proteinG,
    carbsG: remaining / 4,
    fatG: fatKcal / 9,
  );
}
