import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/day_view.dart';

String _sourceBetween(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  final endIndex = source.indexOf(end, startIndex + start.length);
  expect(startIndex, isNonNegative, reason: 'missing start marker: $start');
  expect(endIndex, greaterThan(startIndex), reason: 'missing end marker: $end');
  return source.substring(startIndex, endIndex);
}

void main() {
  late String dayView;
  late String landscape;
  late String calendarPage;
  late String grid;

  setUpAll(() {
    dayView = File('lib/features/calendar/day_view.dart').readAsStringSync();
    landscape = File(
      'lib/features/calendar/landscape_month_view.dart',
    ).readAsStringSync();
    calendarPage = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    grid = File(
      'lib/features/calendar/calendar_grid_widgets.dart',
    ).readAsStringSync();
  });

  test('all-day notes paint 9:00-17:00 without a canonical schedule', () {
    final item = EventItem.fromTimedNote(
      title: 'All day',
      allDay: true,
      color: Colors.blue,
      startHour: 8,
      startMinute: 15,
      endHour: 10,
      endMinute: 45,
    );
    expect(item.startMin, 9 * 60);
    expect(item.endMin, 17 * 60);
    expect(item.hasCanonicalSchedule, isFalse);
  });

  test('timed notes keep supplied minutes as canonical schedule', () {
    final item = EventItem.fromTimedNote(
      title: 'Timed',
      allDay: false,
      color: Colors.blue,
      startHour: 7,
      startMinute: 30,
      endHour: 8,
      endMinute: 0,
    );
    expect(item.startMin, 7 * 60 + 30);
    expect(item.endMin, 8 * 60);
    expect(item.hasCanonicalSchedule, isTrue);
  });

  test(
    'missing timed hours default to 9:00-17:00 without canonical schedule',
    () {
      final item = EventItem.fromTimedNote(
        title: 'Untimed',
        allDay: false,
        color: Colors.blue,
      );
      expect(item.startMin, 9 * 60);
      expect(item.endMin, 17 * 60);
      expect(item.hasCanonicalSchedule, isFalse);
    },
  );

  test('optional projection fields stay adapter-owned', () {
    final filled = EventItem.fromTimedNote(
      title: 'Filled',
      allDay: false,
      color: Colors.red,
      startHour: 8,
      startMinute: 0,
      endHour: 9,
      endMinute: 0,
      canonicalEnd: DateTime(2026, 8, 29, 9),
      flowName: 'Offering',
      flowNotes: 'maat=the-offering-table',
      behaviorPayload: const <String, dynamic>{'kind': 'offering'},
    );
    expect(filled.canonicalEnd, DateTime(2026, 8, 29, 9));
    expect(filled.flowName, 'Offering');
    expect(filled.flowNotes, 'maat=the-offering-table');
    expect(filled.behaviorPayload, const <String, dynamic>{'kind': 'offering'});

    final empty = EventItem.fromTimedNote(
      title: 'Empty',
      allDay: false,
      color: Colors.red,
    );
    expect(empty.canonicalEnd, isNull);
    expect(empty.flowName, isNull);
    expect(empty.flowNotes, isNull);
    expect(empty.behaviorPayload, isNull);
  });

  test('five note projections call the shared contract as small adapters', () {
    final dayAdapter = _sourceBetween(
      dayView,
      'EventItem _eventItemFromNote(NoteData note, Map<int, FlowData> flowIndex) {',
      'String eventItemIdentityKey(EventItem event) {',
    );
    final landscapeAdapter = _sourceBetween(
      landscape,
      'EventItem _eventItemFromNote(NoteData note) {',
      'FlowData? _chromeFlowForId(int? flowId)',
    );
    final pageAdapter = _sourceBetween(
      calendarPage,
      'EventItem _noteToEventItem(_Note note) {',
      'Future<void> _moveEventInDayView(',
    );
    final sheetAdapter = _sourceBetween(
      calendarPage,
      'EventItem _calendarSheetEventItemFromNote(_Note note) {',
      'bool _noteHasStableIdentity(_Note note)',
    );
    final gridAdapter = _sourceBetween(
      grid,
      'EventItem _noteToEventItem(_Note note) {',
      'void _showEventDetailFromNote(',
    );

    for (final adapter in <String>[
      dayAdapter,
      landscapeAdapter,
      pageAdapter,
      sheetAdapter,
      gridAdapter,
    ]) {
      expect(adapter, contains('EventItem.fromTimedNote('));
      expect(adapter, isNot(contains('9 * 60')));
      expect(adapter, isNot(contains('17 * 60')));
      expect(adapter, isNot(contains('noteHasCanonicalSchedule(')));
      expect(adapter, isNot(contains('startMin:')));
      expect(adapter, isNot(contains('endMin:')));
    }

    expect(dayAdapter, contains('canonicalEnd: note.canonicalEnd'));
    expect(dayAdapter, contains('flowName: flow?.name'));
    expect(dayAdapter, contains('flowNotes: flow?.notes'));
    expect(dayAdapter, contains('behaviorPayload: note.behaviorPayload'));

    expect(landscapeAdapter, isNot(contains('canonicalEnd')));
    expect(landscapeAdapter, isNot(contains('flowName')));
    expect(landscapeAdapter, isNot(contains('flowNotes')));
    expect(landscapeAdapter, isNot(contains('behaviorPayload')));

    expect(
      pageAdapter,
      contains('color: note.manualColor ?? _noteColor(note)'),
    );
    expect(pageAdapter, contains('behaviorPayload: note.behaviorPayload'));
    expect(pageAdapter, isNot(contains('canonicalEnd')));

    expect(sheetAdapter, contains('color: _noteColor(note)'));
    expect(sheetAdapter, contains('behaviorPayload: note.behaviorPayload'));
    expect(sheetAdapter, isNot(contains('canonicalEnd')));

    expect(gridAdapter, contains('color: noteColorResolver(note)'));
    expect(gridAdapter, contains('behaviorPayload: note.behaviorPayload'));
    expect(gridAdapter, isNot(contains('canonicalEnd')));
  });
}
