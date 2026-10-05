import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/data/profile_repo.dart';
import 'package:mobile/data/user_events_repo.dart';
import 'package:mobile/data/warm_state/warm_snapshot_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/pages/pages_resource_test.dart' show session, uid;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final allDay in [false, true]) {
    test(
      'publishes a newly created ${allDay ? 'all-day' : 'timed'} flow snapshot',
      () async {
        final fixture = _PublishFixture(allDay: allDay);
        await fixture.start();
        addTearDown(fixture.close);

        final post = await ProfileRepo(
          fixture.client,
        ).postFlow(fixture.flowId, sharedNote: '  A newly created practice.  ');

        expect(post, isNotNull);
        expect(post!.sourceFlowId, fixture.flowId);
        expect(post.userId, uid);
        expect(fixture.inserts, hasLength(1));
        final write = fixture.inserts.single;
        expect(write['user_id'], uid);
        expect(write['color'], 0x6f93a8);
        final metadata = write['ai_metadata'] as Map;
        expect(metadata['shared_note'], 'A newly created practice.');
        final payload = metadata['payload'] as Map;
        expect(payload['shared_note'], 'A newly created practice.');
        final events = payload['events'] as List;
        expect(events, hasLength(2));
        expect(events.first['title'], 'First practice');
        expect(events.last['title'], 'Second practice');
        expect(events.last['offset_days'], 1);
        expect(events.first['detail'], 'Keep the complete instructions.');
        expect(events.first['location'], 'https://example.com/practice');
        expect(events.first['all_day'], allDay);
        expect(events.first['start_time'], allDay ? isNull : isNotNull);
        expect(events.first['end_time'], allDay ? isNull : isNotNull);
      },
    );
  }

  test('simultaneous events retain deterministic source ID order', () async {
    final fixture = _PublishFixture(sameStartTime: true);
    await fixture.start();
    addTearDown(fixture.close);

    expect(
      await ProfileRepo(fixture.client).postFlow(fixture.flowId),
      isNotNull,
    );
    final payload =
        (fixture.inserts.single['ai_metadata'] as Map)['payload'] as Map;
    final events = payload['events'] as List;
    expect(events.map((event) => event['title']), [
      'First practice',
      'Second practice',
    ]);
  });

  test(
    'an owner mismatch never attempts to publish another account flow',
    () async {
      final fixture = _PublishFixture(flowOwner: 'another-owner');
      await fixture.start();
      addTearDown(fixture.close);
      expect(
        await ProfileRepo(fixture.client).postFlow(fixture.flowId),
        isNull,
      );
      expect(fixture.inserts, isEmpty);
    },
  );

  test('failed source lookup does not publish an invented snapshot', () async {
    final fixture = _PublishFixture(flowStatus: 503);
    await fixture.start();
    addTearDown(fixture.close);
    expect(await ProfileRepo(fixture.client).postFlow(fixture.flowId), isNull);
    expect(fixture.inserts, isEmpty);
  });

  for (final warm in [false, true]) {
    test(
      'failed ${warm ? 'warm' : 'cold'} event read never publishes an empty flow',
      () async {
        final fixture = _PublishFixture();
        await fixture.start();
        addTearDown(fixture.close);
        if (warm) {
          await UserEventsRepo(
            fixture.client,
          ).getFlowDetailEvents(fixture.flowId);
        }
        fixture.eventsStatus = 500;

        expect(
          await ProfileRepo(fixture.client).postFlow(fixture.flowId),
          isNull,
        );
        expect(fixture.inserts, isEmpty);
        if (warm) {
          expect(
            WarmSnapshotStore.instance
                .peek(uid, 'flow.events.${fixture.flowId}')!
                .data,
            hasLength(2),
          );
        }
      },
    );
  }

  test('publishes every event across complete event pages', () async {
    final fixture = _PublishFixture(eventCount: 1001);
    await fixture.start();
    addTearDown(fixture.close);

    expect(
      await ProfileRepo(fixture.client).postFlow(fixture.flowId),
      isNotNull,
    );
    expect(fixture.inserts, hasLength(1));
    final payload =
        (fixture.inserts.single['ai_metadata'] as Map)['payload'] as Map;
    final events = payload['events'] as List;
    expect(events, hasLength(1001));
    expect(events.map((event) => event['title']).toSet(), hasLength(1001));
    expect(
      events.map((event) => event['offset_days']),
      List<int>.generate(1001, (index) => index),
    );
    expect(fixture.eventReads, [(0, 500), (500, 500), (1000, 500)]);
  });

  test(
    'a failed later event page never publishes a partial snapshot',
    () async {
      final fixture = _PublishFixture(eventCount: 501, failAtOffset: 500);
      await fixture.start();
      addTearDown(fixture.close);

      expect(
        await ProfileRepo(fixture.client).postFlow(fixture.flowId),
        isNull,
      );
      expect(fixture.inserts, isEmpty);
      expect(
        WarmSnapshotStore.instance.peek(uid, 'flow.events.${fixture.flowId}'),
        isNull,
      );
    },
  );

  for (final returnToOriginal in [false, true]) {
    test(
      'account departure${returnToOriginal ? ' and return' : ''} during event read prevents publication',
      () async {
        final fixture = _PublishFixture()..holdEvents = Completer<void>();
        await fixture.start();
        addTearDown(fixture.close);
        final publishing = ProfileRepo(fixture.client).postFlow(fixture.flowId);
        await fixture.eventsStarted.future;
        await fixture.client.auth.recoverSession(
          _sessionFor('another-account'),
        );
        if (returnToOriginal) {
          await fixture.client.auth.recoverSession(session());
        }
        fixture.holdEvents!.complete();

        expect(await publishing, isNull);
        expect(fixture.inserts, isEmpty);
      },
    );
  }

  for (final status in [403, 500]) {
    test(
      'post HTTP $status is reported as failure without a second insert',
      () async {
        final fixture = _PublishFixture(postStatus: status);
        await fixture.start();
        addTearDown(fixture.close);
        expect(
          await ProfileRepo(fixture.client).postFlow(fixture.flowId),
          isNull,
        );
        expect(fixture.inserts, hasLength(1));
      },
    );
  }
}

