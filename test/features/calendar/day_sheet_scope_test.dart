import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/day_sheet_scope.dart';

void main() {
  group('Day Sheet selected-day scoping', () {
    final selected = DateTime(2026, 6, 21);
    final previous = selected.subtract(const Duration(days: 1));
    final next = selected.add(const Duration(days: 1));

    DaySheetListCandidate item(
      String title, {
      required DateTime start,
      required DateTime end,
      String sourceType = 'note',
      String? eventId,
      String? clientEventId,
      int? flowId,
      String? reminderId,
      bool allDay = false,
    }) {
      return DaySheetListCandidate(
        title: title,
        sourceType: sourceType,
        allDay: allDay,
        startsAtLocal: start,
        endsAtLocal: end,
        eventId: eventId,
        clientEventId: clientEventId,
        flowId: flowId,
        reminderId: reminderId,
      );
    }

    List<DaySheetListCandidate> scoped(
      DateTime day,
      List<DaySheetListCandidate> candidates,
    ) {
      return filterAndDedupeDaySheetCandidates(
        candidates,
        window: daySheetWindowFor(day),
        candidateOf: (candidate) => candidate,
      );
    }

    test('keeps only rows overlapping the selected day', () {
      final rows = scoped(selected, [
        item(
          'previous',
          start: previous.add(const Duration(hours: 9)),
          end: previous.add(const Duration(hours: 10)),
        ),
        item(
          'all-day selected',
          allDay: true,
          start: selected,
          end: next,
          flowId: 10,
          sourceType: 'computed_flow',
        ),
        item(
          'timed selected',
          start: selected.add(const Duration(hours: 8)),
          end: selected.add(const Duration(hours: 8, minutes: 30)),
        ),
        item(
          'next',
          start: next.add(const Duration(hours: 9)),
          end: next.add(const Duration(hours: 10)),
        ),
      ]);

      expect(rows.map((row) => row.title), [
        'all-day selected',
        'timed selected',
      ]);
      expect(rows.length, 2);
    });

    test('recomputes visible rows when the picker date changes', () {
      final candidates = [
        item(
          'selected day flow',
          sourceType: 'computed_flow',
          flowId: 21,
          start: selected.add(const Duration(hours: 7)),
          end: selected.add(const Duration(hours: 8)),
        ),
        item(
          'next day flow',
          sourceType: 'computed_flow',
          flowId: 22,
          start: next.add(const Duration(hours: 7)),
          end: next.add(const Duration(hours: 8)),
        ),
      ];

      expect(scoped(selected, candidates).single.title, 'selected day flow');
      expect(scoped(next, candidates).single.title, 'next day flow');
    });

    test('excludes same-decan off-day flows and empty template candidates', () {
      final rows = scoped(selected, [
        item(
          'same decan off-day flow',
          sourceType: 'computed_flow',
          flowId: 30,
          start: next.add(const Duration(hours: 12)),
          end: next.add(const Duration(hours: 13)),
        ),
        // A template with no selected-day occurrence contributes no candidate.
      ]);

      expect(rows, isEmpty);
    });

    test(
      'includes a midnight-crossing timed row on both overlapped days only',
      () {
        final crossing = item(
          'midnight overlap',
          start: selected.add(const Duration(hours: 23, minutes: 30)),
          end: next.add(const Duration(minutes: 30)),
          eventId: 'event-midnight',
        );

        expect(scoped(selected, [crossing]).single.title, 'midnight overlap');
        expect(scoped(next, [crossing]).single.title, 'midnight overlap');
        expect(scoped(next.add(const Duration(days: 1)), [crossing]), isEmpty);
      },
    );

    test('dedupes computed and event-backed rows by flow occurrence start', () {
      final start = selected.add(const Duration(hours: 9));
      final end = selected.add(const Duration(hours: 9, minutes: 30));
      final rows = scoped(selected, [
        item(
          'The Weighing',
          sourceType: 'computed_flow',
          flowId: 40,
          start: start,
          end: end,
        ),
        item(
          'The Weighing',
          sourceType: 'event_backed_flow',
          clientEventId: 'event-backed-weighing',
          flowId: 40,
          start: start,
          end: end,
        ),
      ]);

      expect(rows, hasLength(1));
      expect(rows.single.sourceType, 'computed_flow');
    });

    test('dedupes reminder rows by reminder id and occurrence start', () {
      final start = selected.add(const Duration(hours: 8));
      final end = selected.add(const Duration(hours: 8, minutes: 30));
      final rows = scoped(selected, [
        item(
          'Daily reminder',
          sourceType: 'reminder',
          reminderId: 'reminder-1',
          start: start,
          end: end,
        ),
        item(
          'Daily reminder duplicate',
          sourceType: 'reminder',
          reminderId: 'reminder-1',
          start: start,
          end: end,
        ),
      ]);

      expect(rows, hasLength(1));
    });

    test('dedupes fallback rows by title, range, and source type', () {
      final start = selected.add(const Duration(hours: 10));
      final end = selected.add(const Duration(hours: 11));
      final rows = scoped(selected, [
        item('Loose note', start: start, end: end),
        item('Loose note', start: start, end: end),
        item('Loose note', sourceType: 'computed_flow', start: start, end: end),
      ]);

      expect(rows.map((row) => row.sourceType), ['note', 'computed_flow']);
      expect(rows.length, 2);
    });
  });
}
