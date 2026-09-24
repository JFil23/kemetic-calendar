import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/flow_appearance.dart';
import 'package:mobile/data/flow_post_model.dart';
import 'package:mobile/features/profile/flow_post_caption_sheet.dart';
import 'package:mobile/features/profile/posted_flow_artifact.dart';
import 'package:mobile/features/profile/profile_flow_post_tile.dart';
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
      150,
    );
    final duration = tester.widget<Text>(find.text('30 DAYS'));
    expect(duration.style?.fontFamily, 'Inter');
    expect(duration.style?.fontSize, 8);
    expect(duration.style?.letterSpacing, 1.6);
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
    expect(heights, everyElement(236));
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

  testWidgets(
    'profile flow post platforms the canonical artifact without outer housing',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final post = FlowPost(
        id: 'profile-post-owner',
        userId: 'owner-1',
        name: 'Daily Math Visuals',
        color: 0xFF6F93A8,
        notes: 'One linked visual mathematics lesson each day.',
        rules: const <dynamic>[],
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 11, 29),
        aiMetadata: const <String, dynamic>{
          'shared_note':
              'The one I keep coming back to when everything else slips. '
              'It has become the quiet beginning I can still trust.',
        },
        createdAt: DateTime(2026, 9, 22),
        likesCount: 2,
        commentsCount: 1,
        likedByMe: false,
        hasLikesCount: true,
        hasCommentsCount: true,
        hasLikedByMe: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            brightness: Brightness.dark,
            fontFamily: 'GentiumPlus',
          ),
          home: Scaffold(
            backgroundColor: const Color(0xFF070604),
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ProfileFlowPostTile(
                  post: post,
                  appearance: const FlowAppearance(
                    signKind: FlowSignKind.palmCount,
                    accentArgb: 0xFF6F93A8,
                  ),
                  accent: const Color(0xFF6F93A8),
                  relationshipLabel: 'You',
                  authorDisplayName: 'BigJFil',
                  authorHandle: 'bigjfil',
                  authorAvatarUrl: null,
                  authorAvatarGlyphIds: const <String>[],
                  events: const <dynamic>[],
                  postedDateLabel: 'Rekh-Nedjes 8 · 2026',
                  isOwner: true,
                  onOpenAuthor: () {},
                  onOpenFlow: () {},
                  onOpenMenu: (_) {},
                  onShare: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final tile = find.byKey(
        const ValueKey<String>('profile-flow-post-profile-post-owner'),
      );
      expect(tile, findsOneWidget);
      expect(tester.widget(tile), isA<SizedBox>());
      expect(tester.getSize(tile).height, 392);
      expect(find.byType(PostedFlowArtifact), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('profile-flow-post-menu')),
        findsOneWidget,
      );
      expect(find.text('View details'), findsNothing);
      expect(find.text('Edit caption'), findsNothing);
      expect(find.text('Save'), findsNothing);
      expect(find.text('BigJFil'), findsOneWidget);
      expect(find.text('@bigjfil'), findsOneWidget);
      expect(find.text('Rekh-Nedjes 8 · 2026'), findsOneWidget);
      expect(find.textContaining('Posted Rekh-Nedjes'), findsNothing);
      expect(find.text('More'), findsNothing);
      expect(find.text('Share'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('visitor profile flow post exposes Save but no owner controls', (
    tester,
  ) async {
    final post = FlowPost(
      id: 'profile-post-visitor',
      userId: 'visited-user',
      name: 'Dawn House Rite',
      color: 0xFFB8A067,
      notes: 'At dawn, the world returns to its order.',
      rules: const <dynamic>[],
      createdAt: DateTime(2026, 9, 21),
      likesCount: 0,
      commentsCount: 0,
      likedByMe: false,
      hasLikesCount: true,
      hasCommentsCount: true,
      hasLikedByMe: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: ProfileFlowPostTile(
            post: post,
            appearance: const FlowAppearance(
              signKind: FlowSignKind.palmCount,
              accentArgb: 0xFFB8A067,
            ),
            accent: const Color(0xFFB8A067),
            relationshipLabel: 'Following',
            authorDisplayName: 'L.',
            authorHandle: 'lcc86',
            authorAvatarUrl: null,
            authorAvatarGlyphIds: const <String>[],
            events: const <dynamic>[],
            postedDateLabel: 'Paopi 25 · 2026',
            isOwner: false,
            onOpenAuthor: () {},
            onOpenFlow: () {},
            onOpenMenu: (_) {},
            onShare: () {},
            onSave: () {},
            onTogether: () {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Together'), findsOneWidget);
    expect(find.text('Share'), findsNothing);
    expect(find.text('Edit caption'), findsNothing);
    expect(find.text('Remove'), findsNothing);
    expect(find.byType(PostedFlowArtifact), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
      final profileTile = File(
        'lib/features/profile/profile_flow_post_tile.dart',
      ).readAsStringSync();
      final engagement = File(
        'lib/features/profile/flow_post_engagement_row.dart',
      ).readAsStringSync();
      final icons = File(
        'lib/features/profile/haw_profile_icon.dart',
      ).readAsStringSync();

      expect(profile, contains('SocialFlowPostTile('));
      expect(profile, contains('ProfileFlowPostTile('));
      expect(profile, contains('_postPageController = PageController();'));
      expect(profile, contains('_repo.getFlowPosts(widget.userId)'));
      expect(profile, contains('_repo.restoreCachedFlowPosts(widget.userId)'));
      expect(profile, contains("label: 'Post'"));
      expect(profile, contains('_openPostChooser()'));
      expect(profile, contains('useShortMonthName: compact'));
      expect(profile, contains("title.toUpperCase()"));
      expect(profile, contains('color: _profileSurface'));
      expect(profile, contains('Color(0x850B0906)'));
      expect(profile, contains('Color(0x700B0906)'));
      expect(profile, contains('Color(0xBD0B0906)'));
      expect(profile, contains('BorderRadius.circular(pill ? 999 : 14)'));
      expect(profile, contains('const Positioned.fill('));
      expect(profile, contains('child: ProfileDayCycleBackdrop()'));
      expect(profileTile, contains('ProfileAvatar('));
      expect(profileTile, contains('profileV2: true'));
      expect(engagement, contains('final bool inlineUnified;'));
      expect(engagement, contains('final bool profileV2;'));
      expect(profile, isNot(contains("label: 'Flow Events'")));
      expect(profile, isNot(contains('_buildPostFlowButton')));
      expect(profile, isNot(contains('_buildPostInsightButton')));
      expect(picker, contains('PostedFlowArtifact('));
      expect(socialTile, contains('PostedFlowArtifact('));
      expect(artifact, contains('UserFlowAppearanceHero('));
      expect(artifact, contains('const double _artifactHeight = 236'));
      expect(artifact, contains('const double _artifactHeroHeight = 150'));
      expect(artifact, contains('const double _artifactCopyHeight = 84'));
      expect(artifact, isNot(contains('_buildCompactArtifact')));
      expect(artifact, isNot(contains('if (appearance.isEmpty)')));
      expect(artifact, isNot(contains('_firstCharacter')));
      expect(icons, contains('..strokeWidth ='));
      expect(icons, contains("HawProfileIconKind.post"));
      expect(icons, contains("HawProfileIconKind.settings"));
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
    expect(userDetail, contains(r'NEXT ${visibleUpcoming.length} UPCOMING'));
    expect(
      File('lib/features/calendar/calendar_page.dart').readAsStringSync(),
      contains('CalendarPage._mountedState?._userFlowCalendarPreviewForWindow'),
    );
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
    expect(profile, contains('color: _profileSurface'));
  });
}
