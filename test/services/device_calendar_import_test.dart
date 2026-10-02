import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/external_calendar_repository.dart';
import 'package:mobile/services/device_calendar_bridge.dart';
import 'package:mobile/services/device_calendar_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final from = DateTime.utc(2026, 9);
final until = DateTime.utc(2026, 11);
Map<String, dynamic> event({
  String calendar = 'native-1',
  String anchor = 'time:2026-10-02T10:00:00Z',
  String start = '2026-10-02T10:00:00Z',
}) => {
  'native_calendar_id': calendar,
  'provider_event_id': 'series-1',
  'recurrence_id': anchor,
  'title': 'An appointment',
  'all_day': false,
  'starts_at': start,
  'ends_at': '2026-10-04T11:00:00Z',
};
Map<String, dynamic> snapshot(
  List<Map<String, dynamic>> events, {
  List<String> ids = const ['native-1'],
  DateTime? start,
  DateTime? end,
}) => {
  'complete': true,
  'calendarIds': ids,
  'fromMs': (start ?? from).millisecondsSinceEpoch,
  'untilMs': (end ?? until).millisecondsSinceEpoch,
  'events': events,
};
Map<String, dynamic> source(
  String id, {
  String? binding,
  String owner = 'device',
}) => {
  'id': id,
  'native_id': 'native-$id',
  'label': 'Calendar $id',
  'account_label': 'An account',
  'kind': 'device',
  'available': true,
  'selected': true,
  'google_source_id': binding,
  'owned_by': owner,
};

class FakeBridge implements DeviceCalendarBridge {
  @override
  bool supported = true;
  String permission = 'granted';
  int prompts = 0;
  final requested = <List<String>>[];
  final emitter = StreamController<void>.broadcast();
  Future<DeviceCalendarSnapshot> Function(List<String>, DateTime, DateTime)?
  read;
  @override
  Stream<void> get changes => emitter.stream;
  @override
  Future<String> deviceId() async => 'device-a';
  @override
  Future<String> permissionStatus() async => permission;
  @override
  Future<String> requestPermission() async {
    prompts++;
    return permission;
  }

  @override
  Future<List<DeviceCalendarInventorySource>> listCalendars() async => const [
    DeviceCalendarInventorySource(
      nativeId: 'native-1',
      label: 'Personal',
      accountLabel: 'An account',
      kind: 'device',
    ),
  ];
  @override
  Future<DeviceCalendarSnapshot> readSnapshot(
    List<String> ids,
    DateTime start,
    DateTime end,
  ) {
    requested.add(ids);
    return read?.call(ids, start, end) ??
        Future.value(
          DeviceCalendarSnapshot.validate(
            snapshot([], ids: ids, start: start, end: end),
            calendarIds: ids,
            from: start,
            until: end,
          ),
        );
  }
}

