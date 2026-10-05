import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/data/account_view_cache.dart';
import 'package:mobile/data/shared_calendars_repo.dart';
import 'package:mobile/features/calendars/shared_calendars_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/maat_flow_visual_test_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var scenario = 0;
  setUpAll(loadMaatFlowVisualTestFonts);

  Future<_CalendarFixture> fixture({WidgetTester? tester}) async {
    final owner = 'calendar-delete-${scenario++}';
    final value = _CalendarFixture(owner);
    SharedPreferences.setMockInitialValues({
      value.cacheKey: jsonEncode(value.rows),
    });
    await value.client.auth.recoverSession(_session(owner));
    AccountViewCache.instance.enterAccount(owner);
    addTearDown(() async {
      if (tester == null) {
        await value.client.dispose();
      } else {
        await tester.runAsync(value.client.dispose);
      }
    });
    return value;
  }

  test(
    'removal waits for acknowledgement, persists, and survives failed refresh',
    () async {
      final f = await fixture();
      final acknowledgement = Completer<http.Response>();
      f.deletions['remove'] = acknowledgement;
      final removal = f.repo.leaveCalendar('remove');
      await f.deleteStarted.future;

      expect(f.repo.cachedAcceptedCalendarsSync()!.map((c) => c.id), [
        'remove',
        'keep',
      ]);
      expect(await f.persistedIds(), ['remove', 'keep']);
      acknowledgement.complete(_json(null));
      await removal;

      expect(f.repo.cachedAcceptedCalendarsSync()!.map((c) => c.id), ['keep']);
      expect(await f.persistedIds(), ['keep']);
      f.failReads = true;
      expect((await f.repo.getAcceptedCalendars()).map((c) => c.id), ['keep']);
      expect(
        (await SharedCalendarsRepo(
          f.client,
        ).restoreCachedSnapshot())!.calendars.map((c) => c.id),
        ['keep'],
      );
    },
  );

  test(
    'rejected removal keeps memory and persisted content for retry',
    () async {
      final f = await fixture();
      f.deletions['remove'] = Completer<http.Response>()..complete(_failure());
      await expectLater(
        f.repo.leaveCalendar('remove'),
        throwsA(isA<PostgrestException>()),
      );
      expect(f.repo.cachedAcceptedCalendarsSync()!.map((c) => c.id), [
        'remove',
        'keep',
      ]);
      expect(await f.persistedIds(), ['remove', 'keep']);
      f.deletions.clear();
      await f.repo.leaveCalendar('remove');
      expect(await f.persistedIds(), ['keep']);
    },
  );

  test(
    'read started before acknowledged removal cannot resurrect it across repositories',
    () async {
      final f = await fixture();
      await f.repo.restoreCachedAcceptedCalendars();
      f.heldRead = Completer<http.Response>();
      final refresh = f.repo.getAcceptedCalendars();
      await f.readStarted.future;
      await SharedCalendarsRepo(f.client).leaveCalendar('remove');
      f.heldRead!.complete(_json(f.rows));

      expect((await refresh).map((c) => c.id), ['keep']);
      expect(f.repo.cachedAcceptedCalendarsSync()!.map((c) => c.id), ['keep']);
      expect(await f.persistedIds(), ['keep']);
    },
  );

  test(
    'read started during removal is fenced when acknowledgement arrives',
    () async {
      final f = await fixture();
      final acknowledgement = Completer<http.Response>();
      f.deletions['remove'] = acknowledgement;
      final removal = f.repo.leaveCalendar('remove');
      await f.deleteStarted.future;
      f.heldRead = Completer<http.Response>();
      final refresh = f.repo.getAcceptedCalendars();
      await f.readStarted.future;
      acknowledgement.complete(_json(null));
      await removal;
      f.heldRead!.complete(_json(f.rows));
      expect((await refresh).map((c) => c.id), ['keep']);
      expect(await f.persistedIds(), ['keep']);
    },
  );

  test(
    'late read from departed account cannot replace or return private content',
    () async {
      final f = await fixture();
      f.heldRead = Completer<http.Response>();
      final refresh = f.repo.getAcceptedCalendars();
      await f.readStarted.future;
      final otherOwner = '${f.owner}-other';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'shared_calendars:accepted:v1:$otherOwner',
        jsonEncode([_row('other', otherOwner)]),
      );
      await f.client.auth.recoverSession(_session(otherOwner));
      AccountViewCache.instance.enterAccount(otherOwner);
      await f.repo.restoreCachedAcceptedCalendars();
      f.heldRead!.complete(_json(f.rows));

      expect(await refresh, isEmpty);
      expect(f.repo.cachedAcceptedCalendarsSync()!.map((c) => c.id), ['other']);
      expect(await f.persistedIds(owner: otherOwner), ['other']);
      expect(await f.persistedIds(), ['remove', 'keep']);
    },
  );

  test(
    'same-account token refresh keeps an accepted calendar read valid',
    () async {
      final f = await fixture();
      f.heldRead = Completer<http.Response>();
      final refresh = f.repo.getAcceptedCalendars();
      await f.readStarted.future;
      await f.client.auth.refreshSession();
      f.heldRead!.complete(_json([_row('fresh-after-refresh', f.owner)]));
      expect((await refresh).map((c) => c.id), ['fresh-after-refresh']);
      expect(await f.persistedIds(), ['fresh-after-refresh']);
    },
  );

  test(
    'returning to an account still rejects its prior session read',
    () async {
      final f = await fixture();
      await f.repo.restoreCachedAcceptedCalendars();
      f.heldRead = Completer<http.Response>();
      final refresh = f.repo.getAcceptedCalendars();
      await f.readStarted.future;
      await f.client.auth.recoverSession(_session('${f.owner}-other'));
      await f.client.auth.recoverSession(_session(f.owner));
      f.heldRead!.complete(_json([_row('stale-private-row', f.owner)]));
      expect((await refresh).map((c) => c.id), ['remove', 'keep']);
      expect(await f.persistedIds(), ['remove', 'keep']);
    },
  );

  test(
    'late deletion acknowledgement updates only its initiating account',
    () async {
      final f = await fixture();
      final acknowledgement = Completer<http.Response>();
      f.deletions['remove'] = acknowledgement;
      final removal = f.repo.leaveCalendar('remove');
      await f.deleteStarted.future;
      final otherOwner = '${f.owner}-other';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'shared_calendars:accepted:v1:$otherOwner',
        jsonEncode([_row('remove', otherOwner)]),
      );
      await f.client.auth.recoverSession(_session(otherOwner));
      AccountViewCache.instance.enterAccount(otherOwner);
      await f.repo.restoreCachedAcceptedCalendars();
      acknowledgement.complete(_json(null));
      await removal;

      expect(f.repo.cachedAcceptedCalendarsSync()!.map((c) => c.id), [
        'remove',
      ]);
      expect(await f.persistedIds(owner: otherOwner), ['remove']);
      expect(await f.persistedIds(), ['keep']);
      await f.client.auth.recoverSession(_session(f.owner));
      expect(
        (await f.repo.restoreCachedAcceptedCalendars())!.map((c) => c.id),
        ['keep'],
      );
    },
  );

  test(
    'departed acknowledgement cannot republish the previous active view',
    () async {
      final f = await fixture();
      await f.repo.getAcceptedCalendars();
      final publications = <String?>[];
      void onPublished() =>
          publications.add(AccountViewCache.instance.changes.value);
      AccountViewCache.instance.changes.addListener(onPublished);
      addTearDown(
        () => AccountViewCache.instance.changes.removeListener(onPublished),
      );
      final acknowledgement = Completer<http.Response>();
      f.deletions['remove'] = acknowledgement;
      final removal = f.repo.leaveCalendar('remove');
      await f.deleteStarted.future;
      // Auth can change before the next frame updates the shared view owner.
      await f.client.auth.recoverSession(_session('${f.owner}-other'));
      acknowledgement.complete(_json(null));
      await removal;
      expect(publications, isEmpty);
      expect(await f.persistedIds(), ['keep']);
    },
  );

  test('concurrent confirmed removals retain both changes on disk', () async {
    final f = await fixture();
    await Future.wait([
      f.repo.leaveCalendar('remove'),
      SharedCalendarsRepo(f.client).leaveCalendar('keep'),
    ]);
    expect(f.repo.cachedAcceptedCalendarsSync(), isEmpty);
    expect(await f.persistedIds(), isEmpty);
  });

  test('cold preview read is fenced by a concurrent deletion', () async {
    final f = await fixture();
    f.heldRead = Completer<http.Response>();
    final preview = f.repo.readAcceptedCalendarsOnly();
    await f.readStarted.future;
    await f.repo.leaveCalendar('remove');
    f.heldRead!.complete(_json(f.rows));
    expect((await preview).map((c) => c.id), ['keep']);
    expect(await f.persistedIds(), ['keep']);
  });

  testWidgets(
    'calendar sheet removes confirmed Delete despite a failed refresh',
    (tester) async {
      final f = (await tester.runAsync(() => fixture(tester: tester)))!;
      await _pumpCalendarSheet(tester, f);
      await tester.tap(find.text('remove'));
      await _settleCalendarSheet(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await _settleCalendarSheet(tester);
      expect(find.text('Delete calendar?'), findsOneWidget);
      final acknowledgement = Completer<http.Response>();
      f.deletions['remove'] = acknowledgement;
      f.failReads = true;
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Delete'),
        ),
      );
      await _settleCalendarSheet(tester);
      expect(find.text('remove'), findsOneWidget);
      acknowledgement.complete(_json(null));
      await _settleCalendarSheet(tester);
      for (
        var frame = 0;
        frame < 20 && find.text('remove').evaluate().isNotEmpty;
        frame++
      ) {
        await _settleCalendarSheet(tester);
      }
      expect(find.text('remove'), findsNothing);
      expect(find.text('keep'), findsOneWidget);
      expect(await f.persistedIds(), ['keep']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'calendar sheet Cancel and failed Delete retain the calendar and allow retry',
    (tester) async {
      final f = (await tester.runAsync(() => fixture(tester: tester)))!;
      await _pumpCalendarSheet(tester, f);
      await tester.tap(find.text('remove'));
      await _settleCalendarSheet(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await _settleCalendarSheet(tester);
      await tester.tap(find.text('Cancel'));
      await _settleCalendarSheet(tester);
      expect(f.deleteStarted.isCompleted, false);
      expect(find.text('remove'), findsOneWidget);
      f.deletions['remove'] = Completer<http.Response>()..complete(_failure());
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await _settleCalendarSheet(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Delete'),
        ),
      );
      await _settleCalendarSheet(tester);
      expect(find.text('remove'), findsOneWidget);
      expect(find.textContaining('fixture failure'), findsOneWidget);
      expect(await f.persistedIds(), ['remove', 'keep']);
      f.deletions.clear();
      f.failReads = true;
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await _settleCalendarSheet(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Delete'),
        ),
      );
      await _settleCalendarSheet(tester);
      await _settleCalendarSheet(tester);
      for (
        var frame = 0;
        frame < 20 && find.text('remove').evaluate().isNotEmpty;
        frame++
      ) {
        await _settleCalendarSheet(tester);
      }
      expect(find.text('remove'), findsNothing);
      expect(find.text('keep'), findsOneWidget);
      expect(await f.persistedIds(), ['keep']);
      expect(tester.takeException(), isNull);
    },
  );
}

