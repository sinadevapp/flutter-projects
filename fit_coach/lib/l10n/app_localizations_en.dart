// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get rolePickerTitle => 'Choose your role';

  @override
  String get coach => 'Coach';

  @override
  String get student => 'Student';

  @override
  String get addStudent => 'Add student';

  @override
  String get studentNameLabel => 'Student name';

  @override
  String get nameRequired => 'Enter a name';

  @override
  String get save => 'Save';

  @override
  String get studentAdded => 'Student added';

  @override
  String get noStudentsYet => 'No students added yet';

  @override
  String get noStudentsRegistered => 'No students registered yet';

  @override
  String get switchRole => 'Switch role';

  @override
  String get myPlans => 'My plans';

  @override
  String plansForStudent(String name) {
    return 'Plans for $name';
  }

  @override
  String get noPlansForStudent => 'No plan built yet';

  @override
  String get noPlansForMe => 'No plan has been built for you yet';

  @override
  String get newPlan => 'New plan';

  @override
  String get planTitleLabel => 'Plan title';

  @override
  String get planTitleRequired => 'Enter a plan title';

  @override
  String get movements => 'Movements';

  @override
  String get addMovement => 'Add movement';

  @override
  String get movementNameLabel => 'Movement name';

  @override
  String get setsLabel => 'Sets';

  @override
  String get repsLabel => 'Reps';

  @override
  String setsXReps(String sets, String reps) {
    return '$sets × $reps';
  }

  @override
  String get planHasNoMovements => 'This plan has no movements';

  @override
  String get startWorkout => 'Start workout';

  @override
  String get resumeWorkout => 'Resume workout';

  @override
  String get completeSet => 'Set done';

  @override
  String get finishWorkout => 'Finish workout';

  @override
  String get workoutComplete => 'Workout complete';

  @override
  String setOf(String current, String total) {
    return 'Set $current of $total';
  }

  @override
  String setsProgress(String done, String total) {
    return '$done of $total sets';
  }

  @override
  String get language => 'Language';

  @override
  String get myProgress => 'My progress';

  @override
  String get completedWorkouts => 'Workouts completed';

  @override
  String get totalSetsDone => 'Total sets';

  @override
  String get weeklyTrend => 'Weekly trend';

  @override
  String get volumeByMovement => 'Volume by movement';

  @override
  String get noHistoryYet => 'No workouts recorded yet';

  @override
  String weekOf(String date) {
    return 'Week of $date';
  }

  @override
  String setsCount(String count) {
    return '$count sets';
  }

  @override
  String weekStart(String day) {
    return 'Week starts: $day';
  }

  @override
  String get nutrition => 'Nutrition';

  @override
  String get foodPrices => 'Food prices';

  @override
  String get foodPricesHint =>
      'Enter a price per kilo to work out what the protein costs';

  @override
  String get noPriceYet => 'No price entered';

  @override
  String get pricePerKg => 'Price per kilo (toman)';

  @override
  String get costPerGramProtein => 'Cost per gram of protein';

  @override
  String get proteinPer100g => 'Protein per 100 g';

  @override
  String get kcalPer100g => 'Energy per 100 g';

  @override
  String get cheapestProteinFirst => 'Ordered by cheapest protein';

  @override
  String get noFoodsYet => 'No foods yet';

  @override
  String enterPriceFor(String name) {
    return 'Price of $name';
  }

  @override
  String get priceSaved => 'Price saved';

  @override
  String get cancel => 'Cancel';

  @override
  String get invalidPrice => 'Enter a valid price';

  @override
  String studentNutrition(String name) {
    return 'Nutrition for $name';
  }

  @override
  String get noProfileYet => 'No nutrition profile yet';

  @override
  String get setProfile => 'Set profile';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get sexLabel => 'Sex';

  @override
  String get male => 'Male';

  @override
  String get female => 'Female';

  @override
  String get ageLabel => 'Age';

  @override
  String get heightLabel => 'Height (cm)';

  @override
  String get weightLabel => 'Weight (kg)';

  @override
  String get activityLabel => 'Activity level';

  @override
  String get activitySedentary => 'Sedentary';

  @override
  String get activityLight => 'Light';

  @override
  String get activityModerate => 'Moderate';

  @override
  String get activityActive => 'Active';

  @override
  String get activityVeryActive => 'Very active';

  @override
  String get goalLabel => 'Goal';

  @override
  String get goalLose => 'Lose weight';

  @override
  String get goalMaintain => 'Maintain weight';

  @override
  String get goalGain => 'Gain weight';

  @override
  String get invalidNumber => 'Enter a valid number';

  @override
  String get bmr => 'Basal metabolic rate';

  @override
  String get tdee => 'Daily energy use';

  @override
  String get dailyCalories => 'Daily calories';

  @override
  String get dailyProtein => 'Daily protein';

  @override
  String get dailyCarbs => 'Daily carbs';

  @override
  String get dailyFat => 'Daily fat';

  @override
  String kcalUnit(String value) {
    return '$value kcal';
  }

  @override
  String gramUnit(String value) {
    return '$value g';
  }

  @override
  String get proteinPlanTitle => 'Cheapest ways to get protein';

  @override
  String get proteinPlanEmpty =>
      'Enter food prices to work out the cheapest options';

  @override
  String planOption(String grams, String name) {
    return '$grams g of $name';
  }

  @override
  String planCost(String cost) {
    return '$cost toman';
  }

  @override
  String planKcal(String value) {
    return '$value kcal';
  }

  @override
  String tomanUnit(String value) {
    return '$value toman';
  }
}
