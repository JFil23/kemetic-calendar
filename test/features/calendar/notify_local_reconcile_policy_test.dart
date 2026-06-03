import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/notify.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Los_Angeles'));
  });

  const baseScheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
  final baseScheduledAt = DateTime.utc(2026, 6, 3, 14, 30);

  String fingerprint({
    int id = 42,
    DateTime? scheduledAt,
    String title = 'Morning practice',
    String body = 'Tap to open in Kemetic.',
    String payload = '{"route":"/calendar/day"}',
    NotificationType type = NotificationType.eventStart,
    bool requireExact = true,
    AndroidScheduleMode mode = baseScheduleMode,
  }) {
    return Notify.debugBuildLocalNotificationFingerprint(
      notificationId: id,
      scheduledAt: scheduledAt ?? baseScheduledAt,
      title: title,
      body: body,
      payload: payload,
      type: type,
      requireExact: requireExact,
      androidScheduleMode: mode,
    );
  }

  test('identical pending fingerprint is left untouched during refresh', () {
    final desired = fingerprint();

    final action = Notify.debugPlanLocalReconcileAction(
      alreadyPending: true,
      refreshExisting: true,
      exactBlocked: false,
      storedFingerprint: desired,
      desiredFingerprint: desired,
    );

    expect(action, NotifyLocalReconcileAction.leaveUnchanged);
  });

  test(
    'changed fire time refreshes only the matching pending notification',
    () {
      final stored = fingerprint();
      final desired = fingerprint(
        scheduledAt: baseScheduledAt.add(const Duration(minutes: 15)),
      );

      expect(stored, isNot(desired));
      expect(
        Notify.debugPlanLocalReconcileAction(
          alreadyPending: true,
          refreshExisting: true,
          exactBlocked: false,
          storedFingerprint: stored,
          desiredFingerprint: desired,
        ),
        NotifyLocalReconcileAction.refreshChanged,
      );
    },
  );

  test(
    'changed visible content or payload refreshes the pending notification',
    () {
      final stored = fingerprint();
      final variants = <String>[
        fingerprint(title: 'Evening practice'),
        fingerprint(body: 'Updated body'),
        fingerprint(payload: '{"route":"/calendar/day","id":"changed"}'),
      ];

      for (final desired in variants) {
        expect(desired, isNot(stored));
        expect(
          Notify.debugPlanLocalReconcileAction(
            alreadyPending: true,
            refreshExisting: true,
            exactBlocked: false,
            storedFingerprint: stored,
            desiredFingerprint: desired,
          ),
          NotifyLocalReconcileAction.refreshChanged,
        );
      }
    },
  );

  test('changed exactness or schedule mode refreshes correctly', () {
    final stored = fingerprint();
    final noExact = fingerprint(
      requireExact: false,
      mode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
    final modeChanged = fingerprint(mode: AndroidScheduleMode.alarmClock);

    expect(noExact, isNot(stored));
    expect(modeChanged, isNot(stored));
    for (final desired in <String>[noExact, modeChanged]) {
      expect(
        Notify.debugPlanLocalReconcileAction(
          alreadyPending: true,
          refreshExisting: true,
          exactBlocked: false,
          storedFingerprint: stored,
          desiredFingerprint: desired,
        ),
        NotifyLocalReconcileAction.refreshChanged,
      );
    }
  });

  test('missing, non-refresh, and exact-blocked rows keep prior semantics', () {
    final desired = fingerprint();

    expect(
      Notify.debugPlanLocalReconcileAction(
        alreadyPending: false,
        refreshExisting: true,
        exactBlocked: false,
        storedFingerprint: null,
        desiredFingerprint: desired,
      ),
      NotifyLocalReconcileAction.scheduleMissing,
    );
    expect(
      Notify.debugPlanLocalReconcileAction(
        alreadyPending: true,
        refreshExisting: false,
        exactBlocked: false,
        storedFingerprint: null,
        desiredFingerprint: desired,
      ),
      NotifyLocalReconcileAction.leavePending,
    );
    expect(
      Notify.debugPlanLocalReconcileAction(
        alreadyPending: true,
        refreshExisting: true,
        exactBlocked: true,
        storedFingerprint: desired,
        desiredFingerprint: desired,
      ),
      NotifyLocalReconcileAction.cancelExactBlocked,
    );
    expect(
      Notify.debugPlanLocalReconcileAction(
        alreadyPending: false,
        refreshExisting: true,
        exactBlocked: true,
        storedFingerprint: null,
        desiredFingerprint: desired,
      ),
      NotifyLocalReconcileAction.skipExactBlocked,
    );
  });

  test('deferred rows remain durable outside the 450 local window', () {
    expect(Notify.debugLocalScheduleWindowCounts(449), (
      armed: 449,
      deferred: 0,
    ));
    expect(Notify.debugLocalScheduleWindowCounts(450), (
      armed: 450,
      deferred: 0,
    ));
    expect(Notify.debugLocalScheduleWindowCounts(589), (
      armed: 450,
      deferred: 139,
    ));
  });

  test(
    'fingerprints are deterministic hashes, not plaintext payload copies',
    () {
      final first = fingerprint();
      final second = fingerprint();

      expect(first, second);
      expect(first, startsWith('v1:'));
      expect(first, isNot(contains('Morning practice')));
      expect(first, isNot(contains('/calendar/day')));
    },
  );

  test('init and full refresh paths are serialized and coalesced', () {
    final source = File('lib/features/calendar/notify.dart').readAsStringSync();

    expect(source, contains('static Future<void>? _initFuture'));
    expect(source, contains('init() joined existing startup initialization'));
    expect(
      source,
      contains('static Future<void>? _syncLocalDeliveryModeFuture'),
    );
    expect(source, contains('static bool _syncLocalDeliveryModeQueued'));
    expect(source, contains('static Future<void>? _rescheduleAllFuture'));
    expect(source, contains('static bool _rescheduleAllQueued'));
    expect(source, contains('_rescheduleAllFromDatabaseSerialized'));
  });

  test('notification payload routing remains unchanged', () {
    final source = File('lib/features/calendar/notify.dart').readAsStringSync();

    expect(source, contains('payload: payload,'));
    expect(
      source,
      contains('CalendarPushOpenIntent.fromPayloadString(response.payload)'),
    );
    expect(source, contains('emitCalendarPushOpenIntent(intent)'));
  });
}
