import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/features/coach_hub/presentation/edit_student_screen.dart';
import 'package:fit_coach/features/nutrition_budget/presentation/nutrition_screen.dart';
import 'package:fit_coach/features/nutrition_budget/presentation/student_nutrition_screen.dart';
import 'package:fit_coach/features/progress_tracker/presentation/progress_screen.dart';
import 'package:fit_coach/features/workout_active/presentation/active_workout_screen.dart';
import 'package:fit_coach/features/workout_builder/presentation/student_detail_screen.dart';
import 'package:flutter/material.dart';

/// Where a screen is opened from.
///
/// **This file is why no feature imports another feature's screens.** It
/// sits in `app/`, the composition layer that already wires roles to screens
/// in `router.dart`, so features ask *it* to navigate instead of pulling a
/// sibling's widget in directly.
///
/// The rule in `CLAUDE.md` (§6 rule 1) was being violated by nine call sites
/// across three features. Routing to them — rather than importing them — was
/// already named as the intended fix; this is that fix, kept as plain
/// navigation so it needs no route plumbing to achieve it.
///
/// Everything below is a screen the *caller* could not reach without
/// depending on another feature.
extension AppNavigation on BuildContext {
  /// The coach opens one student's workspace: plans, history, nutrition.
  Future<void> openStudentDetail(User student) => _push(StudentDetailScreen(
        student: student,
      ));

  /// Corrects a student's name, photo or type.
  Future<void> openEditStudent(User student) => _push(EditStudentScreen(
        student: student,
      ));

  /// The coach sets the nutrition profile for a student they are working with.
  Future<void> openCoachNutrition(User student) => _push(NutritionScreen(
        student: student,
      ));

  /// A student sets their own profile.
  Future<void> openStudentNutrition(int studentId) => _push(
        StudentNutritionScreen(studentId: studentId),
      );

  /// The student's own history — framed as "my progress".
  Future<void> openMyProgress(int studentId) => _push(ProgressScreen(
        studentId: studentId,
      ));

  /// The coach reading one student's history — framed as theirs, not the
  /// reader's.
  Future<void> openStudentProgress({
    required int studentId,
    required String studentName,
  }) =>
      _push(ProgressScreen.forCoach(
        studentId: studentId,
        studentName: studentName,
      ));

  /// Trains one day of a plan, or resumes it if it is already open.
  Future<void> openActiveWorkout({
    required int sessionId,
    required WorkoutPlan plan,
  }) =>
      _push(ActiveWorkoutScreen(sessionId: sessionId, plan: plan));

  Future<void> _push(Widget screen) async =>
      Navigator.of(this).push(MaterialPageRoute(builder: (_) => screen));
}
