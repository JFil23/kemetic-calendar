import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/share_models.dart';
import 'package:mobile/features/inbox/inbox_threading.dart';

void main() {
  group('shared calendar inbox threading', () {
    test('multiple events from the same shared calendar produce one row', () {
      final threads = sharedCalendarInboxThreadsFromNotifications([
        _calendarUpdate(
          shareId: 'notif-1',
          calendarId: 'calendar-phillips',
          calendarName: 'Phillips calendar',
          title: 'Theater',
          body: 'Theater was added by October.',
          createdAt: DateTime.utc(2026, 6, 1, 15),
        ),
        _calendarUpdate(
          shareId: 'notif-2',
          calendarId: 'calendar-phillips',
          calendarName: 'Phillips calendar',
          title: 'piano recital - Colburn Thayer Hall',
          body: 'piano recital was added by October.',
          createdAt: DateTime.utc(2026, 6, 2, 15),
        ),
      ]);

      expect(threads, hasLength(1));
      expect(threads.single.calendarId, 'calendar-phillips');
      expect(threads.single.title, 'Phillips calendar');
      expect(threads.single.notifications.map((item) => item.title), [
        'Theater',
        'piano recital - Colburn Thayer Hall',
      ]);
      expect(threads.single.preview, 'piano recital was added by October.');
      expect(threads.single.unreadCount, 2);
    });

    test('different shared calendars produce separate rows', () {
      final threads = sharedCalendarInboxThreadsFromNotifications([
        _calendarUpdate(
          shareId: 'notif-1',
          calendarId: 'calendar-phillips',
          calendarName: 'Phillips calendar',
          title: 'Theater',
          createdAt: DateTime.utc(2026, 6, 1),
        ),
        _calendarUpdate(
          shareId: 'notif-2',
          calendarId: 'calendar-jordan',
          calendarName: 'Jordan calendar',
          title: 'Dinner',
          createdAt: DateTime.utc(2026, 6, 2),
        ),
      ]);

      expect(threads, hasLength(2));
      expect(threads.map((thread) => thread.calendarId), [
        'calendar-jordan',
        'calendar-phillips',
      ]);
    });

    test('repeated updates from the same calendar do not duplicate rows', () {
      final threads = sharedCalendarInboxThreadsFromNotifications(
        List.generate(
          5,
          (index) => _calendarUpdate(
            shareId: 'notif-$index',
            calendarId: 'calendar-phillips',
            calendarName: 'Phillips calendar',
            title: 'Update $index',
            createdAt: DateTime.utc(2026, 6, 1, index),
          ),
        ),
      );

      expect(threads, hasLength(1));
      expect(threads.single.notifications, hasLength(5));
    });

    test('optimistic read state clears the grouped unread badge', () {
      final threads = sharedCalendarInboxThreadsFromNotifications(
        [
          _calendarUpdate(
            shareId: 'notif-1',
            calendarId: 'calendar-phillips',
            calendarName: 'Phillips calendar',
            title: 'Theater',
            createdAt: DateTime.utc(2026, 6, 1),
          ),
        ],
        optimisticReadShareIds: {'notif-1'},
      );

      expect(threads.single.hasUnread, isFalse);
      expect(threads.single.unreadCount, 0);
    });
  });

  group('direct message threading', () {
    test('direct messages still produce one row per conversation', () {
      final threads = directMessageConversationThreadsFromItems([
        _message(
          shareId: 'msg-1',
          senderId: 'friend-1',
          recipientId: 'me',
          text: 'October',
          createdAt: DateTime.utc(2026, 6, 1),
        ),
        _message(
          shareId: 'msg-2',
          senderId: 'me',
          recipientId: 'friend-1',
          text: 'potato',
          createdAt: DateTime.utc(2026, 6, 2),
        ),
        _message(
          shareId: 'msg-3',
          senderId: 'friend-2',
          recipientId: 'me',
          text: 'jordan',
          createdAt: DateTime.utc(2026, 6, 3),
        ),
      ], 'me');

      expect(threads.keys, containsAll(<String>['friend-1', 'friend-2']));
      expect(threads['friend-1'], hasLength(2));
      expect(threads['friend-2'], hasLength(1));
    });
  });

  group('event invite sheet threading', () {
    test('event RSVP notifications are classified for the Invites sheet', () {
      final invites = eventInviteItemsForInvitesSheet([
        _eventInvite(
          shareId: 'event-1',
          title: 'Theater',
          responseStatus: EventInviteResponseStatus.accepted,
          createdAt: DateTime.utc(2026, 6, 1, 15),
        ),
        _calendarUpdate(
          shareId: 'calendar-1',
          calendarId: 'calendar-phillips',
          calendarName: 'Phillips calendar',
          title: 'Calendar update',
          createdAt: DateTime.utc(2026, 6, 2, 15),
        ),
        _message(
          shareId: 'msg-1',
          senderId: 'friend-1',
          recipientId: 'me',
          text: 'hello',
          createdAt: DateTime.utc(2026, 6, 3, 15),
        ),
      ], 'me');

      expect(invites.map((invite) => invite.title), ['Theater']);
    });

    test('multiple event RSVP notifications roll up as sheet items', () {
      final invites = eventInviteItemsForInvitesSheet([
        _eventInvite(
          shareId: 'event-1',
          title: 'Theater',
          responseStatus: EventInviteResponseStatus.accepted,
          createdAt: DateTime.utc(2026, 6, 1, 15),
        ),
        _eventInvite(
          shareId: 'event-2',
          title: 'piano recital - Colburn Thayer Hall',
          responseStatus: EventInviteResponseStatus.accepted,
          createdAt: DateTime.utc(2026, 6, 2, 15),
        ),
        _eventInvite(
          shareId: 'event-3',
          title: 'Other user event',
          recipientId: 'someone-else',
          responseStatus: EventInviteResponseStatus.noResponse,
          createdAt: DateTime.utc(2026, 6, 3, 15),
        ),
      ], 'me');

      expect(invites, hasLength(2));
      expect(invites.map((invite) => invite.title), [
        'piano recital - Colburn Thayer Hall',
        'Theater',
      ]);
    });

    test('event RSVP status labels stay action-oriented in the sheet', () {
      expect(
        eventInviteStatusLabel(
          _eventInvite(
            shareId: 'event-yes',
            title: 'Theater',
            responseStatus: EventInviteResponseStatus.accepted,
            createdAt: DateTime.utc(2026, 6, 1),
          ),
        ),
        'Yes',
      );
      expect(
        eventInviteStatusLabel(
          _eventInvite(
            shareId: 'event-pending',
            title: 'Dinner',
            responseStatus: EventInviteResponseStatus.noResponse,
            viewedAt: DateTime.utc(2026, 6, 2),
            createdAt: DateTime.utc(2026, 6, 2),
          ),
        ),
        'Pending',
      );
    });
  });

  group('shared calendar notification routing', () {
    test('row tap route opens the shared calendar inbox context', () {
      expect(
        sharedCalendarInboxRouteLocation('calendar-phillips'),
        '/inbox?calendarId=calendar-phillips',
      );
    });

    test('member notification payload opens the shared calendar context', () {
      final route = sharedCalendarInboxRouteLocationFromPushData({
        'kind': 'calendar_event',
        'calendar_id': 'calendar-phillips',
        'client_event_id': 'cid-theater',
      });

      expect(route, '/inbox?calendarId=calendar-phillips');
    });

    test('nested shared-calendar push payload opens intended context', () {
      final route = sharedCalendarInboxRouteLocationFromPushData({
        'push_kind': 'shared_calendar_item_added',
        'payload': jsonEncode({
          'kind': 'shared_calendar_item_added',
          'calendar_id': 'calendar-phillips',
          'client_event_id': 'cid-theater',
        }),
      });

      expect(route, '/inbox?calendarId=calendar-phillips');
    });

    test('non shared calendar event payloads stay on calendar routing', () {
      final route = sharedCalendarInboxRouteLocationFromPushData({
        'kind': 'calendar_event',
        'client_event_id': 'personal-event',
      });

      expect(route, isNull);
    });
  });

  group(
    'inbox implementation guardrails',
    () {
      test(
        'shared calendar row tap opens expanded shared calendar sheet',
        () async {
          final source = await File(
            'lib/features/inbox/inbox_page.dart',
          ).readAsString();

          expect(source, contains('_openSharedCalendarThread'));
          expect(source, contains('SharedCalendarsSheet.show'));
          expect(source, contains('initialExpandedCalendarIds'));
          expect(source, contains('_markItemsViewed(thread.notifications)'));
        },
      );

      test(
        'non-member focused calendar ids are ignored by sheet hydration',
        () async {
          final source = await File(
            'lib/features/calendars/shared_calendars_sheet.dart',
          ).readAsString();

          expect(source, contains('allowedCalendarIds.contains(id)'));
          expect(source, contains('snapshot.calendars'));
        },
      );

      test('calendar and profile inbox glyphs use requested symbols', () async {
        final source = await File(
          'lib/features/inbox/inbox_page.dart',
        ).readAsString();

        expect(source, contains('MeduNeterGlyphs.calendars'));
        expect(source, isNot(contains('Icons.calendar_month_rounded')));
        expect(source, contains('𓁷'));
        expect(source, isNot(contains('KemeticGold.icon(Icons.person)')));
      });

      test(
        'event invite rows are rendered only inside Invites sheet',
        () async {
          final source = await File(
            'lib/features/inbox/inbox_page.dart',
          ).readAsString();
          final unifiedBuilder = _sourceBetween(
            source,
            'List<_UnifiedInboxItem> _buildUnifiedItems() {',
            'void _reconcileOptimisticReadState() {',
          );
          final invitesSheet = _sourceBetween(
            source,
            'Future<void> _openCalendarInboxSheet() async {',
            'Widget _calendarSheetSectionTitle',
          );

          expect(
            source,
            contains('enum _UnifiedKind { message, calendarNotification }'),
          );
          expect(
            unifiedBuilder,
            isNot(contains('_UnifiedInboxItem.eventInvite')),
          );
          expect(unifiedBuilder, isNot(contains('inviteItems')));
          expect(invitesSheet, contains('..._latestEventInvites'));
          expect(
            invitesSheet,
            contains("_calendarSheetSectionTitle('Invites & responses')"),
          );
          expect(invitesSheet, contains('_buildEventInviteRow('));
        },
      );

      test(
        'Invites row and sheet preserve event RSVP routing and read rollup',
        () async {
          final source = await File(
            'lib/features/inbox/inbox_page.dart',
          ).readAsString();
          final summaryTile = _sourceBetween(
            source,
            'Widget _buildCalendarSummaryTile() {',
            'String _calendarSummarySubtitleForNotification',
          );
          final eventRow = _sourceBetween(
            source,
            'Widget _buildEventInviteRow(',
            'Widget _buildSharedCalendarThreadRow',
          );
          final openEvent = _sourceBetween(
            source,
            'Future<void> _openEventInvite(InboxShareItem invite) async {',
            'Future<void> _openSharedCalendarThread',
          );
          final sheet = _sourceBetween(
            source,
            'Future<void> _openCalendarInboxSheet() async {',
            'Widget _calendarSheetSectionTitle',
          );

          expect(summaryTile, contains('onTap: _openCalendarInboxSheet'));
          expect(
            source,
            contains('_latestEventInvites.any(_isUnreadInboxItem)'),
          );
          expect(sheet, contains('_markItemsViewed(unreadInviteItems)'));
          expect(eventRow, contains('BuildContext? closeContext'));
          expect(eventRow, contains('Navigator.of(closeContext).pop()'));
          expect(eventRow, contains('_openEventInvite(invite)'));
          expect(openEvent, contains('_markItemsViewed([invite])'));
          expect(
            openEvent,
            contains('/event-invite/\${Uri.encodeComponent(invite.shareId)}'),
          );
        },
      );
    },
    skip: kIsWeb ? 'Source guardrails use dart:io file reads.' : false,
  );
}

