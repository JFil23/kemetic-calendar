import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The fault tests exercise the coordinator with real pending and rejected
// futures. These guards connect each critical production operation to that
// tested boundary, without executing device plugins or a live auth singleton.
void main() {
  late String mainSource;
  late String startup;
  late String bootstrap;

  setUpAll(() {
    mainSource = File('lib/main.dart').readAsStringSync();
    startup = _between(
      mainSource,
      'Future<void> main()',
      'Future<Widget> _bootstrapApp(',
    );
    bootstrap = _between(
      mainSource,
      'Future<Widget> _bootstrapApp(',
      'final supabase = Supabase.instance.client;',
    );
  });

  test(
    'normal startup installs its independent shell without awaiting I/O',
    () {
      final runApp = startup.indexOf('runApp(');
      expect(runApp, greaterThanOrEqualTo(0));
      expect(
        startup.substring(0, runApp),
        isNot(matches(RegExp(r'\bawait\b'))),
      );
      expect(_callAt(startup, runApp), contains('RootBootApp('));
      expect(
        startup.indexOf('coordinator.start(_bootstrapApp)'),
        greaterThan(runApp),
      );
      expect(RegExp(r'\brunApp\(').allMatches(startup).length, 1);
      expect(bootstrap, isNot(contains('runApp(')));
    },
  );

  const operationsByStage = <String, String>{
    'device time zone': 'MaatFlowDeviceTimeZone.initialize',
    'runtime configuration': '_loadSupabaseConfig',
    'saved session': 'Supabase.initialize',
    'session refresh': '_refreshSessionIfNeeded',
    'profile cache': 'ProfileRepo(Supabase.instance.client).preloadLocalCaches',
    'window identity': 'AppWindowService.instance.ensureInitialized',
    'restoration storage': 'AppRestorationService.instance.initialize',
    'navigation trace': 'NavigationTrace.instance.load',
    'initial app link': '_readBootInitialAppLinkIntent',
    'initial push': '_readBootInitialPushIntent',
    'saved navigation': '_readBootRestoredLocation',
  };

  for (final entry in operationsByStage.entries) {
    test('${entry.key} uses the fault-tested deadline boundary', () {
      final guardedCall = RegExp(
        "attempt\\.run(?:<[^>]+>)?\\(\\s*'${RegExp.escape(entry.key)}'",
      ).firstMatch(bootstrap);
      expect(
        guardedCall,
        isNotNull,
        reason: '${entry.key} must remain guarded.',
      );
      final call = _callAt(bootstrap, guardedCall!.start);
      expect(call, contains(entry.value));
      expect(
        RegExp(RegExp.escape(entry.value)).allMatches(bootstrap).length,
        1,
        reason:
            'Do not duplicate ${entry.value} outside its deadline boundary.',
      );
    });
  }

  test('router and account warmups start only after all startup reads', () {
    final finalRead = bootstrap.indexOf("'saved navigation'");
    final activeCheckpoint = bootstrap.indexOf(
      'attempt.ensureActive();',
      finalRead,
    );
    expect(finalRead, greaterThanOrEqualTo(0));
    expect(activeCheckpoint, greaterThan(finalRead));
    for (final sideEffect in [
      '_router = _createRouter(',
      'RestorationCoordinator.instance.beginLaunchRestore(',
      '_startBackgroundWarmups();',
      '_startWebBootTasks();',
      'return const MyApp();',
    ]) {
      expect(
        bootstrap.indexOf(sideEffect),
        greaterThan(activeCheckpoint),
        reason: '$sideEffect must never follow an abandoned boot attempt.',
      );
    }
  });

  test(
    'recovery reloads the page without deleting session or account storage',
    () {
      expect(
        startup,
        contains('onRetry: kIsWeb ? reloadPageForBootRecovery : null'),
      );
      final history = File('lib/utils/web_history_web.dart').readAsStringSync();
      expect(
        history,
        contains(
          'void reloadPageForBootRecovery() => web.window.location.reload();',
        ),
      );
      final storage = File(
        'lib/utils/hive_local_storage_web.dart',
      ).readAsStringSync();
      expect(storage, contains("static const _boxName = 'sb_session';"));
      expect(
        storage,
        contains('static const _key = supabasePersistSessionKey;'),
      );
      expect(
        bootstrap,
        contains('localStorage: kIsWeb ? HiveLocalStorageWeb() : null'),
      );
      final recoverySources =
          '$startup\n$bootstrap\n${File('lib/root_boot.dart').readAsStringSync()}';
      for (final destructiveFallback in [
        'deleteBoxFromDisk',
        'removePersistedSession',
        '.signOut(',
        'localStorage.clear(',
        'sessionStorage.clear(',
      ]) {
        expect(recoverySources, isNot(contains(destructiveFallback)));
      }
    },
  );

  test(
    'authenticated route still owns its existing launch restoration overlay',
    () {
      expect(mainSource, contains('class _LaunchShell extends StatefulWidget'));
      expect(mainSource, contains('waitForInitialCalendarRestorationToSettle'));
    },
  );
}

String _between(String source, String start, String end) {
  final from = source.indexOf(start);
  expect(from, greaterThanOrEqualTo(0), reason: 'Missing $start');
  final to = source.indexOf(end, from);
  expect(to, greaterThan(from), reason: 'Missing $end');
  return source.substring(from, to);
}

String _callAt(String source, int start) {
  final open = source.indexOf('(', start);
  expect(open, greaterThanOrEqualTo(start));
  var depth = 0;
  for (var i = open; i < source.length; i += 1) {
    if (source[i] == '(') depth += 1;
    if (source[i] == ')') {
      depth -= 1;
      if (depth == 0) return source.substring(start, i + 1);
    }
  }
  fail('Unclosed call at $start');
}
