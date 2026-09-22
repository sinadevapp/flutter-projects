import 'package:flutter/widgets.dart';
import 'package:shamsi_date/shamsi_date.dart';

import 'persian_digits.dart';

/// Persian digits for Persian, plain digits for English.
///
/// Every user-facing number goes through this, so the two languages stay
/// consistent (see the `fa()` helper for the conversion itself).
String localizeNumber(Locale locale, Object value) =>
    locale.languageCode == 'fa' ? fa(value) : value.toString();

/// Formats a date the way the language expects it:
/// Persian → Jalali (شمسی), English → Gregorian (ISO-ish).
///
/// [DateTime] values coming out of Drift are local times.
String localizeDate(Locale locale, DateTime date) {
  if (locale.languageCode == 'fa') {
    final jalali = Jalali.fromDateTime(date);
    final month = jalali.month.toString().padLeft(2, '0');
    final day = jalali.day.toString().padLeft(2, '0');
    return fa('${jalali.year}/$month/$day');
  }
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}/$month/$day';
}

/// Start of the calendar week the language uses, used to group history.
///
/// Persian weeks start on Saturday (شنبه); Gregorian ones start on Monday.
DateTime startOfWeek(Locale locale, DateTime date) {
  final start = DateTime(date.year, date.month, date.day);
  if (locale.languageCode == 'fa') {
    // DateTime.weekday: Sat = 6.
    return start.subtract(Duration(days: (start.weekday + 1) % 7));
  }
  return start.subtract(Duration(days: start.weekday - 1));
}
