import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/data/external_calendar_repository.dart';
import 'package:mobile/data/user_events_repo.dart';
import 'package:mobile/data/warm_state/warm_snapshot_store.dart';
import 'package:mobile/features/calendar/calendar_invalidation.dart';
import 'package:mobile/core/imported_calendar_identity.dart'
    show isImportedDeviceCalendarEvent;
import '../features/pages/pages_resource_test.dart' show session, uid;

Map<String, dynamic> event({String title = 'Work'}) => {
  'id': 'event',
  'client_event_id': 'external:source:event',
  'source_id': 'source',
  'title': title,
  'all_day': false,
  'starts_at': '2026-10-02T13:00:00Z',
  'ends_at': '2026-10-02T14:00:00Z',
  'calendar_name': 'Work',
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final from = DateTime.utc(2026, 10), until = DateTime.utc(2026, 11);
  test(
    'read failures survive successful sibling ranges and retry the existing reader',
    () async {
      SharedPreferences.setMockInitialValues({});
      await WarmSnapshotStore.instance.forgetAccount(uid);
      var failOctober = true;
      final requests = <String>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          final start = jsonDecode(request.body)['p_from'] as String;
          requests.add(start);
          return http.Response(
            failOctober && start.startsWith('2026-10')
                ? '{"message":"offline"}'
                : '[]',
            failOctober && start.startsWith('2026-10') ? 503 : 200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      await client.auth.recoverSession(session());
      final repository = ExternalCalendarRepository(client, lane: 'staging');
      var notifications = 0;
      repository.addReadStateListener(() => notifications++);
      await repository.visibleEvents(from, until);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(repository.readFailure, isNotNull);
      await repository.visibleEvents(until, DateTime.utc(2026, 12));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(repository.readFailure, isNotNull);
      failOctober = false;
      await repository.retryReads();
      expect(repository.readFailure, isNull);
      expect(requests.where((s) => s.startsWith('2026-10')), hasLength(2));
      expect(requests.where((s) => s.startsWith('2026-11')), hasLength(1));
      expect(notifications, greaterThanOrEqualTo(2));
      repository.forgetPresentation();
      expect(repository.readFailure, isNull);
      await client.dispose();
      await WarmSnapshotStore.instance.forgetAccount(uid);
    },
  );

  test(
    'civil dates preserve the local date and exclusive end; invalid dates fail',
    () {
      final row = {
        ...event(),
        'all_day': true,
        'start_date': '2026-11-01',
        'end_date': '2026-11-03',
      };
      final parsed = ExternalCalendarEvent.fromJson(row);
      expect(parsed.startsAtUtc.toLocal(), DateTime(2026, 11, 1));
      expect(parsed.endsAtUtc.toLocal(), DateTime(2026, 11, 3));
      expect(
        () => ExternalCalendarEvent.fromJson({
          ...row,
          'start_date': '2026-02-31',
        }),
        throwsFormatException,
      );
    },
  );
  test(
    'external rows retain identity and are read-only, never reminders or authored rows',
    () {
      final row = standaloneRowFromExternalCalendarEvent(
        ExternalCalendarEvent.fromJson(event()),
      );
      expect(row.calendarId, 'external:source');
      expect(row.calendarIsPersonal, false);
      expect(row.flowLocalId, null);
      expect(row.isReminder, false);
      expect(
        isImportedDeviceCalendarEvent(
          clientEventId: row.clientEventId,
          category: row.category,
        ),
        true,
      );
      expect(
        () => ExternalCalendarEvent.fromJson({
          ...event(),
          'client_event_id': 'manual:x',
        }),
        throwsFormatException,
      );
    },
  );
  test(
    'cold projection read returns immediately, warm restart retains rows, failed refresh cannot publish empty',
    () async {
      SharedPreferences.setMockInitialValues({});
      await WarmSnapshotStore.instance.forgetAccount(uid);
      var failure = false;
      final requests = <http.Request>[];
      var next = Completer<http.Response>();
      final client = SupabaseClient(
        'https://example.supabase.co',
        'key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) {
          requests.add(request);
          return next.future;
        }),
      );
      await client.auth.recoverSession(session());
      final repository = ExternalCalendarRepository(client, lane: 'staging');
      final changed = CalendarInvalidationBus.instance.stream.first;
      expect(await repository.visibleEvents(from, until), isEmpty);
      await Future<void>.delayed(Duration.zero);
      expect(requests, hasLength(1));
      expect(jsonDecode(requests.first.body)['p_lane'], 'staging');
      next.complete(
        http.Response(
          jsonEncode([event()]),
          200,
          headers: {'content-type': 'application/json'},
          request: requests.last,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(repository.readFailure, isNull);
      await changed.timeout(const Duration(seconds: 2));
      expect(
        (await repository.visibleEvents(from, until)).single.title,
        'Work',
      );
      await WarmSnapshotStore.instance.flushed;
      final restored = await WarmSnapshotStore().cached(
        uid,
        repository.rangeKey(from, until),
      );
      expect((restored as List).single['title'], 'Work');
      next = Completer<http.Response>();
      repository.projectionChanged();
      expect(
        (await repository.visibleEvents(from, until)).single.title,
        'Work',
      );
      await Future<void>.delayed(Duration.zero);
      next.complete(
        http.Response(
          '{"message":"offline","code":"503"}',
          503,
          headers: {'content-type': 'application/json'},
          request: requests.last,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      failure = (await repository.visibleEvents(from, until)).isEmpty;
      expect(failure, false);
      await client.dispose();
      await WarmSnapshotStore.instance.forgetAccount(uid);
    },
  );
  test(
    'overlapping warm ranges retain events until a confirmed replacement',
    () async {
      SharedPreferences.setMockInitialValues({});
      await WarmSnapshotStore.instance.forgetAccount(uid);
      final requests = <http.Request>[];
      final pending = <Completer<http.Response>>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) {
          requests.add(request);
          final response = Completer<http.Response>();
          pending.add(response);
          return response.future;
        }),
      );
      await client.auth.recoverSession(session());
      final repository = ExternalCalendarRepository(client, lane: 'staging');
      await WarmSnapshotStore.instance.refresh(
        uid,
        repository.rangeKey(from, until),
        () async => [event()],
        isCurrent: () => true,
      );
      final dayFrom = DateTime.utc(2026, 10, 2);
      final dayUntil = DateTime.utc(2026, 10, 3);
      final visible = await repository.visibleEvents(dayFrom, dayUntil);
      expect(visible.map((row) => row.title), ['Work']);
      await Future<void>.delayed(Duration.zero);
      expect(pending, hasLength(1));
      pending.single.complete(
        http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json'},
          request: requests.single,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(await repository.visibleEvents(dayFrom, dayUntil), isEmpty);
      // The newer confirmed empty subrange must also remove the old event when
      // navigating back to the month whose older snapshot still contains it.
      expect(await repository.visibleEvents(from, until), isEmpty);
      await Future<void>.delayed(Duration.zero);
      final republished = CalendarInvalidationBus.instance.stream.first;
      pending.last.complete(
        http.Response(
          jsonEncode([event()]),
          200,
          headers: {'content-type': 'application/json'},
          request: requests.last,
        ),
      );
      await republished.timeout(const Duration(seconds: 2));
      expect(
        (await repository.visibleEvents(from, until)).single.title,
        'Work',
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await client.dispose();
      await WarmSnapshotStore.instance.forgetAccount(uid);
    },
  );

  test(
    'multi-day all-day import fills each visible civil day and excludes its end',
    () {
      final source = ExternalCalendarEvent.fromJson({
        ...event(),
        'all_day': true,
        'start_date': '2026-11-01',
        'end_date': '2026-11-04',
      });
      final rows = standaloneRowsFromExternalCalendarEvents(
        [source],
        DateTime(2026, 11, 2).toUtc(),
        DateTime(2026, 11, 5).toUtc(),
      ).toList();
      expect(rows.map((r) => r.startsAtUtc.toLocal()), [
        DateTime(2026, 11, 2),
        DateTime(2026, 11, 3),
      ]);
      expect(rows.map((r) => r.clientEventId).toSet(), {
        'external:source:event',
      });
      expect(rows.every((r) => r.allDay), true);
    },
  );
  test(
    'timed multi-day import covers every day and preserves its real end',
    () {
      final start = DateTime(2026, 10, 2, 10);
      final end = DateTime(2026, 10, 4, 12);
      final source = ExternalCalendarEvent.fromJson({
        ...event(),
        'starts_at': start.toUtc().toIso8601String(),
        'ends_at': end.toUtc().toIso8601String(),
      });
      final rows = standaloneRowsFromExternalCalendarEvents(
        [source],
        DateTime(2026, 10, 2).toUtc(),
        DateTime(2026, 10, 5).toUtc(),
      ).toList();
      expect(rows.map((r) => r.startsAtUtc.toLocal()), [
        start,
        DateTime(2026, 10, 3),
        DateTime(2026, 10, 4),
      ]);
      expect(
        rows.map(
          (r) => externalCalendarSegmentEndLocal(r.startsAtUtc, r.endsAtUtc!),
        ),
        [DateTime(2026, 10, 3), DateTime(2026, 10, 4), end],
      );
      expect(rows.every((r) => !r.allDay && r.endsAtUtc == end.toUtc()), true);
      expect(rows.map((r) => r.clientEventId).toSet(), {
        'external:source:event',
      });
    },
  );
  test(
    'timed midnight ends are exclusive across a daylight-saving boundary',
    () {
      final start = DateTime(2026, 11, 1);
      final end = DateTime(2026, 11, 3);
      final source = ExternalCalendarEvent.fromJson({
        ...event(),
        'starts_at': start.toUtc().toIso8601String(),
        'ends_at': end.toUtc().toIso8601String(),
      });
      final rows = standaloneRowsFromExternalCalendarEvents(
        [source],
        start.toUtc(),
        DateTime(2026, 11, 5).toUtc(),
      ).toList();
      expect(rows.map((r) => r.startsAtUtc.toLocal()), [
        start,
        DateTime(2026, 11, 2),
      ]);
      expect(
        externalCalendarSegmentEndLocal(rows.first.startsAtUtc, end),
        DateTime(2026, 11, 2),
      );
      expect(externalCalendarSegmentEndLocal(rows.last.startsAtUtc, end), end);
    },
  );
  test(
    'large confirmed projections display even when they exceed disk-cache limits',
    () async {
      SharedPreferences.setMockInitialValues({});
      await WarmSnapshotStore.instance.forgetAccount(uid);
      var denied = false;
      final payload = [
        for (var i = 0; i < 400; i++)
          {
            ...event(),
            'id': '$i',
            'client_event_id': 'external:source:$i',
            'detail': List.filled(3000, 'x').join(),
          },
      ];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient(
          (request) async => http.Response(
            denied
                ? '{"message":"denied","code":"42501"}'
                : jsonEncode(payload),
            denied ? 403 : 200,
            request: request,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      await client.auth.recoverSession(session());
      final repository = ExternalCalendarRepository(client, lane: 'staging');
      final first = CalendarInvalidationBus.instance.stream.first;
      expect(await repository.visibleEvents(from, until), isEmpty);
      await first.timeout(const Duration(seconds: 5));
      expect(
        WarmSnapshotStore.instance.peek(uid, repository.rangeKey(from, until)),
        null,
      );
      expect(await repository.visibleEvents(from, until), hasLength(400));
      denied = true;
      repository.projectionChanged();
      final revoked = CalendarInvalidationBus.instance.stream.first;
      expect(await repository.visibleEvents(from, until), hasLength(400));
      await revoked.timeout(const Duration(seconds: 5));
      expect(await repository.visibleEvents(from, until), isEmpty);
      repository.forgetPresentation();
      await client.dispose();
      await WarmSnapshotStore.instance.forgetAccount(uid);
    },
  );
  test('range fallback fences lane, account, denial and late reads', () async {
    SharedPreferences.setMockInitialValues({});
    await WarmSnapshotStore.instance.forgetAccount(uid);
    final pending = <Completer<http.Response>>[];
    final requests = <http.Request>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) {
        requests.add(request);
        final result = Completer<http.Response>();
        pending.add(result);
        return result.future;
      }),
    );
    addTearDown(client.dispose);
    await client.auth.recoverSession(session());
    final repository = ExternalCalendarRepository(client, lane: 'staging');
    Future<void> seed(String account, String lane, String title) async {
      await WarmSnapshotStore.instance.refresh(
        account,
        'externalCalendar.$lane.${from.toIso8601String()}.${until.toIso8601String()}',
        () async => [event(title: title)],
        isCurrent: () => true,
      );
    }

    await seed(uid, 'staging', 'This account');
    await seed(uid, 'production', 'Other lane');
    await seed('other-account', 'staging', 'Other account');
    final start = DateTime.utc(2026, 10, 2), end = DateTime.utc(2026, 10, 3);
    expect(
      (await repository.visibleEvents(start, end)).single.title,
      'This account',
    );
    await Future<void>.delayed(Duration.zero);
    pending.single.complete(
      http.Response(
        '{"message":"denied","code":"42501"}',
        403,
        headers: {'content-type': 'application/json'},
        request: requests.single,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(await repository.visibleEvents(start, end), isEmpty);
    expect(
      WarmSnapshotStore.instance.peekFamily(uid, 'externalCalendar.staging.'),
      isEmpty,
    );
    expect(
      WarmSnapshotStore.instance.peekFamily(
        uid,
        'externalCalendar.production.',
      ),
      isNotEmpty,
    );
    expect(
      WarmSnapshotStore.instance.peekFamily(
        'other-account',
        'externalCalendar.staging.',
      ),
      isNotEmpty,
    );

    await seed(uid, 'staging', 'Restored permission');
    final start2 = DateTime.utc(2026, 10, 1), end2 = DateTime.utc(2026, 10, 4);
    expect(
      (await repository.visibleEvents(start2, end2)).single.title,
      'Restored permission',
    );
    await Future<void>.delayed(Duration.zero);
    // Match the app-owned departure fence, including an A-B-A return before
    // the original HTTP response completes.
    repository.forgetPresentation();
    pending.last.complete(
      http.Response(
        jsonEncode([event(title: 'Stale result')]),
        200,
        headers: {'content-type': 'application/json'},
        request: requests.last,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(
      WarmSnapshotStore.instance.peek(uid, repository.rangeKey(start2, end2)),
      isNull,
    );
    await WarmSnapshotStore.instance.forgetAccount(uid);
    await WarmSnapshotStore.instance.forgetAccount('other-account');
  });

  test(
    'deployed v1 range restores into a new window while refresh is offline',
    () async {
      const restartOwner = 'restart-fixture-owner';
      final fromKey =
          'externalCalendar.staging.${from.toIso8601String()}.${until.toIso8601String()}';
      SharedPreferences.setMockInitialValues({
        'warm_snapshot:v1:${Uri.encodeComponent(restartOwner)}:${Uri.encodeComponent(fromKey)}':
            jsonEncode({
              'schema': 1,
              'userId': restartOwner,
              'updatedAt': '2026-10-01T00:00:00Z',
              'data': [event(title: 'Survived restart')],
            }),
      });
      final response = Completer<http.Response>();
      final client = SupabaseClient(
        'https://example.supabase.co',
        'key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((_) => response.future),
      );
      addTearDown(client.dispose);
      await client.auth.recoverSession(session().replaceAll(uid, restartOwner));
      final repository = ExternalCalendarRepository(client, lane: 'staging');
      final start = DateTime.utc(2026, 10, 2), end = DateTime.utc(2026, 10, 3);
      expect(
        (await repository.visibleEvents(start, end)).single.title,
        'Survived restart',
      );
      response.complete(
        http.Response(
          '{"message":"offline","code":"503"}',
          503,
          headers: {'content-type': 'application/json'},
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(
        (await repository.visibleEvents(start, end)).single.title,
        'Survived restart',
      );
      await client.auth.recoverSession(
        session().replaceAll(uid, 'other-account'),
      );
      expect(await repository.visibleEvents(start, end), isEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await WarmSnapshotStore.instance.forgetAccount(restartOwner);
      await WarmSnapshotStore.instance.forgetAccount('other-account');
    },
  );

  test('unknown build lane sends no external requests', () async {
    final client = SupabaseClient('https://example.supabase.co', 'key');
    var calls = 0;
    final repository = ExternalCalendarRepository(
      client,
      currentAccount: () => uid,
      request: (_) async {
        calls++;
        return {};
      },
    );
    await expectLater(
      repository.command('status'),
      throwsA(
        isA<ExternalCalendarFailure>().having(
          (e) => e.code,
          'code',
          'not_configured',
        ),
      ),
    );
    expect(calls, 0);
    await client.dispose();
  });
}
