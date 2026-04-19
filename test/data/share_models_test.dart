import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/share_models.dart';

void main() {
  group('SuggestedSchedule.fromJson', () {
    test('accepts camelCase fields and string values', () {
      final schedule = SuggestedSchedule.fromJson({
        'startDate': '2026-04-20',
        'weekdays': ['1', 3, '7'],
        'everyOtherDay': 'true',
        'perWeek': '2',
        'timesByWeekday': {1: '09:00', '': 'ignored'},
      });

      expect(schedule.normalizedStartDate, '2026-04-20');
      expect(schedule.weekdays, [1, 3, 7]);
      expect(schedule.everyOtherDay, isTrue);
      expect(schedule.perWeek, 2);
      expect(schedule.timesByWeekday, {'1': '09:00'});
      expect(schedule.weekdayLabels, ['Mon', 'Wed', 'Sun']);
    });

    test('drops invalid weekday values instead of throwing', () {
      final schedule = SuggestedSchedule.fromJson({
        'start_date': '2026-04-20',
        'weekdays': [-1, 0, 6, 8],
      });

      expect(schedule.weekdays, [0, 6]);
      expect(schedule.weekdayLabels, ['Sun', 'Sat']);
    });

    test('dedupes weekdays and trims timesByWeekday entries', () {
      final schedule = SuggestedSchedule.fromJson({
        'start_date': ' 2026-04-21 ',
        'weekdays': ['1', 1, ' 1 ', 0, 0, 7],
        'times_by_weekday': {
          ' 1 ': ' 09:00 ',
          '0': ' 06:30 ',
          '': 'ignored',
          '7': '',
        },
      });

      expect(schedule.normalizedStartDate, '2026-04-21');
      expect(schedule.weekdays, [1, 0, 7]);
      expect(schedule.timesByWeekday, {'1': '09:00', '0': '06:30'});
      expect(schedule.weekdayLabels, ['Mon', 'Sun', 'Sun']);
    });
  });

  group('InboxShareItem.fromJson', () {
    test('uses safe sender fallbacks and tolerant schedule parsing', () {
      final item = InboxShareItem.fromJson({
        'share_id': 'share-1',
        'kind': 'flow',
        'recipient_id': 'recipient-1',
        'sender_id': 'sender-1',
        'sender_handle': null,
        'sender_name': null,
        'sender_avatar': null,
        'payload_id': '42',
        'title': 'Morning Flow',
        'created_at': '2026-04-15T00:00:00Z',
        'suggested_schedule': {
          'startDate': '2026-04-20',
          'weekdays': ['1', '3'],
        },
      });

      expect(item.senderHandle, 'unknown');
      expect(item.senderName, 'Unknown User');
      expect(item.suggestedSchedule, isNotNull);
      expect(item.suggestedSchedule!.weekdays, [1, 3]);
      expect(item.payloadJson, isNull);
      expect(item.isUnread, isTrue);
      expect(item.isImported, isFalse);
      expect(item.subtitle, 'Flow shared by @unknown');
    });

    test('keeps message payload behavior stable', () {
      final item = InboxShareItem.fromJson({
        'share_id': 'share-2',
        'kind': 'message',
        'recipient_id': 'recipient-1',
        'sender_id': 'sender-2',
        'sender_handle': 'maatkeeper',
        'sender_name': 'Maat Keeper',
        'payload_id': 'message-1',
        'title': 'Shared Note',
        'created_at': '2026-04-15T00:00:00Z',
        'payload_json': {'kind': 'message', 'text': 'Bring water and fruit'},
        'viewed_at': '2026-04-15T01:00:00Z',
      });

      expect(item.isTextMessage, isTrue);
      expect(item.messageText, 'Bring water and fruit');
      expect(item.subtitle, 'Bring water and fruit');
      expect(item.isUnread, isFalse);
      expect(item.isImported, isFalse);
    });

    test('marks imported and deleted state independently', () {
      final item = InboxShareItem.fromJson({
        'share_id': 'share-3',
        'kind': 'event',
        'recipient_id': 'recipient-1',
        'sender_id': 'sender-3',
        'sender_handle': 'ritualhost',
        'sender_name': 'Ritual Host',
        'payload_id': 'event-1',
        'title': 'Temple Gathering',
        'created_at': '2026-04-15T00:00:00Z',
        'imported_at': '2026-04-15T02:00:00Z',
        'deleted_at': '2026-04-15T03:00:00Z',
        'event_date': '2026-04-20T18:30:00Z',
        'response_status': 'maybe',
        'responded_at': '2026-04-15T02:30:00Z',
        'payload_json': {
          'event_id': 'event-1',
          'title': 'Temple Gathering',
          'detail': 'Bring incense',
          'location': 'South Hall',
          'starts_at': '2026-04-20T18:30:00Z',
          'all_day': false,
        },
      });

      expect(item.isEvent, isTrue);
      expect(item.isImported, isFalse);
      expect(item.isDeleted, isTrue);
      expect(item.isUnread, isFalse);
      expect(item.eventDate, DateTime.parse('2026-04-20T18:30:00Z'));
      expect(item.responseStatus, EventInviteResponseStatus.maybe);
      expect(item.respondedAt, DateTime.parse('2026-04-15T02:30:00Z'));
      expect(item.eventPayload?.location, 'South Hall');
      expect(item.subtitle, 'Event shared by @ritualhost');
    });

    test('flags pending event invites from inbox rows', () {
      final item = InboxShareItem.fromJson({
        'share_id': 'share-5',
        'kind': 'event',
        'recipient_id': 'recipient-1',
        'sender_id': 'sender-5',
        'sender_handle': 'host',
        'sender_name': 'Host',
        'payload_id': 'event-share-1',
        'title': 'New Moon Gathering',
        'created_at': '2026-04-16T00:00:00Z',
        'response_status': 'no_response',
        'payload_json': {
          'event_id': 'event-5',
          'title': 'New Moon Gathering',
          'starts_at': '2026-04-21T19:00:00Z',
          'all_day': false,
        },
      });

      expect(item.isPendingEventInvite, isTrue);
      expect(item.eventPayload?.eventId, 'event-5');
      expect(item.eventPayload?.title, 'New Moon Gathering');
    });

    test('defaults unknown share kinds to flow behavior', () {
      final item = InboxShareItem.fromJson({
        'share_id': 'share-4',
        'kind': 'unexpected-kind',
        'recipient_id': 'recipient-1',
        'sender_id': 'sender-4',
        'sender_handle': 'initiate',
        'sender_name': 'Initiate',
        'payload_id': 'payload-1',
        'title': 'Fallback Flow',
        'created_at': '2026-04-15T00:00:00Z',
      });

      expect(item.kind, InboxShareKind.flow);
      expect(item.isFlow, isTrue);
      expect(item.subtitle, 'Flow shared by @initiate');
    });
  });
}
