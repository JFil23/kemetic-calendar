import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/onboarding/onboarding_progress.dart';

void main() {
  test('Flow Studio Add Flow helper uses a stable ID and dismiss gate', () {
    final source = _between(
      _read('lib/features/calendar/calendar_flow_pages.dart'),
      'Future<void> _maybeShowFlowStudioAddFlowHelper',
      '  Future<void> _markFlowStudioHelperCompleted',
    );
    final registryIndex = source.indexOf(
      'const helper = OnboardingHelperRegistry.flowStudioAddFlow',
    );
    final helperIdIndex = source.indexOf('helperId: helper.id');
    final completeIndex = source.indexOf(
      'helperService.markHelperCompleted(',
      helperIdIndex,
    );
    final completionIdIndex = source.indexOf('helper.id', completeIndex);
    final clearIndex = source.indexOf(
      'GuidedOnboardingController.instance.clear();',
      completeIndex,
    );

    expect(registryIndex, isNonNegative);
    expect(helperIdIndex, isNonNegative);
    expect(completeIndex, greaterThan(helperIdIndex));
    expect(completionIdIndex, greaterThan(completeIndex));
    expect(clearIndex, greaterThan(completeIndex));
    expect(source, isNot(contains('OnboardingHelperIds.flowBuilder')));
    expect(source, contains('helper.analyticsEvent'));
    expect(
      source,
      contains(
        'sourceWidget: OnboardingHelperRegistry.flowHubPageAddFlowSourceWidget',
      ),
    );
  });

  test("Ma'at flow list helper uses the Flow Studio Add Flow ID", () {
    final source = _between(
      _read('lib/features/calendar/calendar_maat_flows.dart'),
      'Future<void> _maybeShowFlowStudioAddFlowHelper',
      '  Future<void> _markFlowStudioHelperCompleted',
    );
    final registryIndex = source.indexOf(
      'const helper = OnboardingHelperRegistry.flowStudioAddFlow',
    );
    final helperIdIndex = source.indexOf('helperId: helper.id');
    final completeIndex = source.indexOf(
      'helperService.markHelperCompleted(',
      helperIdIndex,
    );
    final completionIdIndex = source.indexOf('helper.id', completeIndex);
    final clearIndex = source.indexOf(
      'GuidedOnboardingController.instance.clear();',
      completeIndex,
    );

    expect(registryIndex, isNonNegative);
    expect(helperIdIndex, isNonNegative);
    expect(completeIndex, greaterThan(helperIdIndex));
    expect(completionIdIndex, greaterThan(completeIndex));
    expect(clearIndex, greaterThan(completeIndex));
    expect(source, isNot(contains('OnboardingHelperIds.flowBuilder')));
    expect(source, contains('helper.analyticsEvent'));
    expect(
      source,
      contains(
        'sourceWidget: OnboardingHelperRegistry.maatFlowListAddFlowSourceWidget',
      ),
    );
  });

  test(
    'Journal record helper uses one registered ID for display and Got it',
    () {
      final source = _between(
        _read('lib/features/journal/journal_page.dart'),
        'Future<void> _maybeShowJournalHelper',
        '  @override',
      );
      final registryIndex = source.indexOf(
        'const helper = OnboardingHelperRegistry.journalBadges',
      );
      final asyncGateIndex = source.indexOf(
        'helperService.shouldShowHelper(userId, helper.id)',
      );
      final syncGateIndex = source.indexOf(
        'helperService.shouldShowHelperSync(userId, helper.id)',
      );
      final helperIdIndex = source.indexOf('helperId: helper.id');
      final completeIndex = source.indexOf(
        'helperService.markHelperCompleted(',
        helperIdIndex,
      );
      final completionIdIndex = source.indexOf('helper.id', completeIndex);
      final clearIndex = source.indexOf(
        'GuidedOnboardingController.instance.clear();',
        completeIndex,
      );

      expect(registryIndex, isNonNegative);
      expect(asyncGateIndex, greaterThan(registryIndex));
      expect(syncGateIndex, greaterThan(asyncGateIndex));
      expect(helperIdIndex, greaterThan(syncGateIndex));
      expect(completeIndex, greaterThan(helperIdIndex));
      expect(completionIdIndex, greaterThan(completeIndex));
      expect(clearIndex, greaterThan(completeIndex));
      expect(source, contains('sourceWidget: helper.sourceWidget'));
      expect(source, contains('helper.analyticsEvent'));
      expect(source, isNot(contains('OnboardingHelperIds.journalBadges')));
    },
  );

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
        'helperService.shouldShowHelperSync(userId, helper.definition.id)',
        hydrateIndex,
      );
      final helperIdIndex = source.indexOf('helperId: helper.definition.id');
      final completeIndex = source.indexOf(
        'final completion = _markOnboardingHelperCompleted(',
        helperIdIndex,
      );
      final completionIdIndex = source.indexOf(
        'helper.definition.id',
        completeIndex,
      );
      final trackIndex = source.indexOf('Events.trackIfAuthed(', completeIndex);

      expect(hydrateIndex, isNonNegative);
      expect(syncGateIndex, greaterThan(hydrateIndex));
      expect(helperIdIndex, greaterThan(syncGateIndex));
      expect(completeIndex, greaterThan(helperIdIndex));
      expect(completionIdIndex, greaterThan(completeIndex));
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
      contains('const helper = OnboardingHelperRegistry.profileCommunityFeed'),
    );
    expect(helperSource, contains('helperId: helper.id'));
    expect(helperSource, contains('sourceWidget: helper.sourceWidget'));
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
    final trackIndex = markSource.indexOf('helper.analyticsEvent');

    expect(shouldShowIndex, isNonNegative);
    expect(completeIndex, greaterThan(shouldShowIndex));
    expect(trackIndex, greaterThan(completeIndex));
  });

  test('all visible helper bubbles provide registered helper IDs', () {
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
    final sourceWidgetCount = _count(sources, 'sourceWidget:');

    expect(helperBubbleCount, greaterThan(0));
    expect(helperIdCount, helperBubbleCount);
    expect(helperUserIdCount, helperBubbleCount);
    expect(sourceWidgetCount, helperBubbleCount);
    expect(sources, isNot(contains('OnboardingHelperIds.')));
    expect(sources, isNot(contains('OnboardingHelperIds.flowBuilder')));
  });

  test('registered helper copy covers every visible helper bubble', () {
    final helperTitles = OnboardingHelperRegistry.all
        .map((helper) => helper.title)
        .toSet();
    final helperBodies = OnboardingHelperRegistry.all
        .map((helper) => helper.body)
        .toSet();

    expect(
      helperTitles,
      containsAll([
        'Build your own rhythm',
        'Your record gathers here',
        'Switch calendar views',
        'Month details',
        'Reveal the day card',
        'Control the experience',
        'Your community lives below',
      ]),
    );
    expect(
      helperBodies,
      containsAll([
        'Create personal flows for study, health, family, writing, business, or spiritual practice.',
        'Reflections, observed events, and journal badges will appear here over time.',
        'Tap ḥꜣw to toggle between the Kemetic calendar and the Gregorian calendar at any time.',
        'Tap the month or decan name for lore, structure, and meaning.',
        'Long press a day to reveal its card.',
        'Manage notifications, calendar preferences, profile settings, and privacy here.',
        'Scroll down to reveal the community feed, where shared flows and confirmations begin to gather.',
      ]),
    );
  });

  test('helper render path asserts registered IDs and debug source', () {
    final source = _read(
      'lib/features/onboarding/guided_onboarding_overlay.dart',
    );

    expect(source, contains('OnboardingHelperRegistry.isRegistered(helperId)'));
    expect(source, contains('debugLogHelperRender('));
    expect(source, contains('sourceWidget: sourceWidget'));
    expect(source, contains('helperUserId'));
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
