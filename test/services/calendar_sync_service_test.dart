import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mobile/data/user_events_repo.dart';
import 'package:mobile/features/settings/settings_prefs.dart';
import 'package:mobile/services/calendar_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _testUserId = 'a38c7721-36a8-4a08-b66f-246daef72b43';
const _calendarSyncBoxNames = <String>[
  'calendar_sync.cache.v1',
  'calendar_sync.state.v1',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await _ensureSupabaseInitialized();
    hiveDir = await Directory.systemTemp.createTemp('calendar_sync_test_');
    try {
      Hive.init(hiveDir.path);
    } catch (_) {}
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await _clearCalendarSyncBoxes();
    await _recoverTestSession();
  });

  tearDown(() async {
    await _clearCalendarSyncBoxes();
  });

  tearDownAll(() async {
    await _clearCalendarSyncBoxes();
    if (await hiveDir.exists()) {
      await hiveDir.delete(recursive: true);
    }
  });

  group('isImportedDeviceCalendarEvent', () {
    test('detects native cid imports', () {
      expect(
        isImportedDeviceCalendarEvent(
          clientEventId: 'native:ios:abc123',
          category: null,
        ),
        isTrue,
      );
    });

    test('detects legacy native_sync category imports', () {
      expect(
        isImportedDeviceCalendarEvent(
          clientEventId: 'ky=1-km=1-kd=1|s=540|t=test|f=-1',
          category: 'native_sync',
        ),
        isTrue,
      );
    });

    test('does not treat app-owned events as imported device events', () {
      expect(
        isImportedDeviceCalendarEvent(
          clientEventId: 'ky=1-km=1-kd=1|s=540|t=test|f=-1',
          category: null,
        ),
        isFalse,
      );
    });
  });

  group('parseCalendarSyncTimestamp', () {
    test('parses stored ISO timestamps', () {
      final parsed = parseCalendarSyncTimestamp('2026-04-15T12:34:56.000Z');

      expect(parsed, isNotNull);
      expect(parsed!.toUtc().year, 2026);
      expect(parsed.toUtc().month, 4);
      expect(parsed.toUtc().day, 15);
    });

    test('returns null for unsupported values', () {
      expect(parseCalendarSyncTimestamp(null), isNull);
      expect(parseCalendarSyncTimestamp(123), isNull);
      expect(parseCalendarSyncTimestamp(''), isNull);
      expect(parseCalendarSyncTimestamp('not-a-date'), isNull);
    });
  });

  group('shouldBackOffCalendarPermissionRequest', () {
    test('backs off while denial is still recent', () {
      final now = DateTime.utc(2026, 4, 15, 20);
      final lastDenied = now.subtract(const Duration(hours: 2));

      final result = shouldBackOffCalendarPermissionRequest(
        now: now,
        lastPermissionDeniedAt: lastDenied,
      );

      expect(result, isTrue);
    });

    test('allows retry after cooldown', () {
      final now = DateTime.utc(2026, 4, 15, 20);
      final lastDenied = now.subtract(const Duration(hours: 13));

      final result = shouldBackOffCalendarPermissionRequest(
        now: now,
        lastPermissionDeniedAt: lastDenied,
      );

      expect(result, isFalse);
    });
  });

  group('shouldSkipCalendarAutoStartSync', () {
    test('skips auto-start when a sync just ran', () {
      final now = DateTime.utc(2026, 4, 15, 20, 0, 0);
      final lastSync = now.subtract(const Duration(seconds: 45));

      final result = shouldSkipCalendarAutoStartSync(
        now: now,
        lastSyncAt: lastSync,
      );

      expect(result, isTrue);
    });

    test('runs auto-start sync when last sync is stale', () {
      final now = DateTime.utc(2026, 4, 15, 20, 0, 0);
      final lastSync = now.subtract(const Duration(minutes: 10));

      final result = shouldSkipCalendarAutoStartSync(
        now: now,
        lastSyncAt: lastSync,
      );

      expect(result, isFalse);
    });
  });

  group('calendar sync log guardrails', () {
    test(
      'debug logs summarize cids and titles instead of printing values',
      () async {
        final source = await File(
          'lib/services/calendar_sync_service.dart',
        ).readAsString();

        expect(source, isNot(contains(r'cid=$cid')));
        expect(source, isNot(contains(r'title=${native.title}')));
        expect(source, contains('_calendarSyncNativeSummary(cid, native)'));
        expect(source, contains('_calendarSyncError(e)'));
      },
    );
  });

  group('one-way calendar projection', () {
    test('automatic sync is opt-in on a new install', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();

      expect(SettingsPrefs.autoCalendarSyncEnabledFrom(prefs), isFalse);
    });

    test('native boundary has no calendar write API or permission', () async {
      final dartBridge = await File(
        'lib/services/calendar_sync_service.dart',
      ).readAsString();
      final androidBridge = await File(
        'android/app/src/main/kotlin/com/jaralephillips/hawcalendar/MainActivity.kt',
      ).readAsString();
      final androidManifest = await File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsString();
      final iosBridge = await File(
        'ios/Runner/AppDelegate.swift',
      ).readAsString();
      final iosPlist = await File('ios/Runner/Info.plist').readAsString();

      for (final source in <String>[dartBridge, androidBridge, iosBridge]) {
        expect(source, isNot(contains('upsertEvent')));
        expect(source, isNot(contains('deleteEvent')));
        expect(source, isNot(contains('purgeKemeticEvents')));
      }
      expect(androidManifest, contains('android.permission.READ_CALENDAR'));
      expect(
        androidManifest,
        isNot(contains('android.permission.WRITE_CALENDAR')),
      );
      expect(androidBridge, isNot(contains('contentResolver.insert')));
      expect(androidBridge, isNot(contains('contentResolver.update')));
      expect(androidBridge, isNot(contains('contentResolver.delete')));
      expect(iosBridge, isNot(contains('eventStore.save')));
      expect(iosBridge, isNot(contains('eventStore.remove')));
      expect(iosPlist, contains('one-way import'));
      expect(iosPlist, isNot(contains('read and write your calendar')));
    });

    test('imports all source content, including holidays', () async {
      final platform = _FakeCalendarPlatformBridge(
        events: <NativeCalendarEvent>[
          _nativeEvent(nativeId: 'work:1720000000000', title: 'Project review'),
          _nativeEvent(
            nativeId: 'holidays:1720086400000',
            title: 'Eid observance',
            allDay: true,
            start: DateTime.utc(2026, 7, 2),
          ),
        ],
      );
      final store = _FakeCalendarSyncEventStore();
      final service = _service(platform: platform, store: store);
      addTearDown(service.dispose);

      final result = await service.sync(interactive: true);

      expect(result.state, CalendarSyncRunState.synced);
      expect(result.changesApplied, 2);
      expect(store.events, hasLength(2));
      expect(
        store.events.map((event) => event.title),
        containsAll(<String>['Project review', 'Eid observance']),
      );
    });

    test('external source wins even when its modified time is older', () async {
      final cid = 'native:android:work:1720000000000';
      final platform = _FakeCalendarPlatformBridge(
        events: <NativeCalendarEvent>[
          _nativeEvent(
            nativeId: 'work:1720000000000',
            title: 'Authoritative native title',
            lastModified: DateTime.utc(2026, 6, 1),
          ),
        ],
      );
      final store = _FakeCalendarSyncEventStore(
        events: <UserEvent>[
          _userEvent(
            id: 'haw-row',
            clientEventId: cid,
            title: 'Stale HAw edit',
            updatedAt: DateTime.utc(2026, 8, 1),
          ),
        ],
      );
      final service = _service(platform: platform, store: store);
      addTearDown(service.dispose);

      final result = await service.sync(interactive: true);

      expect(result.changesApplied, 1);
      expect(store.updatedIds, <String>['haw-row']);
      expect(store.events.single.title, 'Authoritative native title');
    });

    test('recurring occurrences remain separate projections', () async {
      final platform = _FakeCalendarPlatformBridge(
        events: <NativeCalendarEvent>[
          _nativeEvent(
            nativeId: 'series-7:calendar-2:1720000000000',
            title: 'Weekly practice',
          ),
          _nativeEvent(
            nativeId: 'series-7:calendar-2:1720604800000',
            title: 'Weekly practice',
            start: DateTime.utc(2026, 7, 8, 16),
          ),
        ],
      );
      final store = _FakeCalendarSyncEventStore();
      final service = _service(platform: platform, store: store);
      addTearDown(service.dispose);

      await service.sync(interactive: true);

      expect(store.events, hasLength(2));
      expect(
        store.events.map((event) => event.clientEventId).toSet(),
        hasLength(2),
      );
    });

    test('native changes reconcile automatically and publish writes', () async {
      final platform = _FakeCalendarPlatformBridge(
        events: <NativeCalendarEvent>[
          _nativeEvent(
            nativeId: 'work:1720000000000',
            title: 'Before native edit',
          ),
        ],
      );
      final store = _FakeCalendarSyncEventStore();
      final service = _service(platform: platform, store: store);
      addTearDown(service.dispose);

      await service.start();
      expect(store.events.single.title, 'Before native edit');
      expect(platform.startMonitoringCount, 1);
      expect(platform.requestPermissionsCount, 0);

      platform.events = <NativeCalendarEvent>[
        _nativeEvent(
          nativeId: 'work:1720000000000',
          title: 'After native edit',
        ),
      ];
      platform.emitCalendarChange();
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(store.events.single.title, 'After native edit');
      expect(store.updatedIds, <String>['haw-1']);
    });

    test(
      'pause retains imports and re-enable catches up immediately',
      () async {
        final platform = _FakeCalendarPlatformBridge(
          events: <NativeCalendarEvent>[
            _nativeEvent(nativeId: 'work:1720000000000', title: 'Original'),
          ],
        );
        final store = _FakeCalendarSyncEventStore();
        final service = _service(platform: platform, store: store);
        addTearDown(service.dispose);

        await service.start();
        service.stop();
        platform.events = <NativeCalendarEvent>[
          _nativeEvent(
            nativeId: 'work:1720000000000',
            title: 'Changed while paused',
          ),
        ];
        platform.emitCalendarChange();
        await Future<void>.delayed(const Duration(milliseconds: 40));

        expect(store.events.single.title, 'Original');
        expect(store.deletedClientIds, isEmpty);

        final catchUp = await service.sync(interactive: true);
        await service.start();

        expect(catchUp.didSync, isTrue);
        expect(store.events.single.title, 'Changed while paused');
        expect(platform.startMonitoringCount, 2);
      },
    );

    test(
      'stale native rows are removed without a suppression tombstone',
      () async {
        final cid = 'native:android:removed:1720000000000';
        final platform = _FakeCalendarPlatformBridge(events: const []);
        final store = _FakeCalendarSyncEventStore(
          events: <UserEvent>[
            _userEvent(
              id: 'haw-row',
              clientEventId: cid,
              title: 'Removed on device',
            ),
          ],
        );
        final service = _service(platform: platform, store: store);
        addTearDown(service.dispose);

        final result = await service.sync(interactive: true);

        expect(result.changesApplied, 1);
        expect(store.deletedClientIds, <String>[cid]);
        expect(store.deleteSuppressesClient, <bool>[false]);
      },
    );

    test('settings enable only persists ON after a successful sync', () async {
      final source = await File(
        'lib/features/settings/settings_page.dart',
      ).readAsString();
      final enableStart = source.indexOf(
        'final result = await sync.sync(interactive: true);',
      );
      final persistOn = source.indexOf(
        'await SettingsPrefs.setAutoCalendarSyncEnabled(true);',
      );

      expect(enableStart, isNonNegative);
      expect(persistOn, greaterThan(enableStart));
      expect(source, contains('Imported events remain in HAw.'));
      expect(source, contains('unlinkImportedCalendarData()'));
    });
  });
}

