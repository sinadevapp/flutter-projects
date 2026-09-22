import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fa.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fa'),
  ];

  /// No description provided for @rolePickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your role'**
  String get rolePickerTitle;

  /// No description provided for @coach.
  ///
  /// In en, this message translates to:
  /// **'Coach'**
  String get coach;

  /// No description provided for @student.
  ///
  /// In en, this message translates to:
  /// **'Student'**
  String get student;

  /// No description provided for @addStudent.
  ///
  /// In en, this message translates to:
  /// **'Add student'**
  String get addStudent;

  /// No description provided for @studentNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Student name'**
  String get studentNameLabel;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get nameRequired;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @studentAdded.
  ///
  /// In en, this message translates to:
  /// **'Student added'**
  String get studentAdded;

  /// No description provided for @noStudentsYet.
  ///
  /// In en, this message translates to:
  /// **'No students added yet'**
  String get noStudentsYet;

  /// No description provided for @noStudentsRegistered.
  ///
  /// In en, this message translates to:
  /// **'No students registered yet'**
  String get noStudentsRegistered;

  /// No description provided for @switchRole.
  ///
  /// In en, this message translates to:
  /// **'Switch role'**
  String get switchRole;

  /// No description provided for @myPlans.
  ///
  /// In en, this message translates to:
  /// **'My plans'**
  String get myPlans;

  /// No description provided for @plansForStudent.
  ///
  /// In en, this message translates to:
  /// **'Plans for {name}'**
  String plansForStudent(String name);

  /// No description provided for @noPlansForStudent.
  ///
  /// In en, this message translates to:
  /// **'No plan built yet'**
  String get noPlansForStudent;

  /// No description provided for @noPlansForMe.
  ///
  /// In en, this message translates to:
  /// **'No plan has been built for you yet'**
  String get noPlansForMe;

  /// No description provided for @newPlan.
  ///
  /// In en, this message translates to:
  /// **'New plan'**
  String get newPlan;

  /// No description provided for @planTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Plan title'**
  String get planTitleLabel;

  /// No description provided for @planTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a plan title'**
  String get planTitleRequired;

  /// No description provided for @movements.
  ///
  /// In en, this message translates to:
  /// **'Movements'**
  String get movements;

  /// No description provided for @addMovement.
  ///
  /// In en, this message translates to:
  /// **'Add movement'**
  String get addMovement;

  /// No description provided for @movementNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Movement name'**
  String get movementNameLabel;

  /// No description provided for @setsLabel.
  ///
  /// In en, this message translates to:
  /// **'Sets'**
  String get setsLabel;

  /// No description provided for @repsLabel.
  ///
  /// In en, this message translates to:
  /// **'Reps'**
  String get repsLabel;

  /// No description provided for @setsXReps.
  ///
  /// In en, this message translates to:
  /// **'{sets} × {reps}'**
  String setsXReps(String sets, String reps);

  /// No description provided for @planHasNoMovements.
  ///
  /// In en, this message translates to:
  /// **'This plan has no movements'**
  String get planHasNoMovements;

  /// No description provided for @startWorkout.
  ///
  /// In en, this message translates to:
  /// **'Start workout'**
  String get startWorkout;

  /// No description provided for @resumeWorkout.
  ///
  /// In en, this message translates to:
  /// **'Resume workout'**
  String get resumeWorkout;

  /// No description provided for @completeSet.
  ///
  /// In en, this message translates to:
  /// **'Set done'**
  String get completeSet;

  /// No description provided for @finishWorkout.
  ///
  /// In en, this message translates to:
  /// **'Finish workout'**
  String get finishWorkout;

  /// No description provided for @workoutComplete.
  ///
  /// In en, this message translates to:
  /// **'Workout complete'**
  String get workoutComplete;

  /// No description provided for @setOf.
  ///
  /// In en, this message translates to:
  /// **'Set {current} of {total}'**
  String setOf(String current, String total);

  /// No description provided for @setsProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} sets'**
  String setsProgress(String done, String total);

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @myProgress.
  ///
  /// In en, this message translates to:
  /// **'My progress'**
  String get myProgress;

  /// No description provided for @completedWorkouts.
  ///
  /// In en, this message translates to:
  /// **'Workouts completed'**
  String get completedWorkouts;

  /// No description provided for @totalSetsDone.
  ///
  /// In en, this message translates to:
  /// **'Total sets'**
  String get totalSetsDone;

  /// No description provided for @weeklyTrend.
  ///
  /// In en, this message translates to:
  /// **'Weekly trend'**
  String get weeklyTrend;

  /// No description provided for @volumeByMovement.
  ///
  /// In en, this message translates to:
  /// **'Volume by movement'**
  String get volumeByMovement;

  /// No description provided for @noHistoryYet.
  ///
  /// In en, this message translates to:
  /// **'No workouts recorded yet'**
  String get noHistoryYet;

  /// No description provided for @weekOf.
  ///
  /// In en, this message translates to:
  /// **'Week of {date}'**
  String weekOf(String date);

  /// No description provided for @setsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} sets'**
  String setsCount(String count);

  /// No description provided for @weekStart.
  ///
  /// In en, this message translates to:
  /// **'Week starts: {day}'**
  String weekStart(String day);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fa'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fa':
      return AppLocalizationsFa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
