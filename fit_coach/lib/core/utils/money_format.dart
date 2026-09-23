import 'dart:ui' show Locale;

import 'package:intl/intl.dart';

/// Formats a toman amount the way a person would say it.
///
/// Prices in this market run large — a kilo of whey is millions of toman — so
/// `2500000` raw is unreadable at a glance on a phone. Below 100,000 the number
/// is grouped and shown in full; above it, abbreviated to thousands or
/// millions.
///
/// `NumberFormat` is given the locale rather than post-processed: it already
/// emits Persian digits *and* the Persian thousands separator «٬» for `fa`,
/// and plain Latin digits with `,` for `en`. Converting digits afterwards
/// would leave a Latin comma inside a Persian number.
///
/// The unit words are passed in rather than read from `context.l10n`, so this
/// stays a pure function a unit test can call without a widget tree.
String formatToman(
  Locale locale,
  String unit,
  String thousandWord,
  String millionWord,
  num amount,
) {
  final negative = amount < 0;
  final value = amount.abs();
  final tag = locale.languageCode;

  String format(num v, {int decimals = 1}) {
    final pattern = decimals > 0 ? '#,##0.#' : '#,##0';
    return NumberFormat(pattern, tag).format(v);
  }

  // Persian writes the scale word as a separate word — «۳۲۰ هزار» — while
  // English suffix notation joins it — "320k". That is a real difference
  // between the two conventions, not a detail to paper over.
  final gap = tag == 'fa' ? ' ' : '';

  final String body;
  if (value >= 1000000) {
    body = '${format(value / 1000000)}$gap$millionWord';
  } else if (value >= 100000) {
    // Six digits is more than the eye can hold at a glance; 45,000 is not.
    body = '${format(value / 1000, decimals: 0)}$gap$thousandWord';
  } else {
    body = format(value, decimals: 0);
  }

  return '${negative ? '-' : ''}$body $unit'.trim();
}
