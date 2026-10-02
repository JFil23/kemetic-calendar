import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/day_view.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String _sourceBetween(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  final endIndex = source.indexOf(end, startIndex + start.length);
  expect(startIndex, isNonNegative, reason: 'missing start marker: $start');
  expect(endIndex, greaterThan(startIndex), reason: 'missing end marker: $end');
  return source.substring(startIndex, endIndex);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String dayView;
  late String landscape;
  late String calendarPage;
  late String grid;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
    );
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

  test(
    'real page sheet and grid adapters forward only external provider end',
    () {
      final state = CalendarPageState();
      final providerEnd = DateTime.utc(2026, 11, 2, 1, 15);
      for (final clientEventId in <String?>[
        'external:provider-occurrence',
        'authored-note',
        'native:legacy-copy',
        null,
      ]) {
        final projections = state.debugNoteEventAdaptersForTesting(
          NoteData(
            id: 'row-id',
            clientEventId: clientEventId,
            title: 'Existing exact title',
            detail: 'Existing detail',
            allDay: false,
            start: const TimeOfDay(hour: 9, minute: 15),
            end: const TimeOfDay(hour: 10, minute: 30),
            canonicalEnd: providerEnd,
            manualColor: Colors.red,
            behaviorPayload: const {'kind': 'offering'},
          ),
        );
        expect(
          projections.adapters.keys,
          unorderedEquals(['page', 'sheet', 'grid']),
        );
        for (final entry in projections.adapters.entries) {
          final item = entry.value;
          expect(
            item.canonicalEnd,
            clientEventId?.startsWith('external:') == true
                ? providerEnd
                : isNull,
            reason: '${entry.key} adapter for $clientEventId',
          );
          expect(item.title, 'Existing exact title');
          expect(item.detail, 'Existing detail');
          expect(item.startMin, 9 * 60 + 15);
          expect(item.endMin, 10 * 60 + 30);
          expect(item.color, Colors.red);
          expect(item.behaviorPayload, const {'kind': 'offering'});
          expect(item.flowName, isNull);
          expect(item.flowNotes, isNull);
        }
      }
    },
  );

  test('real grid labels preserve provider titles and authored cleanup', () {
    final state = CalendarPageState();
    for (final title in ['10:30', 'Event', 'Train 8:00 PM']) {
      for (final external in [true, false]) {
        final projection = state.debugNoteEventAdaptersForTesting(
          NoteData(
            clientEventId: external ? 'external:provider' : 'authored-note',
            title: title,
            allDay: true,
            manualColor: Colors.red,
          ),
        );
        expect(
          projection.gridLabel,
          external || title == 'Train 8:00 PM' ? title : '',
          reason: 'grid title "$title", external=$external',
        );
      }
    }
  });

  test('note projections share the complete Day View display contract', () {
    final dayAdapter = _sourceBetween(
      dayView,
      'EventItem _eventItemFromNote(NoteData note, Map<int, FlowData> flowIndex) {',
      'String eventItemIdentityKey(EventItem event) {',
    );
    final landscapeAdapter = _sourceBetween(
      landscape,
      'List<EventItem> _eventsForKemeticDay(int ky, int km, int kd)',
      'void _configureColumns',
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

    expect(landscapeAdapter, contains('calendarEventsForNotes('));
    expect(landscapeAdapter, contains('widget.notesForDay(ky, km, kd)'));

    expect(
      pageAdapter,
      contains('color: note.manualColor ?? _noteColor(note)'),
    );
    expect(pageAdapter, contains('behaviorPayload: note.behaviorPayload'));
    expect(
      pageAdapter,
      matches(
        r"canonicalEnd:\s*note.clientEventId\?\.startsWith\('external:'\) == true\s*\? note.canonicalEnd\s*: null",
      ),
    );

    expect(sheetAdapter, contains('color: _noteColor(note)'));
    expect(sheetAdapter, contains('behaviorPayload: note.behaviorPayload'));
    expect(
      sheetAdapter,
      matches(
        r"canonicalEnd:\s*note.clientEventId\?\.startsWith\('external:'\) == true\s*\? note.canonicalEnd\s*: null",
      ),
    );

    expect(gridAdapter, contains('color: noteColorResolver(note)'));
    expect(gridAdapter, contains('behaviorPayload: note.behaviorPayload'));
    expect(
      gridAdapter,
      matches(
        r"canonicalEnd:\s*note.clientEventId\?\.startsWith\('external:'\) == true\s*\? note.canonicalEnd\s*: null",
      ),
    );
  });
}
