import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