class _PublishFixture {
  _PublishFixture({
    this.allDay = false,
    this.sameStartTime = false,
    this.flowOwner = uid,
    this.flowStatus = 200,
    this.postStatus = 201,
    this.eventCount = 2,
    this.failAtOffset,
  });

  final bool allDay;
  final bool sameStartTime;
  final String flowOwner;
  final int flowStatus;
  final int postStatus;
  final int eventCount;
  final int? failAtOffset;
  int eventsStatus = 200;
  final eventReads = <(int, int)>[];
  final eventsStarted = Completer<void>();
  Completer<void>? holdEvents;
  final int flowId = 98123;
  final inserts = <Map<String, dynamic>>[];
  late final SupabaseClient client;

  Future<void> start() async {
    SharedPreferences.setMockInitialValues({});
    WarmSnapshotStore.instance.invalidate(uid, prefix: 'flow.');
    client = SupabaseClient(
      'https://example.supabase.co',
      'fixture-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        http.Response reply(Object body, [int status = 200]) => http.Response(
          jsonEncode(body),
          status,
          request: request,
          headers: {'content-type': 'application/json'},
        );
        if (request.url.path.endsWith('/flows')) {
          if (flowStatus != 200) {
            return reply({
              'code': '57014',
              'message': 'fixture source unavailable',
            }, flowStatus);
          }
          return reply({
            'id': flowId,
            'user_id': flowOwner,
            'name': 'Newly created practice',
            'color': 0xff6f93a8,
            'active': true,
            'is_saved': false,
            'is_hidden': false,
            'start_date': '2026-10-05',
            'end_date': '2026-10-06',
            'notes': 'mode=gregorian',
            'rules': [],
          });
        }
        if (request.url.path.endsWith('/user_event_filing_items_client')) {
          expect(request.url.queryParameters['filed_flow_id'], 'eq.$flowId');
          final offset = int.parse(
            request.url.queryParameters['offset'] ?? '0',
          );
          // Match the Data API's default cap when the caller does not page.
          final limit = int.parse(
            request.url.queryParameters['limit'] ?? '1000',
          );
          eventReads.add((offset, limit));
          if (!eventsStarted.isCompleted) eventsStarted.complete();
          await holdEvents?.future;
          if (eventsStatus >= 400 || offset == failAtOffset) {
            return reply({
              'code': '57014',
              'message': 'fixture event read timed out',
            }, 500);
          }
          final rows = <Map<String, dynamic>>[
            for (var day = 0; day < eventCount; day++)
              {
                'id': 'event-$day',
                'filed_flow_id': flowId,
                'flow_local_id': flowId,
                'item_kind': 'flow',
                'title': day == 0
                    ? 'First practice'
                    : day == 1
                    ? 'Second practice'
                    : 'Practice $day',
                'detail': 'Keep the complete instructions.',
                'location': 'https://example.com/practice',
                'all_day': allDay,
                'starts_at': DateTime(
                  2026,
                  10,
                  5 + (sameStartTime ? 0 : day),
                  9,
                ).toUtc().toIso8601String(),
                'ends_at': DateTime(
                  2026,
                  10,
                  5 + (sameStartTime ? 0 : day),
                  10,
                ).toUtc().toIso8601String(),
              },
          ];
          final ordering = (request.url.queryParameters['order'] ?? '')
              .split(',')
              .where((value) => value.isNotEmpty)
              .map((value) => value.split('.'));
          rows.sort((left, right) {
            for (final order in ordering) {
              final difference = (left[order.first] as String).compareTo(
                right[order.first] as String,
              );
              if (difference != 0) {
                return order[1] == 'asc' ? difference : -difference;
              }
            }
            return 0;
          });
          return reply(rows.skip(offset).take(limit).toList());
        }
        if (request.url.path.endsWith('/flow_posts') &&
            request.method == 'POST') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          inserts.add(body);
          if (postStatus >= 400) {
            return reply({
              'code': postStatus == 403 ? '42501' : 'XX000',
              'message': 'fixture publish failure',
            }, postStatus);
          }
          return reply({
            ...body,
            'id': 'new-post-fixture',
            'created_at': '2026-10-05T16:00:00Z',
          }, postStatus);
        }
        return reply([]);
      }),
    );
    await client.auth.recoverSession(session());
  }

  Future<void> close() async {
    await WarmSnapshotStore.instance.flushed;
    await client.dispose();
  }
}

String _sessionFor(String accountId) {
  final data = jsonDecode(session()) as Map<String, dynamic>;
  (data['user'] as Map)['id'] = accountId;
  final parts = (data['access_token'] as String).split('.');
  final claims =
      jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))))
          as Map<String, dynamic>;
  claims['sub'] = accountId;
  parts[1] = base64Url
      .encode(utf8.encode(jsonEncode(claims)))
      .replaceAll('=', '');
  data['access_token'] = parts.join('.');
  return jsonEncode(data);
}
