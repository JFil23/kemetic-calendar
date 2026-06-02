import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _sliceBetween(String source, String startNeedle, String endNeedle) {
  final start = source.indexOf(startNeedle);
  expect(start, greaterThanOrEqualTo(0), reason: startNeedle);
  final end = source.indexOf(endNeedle, start);
  expect(end, greaterThan(start), reason: endNeedle);
  return source.substring(start, end);
}

void main() {
  test(
    'edited custom planned-note flows replace stale occurrences before scheduling at-time alerts',
    () {
      final source = File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsStringSync();
      final body = _sliceBetween(
        source,
        'Future<int?> _persistFlowStudioResult(_FlowStudioResult r) async',
        '/// Schedules all note occurrences for a flow',
      );

      final plannedBranch = body.indexOf('if (r.plannedNotes.isNotEmpty)');
      final replaceCall = body.indexOf(
        'await repo2.deleteByFlowId(',
        plannedBranch,
      );
      final writeLoop = body.indexOf(
        'for (final p in r.plannedNotes)',
        plannedBranch,
      );
      final upsertCall = body.indexOf(
        'await repo2.upsertByClientId(',
        writeLoop,
      );
      final scheduleCall = body.indexOf(
        'final scheduleResult = await _scheduleAlertForEvent(',
        upsertCall,
      );

      expect(plannedBranch, greaterThanOrEqualTo(0));
      expect(replaceCall, greaterThan(plannedBranch));
      expect(replaceCall, lessThan(writeLoop));
      expect(body, contains("semantic: 'flow_replace'"));
      expect(body, contains('suppressesClient: false'));
      expect(body, contains("'planned_flow_replace'"));
      expect(upsertCall, greaterThan(writeLoop));
      expect(scheduleCall, greaterThan(upsertCall));
      expect(body, contains('alertMinutes: n.alertOffsetMinutes'));
    },
  );

  test(
    'changed event times replace the existing notification id before re-arming',
    () {
      final source = File(
        'lib/features/calendar/notify.dart',
      ).readAsStringSync();
      final body = _sliceBetween(
        source,
        'static Future<NotificationScheduleResult> scheduleAlertWithPersistenceResult',
        '/// Best-effort bulk cancellation used by delete/reconcile paths.',
      );

      final existingLookup = body.indexOf(
        'final existing = await _getNotificationByEventId(',
      );
      final cancelExisting = body.indexOf(
        'await _plugin.cancel(notificationId);',
        existingLookup,
      );
      final localReconcile = body.indexOf(
        '_requestLocalWindowReconcile();',
        cancelExisting,
      );
      final localFallback = body.indexOf(
        'await _scheduleLocalNotification(',
        cancelExisting,
      );

      expect(existingLookup, greaterThanOrEqualTo(0));
      expect(cancelExisting, greaterThan(existingLookup));
      expect(localReconcile, greaterThan(cancelExisting));
      expect(localFallback, greaterThan(cancelExisting));
    },
  );

  test(
    'missing local notification permission is surfaced instead of silent success',
    () {
      final notifySource = File(
        'lib/features/calendar/notify.dart',
      ).readAsStringSync();
      final pageSource = File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsStringSync();

      expect(
        notifySource,
        contains('NotificationScheduleOutcome.permissionMissing'),
      );
      expect(notifySource, contains('requestNotificationsPermission()'));
      expect(notifySource, contains('localPermissionMissingMessage'));
      expect(notifySource, contains('localDeliveryPermissionWarning'));
      expect(
        notifySource,
        contains('return const NotificationScheduleResult.permissionMissing'),
      );
      expect(
        pageSource,
        contains('scheduleResult?.isPermissionMissing == true'),
      );
      expect(
        pageSource,
        contains('_showNotificationScheduleWarning(notificationWarning)'),
      );
    },
  );

  test(
    'headless Ma’at flow delivery still uses EventFilingService offsets',
    () {
      final source = File(
        'lib/features/calendar/flow_join_service.dart',
      ).readAsStringSync();

      expect(source, contains('EventFilingService? eventFiling'));
      expect(
        source,
        contains('_eventFiling = eventFiling ?? EventFilingService()'),
      );
      expect(
        source,
        contains('if (alertOffsetMinutes != kEventFilingNoAlertMinutes)'),
      );
      expect(source, contains('alertOffsetMinutes: alertOffsetMinutes'));
      expect(source, contains('startsAtLocal: occurrence.startLocal'));
    },
  );
}
