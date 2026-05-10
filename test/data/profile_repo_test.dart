import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/profile_repo.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
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
}
