import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/flow_appearance.dart';
import 'package:mobile/data/flow_post_model.dart';
import 'package:mobile/features/profile/flow_post_caption_sheet.dart';
import 'package:mobile/features/profile/posted_flow_artifact.dart';
import 'package:mobile/features/profile/social_flow_post_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    try {
      Supabase.instance.client;
    } catch (_) {
      await Supabase.initialize(
        url: 'https://example.supabase.co',
        anonKey: 'anon-key-0123456789012345678901234567890123456789',
      );
    }
  });

  testWidgets('renders one portable flow artifact with Merkhet and span', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: SizedBox(
            width: 390,
            child: PostedFlowArtifact(
              name: 'Evening Return',
              color: 0xFF6F93A8,
              notes: 'A measured return to the body.',
              startDate: DateTime(2026, 9, 1),
              endDate: DateTime(2026, 9, 30),
              appearance: FlowAppearance(
                signKind: FlowSignKind.palmCount,
                signLabel: 'kept',
                accentArgb: 0xFF6F93A8,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('posted-flow-artifact')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('posted-flow-artifact-appearance')),
      findsOneWidget,
    );
    expect(find.text('Evening Return'), findsOneWidget);
    expect(find.text('30 DAYS'), findsOneWidget);
    expect(find.text('A measured return to the body.'), findsOneWidget);
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey('posted-flow-artifact-appearance')),
          )
          .height,
      148,
    );
  });

  testWidgets('image, widget-only, and plain artifacts share one geometry', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: const <Widget>[
                PostedFlowArtifact(
                  key: ValueKey<String>('image-artifact'),
                  name: 'Image Flow',
                  color: 0xFF8A8378,
                  appearance: FlowAppearance(imageObjectPath: 'image-flow.jpg'),
                ),
                PostedFlowArtifact(
                  key: ValueKey<String>('widget-artifact'),
                  name: 'Widget Flow',
                  color: 0xFF6F93A8,
                  appearance: FlowAppearance(signKind: FlowSignKind.palmCount),
                ),
                PostedFlowArtifact(
                  key: ValueKey<String>('plain-artifact'),
                  name: 'Plain Flow',
                  color: 0xFFC08E6E,
                  appearance: FlowAppearance.empty,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final heights = <double>[
      tester.getSize(find.byKey(const ValueKey('image-artifact'))).height,
      tester.getSize(find.byKey(const ValueKey('widget-artifact'))).height,
      tester.getSize(find.byKey(const ValueKey('plain-artifact'))).height,
    ];
    expect(heights, everyElement(300));
    expect(
      find.byKey(const ValueKey('posted-flow-artifact-appearance')),
      findsNWidgets(3),
    );
    expect(
      find.byKey(const ValueKey('user-flow-appearance-sign-layer')),
      findsOneWidget,
    );
    expect(find.text('P'), findsNothing);
  });

  testWidgets('caption composer previews typed words above the artifact', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showFlowPostCaptionSheet(
              context: context,
              actionLabel: 'Post flow',
              preview: const PostedFlowArtifact(
                name: 'Evening Return',
                color: 0xFF6F93A8,
                appearance: FlowAppearance.empty,
              ),
            ),
            child: const Text('Open composer'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open composer'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('flow-post-caption-field')),
      'This practice changed my mornings.',
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('flow-post-live-caption-preview')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('flow-post-live-caption-text')),
      findsOneWidget,
    );
    expect(find.text('This practice changed my mornings.'), findsNWidgets(2));
  });

  testWidgets(
    'social post keeps one unboxed post and one action row at 390px',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final post = FlowPost(
        id: 'social-post-1',
        userId: 'reader-1',
        name: 'Return to the Body',
        color: 0xFF6F93A8,
        notes: 'A measured evening practice.',
        rules: const <dynamic>[],
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 30),
        aiMetadata: const <String, dynamic>{
          'shared_note': 'This flow changes the way I exercise.',
        },
        createdAt: DateTime(2026, 9, 22),
        authorHandle: 'amina',
        authorDisplayName: 'Amina',
        likesCount: 14,
        commentsCount: 3,
        likedByMe: false,
        hasLikesCount: true,
        hasCommentsCount: true,
        hasLikedByMe: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SocialFlowPostTile(
                  post: post,
                  appearance: const FlowAppearance(
                    signKind: FlowSignKind.palmCount,
                    signLabel: 'kept',
                    accentArgb: 0xFF6F93A8,
                  ),
                  accent: const Color(0xFF6F93A8),
                  relationshipLabel: 'Following',
                  events: const <Map<String, dynamic>>[],
                  postedDateLabel: 'Rekh-Nedjes 10',
                  isOwner: false,
                  onOpenAuthor: () {},
                  onOpenFlow: () {},
                  onShare: () {},
                  onSaveOrEdit: () {},
                  onTogether: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('social-flow-post-social-post-1')),
        findsOneWidget,
      );
      expect(find.byType(SocialPostAuthorHeader), findsOneWidget);
      expect(find.byType(PostedFlowArtifact), findsOneWidget);
      expect(
        find.text('This flow changes the way I exercise.'),
        findsOneWidget,
      );
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Together'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'social flow surfaces have one artifact and no legacy flow renderer',
    () {
      final profile = File(
        'lib/features/profile/profile_page.dart',
      ).readAsStringSync();
      final picker = File(
        'lib/features/profile/flow_post_picker_page.dart',
      ).readAsStringSync();
      final artifact = File(
        'lib/features/profile/posted_flow_artifact.dart',
      ).readAsStringSync();
      final socialTile = File(
        'lib/features/profile/social_flow_post_tile.dart',
      ).readAsStringSync();

      expect(profile, contains('SocialFlowPostTile('));
      expect(picker, contains('PostedFlowArtifact('));
      expect(socialTile, contains('PostedFlowArtifact('));
      expect(artifact, contains('UserFlowAppearanceHero('));
      expect(artifact, isNot(contains('_buildCompactArtifact')));
      expect(artifact, isNot(contains('if (appearance.isEmpty)')));
      expect(profile, isNot(contains('_buildExpandedFlowDetailCard')));
      expect(profile, isNot(contains('_buildExpandedFlowEventTile')));
      expect(profile, isNot(contains('copyWith(clearImage: true)')));
      expect(profile, isNot(contains("label: 'Begin'")));
      expect(profile, isNot(contains('_splitFeedItems')));
    },
  );

  test('caption, share, and canonical detail boundaries stay explicit', () {
    final profile = File(
      'lib/features/profile/profile_page.dart',
    ).readAsStringSync();
    final caption = File(
      'lib/features/profile/flow_post_caption_sheet.dart',
    ).readAsStringSync();
    final engagement = File(
      'lib/features/profile/flow_post_engagement_row.dart',
    ).readAsStringSync();
    final socialTile = File(
      'lib/features/profile/social_flow_post_tile.dart',
    ).readAsStringSync();
    final detail = File(
      'lib/features/profile/flow_post_detail_page.dart',
    ).readAsStringSync();
    final sharedDetail = File(
      'lib/features/inbox/shared_flow_details_page.dart',
    ).readAsStringSync();
    final userDetail = File(
      'lib/features/calendar/calendar_user_flow_detail.dart',
    ).readAsStringSync();
    final profileRepo = File('lib/data/profile_repo.dart').readAsStringSync();
    final commonsRepo = File('lib/data/commons_repo.dart').readAsStringSync();

    expect(caption, contains('kFlowPostCaptionMaxLength = 280'));
    expect(caption, contains('ValueListenableBuilder<TextEditingValue>'));
    expect(caption, contains("'flow-post-live-caption-preview'"));
    expect(caption, contains("'flow-post-live-caption-text'"));
    expect(profile, contains('updateFlowPostSharedNote'));
    expect(profileRepo, contains("'get_profile_feed_cards'"));
    expect(commonsRepo, contains("'get_commons_home_cards'"));
    expect(detail, contains('_fullPostFor(post)'));
    expect(profileRepo, contains("post.payloadJson?['events'] is! List"));
    expect(socialTile, contains('additionalActions:'));
    expect(profile, isNot(contains('_feedBloomController')));
    expect(profile, isNot(contains('_buildExpandedFeedView')));
    expect(engagement, contains("'flow-post-share-action'"));
    expect(engagement, contains("'Share'"));
    expect(detail, contains('SharedFlowDetailsPage('));
    expect(detail, contains('useCanonicalUserFlowDetail: true'));
    expect(detail, contains("label: 'Remove from profile'"));
    expect(detail, contains('FlowDetailActionKind.manage'));
    expect(detail, contains('resolveCanonicalCustomFlowActionPolicy('));
    expect(detail, isNot(contains('FlowPostEngagementRow(')));
    expect(sharedDetail, contains('this.useCanonicalUserFlowDetail = false'));
    expect(
      sharedDetail,
      contains('useMySavedExpansionParity: widget.useCanonicalUserFlowDetail'),
    );
    expect(userDetail, contains('final externalPolicy = widget.actionPolicy'));
    expect(userDetail, contains('if (externalPolicy != null)'));
    expect(profile, contains('color: const Color(0xFF070604)'));
  });
}
