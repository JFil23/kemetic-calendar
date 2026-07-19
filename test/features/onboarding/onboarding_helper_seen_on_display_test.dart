import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/onboarding/onboarding_progress.dart';

void main() {
  test("Flow Studio Ma'at helper uses a stable ID and dismiss gate", () {
    final fullSource = _read('lib/features/calendar/calendar_flow_pages.dart');
    final stateSource = _between(
      fullSource,
      'class _FlowHubPageState extends State<_FlowHubPage>',
      '  @override\n  Widget build',
    );
    final initStateSource = _between(
      stateSource,
      '  void initState()',
      '  void _scheduleFlowStudioMaatFlowsHelper()',
    );
    final scheduleSource = _between(
      stateSource,
      '  void _scheduleFlowStudioMaatFlowsHelper()',
      '  Future<void> _maybeShowFlowStudioMaatFlowsHelper()',
    );
    final source = _between(
      fullSource,
      'Future<void> _maybeShowFlowStudioMaatFlowsHelper',
      '  Future<void> _markFlowStudioHelperCompleted',
    );
    final registryIndex = source.indexOf(
      'const helper = OnboardingHelperRegistry.flowStudioMaatFlows',
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
    expect(initStateSource, contains('_scheduleFlowStudioMaatFlowsHelper();'));
    expect(
      initStateSource,
      isNot(contains('unawaited(_maybeShowFlowStudioMaatFlowsHelper())')),
    );
    expect(stateSource, contains('bool _helperPromptScheduled = false;'));
    expect(scheduleSource, contains('if (_helperPromptScheduled) return;'));
    expect(scheduleSource, contains('_helperPromptScheduled = true;'));
    expect(
      scheduleSource,
      contains('WidgetsBinding.instance.addPostFrameCallback((_) {'),
    );
    expect(scheduleSource, contains('if (!mounted) return;'));
    expect(
      scheduleSource,
      contains('unawaited(_maybeShowFlowStudioMaatFlowsHelper());'),
    );
    expect(source, isNot(contains('OnboardingHelperIds.flowBuilder')));
    expect(source, isNot(contains('flowStudioAddFlow')));
    expect(source, contains('helper.analyticsEvent'));
    expect(
      source,
      contains(
        'sourceWidget: OnboardingHelperRegistry.flowHubPageMaatFlowsSourceWidget',
      ),
    );
    expect(fullSource, contains('key: _maatFlowsHelperKey'));
    expect(fullSource, isNot(contains('key: _addFlowHelperKey')));
  });

  test("Ma'at flow list does not show an Add Flow first-run helper", () {
    final source = _between(
      _read('lib/features/calendar/calendar_maat_flows.dart'),
      'class _MaatFlowsListPageState extends State<_MaatFlowsListPage>',
      '  Future<void> _markFlowStudioHelperCompleted',
    );

    expect(source, isNot(contains('GuidedOnboardingController.instance.show')));
    expect(
      source,
      isNot(contains('OnboardingHelperRegistry.flowStudioAddFlow')),
    );
    expect(source, isNot(contains('Build your own rhythm')));
  });

  test(
    'Journal observed-events helper uses accepted copy and completion gate',
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
      expect(
        OnboardingHelperRegistry.journalBadges.title,
        'Observed events will appear here',
      );
      expect(
        OnboardingHelperRegistry.journalBadges.body,
        'Observed events are added to your ledger.',
      );
    },
  );

  test('calendar menuExplore helper targets the visible menu bubble', () {
    final calendarSource = _between(
      _read('lib/features/calendar/calendar_page.dart'),
      '  void _showMenuExploreCoachmark()',
      '  Future<void> _completeTrueOnboarding()',
    );
    final mainSource = _read('lib/main.dart');

    expect(
      calendarSource,
      contains('const helper = OnboardingHelperRegistry.calendarMenuExplore'),
    );
    expect(calendarSource, contains('key: globalMenuButtonKey'));
    expect(calendarSource, contains('_waitForCoachmarkTargetReady'));
    expect(calendarSource, contains('variant: CoachmarkVariant.helperBubble'));
    expect(calendarSource, contains('allowBackgroundInteraction: true'));
    expect(calendarSource, contains('externalOverlaySuppressed: false'));
    expect(calendarSource, contains('helperId: helper.id'));
    expect(calendarSource, contains('sourceWidget: helper.sourceWidget'));
    expect(calendarSource, contains('showWhenHelperCompleted: true'));
    expect(
      mainSource,
      contains(
        'activeHelper?.helperId == OnboardingHelperIds.calendarMenuExplore',
      ),
    );
    expect(mainSource, contains('showingMenuExploreHelper'));
    expect(
      OnboardingHelperRegistry.calendarMenuExplore.title,
      'Tap to explore',
    );
    expect(
      OnboardingHelperRegistry.calendarMenuExplore.body,
      'Create with flows, journal, planner, and tools.',
    );
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
    expect(
      OnboardingHelperRegistry.profileCommunityFeed.body,
      'Scroll down for shared flows and confirmations.',
    );
  });

  test('PWA review profile route can show the community helper signed out', () {
    final mainSource = _read('lib/main.dart');
    final profileSource = _read('lib/features/profile/profile_page.dart');

    expect(mainSource, contains('final useReviewProfile ='));
    expect(mainSource, contains('onboardingReviewSessionRequested'));
    expect(mainSource, contains('kOnboardingReviewHelperUserId'));
    expect(mainSource, contains('isMyProfile:'));
    expect(mainSource, contains('useReviewProfile ||'));

    expect(
      profileSource,
      contains('widget.userId == kOnboardingReviewHelperUserId'),
    );
    expect(profileSource, contains("handle: 'review'"));
    expect(profileSource, contains("displayName: 'Review Profile'"));
    expect(profileSource, contains('_maybeShowProfileCommunityHelper();'));
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
        'Tap to explore',
        'Start with Ma’at',
        'Observed events will appear here',
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
        'Create with flows, journal, planner, and tools.',
        'Choose a guided rhythm, ḥꜣw carries it into your calendar.',
        'Observed events are added to your ledger.',
        'Tap ḥꜣw to toggle between the Kemetic calendar and the Gregorian calendar at any time.',
        'Tap the month or decan name for lore, structure, and meaning.',
        'Long press a day to reveal its card.',
        'Manage notifications, calendar preferences, profile settings, and privacy here.',
        'Scroll down for shared flows and confirmations.',
      ]),
    );
    expect(helperTitles, isNot(contains('Build your own rhythm')));
    expect(
      helperBodies,
      isNot(
        contains(
          'Create personal flows for study, health, family, writing, business, or spiritual practice.',
        ),
      ),
    );
  });

  test('quiet first-run sections do not define helper bubbles', () {
    final quietSources = <String, String>{
      'planner': _read('lib/features/rhythm/pages/todays_alignment_page.dart'),
      'library': _read('lib/features/nodes/kemetic_node_list_page.dart'),
      'inbox': _read('lib/features/inbox/inbox_page.dart'),
      'reflections': _read(
        'lib/features/reflections/decan_reflection_archive_page.dart',
      ),
    };

    for (final entry in quietSources.entries) {
      expect(
        entry.value,
        isNot(contains('CoachmarkVariant.helperBubble')),
        reason: '${entry.key} should remain quiet during first-run helpers.',
      );
      expect(
        entry.value,
        isNot(contains('OnboardingHelperRegistry.')),
        reason: '${entry.key} should not register a first-run helper.',
      );
    }
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
