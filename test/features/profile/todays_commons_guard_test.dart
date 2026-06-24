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
    expect(source, contains('dailyReflectionQuestionForDate'));
    expect(source, contains("Today's Rhythm"));
    expect(source, contains('_commonsInsightFragments'));
    expect(source, contains('_commonsDiscoverItems'));
  });

  test('Today Commons keeps rollups fallback-only in this slice', () {
    expect(source, contains("Today's Rhythm"));
    expect(
      source,
      contains(
        'Community rollups are unavailable, so this shows profile rhythm.',
      ),
    );
    expect(source, isNot(contains('_communityRhythmRollups')));
    expect(source, isNot(contains('_loadCommunityRhythmRollups')));
  });

  test('Discover Practices uses expanded For You blocks', () {
    final discoverSource = _methodSource(
      source,
      'Widget _buildCommonsDiscoverSection()',
      'Widget _buildCommonsEndBoundary()',
    );
    final expandedShellSource = _methodSource(
      source,
      'Widget _buildExpandedFeedCardShell({',
      'Widget _buildExpandedFeedAuthorRow({',
    );

    expect(discoverSource, contains('_buildCommonsDiscoverExpandedBlock'));
    expect(discoverSource, contains('_buildExpandedFeedDetailCard'));
    expect(discoverSource, contains('embeddedInScrollView: true'));
    expect(
      discoverSource,
      contains(
        'Commons Discover intentionally embeds the expanded For You block',
      ),
    );
    expect(source, contains('_openCommonsDiscoverItem'));
    expect(source, contains('_selectedFeedTab = _SocialFeedTab.forYou'));
    expect(expandedShellSource, contains('embeddedInScrollView'));
    expect(expandedShellSource, contains('Icons.north_east_rounded'));
    expect(source, isNot(contains('_buildCommonsDiscoverCard')));
    expect(source, isNot(contains('_buildCommonsDiscoverFlow')));
    expect(source, isNot(contains('_FeedTileMode')));
  });

  test('Discover Practices uses the loaded For You feed source', () {
    expect(source, contains('return _feedItems.take(3).toList'));
    expect(source, contains('same real feed data as For You.'));
    expect(
      source,
      contains('Finite real items from the same For You feed page.'),
    );
  });

  test('Commons Discover inherits expanded engagement and owner actions', () {
    final expandedFlowSource = _methodSource(
      source,
      'Widget _buildExpandedFlowDetailCard(',
      'Widget _buildExpandedInsightDetailCard(',
    );

    expect(expandedFlowSource, contains('FlowPostEngagementRow('));
    expect(expandedFlowSource, contains("ValueKey('expanded_"));
    expect(
      expandedFlowSource,
      contains('onPressed: () => _removePost(post.id)'),
    );
    expect(expandedFlowSource, contains('onPressed: () => _savePost(post)'));
    expect(expandedFlowSource, contains('Practice Together'));
    expect(expandedFlowSource, contains('cleanFlowOverview('));
    expect(expandedFlowSource, contains('decodedOverview: meta.overview'));
  });

  test('Today Commons keeps honest empty states', () {
    expect(source, contains('No fragments have been shared today.'));
    expect(source, contains('No discoverable practices yet.'));
    expect(source, contains('Public commons answers are not enabled yet.'));
    expect(source, contains('Shared progress rooms are not active yet.'));
  });

  test('prototype social claims are not present', () {
    const removedPrototypeCopy = <String>[
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
