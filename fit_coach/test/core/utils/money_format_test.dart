import 'package:fit_coach/core/utils/money_format.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Toman figures in this market are large — a kilo of whey is millions — so
/// showing `2500000` raw is unreadable at a glance. These abbreviate, and keep
/// the digits Persian in Persian.
void main() {
  const fa = Locale('fa');
  const en = Locale('en');

  test('small amounts print in full with Persian digits', () {
    expect(formatToman(fa, 'تومان', 'هزار', 'میلیون', 45000), '۴۵٬۰۰۰ تومان');
  });

  test('thousands are abbreviated', () {
    // 320000 -> "320 thousand", not six digits to count.
    expect(formatToman(fa, 'تومان', 'هزار', 'میلیون', 320000), '۳۲۰ هزار تومان');
  });

  test('millions are abbreviated', () {
    // Persian uses «٫» as the decimal separator, not a Latin full stop.
    expect(
      formatToman(fa, 'تومان', 'هزار', 'میلیون', 2500000),
      '۲٫۵ میلیون تومان',
    );
  });

  test('the same numbers are plain in English', () {
    expect(formatToman(en, 'toman', 'k', 'M', 320000), '320k toman');
    expect(formatToman(en, 'toman', 'k', 'M', 2500000), '2.5M toman');
    expect(formatToman(en, 'toman', 'k', 'M', 45000), '45,000 toman');
  });

  test('a trailing .0 is dropped rather than printed', () {
    // "2.0M" reads as false precision; "2M" is what a person would say.
    expect(formatToman(en, 'toman', 'k', 'M', 2000000), '2M toman');
    expect(formatToman(fa, 'تومان', 'هزار', 'میلیون', 3000000),
        '۳ میلیون تومان');
  });

  test('zero and negative amounts do not break the formatter', () {
    // A free food has a real price of zero.
    expect(formatToman(fa, 'تومان', 'هزار', 'میلیون', 0), '۰ تومان');
    // Negative should never reach the UI, but must not crash if it does.
    expect(formatToman(fa, 'تومان', 'هزار', 'میلیون', -5000), isNotEmpty);
  });

  test('the boundary between thousands and millions is where it looks', () {
    // Just under a million still reads in thousands, grouped: 1,000k.
    expect(formatToman(en, 'toman', 'k', 'M', 999999), '1,000k toman');
    expect(formatToman(en, 'toman', 'k', 'M', 1000000), '1M toman');
  });

  test('it does not lose the magnitude it is reporting', () {
    // 2,500,000 must never render as "2.5k" — the unit has to match the scale.
    expect(formatToman(en, 'toman', 'k', 'M', 2500000), contains('M'));
    expect(formatToman(en, 'toman', 'k', 'M', 250000), contains('k'));
  });
}
