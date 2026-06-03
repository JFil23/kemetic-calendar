import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Flow Builder helper is marked seen when displayed', () {
    final source = _read('lib/features/calendar/calendar_flow_pages.dart');
    final showIndex = source.indexOf(
      'GuidedOnboardingController.instance.show(',
    );
    final markIndex = source.indexOf(
      'await storage.markHelperCompleted(userId, OnboardingHelperIds.flowBuilder);',
      showIndex,
    );
    final trackIndex = source.indexOf("'helper_seen_flow_builder'", markIndex);

    expect(showIndex, isNonNegative);
    expect(markIndex, greaterThan(showIndex));
    expect(trackIndex, greaterThan(markIndex));
    expect(_count(source, "'helper_seen_flow_builder'"), 1);
  });

  test("Ma'at flows helper is marked seen when displayed", () {
    final source = _read('lib/features/calendar/calendar_maat_flows.dart');
    final showIndex = source.indexOf(
      'GuidedOnboardingController.instance.show(',
    );
    final markIndex = source.indexOf(
      'await storage.markHelperCompleted(userId, OnboardingHelperIds.flowBuilder);',
      showIndex,
    );
    final trackIndex = source.indexOf("'helper_seen_flow_builder'", markIndex);

    expect(showIndex, isNonNegative);
    expect(markIndex, greaterThan(showIndex));
    expect(trackIndex, greaterThan(markIndex));
    expect(_count(source, "'helper_seen_flow_builder'"), 1);
  });

  test(
    'calendar helper is marked seen on display and dismiss advances chain',
    () {
      final source = _between(
        _read('lib/features/calendar/calendar_page.dart'),
        'Future<void> _maybeShowCalendarHelperAfterOnboarding',
        '  ({',
      );
      final showIndex = source.indexOf(
        'GuidedOnboardingController.instance.show(',
      );
      final markIndex = source.indexOf(
        'await _markOnboardingHelperCompleted(helper.id, clearActiveHelper: false);',
        showIndex,
      );
      final trackIndex = source.indexOf('Events.trackIfAuthed(', markIndex);

      expect(showIndex, isNonNegative);
      expect(markIndex, greaterThan(showIndex));
      expect(trackIndex, greaterThan(markIndex));
      expect(_count(source, 'Events.trackIfAuthed('), 1);
      expect(source, contains('_maybeShowCalendarHelperAfterOnboarding'));
    },
  );

  test('profile community helper uses one guarded seen path', () {
    final source = _read('lib/features/profile/profile_page.dart');
    final helperSource = _between(
      source,
      'Future<void> _maybeShowProfileCommunityHelper',
      '  Future<void> _markProfileCommunityHelperSeen',
    );
    final markSource = _between(
      source,
      'Future<void> _markProfileCommunityHelperSeen',
      '  Future<void> _restoreCachedPostedContent',
    );
    final revealSource = _between(
      source,
      'Future<void> _revealFeed',
      '  Future<void> _closeFeed',
    );

    expect(
      helperSource,
      contains(
        'await _markProfileCommunityHelperSeen(clearActiveHelper: false);',
      ),
    );
    expect(helperSource, isNot(contains('Events.trackIfAuthed(')));
    expect(
      revealSource,
      contains('unawaited(_markProfileCommunityHelperSeen());'),
    );

    final shouldShowIndex = markSource.indexOf('shouldShowHelper');
    final completeIndex = markSource.indexOf('markHelperCompleted');
    final trackIndex = markSource.indexOf(
      "'helper_seen_profile_community_feed'",
    );

    expect(shouldShowIndex, isNonNegative);
    expect(completeIndex, greaterThan(shouldShowIndex));
    expect(trackIndex, greaterThan(completeIndex));
    expect(_count(source, "'helper_seen_profile_community_feed'"), 1);
  });
}

String _read(String path) => File(path).readAsStringSync();

String _between(String source, String startNeedle, String endNeedle) {
  final start = source.indexOf(startNeedle);
  expect(start, isNonNegative, reason: 'Missing source marker: $startNeedle');
  final end = source.indexOf(endNeedle, start + startNeedle.length);
  expect(end, isNonNegative, reason: 'Missing source marker: $endNeedle');
  return source.substring(start, end);
}

int _count(String source, String needle) {
  return RegExp(RegExp.escape(needle)).allMatches(source).length;
}
