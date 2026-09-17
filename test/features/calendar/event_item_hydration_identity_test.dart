import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/day_view.dart';

EventItem _item({
  String? id,
  String? clientEventId,
  String? reminderId,
  String title = 'Same title',
  String? calendarId,
  int startMin = 9 * 60,
  int endMin = 10 * 60,
}) {
  return EventItem(
    id: id,
    clientEventId: clientEventId,
    reminderId: reminderId,
    calendarId: calendarId,
    title: title,
    startMin: startMin,
    endMin: endMin,
    color: Colors.blue,
    allDay: false,
  );
}

void main() {
  test('stable ids match before fallback composite keys', () {
    expect(
      eventsShareStableIdentity(
        _item(id: 'a', title: 'One', calendarId: 'cal-1'),
        _item(id: 'a', title: 'Two', calendarId: 'cal-2'),
      ),
      isTrue,
    );
    expect(
      eventsShareStableIdentity(
        _item(clientEventId: 'cid', title: 'One'),
        _item(clientEventId: 'cid', title: 'Two'),
      ),
      isTrue,
    );
    expect(
      eventsShareStableIdentity(
        _item(reminderId: 'rid', title: 'One'),
        _item(reminderId: 'rid', title: 'Two'),
      ),
      isTrue,
    );
  });

  test(
    'fallback identity includes calendarId so same-title events stay distinct',
    () {
      expect(
        eventItemIdentityKey(_item(calendarId: 'cal-1')),
        isNot(eventItemIdentityKey(_item(calendarId: 'cal-2'))),
      );
      expect(
        eventsShareStableIdentity(
          _item(calendarId: 'cal-1'),
          _item(calendarId: 'cal-2'),
        ),
        isFalse,
      );
      expect(
        eventsShareStableIdentity(
          _item(calendarId: 'cal-1'),
          _item(calendarId: 'cal-1'),
        ),
        isTrue,
      );
    },
  );

  test('schedule order is start, then end, then shared identity', () {
    final earlier = _item(id: 'b', startMin: 8 * 60, endMin: 9 * 60);
    final later = _item(id: 'a', startMin: 10 * 60, endMin: 11 * 60);
    expect(compareEventItemsBySchedule(earlier, later), lessThan(0));

    final shorter = _item(id: 'b', startMin: 9 * 60, endMin: 9 * 60 + 30);
    final longer = _item(id: 'a', startMin: 9 * 60, endMin: 11 * 60);
    expect(compareEventItemsBySchedule(shorter, longer), lessThan(0));

    final firstKey = _item(id: 'a', startMin: 9 * 60, endMin: 10 * 60);
    final secondKey = _item(id: 'b', startMin: 9 * 60, endMin: 10 * 60);
    expect(compareEventItemsBySchedule(firstKey, secondKey), lessThan(0));
  });

  test(
    'Landscape uses shared identity/order and keeps month-scoped enumeration',
    () {
      final landscape = File(
        'lib/features/calendar/landscape_month_view.dart',
      ).readAsStringSync();
      expect(landscape, isNot(contains('_sheetEventIdentityKey')));
      expect(
        landscape,
        isNot(
          contains('bool _eventsShareStableIdentity(EventItem a, EventItem b)'),
        ),
      );
      expect(landscape, contains('eventsShareStableIdentity('));
      expect(landscape, contains('compareEventItemsBySchedule'));
      expect(
        landscape,
        contains(
          'List<EventItem> _eventsForKemeticDay(int ky, int km, int kd)',
        ),
      );
      expect(landscape, contains('widget.notesForDay(ky, km, kd)'));
      expect(
        landscape,
        contains('if (ky != widget.kYear || km != widget.kMonth)'),
      );
    },
  );
}
