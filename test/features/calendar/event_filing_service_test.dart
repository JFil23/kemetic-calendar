import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/event_filing_service.dart';
import 'package:mobile/features/calendar/notify.dart';

void main() {
  test('files positive alert offsets before the event start', () async {
    final scheduled = <({String clientEventId, DateTime scheduledAt})>[];
    final service = EventFilingService(
      scheduleNotification:
          ({
            required clientEventId,
            required scheduledAt,
            required title,
            body,
            payload,
            type = NotificationType.eventStart,
          }) async {
            scheduled.add((
              clientEventId: clientEventId,
              scheduledAt: scheduledAt,
            ));
          },
      cancelNotification: (_) async {
        fail('positive alert should not cancel notifications');
      },
    );

    final startsAt = DateTime(2026, 6, 1, 9, 30);
    final result = await service.fileDelivery(
      clientEventId: 'event-1',
      startsAtLocal: startsAt,
      alertOffsetMinutes: 10,
      title: 'Event',
    );

    expect(result.outcome, EventFilingOutcome.scheduled);
    expect(result.scheduledAt, DateTime(2026, 6, 1, 9, 20));
    expect(scheduled, [
      (clientEventId: 'event-1', scheduledAt: DateTime(2026, 6, 1, 9, 20)),
    ]);
  });

  test('legacy null alert offsets schedule at event time', () async {
    DateTime? capturedScheduledAt;
    final service = EventFilingService(
      scheduleNotification:
          ({
            required clientEventId,
            required scheduledAt,
            required title,
            body,
            payload,
            type = NotificationType.eventStart,
          }) async {
            capturedScheduledAt = scheduledAt;
          },
      cancelNotification: (_) async {
        fail('legacy alert should not cancel notifications');
      },
    );

    final startsAt = DateTime(2026, 6, 1, 9, 30);
    final result = await service.fileDelivery(
      clientEventId: 'event-1',
      startsAtLocal: startsAt,
      alertOffsetMinutes: null,
      title: 'Event',
    );

    expect(result.outcome, EventFilingOutcome.scheduled);
    expect(result.scheduledAt, startsAt);
    expect(capturedScheduledAt, startsAt);
  });

  test(
    'explicit at-time offsets schedule exactly at the local event start',
    () async {
      DateTime? capturedScheduledAt;
      final service = EventFilingService(
        scheduleNotification:
            ({
              required clientEventId,
              required scheduledAt,
              required title,
              body,
              payload,
              type = NotificationType.eventStart,
            }) async {
              capturedScheduledAt = scheduledAt;
            },
        cancelNotification: (_) async {
          fail('at-time alert should not cancel notifications');
        },
      );

      final startsAtLocal = DateTime(2026, 8, 17, 12);
      final result = await service.fileDelivery(
        clientEventId: 'custom-90-day-math:event-1',
        startsAtLocal: startsAtLocal,
        alertOffsetMinutes: 0,
        title: 'Area of Square',
      );

      expect(result.outcome, EventFilingOutcome.scheduled);
      expect(result.scheduledAt, startsAtLocal);
      expect(capturedScheduledAt, startsAtLocal);
      expect(capturedScheduledAt!.isUtc, isFalse);
    },
  );

  test(
    'explicit no-alert offsets cancel delivery instead of scheduling',
    () async {
      final cancelled = <String>[];
      final service = EventFilingService(
        scheduleNotification:
            ({
              required clientEventId,
              required scheduledAt,
              required title,
              body,
              payload,
              type = NotificationType.eventStart,
            }) async {
              fail('explicit no-alert should not schedule notifications');
            },
        cancelNotification: (clientEventId) async {
          cancelled.add(clientEventId);
        },
      );

      final result = await service.fileDelivery(
        clientEventId: ' event-1 ',
        startsAtLocal: DateTime(2026, 6, 1, 9, 30),
        alertOffsetMinutes: kEventFilingNoAlertMinutes,
        title: 'Event',
      );

      expect(result.outcome, EventFilingOutcome.cancelled);
      expect(cancelled, ['event-1']);
    },
  );

  test(
    'past and future event starts are passed to Notify for active-state policy',
    () async {
      final scheduled = <({String clientEventId, DateTime scheduledAt})>[];
      final service = EventFilingService(
        scheduleNotification:
            ({
              required clientEventId,
              required scheduledAt,
              required title,
              body,
              payload,
              type = NotificationType.eventStart,
            }) async {
              scheduled.add((
                clientEventId: clientEventId,
                scheduledAt: scheduledAt,
              ));
            },
        cancelNotification: (_) async {
          fail(
            'past event starts should be retired by Notify, not cancelled here',
          );
        },
      );

      final pastStart = DateTime(2026, 1, 1, 18);
      final futureStart = DateTime(2026, 1, 29, 18);

      await service.fileDelivery(
        clientEventId: 'moon-return:43:full:2026-01-01',
        startsAtLocal: pastStart,
        alertOffsetMinutes: 0,
        title: 'Moon Return: Whole Eye',
      );
      await service.fileDelivery(
        clientEventId: 'moon-return:43:new:2026-01-29',
        startsAtLocal: futureStart,
        alertOffsetMinutes: 0,
        title: 'Moon Return: Empty Eye',
      );

      expect(scheduled, <({String clientEventId, DateTime scheduledAt})>[
        (
          clientEventId: 'moon-return:43:full:2026-01-01',
          scheduledAt: pastStart,
        ),
        (
          clientEventId: 'moon-return:43:new:2026-01-29',
          scheduledAt: futureStart,
        ),
      ]);
    },
  );

  test(
    'Notify active-state policy retires only already-due rows before persist',
    () {
      final source = File(
        'lib/features/calendar/notify.dart',
      ).readAsStringSync();
      final scheduleStart = source.indexOf(
        'static Future<void> scheduleAlertWithPersistence',
      );
      final scheduleEnd = source.indexOf(
        '/// **DEPRECATED**: Old method - use scheduleAlert',
        scheduleStart,
      );
      final persistStart = source.indexOf(
        'static Future<_PersistedNotification?> _persistNotificationToDatabase',
      );
      final persistEnd = source.indexOf(
        '/// **PRIVATE**: Get notification by event ID',
        persistStart,
      );

      expect(scheduleStart, greaterThanOrEqualTo(0));
      expect(scheduleEnd, greaterThan(scheduleStart));
      expect(persistStart, greaterThanOrEqualTo(0));
      expect(persistEnd, greaterThan(persistStart));

      final scheduleBody = source.substring(scheduleStart, scheduleEnd);
      final alreadyDueGuard = scheduleBody.indexOf(
        '!scheduledAt.isAfter(now.add(_minimumScheduleLead))',
      );
      final retireCall = scheduleBody.indexOf(
        '_markNotificationInactive(clientEventId, type: type)',
        alreadyDueGuard,
      );
      final persistCall = scheduleBody.indexOf(
        '_persistNotificationToDatabase(',
      );

      expect(alreadyDueGuard, greaterThanOrEqualTo(0));
      expect(retireCall, greaterThan(alreadyDueGuard));
      expect(persistCall, greaterThan(retireCall));

      final persistBody = source.substring(persistStart, persistEnd);
      expect(
        persistBody,
        contains("client.rpc(\n        'upsert_scheduled_notification'"),
      );
      expect(
        persistBody,
        isNot(contains(".from('scheduled_notifications').upsert")),
      );
    },
  );
}
