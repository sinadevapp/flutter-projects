// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Persian (`fa`).
class AppLocalizationsFa extends AppLocalizations {
  AppLocalizationsFa([String locale = 'fa']) : super(locale);

  @override
  String get rolePickerTitle => 'نقش خود را انتخاب کنید';

  @override
  String get coach => 'مربی';

  @override
  String get student => 'شاگرد';

  @override
  String get addStudent => 'افزودن شاگرد';

  @override
  String get studentNameLabel => 'نام شاگرد';

  @override
  String get nameRequired => 'نام را وارد کنید';

  @override
  String get save => 'ذخیره';

  @override
  String get studentAdded => 'شاگرد اضافه شد';

  @override
  String get noStudentsYet => 'هنوز شاگردی اضافه نشده';

  @override
  String get noStudentsRegistered => 'هنوز شاگردی ثبت نشده';

  @override
  String get switchRole => 'تغییر نقش';

  @override
  String get myPlans => 'برنامه‌های من';

  @override
  String plansForStudent(String name) {
    return 'برنامه‌های $name';
  }

  @override
  String get noPlansForStudent => 'هنوز برنامه‌ای ساخته نشده';

  @override
  String get noPlansForMe => 'هنوز برنامه‌ای برایت ساخته نشده';

  @override
  String get newPlan => 'برنامه جدید';

  @override
  String get planTitleLabel => 'عنوان برنامه';

  @override
  String get planTitleRequired => 'عنوان برنامه را وارد کنید';

  @override
  String get movements => 'حرکات';

  @override
  String get addMovement => 'افزودن حرکت';

  @override
  String get movementNameLabel => 'نام حرکت';

  @override
  String get setsLabel => 'ست';

  @override
  String get repsLabel => 'تکرار';

  @override
  String setsXReps(String sets, String reps) {
    return '$sets × $reps';
  }

  @override
  String get planHasNoMovements => 'این برنامه حرکتی ندارد';

  @override
  String get startWorkout => 'شروع تمرین';

  @override
  String get resumeWorkout => 'ادامه تمرین';

  @override
  String get completeSet => 'ست تمام';

  @override
  String get finishWorkout => 'پایان تمرین';

  @override
  String get workoutComplete => 'تمرین تمام شد';

  @override
  String setOf(String current, String total) {
    return 'ست $current از $total';
  }

  @override
  String setsProgress(String done, String total) {
    return '$done از $total ست';
  }

  @override
  String get language => 'زبان';

  @override
  String get myProgress => 'پیشرفت من';

  @override
  String get completedWorkouts => 'تمرین‌های کامل‌شده';

  @override
  String get totalSetsDone => 'کل ست‌ها';

  @override
  String get weeklyTrend => 'روند هفتگی';

  @override
  String get volumeByMovement => 'حجم به تفکیک حرکت';

  @override
  String get noHistoryYet => 'هنوز تمرینی ثبت نشده';

  @override
  String weekOf(String date) {
    return 'هفته $date';
  }

  @override
  String setsCount(String count) {
    return '$count ست';
  }

  @override
  String weekStart(String day) {
    return 'شروع هفته: $day';
  }
}