CalendarSyncService _service({
  required _FakeCalendarPlatformBridge platform,
  required _FakeCalendarSyncEventStore store,
}) {
  return CalendarSyncService(
    Supabase.instance.client,
    platform: platform,
    eventsStore: store,
    nativeChangeDebounce: const Duration(milliseconds: 10),
    now: () => DateTime.utc(2026, 7, 1, 12),
  );
}

NativeCalendarEvent _nativeEvent({
  required String nativeId,
  required String title,
  bool allDay = false,
  DateTime? start,
  DateTime? lastModified,
}) {
  final eventStart = start ?? DateTime.utc(2026, 7, 1, 16);
  return NativeCalendarEvent(
    nativeId: nativeId,
    title: title,
    description: 'source detail',
    location: 'source location',
    allDay: allDay,
    start: eventStart,
    end: allDay ? null : eventStart.add(const Duration(hours: 1)),
    calendarId: 'calendar-2',
    timeZone: 'America/Los_Angeles',
    lastModified: lastModified ?? eventStart,
    clientEventId: null,
    source: 'android',
  );
}

UserEvent _userEvent({
  required String id,
  required String clientEventId,
  required String title,
  DateTime? updatedAt,
}) {
  final start = DateTime.utc(2026, 7, 1, 16);
  return UserEvent(
    id: id,
    clientEventId: clientEventId,
    title: title,
    detail: 'source detail',
    location: 'source location',
    allDay: false,
    startsAt: start,
    endsAt: start.add(const Duration(hours: 1)),
    category: 'native_sync',
    updatedAt: updatedAt ?? start,
  );
}

