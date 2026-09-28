import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('lib/features/profile/profile_page.dart').readAsStringSync();
  });

  test('Today Commons uses sticky tabs and real data hooks', () {
    expect(source, contains('SliverPersistentHeader'));
    expect(source, contains('_SocialFeedTab.todaysCommons'));
    expect(source, contains("label: 'COMMONS'"));
    expect(source, contains("isCommons ? 'Commons' : 'For You'"));
    expect(source, isNot(contains("TODAY'S COMMONS")));
    expect(source, isNot(contains("Today's Commons")));
    expect(source, contains('commonsQuestionSeed(DateTime.now())'));
    expect(
      File('lib/data/commons_question_selection.dart').readAsStringSync(),
      contains('dailyReflectionQuestionForDate'),
    );
    expect(source, contains('CommonsRhythmBlock('));
    expect(
      File('lib/features/profile/commons_rhythm_block.dart').readAsStringSync(),
      contains('Public Rhythm'),
    );
    expect(source, contains('_loadCommonsHome'));
    expect(source, contains('CommonsRepo'));
    expect(source, contains('_commonsInsightFragments'));
    expect(source, contains('_commonsDiscoverItems'));
  });

  test('Today Commons uses Commons home instead of profile placeholders', () {
    expect(source, contains('_commonsHome'));
    expect(source, contains('getCommonsHome'));
    expect(source, contains('answerQuestion'));
    expect(source, contains('viewerCanRequestJoin'));
    expect(source, isNot(contains('setPracticeVisibility')));
    expect(source, contains('requestJoinSharedPractice'));
    expect(
      source,
      isNot(
        contains(
          'Community rollups are unavailable, so this shows profile rhythm.',
        ),
      ),
    );
  });

  test(
    'Commons question supports answer compose, edit, delete, report, block',
    () {
      final questionSource = _methodSource(
        source,
        'Widget _buildCommonsQuestionSection()',
        'Widget _buildCommonsAnswerComposer(CommonsQuestion question)',
      );
      final composerSource = _methodSource(
        source,
        'Widget _buildCommonsAnswerComposer(CommonsQuestion question)',
        'Widget _buildCommonsAnswerCard(CommonsAnswer answer',
      );
      final answerCardSource = _methodSource(
        source,
        'Widget _buildCommonsAnswerCard(CommonsAnswer answer',
        'Widget _buildCommonsReflectionSection()',
      );

      final shared = File(
        'lib/features/profile/commons_question_block.dart',
      ).readAsStringSync();
      expect(questionSource, contains('CommonsQuestionBlock('));
      expect(
        questionSource,
        contains('_buildCommonsAnswerComposer(_activeCommonsQuestion())'),
      );
      expect(
        questionSource,
        contains('_buildCommonsAnswerCard(answer, isMine: isMine)'),
      );
      expect(shared, contains('answerBuilder(myAnswer, true)'));
      expect(shared, contains('PUBLIC ANSWERS'));
      expect(composerSource, contains('_commonsAnswerEditing'));
      expect(composerSource, contains('Edit answer'));
      expect(shared, contains('Answer in the Commons'));
      expect(shared, contains('Save public answer'));
      expect(composerSource, contains('_saveCommonsAnswer()'));
      expect(shared, contains('Your answer'));
      expect(answerCardSource, contains("_deleteCommonsAnswer(answer)"));
      expect(answerCardSource, contains("_reportCommonsAnswer(answer)"));
      expect(answerCardSource, contains("_blockCommonsAnswerAuthor(answer)"));
      expect(shared, contains("PopupMenuItem(value: 'edit'"));
      expect(shared, contains("PopupMenuItem(value: 'delete'"));
    },
  );

  test(
    'Practice Together carousel shows public groups and capability-gated actions',
    () {
      final orderingSource = _methodSource(
        source,
        'List<CommonsPracticeRoom> _commonsPracticeRooms()',
        'void _maybeLoadMoreFeed()',
      );
      final sectionSource = _methodSource(
        source,
        'Widget _buildCommonsPracticeTogetherSection()',
        'double _commonsPracticeCarouselHeight(BuildContext context)',
      );
      final cardSource = _methodSource(
        source,
        'Widget _buildCommonsPracticeRoomCard(CommonsPracticeRoom room)',
        'Widget _buildCommonsPublicMemberRoster(CommonsPracticeRoom room)',
      );
      final viewerActionSource = _methodSource(
        source,
        'Widget _buildCommonsPracticeViewerAction(CommonsPracticeRoom room)',
        'Widget _buildCommonsStatusPill(',
      );

      expect(orderingSource, contains('home.publicSharedPractices'));
      expect(orderingSource, contains('home.mySharedPractices'));
      expect(
        orderingSource,
        contains('room.visibility != SharedPracticeRoomVisibility.public'),
      );
      expect(orderingSource, contains('room.memberCount < 2'));
      expect(
        orderingSource,
        contains("room.status.trim().toLowerCase() != 'active'"),
      );
      expect(orderingSource, contains('seen.add(room.id)'));
      expect(sectionSource, contains('PageView.builder'));
      expect(sectionSource, contains('_commonsPracticePageController'));
      expect(sectionSource, contains('BouncingScrollPhysics'));
      expect(sectionSource, contains('onPageChanged'));
      expect(sectionSource, contains('_buildCommonsCarouselDots'));
      expect(cardSource, contains("'Public group flow'"));
      expect(cardSource, contains('room.memberCount'));
      expect(cardSource, contains('_buildCommonsPublicMemberRoster(room)'));
      expect(cardSource, contains('commons_group_like_'));
      expect(viewerActionSource, contains("'Open flow'"));
      expect(
        viewerActionSource,
        contains(
          'if (!room.viewerCanRequestJoin) return const SizedBox.shrink()',
        ),
      );
      expect(viewerActionSource, contains("'Requested'"));
      expect(viewerActionSource, contains("'Practice Together'"));
      expect(viewerActionSource, contains('_requestedCommonsRoomIds'));
      expect(viewerActionSource, contains('_toggleCommonsRoomRequest(room)'));
      expect(source, isNot(contains('_updateCommonsPracticeVisibility')));
      expect(source, isNot(contains('_requestJoinCommonsPractice')));
    },
  );

  test('Discover Practices reuses the For You post component', () {
    final discoverSource = _methodSource(
      source,
      'Widget _buildCommonsDiscoverSection()',
      'Widget _buildCommonsGhostButton({',
    );
    expect(discoverSource, contains('_buildCommonsDiscoverPost'));
    expect(discoverSource, contains('return _buildFeedItemTile(item)'));
    expect(discoverSource, isNot(contains('_buildExpandedFeedDetailCard')));
    expect(discoverSource, isNot(contains('_expandedFeedDetailHeight')));
    expect(source, isNot(contains('_buildCommonsDiscoverCard')));
    expect(source, isNot(contains('_buildCommonsDiscoverFlow')));
    expect(source, isNot(contains('_FeedTileMode')));
  });

  test('Discover Practices uses the loaded For You feed source', () {
    expect(source, contains('final homeDiscover = _commonsHome?.discover'));
    expect(source, contains('return _feedItems.take(3).toList'));
    expect(
      source,
      contains('Public flows and insights from the wider rhythm.'),
    );
  });

  test('Commons Discover inherits shared flow-post actions', () {
    final feedFlowSource = _methodSource(
      source,
      'Widget _buildFeedFlowTile(',
      'Widget _buildFeedInsightTile(',
    );
    final tileSource = File(
      'lib/features/profile/social_flow_post_tile.dart',
    ).readAsStringSync();

    expect(feedFlowSource, contains('SocialFlowPostTile('));
    expect(
      feedFlowSource,
      contains('FlowPostShareActions.open(context, post)'),
    );
    expect(tileSource, contains('FlowPostEngagementRow('));
    expect(tileSource, contains('PostedFlowArtifact('));
    expect(tileSource, contains('additionalActions:'));
    expect(tileSource, contains("label: isOwner ? 'Edit' : 'Save'"));
    expect(tileSource, contains('if (onTogether != null)'));
    expect(tileSource, contains('label: togetherLabel'));
    expect(feedFlowSource, contains('post.viewerCanRequestTogether'));
    expect(feedFlowSource, isNot(contains('_buildForYouFlowTileActions')));
    expect(feedFlowSource, contains(': () => unawaited(_savePost(post))'));
    expect(source, contains('Practice Together'));
    expect(source, isNot(contains('_buildExpandedFlowDetailCard')));
    expect(source, isNot(contains('_buildExpandedFeedView')));
    expect(source, isNot(contains('_feedBloomController')));
  });

  test('Today Commons keeps honest empty states', () {
    expect(source, contains('No fragments have been shared today.'));
    expect(source, contains('No discoverable practices yet.'));
    expect(
      File(
        'lib/features/profile/commons_question_block.dart',
      ).readAsStringSync(),
      contains('Answer in the Commons'),
    );
    expect(source, contains('No public group flows yet.'));
    expect(
      source,
      contains('Public groups appear here after a second person joins.'),
    );
  });

  test('prototype social claims are not present', () {
    const removedPrototypeCopy = <String>[
      'You have seen today\'s commons.',
      'Return to practice.',
      'BACK TO MY DAY',
      'THE COMMONS RENEWS AT DAWN',
      '42 practitioners completed',
      '18 began The Closing',
      '7 reached their first full decan',
      'with three others',
      'Jarale',
      'Monroe',
      'Aset',
      '10-Day Yoga Plan',
      'On Cyclical Return',
      'have answered today',
      'Hold this',
      'mode=gregorian',
      'split=',
      'ov=',
      '%20',
      'Finite real items',
      'Finite real items from the same For You feed page.',
    ];

    for (final copy in removedPrototypeCopy) {
      expect(source, isNot(contains(copy)));
    }
  });
}

String _methodSource(String source, String startMarker, String endMarker) {
  final start = source.indexOf(startMarker);
  final end = source.indexOf(endMarker, start + startMarker.length);

  expect(start, isNonNegative, reason: startMarker);
  expect(end, isNonNegative, reason: endMarker);

  return source.substring(start, end);
}
