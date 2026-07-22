import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/settings/settings_page.dart';
import 'package:mobile/features/settings/settings_prefs.dart';
import 'package:mobile/services/calendar_sync_service.dart';
import 'package:mobile/services/push_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _unavailablePushDiagnostics = PushRegistrationDiagnostics(
  checkedAt: _fixtureTime,
  firebaseReady: false,
  permissionStatus: 'unavailable',
  permissionGranted: false,
  platform: 'ios',
  hasSession: true,
  databaseRegistered: false,
  browserSubscriptionPresent: false,
);

final _readyPushDiagnostics = PushRegistrationDiagnostics(
  checkedAt: _fixtureTime,
  firebaseReady: true,
  permissionStatus: 'authorized',
  permissionGranted: true,
  platform: 'ios',
  hasSession: true,
  databaseRegistered: true,
  browserSubscriptionPresent: false,
  registeredToken: 'fixture-device-token',
);

final _fixtureTime = DateTime.utc(2026, 7, 22, 12);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String source;

  setUpAll(() async {
    source = await File(
      'lib/features/settings/settings_page.dart',
    ).readAsString();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await _ensureSupabaseInitialized();
  });

  group('settings page guard', () {
    testWidgets(
      'app bar sign-out action signs out and routes through auth gate',
      (tester) async {
        var signOutCalls = 0;
        await _pumpSettings(
          tester,
          hasSession: true,
          signOut: () async {
            signOutCalls += 1;
          },
        );

        expect(find.byTooltip('Sign out'), findsOneWidget);
        final action = tester.widget<IconButton>(
          find.ancestor(
            of: find.byTooltip('Sign out'),
            matching: find.byType(IconButton),
          ),
        );
        expect(action.onPressed, isNotNull);

        await tester.tap(find.byTooltip('Sign out'));
        await _pumpUntil(
          tester,
          () => find.text('Auth gate').evaluate().isNotEmpty,
        );
        await tester.pumpAndSettle();

        expect(signOutCalls, 1);
        expect(find.text('Auth gate'), findsOneWidget);
        expect(find.text('Settings'), findsNothing);
      },
    );

    testWidgets('scroll padding does not duplicate the route bottom inset', (
      tester,
    ) async {
      await _pumpSettings(tester);

      final scrollView = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(scrollView.padding, const EdgeInsets.fromLTRB(16, 12, 16, 32));
    });

    test('legal support visibility and account rows stay in compact footer', () {
      expect(
        source,
        contains("static const String _termsUrl = 'https://maat.app/terms';"),
      );
      expect(
        source,
        contains(
          "static const String _privacyPolicyUrl = 'https://maat.app/privacy';",
        ),
      );
      expect(
        source,
        contains(
          "static const String _supportUrl = 'https://maat.app/support';",
        ),
      );
      expect(source, contains("_footerHeading('Legal & Support')"));
      expect(source, contains("_footerHeading('Danger Zone')"));
      expect(source, contains("title: 'Terms'"));
      expect(source, contains("title: 'Privacy'"));
      expect(source, contains("title: 'Support'"));
      expect(source, contains("title: _deletingAccount"));
      expect(source, contains("? 'Deleting account...'"));
      expect(source, contains(": 'Delete account'"));
      expect(
        source,
        contains("title: _signingOut ? 'Signing out...' : 'Sign out'"),
      );
      expect(source, contains('Privacy & visibility'));
      expect(
        source,
        contains(
          'Your private journal, calendar, and personal flow activity are private by default.',
        ),
      );
    });

    testWidgets(
      'daily cosmic context toggle stays in calendar content settings',
      (tester) async {
        await _pumpSettings(
          tester,
          initialPreferences: <String, Object>{
            SettingsPrefs.dailyCosmicContextBadgeEnabledKey: false,
          },
        );

        final title = find.text('The Day’s Rhythm badge');
        final switchFinder = find.ancestor(
          of: title,
          matching: find.byType(SwitchListTile),
        );
        expect(switchFinder, findsOneWidget);
        expect(tester.widget<SwitchListTile>(switchFinder).value, isFalse);

        await tester.ensureVisible(title);
        await tester.pump();
        await tester.tap(title);
        await _pumpUntil(
          tester,
          () => tester.widget<SwitchListTile>(switchFinder).value,
        );

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getBool(SettingsPrefs.dailyCosmicContextBadgeEnabledKey),
          isTrue,
        );
      },
    );

    testWidgets('calendar import settings support web read-only import', (
      tester,
    ) async {
      await _pumpSettings(
        tester,
        hasSession: true,
        useWebCalendarPresentation: true,
      );

      expect(find.text('Calendar Import'), findsOneWidget);
      expect(
        find.textContaining(
          'One-way import only: external calendar events can appear in HAw',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'does not export, create, update, or delete events in outside calendars',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Uses Google Calendar read-only access to read external events into HAw.',
        ),
        findsOneWidget,
      );
      expect(find.text('Import from Google'), findsOneWidget);

      final importButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Import from Google'),
      );
      expect(importButton.onPressed, isNotNull);
      expect(find.textContaining('Import unavailable on web'), findsNothing);
    });

    testWidgets('build marker renders public version metadata only', (
      tester,
    ) async {
      await _pumpSettings(tester);

      expect(find.text('Build'), findsOneWidget);
      expect(find.text('App version: 1.0.0+1'), findsOneWidget);
      expect(find.text('Web build: native'), findsOneWidget);
      expect(find.text('Build time: unavailable'), findsOneWidget);
      expect(find.text('APP_ENV: dev'), findsOneWidget);
    });

    test('build marker does not expose secret runtime config values', () {
      final readBuildInfo = _sourceBetween(
        source,
        'Future<_SettingsBuildInfo> _readBuildInfo() async {',
        '\n  String _safeBuildInfoValue',
      );
      final buildMarker = _sourceBetween(
        source,
        'Widget _buildMarker() {',
        '\n  Widget _buildMarkerLine',
      );
      final markerSource = '$readBuildInfo\n$buildMarker';

      for (final secretKey in <String>[
        'SUPABASE_URL',
        'SUPABASE_ANON_KEY',
        'FIREBASE_WEB_API_KEY',
        'FIREBASE_WEB_VAPID_KEY',
        'WEB_PUSH_PUBLIC_KEY',
      ]) {
        expect(markerSource, isNot(contains(secretKey)));
      }
    });

    test('push linked copy requires current device readiness', () {
      final subtitleSource = _sourceBetween(
        source,
        'String _pushToggleSubtitle() {',
        '\n  bool get _canSendPushSelfTest',
      );

      expect(subtitleSource, contains('diagnostics.currentDeviceReadyForPush'));
      expect(
        subtitleSource.indexOf('diagnostics.currentDeviceReadyForPush'),
        lessThan(
          subtitleSource.indexOf(
            "'This device is linked for account-level push alerts.'",
          ),
        ),
      );
      expect(subtitleSource, contains('not currently ready for delivery'));
    });

    testWidgets(
      'stale local push setting alone cannot enable self-test dispatch',
      (tester) async {
        const initialPreferences = <String, Object>{
          SettingsPrefs.realTimeAlertsKey: true,
        };

        await _pumpSettings(
          tester,
          initialPreferences: initialPreferences,
          hasSession: true,
          pushDiagnostics: _unavailablePushDiagnostics,
        );

        final buttonFinder = find.widgetWithText(
          OutlinedButton,
          'Send test push to this device',
        );
        expect(tester.widget<OutlinedButton>(buttonFinder).onPressed, isNull);
        expect(
          find.text('Firebase push is not ready for this device build.'),
          findsWidgets,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await _pumpSettings(
          tester,
          initialPreferences: initialPreferences,
          hasSession: true,
          pushDiagnostics: _readyPushDiagnostics,
        );

        expect(
          tester.widget<OutlinedButton>(buttonFinder).onPressed,
          isNotNull,
        );
        expect(
          find.text('This device is linked for account-level push alerts.'),
          findsOneWidget,
        );
      },
    );
  });
}

