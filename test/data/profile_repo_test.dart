import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/flow_post_model.dart';
import 'package:mobile/data/profile_repo.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const ownerUserId = '4d2583da-8de4-49d3-9cd1-37a9a74f55bd';

  test(
    'restoreCachedProfile reads the last profile summary without network',
    () async {
      const userId = 'user-profile-cache-1';
      SharedPreferences.setMockInitialValues({
        'profile:summary:v1:$userId': jsonEncode({
          'id': userId,
          'handle': 'bigjfil',
          'display_name': 'BigJFil',
          'avatar_url': null,
          'avatar_glyphs': <String>[],
          'bio': 'Creator/Founder of h3w',
          'location': null,
          'is_discoverable': true,
          'allow_incoming_shares': true,
          'active_flows_count': 2,
          'total_flow_events_count': 29,
          'followers_count': 5,
          'following_count': 5,
          'created_at': '2026-05-04T20:42:08Z',
        }),
      });

      final repo = ProfileRepo(
        SupabaseClient('https://example.supabase.co', 'anon-key'),
      );

      final profile = await repo.restoreCachedProfile(userId);

      expect(profile?.displayName, 'BigJFil');
      expect(profile?.activeFlowsCount, 2);
      expect(profile?.totalFlowEventsCount, 29);
    },
  );

  test(
    'restoreCachedFlowPosts reads posted flow cache without network',
    () async {
      const userId = 'user-profile-cache-2';
      SharedPreferences.setMockInitialValues({
        'profile:flow_posts:v1:$userId': jsonEncode([
          {
            'id': 'post-1',
            'user_id': userId,
            'flow_id': 42,
            'name': 'Follow the sky',
            'color': 4278255360,
            'notes': 'cached flow',
            'rules': <Map<String, Object?>>[],
            'start_date': '2026-05-01T00:00:00Z',
            'end_date': '2027-03-20T00:00:00Z',
            'is_hidden': false,
            'ai_metadata': null,
            'payload': {'summary': 'cached'},
            'created_at': '2026-05-04T20:42:08Z',
            'author_handle': 'bigjfil',
            'author_display_name': 'BigJFil',
            'author_avatar_url': null,
            'author_avatar_glyphs': <String>[],
            'likes_count': 7,
            'comments_count': 2,
            'liked_by_me': true,
            'score': 3.5,
            'is_following_author': false,
          },
        ]),
      });

      final repo = ProfileRepo(
        SupabaseClient('https://example.supabase.co', 'anon-key'),
      );

      final posts = await repo.restoreCachedFlowPosts(userId);

      expect(posts, hasLength(1));
      expect(posts?.single.name, 'Follow the sky');
      expect(posts?.single.likesCount, 7);
      expect(posts?.single.payloadJson?['summary'], 'cached');
    },
  );

  test('preloadLocalCaches hydrates profile and post memory caches', () async {
    const userId = 'user-profile-cache-3';
    SharedPreferences.setMockInitialValues({
      'app:has_seen_onboarding': true,
      'profile:summary:v1:$userId': jsonEncode({
        'id': userId,
        'handle': 'october',
        'display_name': 'October',
        'avatar_url': null,
        'avatar_glyphs': <String>[],
        'bio': null,
        'location': null,
        'is_discoverable': true,
        'allow_incoming_shares': true,
        'active_flows_count': 1,
        'total_flow_events_count': 4,
        'followers_count': 0,
        'following_count': 0,
        'created_at': '2026-05-04T20:42:08Z',
      }),
      'profile:flow_posts:v1:$userId': jsonEncode([
        {
          'id': 'post-2',
          'user_id': userId,
          'flow_id': 7,
          'name': 'October birthday',
          'color': 4294901760,
          'rules': <Map<String, Object?>>[],
          'created_at': '2026-05-04T20:42:08Z',
        },
      ]),
      'profile:insight_posts:v1:$userId': jsonEncode([
        {
          'id': 'insight-1',
          'user_id': userId,
          'insight_entry_id': 'entry-1',
          'node_slug': 'abundance',
          'node_title': 'Abundance',
          'node_glyph': null,
          'body_text': 'cached insight',
          'entry_date': '2026-05-04T00:00:00Z',
          'is_hidden': false,
          'created_at': '2026-05-04T20:42:08Z',
          'updated_at': '2026-05-04T20:42:08Z',
        },
      ]),
    });

    final repo = ProfileRepo(
      SupabaseClient('https://example.supabase.co', 'anon-key'),
    );

    await repo.preloadLocalCaches();

    expect(repo.getCachedProfileSync(userId)?.displayName, 'October');
    expect(
      repo.getCachedFlowPostsSync(userId)?.single.name,
      'October birthday',
    );
    expect(
      repo.getCachedInsightPostsSync(userId)?.single.bodyText,
      'cached insight',
    );
  });

  test(
    'getProfile falls back to current user profiles row when stats fail',
    () async {
      SharedPreferences.setMockInitialValues({});

      final result = await _withProfileServer(
        (request) async {
          if (request.uri.path == '/rest/v1/profile_stats') {
            await _sendJson(
              request,
              statusCode: HttpStatus.internalServerError,
              body: {
                'code': '57014',
                'message': 'canceling statement due to statement timeout',
              },
            );
            return;
          }

          if (request.uri.path == '/rest/v1/profiles') {
            await _sendJson(request, body: [_profileRow(ownerUserId)]);
            return;
          }

          if (request.uri.path == '/rest/v1/rpc/get_profile_flow_counts') {
            await _sendJson(
              request,
              body: [
                {'active_flows_count': 10, 'total_flow_events_count': 211},
              ],
            );
            return;
          }

          await _sendJson(request, statusCode: HttpStatus.notFound, body: {});
        },
        (client, requests) async {
          await client.auth.recoverSession(_sessionJson(ownerUserId));
          final repo = ProfileRepo(client);

          final profile = await repo.getProfile(ownerUserId);

          return (profile: profile, requests: List<Uri>.from(requests));
        },
      );

      expect(result.profile?.id, ownerUserId);
      expect(result.profile?.handle, 'bigjfil');
      expect(result.profile?.displayName, 'BigJFil');
      expect(result.profile?.activeFlowsCount, 10);
      expect(result.profile?.totalFlowEventsCount, 211);
      expect(
        result.requests.map((uri) => uri.path),
        containsAllInOrder([
          '/rest/v1/profile_stats',
          '/rest/v1/profiles',
          '/rest/v1/rpc/get_profile_flow_counts',
        ]),
      );
    },
  );

  test(
    'getProfile falls back to current user profiles row when stats are empty',
    () async {
      SharedPreferences.setMockInitialValues({});

      final result = await _withProfileServer(
        (request) async {
          if (request.uri.path == '/rest/v1/profile_stats') {
            await _sendJson(request, body: null);
            return;
          }

          if (request.uri.path == '/rest/v1/profiles') {
            await _sendJson(request, body: [_profileRow(ownerUserId)]);
            return;
          }

          if (request.uri.path == '/rest/v1/rpc/get_profile_flow_counts') {
            await _sendJson(
              request,
              body: [
                {'active_flows_count': 10, 'total_flow_events_count': 211},
              ],
            );
            return;
          }

          await _sendJson(request, statusCode: HttpStatus.notFound, body: {});
        },
        (client, requests) async {
          await client.auth.recoverSession(_sessionJson(ownerUserId));
          final repo = ProfileRepo(client);

          final profile = await repo.getProfile(ownerUserId);

          return (profile: profile, requests: List<Uri>.from(requests));
        },
      );

      expect(result.profile?.displayName, 'BigJFil');
      expect(
        result.requests.map((uri) => uri.path),
        containsAllInOrder(['/rest/v1/profile_stats', '/rest/v1/profiles']),
      );
    },
  );

  test('getProfile does not use owner fallback for another user', () async {
    const viewerUserId = 'c52ecec0-d45d-414f-8a4b-ea0c78a3fd97';
    SharedPreferences.setMockInitialValues({});

    final result = await _withProfileServer(
      (request) async {
        if (request.uri.path == '/rest/v1/profile_stats') {
          await _sendJson(
            request,
            statusCode: HttpStatus.internalServerError,
            body: {
              'code': '57014',
              'message': 'canceling statement due to statement timeout',
            },
          );
          return;
        }

        await _sendJson(request, statusCode: HttpStatus.notFound, body: {});
      },
      (client, requests) async {
        await client.auth.recoverSession(_sessionJson(ownerUserId));
        final repo = ProfileRepo(client);

        final profile = await repo.getProfile(viewerUserId);

        return (profile: profile, requests: List<Uri>.from(requests));
      },
    );

    expect(result.profile, isNull);
    expect(
      result.requests.map((uri) => uri.path),
      isNot(contains('/rest/v1/profiles')),
    );
  });

  test(
    'saveFlowPostToMyFlows creates profile-import metadata and snapshot events',
    () async {
      SharedPreferences.setMockInitialValues({});

      final flowInserts = <Map<String, dynamic>>[];
      final saveUpserts = <Map<String, dynamic>>[];
      final eventUpserts = <Map<String, dynamic>>[];

      final result = await _withProfileServer(
        (request) async {
          if (request.uri.path == '/rest/v1/flow_saves' &&
              request.method == 'GET') {
            await _sendJson(request, body: <Object?>[]);
            return;
          }

          if (request.uri.path == '/rest/v1/flows' && request.method == 'GET') {
            await _sendJson(request, body: <Object?>[]);
            return;
          }

          if (request.uri.path == '/rest/v1/flows' &&
              request.method == 'POST') {
            final payload = await _readJsonMap(request);
            flowInserts.add(payload);
            await _sendJson(request, body: {'id': 901});
            return;
          }

          if (request.uri.path == '/rest/v1/flow_saves' &&
              request.method == 'POST') {
            final payload = await _readJsonMap(request);
            saveUpserts.add(payload);
            await _sendJson(request, body: [payload]);
            return;
          }

          if (request.uri.path == '/rest/v1/user_events' &&
              request.method == 'GET') {
            await _sendJson(request, body: null);
            return;
          }

          if (request.uri.path == '/rest/v1/user_events' &&
              request.method == 'POST') {
            final payload = await _readJsonMap(request);
            eventUpserts.add(payload);
            await _sendJson(
              request,
              body: {
                ...payload,
                'id': 'profile-import-event-1',
                'created_at': '2026-08-03T00:00:00.000Z',
              },
            );
            return;
          }

          await _sendJson(request, statusCode: HttpStatus.notFound, body: {});
        },
        (client, requests) async {
          await client.auth.recoverSession(_sessionJson(ownerUserId));
          final repo = ProfileRepo(client);

          final flowId = await repo.saveFlowPostToMyFlows(
            _profileFlowPost(),
            startDateOverride: DateTime(2026, 8, 3),
          );

          return (
            flowId: flowId,
            requests: List<Uri>.from(requests),
            flowInserts: List<Map<String, dynamic>>.from(flowInserts),
            saveUpserts: List<Map<String, dynamic>>.from(saveUpserts),
            eventUpserts: List<Map<String, dynamic>>.from(eventUpserts),
          );
        },
      );

      expect(result.flowId, 901);
      expect(result.flowInserts, hasLength(1));
      expect(result.saveUpserts, hasLength(1));
      expect(result.eventUpserts, hasLength(1));

      final flowPayload = result.flowInserts.single;
      expect(flowPayload['user_id'], ownerUserId);
      expect(flowPayload['name'], 'CODEX_PROFILE_IMPORT_SMOKE');
      expect(flowPayload['active'], isFalse);
      expect(flowPayload['is_saved'], isTrue);
      expect(flowPayload['origin_type'], 'profile_import');
      expect(flowPayload['origin_flow_id'], 321);
      expect(flowPayload['root_flow_id'], 321);
      expect(flowPayload['start_date'], startsWith('2026-08-03'));
      expect(flowPayload['end_date'], startsWith('2026-08-12'));

      final savePayload = result.saveUpserts.single;
      expect(savePayload['user_id'], ownerUserId);
      expect(savePayload['flow_id'], 901);
      expect(savePayload['saved_from'], 'profile');
      expect(savePayload['metadata'], {
        'flow_post_id': 'post-profile-import-1',
        'source_user_id': 'source-user-1',
      });

      final eventPayload = result.eventUpserts.single;
      expect(eventPayload['flow_local_id'], 901);
      expect(eventPayload['title'], 'Opening sitting');
      expect(eventPayload['detail'], 'snapshot detail');
      expect(eventPayload['location'], 'Temple room');
      expect(eventPayload['all_day'], isFalse);
      expect(eventPayload['starts_at'], contains('2026-08-05'));
    },
  );

  test(
    'saveFlowPostToMyFlows returns existing save without duplicate writes',
    () async {
      SharedPreferences.setMockInitialValues({});
      var flowInsertCount = 0;
      var flowSaveWriteCount = 0;
      var eventWriteCount = 0;

      final flowId = await _withProfileServer(
        (request) async {
          if (request.uri.path == '/rest/v1/flow_saves' &&
              request.method == 'GET') {
            await _sendJson(
              request,
              body: [
                {'flow_id': 777, 'saved_at': '2026-08-03T00:00:00.000Z'},
              ],
            );
            return;
          }

          if (request.uri.path == '/rest/v1/flows' &&
              request.method == 'POST') {
            flowInsertCount++;
          }
          if (request.uri.path == '/rest/v1/flow_saves' &&
              request.method == 'POST') {
            flowSaveWriteCount++;
          }
          if (request.uri.path == '/rest/v1/user_events' &&
              request.method == 'POST') {
            eventWriteCount++;
          }

          await _sendJson(request, statusCode: HttpStatus.notFound, body: {});
        },
        (client, _) async {
          await client.auth.recoverSession(_sessionJson(ownerUserId));
          return ProfileRepo(client).saveFlowPostToMyFlows(_profileFlowPost());
        },
      );

      expect(flowId, 777);
      expect(flowInsertCount, 0);
      expect(flowSaveWriteCount, 0);
      expect(eventWriteCount, 0);
    },
  );

  test(
    'getSavedFlowPostFlowId falls back to existing profile-import flow',
    () async {
      SharedPreferences.setMockInitialValues({});

      final flowId = await _withProfileServer(
        (request) async {
          if (request.uri.path == '/rest/v1/flow_saves' &&
              request.method == 'GET') {
            await _sendJson(request, body: <Object?>[]);
            return;
          }

          if (request.uri.path == '/rest/v1/flows' && request.method == 'GET') {
            await _sendJson(
              request,
              body: [
                {'id': 778, 'created_at': '2026-08-04T00:00:00.000Z'},
              ],
            );
            return;
          }

          await _sendJson(request, statusCode: HttpStatus.notFound, body: {});
        },
        (client, _) async {
          await client.auth.recoverSession(_sessionJson(ownerUserId));
          return ProfileRepo(client).getSavedFlowPostFlowId(_profileFlowPost());
        },
      );

      expect(flowId, 778);
    },
  );
}

