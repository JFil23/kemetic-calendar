import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/hydration/calendar_coverage_ledger.dart';
import 'package:mobile/features/calendar/hydration/calendar_hydration_models.dart';

void main() {
  group('catalog fingerprint', () {
    CalendarCatalogFingerprintRow row({
      int id = 1,
      Object? rules = const <String, Object?>{
        'type': 'week',
        'days': <int>[1, 2],
      },
      String name = 'Flow',
    }) => CalendarCatalogFingerprintRow(
      id: id,
      userId: 'user',
      calendarId: 'calendar',
      name: name,
      color: 0x123456,
      active: true,
      isSaved: false,
      startDate: DateTime(2026, 8, 1),
      endDate: DateTime(2026, 8, 31),
      notes: 'notes',
      rules: rules,
      shareId: null,
      isHidden: false,
      isReminder: false,
      reminderUuid: null,
    );

    test('is stable across row and map-key ordering', () {
      final first = computeCalendarCatalogFingerprint(
        <CalendarCatalogFingerprintRow>[
          row(id: 2),
          row(
            id: 1,
            rules: <String, Object?>{
              'days': <int>[1, 2],
              'type': 'week',
            },
          ),
        ],
      );
      final second = computeCalendarCatalogFingerprint(
        <CalendarCatalogFingerprintRow>[
          row(id: 1, rules: '{"type":"week","days":[1,2]}'),
          row(id: 2),
        ],
      );

      expect(first, second);
      expect(first, startsWith('$calendarCatalogFingerprintVersion:'));
      expect(first.length, calendarCatalogFingerprintVersion.length + 1 + 64);
    });

    test('changes when an authority-affecting field changes', () {
      expect(
        computeCalendarCatalogFingerprint(<CalendarCatalogFingerprintRow>[
          row(),
        ]),
        isNot(
          computeCalendarCatalogFingerprint(<CalendarCatalogFingerprintRow>[
            row(name: 'Changed'),
          ]),
        ),
      );
    });
  });

  group('intervals and coverage', () {
    CalendarHydrationInterval interval(int startDay, int endDay) =>
        CalendarHydrationInterval(
          startUtc: DateTime.utc(2026, 8, startDay),
          endUtc: DateTime.utc(2026, 8, endDay),
        );

    test('merges touching and overlapping coverage', () {
      final ledger = CalendarCoverageLedger.empty('a')
          .add(fingerprint: 'a', interval: interval(1, 4))
          .add(fingerprint: 'a', interval: interval(4, 7))
          .add(fingerprint: 'a', interval: interval(6, 9));

      expect(ledger.intervals, <CalendarHydrationInterval>[interval(1, 9)]);
      expect(ledger.covers(interval(2, 8)), isTrue);
    });

    test('fingerprint change invalidates previous coverage', () {
      final ledger = CalendarCoverageLedger.empty('old')
          .add(fingerprint: 'old', interval: interval(1, 9))
          .add(fingerprint: 'new', interval: interval(10, 12));

      expect(ledger.catalogFingerprint, 'new');
      expect(ledger.intervals, <CalendarHydrationInterval>[interval(10, 12)]);
    });

    test('returns exact gaps within a horizon', () {
      final ledger = CalendarCoverageLedger.empty('a')
          .add(fingerprint: 'a', interval: interval(2, 4))
          .add(fingerprint: 'a', interval: interval(6, 8));

      expect(ledger.gapsWithin(interval(1, 9)), <CalendarHydrationInterval>[
        interval(1, 2),
        interval(4, 6),
        interval(8, 9),
      ]);
    });

    test('builds half-open boundaries with local calendar arithmetic', () {
      final range = CalendarHydrationInterval.fromInclusiveLocalDays(
        firstLocalDay: DateTime(2026, 3, 8),
        lastLocalDay: DateTime(2026, 3, 9),
      );

      expect(range.startUtc, DateTime(2026, 3, 8).toUtc());
      expect(range.endUtc, DateTime(2026, 3, 10).toUtc());
    });
  });
}