class Harness {
  Harness({
    List<Map<String, dynamic>>? sources,
    bool automatic = true,
    Duration timeout = const Duration(seconds: 2),
  }) {
    rows = sources ?? [source('1')];
    enabled = automatic;
    repository = ExternalCalendarRepository(
      client,
      lane: 'staging',
      currentAccount: () => account,
      request: (body) async {
        calls.add(body);
        if (body['action'] == 'device_status' && failStatus) {
          failStatus = false;
          throw const ExternalCalendarFailure(
            code: 'unavailable',
            retryable: true,
          );
        }
        if (body['action'] != 'device_status') {
          expect(body['device_id'], 'device-a');
          expect(body['expected_revision'], revision);
          revision++;
        }
        if (body['action'] == 'device_pause') enabled = false;
        if (body['action'] == 'device_resume') enabled = true;
        return {
          'available': true,
          'connection': {
            'id': 'connection-1',
            'owner_device_id': 'device-a',
            'status': enabled ? 'connected' : 'paused',
            'automatic': enabled,
            'revision': revision,
          },
          'sources': rows,
        };
      },
    );
    controller = DeviceCalendarController(
      repository: repository,
      bridge: bridge,
      operationTimeout: timeout,
      pollInterval: const Duration(seconds: 5),
      clock: () => now,
    );
  }
  final client = SupabaseClient(
    'https://example.supabase.co',
    'public-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  final bridge = FakeBridge();
  late final ExternalCalendarRepository repository;
  late final DeviceCalendarController controller;
  final calls = <Map<String, dynamic>>[];
  late List<Map<String, dynamic>> rows;
  late bool enabled;
  int revision = 1;
  DateTime now = DateTime.utc(2026, 10, 2);
  String? account = 'account-a';
  bool failStatus = false;
  Future<void> dispose() async {
    controller.dispose();
    await bridge.emitter.close();
    await client.dispose();
  }

  List<Map<String, dynamic>> get uploads =>
      calls.where((call) => call['action'] == 'device_snapshot').toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('complete native projection snapshots', () {
    test('moved recurring occurrence retains its original identity', () {
      final first = DeviceCalendarSnapshot.validate(
        snapshot([event()]),
        calendarIds: ['native-1'],
        from: from,
        until: until,
      );
      final moved = DeviceCalendarSnapshot.validate(
        snapshot([event(start: '2026-10-03T10:00:00Z')]),
        calendarIds: ['native-1'],
        from: from,
        until: until,
      );
      expect(
        first.eventsByCalendar['native-1']!.single['recurrence_id'],
        moved.eventsByCalendar['native-1']!.single['recurrence_id'],
      );
      expect(
        first.eventsByCalendar['native-1']!.single['starts_at'],
        isNot(moved.eventsByCalendar['native-1']!.single['starts_at']),
      );
    });
    test(
      'keeps all-day civil dates and original instants with exclusive end',
      () {
        final row = event()
          ..addAll({
            'all_day': true,
            'start_date': '2026-10-02',
            'end_date': '2026-10-03',
            'starts_at': '2026-10-02T07:00:00Z',
            'ends_at': '2026-10-03T07:00:00Z',
          });
        final result = DeviceCalendarSnapshot.validate(
          snapshot([row]),
          calendarIds: ['native-1'],
          from: from,
          until: until,
        );
        expect(
          result.eventsByCalendar['native-1']!.single['starts_at'],
          '2026-10-02T07:00:00Z',
        );
        expect(
          result.eventsByCalendar['native-1']!.single['end_date'],
          '2026-10-03',
        );
      },
    );
    for (final failure in [
      'incomplete',
      'wrong range',
      'missing source',
      'extra source',
      'duplicate',
      'invalid civil',
    ]) {
      test('$failure cannot authorize reconciliation', () {
        final data = snapshot([event()]);
        switch (failure) {
          case 'incomplete':
            data['complete'] = false;
          case 'wrong range':
            data['untilMs'] = 1;
          case 'missing source':
            data['calendarIds'] = <String>[];
          case 'extra source':
            data['events'] = [event(calendar: 'other')];
          case 'duplicate':
            data['events'] = [event(), event()];
          case 'invalid civil':
            data['events'] = [
              event()..addAll({
                'all_day': true,
                'start_date': '2026-02-31',
                'end_date': '2026-03-01',
              }),
            ];
        }
        expect(
          () => DeviceCalendarSnapshot.validate(
            data,
            calendarIds: ['native-1'],
            from: from,
            until: until,
          ),
          throwsA(isA<DeviceCalendarFailure>()),
        );
      });
    }
  });

  test(
    'failed first status still retries on resume without permission prompts',
    () async {
      final h = Harness()..failStatus = true;
      try {
        h.controller.startForAccount();
        await Future<void>.delayed(const Duration(milliseconds: 5));
        expect(h.controller.errorCode, 'unavailable');
        h.controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await Future<void>.delayed(const Duration(milliseconds: 5));
        expect(h.uploads, hasLength(1));
        expect(h.bridge.prompts, 0);
        expect(h.controller.busy, false);
      } finally {
        h.controller.stop();
        await Future<void>.delayed(const Duration(milliseconds: 5));
        await h.dispose();
      }
    },
  );
  test('failed first status still retries on periodic trigger', () async {
    final h = Harness()..failStatus = true;
    addTearDown(h.dispose);
    h.controller.startForAccount();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await Future<void>.delayed(const Duration(seconds: 5));
    expect(h.uploads, hasLength(1));
    expect(h.bridge.prompts, 0);
  });
  test(
    'denied access does not upload an empty snapshot or prompt automatically',
    () async {
      final h = Harness();
      h.bridge.permission = 'denied';
      try {
        h.controller.startForAccount();
        await Future<void>.delayed(const Duration(milliseconds: 5));
        expect(h.controller.errorCode, 'permission_denied');
        expect(h.uploads, isEmpty);
        expect(h.bridge.prompts, 0);
        await h.controller.connect();
        expect(h.bridge.prompts, 1);
        expect(h.uploads, isEmpty);
      } finally {
        h.controller.stop();
        await Future<void>.delayed(const Duration(milliseconds: 5));
        await h.dispose();
      }
    },
  );
  test(
    'timeout releases busy, fences late native result, and allows retry',
    () async {
      final h = Harness(timeout: const Duration(seconds: 1));
      try {
        final pending = Completer<DeviceCalendarSnapshot>();
        h.bridge.read = (_, _, _) => pending.future;
        h.controller.startForAccount();
        await Future<void>.delayed(const Duration(milliseconds: 5));
        expect(h.controller.busy, true);
        await Future<void>.delayed(const Duration(milliseconds: 1050));
        expect(h.controller.errorCode, 'timeout');
        expect(h.controller.busy, false);
        pending.complete(
          DeviceCalendarSnapshot.validate(
            snapshot(
              [],
              start: DateTime.utc(2026, 4, 5),
              end: DateTime.utc(2027, 10, 2),
            ),
            calendarIds: ['native-1'],
            from: DateTime.utc(2026, 4, 5),
            until: DateTime.utc(2027, 10, 2),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 5));
        expect(h.uploads, isEmpty);
        h.bridge.read = null;
        await h.controller.refresh();
        expect(h.uploads, hasLength(1));
      } finally {
        h.controller.stop();
        await Future<void>.delayed(const Duration(milliseconds: 5));
        await h.dispose();
      }
    },
  );
  test(
    'account departure discards pending native content before upload',
    () async {
      final h = Harness();
      try {
        final pending = Completer<DeviceCalendarSnapshot>();
        h.bridge.read = (_, _, _) => pending.future;
        h.controller.startForAccount();
        await Future<void>.delayed(const Duration(milliseconds: 5));
        h.account = 'account-b';
        pending.complete(
          DeviceCalendarSnapshot.validate(
            snapshot([]),
            calendarIds: ['native-1'],
            from: from,
            until: until,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 5));
        expect(h.uploads, isEmpty);
        expect(h.controller.status.connectionId, isNull);
        expect(h.controller.busy, false);
      } finally {
        h.controller.stop();
        await Future<void>.delayed(const Duration(milliseconds: 5));
        await h.dispose();
      }
    },
  );
  test(
    'Google owned calendars remain excluded even after their binding disappears',
    () async {
      final h = Harness(
        sources: [
          source('1'),
          source('2', binding: 'google-source', owner: 'google'),
          source('3', owner: 'google'),
        ],
      );
      try {
        h.controller.startForAccount();
        await Future<void>.delayed(const Duration(milliseconds: 5));
        expect(h.bridge.requested.single, ['native-1']);
        expect(
          (h.uploads.single['sources'] as List).map(
            (row) => (row as Map)['id'],
          ),
          ['1'],
        );
        expect(h.controller.unresolvedCloudSources, {'3'});
      } finally {
        h.controller.stop();
        await Future<void>.delayed(const Duration(milliseconds: 5));
        await h.dispose();
      }
    },
  );
  test('source chooser drafts survive resume and background polling', () async {
    final h = Harness(automatic: false);
    addTearDown(h.dispose);
    h.controller.startForAccount();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await h.controller.chooseCalendars();
    h.controller.selectSource('1', false);
    h.controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(const Duration(seconds: 5));
    expect(h.controller.selectedSources, isEmpty);
    expect(h.controller.choosing, true);
  });
  test(
    'paused connection never reads or requests permission automatically',
    () async {
      final h = Harness(automatic: false);
      try {
        h.controller.startForAccount();
        await Future<void>.delayed(const Duration(milliseconds: 5));
        await Future<void>.delayed(const Duration(seconds: 5));
        expect(h.bridge.requested, isEmpty);
        expect(h.uploads, isEmpty);
        expect(h.bridge.prompts, 0);
      } finally {
        h.controller.stop();
        await Future<void>.delayed(const Duration(milliseconds: 5));
        await h.dispose();
      }
    },
  );
  test(
    'native bridges expose no calendar writes and preserve original occurrence anchors',
    () {
      final ios = File(
        'ios/Runner/DeviceCalendarBridge.swift',
      ).readAsStringSync();
      final android = File(
        'android/app/src/main/kotlin/com/jaralephillips/hawcalendar/DeviceCalendarBridge.kt',
      ).readAsStringSync();
      expect(ios, contains('event.occurrenceDate'));
      expect(android, contains('originalInstanceTime'));
      expect(
        ios,
        isNot(matches(RegExp(r'\b(?:store|eventStore)\.(?:save|remove)\s*\('))),
      );
      expect(
        android,
        isNot(
          matches(RegExp(r'contentResolver\.(?:insert|update|delete)\s*\(')),
        ),
      );
      expect(ios, contains('permission_denied'));
      expect(android, contains('permission_denied'));
      expect(
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
        isNot(contains('WRITE_CALENDAR')),
      );
    },
  );

  test(
    'defaults OFF until access succeeds and failed first import stays OFF',
    () async {
      final h = Harness(automatic: false);
      addTearDown(h.dispose);
      h.bridge.read = (_, _, _) async =>
          throw const DeviceCalendarFailure('read_failed');
      await h.controller.connect();
      expect(h.controller.status.automatic, false);
      await h.controller.saveSelection();
      expect(h.controller.status.automatic, false);
      expect(h.controller.errorCode, 'read_failed');
      expect(
        h.calls.where((call) => call['action'] == 'device_resume'),
        isEmpty,
      );
    },
  );
  test(
    'pause retains imports and requires successful read before resume',
    () async {
      final h = Harness();
      addTearDown(h.dispose);
      await h.controller.refresh();
      await h.controller.setAutomatic(false);
      expect(h.controller.status.automatic, false);
      expect(
        h.calls.where((call) => call['action'] == 'device_disconnect'),
        isEmpty,
      );
      h.bridge.permission = 'denied';
      await h.controller.setAutomatic(true);
      expect(h.controller.status.automatic, false);
      expect(h.uploads, hasLength(1));
      h.bridge.permission = 'granted';
      await h.controller.setAutomatic(true);
      expect(h.controller.status.automatic, true);
      expect(h.uploads, hasLength(2));
    },
  );
  test(
    'skips auto-start when a sync just ran and retries after cooldown',
    () async {
      final h = Harness();
      addTearDown(h.dispose);
      h.controller.startForAccount();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(h.uploads, hasLength(1));
      h.controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(h.uploads, hasLength(1));
      h.now = h.now.add(const Duration(minutes: 3));
      h.controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(h.uploads, hasLength(2));
    },
  );
  test('native changes bypass recent successful import cooldown', () async {
    final h = Harness();
    addTearDown(h.dispose);
    h.controller.startForAccount();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    h.bridge.emitter.add(null);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    expect(h.uploads, hasLength(2));
  });
  test('unavailable selected calendar can be explicitly deselected', () async {
    final h = Harness(automatic: false);
    addTearDown(h.dispose);
    h.rows.single['available'] = false;
    await h.controller.chooseCalendars();
    h.controller.selectSource('1', false);
    expect(h.controller.selectedSources, isEmpty);
    h.controller.selectSource('1', true);
    expect(h.controller.selectedSources, isEmpty);
  });
  test(
    'orphaned Google ownership requires an explicit replacement choice',
    () async {
      final h = Harness(
        automatic: false,
        sources: [source('1', owner: 'google')],
      );
      addTearDown(h.dispose);
      await h.controller.chooseCalendars();
      await h.controller.saveSelection();
      expect(h.controller.errorCode, 'source_ownership_required');
      expect(
        h.calls.where((call) => call['action'] == 'device_select_sources'),
        isEmpty,
      );
      expect(h.controller.choosing, true);
      h.controller.bindCloudSource('1', null);
      expect(h.controller.unresolvedCloudSources, isEmpty);
    },
  );
  test(
    'a newly visible range queued during an import is caught up immediately',
    () async {
      final h = Harness();
      addTearDown(h.dispose);
      final pending = Completer<DeviceCalendarSnapshot>();
      DateTime? capturedFrom, capturedUntil;
      var first = true;
      h.bridge.read = (ids, start, end) {
        if (first) {
          first = false;
          capturedFrom = start;
          capturedUntil = end;
          return pending.future;
        }
        return Future.value(
          DeviceCalendarSnapshot.validate(
            snapshot([], ids: ids, start: start, end: end),
            calendarIds: ids,
            from: start,
            until: end,
          ),
        );
      };
      h.controller.startForAccount();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      h.controller.ensureRange(DateTime.utc(2028, 1), DateTime.utc(2028, 2));
      pending.complete(
        DeviceCalendarSnapshot.validate(
          snapshot([], start: capturedFrom, end: capturedUntil),
          calendarIds: ['native-1'],
          from: capturedFrom!,
          until: capturedUntil!,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 15));
      expect(h.uploads, hasLength(2));
      expect(h.uploads.last['start'], DateTime.utc(2028, 1).toIso8601String());
      h.controller.ensureRange(
        DateTime.utc(2028, 1, 2),
        DateTime.utc(2028, 1, 5),
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(h.uploads, hasLength(2));
    },
  );
  test(
    'Google-only selections cannot turn visible range requests into an import loop',
    () async {
      final h = Harness(
        sources: [source('1', owner: 'google', binding: 'google-source')],
      );
      addTearDown(h.dispose);
      h.controller.startForAccount();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      h.controller.ensureRange(from, until);
      await Future<void>.delayed(const Duration(milliseconds: 15));
      expect(h.uploads, isEmpty);
      expect(h.calls, hasLength(1));
    },
  );
  test('native channel deadline is observable as a typed failure', () async {
    const channel = MethodChannel('test/device-calendar-timeout');
    final pending = Completer<dynamic>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) => pending.future);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final bridge = MethodChannelDeviceCalendarBridge(
      channel: channel,
      supported: true,
      requestTimeout: const Duration(milliseconds: 1),
    );
    await expectLater(
      bridge.permissionStatus(),
      throwsA(
        isA<DeviceCalendarFailure>().having((e) => e.code, 'code', 'timeout'),
      ),
    );
    pending.complete('granted');
  });
}
