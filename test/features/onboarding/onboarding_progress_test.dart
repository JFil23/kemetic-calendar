import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/features/onboarding/onboarding_progress.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    OnboardingHelperCompletionService.resetForTesting(
      remoteStore: _FakeRemoteStore(),
    );
  });

  test('complete step marks onboarding complete', () {
    final progress = const OnboardingProgress().copyWith(
      currentStep: TrueOnboardingStep.complete,
    );

    expect(progress.completedOnboarding, isTrue);
    expect(progress.currentStep, TrueOnboardingStep.complete);
  });

  test('reflection decan onboarding gate fields persist locally', () {
    final progress = const OnboardingProgress().copyWith(
      reflectionSignupDecanIdentity: '2026:4:2',
      hasCrossedFirstDecanBoundary: true,
      firstReflectionEligibleDecanIdentity: '2026:4:3',
    );
    final restored = OnboardingProgress.fromJson(progress.toJson());

    expect(restored.reflectionSignupDecanIdentity, '2026:4:2');
    expect(restored.hasCrossedFirstDecanBoundary, isTrue);
    expect(restored.firstReflectionEligibleDecanIdentity, '2026:4:3');
  });

  test('profile basics require a glyph avatar and display name or handle', () {
    expect(
      hasCompletedProfileBasics(
        avatarGlyphIds: const ['glyph_a'],
        displayName: 'Jara',
        handle: null,
      ),
      isTrue,
    );
    expect(
      hasCompletedProfileBasics(
        avatarGlyphIds: const ['glyph_a'],
        displayName: null,
        handle: 'jara',
      ),
      isTrue,
    );
    expect(
      hasCompletedProfileBasics(
        avatarGlyphIds: const [],
        displayName: 'Jara',
        handle: 'jara',
      ),
      isFalse,
    );
    expect(
      hasCompletedProfileBasics(
        avatarGlyphIds: const ['glyph_a'],
        displayName: ' ',
        handle: null,
      ),
      isFalse,
    );
  });

  test('helper registry does not include a day view helper', () {
    expect(
      OnboardingHelperIds.all,
      isNot(contains(anyOf('dayView', 'dayViewHelper', 'dayViewReveal'))),
    );
  });

  test('each helper uses a stable registered helper ID', () {
    expect(
      OnboardingHelperIds.all,
      containsAll([
        OnboardingHelperIds.flowStudioAddFlow,
        OnboardingHelperIds.flowStudioSavedFlows,
        OnboardingHelperIds.flowStudioMaatFlows,
        OnboardingHelperIds.calendarToggle,
        OnboardingHelperIds.journalBadges,
        OnboardingHelperIds.settingsControl,
        OnboardingHelperIds.profileCommunityFeed,
      ]),
    );
    expect(OnboardingHelperIds.all, isNot(contains('flowBuilder')));
    for (final helperId in OnboardingHelperIds.all) {
      expect(
        helperId,
        matches(RegExp(r'^[a-z0-9]+(_[a-z0-9]+)*$')),
        reason: '$helperId must be a stable snake_case constant',
      );
      expect(OnboardingHelperIds.versions, contains(helperId));
      expect(
        OnboardingHelperIds.completionKeysFor(helperId),
        contains(helperId),
      );
    }

    expect(
      OnboardingHelperRegistry.all.map((helper) => helper.id).toSet(),
      OnboardingHelperIds.all,
    );
    expect(OnboardingHelperRegistry.byId.keys.toSet(), OnboardingHelperIds.all);
    for (final helper in OnboardingHelperRegistry.all) {
      expect(helper.title.trim(), isNotEmpty);
      expect(helper.body.trim(), isNotEmpty);
      expect(helper.analyticsEvent.trim(), startsWith('helper_seen_'));
      expect(helper.sourceWidget.trim(), isNotEmpty);
      expect(OnboardingHelperRegistry.isRegistered(helper.id), isTrue);
    }
  });

  test('storage persists progress per user', () async {
    final storage = OnboardingProgressStorage();
    final userAProgress = const OnboardingProgress().copyWith(
      hasChosenFirstMaatFlow: true,
      firstMaatFlowId: '42',
      currentStep: TrueOnboardingStep.firstFlowCalendarDay,
      seenHelpers: const {OnboardingHelperIds.calendarToggle},
    );

    await storage.save('user-a', userAProgress);

    expect(
      (await storage.load('user-a')).firstMaatFlowId,
      userAProgress.firstMaatFlowId,
    );
    expect(
      (await storage.load('user-a')).seenHelpers,
      contains(OnboardingHelperIds.calendarToggle),
    );
    expect((await storage.load('user-b')).firstMaatFlowId, isNull);
    expect((await storage.load('user-b')).seenHelpers, isEmpty);
  });

  test(
    'helper visibility is one-time for a completed onboarding user',
    () async {
      final storage = OnboardingProgressStorage();
      await storage.save(
        'user-a',
        const OnboardingProgress().copyWith(
          currentStep: TrueOnboardingStep.complete,
          completedOnboarding: true,
        ),
      );

      expect(
        await storage.shouldShowHelper(
          'user-a',
          OnboardingHelperIds.calendarToggle,
        ),
        isTrue,
      );

      await storage.markHelperCompleted(
        'user-a',
        OnboardingHelperIds.calendarToggle,
      );

      expect(
        await OnboardingProgressStorage().shouldShowHelper(
          'user-a',
          OnboardingHelperIds.calendarToggle,
        ),
        isFalse,
      );
    },
  );

  test(
    'helper completion is idempotent for repeated display and dismiss paths',
    () async {
      final storage = OnboardingProgressStorage();
      await storage.save(
        'user-a',
        const OnboardingProgress().copyWith(
          currentStep: TrueOnboardingStep.complete,
          completedOnboarding: true,
        ),
      );

      final first = await storage.markHelperCompleted(
        'user-a',
        OnboardingHelperIds.profileCommunityFeed,
      );
      final prefs = await SharedPreferences.getInstance();
      final rawAfterFirst = prefs.getString('onboarding_v2_progress:user-a');

      final second = await storage.markHelperCompleted(
        'user-a',
        OnboardingHelperIds.profileCommunityFeed,
      );

      expect(
        first.seenHelpers,
        contains(OnboardingHelperIds.profileCommunityFeed),
      );
      expect(
        second.seenHelpers,
        contains(OnboardingHelperIds.profileCommunityFeed),
      );
      expect(
        second.seenHelpers.where(
          (id) => id == OnboardingHelperIds.profileCommunityFeed,
        ),
        hasLength(1),
      );
      expect(prefs.getString('onboarding_v2_progress:user-a'), rawAfterFirst);
    },
  );

  test(
    'display-time helper completion keeps helpers hidden after remounts',
    () async {
      final storage = OnboardingProgressStorage();
      final completed = const OnboardingProgress().copyWith(
        currentStep: TrueOnboardingStep.complete,
        completedOnboarding: true,
      );

      final helperCases = <({String label, String id})>[
        (label: 'calendar helper', id: OnboardingHelperIds.calendarToggle),
        (label: 'journal helper', id: OnboardingHelperIds.journalBadges),
        (label: 'settings helper', id: OnboardingHelperIds.settingsControl),
        (
          label: 'Flow Studio Add Flow helper',
          id: OnboardingHelperIds.flowStudioAddFlow,
        ),
        (
          label: "Flow Studio Ma'at flows helper",
          id: OnboardingHelperIds.flowStudioMaatFlows,
        ),
        (
          label: 'profile community helper',
          id: OnboardingHelperIds.profileCommunityFeed,
        ),
      ];

      for (var i = 0; i < helperCases.length; i += 1) {
        final helper = helperCases[i];
        final userId = 'user-$i';
        await storage.save(userId, completed);
        expect(
          await storage.shouldShowHelper(userId, helper.id),
          isTrue,
          reason: '${helper.label} should be visible before display',
        );
        await storage.markHelperCompleted(userId, helper.id);
        expect(
          await OnboardingProgressStorage().shouldShowHelper(userId, helper.id),
          isFalse,
          reason: '${helper.label} should not repeat after remount',
        );
      }
    },
  );

  test('helpers do not show before onboarding is complete', () async {
    final storage = OnboardingProgressStorage();
    await storage.save('user-a', const OnboardingProgress());

    expect(
      await storage.shouldShowHelper(
        'user-a',
        OnboardingHelperIds.calendarToggle,
      ),
      isFalse,
    );
  });

  test('helper completion is scoped per user', () async {
    final storage = OnboardingProgressStorage();
    final completed = const OnboardingProgress().copyWith(
      currentStep: TrueOnboardingStep.complete,
      completedOnboarding: true,
    );
    await storage.save('user-a', completed);
    await storage.save('user-b', completed);

    await storage.markHelperCompleted(
      'user-a',
      OnboardingHelperIds.journalBadges,
    );

    expect(
      await storage.shouldShowHelper(
        'user-a',
        OnboardingHelperIds.journalBadges,
      ),
      isFalse,
    );
    expect(
      await storage.shouldShowHelper(
        'user-b',
        OnboardingHelperIds.journalBadges,
      ),
      isTrue,
    );
  });

  test('helper engagement merges with latest persisted helper state', () async {
    final storage = OnboardingProgressStorage();
    await storage.save(
      'user-a',
      const OnboardingProgress().copyWith(
        currentStep: TrueOnboardingStep.complete,
        completedOnboarding: true,
        seenHelpers: const {OnboardingHelperIds.calendarToggle},
      ),
    );

    await storage.markHelperCompleted(
      'user-a',
      OnboardingHelperIds.flowStudioAddFlow,
    );

    final reloaded = await OnboardingProgressStorage().load('user-a');
    expect(
      reloaded.seenHelpers,
      containsAll([
        OnboardingHelperIds.calendarToggle,
        OnboardingHelperIds.flowStudioAddFlow,
      ]),
    );
  });

  test('old local flowBuilder progress is respected', () async {
    final rawProgress = const OnboardingProgress()
        .copyWith(
          currentStep: TrueOnboardingStep.complete,
          completedOnboarding: true,
        )
        .toJson();
    rawProgress['seenHelpers'] = ['flowBuilder'];
    SharedPreferences.setMockInitialValues(<String, Object>{
      'onboarding_v2_progress:user-a': jsonEncode(rawProgress),
    });
    OnboardingHelperCompletionService.resetForTesting(
      remoteStore: _FakeRemoteStore(),
    );

    final storage = OnboardingProgressStorage();
    final reloaded = await storage.load('user-a');

    expect(
      reloaded.seenHelpers,
      containsAll([
        OnboardingHelperIds.flowStudioAddFlow,
        OnboardingHelperIds.flowStudioSavedFlows,
        OnboardingHelperIds.flowStudioMaatFlows,
      ]),
    );
    expect(
      await storage.shouldShowHelper(
        'user-a',
        OnboardingHelperIds.flowStudioAddFlow,
      ),
      isFalse,
    );
  });

  test('old local Journal helper progress is respected', () async {
    final rawProgress = const OnboardingProgress()
        .copyWith(
          currentStep: TrueOnboardingStep.complete,
          completedOnboarding: true,
        )
        .toJson();
    rawProgress['seenHelpers'] = ['journalBadges'];
    SharedPreferences.setMockInitialValues(<String, Object>{
      'onboarding_v2_progress:user-a': jsonEncode(rawProgress),
    });
    OnboardingHelperCompletionService.resetForTesting(
      remoteStore: _FakeRemoteStore(),
    );

    final storage = OnboardingProgressStorage();
    final reloaded = await storage.load('user-a');

    expect(
      reloaded.seenHelpers,
      contains(OnboardingHelperRegistry.journalBadges.id),
    );
    expect(
      await storage.shouldShowHelper(
        'user-a',
        OnboardingHelperRegistry.journalBadges.id,
      ),
      isFalse,
    );
  });

  test('old local Journal analytics/debug aliases are respected', () async {
    for (final oldId in [
      'journal_badges_helper',
      'helper_seen_journal_badges',
      'journal_record_badges',
    ]) {
      final rawProgress = const OnboardingProgress()
          .copyWith(
            currentStep: TrueOnboardingStep.complete,
            completedOnboarding: true,
          )
          .toJson();
      rawProgress['seenHelpers'] = [oldId];
      SharedPreferences.setMockInitialValues(<String, Object>{
        'onboarding_v2_progress:user-$oldId': jsonEncode(rawProgress),
      });
      OnboardingHelperCompletionService.resetForTesting(
        remoteStore: _FakeRemoteStore(),
      );

      final storage = OnboardingProgressStorage();
      expect(
        await storage.shouldShowHelper(
          'user-$oldId',
          OnboardingHelperRegistry.journalBadges.id,
        ),
        isFalse,
        reason: '$oldId should migrate to journal_badges',
      );
    }
  });

  test('concurrent helper completions merge without dropping ids', () async {
    final storage = OnboardingProgressStorage();
    await storage.save(
      'user-a',
      const OnboardingProgress().copyWith(
        currentStep: TrueOnboardingStep.complete,
        completedOnboarding: true,
      ),
    );

    await Future.wait([
      storage.markHelperCompleted('user-a', OnboardingHelperIds.calendarToggle),
      storage.markHelperCompleted(
        'user-a',
        OnboardingHelperIds.flowStudioAddFlow,
      ),
      storage.markHelperCompleted('user-a', OnboardingHelperIds.journalBadges),
    ]);

    final reloaded = await storage.load('user-a');
    expect(
      reloaded.seenHelpers,
      containsAll([
        OnboardingHelperIds.calendarToggle,
        OnboardingHelperIds.flowStudioAddFlow,
        OnboardingHelperIds.journalBadges,
      ]),
    );
  });

  test(
    'Flow Studio helper does not show before progress hydration completes',
    () async {
      final remoteCompleter = Completer<Set<String>>();
      final fakeRemote = _FakeRemoteStore(loadCompleter: remoteCompleter);
      OnboardingHelperCompletionService.resetForTesting(
        remoteStore: fakeRemote,
      );
      final storage = OnboardingProgressStorage();
      await storage.save(
        'user-a',
        const OnboardingProgress().copyWith(
          currentStep: TrueOnboardingStep.complete,
          completedOnboarding: true,
        ),
      );

      final service = OnboardingHelperCompletionService.instance;
      final hydration = service.hydrateUser('user-a');

      expect(
        service.hydrationStateFor('user-a'),
        OnboardingHelperHydrationState.loading,
      );
      expect(
        service.shouldShowHelperSync(
          'user-a',
          OnboardingHelperIds.flowStudioAddFlow,
        ),
        isFalse,
      );

      remoteCompleter.complete(const <String>{});
      await hydration;

      expect(
        service.shouldShowHelperSync(
          'user-a',
          OnboardingHelperIds.flowStudioAddFlow,
        ),
        isTrue,
      );
    },
  );

  test('Flow Studio helper disappears after Got it', () async {
    final storage = OnboardingProgressStorage();
    await storage.save(
      'user-a',
      const OnboardingProgress().copyWith(
        currentStep: TrueOnboardingStep.complete,
        completedOnboarding: true,
      ),
    );
    final service = OnboardingHelperCompletionService.instance;
    await service.hydrateUser('user-a');

    expect(
      service.shouldShowHelperSync(
        'user-a',
        OnboardingHelperIds.flowStudioAddFlow,
      ),
      isTrue,
    );

    final completion = service.markHelperCompleted(
      'user-a',
      OnboardingHelperIds.flowStudioAddFlow,
    );

    expect(
      service.isHelperCompletedSync(
        'user-a',
        OnboardingHelperIds.flowStudioAddFlow,
      ),
      isTrue,
    );
    expect(
      service.shouldShowHelperSync(
        'user-a',
        OnboardingHelperIds.flowStudioAddFlow,
      ),
      isFalse,
    );
    await completion;
  });

  test(
    'Journal record/badges helper does not show before progress hydration completes',
    () async {
      const helper = OnboardingHelperRegistry.journalBadges;
      final remoteCompleter = Completer<Set<String>>();
      final fakeRemote = _FakeRemoteStore(loadCompleter: remoteCompleter);
      OnboardingHelperCompletionService.resetForTesting(
        remoteStore: fakeRemote,
      );
      final storage = OnboardingProgressStorage();
      await storage.save(
        'user-a',
        const OnboardingProgress().copyWith(
          currentStep: TrueOnboardingStep.complete,
          completedOnboarding: true,
        ),
      );

      final service = OnboardingHelperCompletionService.instance;
      final hydration = service.hydrateUser('user-a');

      expect(
        service.hydrationStateFor('user-a'),
        OnboardingHelperHydrationState.loading,
      );
      expect(service.shouldShowHelperSync('user-a', helper.id), isFalse);

      remoteCompleter.complete(const <String>{});
      await hydration;

      expect(service.shouldShowHelperSync('user-a', helper.id), isTrue);
    },
  );

  test('Journal record/badges helper disappears after Got it', () async {
    const helper = OnboardingHelperRegistry.journalBadges;
    final storage = OnboardingProgressStorage();
    await storage.save(
      'user-a',
      const OnboardingProgress().copyWith(
        currentStep: TrueOnboardingStep.complete,
        completedOnboarding: true,
      ),
    );
    final service = OnboardingHelperCompletionService.instance;
    await service.hydrateUser('user-a');

    expect(service.shouldShowHelperSync('user-a', helper.id), isTrue);

    final displayedHelperId = helper.id;
    final gotItCompletionHelperId = helper.id;
    expect(gotItCompletionHelperId, displayedHelperId);

    final completion = service.markHelperCompleted(
      'user-a',
      gotItCompletionHelperId,
    );

    expect(service.isHelperCompletedSync('user-a', displayedHelperId), isTrue);
    expect(service.shouldShowHelperSync('user-a', displayedHelperId), isFalse);
    await completion;
  });

  test(
    'Journal record/badges helper does not return after navigating away/back',
    () async {
      const helper = OnboardingHelperRegistry.journalBadges;
      final storage = OnboardingProgressStorage();
      await storage.save(
        'user-a',
        const OnboardingProgress().copyWith(
          currentStep: TrueOnboardingStep.complete,
          completedOnboarding: true,
        ),
      );
      final service = OnboardingHelperCompletionService.instance;
      await service.hydrateUser('user-a');
      await service.markHelperCompleted('user-a', helper.id);

      expect(await service.shouldShowHelper('user-a', helper.id), isFalse);
    },
  );

  test(
    'Journal record/badges helper does not return after app restart with persisted local progress',
    () async {
      const helper = OnboardingHelperRegistry.journalBadges;
      final storage = OnboardingProgressStorage();
      await storage.save(
        'user-a',
        const OnboardingProgress().copyWith(
          currentStep: TrueOnboardingStep.complete,
          completedOnboarding: true,
        ),
      );
      await OnboardingHelperCompletionService.instance.markHelperCompleted(
        'user-a',
        helper.id,
      );

      OnboardingHelperCompletionService.resetForTesting(
        remoteStore: _FakeRemoteStore(),
      );

      expect(
        await OnboardingHelperCompletionService.instance.shouldShowHelper(
          'user-a',
          helper.id,
        ),
        isFalse,
      );
    },
  );

  test(
    'Flow Studio helper does not return after navigating away/back',
    () async {
      final storage = OnboardingProgressStorage();
      await storage.save(
        'user-a',
        const OnboardingProgress().copyWith(
          currentStep: TrueOnboardingStep.complete,
          completedOnboarding: true,
        ),
      );
      final service = OnboardingHelperCompletionService.instance;
      await service.hydrateUser('user-a');
      await service.markHelperCompleted(
        'user-a',
        OnboardingHelperIds.flowStudioAddFlow,
      );

      expect(
        await service.shouldShowHelper(
          'user-a',
          OnboardingHelperIds.flowStudioAddFlow,
        ),
        isFalse,
      );
    },
  );

  test(
    'Flow Studio helper does not return after app restart with persisted local progress',
    () async {
      final storage = OnboardingProgressStorage();
      await storage.save(
        'user-a',
        const OnboardingProgress().copyWith(
          currentStep: TrueOnboardingStep.complete,
          completedOnboarding: true,
        ),
      );
      await OnboardingHelperCompletionService.instance.markHelperCompleted(
        'user-a',
        OnboardingHelperIds.flowStudioAddFlow,
      );

      OnboardingHelperCompletionService.resetForTesting(
        remoteStore: _FakeRemoteStore(),
      );

      expect(
        await OnboardingHelperCompletionService.instance.shouldShowHelper(
          'user-a',
          OnboardingHelperIds.flowStudioAddFlow,
        ),
        isFalse,
      );
    },
  );

  test(
    'Flow Studio helper stays completed across navigation and service recreation',
    () async {
      final storage = OnboardingProgressStorage();
      await storage.save(
        'user-a',
        const OnboardingProgress().copyWith(
          currentStep: TrueOnboardingStep.complete,
          completedOnboarding: true,
        ),
      );

      var service = OnboardingHelperCompletionService.instance;
      await service.hydrateUser('user-a');
      expect(
        service.shouldShowHelperSync(
          'user-a',
          OnboardingHelperIds.flowStudioAddFlow,
        ),
        isTrue,
      );

      final gotItCompletion = service.markHelperCompleted(
        'user-a',
        OnboardingHelperIds.flowStudioAddFlow,
      );
      expect(
        service.shouldShowHelperSync(
          'user-a',
          OnboardingHelperIds.flowStudioAddFlow,
        ),
        isFalse,
      );
      await gotItCompletion;

      expect(
        await service.shouldShowHelper(
          'user-a',
          OnboardingHelperIds.flowStudioAddFlow,
        ),
        isFalse,
        reason: 'navigation away/back should not re-arm the helper',
      );

      OnboardingHelperCompletionService.resetForTesting(
        remoteStore: _FakeRemoteStore(),
      );
      service = OnboardingHelperCompletionService.instance;

      expect(
        await service.shouldShowHelper(
          'user-a',
          OnboardingHelperIds.flowStudioAddFlow,
        ),
        isFalse,
        reason: 'service restart must restore persisted local completion',
      );
    },
  );

  test(
    'target engagement marks Flow Studio Add Flow helper complete',
    () async {
      final storage = OnboardingProgressStorage();
      await storage.save(
        'user-a',
        const OnboardingProgress().copyWith(
          currentStep: TrueOnboardingStep.complete,
          completedOnboarding: true,
        ),
      );
      final service = OnboardingHelperCompletionService.instance;
      await service.hydrateUser('user-a');

      final completion = service.markHelperCompleted(
        'user-a',
        OnboardingHelperIds.flowStudioAddFlow,
      );

      expect(
        service.shouldShowHelperSync(
          'user-a',
          OnboardingHelperIds.flowStudioAddFlow,
        ),
        isFalse,
      );
      await completion;
    },
  );

  test(
    'cloud persistence restores completed helpers for same user on fresh local install',
    () async {
      final fakeRemote = _FakeRemoteStore(
        completedByUser: {
          'user-a': {OnboardingHelperIds.flowStudioAddFlow},
        },
      );
      OnboardingHelperCompletionService.resetForTesting(
        remoteStore: fakeRemote,
      );
      final storage = OnboardingProgressStorage();
      await storage.save(
        'user-a',
        const OnboardingProgress().copyWith(
          currentStep: TrueOnboardingStep.complete,
          completedOnboarding: true,
        ),
      );

      expect(
        await OnboardingHelperCompletionService.instance.shouldShowHelper(
          'user-a',
          OnboardingHelperIds.flowStudioAddFlow,
        ),
        isFalse,
      );
      expect(
        (await storage.load('user-a')).seenHelpers,
        contains(OnboardingHelperIds.flowStudioAddFlow),
      );
    },
  );

  test(
    'helper render debug snapshot reports local and cloud completion',
    () async {
      const helper = OnboardingHelperRegistry.journalBadges;
      final fakeRemote = _FakeRemoteStore(
        completedByUser: {
          'user-a': {helper.id},
        },
      );
      OnboardingHelperCompletionService.resetForTesting(
        remoteStore: fakeRemote,
      );
      final storage = OnboardingProgressStorage();
      await storage.save(
        'user-a',
        const OnboardingProgress().copyWith(
          currentStep: TrueOnboardingStep.complete,
          completedOnboarding: true,
        ),
      );

      final service = OnboardingHelperCompletionService.instance;
      await service.hydrateUser('user-a');
      final snapshot = service.debugSnapshot('user-a', helper.id);

      expect(snapshot.helperId, helper.id);
      expect(snapshot.userId, 'user-a');
      expect(snapshot.hydrationState, OnboardingHelperHydrationState.ready);
      expect(snapshot.completedCloud, isTrue);
      expect(snapshot.completedLocal, isTrue);
    },
  );

  test(
    'helper completed during onboarding stays hidden after completion',
    () async {
      final storage = OnboardingProgressStorage();
      await storage.markHelperCompleted(
        'user-a',
        OnboardingHelperIds.dayCardLongPress,
      );

      await storage.update(
        'user-a',
        (progress) => progress.copyWith(
          currentStep: TrueOnboardingStep.complete,
          completedOnboarding: true,
        ),
      );

      expect(
        await storage.shouldShowHelper(
          'user-a',
          OnboardingHelperIds.dayCardLongPress,
        ),
        isFalse,
      );
    },
  );

  testWidgets(
    'Journal-style helper hydration does not notify listeners during build',
    (tester) async {
      final storage = OnboardingProgressStorage();
      await storage.save(
        'user-a',
        const OnboardingProgress().copyWith(
          currentStep: TrueOnboardingStep.complete,
          completedOnboarding: true,
        ),
      );
      OnboardingHelperCompletionService.resetForTesting(
        remoteStore: _FakeRemoteStore(),
      );

      await tester.pumpWidget(
        _HydrateDuringBuildHarness(
          service: OnboardingHelperCompletionService.instance,
        ),
      );
      expect(tester.takeException(), isNull);

      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('notifications='), findsOneWidget);
    },
  );
}