class _CalendarFixture {
  _CalendarFixture(this.owner) {
    client = SupabaseClient(
      'https://example.supabase.test',
      'fixture-anon-key',
      httpClient: MockClient((request) async {
        final response = await _respond(request);
        return http.Response.bytes(
          response.bodyBytes,
          response.statusCode,
          headers: response.headers,
          request: request,
        );
      }),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    repo = SharedCalendarsRepo(client);
  }

  final String owner;
  late final SupabaseClient client;
  late final SharedCalendarsRepo repo;
  final deletions = <String, Completer<http.Response>>{};
  final deleteStarted = Completer<void>();
  final readStarted = Completer<void>();
  Completer<http.Response>? heldRead;
  bool failReads = false;
  List<Map<String, Object?>> get rows => [
    _row('remove', owner),
    _row('keep', owner),
  ];
  String get cacheKey => 'shared_calendars:accepted:v1:$owner';

  Future<http.Response> _respond(http.Request request) async {
    final path = request.url.path;
    if (path.endsWith('/auth/v1/token')) {
      return _json(jsonDecode(_session(owner)));
    }
    if (path.endsWith('/rpc/leave_shared_calendar')) {
      if (!deleteStarted.isCompleted) deleteStarted.complete();
      final id = (jsonDecode(request.body) as Map)['p_calendar_id'];
      return deletions[id]?.future ?? _json(null);
    }
    if (path.endsWith('/shared_calendar_filing_items_client') ||
        path.endsWith('/shared_calendar_summaries')) {
      if (!readStarted.isCompleted) readStarted.complete();
      if (failReads) return _failure();
      return heldRead?.future ?? _json(rows);
    }
    return _json(path.contains('/rpc/') ? null : []);
  }

  Future<List<Object?>> persistedIds({String? owner}) async {
    final prefs = await SharedPreferences.getInstance();
    final rows =
        jsonDecode(
              prefs.getString(
                'shared_calendars:accepted:v1:${owner ?? this.owner}',
              )!,
            )
            as List;
    return rows.map((row) => (row as Map)['id']).toList();
  }
}

http.Response _json(Object? body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
);
http.Response _failure() => http.Response(
  jsonEncode({'message': 'fixture failure', 'code': '23503'}),
  400,
  headers: {'content-type': 'application/json'},
);
Map<String, Object?> _row(String id, String owner) => {
  'id': id,
  'owner_id': owner,
  'name': id,
  'role': 'owner',
  'status': 'accepted',
  'color': 0xffd4ae43,
  'is_personal': false,
};
String _session(String userId) {
  final expiresAt = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return jsonEncode({
    'access_token':
        '${encode({'alg': 'HS256', 'typ': 'JWT'})}.${encode({'sub': userId, 'exp': expiresAt})}.signature',
    'refresh_token': 'fixture-refresh-token',
    'token_type': 'bearer',
    'expires_in': 3600,
    'expires_at': expiresAt,
    'user': {
      'id': userId,
      'aud': 'authenticated',
      'role': 'authenticated',
      'email': 'calendar@example.com',
      'app_metadata': {},
      'user_metadata': {},
      'created_at': '2026-01-01T00:00:00Z',
    },
  });
}

Future<void> _pumpCalendarSheet(
  WidgetTester tester,
  _CalendarFixture fixture,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SharedCalendarsSheet(
          repo: fixture.repo,
          routeMode: true,
          showCloseButton: false,
        ),
      ),
    ),
  );
  await _settleCalendarSheet(tester);
  expect(find.text('remove'), findsOneWidget);
  expect(find.text('keep'), findsOneWidget);
}

Future<void> _settleCalendarSheet(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  });
  await tester.pumpAndSettle();
}
