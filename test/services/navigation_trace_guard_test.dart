import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/navigation_trace.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    NavigationTrace.instance.resetForTesting();
  });

  tearDown(() {
    NavigationTrace.instance.resetForTesting();
  });

  group('navigation trace guard', () {
    test('source contains the PWA tap-path labels and overlay state', () async {
      final mainSource = await File('lib/main.dart').readAsString();
      final calendarSource = await File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsString();
      final profileSource = await File(
        'lib/features/profile/profile_page.dart',
      ).readAsString();
      final plannerSource = await File(
        'lib/features/rhythm/pages/todays_alignment_page.dart',
      ).readAsString();
      final combined =
          '$mainSource\n$calendarSource\n$profileSource\n$plannerSource';

      for (final label in <String>[
        'bottom menu button tapped',
        'global menu mounted/opened',
        'Flow Studio tile tapped',
        'Calendars tile tapped',
        '_openFlowStudioFromMenu entered',
        '_openCalendarsFromMenu entered',
        'menu close started',
        'menu close completed',
        "global menu utility route push('/flows') requested",
        "global menu utility route push('/calendars') requested",
        'calendar overlay state save skipped',
        'detached calendar overlay state save skipped',
        'calendars sheet helper entered',
        'calendars sheet overlay state save returned',
        'calendars sheet show requested',
        'calendars sheet future created',
        'calendars sheet future completed',
        'flow studio sheet helper entered',
        'flow studio sheet overlay state save returned',
        'flow studio sheet show requested',
        'flow studio sheet future created',
        'flow studio sheet future completed',
        'sheet open success',
        'sheet open error',
        'Profile app-bar tap fired',
        'openProfileFromAnyContext entered',
        'current user id resolved',
        'profile feed continuity clear skipped',
        '/profile/me route command issued',
        'profile route push requested',
        'profile route push completed/current uri',
        'profile route push error',
        'profile route builder started',
        'profile route user resolved',
        'profile route returning ProfilePage',
        'ProfilePage initState',
        'ProfilePage build first frame',
        'ProfilePage first frame completed',
        'Today app-bar tap fired',
        'openMainCalendarAtToday entered',
        'Today restoration state saved',
        "go('/') issued",
        'CalendarPage consumed pending Today command',
      ]) {
        expect(combined, contains(label), reason: 'Missing trace: $label');
      }

      for (final stateKey in <String>[
        '_menuMounted',
        '_menuOpen',
        '_floatingMenuModalDepth.value',
        '_launchOverlayDismissed.value',
        'route',
        'MediaQuery.viewInsets.bottom',
      ]) {
        expect(mainSource, contains(stateKey));
      }
    });

    test(
      'Settings build marker is the hidden persisted activation path',
      () async {
        final settingsSource = await File(
          'lib/features/settings/settings_page.dart',
        ).readAsString();

        expect(settingsSource, contains('_buildMarkerTapCount < 7'));
        expect(settingsSource, contains('_handleBuildMarkerTap'));
        expect(settingsSource, contains('NavigationTrace.instance.setEnabled'));
        expect(settingsSource, contains('Navigation Trace enabled'));
        expect(settingsSource, contains('Navigation Trace disabled'));
      },
    );

    testWidgets('overlay is visible when enabled and does not intercept taps', (
      tester,
    ) async {
      var tapCount = 0;
      await NavigationTrace.instance.setEnabled(true);
      NavigationTrace.instance.record('bottom menu button tapped');

      await tester.pumpWidget(
        NavigationTraceOverlay(
          child: MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: TextButton(
                  onPressed: () {
                    tapCount += 1;
                  },
                  child: const Text('Tap target'),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Navigation Trace'), findsOneWidget);
      expect(find.textContaining('bottom menu button tapped'), findsOneWidget);

      await tester.tap(find.text('Tap target'));
      expect(tapCount, 1);
    });

    test(
      'recordError stores runtime type, message, and stack frames',
      () async {
        await NavigationTrace.instance.setEnabled(true);

        try {
          throw StateError('profile route failed');
        } catch (error, stackTrace) {
          NavigationTrace.instance.recordError(
            'profile route go error',
            error,
            stackTrace,
            state: const <String, Object?>{'route': '/profile/me'},
          );
        }

        final joinedEntries = NavigationTrace.instance.entries.join('\n');
        expect(joinedEntries, contains('profile route go error'));
        expect(joinedEntries, contains('StateError'));
        expect(joinedEntries, contains('profile route failed'));
        expect(joinedEntries, contains('stack1'));
      },
    );

    test('trace source does not expose runtime secret config names', () async {
      final traceSource = await File(
        'lib/services/navigation_trace.dart',
      ).readAsString();

      for (final secretKey in <String>[
        'SUPABASE_URL',
        'SUPABASE_ANON_KEY',
        'FIREBASE_WEB_API_KEY',
        'FIREBASE_WEB_VAPID_KEY',
        'WEB_PUSH_PUBLIC_KEY',
        'env.json',
      ]) {
        expect(traceSource, isNot(contains(secretKey)));
      }
    });
  });
}