InboxShareItem _calendarUpdate({
  required String shareId,
  required String calendarId,
  required String calendarName,
  required String title,
  String? body,
  required DateTime createdAt,
}) {
  return InboxShareItem.fromJson({
    'share_id': shareId,
    'kind': 'calendar',
    'recipient_id': 'me',
    'sender_id': 'sender-1',
    'sender_handle': 'october',
    'sender_name': 'October',
    'payload_id': calendarId,
    'title': title,
    'created_at': createdAt.toIso8601String(),
    'payload_json': {
      'notification_kind': 'calendar_event',
      'calendar_id': calendarId,
      'calendar_name': calendarName,
      'body': body ?? '$title was added.',
      'client_event_id': 'cid-$shareId',
      'calendar_color': 0xFFD4AF37,
    },
  });
}

InboxShareItem _message({
  required String shareId,
  required String senderId,
  required String recipientId,
  required String text,
  required DateTime createdAt,
}) {
  return InboxShareItem.fromJson({
    'share_id': shareId,
    'kind': 'message',
    'recipient_id': recipientId,
    'sender_id': senderId,
    'sender_handle': senderId,
    'sender_name': senderId,
    'payload_id': shareId,
    'title': text,
    'created_at': createdAt.toIso8601String(),
    'payload_json': {'type': 'message', 'text': text},
  });
}

InboxShareItem _eventInvite({
  required String shareId,
  required String title,
  String recipientId = 'me',
  required EventInviteResponseStatus responseStatus,
  DateTime? viewedAt,
  required DateTime createdAt,
}) {
  return InboxShareItem.fromJson({
    'share_id': shareId,
    'kind': 'event',
    'recipient_id': recipientId,
    'sender_id': 'sender-1',
    'sender_handle': 'producedbyearth',
    'sender_name': 'producedbyearth',
    'payload_id': 'event-$shareId',
    'title': title,
    'created_at': createdAt.toIso8601String(),
    'viewed_at': viewedAt?.toIso8601String(),
    'response_status': responseStatus.dbValue,
    'payload_json': {
      'event_id': 'event-$shareId',
      'calendar_id': 'calendar-phillips',
      'calendar_name': 'Phillips calendar',
      'title': title,
      'starts_at': '2026-05-10T21:45:00Z',
      'all_day': false,
    },
  });
}

String _sourceBetween(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  expect(startIndex, isNonNegative, reason: 'Missing source start: $start');
  final endIndex = source.indexOf(end, startIndex + start.length);
  expect(endIndex, isNonNegative, reason: 'Missing source end: $end');
  return source.substring(startIndex, endIndex);
}
