import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mobile/services/calendar_sync_service.dart';
import 'package:mobile/data/user_events_repo.dart';
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
    } catch (_) {
      // Hive may already be initialized by another test file in the same run.
    }
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

  group('one-way calendar import', () {
    test(
      'imports external events into HAw without external write calls',
      () async {
        final native = NativeCalendarEvent(
          nativeId: 'device-event-1',
          title: 'External appointment',
          description: 'private notes stay out of logs',
          location: 'Private location',
          allDay: false,
          start: DateTime.utc(2026, 7, 1, 16),
          end: DateTime.utc(2026, 7, 1, 17),
          calendarId: 'external-calendar',
          timeZone: 'America/Los_Angeles',
          lastModified: DateTime.utc(2026, 7, 1, 15),
          clientEventId: null,
          source: 'android',
        );
        final platform = _FakeCalendarPlatformBridge(events: [native]);
        final store = _FakeCalendarSyncEventStore();
        final service = CalendarSyncService(
          Supabase.instance.client,
          platform: platform,
          eventsStore: store,
          runLegacyUnlinkReset: false,
          now: () => DateTime.utc(2026, 7, 1, 12),
        );
        addTearDown(service.dispose);

        final result = await service.sync(
          windowStart: DateTime.utc(2026, 7),
          windowEnd: DateTime.utc(2026, 7, 2),
          interactive: true,
        );

        expect(result.state, CalendarSyncRunState.synced);
        expect(platform.requestPermissionsCount, 1);
        expect(platform.fetchEventsCount, 1);
        expect(store.upserts, hasLength(1));
        expect(
          store.upserts.single.clientEventId,
          'native:android:device-event-1',
        );
        expect(store.upserts.single.title, 'External appointment');
        expect(store.upserts.single.detail, 'private notes stay out of logs');
        expect(store.upserts.single.category, 'native_sync');
        expect(store.updatedIds, isEmpty);
        expect(store.deletedClientIds, isEmpty);
        expect(store.deletedPrefixes, isEmpty);
        expect(store.deletedCategories, isEmpty);
      },
    );

    test(
      'calendar import bridge and permissions stay read-only scoped',
      () async {
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

        for (final source in [dartBridge, androidBridge, iosBridge]) {
          expect(source, isNot(contains('upsertEvent')));
          expect(source, isNot(contains('deleteEvent')));
          expect(source, isNot(contains('purgeKemeticEvents')));
        }

        expect(androidManifest, contains('android.permission.READ_CALENDAR'));
        expect(
          androidManifest,
          isNot(contains('android.permission.WRITE_CALENDAR')),
        );
        expect(androidBridge, isNot(contains('CalendarContract.Events')));
        expect(androidBridge, isNot(contains('contentResolver.delete')));
        expect(androidBridge, isNot(contains('contentResolver.insert')));
        expect(androidBridge, isNot(contains('contentResolver.update')));

        expect(iosBridge, isNot(contains('eventStore.save')));
        expect(iosBridge, isNot(contains('eventStore.remove')));
        expect(iosPlist, contains('one-way import'));
        expect(iosPlist, isNot(contains('read and write your calendar')));
        expect(iosPlist, isNot(contains('stay in sync with Apple Calendar')));
      },
    );

    test(
      'continues importing after a recently deleted external event',
      () async {
        final deletedNative = NativeCalendarEvent(
          nativeId: 'deleted-device-event',
          title: 'Deleted external event',
          description: null,
          location: null,
          allDay: false,
          start: DateTime.utc(2026, 7, 1, 16),
          end: DateTime.utc(2026, 7, 1, 17),
          calendarId: 'external-calendar',
          timeZone: 'America/Los_Angeles',
          lastModified: DateTime.utc(2026, 7, 1, 15),
          clientEventId: null,
          source: 'android',
        );
        final keptNative = NativeCalendarEvent(
          nativeId: 'kept-device-event',
          title: 'Kept external event',
          description: 'safe import',
          location: null,
          allDay: false,
          start: DateTime.utc(2026, 7, 1, 18),
          end: DateTime.utc(2026, 7, 1, 19),
          calendarId: 'external-calendar',
          timeZone: 'America/Los_Angeles',
          lastModified: DateTime.utc(2026, 7, 1, 17),
          clientEventId: null,
          source: 'android',
        );
        final platform = _FakeCalendarPlatformBridge(
          events: [deletedNative, keptNative],
        );
        final store = _FakeCalendarSyncEventStore(
          recentlyDeletedCids: const {'native:android:deleted-device-event'},
        );
        final service = CalendarSyncService(
          Supabase.instance.client,
          platform: platform,
          eventsStore: store,
          runLegacyUnlinkReset: false,
          now: () => DateTime.utc(2026, 7, 1, 12),
        );
        addTearDown(service.dispose);

        final result = await service.sync(
          windowStart: DateTime.utc(2026, 7),
          windowEnd: DateTime.utc(2026, 7, 2),
          interactive: true,
        );

        expect(result.state, CalendarSyncRunState.synced);
        expect(store.upserts, hasLength(1));
        expect(
          store.upserts.single.clientEventId,
          'native:android:kept-device-event',
        );
        expect(store.events.single.title, 'Kept external event');
      },
    );
  });
}