Future<void> _ensureSupabaseInitialized() async {
  try {
    Supabase.instance.client;
    return;
  } catch (_) {}

  await Supabase.initialize(
    url: 'https://example.supabase.co',
    publishableKey: 'anon-key-0123456789012345678901234567890123456789',
  );
}

Future<void> _recoverTestSession() async {
  final expiresAt =
      DateTime.now().add(const Duration(days: 365)).millisecondsSinceEpoch ~/
      1000;
  await Supabase.instance.client.auth.recoverSession(
    jsonEncode(<String, Object?>{
      'access_token': 'test-access-token-$expiresAt',
      'expires_in': 31536000,
      'refresh_token': 'test-refresh-token',
      'token_type': 'bearer',
      'user': <String, Object?>{
        'id': _testUserId,
        'app_metadata': <String, Object?>{
          'provider': 'email',
          'providers': <String>['email'],
        },
        'user_metadata': <String, Object?>{},
        'aud': 'authenticated',
        'email': 'calendar-sync-test@example.com',
        'phone': '',
        'created_at': '2026-01-01T00:00:00.000000Z',
        'email_confirmed_at': '2026-01-01T00:00:00.000000Z',
        'role': 'authenticated',
        'updated_at': '2026-01-01T00:00:00.000000Z',
      },
      'expiresAt': expiresAt,
    }),
  );
}

