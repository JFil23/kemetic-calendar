import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Flow Studio Add Flow helper uses a stable ID and dismiss gate', () {
    final source = _between(
      _read('lib/features/calendar/calendar_flow_pages.dart'),
      'Future<void> _maybeShowFlowStudioAddFlowHelper',
      '  Future<void> _markFlowStudioHelperCompleted',
    );
    final helperIdIndex = source.indexOf(
      'helperId: OnboardingHelperIds.flowStudioAddFlow',
    );
    final completeIndex = source.indexOf(
      'helperService.markHelperCompleted(',
      helperIdIndex,
    );
    final clearIndex = source.indexOf(
      'GuidedOnboardingController.instance.clear();',
      completeIndex,
    );

    expect(helperIdIndex, isNonNegative);
    expect(completeIndex, greaterThan(helperIdIndex));
    expect(clearIndex, greaterThan(completeIndex));
    expect(source, isNot(contains('OnboardingHelperIds.flowBuilder')));
    expect(_count(source, "'helper_seen_flow_builder'"), 1);
  });

  test("Ma'at flow list helper uses the Flow Studio Add Flow ID", () {
    final source = _between(
      _read('lib/features/calendar/calendar_maat_flows.dart'),
      'Future<void> _maybeShowFlowStudioAddFlowHelper',
      '  Future<void> _markFlowStudioHelperCompleted',
    );
    final helperIdIndex = source.indexOf(
      'helperId: OnboardingHelperIds.flowStudioAddFlow',
    );
    final completeIndex = source.indexOf(
      'helperService.markHelperCompleted(',
      helperIdIndex,
    );
    final clearIndex = source.indexOf(
      'GuidedOnboardingController.instance.clear();',
      completeIndex,
    );

    expect(helperIdIndex, isNonNegative);
    expect(completeIndex, greaterThan(helperIdIndex));
    expect(clearIndex, greaterThan(completeIndex));
    expect(source, isNot(contains('OnboardingHelperIds.flowBuilder')));
    expect(_count(source, "'helper_seen_flow_builder'"), 1);
  });

  test(
    'calendar helper waits for service hydration and dismiss advances chain',
    () {
      final source = _between(
        _read('lib/features/calendar/calendar_page.dart'),
        'Future<void> _maybeShowCalendarHelperAfterOnboarding',
        '  ({',
      );
      final hydrateIndex = source.indexOf('helperService.hydrateUser(userId)');
      final syncGateIndex = source.indexOf(
        'helperService.shouldShowHelperSync(userId, helper.id)',
        hydrateIndex,
      );
      final helperIdIndex = source.indexOf('helperId: helper.id');
      final completeIndex = source.indexOf(
        'final completion = _markOnboardingHelperCompleted(helper.id);',
        helperIdIndex,
      );
      final trackIndex = source.indexOf('Events.trackIfAuthed(', completeIndex);

      expect(hydrateIndex, isNonNegative);
      expect(syncGateIndex, greaterThan(hydrateIndex));
      expect(helperIdIndex, greaterThan(syncGateIndex));
      expect(completeIndex, greaterThan(helperIdIndex));
      expect(trackIndex, greaterThan(completeIndex));
      expect(source, isNot(contains('clearActiveHelper: false')));
      expect(_count(source, 'Events.trackIfAuthed('), 1);
      expect(source, contains('_maybeShowCalendarHelperAfterOnboarding'));
    },
  );

  test('profile community helper gates dismiss and reveal through service', () {
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
      contains('helperId: OnboardingHelperIds.profileCommunityFeed'),
    );
    expect(helperSource, contains('helperService.shouldShowHelperSync'));
    final dismissCompleteIndex = helperSource.indexOf(
      'helperService.markHelperCompleted(',
    );
    final dismissClearIndex = helperSource.indexOf(
      'GuidedOnboardingController.instance.clear();',
      dismissCompleteIndex,
    );
    expect(dismissCompleteIndex, isNonNegative);
    expect(dismissClearIndex, greaterThan(dismissCompleteIndex));
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
    expect(_count(source, "'helper_seen_profile_community_feed'"), 2);
  });

  test('all visible helper bubbles provide stable helper IDs', () {
    final sources = [
      _read('lib/features/calendar/calendar_flow_pages.dart'),
      _read('lib/features/calendar/calendar_maat_flows.dart'),
      _read('lib/features/calendar/calendar_page.dart'),
      _read('lib/features/journal/journal_page.dart'),
      _read('lib/features/settings/settings_page.dart'),
      _read('lib/features/profile/profile_page.dart'),
    ].join('\n');
    final helperBubbleCount = _count(
      sources,
      'variant: CoachmarkVariant.helperBubble',
    );
    final helperIdCount = _count(sources, 'helperId:');
    final helperUserIdCount = _count(sources, 'helperUserId:');

    expect(helperBubbleCount, greaterThan(0));
    expect(helperIdCount, helperBubbleCount);
    expect(helperUserIdCount, helperBubbleCount);
    expect(sources, isNot(contains('OnboardingHelperIds.flowBuilder')));
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
