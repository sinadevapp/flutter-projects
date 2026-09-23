import 'package:fit_coach/app/router.dart';
import 'package:fit_coach/core/settings/locale_provider.dart';
import 'package:fit_coach/core/theme/app_theme.dart';
import 'package:fit_coach/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Root widget of the FitCoach application.
class FitCoachApp extends ConsumerWidget {
  const FitCoachApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Null = follow the device; Flutter picks the best of supportedLocales.
    final locale = ref.watch(appLocaleProvider).value;

    return MaterialApp.router(
      title: 'FitCoach',
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light,
      routerConfig: buildAppRouter(),
    );
  }
}