Future<void> _clearCalendarSyncBoxes() async {
  for (final name in _calendarSyncBoxNames) {
    if (Hive.isBoxOpen(name)) {
      await Hive.box<dynamic>(name).close();
    }
    try {
      await Hive.deleteBoxFromDisk(name);
    } catch (_) {}
  }
}

class _FakeCalendarPlatformBridge extends CalendarPlatformBridge {
  _FakeCalendarPlatformBridge({required this.events});

  List<NativeCalendarEvent> events;
  final StreamController<void> _changes = StreamController<void>.broadcast();
  int requestPermissionsCount = 0;
  int fetchEventsCount = 0;
  int startMonitoringCount = 0;
  int stopMonitoringCount = 0;

  @override
  Stream<void> get calendarChanges => _changes.stream;

  void emitCalendarChange() => _changes.add(null);

  @override
  Future<bool> requestPermissions() async {
    requestPermissionsCount += 1;
    return true;
  }

  @override
  Future<bool> hasPermissions() async => true;

  @override
  Future<void> startMonitoring() async {
    startMonitoringCount += 1;
  }

  @override
  Future<void> stopMonitoring() async {
    stopMonitoringCount += 1;
  }

  @override
  Future<List<NativeCalendarEvent>> fetchEvents(
    DateTime start,
    DateTime end,
  ) async {
    fetchEventsCount += 1;
    return events;
  }

