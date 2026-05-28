import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const migrationPath =
      '../supabase/migrations/20260528090000_stable_scheduled_notification_ids.sql';

  String migrationSql() => File(migrationPath).readAsStringSync();

  String notifySource() =>
      File('lib/features/calendar/notify.dart').readAsStringSync();

  String functionBody(String source, String functionName, String endMarker) {
    final start = source.indexOf(functionName);
    final end = source.indexOf(endMarker, start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    return source.substring(start, end);
  }

  test('migration repairs duplicate legacy ids before enforcing uniqueness', () {
    final sql = migrationSql();

    final sequence = sql.indexOf(
      'create sequence if not exists public.scheduled_notifications_notification_id_seq',
    );
    final duplicateRank = sql.indexOf(
      'row_number() over (\n      partition by notification_id',
    );
    final duplicateUpdate = sql.indexOf(
      'update public.scheduled_notifications sn',
      duplicateRank,
    );
    final defaultSet = sql.indexOf(
      'alter column notification_id set default',
      duplicateUpdate,
    );
    final uniqueIndex = sql.indexOf(
      'create unique index if not exists scheduled_notifications_notification_id_key',
      defaultSet,
    );

    expect(sequence, greaterThanOrEqualTo(0));
    expect(sql, contains('maxvalue 2147483647'));
    expect(sql, contains('check (notification_id > 0)'));
    expect(duplicateRank, greaterThan(sequence));
    expect(duplicateUpdate, greaterThan(duplicateRank));
    expect(defaultSet, greaterThan(duplicateUpdate));
    expect(uniqueIndex, greaterThan(defaultSet));
  });

  test('RPC upserts by logical identity and preserves notification_id', () {
    final sql = migrationSql();

    expect(
      sql,
      contains(
        'create or replace function public.upsert_scheduled_notification',
      ),
    );
    expect(sql, contains('v_user_id uuid := auth.uid()'));
    expect(
      sql,
      contains('on conflict (user_id, client_event_id, notification_type)'),
    );
    expect(sql, contains('sn.notification_id'));
    expect(
      sql,
      contains(
        'grant execute on function public.upsert_scheduled_notification',
      ),
    );

    final updateStart = sql.indexOf('do update set');
    final returningStart = sql.indexOf('returning', updateStart);
    expect(updateStart, greaterThanOrEqualTo(0));
    expect(returningStart, greaterThan(updateStart));

    final updateClause = sql.substring(updateStart, returningStart);
    expect(updateClause, isNot(contains('notification_id')));
  });

  test(
    'logical variants allocate distinct stored ids through sequence default',
    () {
      final sql = migrationSql();
      final schema = File('../db/schema.sql').readAsStringSync();

      expect(
        schema,
        contains(
          'ADD CONSTRAINT "unique_user_client_event_type" UNIQUE ("user_id", "client_event_id", "notification_type")',
        ),
        reason: 'logical identity must remain user + event + notification type',
      );
      expect(
        sql,
        contains(
          'create unique index if not exists scheduled_notifications_notification_id_key',
        ),
      );

      final insertStart = sql.indexOf(
        'insert into public.scheduled_notifications as sn (',
      );
      final valuesStart = sql.indexOf('  values (', insertStart);
      expect(insertStart, greaterThanOrEqualTo(0));
      expect(valuesStart, greaterThan(insertStart));

      final insertColumns = sql.substring(insertStart, valuesStart);
      expect(
        insertColumns,
        isNot(contains('notification_id')),
        reason: 'inserts should allocate from the DB default sequence',
      );
    },
  );

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
