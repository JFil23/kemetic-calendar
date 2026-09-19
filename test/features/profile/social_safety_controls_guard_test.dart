import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('social safety controls guard', () {
    late String repoSource;
    late String detailSource;
    late String commentsSource;
    late String profileSource;

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
  });
}