  @override
  Future<void> dispose() async {
    await super.dispose();
    await _changes.close();
  }
}

class _FakeCalendarSyncEventStore implements CalendarSyncEventStore {
  _FakeCalendarSyncEventStore({List<UserEvent> events = const <UserEvent>[]})
    : events = List<UserEvent>.of(events);

  var events = <UserEvent>[];
  final updatedIds = <String>[];
  final deletedClientIds = <String>[];
  final deleteSuppressesClient = <bool>[];
  final deletedPrefixes = <String>[];
  final deletedCategories = <String>[];

  @override
  Future<UserEvent> upsertByClientId({
    required String clientEventId,
    required String title,
    required DateTime startsAtUtc,
    String? detail,
    String? location,
    bool allDay = false,
    DateTime? endsAtUtc,
    String? category,
    String? caller,
  }) async {
    final event = UserEvent(
      id: 'haw-${events.length + 1}',
      clientEventId: clientEventId,
      title: title,
      detail: detail,
      location: location,
      allDay: allDay,
      startsAt: startsAtUtc,
      endsAt: endsAtUtc,
      category: category,
      updatedAt: startsAtUtc,
    );
    events = <UserEvent>[...events, event];
    return event;
  }

  @override
  Future<UserEvent> update({
    required String id,
    String? title,
    String? detail,
    String? location,
    bool? allDay,
    DateTime? startsAt,
    DateTime? endsAt,
  }) async {
    updatedIds.add(id);
    final existing = events.firstWhere((event) => event.id == id);
    final updated = UserEvent(
      id: existing.id,
      clientEventId: existing.clientEventId,
      title: title ?? existing.title,
      detail: detail ?? existing.detail,
      location: location ?? existing.location,
      allDay: allDay ?? existing.allDay,
      startsAt: startsAt ?? existing.startsAt,
      endsAt: endsAt ?? existing.endsAt,
      category: existing.category,
      updatedAt: DateTime.utc(2026, 8),
    );
    events = <UserEvent>[
      for (final event in events)
        if (event.id == id) updated else event,
    ];
    return updated;
  }

  @override
  Future<List<UserEvent>> getEventsForWindow({
    required DateTime startUtc,
    required DateTime endUtc,
    int limit = 2000,
  }) async => List<UserEvent>.of(events);

  @override
  Future<void> deleteByClientId(
    String clientEventId, {
    String semantic = 'native_calendar_prune',
    bool suppressesClient = false,
    String sourceFeature = 'CalendarSyncService',
    String deleteScope = 'native_missing_from_device',
  }) async {
    deletedClientIds.add(clientEventId);
    deleteSuppressesClient.add(suppressesClient);
    events = events
        .where((event) => event.clientEventId != clientEventId)
        .toList();
  }

  @override
  Future<void> deleteByClientIdPrefix(
    String prefix, {
    String semantic = 'native_calendar_unlink',
    bool suppressesClient = false,
    String sourceFeature = 'CalendarSyncService',
    String deleteScope = 'native_client_id_prefix',
  }) async {
    deletedPrefixes.add(prefix);
    events = events
        .where((event) => !(event.clientEventId ?? '').startsWith(prefix))
        .toList();
  }

  @override
  Future<void> deleteByCategory(
    String category, {
    String semantic = 'native_calendar_unlink',
    bool suppressesClient = false,
    String sourceFeature = 'CalendarSyncService',
    String deleteScope = 'native_sync_category',
  }) async {
    deletedCategories.add(category);
    events = events.where((event) => event.category != category).toList();
  }
}
