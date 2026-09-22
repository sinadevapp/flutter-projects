import 'package:fit_coach/core/utils/date_format.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const fa = Locale('fa');
  const en = Locale('en');
  final date = DateTime(2026, 9, 21); // Monday

  test('Persian dates are Jalali with Persian digits', () {
    expect(localizeDate(fa, date), '۱۴۰۵/۰۶/۳۰');
  });

  test('English dates stay Gregorian with plain digits', () {
    expect(localizeDate(en, date), '2026/09/21');
  });

  test('the Persian week starts on Saturday', () {
    // Monday 21 Sep 2026 -> the Saturday before it.
    expect(startOfWeek(fa, date), DateTime(2026, 9, 19));
  });

  test('the English week starts on Monday', () {
    expect(startOfWeek(en, date), DateTime(2026, 9, 21));
  });

  test('numbers follow the language', () {
    expect(localizeNumber(fa, 12), '۱۲');
    expect(localizeNumber(en, 12), '12');
  });
}
