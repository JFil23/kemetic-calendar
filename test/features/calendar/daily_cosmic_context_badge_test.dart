import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/calendar/daily_cosmic_context_badge.dart';
import 'package:mobile/features/settings/settings_prefs.dart';
import 'package:mobile/widgets/kemetic_day_info.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    expect(
      prefs.getString(
        DailyCosmicContextPrefs.lastShownGregorianDateKeyForUser(_userId),
      ),
      '2026-06-09',
    );
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

    expect(build, contains('if (signedIn && _passwordRecoverySession)'));
    expect(
      build.indexOf('_buildPasswordRecoveryApp()'),
      lessThan(build.indexOf('_buildAuthedApp()')),
    );
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
