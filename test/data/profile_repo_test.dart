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
}
