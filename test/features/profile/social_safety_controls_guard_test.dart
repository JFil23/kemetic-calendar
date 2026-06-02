import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('social safety controls guard', () {
    late String repoSource;
    late String detailSource;
    late String commentsSource;
    late String profileSource;
    late String migrationSource;
    late String deleteAccountSource;

    setUpAll(() async {
      repoSource = await File('lib/data/profile_repo.dart').readAsString();
      detailSource = await File(
        'lib/features/profile/flow_post_detail_page.dart',
      ).readAsString();
      commentsSource = await File(
        'lib/features/profile/flow_post_engagement_row.dart',
      ).readAsString();
      profileSource = await File(
        'lib/features/profile/profile_page.dart',
      ).readAsString();
      migrationSource = await File(
        '../supabase/migrations/20260602090000_social_safety_controls.sql',
      ).readAsString();
      deleteAccountSource = await File(
        '../supabase/functions/delete_account/index.ts',
      ).readAsString();
    });

    test('migration creates report and block tables with RLS', () {
      expect(
        migrationSource,
        contains('create table if not exists public.user_blocks'),
      );
      expect(
        migrationSource,
        contains('create table if not exists public.content_reports'),
      );
      expect(
        migrationSource,
        contains('alter table public.user_blocks enable row level security'),
      );
      expect(
        migrationSource,
        contains(
          'alter table public.content_reports enable row level security',
        ),
      );
      expect(migrationSource, contains('Users can create their own reports'));
      expect(migrationSource, contains('Users can delete their own blocks'));
      expect(migrationSource, contains('Users can view unblocked flow posts'));
      expect(migrationSource, contains('Public can view visible flow posts'));
      expect(
        migrationSource,
        contains('Users can view unblocked insight posts'),
      );
      expect(
        migrationSource,
        contains('Users can view unblocked flow post comments'),
      );
    });

    test(
      'mobile has report block and delete controls for live social content',
      () {
        expect(repoSource, contains('Future<bool> blockUser'));
        expect(repoSource, contains('Future<bool> reportContent'));
        expect(repoSource, contains('_filterBlockedFeedItems'));
        expect(detailSource, contains('Report post'));
        expect(detailSource, contains('Block user'));
        expect(commentsSource, contains('Report comment'));
        expect(commentsSource, contains('Block user'));
        expect(commentsSource, contains('deleteFlowPostComment'));
        expect(profileSource, contains('Report user'));
        expect(profileSource, contains('Block user'));
        expect(profileSource, contains('deleteFlowPost'));
      },
    );

    test('account deletion includes report and block rows', () {
      expect(
        deleteAccountSource,
        contains('["content_reports", "reporter_user_id"]'),
      );
      expect(
        deleteAccountSource,
        contains('["content_reports", "reported_user_id"]'),
      );
      expect(
        deleteAccountSource,
        contains('["user_blocks", "blocker_user_id"]'),
      );
      expect(
        deleteAccountSource,
        contains('["user_blocks", "blocked_user_id"]'),
      );
    });
  });
}
