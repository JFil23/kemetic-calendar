import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/reminders/reminder_rule.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _userA = '11111111-1111-4111-8111-111111111111';
const _userB = '22222222-2222-4222-8222-222222222222';
const _reminderId = '33333333-3333-4333-8333-333333333333';
final _day = DateTime(2026, 10, 5, 9);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory hiveDirectory;
  late _FixtureClient fixture;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('reminder_owner.');
    Hive.init(hiveDirectory.path);
    const messages = MethodChannel('com.llfbandit.app_links/messages');
    const events = MethodChannel('com.llfbandit.app_links/events');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(messages, (_) async => null);
    messenger.setMockMethodCallHandler(events, (_) async {
      scheduleMicrotask(
        () => messenger.handlePlatformMessage(events.name, null, (_) {}),
      );
      return null;
    });
    fixture = _FixtureClient();
    SharedPreferences.setMockInitialValues({
      'app:has_seen_onboarding': true,
      'app:onboarding:completed': true,
    });
    await Supabase.initialize(
      url: 'http://127.0.0.1:9',
      anonKey: 'test-anon-key',
      httpClient: fixture,
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
    );
  });

  tearDownAll(() async {
    await Supabase.instance.dispose();
    await hiveDirectory.delete(recursive: true);
  });

  setUp(() async {
    fixture.reset();
    CalendarPage.debugReminderSyncTodayForTesting = _day;
    CalendarPage.debugReminderSyncWindowEndForTesting = _day;
    await Supabase.instance.client.auth.recoverSession(_session(_userA));
  });

  tearDown(() {
    CalendarPage.debugReminderSyncTodayForTesting = null;
    CalendarPage.debugReminderSyncWindowEndForTesting = null;
  });

  Future<CalendarPageState> mount(
    WidgetTester tester, {
    bool nutrition = false,
  }) async {
    final key = GlobalKey<CalendarPageState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CalendarPage(key: key)),
      ),
    );
    await tester.pump();
    final state = key.currentState!;
    state.debugSeedReminderRulesForTesting([
      ReminderRule(
        id: nutrition ? 'nutrition:$_reminderId' : _reminderId,
        title: 'Owner regression reminder',
        startLocal: _day,
        color: Colors.blue,
        alertOffsetMinutes: -1,
      ),
    ], windowEnd: _day);
    fixture.eventReads = 0;
    fixture.eventWrites.clear();
    return state;
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  }

  testWidgets('confirmed absent owner prevents occurrence reads and writes', (
    tester,
  ) async {
    fixture.ownerPresent = false;
    final state = await mount(tester);
    state.debugDestroyInMemoryPendingState(keepWarmNotes: false);
    await tester.runAsync(state.debugRunReminderSyncForTesting);
    expect(fixture.ownerReads, greaterThan(0));
    expect(fixture.eventReads, 0);
    expect(fixture.eventWrites, isEmpty);
    final date = KemeticMath.fromGregorian(_day);
    expect(
      state.notesForDayForTesting(date.kYear, date.kMonth, date.kDay),
      isEmpty,
    );
    await dispose(tester);
  });

  testWidgets('owner read failure retains local state without event work', (
    tester,
  ) async {
    fixture.ownerReadFails = true;
    final state = await mount(tester);
    final date = KemeticMath.fromGregorian(_day);
    final before = state.notesForDayForTesting(
      date.kYear,
      date.kMonth,
      date.kDay,
    );
    await tester.runAsync(state.debugRunReminderSyncForTesting);
    expect(fixture.eventReads, 0);
    expect(fixture.eventWrites, isEmpty);
    expect(state.debugReminderRulesForTesting, hasLength(1));
    expect(
      state
          .notesForDayForTesting(date.kYear, date.kMonth, date.kDay)
          .map((n) => n.clientEventId),
      before.map((n) => n.clientEventId),
    );
    await dispose(tester);
  });

  testWidgets('late owner read cannot sync after account departure', (
    tester,
  ) async {
    final state = await mount(tester);
    fixture.beforeOwnerReply = () async {
      await Supabase.instance.client.auth.recoverSession(_session(_userB));
    };
    await tester.runAsync(state.debugRunReminderSyncForTesting);
    expect(fixture.eventReads, 0);
    expect(fixture.eventWrites, isEmpty);
    await dispose(tester);
  });

  testWidgets('late tombstone read cannot write for the next account', (
    tester,
  ) async {
    final state = await mount(tester);
    fixture.beforeTombstoneReply = () async {
      await Supabase.instance.client.auth.recoverSession(_session(_userB));
    };
    await tester.runAsync(state.debugRunReminderSyncForTesting);
    expect(fixture.ownerReads, greaterThan(0));
    expect(fixture.eventReads, 2);
    expect(fixture.eventWrites, isEmpty);
    await dispose(tester);
  });

  testWidgets('account departure clears derived reminder registry', (
    tester,
  ) async {
    final state = await mount(tester);
    expect(state.debugReminderRulesForTesting, hasLength(1));
    await tester.runAsync(
      () => Supabase.instance.client.auth.signOut(scope: SignOutScope.local),
    );
    await tester.pump();
    expect(state.debugReminderRulesForTesting, isEmpty);
    expect(state.debugReminderFlowCountForTesting, 0);
    await dispose(tester);
  });

  testWidgets('confirmed owner preserves ordinary occurrence sync', (
    tester,
  ) async {
    final state = await mount(tester);
    await tester.runAsync(state.debugRunReminderSyncForTesting);
    expect(fixture.eventWrites, hasLength(1));
    expect(fixture.eventWrites.single['flow_local_id'], 8100);
    expect(fixture.eventWrites.single['user_id'], _userA);
    expect(
      fixture.eventWrites.single['client_event_id'],
      'reminder:$_reminderId:2026-10-05',
    );
    await dispose(tester);
  });

  testWidgets(
    'nutrition owner uses normalized UUID without user-event writes',
    (tester) async {
      final state = await mount(tester, nutrition: true);
      await tester.runAsync(state.debugRunReminderSyncForTesting);
      expect(fixture.ownerFilters, contains('eq.$_reminderId'));
      expect(fixture.eventWrites, isEmpty);
      expect(
        state.debugReminderRulesForTesting.single.id,
        'nutrition:$_reminderId',
      );
      await dispose(tester);
    },
  );
}

