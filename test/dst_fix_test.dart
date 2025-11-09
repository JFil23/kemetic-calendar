import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/kemetic_time_constants.dart';

void main() {
  group('DST Bug Fix Verification', () {
    test('UTC epoch increments are DST-safe (fall back 2025-11-02)', () {
      // November 2, 2025 is when US DST falls back
      // Days from March 20, 2025 to November 1, 2, 3:
      final nov1 = kKemeticEpochUtc.add(const Duration(days: 226));
      final nov2 = kKemeticEpochUtc.add(const Duration(days: 227));
      final nov3 = kKemeticEpochUtc.add(const Duration(days: 228));
      
      expect(nov1.year, 2025);
      expect(nov1.month, 11);
      expect(nov1.day, 1);
      expect(nov2.day, 2, reason: 'November 2 must not duplicate');
      expect(nov3.day, 3);
    });

    test('Local display at noon is stable across fall back', () {
      final dUtc = DateTime.utc(2025, 11, 2);
      final display = safeLocalDisplay(dUtc);
      
      expect(display.year, 2025);
      expect(display.month, 11);
      expect(display.day, 2);
      expect(display.hour, 12, reason: 'Should be at noon to avoid DST midnight');
    });

    test('Spring forward 2026-03-08 is stable', () {
      // March 8, 2026 is spring forward in US
      final d1 = DateTime.utc(2026, 3, 7);
      final d2 = d1.add(const Duration(days: 1));
      final d3 = d2.add(const Duration(days: 1));
      
      expect(d2.day, 8, reason: 'March 8 must not be skipped');
      expect(d3.day, 9);
    });

    test('Kemetic Month 8 Days 16-20 map to unique November dates', () {
      // The problematic range where November 2 was duplicating
      final dates = <int, int>{};
      
      for (int kDay = 16; kDay <= 20; kDay++) {
        final gDate = KemeticMath.toGregorian(1, 8, kDay);
        final localDisplay = safeLocalDisplay(gDate);
        
        expect(dates.containsKey(localDisplay.day), false,
            reason: 'Day ${localDisplay.day} appeared twice for Kemetic days $kDay and ${dates[localDisplay.day]}');
        
        dates[localDisplay.day] = kDay;
      }
      
      // Should map to: 31 (Oct), 1, 2, 3, 4 (Nov)
      expect(dates.keys.toList()..sort(), [31, 1, 2, 3, 4]);
    });

    test('Entire Month 8 has no duplicate Gregorian days', () {
      final gregorianDays = <int>[];
      
      for (int kDay = 1; kDay <= 30; kDay++) {
        final gDate = KemeticMath.toGregorian(1, 8, kDay);
        final localDisplay = safeLocalDisplay(gDate);
        gregorianDays.add(localDisplay.day);
      }
      
      final uniqueDays = gregorianDays.toSet();
      expect(gregorianDays.length, uniqueDays.length,
          reason: 'Found duplicate Gregorian day numbers in Month 8');
    });

    test('Round-trip: toGregorian -> fromGregorian preserves Kemetic date', () {
      // Test around DST boundaries
      final testCases = [
        (1, 8, 16), // Oct 31
        (1, 8, 17), // Nov 1
        (1, 8, 18), // Nov 2 (DST fall back)
        (1, 8, 19), // Nov 3
        (1, 8, 20), // Nov 4
      ];
      
      for (final (ky, km, kd) in testCases) {
        final gUtc = KemeticMath.toGregorian(ky, km, kd);
        final roundTrip = KemeticMath.fromGregorian(gUtc);
        
        expect(roundTrip.kYear, ky,
            reason: 'Year mismatch for K($ky,$km,$kd)');
        expect(roundTrip.kMonth, km,
            reason: 'Month mismatch for K($ky,$km,$kd)');
        expect(roundTrip.kDay, kd,
            reason: 'Day mismatch for K($ky,$km,$kd)');
      }
    });

    test('Round-trip: fromGregorian -> toGregorian preserves date', () {
      final testDates = [
        DateTime.utc(2025, 10, 31), // Before DST
        DateTime.utc(2025, 11, 1),  // DST fall back night
        DateTime.utc(2025, 11, 2),  // DST fall back day
        DateTime.utc(2025, 11, 3),  // After DST
        DateTime.utc(2026, 3, 7),   // Before spring forward
        DateTime.utc(2026, 3, 8),   // Spring forward day
        DateTime.utc(2026, 3, 9),   // After spring forward
      ];
      
      for (final gUtc in testDates) {
        final k = KemeticMath.fromGregorian(gUtc);
        final roundTrip = KemeticMath.toGregorian(k.kYear, k.kMonth, k.kDay);
        final rtUtc = toUtcDateOnly(roundTrip);
        
        expect(rtUtc.year, gUtc.year,
            reason: 'Year mismatch for ${gUtc.toIso8601String()}');
        expect(rtUtc.month, gUtc.month,
            reason: 'Month mismatch for ${gUtc.toIso8601String()}');
        expect(rtUtc.day, gUtc.day,
            reason: 'Day mismatch for ${gUtc.toIso8601String()}');
      }
    });

    test('Dates before epoch work correctly (negative offsets)', () {
      // Test that negative day counts work
      final beforeEpoch = DateTime.utc(2025, 3, 19); // One day before epoch
      final k = KemeticMath.fromGregorian(beforeEpoch);
      final roundTrip = KemeticMath.toGregorian(k.kYear, k.kMonth, k.kDay);
      
      expect(toUtcDateOnly(roundTrip), beforeEpoch);
    });

    test('Integer epoch-day helpers are consistent', () {
      final testDate = DateTime.utc(2025, 11, 2);
      final epochDays = epochDayFromUtc(testDate);
      final reconstructed = utcFromEpochDay(epochDays);
      
      expect(reconstructed, testDate);
    });
  });
}


