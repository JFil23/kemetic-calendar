import 'package:mobile/core/kemetic_converter.dart';
import 'package:flutter_test/flutter_test.dart';


void main() {
  final conv = KemeticConverter();

  test('Epoch -> Kemetic Y1 M1 D1', () {
    final kd = conv.fromGregorian(DateTime(2025, 3, 20));
    expect(kd.year, 1);
    expect(kd.month, 1);
    expect(kd.day, 1);
    expect(kd.epagomenal, false);
  });

  test('Month boundary', () {
    final endThoth = conv.fromGregorian(DateTime(2025, 4, 18));
    expect(endThoth.month, 1);
    expect(endThoth.day, 30);

    final phaophi1 = conv.fromGregorian(DateTime(2025, 4, 19));
    expect(phaophi1.month, 2);
    expect(phaophi1.day, 1);
  });

  test('Epagomenal 5 days (non-leap Kemetic year)', () {
    final epi1 = conv.fromGregorian(DateTime(2026, 3, 15));
    expect(epi1.epagomenal, true);
    expect(epi1.year, 1);
    expect(epi1.day, 1);

    final epi5 = conv.fromGregorian(DateTime(2026, 3, 19));
    expect(epi5.epagomenal, true);
    expect(epi5.day, 5);

    final y2d1 = conv.fromGregorian(DateTime(2026, 3, 20));
    expect(y2d1.year, 2);
    expect(y2d1.month, 1);
    expect(y2d1.day, 1);
  });

  test('Leap rule: 6th epagomenal appears around Mar 2028', () {
    final d18 = conv.fromGregorian(DateTime(2028, 3, 18));
    final d19 = conv.fromGregorian(DateTime(2028, 3, 19));
    final d20 = conv.fromGregorian(DateTime(2028, 3, 20));
    final has6 = [d18, d19, d20].any((k) => k.epagomenal && k.day == 6);
    expect(has6, true);
  });

  test('Roundtrip Kemetic -> Gregorian -> Kemetic', () {
    final kd = KemeticDate(year: 3, month: 7, day: 12, epagomenal: false);
    final g = conv.toGregorianMidnight(kd);
    final back = conv.fromGregorian(g);
    expect(back.year, kd.year);
    expect(back.month, kd.month);
    expect(back.day, kd.day);
    expect(back.epagomenal, false);
  });
}
