import 'package:flutter/material.dart';

/// The FitCoach visual language.
///
/// Flat by design: depth comes from surface tiers and 1px borders, never from
/// dramatic shadows — this is used on a phone, with one hand, in a gym.
/// See `docs/design-system.md` for the full reasoning.
abstract final class AppTheme {
  /// Deep teal. Health and calm without the clinical coldness of blue, and
  /// without the aggressive red of supplement branding.
  static const Color seed = Color(0xFF0F766E);

  /// The live, in-progress accent — a running rest timer, the current set.
  /// Deliberately scarce: used anywhere else it stops meaning anything.
  static const Color live = Color(0xFFEA580C);

  /// Reserved for *completed* states. Never decoration.
  static const Color done = Color(0xFF16A34A);

  static const String fontFamily = 'Vazirmatn';

  /// The design system's shape language: 12px on buttons, fields and cards.
  static const double radius = 12;

  /// Page padding. 16px, mobile-first.
  static const double pagePadding = 16;

  /// The smallest touch target allowed. This is tapped by one thumb, possibly
  /// while out of breath.
  static const double minTouchTarget = 48;

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme);

    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      textTheme: _textTheme(base.textTheme),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: const Color(0xFFF8FAFC),
        foregroundColor: scheme.onSurface,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
        ),
      ),
      // Flat: a hard shadow reads as heavy and dated on a phone.
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(minTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(minTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(minTouchTarget, minTouchTarget),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      listTileTheme: const ListTileThemeData(
        // Rows are at least 56px tall — the design system's list rule.
        minVerticalPadding: 12,
      ),
      // A list row that is not at least this tall is a mis-tap waiting to
      // happen with sweaty hands.
      visualDensity: VisualDensity.standard,
    );
  }

  /// Every text style carries Vazirmatn, with the generous line height Persian
  /// needs — its ascenders and descenders are taller than Latin's.
  static TextTheme _textTheme(TextTheme base) {
    TextStyle? style(TextStyle? s, {FontWeight? weight, double? size}) =>
        s?.copyWith(
          fontFamily: fontFamily,
          fontWeight: weight,
          fontSize: size,
          height: 1.6,
        );

    return base.copyWith(
      displayLarge: style(base.displayLarge, weight: FontWeight.w700),
      displayMedium: style(base.displayMedium, weight: FontWeight.w700),
      headlineLarge: style(base.headlineLarge, weight: FontWeight.w700),
      headlineMedium: style(base.headlineMedium, weight: FontWeight.w600),
      headlineSmall: style(base.headlineSmall, weight: FontWeight.w600),
      titleLarge: style(base.titleLarge, weight: FontWeight.w600),
      titleMedium: style(base.titleMedium, weight: FontWeight.w600),
      bodyLarge: style(base.bodyLarge),
      bodyMedium: style(base.bodyMedium),
      bodySmall: style(base.bodySmall),
      labelLarge: style(base.labelLarge, weight: FontWeight.w500),
      labelMedium: style(base.labelMedium, weight: FontWeight.w500),
    );
  }
}