Future<void> _pumpSettings(
  WidgetTester tester, {
  Map<String, Object> initialPreferences = const <String, Object>{},
  bool hasSession = false,
  bool useWebCalendarPresentation = false,
  PushRegistrationDiagnostics? pushDiagnostics,
  Future<void> Function()? signOut,
}) async {
  SharedPreferences.setMockInitialValues(initialPreferences);
  final router = GoRouter(
    initialLocation: '/settings',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('Auth gate')),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, _) => SettingsPage.forTesting(
          signOut: signOut,
          calendarStatusLoader: () async => const CalendarSyncStatus(),
          pushDiagnosticsLoader: () async =>
              pushDiagnostics ?? _unavailablePushDiagnostics,
          hasSession: hasSession,
          useWebCalendarPresentation: useWebCalendarPresentation,
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    MaterialApp.router(theme: ThemeData.dark(), routerConfig: router),
  );
  await _pumpUntil(tester, () => find.text('Settings').evaluate().isNotEmpty);
  await _pumpUntil(
    tester,
    () => find
        .widgetWithText(OutlinedButton, 'Send test push to this device')
        .evaluate()
        .isNotEmpty,
  );
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  int maxPumps = 100,
}) async {
  for (var i = 0; i < maxPumps; i += 1) {
    if (condition()) return;
    await tester.pump(const Duration(milliseconds: 10));
  }
  expect(condition(), isTrue, reason: 'Timed out waiting for fixture state.');
}

Future<void> _ensureSupabaseInitialized() async {
  try {
    Supabase.instance.client;
    return;
  } catch (_) {}

  await Supabase.initialize(
    url: 'https://example.supabase.co',
    anonKey: 'anon-key-0123456789012345678901234567890123456789',
  );
}

String _sourceBetween(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  expect(startIndex, isNonNegative, reason: 'Missing source start: $start');
  final endIndex = source.indexOf(end, startIndex + start.length);
  expect(endIndex, isNonNegative, reason: 'Missing source end: $end');
  return source.substring(startIndex, endIndex);
}
