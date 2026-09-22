import 'package:fit_coach/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Localizations every test tree needs.
///
/// A screen that renders `context.l10n` throws without these, so tests pump
/// their widget through one of the helpers below instead of a bare
/// `MaterialApp`.
const _delegates = [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// Persian (the primary language) by default, so assertions read naturally.
const testLocale = Locale('fa');

/// A single screen inside a localized [MaterialApp].
Widget testApp({required Widget home, Locale locale = testLocale}) =>
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: _delegates,
      home: home,
    );

/// The real router inside a localized [MaterialApp.router].
Widget testRouterApp({
  required RouterConfig<Object> routerConfig,
  Locale locale = testLocale,
}) =>
    MaterialApp.router(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: _delegates,
      routerConfig: routerConfig,
    );
