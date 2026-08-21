import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart';

void main() {
  final now = DateTime(2026, 8, 19, 12);

  QuickAddParse parse(String raw) {
    final parsed = CalendarPage.parseQuickAddText(raw, now: now);
    expect(parsed, isNotNull, reason: 'expected a parse for "$raw"');
    return parsed!;
  }

  DateTime day(int year, int month, int day) => DateTime(year, month, day);

  DateTime kemeticDay(int monthId, int dayNumber) {
    final current = KemeticMath.fromGregorian(now);
    for (var offset = 0; offset <= 4; offset++) {
      try {
        final utc = KemeticMath.toGregorian(
          current.kYear + offset,
          monthId,
          dayNumber,
        );
        final local = DateTime(utc.year, utc.month, utc.day);
        if (!local.isBefore(DateUtils.dateOnly(now)) || offset > 0) {
          return local;
        }
      } catch (_) {
        continue;
      }
    }
    fail('Could not resolve Kemetic $monthId/$dayNumber from $now');
  }

  group('Quick Add parser', () {
    test('dinner with Mike at 6pm in Beverly Hills', () {
      final parsed = parse('dinner with Mike at 6pm in Beverly Hills');
      expect(parsed.title, 'dinner with Mike');
      expect(parsed.allDay, isFalse);
      expect(parsed.start, const TimeOfDay(hour: 18, minute: 0));
      expect(parsed.end, const TimeOfDay(hour: 19, minute: 0));
      expect(parsed.location, 'Beverly Hills');
      expect(parsed.date, day(2026, 8, 19));
    });

    test('dentist tomorrow at 2', () {
      final parsed = parse('dentist tomorrow at 2');
      expect(parsed.title, 'dentist');
      expect(parsed.date, day(2026, 8, 20));
      expect(parsed.start, const TimeOfDay(hour: 2, minute: 0));
      expect(parsed.end, const TimeOfDay(hour: 3, minute: 0));
      expect(parsed.location, isNull);
    });

    test('call mom on Friday at noon', () {
      final parsed = parse('call mom on Friday at noon');
      expect(parsed.title, 'call mom');
      expect(parsed.date, day(2026, 8, 21));
      expect(parsed.start, const TimeOfDay(hour: 12, minute: 0));
      expect(parsed.end, const TimeOfDay(hour: 13, minute: 0));
    });

    test('workout for an hour at 7am', () {
      final parsed = parse('workout for an hour at 7am');
      expect(parsed.title, 'workout');
      expect(parsed.start, const TimeOfDay(hour: 7, minute: 0));
      expect(parsed.end, const TimeOfDay(hour: 8, minute: 0));
    });

    test('meet James at Soho House at 8', () {
      final parsed = parse('meet James at Soho House at 8');
      expect(parsed.title, 'meet James');
      expect(parsed.location, 'Soho House');
      expect(parsed.start, const TimeOfDay(hour: 8, minute: 0));
      expect(parsed.end, const TimeOfDay(hour: 9, minute: 0));
    });

    test('work in silence at 6 keeps non-location in', () {
      final parsed = parse('work in silence at 6');
      expect(parsed.title, 'work in silence');
      expect(parsed.location, isNull);
      expect(parsed.start, const TimeOfDay(hour: 6, minute: 0));
    });

    test('dinner from 6 to 8 owns the range phrase', () {
      final parsed = parse('dinner from 6 to 8');
      expect(parsed.title, 'dinner');
      expect(parsed.start, const TimeOfDay(hour: 6, minute: 0));
      expect(parsed.end, const TimeOfDay(hour: 8, minute: 0));
    });

    test('Gregorian numeric and month-name dates', () {
      final slash = parse('flight 3/15 at 9am');
      expect(slash.title, 'flight');
      expect(slash.date, day(2027, 3, 15));
      expect(slash.start, const TimeOfDay(hour: 9, minute: 0));

      final named = parse('exam on March 15 at 3pm');
      expect(named.title, 'exam');
      expect(named.date, day(2027, 3, 15));
      expect(named.start, const TimeOfDay(hour: 15, minute: 0));
      expect(named.end, const TimeOfDay(hour: 16, minute: 0));
    });

    test('today, tomorrow, in N days, and weekdays', () {
      expect(parse('stand-up today').date, day(2026, 8, 19));
      expect(parse('stand-up today').title, 'stand-up');
      expect(parse('trip in 3 days').date, day(2026, 8, 22));
      expect(parse('trip in 3 days').title, 'trip');
      expect(parse('sync next Monday').date, day(2026, 8, 24));
      expect(parse('sync next Monday').title, 'sync');
    });

    test('Kemetic month and date forms resolve through KemeticMath', () {
      final rekh = parse('dinner on Rekh-Wer 8 at 6pm');
      expect(rekh.title, 'dinner');
      expect(rekh.date, kemeticDay(6, 8));
      expect(rekh.start, const TimeOfDay(hour: 18, minute: 0));

      final paopi = parse('call mom Paopi 12');
      expect(paopi.title, 'call mom');
      expect(paopi.date, kemeticDay(2, 12));
      expect(paopi.allDay, isTrue);

      final hathor = parse('appointment Hathor 3 at 10am');
      expect(hathor.title, 'appointment');
      expect(hathor.date, kemeticDay(3, 3));
      expect(hathor.start, const TimeOfDay(hour: 10, minute: 0));

      final mechir = parse('lab Mechir 4');
      expect(mechir.title, 'lab');
      expect(mechir.date, kemeticDay(6, 4));
    });

    test(
      'keeps ordinary at/on/in/for words that are not scheduling syntax',
      () {
        expect(parse('looking at notes tomorrow').title, 'looking at notes');
        expect(parse('gift for mom on Friday').title, 'gift for mom');
        expect(parse('conference on AI on Friday').title, 'conference on AI');
        expect(parse('work in silence').title, 'work in silence');
        expect(parse('work in silence').allDay, isTrue);
      },
    );

    test('empty input is rejected', () {
      expect(CalendarPage.parseQuickAddText('   ', now: now), isNull);
    });
  });

  group('Quick Add save mapping', () {
    test('mounted and detached saves pass the parsed location through', () {
      final source = File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsStringSync();

      final mountedSave = source.substring(
        source.indexOf('Future<void> _openQuickAddSheet() async {'),
        source.indexOf('  /* ───── UI ───── */'),
      );
      expect(mountedSave, contains('location: parsed.location'));
      expect(mountedSave, isNot(contains('location: null')));

      expect(source, contains('location: parsed.location'));
      expect(source, contains("caller: 'save_single_detached'"));
      final detachedSave = source.substring(
        source.indexOf('static Future<void> _saveDetachedQuickAddNote('),
        source.indexOf("caller: 'save_single_detached'"),
      );
      expect(detachedSave, contains('location: parsed.location'));
    });
  });
}
