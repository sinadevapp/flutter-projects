import 'package:fit_coach/core/database/database_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Languages the app ships with.
const supportedLocales = [Locale('fa'), Locale('en')];

/// The language to run the UI in.
///
/// Persisted in the settings row, so the choice survives a restart. A null
/// value means "follow the device", which Flutter resolves against
/// [supportedLocales].
final appLocaleProvider =
    AsyncNotifierProvider<AppLocaleNotifier, Locale?>(AppLocaleNotifier.new);

class AppLocaleNotifier extends AsyncNotifier<Locale?> {
  @override
  Future<Locale?> build() async {
    final code = await ref.read(appDatabaseProvider).getLocaleCode();
    return code == null ? null : Locale(code);
  }

  Future<void> setLocale(Locale locale) async {
    await ref.read(appDatabaseProvider).setLocaleCode(locale.languageCode);
    state = AsyncData(locale);
  }
}
