import 'package:fit_coach/core/database/app_database.dart';
import 'package:fit_coach/l10n/app_localizations.dart';

/// The localized name of a movement's category.
///
/// A function in `core/` rather than a switch in each screen: the authoring
/// form, the edit list and the movement dialog all label the same seven
/// values, and a second switch would be a second place for the words to
/// drift apart.
String categoryLabel(AppLocalizations l10n, ExerciseCategory category) =>
    switch (category) {
      ExerciseCategory.legs => l10n.catLegs,
      ExerciseCategory.chest => l10n.catChest,
      ExerciseCategory.shoulders => l10n.catShoulders,
      ExerciseCategory.back => l10n.catBack,
      ExerciseCategory.arms => l10n.catArms,
      ExerciseCategory.core => l10n.catCore,
      ExerciseCategory.compound => l10n.catCompound,
    };