Future<void> _ensureSupabaseInitialized() async {
  try {
    Supabase.instance.client;
    return;
  } catch (_) {}

  await Supabase.initialize(
    url: 'https://example.supabase.co',
    anonKey: 'anon-key-0123456789012345678901234567890123456789',
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

  final List<NativeCalendarEvent> events;
  int requestPermissionsCount = 0;
  int fetchEventsCount = 0;

  @override
  Future<bool> requestPermissions() async {
    requestPermissionsCount += 1;
    return true;
  }

  @override
  Future<List<NativeCalendarEvent>> fetchEvents(
    DateTime start,
    DateTime end,
  ) async {
    fetchEventsCount += 1;
    return events;
  }
}

class _FakeCalendarSyncEventStore implements CalendarSyncEventStore {
  _FakeCalendarSyncEventStore({this.recentlyDeletedCids = const <String>{}});

  final Set<String> recentlyDeletedCids;
  final upserts = <_UpsertRecord>[];
  final updatedIds = <String>[];
  final deletedClientIds = <String>[];
  final deletedPrefixes = <String>[];
  final deletedCategories = <String>[];
  var events = <UserEvent>[];

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
    if (recentlyDeletedCids.contains(clientEventId)) {
      throw const PostgrestException(
        message: 'EVENT_RECENTLY_DELETED',
        code: 'P0001',
      );
    }
    upserts.add(
      _UpsertRecord(
        clientEventId: clientEventId,
        title: title,
        detail: detail,
        location: location,
        allDay: allDay,
        startsAtUtc: startsAtUtc,
        endsAtUtc: endsAtUtc,
        category: category,
        caller: caller,
      ),
    );
    final event = _event(
      id: 'haw-${upserts.length}',
      clientEventId: clientEventId,
      title: title,
      detail: detail,
      location: location,
      allDay: allDay,
      startsAt: startsAtUtc,
      endsAt: endsAtUtc,
      category: category,
    );
    events = [...events, event];
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
    final updated = _event(
      id: existing.id,
      clientEventId: existing.clientEventId,
      title: title ?? existing.title,
      detail: detail ?? existing.detail,
      location: location ?? existing.location,
      allDay: allDay ?? existing.allDay,
      startsAt: startsAt ?? existing.startsAt,
      endsAt: endsAt ?? existing.endsAt,
      category: existing.category,
    );
    events = [for (final event in events) event.id == id ? updated : event];
    return updated;
  }

  @override
  Future<List<UserEvent>> getEventsForWindow({
    required DateTime startUtc,
    required DateTime endUtc,
    int limit = 2000,
  }) async {
    return events;
  }

  @override
  Future<void> deleteByClientId(
    String clientEventId, {
    String semantic = 'user_delete',
    bool suppressesClient = true,
    String sourceFeature = 'UserEventsRepo.deleteByClientId',
    String deleteScope = 'exact_occurrence',
  }) async {
    deletedClientIds.add(clientEventId);
  }

  @override
  Future<void> deleteByClientIdPrefix(
    String prefix, {
    String semantic = 'bulk_delete',
    bool suppressesClient = true,
    String sourceFeature = 'UserEventsRepo.deleteByClientIdPrefix',
    String deleteScope = 'client_id_prefix',
  }) async {
    deletedPrefixes.add(prefix);
  }

  @override
  Future<void> deleteByCategory(
    String category, {
    String semantic = 'bulk_delete',
    bool suppressesClient = true,
    String sourceFeature = 'UserEventsRepo.deleteByCategory',
    String deleteScope = 'category',
  }) async {
    deletedCategories.add(category);
  }

  UserEvent _event({
    required String id,
    required String? clientEventId,
    required String title,
    required String? detail,
    required String? location,
    required bool allDay,
    required DateTime startsAt,
    required DateTime? endsAt,
    required String? category,
  }) {
    return UserEvent(
      id: id,
      clientEventId: clientEventId,
      title: title,
      detail: detail,
      location: location,
      allDay: allDay,
      startsAt: startsAt,
      endsAt: endsAt,
      category: category,
      updatedAt: startsAt,
    );
  }
}

class _UpsertRecord {
  const _UpsertRecord({
    required this.clientEventId,
    required this.title,
    required this.detail,
    required this.location,
    required this.allDay,
    required this.startsAtUtc,
    required this.endsAtUtc,
    required this.category,
    required this.caller,
  });

  final String clientEventId;
  final String title;
  final String? detail;
  final String? location;
  final bool allDay;
  final DateTime startsAtUtc;
  final DateTime? endsAtUtc;
  final String? category;
  final String? caller;
}
