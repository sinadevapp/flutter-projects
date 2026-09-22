import 'package:fit_coach/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';

/// `context.l10n.save` instead of `AppLocalizations.of(context).save`.
extension LocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
