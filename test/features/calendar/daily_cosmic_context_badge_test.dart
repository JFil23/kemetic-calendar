import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/calendar/daily_cosmic_context_badge.dart';
import 'package:mobile/features/calendar/track_sky_flow.dart';
import 'package:mobile/features/settings/settings_prefs.dart';
import 'package:mobile/widgets/kemetic_day_info.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

const _userId = 'daily-cosmic-user';
final _firstDay = DateTime(2026, 6, 9);
final _nextDay = DateTime(2026, 6, 10);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
  });

  test('first open of day shows badge once and records today', () async {
    final controller = DailyCosmicContextController(now: () => _firstDay);

    await controller.evaluate(
      userId: _userId,
      isAuthenticated: true,
      onboardingComplete: true,
      suppressed: false,
    );

    expect(controller.current, isNotNull);
    expect(controller.current!.gregorianDateKey, '2026-06-09');

    final prefs = await SharedPreferences.getInstance();
    final markerKey = DailyCosmicContextPrefs.lastShownGregorianDateKeyForUser(
      _userId,
    );
    expect(prefs.getString(markerKey), isNull);
    await controller.recordVisiblePresentation(controller.current!);
    expect(prefs.getString(markerKey), '2026-06-09');
    expect(
      DailyCosmicContextPrefs.lastShownGregorianDateKeyForUser(_userId),
      'daily_cosmic_context:last_shown_gregorian_date:$_userId',
    );
    expect(
      prefs
          .getKeys()
          .where((key) => key.contains('daily_cosmic_context'))
          .map(prefs.get)
          .whereType<String>(),
      everyElement(matches(RegExp(r'^\d{4}-\d{2}-\d{2}$'))),
      reason: 'The daily marker should store only a Gregorian date.',
    );

    await controller.evaluate(
      userId: _userId,
      isAuthenticated: true,
      onboardingComplete: true,
      suppressed: false,
    );

    expect(
      controller.current,
      isNotNull,
      reason: 'A duplicate same-frame evaluation should not hide the badge.',
    );
  });

  test('cosmic context resolves from current Kemetic day data source', () {
    final badge = dailyCosmicContextBadgeForDate(_firstDay);

    expect(badge, isNotNull);
    final info = KemeticDayData.getInfoForDay(badge!.dayKey);
    expect(info, isNotNull);
    expect(badge.cosmicContext, info!.cosmicContext.trim());
  });

  test(
    'onboarding badge duplicate requests collapse to one presentation',
    () async {
      final controller = DailyCosmicContextController(now: () => _firstDay);
      addTearDown(controller.dispose);
      final badge = dailyCosmicContextBadgeForDate(_firstDay)!;
      var dismissCount = 0;

      expect(
        controller.showOnboardingBadge(
          badge,
          onDismissed: () {
            dismissCount += 1;
          },
        ),
        isTrue,
      );
      expect(
        controller.showOnboardingBadge(
          badge,
          onDismissed: () {
            dismissCount += 1;
          },
        ),
        isFalse,
      );
      expect(controller.current, same(badge));

      await controller.dismiss();
      expect(dismissCount, 1);
    },
  );

  test(
    'shown marker stores only the date and never the context body',
    () async {
      const editedCopy = 'Edited live copy that should never be persisted.';
      final controller = DailyCosmicContextController(
        now: () => _firstDay,
        badgeForDate: (date) => _testBadge(date, cosmicContext: editedCopy),
      );

      await controller.evaluate(
        userId: _userId,
        isAuthenticated: true,
        onboardingComplete: true,
        suppressed: false,
      );

      final prefs = await SharedPreferences.getInstance();
      final markerKey =
          DailyCosmicContextPrefs.lastShownGregorianDateKeyForUser(_userId);
      expect(prefs.getString(markerKey), isNull);
      await controller.recordVisiblePresentation(controller.current!);
      expect(prefs.getString(markerKey), '2026-06-09');
      expect(prefs.getString(markerKey), isNot(contains(editedCopy)));
      expect(
        prefs
            .getKeys()
            .where((key) => key.contains('daily_cosmic_context'))
            .map(prefs.get)
            .whereType<String>(),
        isNot(contains(editedCopy)),
      );
    },
  );

  test(
    'copy edited before first show is displayed from the live source',
    () async {
      var liveCopy = 'Original copy before edit.';
      final controller = DailyCosmicContextController(
        now: () => _firstDay,
        badgeForDate: (date) => _testBadge(date, cosmicContext: liveCopy),
      );

      liveCopy = 'Updated copy before the user sees the badge.';
      await controller.evaluate(
        userId: _userId,
        isAuthenticated: true,
        onboardingComplete: true,
        suppressed: false,
      );

      expect(controller.current, isNotNull);
      expect(controller.current!.cosmicContext, liveCopy);
    },
  );

  test(
    'copy edited after dismiss does not reset same-day visibility',
    () async {
      var liveCopy = 'Copy shown before dismiss.';
      var resolveCount = 0;
      final controller = DailyCosmicContextController(
        now: () => _firstDay,
        badgeForDate: (date) {
          resolveCount += 1;
          return _testBadge(date, cosmicContext: liveCopy);
        },
      );

      await controller.evaluate(
        userId: _userId,
        isAuthenticated: true,
        onboardingComplete: true,
        suppressed: false,
      );
      expect(controller.current!.cosmicContext, liveCopy);

      await controller.dismiss();
      liveCopy = 'Edited copy after dismiss should wait until tomorrow.';
      await controller.evaluate(
        userId: _userId,
        isAuthenticated: true,
        onboardingComplete: true,
        suppressed: false,
      );

      expect(controller.current, isNull);
      expect(resolveCount, 1);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(
          DailyCosmicContextPrefs.lastShownGregorianDateKeyForUser(_userId),
        ),
        '2026-06-09',
      );
    },
  );

  test(
    'missing or empty cosmic context suppresses badge without marker',
    () async {
      expect(
        dailyCosmicContextBadgeForDate(_firstDay, infoForDay: (_) => null),
        isNull,
      );
      expect(
        dailyCosmicContextBadgeForDate(
          _firstDay,
          infoForDay: (_) => _testDayInfo(cosmicContext: '   '),
        ),
        isNull,
      );

      final controller = DailyCosmicContextController(
        now: () => _firstDay,
        badgeForDate: (_) => null,
      );

      await expectLater(
        controller.evaluate(
          userId: _userId,
          isAuthenticated: true,
          onboardingComplete: true,
          suppressed: false,
        ),
        completes,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(controller.current, isNull);
      expect(
        prefs.getString(
          DailyCosmicContextPrefs.lastShownGregorianDateKeyForUser(_userId),
        ),
        isNull,
      );
    },
  );

  test('dismiss prevents repeat on the same day', () async {
    final controller = DailyCosmicContextController(now: () => _firstDay);

    await controller.evaluate(
      userId: _userId,
      isAuthenticated: true,
      onboardingComplete: true,
      suppressed: false,
    );
    await controller.dismiss();

    expect(controller.current, isNull);

    await controller.evaluate(
      userId: _userId,
      isAuthenticated: true,
      onboardingComplete: true,
      suppressed: false,
    );

    expect(controller.current, isNull);
  });

  test('next day can show again', () async {
    var now = _firstDay;
    final controller = DailyCosmicContextController(now: () => now);

    await controller.evaluate(
      userId: _userId,
      isAuthenticated: true,
      onboardingComplete: true,
      suppressed: false,
    );
    await controller.dismiss();

    now = _nextDay;
    await controller.evaluate(
      userId: _userId,
      isAuthenticated: true,
      onboardingComplete: true,
      suppressed: false,
    );

    expect(controller.current, isNotNull);
    expect(controller.current!.gregorianDateKey, '2026-06-10');
  });

  test('missed days do not stack and only current day appears', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      DailyCosmicContextPrefs.lastShownGregorianDateKeyForUser(_userId),
      '2026-06-01',
    );
    final controller = DailyCosmicContextController(now: () => _firstDay);

    await controller.evaluate(
      userId: _userId,
      isAuthenticated: true,
      onboardingComplete: true,
      suppressed: false,
    );

    expect(controller.current, isNotNull);
    expect(controller.current!.gregorianDateKey, '2026-06-09');
  });

  test('setting off suppresses badge', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SettingsPrefs.dailyCosmicContextBadgeEnabledKey, false);
    final controller = DailyCosmicContextController(now: () => _firstDay);

    await controller.evaluate(
      userId: _userId,
      isAuthenticated: true,
      onboardingComplete: true,
      suppressed: false,
    );

    expect(controller.current, isNull);
  });

  test('auth onboarding and recovery/setup gates suppress badge', () async {
    final controller = DailyCosmicContextController(now: () => _firstDay);

    await controller.evaluate(
      userId: _userId,
      isAuthenticated: false,
      onboardingComplete: true,
      suppressed: false,
    );
    expect(controller.current, isNull);

    await controller.evaluate(
      userId: _userId,
      isAuthenticated: true,
      onboardingComplete: false,
      suppressed: false,
    );
    expect(controller.current, isNull);

    await controller.evaluate(
      userId: _userId,
      isAuthenticated: true,
      onboardingComplete: true,
      suppressed: true,
    );
    expect(controller.current, isNull);

    expect(
      isDailyCosmicContextRouteSuppressed(
        Uri.parse('/profile/me/edit?requireCompletion=1&onboarding=1'),
      ),
      isTrue,
    );
    expect(
      isDailyCosmicContextRouteSuppressed(Uri.parse('/password-recovery')),
      isTrue,
    );
  });

  test('normal restored non-calendar routes are not route-suppressed', () {
    expect(isDailyCosmicContextRouteSuppressed(Uri.parse('/nodes')), isFalse);
    expect(isDailyCosmicContextRouteSuppressed(Uri.parse('/flows')), isFalse);
    expect(
      isDailyCosmicContextRouteSuppressed(Uri.parse('/calendars')),
      isFalse,
    );
    expect(
      isDailyCosmicContextRouteSuppressed(Uri.parse('/rhythm/editor/timed')),
      isFalse,
    );
    expect(
      isDailyCosmicContextRouteSuppressed(Uri.parse('/profile/me')),
      isFalse,
    );
  });

  testWidgets(
    'pending daily rhythm is not consumed until visible presentation',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var resolveCount = 0;
      final controller = DailyCosmicContextController(
        now: () => _firstDay,
        badgeForDate: (date) {
          resolveCount += 1;
          return _testBadge(
            date,
            cosmicContext: 'Today asks for visible rhythm.',
          );
        },
      );
      addTearDown(controller.dispose);

      final prefs = await SharedPreferences.getInstance();
      final markerKey =
          DailyCosmicContextPrefs.lastShownGregorianDateKeyForUser(_userId);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: [
                const Text('Restored page'),
                DailyCosmicContextOverlayHost(controller: controller),
              ],
            ),
          ),
        ),
      );

      await controller.evaluate(
        userId: _userId,
        isAuthenticated: true,
        onboardingComplete: true,
        suppressed: false,
      );

      expect(controller.current, isNotNull);
      expect(prefs.getString(markerKey), isNull);

      await controller.evaluate(
        userId: _userId,
        isAuthenticated: true,
        onboardingComplete: true,
        suppressed: true,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 260));

      expect(controller.current, isNull);
      expect(find.byKey(dailyCosmicContextOverlayKey), findsNothing);
      expect(prefs.getString(markerKey), isNull);

      await controller.evaluate(
        userId: _userId,
        isAuthenticated: true,
        onboardingComplete: true,
        suppressed: false,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 260));

      expect(find.byKey(dailyCosmicContextOverlayKey), findsOneWidget);
      expect(find.text('The Day’s Rhythm'), findsOneWidget);
      expect(prefs.getString(markerKey), '2026-06-09');

      await tester.tap(find.byKey(dailyCosmicContextDismissButtonKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 260));
      expect(find.byKey(dailyCosmicContextOverlayKey), findsNothing);

      await controller.evaluate(
        userId: _userId,
        isAuthenticated: true,
        onboardingComplete: true,
        suppressed: false,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 260));

      expect(find.byKey(dailyCosmicContextOverlayKey), findsNothing);
      expect(resolveCount, 2);
      expect(prefs.getString(markerKey), '2026-06-09');
    },
  );

  testWidgets(
    'overlay presents rhythm title kemetic-first metadata and hides deck label',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = DailyCosmicContextController(
        now: () => _firstDay,
        badgeForDate: (date) => _testBadge(
          date,
          gregorianDateLabel: 'June 9, 2026',
          kemeticDate: 'Hathor III, Day 22',
          decanName: 'ḳdty (translation uncertain) | Deck: The Builders',
          cosmicContext: 'A readable rhythm for today.',
        ),
      );
      await controller.evaluate(
        userId: _userId,
        isAuthenticated: true,
        onboardingComplete: true,
        suppressed: false,
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: [
                const Text('Restored page'),
                DailyCosmicContextOverlayHost(controller: controller),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 260));

      expect(find.text('The Day’s Rhythm'), findsOneWidget);
      expect(find.text('Cosmic Context'), findsNothing);
      expect(find.text('Hathor III, Day 22 | June 9, 2026'), findsOneWidget);
      expect(find.text('June 9, 2026 | Hathor III, Day 22'), findsNothing);
      expect(find.text('ḳdty (translation uncertain)'), findsOneWidget);
      expect(find.textContaining('Deck:'), findsNothing);
    },
  );

  testWidgets('long rhythm text scrolls inside badge without overflowing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final longRhythm = List<String>.filled(
      80,
      'Long rhythm text remains readable inside the floating badge.',
    ).join('\n');
    final controller = DailyCosmicContextController(
      now: () => _firstDay,
      badgeForDate: (date) => _testBadge(date, cosmicContext: longRhythm),
    );
    await controller.evaluate(
      userId: _userId,
      isAuthenticated: true,
      onboardingComplete: true,
      suppressed: false,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              const Text('Restored page'),
              DailyCosmicContextOverlayHost(controller: controller),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));

    expect(tester.takeException(), isNull);
    expect(find.text('The Day’s Rhythm'), findsOneWidget);
    expect(find.byKey(dailyCosmicContextDismissButtonKey), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });

  testWidgets(
    'overlay appears over restored non-calendar route without changing route',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = DailyCosmicContextController(now: () => _firstDay);
      await controller.evaluate(
        userId: _userId,
        isAuthenticated: true,
        onboardingComplete: true,
        suppressed: false,
      );
      addTearDown(controller.dispose);

      final router = GoRouter(
        initialLocation: '/nodes',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                const Scaffold(body: Text('Calendar route')),
          ),
          GoRoute(
            path: '/nodes',
            builder: (context, state) =>
                const Scaffold(body: Text('Nodes route')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => Stack(
            fit: StackFit.expand,
            children: [
              child ?? const SizedBox.shrink(),
              DailyCosmicContextOverlayHost(controller: controller),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 260));

      expect(find.text('Nodes route'), findsOneWidget);
      expect(find.byKey(dailyCosmicContextOverlayKey), findsOneWidget);
      expect(router.routerDelegate.currentConfiguration.uri.path, '/nodes');

      await tester.tap(find.byKey(dailyCosmicContextDismissButtonKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byKey(dailyCosmicContextOverlayKey), findsNothing);
      expect(router.routerDelegate.currentConfiguration.uri.path, '/nodes');
    },
  );

  test('password recovery stays outside authed chrome shell', () async {
    final source = await File('lib/main.dart').readAsString();
    final myAppState = _sourceBetween(
      source,
      'class _MyAppState extends State<MyApp>',
      'class _AppChrome extends StatefulWidget',
    );
    final build = _sourceBetween(
      myAppState,
      'Widget build(BuildContext context) {',
      '\n  }\n}',
    );
    final normalRuntimeStart = build.indexOf(
      'final signedIn = supabase.auth.currentSession != null;',
    );
    expect(
      normalRuntimeStart,
      isNonNegative,
      reason: 'Missing normal runtime signed-in branch.',
    );
    final normalRuntimeBuild = build.substring(normalRuntimeStart);
    final recoveryApp = _sourceBetween(
      myAppState,
      'Widget _buildPasswordRecoveryApp()',
      'Widget _buildAuthedApp()',
    );
    final authedApp = _sourceBetween(
      myAppState,
      'Widget _buildAuthedApp()',
      '@override\n  Widget build(BuildContext context)',
    );

    expect(
      build,
      contains('if (_debugDaySheetSmokeBootRequested)'),
      reason:
          'The debug Day Sheet smoke route is allowed to boot authed chrome before normal runtime routing.',
    );
    expect(
      normalRuntimeBuild,
      contains('if (signedIn && _passwordRecoverySession)'),
    );
    expect(
      normalRuntimeBuild.indexOf('_buildPasswordRecoveryApp()'),
      lessThan(normalRuntimeBuild.indexOf('_buildAuthedApp()')),
      reason:
          'In normal runtime, a signed-in password recovery session must bypass the authed chrome shell.',
    );
    expect(recoveryApp, contains('home: PasswordRecoveryScreen('));
    expect(recoveryApp, isNot(contains('_AppChrome(')));
    expect(recoveryApp, isNot(contains('MaterialApp.router')));
    expect(authedApp, contains('_AppChrome('));
  });

  test(
    'global shell back button dismisses badge before route handling',
    () async {
      final source = await File('lib/main.dart').readAsString();
      final handleBackButton = _sourceBetween(
        source,
        'Future<bool> _handleBackButton() async {',
        '\n  }\n\n  @override\n  Widget build',
      );

      expect(
        handleBackButton,
        contains('_dailyCosmicContextController.hasVisibleBadge'),
      );
      expect(
        handleBackButton.indexOf('_dailyCosmicContextController.dismiss()'),
        lessThan(handleBackButton.indexOf('if (_menuMounted && _menuOpen)')),
      );
      expect(
        handleBackButton.indexOf('_dailyCosmicContextController.dismiss()'),
        lessThan(handleBackButton.indexOf('_shouldOpenDrawerForBack(context)')),
      );
    },
  );

  test('global daily context waits for completed onboarding handoff', () async {
    final source = await File('lib/main.dart').readAsString();
    final completionGate = _sourceBetween(
      source,
      'Future<bool> _dailyCosmicContextOnboardingComplete(String userId) async {',
      'void _resetFloatingMenuStateAfterFrame()',
    );
    final progressSource = await File(
      'lib/features/onboarding/onboarding_progress.dart',
    ).readAsString();
    final handoffGate = _sourceBetween(
      progressSource,
      'bool shouldAllowDailyCosmicContextAfterOnboardingHandoff({',
      'class OnboardingProgressStorage',
    );

    expect(handoffGate, contains('progress.hasSeenMenuPrompt'));
    expect(
      handoffGate,
      contains('progress.currentStep == TrueOnboardingStep.complete'),
    );
    expect(handoffGate, contains('onboardingSatisfiedDayRhythmIdentity'));
    expect(handoffGate, contains('compareTo(normalizedToday) >= 0'));
    expect(
      handoffGate,
      contains('shouldAllowDailyCosmicContextAfterOnboardingHandoff'),
    );
    expect(
      completionGate,
      contains('loadLocalReconciledWithLegacyCompletion('),
    );
    expect(
      completionGate,
      contains('shouldAllowDailyCosmicContextAfterOnboardingHandoff'),
    );
    expect(
      completionGate.indexOf('loadLocalReconciledWithLegacyCompletion('),
      lessThan(completionGate.indexOf('isCompletedLocally(userId)')),
      reason:
          'The global Rhythm gate must consume legacy completion through the '
          'v2 reconciliation boundary before evaluating surfaces.',
    );
    expect(completionGate, isNot(contains('loadLocalIfPresent(')));
    expect(completionGate, isNot(contains('progress.firstMaatFlowEventDate')));
  });

  test('onboarding Day Rhythm dismissal marks identity satisfied', () async {
    final source = await File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsString();
    final showMethod = _sourceBetween(
      source,
      'Future<void> _showOnboardingDayRhythm() async {',
      'Future<void> _handleOnboardingDayRhythmDismissed() async {',
    );
    final dismissMethod = _sourceBetween(
      source,
      'Future<void> _handleOnboardingDayRhythmDismissed() async {',
      'Future<void> _handleObservedJournalPromptNext() async {',
    );
    final observedNextMethod = _sourceBetween(
      source,
      'Future<void> _handleObservedJournalPromptNext() async {',
      'void _showMenuExploreCoachmark()',
    );

    expect(showMethod, contains('onboardingDayRhythmDateIdentity'));
    expect(showMethod, contains('lastSatisfiedDayRhythmIdentity'));
    expect(dismissMethod, contains('lastSatisfiedDayRhythmIdentity: identity'));
    expect(dismissMethod, contains('DailyCosmicContextPrefs().markShown'));
    expect(
      observedNextMethod,
      contains(
        '_onboardingProgress.currentStep == TrueOnboardingStep.complete',
      ),
    );
    expect(
      observedNextMethod.indexOf(
        '_onboardingProgress.currentStep == TrueOnboardingStep.complete',
      ),
      lessThan(
        observedNextMethod.indexOf(
          '_onboardingProgress.currentStep == TrueOnboardingStep.menuExplore',
        ),
      ),
      reason:
          'Completed returning users must bail out before the observed-journal '
          'path can rewrite progress back to menuExplore.',
    );
  });

  test(
    'onboarding Day Rhythm uses canonical identity, not first event date',
    () async {
      final source = await File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsString();
      final dateMethod = _sourceBetween(
        source,
        'DateTime _onboardingDayRhythmDate() {',
        'String _onboardingDayRhythmIdentity() {',
      );
      final joinedMethod = _sourceBetween(
        source,
        'Future<void> _handleHawRecommendedFlowJoined(int flowId) async {',
        'Future<int> _addOnboardingReviewEveningThresholdInstance({',
      );
      final stagedMethod = _sourceBetween(
        source,
        'void _stageEveningThresholdOnboardingTarget({',
        'Widget _buildHawRecommendedFlow(',
      );

      expect(
        dateMethod,
        contains('_onboardingProgress.onboardingDayRhythmDateIdentity'),
      );
      expect(
        dateMethod,
        contains('trackSkyNowInZone(detectTrackSkyTimeZone())'),
      );
      expect(dateMethod, isNot(contains('_firstMaatFlowEventKDate')));
      expect(dateMethod, isNot(contains('KemeticMath.toGregorian')));
      expect(joinedMethod, contains('canonicalDayRhythmIdentity'));
      expect(joinedMethod, contains('onboardingDayRhythmDateIdentity'));
      expect(stagedMethod, contains('trackSkyNowInZone(timezone)'));
    },
  );

  test('timezone identity uses local day, not raw UTC day at boundary', () {
    final utcBoundary = DateTime.utc(2026, 7, 11, 2, 30);
    final pacificNow = trackSkyNowInZone(
      TrackSkyTimeZone.pacific,
      now: utcBoundary,
    );
    final utcNow = _instantInIanaZone(utcBoundary, 'UTC');
    final aheadOfUtcNow = _instantInIanaZone(utcBoundary, 'Africa/Cairo');

    expect(dailyCosmicContextGregorianDateKey(pacificNow), '2026-07-10');
    expect(dailyCosmicContextGregorianDateKey(utcNow), '2026-07-11');
    expect(dailyCosmicContextGregorianDateKey(aheadOfUtcNow), '2026-07-11');
  });
}

String _sourceBetween(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  expect(startIndex, isNonNegative, reason: 'Missing source start: $start');
  final endIndex = source.indexOf(end, startIndex + start.length);
  expect(endIndex, isNonNegative, reason: 'Missing source end: $end');
  return source.substring(startIndex, endIndex);
}

DailyCosmicContextBadge _testBadge(
  DateTime date, {
  required String cosmicContext,
  String gregorianDateLabel = 'Test date',
  String kemeticDate = 'Test Kemetic date',
  String decanName = 'Test decan',
}) {
  return DailyCosmicContextBadge(
    dayKey: 'test_day',
    gregorianDateKey: dailyCosmicContextGregorianDateKey(date),
    gregorianDateLabel: gregorianDateLabel,
    kemeticDate: kemeticDate,
    decanName: decanName,
    cosmicContext: cosmicContext,
  );
}

KemeticDayInfo _testDayInfo({required String cosmicContext}) {
  return KemeticDayInfo(
    kemeticDate: 'Test Kemetic date',
    season: 'Test season',
    month: 'Test month',
    decanName: 'Test decan',
    starCluster: 'Test stars',
    maatPrinciple: 'Test principle',
    cosmicContext: cosmicContext,
    decanFlow: const <DecanDayInfo>[],
    meduNeter: MeduNeterKey(
      glyph: 'test',
      colorFrequency: 'test',
      mantra: 'test',
    ),
  );
}

DateTime _instantInIanaZone(DateTime instant, String ianaName) {
  tzdata.initializeTimeZones();
  final zoned = tz.TZDateTime.from(instant.toUtc(), tz.getLocation(ianaName));
  return DateTime(zoned.year, zoned.month, zoned.day, zoned.hour, zoned.minute);
}
