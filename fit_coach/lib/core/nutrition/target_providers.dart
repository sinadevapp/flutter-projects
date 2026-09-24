import 'package:drift/drift.dart' show Value;
import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/core/database/database_provider.dart';
import 'package:fit_coach/core/nutrition/nutrition_target.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A stored profile as the domain sees it.
///
/// The enum indices are the seam between storage and logic: the domain enum
/// owns the ordering, and this is the only place that trusts it.
NutritionProfile profileFromRow(NutritionTargetsRow row) => NutritionProfile(
      sex: Sex.values[row.sex],
      age: row.age,
      heightCm: row.heightCm,
      weightKg: row.weightKg,
      activity: ActivityLevel.values[row.activity],
      goal: Goal.values[row.goal],
    );

/// One student's saved nutrition profile, or null before the coach sets one.
final nutritionProfileProvider =
    StreamProvider.autoDispose.family<NutritionTargetsRow?, int>(
        (ref, studentId) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.nutritionTargets)
        ..where((t) => t.studentId.equals(studentId)))
      .watchSingleOrNull();
});

/// The daily targets estimated from that profile.
///
/// Null when there is no profile yet — the screen shows a prompt instead of
/// inventing a default student to estimate from.
final nutritionTargetsProvider =
    Provider.autoDispose.family<NutritionTarget?, int>((ref, studentId) {
  final profile = ref.watch(nutritionProfileProvider(studentId)).value;
  if (profile == null) return null;
  return estimateTargets(profileFromRow(profile));
});

/// Stores a profile for [studentId], replacing any previous one.
Future<void> saveProfile(
  AppDatabase db,
  int studentId,
  NutritionProfile profile,
) =>
    db.saveNutritionTarget(
      NutritionTargetsCompanion.insert(
        studentId: Value(studentId),
        sex: profile.sex.index,
        age: profile.age,
        heightCm: profile.heightCm,
        weightKg: profile.weightKg,
        activity: profile.activity.index,
        goal: profile.goal.index,
      ),
    );
