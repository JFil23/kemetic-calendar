import 'package:flutter/material.dart' show TimeOfDay;
import 'package:mobile/data/nutrition_repo.dart';
import 'package:mobile/features/rhythm/planner/planner_overview.dart';
import 'package:mobile/widgets/kemetic_date_picker.dart' show KemeticMath;
import 'package:fake_async/fake_async.dart';
import 'package:mobile/data/commons_models.dart';
import 'package:mobile/features/pages/pages_feed_rotation.dart';
import 'package:mobile/features/pages/pages_arrangement.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/data/account_view_cache.dart';
import 'package:mobile/data/share_repo.dart';
import 'package:mobile/data/share_models.dart';
import 'package:mobile/data/shared_practice_models.dart';
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
    'Planner and Feed editions use cached data and make zero requests',
    () async {
      SharedPreferences.setMockInitialValues({});
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response('[]', 200);
        }),
      );
      await client.auth.recoverSession(session());
      final cache = AccountViewCache()..enterAccount(uid);
      final snapshot = CommonsHomeSnapshot(
        rhythm: CommonsRhythmSummary.empty(),
        publicSharedPractices: [
          CommonsPracticeRoom.fromJson({
            'id': 'room',
            'title': 'Actual public practice',
            'visibility': 'public',
            'status': 'active',
            'join_policy': 'owner_approval',
            'member_count': 3,
            'viewer_can_request_join': true,
          }),
        ],
      );
      cache.publish(uid, 'social.commons', snapshot);
      final day = DateTime(2026, 9, 28);
      final decan = (KemeticMath.fromGregorian(day).kDay - 1) % 10 + 1;
      cache.publish(
        uid,
        'planner.overview',
        PlannerOverview(
          todos: const [],
          alignment: const [],
          note: 'Say no to burnout',
          nutritionStates: const {},
          nutrition: [
            NutritionItem(
              id: 'food',
              nutrient: 'Magnesium',
              source: 'Pumpkin seeds',
              purpose: 'Support',
              schedule: IntakeSchedule(
                mode: IntakeMode.decan,
                decanDays: {decan},
                repeat: true,
                time: const TimeOfDay(hour: 7, minute: 0),
              ),
            ),
          ],
        ),
      );
      fakeAsync((time) {
        final start = DateTime(2026, 9, 28, 11, 29, 59);
        final rotation = PagesFeedRotation(now: () => start.add(time.elapsed));
        final controller = PagesController(
          client,
          cache: cache,
          feedRotation: rotation,
        );
        final feed = controller.cards[PagesDestination.feed.index];
        final planner = controller.cards[PagesDestination.planner.index];
        var plannerPaints = 0;
        planner.addListener(() => plannerPaints++);
        var feedPaints = 0;
        var otherPaints = 0;
        feed.addListener(() => feedPaints++);
        for (final card in controller.cards) {
          if (card != feed && card != planner) {
            card.addListener(() => otherPaints++);
          }
        }
        requests.clear();
        rotation.setActive(true);
        expect(feed.value.feedDisplay, PagesFeedDisplay.question);
        expect(planner.value.plannerDisplay, PagesPlannerDisplay.note);
        time.elapse(const Duration(seconds: 2));
        expect(feed.value.feedDisplay, PagesFeedDisplay.practice);
        expect(feed.value.practice?.id, 'room');
        expect(planner.value.plannerDisplay, PagesPlannerDisplay.nutrition);
        expect(planner.value.primary.title, 'Magnesium');
        expect(identical(feed.value.rhythm, snapshot.rhythm), isTrue);
        time.elapse(const Duration(hours: 6));
        expect(feed.value.feedDisplay, PagesFeedDisplay.publicRhythm);
        expect(feedPaints, 2);
        expect(plannerPaints, 2);
        expect(planner.value.plannerDisplay, PagesPlannerDisplay.scale);
        expect(otherPaints, 0);
        expect(requests, isEmpty);
        controller.setVisible(false);
        expect(time.nonPeriodicTimerCount, 0);
        time.elapse(const Duration(hours: 12));
        expect(feedPaints, 2);
        rotation.setActive(true);
        expect(feed.value.feedDisplay, PagesFeedDisplay.question);
        expect(requests, isEmpty);
        final freshSnapshot = CommonsHomeSnapshot(
          rhythm: snapshot.rhythm,
          publicSharedPractices: [
            CommonsPracticeRoom.fromJson({
              'id': 'fresh',
              'title': 'New eligible room',
              'status': 'active',
              'visibility': 'public',
              'join_policy': 'owner_approval',
              'viewer_can_request_join': true,
              'created_at': rotation.now
                  .subtract(const Duration(minutes: 10))
                  .toIso8601String(),
            }),
          ],
        );
        cache.publish(uid, 'social.commons', freshSnapshot);
        expect(feed.value.practice?.id, 'fresh');
        expect(feed.value.meta, startsWith('New public practice'));
        controller.didOpenFeed();
        expect(feed.value.feedDisplay, PagesFeedDisplay.question);
        cache.publish(uid, 'social.commons', freshSnapshot);
        expect(feed.value.feedDisplay, PagesFeedDisplay.question);
        expect(requests, isEmpty);
        controller.dispose();
        expect(time.nonPeriodicTimerCount, 0);
      });
      await client.dispose();
    },
  );
  test(
    'filed upcoming events select Sky before tomorrow Offering and retain its artwork key',
    () async {
      SharedPreferences.setMockInitialValues({});
      final now = DateTime(2026, 9, 26, 18);
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          requests.add(request);
          final payload = request.url.path.endsWith('get_my_filed_flows_v1')
              ? [
                  {
                    'id': 963,
                    'user_id': uid,
                    'name': 'The Offering Table',
                    'color': 0xffbb9933,
                    'notes': 'maat=the-offering-table',
                    'active': true,
                    'visible_in_active_list': true,
                    'total_event_count': 30,
                    'remaining_event_count': 27,
                  },
                  {
                    'id': 956,
                    'user_id': uid,
                    'name': 'Follow the sky',
                    'color': 0xffbb9933,
                    'notes': 'maat=track-the-sky',
                    'active': true,
                    'visible_in_active_list': true,
                    'total_event_count': 65,
                    'remaining_event_count': 64,
                  },
                ]
              : [
                  {
                    'title': 'Hidden event',
                    'filed_flow_id': 963,
                    'calendar_id': 'hidden',
                    'starts_at': now
                        .add(const Duration(hours: 1))
                        .toUtc()
                        .toIso8601String(),
                  },
                  {
                    'title': 'Full Moon',
                    'filed_flow_id': 956,
                    'calendar_id': 'visible',
                    'starts_at': now
                        .add(const Duration(hours: 2))
                        .toUtc()
                        .toIso8601String(),
                  },
                  {
                    'title': 'Household Table',
                    'filed_flow_id': 963,
                    'calendar_id': 'visible',
                    'starts_at': now
                        .add(const Duration(hours: 13))
                        .toUtc()
                        .toIso8601String(),
                  },
                ];
          return http.Response(
            jsonEncode(payload),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      await client.auth.recoverSession(session());
      final repo = PagesReadRepository(client, mayFetch: () => true);
      final flows = await repo.flows();
      final events = await repo.events(now, hidden: {'hidden'});
      final selected = selectPagesStudio(flows, events.events, now);
      expect(selected.flow?.name, 'Follow the sky');
      expect(selected.flow?.maatKey, 'track-the-sky');
      expect(selected.event?.title, 'Full Moon');
      expect(
        requests.last.url.queryParameters['order'],
        startsWith('starts_at.asc'),
      );
      await client.dispose();
    },
  );

  test(
    'displayed Inbox actor glyphs use one read and survive revisit',
    () async {
      SharedPreferences.setMockInitialValues({});
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          requests.add(request);
          final name = request.url.pathSegments.last;
          final Object payload = name == 'profiles'
              ? [
                  {
                    'avatar_glyphs': ['sun'],
                  },
                ]
              : name == 'get_together_inbox' ||
                    name == 'get_commons_together_home_cards'
              ? <String, Object>{}
              : <Object>[];
          return http.Response(
            jsonEncode(payload),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      await client.auth.recoverSession(session());
      final cache = AccountViewCache()..enterAccount(uid);
      cache.publish(uid, 'social.activity', [
        InboxActivityItem(
          type: InboxActivityType.follow,
          createdAt: DateTime.now(),
          actorId: 'c5cebdcc-0fa4-490c-9db7-922157e9d300',
          actorName: 'Reader',
        ),
      ]);
      cache.publish(uid, 'social.inbox', <InboxShareItem>[]);
      cache.publish(uid, 'social.together', TogetherInboxSnapshot.fromJson({}));
      final controller = PagesController(client, cache: cache);
      final glyphReady = Completer<void>();
      controller.cards[PagesDestination.inbox.index].addListener(() {
        if (!glyphReady.isCompleted &&
            controller
                .cards[PagesDestination.inbox.index]
                .value
                .primary
                .glyphIds
                .isNotEmpty) {
          glyphReady.complete();
        }
      });
      controller.setVisible(true);
      await glyphReady.future.timeout(const Duration(seconds: 5));
      await drain();
      final inbox = controller.cards[PagesDestination.inbox.index].value;
      expect(inbox.primary.glyphIds, ['sun']);
      expect(inbox.upper.glyphIds, ['sun']);
      final glyphReads = requests
          .where((r) => r.url.path.endsWith('/profiles'))
          .toList();
      expect(glyphReads, hasLength(1));
      expect(glyphReads.single.method, 'GET');
      expect(glyphReads.single.url.queryParameters['select'], 'avatar_glyphs');
      expect(glyphReads.single.url.queryParameters['limit'], '1');
      controller.setVisible(false);
      controller.setVisible(true);
      await drain();
      expect(
        requests.where((r) => r.url.path.endsWith('/profiles')),
        hasLength(1),
      );
      controller.dispose();
      await client.dispose();
    },
  );

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
      expect(endpoints['user_event_filing_items_client'], 2);
      expect(
        endpoints.entries
            .where((e) => e.key != 'user_event_filing_items_client')
            .every((e) => e.value == 1),
        isTrue,
      );
      for (final request in requests.where(
        (r) => r.url.path.endsWith('/user_event_filing_items_client'),
      )) {
        expect(
          request.url.queryParameters['order'],
          startsWith('starts_at.asc'),
        );
        expect(request.url.queryParameters['live_on_calendar'], 'eq.true');
      }
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
