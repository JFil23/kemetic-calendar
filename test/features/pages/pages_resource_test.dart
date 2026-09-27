import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/data/account_view_cache.dart';
import 'package:mobile/data/pages_read_repository.dart';
import 'package:mobile/features/nodes/library_read_progress_store.dart';
import 'package:mobile/features/nodes/library_read_state.dart';
import 'package:mobile/features/pages/pages_controller.dart';
import 'package:mobile/features/pages/pages_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const uid = '27d63169-a28a-4550-a0a0-8fee0e8e7b95';
String session() {
  final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
  String enc(Object x) =>
      base64Url.encode(utf8.encode(jsonEncode(x))).replaceAll('=', '');
  return jsonEncode({
    'access_token':
        '${enc({'alg': 'HS256', 'typ': 'JWT'})}.${enc({'sub': uid, 'exp': exp})}.signature',
    'refresh_token': 'test',
    'token_type': 'bearer',
    'expires_at': exp,
    'expires_in': 3600,
    'user': {
      'id': uid,
      'aud': 'authenticated',
      'role': 'authenticated',
      'email': 'fixture@example.com',
      'app_metadata': {},
      'user_metadata': {},
      'created_at': '2026-01-01T00:00:00Z',
    },
  });
}

Future<void> drain() async {
  for (var i = 0; i < 30; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'cold entry bounded; revisit search sheet and hidden view do not write or refetch',
    () async {
      SharedPreferences.setMockInitialValues({});
      final requests = <http.Request>[];
      var bytes = 0;
      final transport = MockClient((request) async {
        requests.add(request);
        final name = request.url.pathSegments.last;
        Object payload = const [];
        if (name == 'get_together_inbox' ||
            name == 'get_commons_together_home_cards') {
          payload = <String, Object>{};
        }
        if (name == 'todos') {
          payload = [
            {
              'id': 'todo',
              'title': 'Test commitment',
              'status': 'pending',
              'due_date': PagesReadRepository.dayKey(DateTime.now()),
            },
          ];
        }
        final body = jsonEncode(payload);
        bytes += utf8.encode(body).length;
        return http.Response(
          body,
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      });
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: transport,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      await client.auth.recoverSession(session());
      final cache = AccountViewCache();
      final controller = PagesController(client, cache: cache);
      controller.setVisible(true);
      await drain();
      final cold = requests.length;
      expect(cold, 15);
      final todoQuery = requests
          .singleWhere((r) => r.url.path.endsWith('/todos'))
          .url
          .queryParameters;
      expect(
        todoQuery['or'],
        contains('due_date.gte.${PagesReadRepository.dayKey(DateTime.now())}'),
      );
      expect(
        todoQuery['or'],
        contains('status.not.in.(done,skipped,archived)'),
      );
      final nutritionQuery = requests
          .singleWhere((r) => r.url.path.endsWith('/nutrition_items'))
          .url
          .queryParameters;
      expect(nutritionQuery['or'], contains('enabled.eq.true'));
      expect(nutritionQuery['select'], isNot(contains('purpose')));
      expect(cache.failed('planner.overview'), isFalse);
      expect(
        controller.cards[PagesDestination.planner.index].value.state,
        PagesLoadState.ready,
      );
      final endpoints = <String, int>{};
      for (final request in requests) {
        final name = request.url.pathSegments.last;
        endpoints[name] = (endpoints[name] ?? 0) + 1;
        if (request.method == 'POST') {
          expect(
            name,
            isIn([
              'get_together_inbox',
              'get_commons_together_home_cards',
              'get_my_filed_flows_v1',
            ]),
          );
        } else {
          expect(request.method, 'GET');
          expect(request.url.queryParameters['limit'], isNotNull);
        }
      }
      expect(endpoints.values.every((n) => n == 1), isTrue);
      controller.setVisible(false);
      await drain();
      expect(requests.length, cold);
      controller.setVisible(true);
      await drain();
      expect(requests.length, cold);
      for (final query in ['m', 'ma', 'maat']) {
        controller
            .searchRecords()
            .where((r) => r.title.contains(query))
            .toList();
      }
      expect(requests.length, cold);
      final changed = <PagesDestination>[];
      for (final d in PagesDestination.values) {
        controller.cards[d.index].addListener(() => changed.add(d));
      }
      cache.publish(
        uid,
        'journal.overview',
        const JournalOverview(
          written: {},
          badgesByDay: {
            '2026-09-26': [PagesSignal('A real badge')],
          },
        ),
      );
      expect(changed, [PagesDestination.journal]);
      expect(requests.length, cold);
      controller.setVisible(false);
      controller.setVisible(true, resumed: true);
      await drain();
      expect(requests.length, cold);
      controller.setVisible(false);
      controller.resumeAfter(DateTime.now());
      controller.setVisible(true, resumed: true);
      await drain();
      expect(requests.length, cold + 6);
      controller.dispose();
      await drain();
      expect(requests.length, cold + 6);
      // Request methods above exclude inserts, updates, deletes, and mutating RPCs.
      // ignore: avoid_print
      print(
        'Pages fixture resource receipt: cold=$cold requests, payload=$bytes bytes; fresh revisit=0, local search=0, journal notification=0, fresh resume=0, expired social resume=6, leave=0; write requests=0.',
      );
      await client.dispose();
    },
  );
  test(
    'member preview reads three accepted members and only their glyph metadata',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          requests.add(request);
          final body = request.url.path.endsWith('list_shared_calendar_members')
              ? [
                  {'user_id': 'member', 'display_name': 'Actual member'},
                ]
              : [
                  {
                    'id': 'member',
                    'avatar_glyphs': ['sun'],
                  },
                ];
          return http.Response(
            jsonEncode(body),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      await client.auth.recoverSession(session());
      final people = await PagesReadRepository(
        client,
        mayFetch: () => true,
      ).calendarMembers('calendar');
      expect(people.single.name, 'Actual member');
      expect(people.single.glyphIds, ['sun']);
      expect(requests.length, 2);
      expect(requests.first.url.queryParameters['status'], 'eq.accepted');
      expect(
        requests.every((r) => r.url.queryParameters['limit'] == '3'),
        isTrue,
      );
      expect(requests.last.method, 'GET');
      expect(
        requests.last.url.queryParameters['select'],
        'id,display_name,handle,avatar_glyphs',
      );
      await client.dispose();
    },
  );
  test(
    'failed inbox metadata shows unavailable and does not retry while visible',
    () async {
      SharedPreferences.setMockInitialValues({});
      var inboxReads = 0;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          final name = request.url.pathSegments.last;
          if (name == 'share_filing_items_client') {
            inboxReads++;
            return http.Response(
              '{"message":"unavailable"}',
              503,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }
          return http.Response(
            name == 'get_together_inbox' ||
                    name == 'get_commons_together_home_cards'
                ? '{}'
                : '[]',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      await client.auth.recoverSession(session());
      final controller = PagesController(client, cache: AccountViewCache());
      controller.setVisible(true);
      await drain();
      expect(
        controller.cards[PagesDestination.inbox.index].value.state,
        PagesLoadState.failed,
      );
      controller.setVisible(true);
      await drain();
      expect(inboxReads, 1);
      controller.dispose();
      await client.dispose();
    },
  );
  test(
    'Library preview never synchronizes local progress or calls remote',
    () async {
      SharedPreferences.setMockInitialValues({
        'library_node_read_progress_v2:preview-user': jsonEncode({
          'ptah': const LibraryNodeProgress(
            nodeId: 'ptah',
            progressPercent: 8,
          ).toJson(),
        }),
      });
      final remote = _NoLibraryRemote();
      final store = LibraryReadProgressStore(
        currentUserIdProvider: () => 'preview-user',
        remote: remote,
      );
      final snapshot = await store.readCachedSnapshotOnly();
      expect(snapshot!.progressFor('ptah')!.progressPercent, 8);
      expect(remote.calls, 0);
      final unknown = await LibraryReadProgressStore(
        currentUserIdProvider: () => 'another-user',
        remote: remote,
      ).readCachedSnapshotOnly();
      expect(unknown, isNull);
      expect(remote.calls, 0);
    },
  );
  test(
    'hide during a compound planner read prevents subsequent reads',
    () async {
      final requestStarted = Completer<void>(),
          response = Completer<http.Response>();
      var count = 0, visible = true;
      http.Request? observed;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: MockClient((request) {
          count++;
          observed = request;
          requestStarted.complete();
          return response.future;
        }),
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      await client.auth.recoverSession(session());
      final read = PagesReadRepository(
        client,
        mayFetch: () => visible,
      ).planner(DateTime.now());
      await requestStarted.future;
      visible = false;
      response.complete(
        http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json'},
          request: observed,
        ),
      );
      await expectLater(read, throwsA(isA<ViewReadCancelled>()));
      expect(count, 1);
      await client.dispose();
    },
  );
}

class _NoLibraryRemote implements LibraryReadProgressRemote {
  int calls = 0;
  @override
  Future<List<LibraryNodeProgress>> fetchAll({required String userId}) async {
    calls++;
    throw StateError('Preview must not fetch');
  }

  @override
  Future<LibraryNodeProgress?> upsert({
    required String userId,
    required LibraryNodeProgress progress,
  }) async {
    calls++;
    throw StateError('Preview must not synchronize');
  }
}