Future<T> _withProfileServer<T>(
  Future<void> Function(HttpRequest request) handle,
  Future<T> Function(SupabaseClient client, List<Uri> requests) run,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final requests = <Uri>[];
  final subscription = server.listen((request) async {
    requests.add(request.uri);
    await handle(request);
  });

  final client = SupabaseClient(
    'http://${server.address.host}:${server.port}',
    'test-anon-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );

  try {
    return await run(client, requests);
  } finally {
    await subscription.cancel();
    await server.close(force: true);
  }
}

Future<void> _sendJson(
  HttpRequest request, {
  required Object? body,
  int statusCode = HttpStatus.ok,
}) async {
  request.response.statusCode = statusCode;
  request.response.headers.contentType = ContentType.json;
  request.response.write(jsonEncode(body));
  await request.response.close();
}

Future<Map<String, dynamic>> _readJsonMap(HttpRequest request) async {
  final raw = await utf8.decoder.bind(request).join();
  if (raw.trim().isEmpty) return <String, dynamic>{};

  final decoded = jsonDecode(raw);
  if (decoded is List && decoded.isNotEmpty) {
    return Map<String, dynamic>.from(decoded.first as Map);
  }
  return Map<String, dynamic>.from(decoded as Map);
}

FlowPost _profileFlowPost() {
  return FlowPost(
    id: 'post-profile-import-1',
    userId: 'source-user-1',
    sourceFlowId: 321,
    name: 'CODEX_PROFILE_IMPORT_SMOKE',
    color: 0xFFAA55CC,
    notes: 'profile import notes',
    rules: const [
      {'kind': 'profile-rule'},
    ],
    startDate: DateTime(2026, 7, 1),
    endDate: DateTime(2026, 7, 10),
    payloadJson: const {
      'events': [
        {
          'offset_days': 2,
          'title': 'Opening sitting',
          'detail': 'snapshot detail',
          'location': 'Temple room',
          'all_day': false,
          'start_time': '10:30',
          'end_time': '11:00',
        },
      ],
    },
    createdAt: DateTime.utc(2026, 7, 1),
  );
}

Map<String, Object?> _profileRow(String userId) {
  return {
    'id': userId,
    'handle': 'bigjfil',
    'display_name': 'BigJFil',
    'avatar_url': null,
    'avatar_glyphs': <String>[],
    'email': 'bigjfil@example.com',
    'bio': 'Creator/Founder of h3w',
    'location': null,
    'is_discoverable': true,
    'allow_incoming_shares': true,
    'created_at': '2026-05-04T20:42:08Z',
  };
}

String _sessionJson(String userId) {
  final expiresAt =
      DateTime.now().add(const Duration(days: 365)).millisecondsSinceEpoch ~/
      1000;
  return jsonEncode(<String, Object?>{
    'access_token': 'test-access-token-$expiresAt',
    'expires_in': 31536000,
    'refresh_token': 'test-refresh-token',
    'token_type': 'bearer',
    'user': <String, Object?>{
      'id': userId,
      'app_metadata': <String, Object?>{
        'provider': 'email',
        'providers': <String>['email'],
      },
      'user_metadata': <String, Object?>{},
      'aud': 'authenticated',
      'email': 'profile-owner@example.com',
      'phone': '',
      'created_at': '2026-01-01T00:00:00.000000Z',
      'email_confirmed_at': '2026-01-01T00:00:00.000000Z',
      'role': 'authenticated',
      'updated_at': '2026-01-01T00:00:00.000000Z',
    },
    'expiresAt': expiresAt,
  });
}
