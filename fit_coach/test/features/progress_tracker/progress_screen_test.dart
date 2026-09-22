import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:fit_coach/core/database/test_database.dart';
import 'package:fit_coach/core/utils/persian_digits.dart';
import 'package:fit_coach/features/auth/presentation/role_picker_screen.dart';
import 'package:fit_coach/features/progress_tracker/presentation/progress_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../helpers/localized_app.dart';

/// The app ships in Persian and English, and the same data has to read
/// correctly in both — including the calendar.
void main() {
  testWidgets('the role picker speaks each language', (tester) async {
    final db = createTestDatabase();
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: testApp(home: const RolePickerScreen(), locale: const Locale('en')),
      ),
    );
    expect(find.text('Choose your role'), findsOneWidget);
    expect(find.text('Coach'), findsOneWidget);
    expect(find.text('Student'), findsOneWidget);
    expect(find.text('مربی'), findsNothing);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: testApp(home: const RolePickerScreen()),
      ),
    );
    expect(find.text('نقش خود را انتخاب کنید'), findsOneWidget);
    expect(find.text('Coach'), findsNothing);
  });

  testWidgets('progress history dates are Jalali in Persian, Gregorian in English',
      (tester) async {
    Future<void> pumpProgress(Locale locale) async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final studentId = await db.insertUser(
        UsersCompanion.insert(name: 'علی', role: UserRole.student),
      );
      final planId = await db.insertWorkoutPlan(
        WorkoutPlansCompanion.insert(studentId: studentId, title: 'برنامه حجم'),
      );
      final squatId = await db.insertExercise(ExercisesCompanion.insert(
        planId: planId,
        name: 'اسکوات',
        sets: 1,
        reps: 10,
      ));
      final sessionId = await db.startWorkoutSession(
        planId: planId,
        studentId: studentId,
      );
      await db.logSet(sessionId: sessionId, exerciseId: squatId, setNumber: 1);
      await db.finishWorkoutSession(sessionId);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: testApp(
            home: ProgressScreen(studentId: studentId),
            locale: locale,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpProgress(const Locale('fa'));
    expect(find.text('پیشرفت من'), findsOneWidget);
    expect(find.text('۱'), findsWidgets); // one completed workout, Persian digit
    // The week label uses the Persian calendar; ask the calendar library what
    // this week's Jalali year is, rather than hard-coding one.
    final jalaliYear = fa(Jalali.fromDateTime(DateTime.now()).year);
    expect(find.textContaining(jalaliYear), findsOneWidget);

    await pumpProgress(const Locale('en'));
    expect(find.text('My progress'), findsOneWidget);
    expect(find.textContaining('${DateTime.now().year}/'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
