import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('settings page guard', () {
    late String source;

    setUpAll(() async {
      source = await File(
        'lib/features/settings/settings_page.dart',
      ).readAsString();
    });

    test('app bar sign-out action signs out and routes through auth gate', () {
      expect(source, contains("import 'package:go_router/go_router.dart';"));

      final signOut = _sourceBetween(
        source,
        'Future<void> _signOut() async {',
        '\n  @override\n  void initState',
      );
      expect(
        signOut,
        contains('await Supabase.instance.client.auth.signOut();'),
      );
      expect(signOut, contains("context.go('/');"));
      expect(signOut, contains("'Could not sign out. Please try again.'"));

      final appBar = _sourceBetween(
        source,
        'appBar: AppBar(',
        '),\n      body: SingleChildScrollView(',
      );
      expect(appBar, contains('centerTitle: true'));
      expect(appBar, contains("tooltip: 'Sign out'"));
      expect(appBar, contains('Icons.logout'));
      expect(appBar, contains('onPressed: _signingOut ? null : _signOut'));
    });

    test('scroll padding does not duplicate the route bottom inset', () {
      expect(source, isNot(contains('bottomPaddingAboveGlobalChrome')));
      expect(source, contains('const scrollBottomPadding = 32.0;'));

      final scrollView = _sourceBetween(
        source,
        'body: SingleChildScrollView(',
        'child: Column(',
      );
      expect(
        scrollView,
        contains('EdgeInsets.fromLTRB(16, 12, 16, scrollBottomPadding)'),
      );
      expect(
        scrollView,
        isNot(contains('EdgeInsets.fromLTRB(16, 12, 16, 24)')),
      );
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

    test('daily cosmic context toggle stays in calendar content settings', () {
      final calendarContent = _sourceBetween(
        source,
        "_sectionCard(\n              title: 'Calendar Content'",
        "_sectionCard(\n              title: 'Speech'",
      );

      expect(calendarContent, contains('The Day’s Rhythm badge'));
      expect(calendarContent, contains('_dailyCosmicContextBadgeEnabled'));
      expect(calendarContent, contains('_setDailyCosmicContextBadgeEnabled'));
    });

    test('build marker renders public version metadata only', () {
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
      final footer = _sourceBetween(
        source,
        "'Preferences stay local to this device.",
        '],\n        ),\n      ),',
      );

      expect(source, contains("import 'dart:convert';"));
      expect(source, contains("import 'package:http/http.dart' as http;"));
      expect(source, contains("show Events, appEnvironmentEnv"));
      expect(readBuildInfo, contains("Uri.base.resolve('version.json')"));
      expect(readBuildInfo, contains("decoded['build_version']"));
      expect(readBuildInfo, contains('_readWebRuntimeAppEnvironment()'));
      expect(readBuildInfo, contains('appEnvironmentEnv'));
      expect(source, contains("Uri.base.resolve('env.json')"));
      expect(source, contains("decoded['APP_ENV']"));
      expect(buildMarker, contains("_buildMarkerLine('App version'"));
      expect(buildMarker, contains("_buildMarkerLine('Web build'"));
      expect(buildMarker, contains("_buildMarkerLine('Build time'"));
      expect(buildMarker, contains("_buildMarkerLine('APP_ENV'"));
      expect(footer, contains('_buildMarker()'));
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

    test('stale local push setting alone cannot enable self-test dispatch', () {
      final canSendSource = _sourceBetween(
        source,
        'bool get _canSendPushSelfTest {',
        '\n  String _pushStatusText() {',
      );
      final buttonSource = _sourceBetween(
        source,
        'child: OutlinedButton(',
        'child: Text(\n                      _sendingPushTest',
      );

      expect(canSendSource, contains('_realTimeAlerts'));
      expect(
        canSendSource,
        contains('_pushDiagnostics?.currentDeviceReadyForPush == true'),
      );
      expect(
        buttonSource,
        contains('onPressed: _canSendPushSelfTest ? _sendPushTest : null'),
      );
    });
  });
}

String _sourceBetween(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  expect(startIndex, isNonNegative, reason: 'Missing source start: $start');
  final endIndex = source.indexOf(end, startIndex + start.length);
  expect(endIndex, isNonNegative, reason: 'Missing source end: $end');
  return source.substring(startIndex, endIndex);
}
