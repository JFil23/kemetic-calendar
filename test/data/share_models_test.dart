import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/share_models.dart';

void main() {
  group('share recipient helpers', () {
    test('dedupeShareRecipients preserves first occurrence order', () {
      final deduped = dedupeShareRecipients([
        ShareRecipient(type: ShareRecipientType.user, value: 'user-1'),
        ShareRecipient(type: ShareRecipientType.user, value: 'user-2'),
        ShareRecipient(type: ShareRecipientType.user, value: 'user-1'),
        ShareRecipient(
          type: ShareRecipientType.email,
          value: ' Test@Email.com ',
        ),
        ShareRecipient(type: ShareRecipientType.email, value: 'test@email.com'),
      ]);

      expect(deduped.map(shareRecipientKey).toList(), [
        'user:user-1',
        'user:user-2',
        'email:test@email.com',
      ]);
    });
  });

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

    test(
      'parses bool-like event payload fields without dropping the invite',
      () {
        final item = InboxShareItem.fromJson({
          'share_id': 'share-6',
          'kind': 'event',
          'recipient_id': 'recipient-1',
          'sender_id': 'sender-6',
          'sender_handle': 'host',
          'sender_name': 'Host',
          'payload_id': 'event-share-6',
          'title': 'Equinox Circle',
          'created_at': '2026-04-16T00:00:00Z',
          'payload_json': {
            'event_id': 'event-6',
            'title': 'Equinox Circle',
            'starts_at': '2026-04-21T19:00:00Z',
            'all_day': '1',
          },
        });

        expect(item.eventPayload, isNotNull);
        expect(item.eventPayload?.allDay, isTrue);
        expect(item.eventPayload?.title, 'Equinox Circle');
      },
    );

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

    test('decodes stringified payload_json maps for direct messages', () {
      final item = InboxShareItem.fromJson({
        'share_id': 'share-7',
        'kind': 'flow',
        'recipient_id': 'recipient-1',
        'sender_id': 'sender-7',
        'sender_handle': 'scribe',
        'sender_name': 'Scribe',
        'payload_id': 'share-7',
        'title': '',
        'created_at': '2026-04-16T00:00:00Z',
        'payload_json': '{"type":"message","text":"Bring candles"}',
      });

      expect(item.isTextMessage, isTrue);
      expect(item.messageText, 'Bring candles');
      expect(item.title, 'Bring candles');
    });

    test('parses shared calendar notifications', () {
      final item = InboxShareItem.fromJson({
        'share_id': 'share-8',
        'kind': 'calendar',
        'recipient_id': 'recipient-1',
        'sender_id': 'sender-8',
        'sender_handle': 'scribe',
        'sender_name': 'Scribe',
        'payload_id': 'calendar-1',
        'title': 'Phillips\'',
        'created_at': '2026-04-16T00:00:00Z',
        'payload_json': {
          'notification_kind': 'calendar_invite',
          'calendar_name': 'Phillips\'',
          'body': 'You were invited to join this calendar.',
          'calendar_color': 13807415,
        },
      });

      expect(item.kind, InboxShareKind.calendar);
      expect(item.isCalendarInviteNotification, isTrue);
      expect(item.calendarName, 'Phillips\'');
      expect(item.calendarBody, 'You were invited to join this calendar.');
      expect(item.calendarColorValue, 13807415);
    });

    test('tryFromJson drops malformed rows instead of throwing', () {
      final item = InboxShareItem.tryFromJson({
        'kind': 'flow',
        'sender_id': 'sender-8',
        'created_at': 'not-a-date',
      });

      expect(item, isNull);
    });
  });

  group('ShareResult.fromJson', () {
    test('parses recipient metadata returned by event invite sends', () {
      final result = ShareResult.fromJson({
        'id': 'share-1',
        'status': 'sent',
        'recipient': {'type': 'user', 'value': 'user-1'},
      });

      expect(result.isSuccess, isTrue);
      expect(result.recipient?.type, ShareRecipientType.user);
      expect(result.recipient?.value, 'user-1');
    });

    test('falls back to recipient_id when recipient metadata is absent', () {
      final result = ShareResult.fromJson({
        'id': 'share-2',
        'status': 'sent',
        'recipient_id': 'user-2',
      });

      expect(result.recipient?.value, 'user-2');
      expect(result.recipient?.type, ShareRecipientType.user);
    });
  });
}