class _HydrateDuringBuildHarness extends StatefulWidget {
  const _HydrateDuringBuildHarness({required this.service});

  final OnboardingHelperCompletionService service;

  @override
  State<_HydrateDuringBuildHarness> createState() =>
      _HydrateDuringBuildHarnessState();
}

class _HydrateDuringBuildHarnessState
    extends State<_HydrateDuringBuildHarness> {
  var _notifications = 0;
  var _started = false;

  @override
  void initState() {
    super.initState();
    widget.service.addListener(_handleServiceChanged);
  }

  @override
  void dispose() {
    widget.service.removeListener(_handleServiceChanged);
    super.dispose();
  }

  void _handleServiceChanged() {
    setState(() {
      _notifications += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_started) {
      _started = true;
      unawaited(widget.service.hydrateUser('user-a'));
    }
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text('notifications=$_notifications'),
    );
  }
}

class _FakeRemoteStore implements OnboardingHelperCompletionRemoteStore {
  _FakeRemoteStore({
    Map<String, Set<String>> completedByUser = const <String, Set<String>>{},
    this.loadCompleter,
  }) : completedByUser = {
         for (final entry in completedByUser.entries)
           entry.key: OnboardingHelperIds.normalizeCompletedHelperKeys(
             entry.value,
           ),
       };

  final Map<String, Set<String>> completedByUser;
  final Completer<Set<String>>? loadCompleter;

  @override
  Future<Set<String>> loadCompletedHelperKeys(String userId) async {
    if (loadCompleter != null) {
      return loadCompleter!.future;
    }
    return completedByUser[userId] ?? const <String>{};
  }

  @override
  Future<void> markCompleted(
    String userId,
    Iterable<String> completionKeys,
  ) async {
    final existing = completedByUser.putIfAbsent(userId, () => <String>{});
    existing.addAll(
      OnboardingHelperIds.normalizeCompletedHelperKeys(completionKeys),
    );
  }
}
