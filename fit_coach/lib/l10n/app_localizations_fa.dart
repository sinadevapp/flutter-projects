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
  String get noStudentsHint =>
      'اولین شاگردت را اضافه کن تا بتوانی برایش برنامه بسازی.';

  @override
  String get askCoachToAddYou => 'از مربی‌ات بخواه نامت را اضافه کند.';

  @override
  String get noPlansHint => 'برای این شاگرد هنوز برنامه‌ای نساخته‌ای.';

  @override
  String get noPlansHintStudent =>
      'وقتی مربی برایت برنامه ساخت، اینجا نمایش داده می‌شود.';

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
  String get pickFromLibrary => 'انتخاب از کتابخانه';

  @override
  String get noLibraryForCategory => 'برای این دسته حرکتی در کتابخانه نیست';

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
  String get renamePlan => 'تغییر نام برنامه';

  @override
  String get somethingWentWrong => 'مشکلی پیش آمد';

  @override
  String get tryAgainHint =>
      'دوباره تلاش کن. اگر ادامه داشت، برنامه را ببند و باز کن.';

  @override
  String get retry => 'تلاش دوباره';

  @override
  String get toman => 'تومان';

  @override
  String get scaleThousand => 'هزار';

  @override
  String get scaleMillion => 'میلیون';

  @override
  String thousandToman(String value) {
    return '$value هزار تومان';
  }

  @override
  String millionToman(String value) {
    return '$value میلیون تومان';
  }

  @override
  String get renameConfirm => 'ذخیره';

  @override
  String get deletePlan => 'حذف برنامه';

  @override
  String deletePlanConfirm(String title) {
    return 'برنامه «$title» و تمام تمرین‌های ثبت‌شده آن حذف می‌شود. مطمئنی؟';
  }

  @override
  String get planDeleted => 'برنامه حذف شد';

  @override
  String get editMovement => 'ویرایش حرکت';

  @override
  String get deleteMovement => 'حذف حرکت';

  @override
  String deleteMovementConfirm(String name) {
    return 'حرکت «$name» از این برنامه حذف شود؟';
  }

  @override
  String get movementDeleted => 'حرکت حذف شد';

  @override
  String get movementUpdated => 'حرکت ویرایش شد';

  @override
  String get planRenamed => 'نام برنامه تغییر کرد';

  @override
  String get duplicatePlan => 'کپی برای شاگرد دیگر';

  @override
  String get duplicateTo => 'کپی برنامه برای';

  @override
  String get duplicated => 'برنامه کپی شد';

  @override
  String get noOtherStudents => 'شاگرد دیگری وجود ندارد';

  @override
  String get edit => 'ویرایش';

  @override
  String get delete => 'حذف';

  @override
  String get resting => 'استراحت';

  @override
  String get restDone => 'استراحت تمام شد';

  @override
  String get skipRest => 'رد کردن';

  @override
  String get pauseRest => 'توقف';

  @override
  String get resumeRest => 'ادامه';

  @override
  String restSeconds(String seconds) {
    return '$seconds ثانیه';
  }

  @override
  String get workoutSummary => 'خلاصه تمرین';

  @override
  String get summaryDuration => 'مدت';

  @override
  String get summarySets => 'ست‌ها';

  @override
  String get summaryReps => 'تکرارها';

  @override
  String get summaryComplete => 'تمرین کامل شد';

  @override
  String get summaryPartial => 'تمرین ناتمام';

  @override
  String durationMinutes(String minutes) {
    return '$minutes دقیقه';
  }

  @override
  String durationHoursMinutes(String hours, String minutes) {
    return '$hours ساعت و $minutes دقیقه';
  }

  @override
  String get restTimeLabel => 'زمان استراحت (ثانیه)';

  @override
  String get weeklyTrendChart => 'نمودار روند هفتگی';

  @override
  String get movementVolumeChart => 'نمودار حجم حرکات';

  @override
  String get setsAxisLabel => 'ست';

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

  @override
  String get nutrition => 'تغذیه';

  @override
  String get foodPrices => 'قیمت مواد غذایی';

  @override
  String get foodPricesHint =>
      'قیمت هر کیلو را وارد کنید تا هزینه پروتئین محاسبه شود';

  @override
  String get noPriceYet => 'قیمت وارد نشده';

  @override
  String get pricePerKg => 'قیمت هر کیلو (تومان)';

  @override
  String get costPerGramProtein => 'هزینه هر گرم پروتئین';

  @override
  String get proteinPer100g => 'پروتئین در ۱۰۰ گرم';

  @override
  String get kcalPer100g => 'کالری در ۱۰۰ گرم';

  @override
  String get cheapestProteinFirst => 'ترتیب: ارزان‌ترین پروتئین';

  @override
  String get noFoodsYet => 'هنوز غذایی ثبت نشده';

  @override
  String enterPriceFor(String name) {
    return 'قیمت $name';
  }

  @override
  String get priceSaved => 'قیمت ذخیره شد';

  @override
  String get cancel => 'انصراف';

  @override
  String get invalidPrice => 'قیمت را درست وارد کنید';

  @override
  String studentNutrition(String name) {
    return 'تغذیه $name';
  }

  @override
  String get noProfileYet => 'هنوز پروفایل تغذیه ثبت نشده';

  @override
  String get setProfile => 'ثبت پروفایل';

  @override
  String get editProfile => 'ویرایش پروفایل';

  @override
  String get sexLabel => 'جنسیت';

  @override
  String get male => 'مرد';

  @override
  String get female => 'زن';

  @override
  String get ageLabel => 'سن';

  @override
  String get heightLabel => 'قد (سانتی‌متر)';

  @override
  String get weightLabel => 'وزن (کیلوگرم)';

  @override
  String lastTime(String weight, String reps) {
    return 'آخرین بار: $weight × $reps';
  }

  @override
  String lastTimeNoLoad(String reps) {
    return 'آخرین بار: $reps تکرار';
  }

  @override
  String get activityLabel => 'سطح فعالیت';

  @override
  String get activitySedentary => 'بی‌تحرک';

  @override
  String get activityLight => 'کم';

  @override
  String get activityModerate => 'متوسط';

  @override
  String get activityActive => 'زیاد';

  @override
  String get activityVeryActive => 'خیلی زیاد';

  @override
  String get goalLabel => 'هدف';

  @override
  String get goalLose => 'کاهش وزن';

  @override
  String get goalMaintain => 'حفظ وزن';

  @override
  String get goalGain => 'افزایش وزن';

  @override
  String get invalidNumber => 'عدد را درست وارد کنید';

  @override
  String get bmr => 'سوخت‌وساز پایه';

  @override
  String get tdee => 'سوخت روزانه';

  @override
  String get dailyCalories => 'کالری روزانه';

  @override
  String get dailyProtein => 'پروتئین روزانه';

  @override
  String get dailyCarbs => 'کربوهیدرات روزانه';

  @override
  String get dailyFat => 'چربی روزانه';

  @override
  String kcalUnit(String value) {
    return '$value کالری';
  }

  @override
  String gramUnit(String value) {
    return '$value گرم';
  }

  @override
  String get noStudentNutritionYet => 'هنوز برنامه غذایی برایت تنظیم نشده';

  @override
  String get progress => 'پیشرفت';

  @override
  String studentProgress(String name) {
    return 'پیشرفت $name';
  }

  @override
  String get proteinPlanTitle => 'ارزان‌ترین راه پروتئین';

  @override
  String get proteinPlanEmpty => 'برای محاسبه، قیمت مواد غذایی را وارد کنید';

  @override
  String planOption(String grams, String name) {
    return '$grams گرم $name';
  }

  @override
  String planCost(String cost) {
    return '$cost تومان';
  }

  @override
  String planKcal(String value) {
    return '$value کالری';
  }

  @override
  String tomanUnit(String value) {
    return '$value تومان';
  }

  @override
  String get tabAll => 'همه';

  @override
  String get tabPrivate => 'خصوصی';

  @override
  String get tabPublic => 'عمومی';

  @override
  String get visibilityLabel => 'نوع شاگرد';

  @override
  String get privateStudent => 'شاگرد خصوصی';

  @override
  String get publicStudent => 'شاگرد گروهی';

  @override
  String get addPhoto => 'افزودن عکس';

  @override
  String get changePhoto => 'تغییر عکس';

  @override
  String get removePhoto => 'حذف عکس';

  @override
  String get editStudent => 'ویرایش شاگرد';

  @override
  String get deleteStudent => 'حذف شاگرد';

  @override
  String deleteStudentConfirm(String name) {
    return 'همه برنامه‌ها، تمرین‌ها و اطلاعات $name برای همیشه حذف می‌شود. مطمئنی؟';
  }

  @override
  String get studentDeleted => 'شاگرد حذف شد';

  @override
  String get restDay => 'استراحت';

  @override
  String get restDayHint => 'این روز استراحت است — حرکتی برای اجرا ندارد';

  @override
  String get dayNameLabel => 'نام روز';

  @override
  String get dayNameHint => 'مثل «بالاتنه» یا «پا دست» (اختیاری)';

  @override
  String programLength(String n) {
    return '$n هفته';
  }

  @override
  String get studentUpdated => 'اطلاعات شاگرد به‌روز شد';

  @override
  String get noPrivateStudents => 'شاگرد خصوصی‌ای ثبت نشده';

  @override
  String get noPublicStudents => 'شاگرد گروهی‌ای ثبت نشده';

  @override
  String get emptyTabHint => 'شاگردان این دسته در تب دیگری هستند';

  @override
  String weekLabel(String n) {
    return 'هفته $n';
  }

  @override
  String dayLabel(String n) {
    return 'روز $n';
  }

  @override
  String get finishPreviousFirst => 'ابتدا تمرین قبلی را پایان ده';

  @override
  String get catLegs => 'پا';

  @override
  String get catChest => 'سینه';

  @override
  String get catShoulders => 'سرشانه';

  @override
  String get catBack => 'پشت';

  @override
  String get catArms => 'دست';

  @override
  String get catCore => 'شکم';

  @override
  String get catCompound => 'ترکیبی';

  @override
  String planForStudent(String name) {
    return 'برنامه برای $name';
  }

  @override
  String get durationWeeksLabel => 'مدت برنامه (هفته)';

  @override
  String addWeek(String n) {
    return 'افزودن هفته $n';
  }

  @override
  String get addDay => 'افزودن روز';

  @override
  String weekCopied(String n) {
    return 'هفته $n کپی شد';
  }

  @override
  String get weekNotEmpty => 'این هفته قبلاً حرکت دارد';

  @override
  String get categoryLabel => 'دسته‌بندی';

  @override
  String get nutritionForThisPlan => 'تغذیه این شاگرد';
}
