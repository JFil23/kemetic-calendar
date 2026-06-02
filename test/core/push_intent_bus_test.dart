import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/push_intent_bus.dart';

void main() {
  group('CalendarPushOpenIntent', () {
    test(
      'parses scheduled notification data with nested flow event payload',
      () {
        final intent = CalendarPushOpenIntent.fromNotificationData({
          'type': 'scheduled_notification',
          'client_event_id': 'cid-flow-top',
          'payload': jsonEncode({
            'item_type': 'flow_event',
            'k_year': 2,
            'k_month': 3,
            'k_day': 4,
            'client_event_id': 'cid-flow',
            'event_id': 'event-flow',
            'flow_id': 42,
          }),
        }, nonce: 7);

        expect(intent, isNotNull);
        expect(intent!.itemType, calendarPushItemTypeFlowEvent);
        expect(intent.kYear, 2);
        expect(intent.kMonth, 3);
        expect(intent.kDay, 4);
        expect(intent.clientEventId, 'cid-flow');
        expect(intent.eventId, 'event-flow');
        expect(intent.flowId, 42);
        expect(intent.nonce, 7);
      },
    );

    test('parses note payload strings', () {
      final intent = CalendarPushOpenIntent.fromPayloadString(
        jsonEncode({
          'item_type': 'note',
          'kYear': 1,
          'kMonth': 2,
          'kDay': 3,
          'clientEventId': 'cid-note',
          'eventId': 'event-note',
        }),
        nonce: 9,
      );

      expect(intent, isNotNull);
      expect(intent!.itemType, calendarPushItemTypeNote);
      expect(intent.kYear, 1);
      expect(intent.kMonth, 2);
      expect(intent.kDay, 3);
      expect(intent.clientEventId, 'cid-note');
      expect(intent.eventId, 'event-note');
      expect(intent.nonce, 9);
    });

    test('parses reminder identity without a client event id', () {
      final intent = CalendarPushOpenIntent.fromNotificationData({
        'item_type': 'reminder',
        'k_year': '4',
        'k_month': '5',
        'k_day': '6',
        'reminder_id': 'reminder-rule',
      });

      expect(intent, isNotNull);
      expect(intent!.itemType, calendarPushItemTypeReminder);
      expect(intent.kYear, 4);
      expect(intent.kMonth, 5);
      expect(intent.kDay, 6);
      expect(intent.reminderId, 'reminder-rule');
    });

    test('keeps legacy client-event-only payloads routable', () {
      final intent = CalendarPushOpenIntent.fromNotificationData({
        'client_event_id': 'legacy-cid',
      }, nonce: 11);

      expect(intent, isNotNull);
      expect(intent!.clientEventId, 'legacy-cid');
      expect(intent.itemType, isNull);
      expect(intent.hasKemeticDate, isFalse);
    });
  });
}
