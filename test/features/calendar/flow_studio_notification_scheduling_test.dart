import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

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
      final localCleanup = body.indexOf(
        '_removeLocalNotesForFlowReplacement(flowId)',
        replaceCall,
      );
      final scheduleCall = body.indexOf(
        'final scheduleResult = await _scheduleAlertForEvent(',
        upsertCall,
      );

      expect(plannedBranch, greaterThanOrEqualTo(0));
      expect(replaceCall, greaterThan(plannedBranch));
      expect(replaceCall, lessThan(writeLoop));
      expect(localCleanup, greaterThan(replaceCall));
      expect(localCleanup, lessThan(writeLoop));
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
      expect(notifySource, contains('needsUserVisibleWarning'));
      expect(
        pageSource,
        contains('scheduleResult?.needsUserVisibleWarning == true'),
      );
      expect(
        pageSource,
        contains('_showNotificationScheduleWarning(notificationWarning)'),
      );
    },
  );

  test(
    'Android event reminders require exact scheduling when exact alarms are available',
    () {
      final source = File(
        'lib/features/calendar/notify.dart',
      ).readAsStringSync();
      final scheduleLocal = _sliceBetween(
        source,
        'static Future<void> _scheduleLocalNotification',
        'static Future<AndroidScheduleMode> _androidScheduleMode',
      );
      final modeSelector = _sliceBetween(
        source,
        'static Future<AndroidScheduleMode> _androidScheduleMode',
        'static bool _isExactAlarmDenied',
      );

      expect(source, contains('_notificationRequiresExactLocalDelivery'));
      expect(source, contains('case NotificationType.eventStart:'));
      expect(source, contains('case NotificationType.reminder10min:'));
      expect(scheduleLocal, contains('requireExact: requireExact'));
      expect(scheduleLocal, contains('Android schedule mode selected'));
      expect(modeSelector, contains('AndroidScheduleMode.exactAllowWhileIdle'));
      expect(modeSelector, contains('requireExact'));
      expect(modeSelector, contains('_androidExactAlarmsAvailable()'));
    },
  );

  test(
    'Android exact-alarm denial returns a visible warning instead of inexact event-time success',
    () {
      final notifySource = File(
        'lib/features/calendar/notify.dart',
      ).readAsStringSync();
      final pageSource = File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsStringSync();

      expect(
        notifySource,
        contains('NotificationScheduleOutcome.exactAlarmUnavailable'),
      );
      expect(notifySource, contains('exactAlarmUnavailableMessage'));
      expect(notifySource, contains('_ExactAlarmUnavailableException'));
      expect(
        notifySource,
        contains(
          'return const NotificationScheduleResult.exactAlarmUnavailable',
        ),
      );
      expect(notifySource, contains('if (requireExact) {\n          _log('));
      expect(pageSource, contains('needsUserVisibleWarning'));
    },
  );

  test('Android manifest declares scheduled notification receivers', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(
      manifest,
      contains(
        'com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver',
      ),
    );
    expect(
      manifest,
      contains(
        'com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver',
      ),
    );
    expect(manifest, contains('android.intent.action.MY_PACKAGE_REPLACED'));
  });

  test(
    'edited custom flow day view dedupes by logical flow event, not CID time',
    () {
      final calendarSource = File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsStringSync();
      final dayViewSource = File(
        'lib/features/calendar/day_view.dart',
      ).readAsStringSync();

      expect(calendarSource, contains('_visibleDayFlowLogicalKey'));
      expect(calendarSource, contains('flow-logical|\$flowId|\$titleKey'));
      expect(dayViewSource, contains('flowLogicalIndexByKey'));
      expect(dayViewSource, contains('flow-logical|\$flowId|\$titleKey'));
    },
  );

  test(
    'local timezone conversion keeps UTC starts_at at the PDT wall time',
    () {
      tzdata.initializeTimeZones();
      final losAngeles = tz.getLocation('America/Los_Angeles');
      final startsAtUtc = DateTime.parse('2026-06-02T10:57:00.000Z');
      final local = tz.TZDateTime.from(startsAtUtc, losAngeles);

      expect(local.year, 2026);
      expect(local.month, 6);
      expect(local.day, 2);
      expect(local.hour, 3);
      expect(local.minute, 57);
      expect(local.timeZoneName, 'PDT');
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
