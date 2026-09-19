import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String notifySource() =>
      File('lib/features/calendar/notify.dart').readAsStringSync();

  String functionBody(String source, String functionName, String endMarker) {
    final start = source.indexOf(functionName);
    final end = source.indexOf(endMarker, start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    return source.substring(start, end);
  }

  test('Notify normal persisted path prefers DB-returned notification_id', () {
    final source = notifySource();
    final scheduleBody = functionBody(
      source,
      'static Future<void> scheduleAlertWithPersistence',
      '/// Best-effort bulk cancellation',
    );

    expect(
      scheduleBody,
      contains(
        'final persistedNotification = await _persistNotificationToDatabase(',
      ),
    );
    expect(
      scheduleBody,
      contains(
        'persistedNotification?.notificationId ?? fallbackNotificationId',
      ),
    );

    final persistCall = scheduleBody.indexOf(
      'final persistedNotification = await _persistNotificationToDatabase(',
    );
    final finalId = scheduleBody.indexOf(
      'persistedNotification?.notificationId ?? fallbackNotificationId',
      persistCall,
    );
    expect(finalId, greaterThan(persistCall));
  });

  test(
    'Notify persistence uses RPC and no longer writes hash ids directly',
    () {
      final source = notifySource();
      final persistBody = functionBody(
        source,
        'static Future<_PersistedNotification?> _persistNotificationToDatabase',
        '/// **PRIVATE**: Get notification by event ID',
      );

      expect(
        persistBody,
        contains("client.rpc(\n        'upsert_scheduled_notification'"),
      );
      expect(persistBody, contains("'p_notification_type': type.value"));
      expect(persistBody, isNot(contains("'notification_id':")));
      expect(
        persistBody,
        isNot(contains(".from('scheduled_notifications').upsert")),
      );
    },
  );

  test('fallback hash helper is marked fallback-only', () {
    final source = notifySource();

    expect(source, contains('Fallback-only platform id'));
    expect(source, contains('_generateFallbackNotificationId'));
    expect(source, isNot(contains('_generateStableNotificationId')));
  });

  test(
    'cancel and reconcile continue to use persisted row notification_id',
    () {
      final source = notifySource();
      final reconcileBody = functionBody(
        source,
        'static Future<void> _reconcileLocalScheduleWindow',
        'static Future<void> syncLocalDeliveryMode',
      );
      final cancelBody = functionBody(
        source,
        'static Future<void> cancelNotificationsForClientEventIds',
        'static Future<void> cancelNotificationForEvent',
      );

      expect(reconcileBody, contains("row['notification_id'] as int"));
      expect(reconcileBody, contains('desiredIds.contains(notif.id)'));
      expect(
        cancelBody,
        contains(".select('client_event_id, notification_id')"),
      );
      expect(cancelBody, contains("row['notification_id'] as int?"));
      expect(cancelBody, contains('await _plugin.cancel(notificationId)'));
    },
  );
}
