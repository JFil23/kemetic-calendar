import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('root app shell startup policy', () {
    late String mainSource;
    late String rootBootSource;

    setUpAll(() {
      mainSource = File('lib/main.dart').readAsStringSync();
      rootBootSource = File('lib/root_boot.dart').readAsStringSync();
    });

    test(
      'normal startup installs a Flutter-owned shell before Supabase init',
      () {
        final normalRunApp = _firstNormalRunApp(mainSource);
        final supabaseInitialize = _requiredIndex(
          mainSource,
          'await Supabase.initialize(',
        );

        expect(
          normalRunApp,
          lessThan(supabaseInitialize),
          reason:
              'Android cannot release its launch splash until Flutter produces '
              'a first frame. Normal startup must call runApp with a safe boot '
              'shell before Supabase.initialize completes.',
        );
      },
    );

    test('safe first frame is not blocked by nonessential boot work', () {
      final normalRunApp = _firstNormalRunApp(mainSource);
      final blockers = <String>[
        "await _refreshSessionIfNeeded('boot');",
        'await AppWindowService.instance.ensureInitialized();',
        'await AppRestorationService.instance.initialize();',
        'await NavigationTrace.instance.load();',
        'await _readBootInitialAppLinkIntent();',
        'await _readBootInitialPushIntent();',
        '_bootRestoredLocation = await _readBootRestoredLocation();',
        '_router = _createRouter(initialLocation: initialLocation);',
        'RestorationCoordinator.instance.beginLaunchRestore(',
      ];

      for (final blocker in blockers) {
        final blockerIndex = _requiredIndex(mainSource, blocker);
        expect(
          normalRunApp,
          lessThan(blockerIndex),
          reason:
              '$blocker must not delay the first Flutter-owned boot frame. '
              'It may gate authenticated route content, but not the safe root '
              'shell that replaces the Android launch splash.',
        );
      }
    });

    test(
      'boot architecture exposes an identity-ready boundary for cached routes',
      () {
        final bootSources = '$mainSource\n$rootBootSource';
        final hasIdentityReadyBoundary =
            bootSources.contains('RootBootShell') ||
            bootSources.contains('BootShell') ||
            bootSources.contains('SupabaseReady') ||
            bootSources.contains('AuthIdentityReady');

        expect(
          hasIdentityReadyBoundary,
          isTrue,
          reason:
              'Moving runApp before Supabase init requires an explicit boundary '
              'that lets the safe shell paint immediately while preventing '
              'cached authenticated content from rendering before user identity '
              'and environment are confirmed.',
        );
      },
    );

    test('authenticated app still owns the launch shell after boot resolves', () {
      expect(
        mainSource,
        contains('_LaunchShell'),
        reason:
            'The app-level launch overlay may remain for auth callback exchange '
            'after boot resolution, but it must not be the first-frame gate.',
      );
    });
  });
}

int _firstNormalRunApp(String source) {
  final matches = RegExp(r'runApp\((.*?)\);', dotAll: true).allMatches(source);
  for (final match in matches) {
    final argument = match.group(1) ?? '';
    if (!argument.contains('_runtimeConfigErrorApp')) {
      return match.start;
    }
  }
  fail('No normal runApp call found');
}

int _requiredIndex(String source, String needle) {
  final index = source.indexOf(needle);
  expect(index, isNot(-1), reason: 'Missing "$needle"');
  return index;
}