class _FixtureClient extends http.BaseClient {
  bool ownerPresent = true;
  bool ownerReadFails = false;
  int ownerReads = 0;
  int eventReads = 0;
  final ownerFilters = <String>[];
  final eventWrites = <Map<String, dynamic>>[];
  Future<void> Function()? beforeOwnerReply;
  Future<void> Function()? beforeTombstoneReply;

  void reset() {
    ownerPresent = true;
    ownerReadFails = false;
    ownerReads = 0;
    eventReads = 0;
    ownerFilters.clear();
    eventWrites.clear();
    beforeOwnerReply = null;
    beforeTombstoneReply = null;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    if (path == '/rest/v1/flows' &&
        request.url.queryParameters.containsKey('reminder_uuid')) {
      ownerReads++;
      ownerFilters.add(request.url.queryParameters['reminder_uuid']!);
      final callback = beforeOwnerReply;
      beforeOwnerReply = null;
      await callback?.call();
      if (ownerReadFails) {
        return _reply(request, {
          'code': '57014',
          'message': 'timeout',
        }, status: 500);
      }
      return _reply(
        request,
        ownerPresent
            ? [
                {'id': 8100},
              ]
            : [],
      );
    }
    if (path == '/rest/v1/user_events') {
      if (request.method == 'GET') {
        eventReads++;
        if (request.url.queryParameters['client_event_id']?.startsWith('eq.') ==
            true) {
          final callback = beforeTombstoneReply;
          beforeTombstoneReply = null;
          await callback?.call();
        }
        return _reply(request, []);
      }
      if (request.method == 'POST' && request is http.Request) {
        final body = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
        eventWrites.add(body);
        return _reply(request, {
          ...body,
          'id': '44444444-4444-4444-8444-444444444444',
          'created_at': '2026-10-05T16:00:00Z',
          'updated_at': '2026-10-05T16:00:00Z',
        });
      }
      throw StateError('Unexpected event mutation: ${request.method}');
    }
    if (path == '/rest/v1/rpc/get_calendar_flow_catalog_v1') {
      return _reply(request, {
        'code': '57014',
        'message': 'fixture has no startup catalog',
      }, status: 500);
    }
    return _reply(request, []);
  }

  http.StreamedResponse _reply(
    http.BaseRequest request,
    Object? data, {
    int status = 200,
  }) => http.StreamedResponse(
    Stream.value(utf8.encode(jsonEncode(data))),
    status,
    request: request,
    headers: {'content-type': 'application/json'},
  );
}

String _session(String id) => jsonEncode({
  'access_token': 'fixture-access-token',
  'refresh_token': 'fixture-refresh-token',
  'expires_in': 31536000,
  'expiresAt':
      DateTime.now().add(const Duration(days: 365)).millisecondsSinceEpoch ~/
      1000,
  'token_type': 'bearer',
  'user': {
    'id': id,
    'app_metadata': {'provider': 'email'},
    'user_metadata': {},
    'aud': 'authenticated',
    'created_at': '2026-01-01T00:00:00Z',
  },
});
