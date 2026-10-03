@TestOn('browser')
library;

import 'dart:async';
// The pinned Hive web backend itself uses dart:html IndexedDB. Exercise that
// same backend, rather than a different interop implementation.
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/boot_diagnostics.dart';
import 'package:mobile/root_boot.dart';
import 'package:mobile/utils/hive_local_storage_web.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'real IndexedDB version mismatch reaches safe openSessionBox diagnostic',
    () async {
      // flutter test owns a disposable browser profile and localhost origin.
      final database = await html.window.indexedDB!.open(
        'sb_session',
        version: 2,
        onUpgradeNeeded: (_) {},
      );
      database.close();
      Object? observed;
      final backendErrors = <Object>[];
      try {
        await runZonedGuarded<Future<void>>(
          () async {
            try {
              await HiveLocalStorageWeb().initialize();
            } catch (error) {
              observed = error;
            }
            // Hive also completes its concurrent-opener future with the same error.
            await Future<void>.delayed(Duration.zero);
          },
          (error, stack) {
            backendErrors.add(error);
          },
        );
        expect(observed, isA<BootStorageFailure>());
        final diagnostic = BootFailure('saved session', observed!).diagnostic;
        expect(
          diagnostic,
          'Stage: saved session\nOperation: openSessionBox\nError: VersionError',
        );
        expect(
          backendErrors.every(
            (error) => bootErrorCategory(error) == 'VersionError',
          ),
          true,
        );
        // Output is deliberately restricted to the same safe user-facing labels.
        // ignore: avoid_print
        print(diagnostic);
      } finally {
        await html.window.indexedDB!.deleteDatabase('sb_session');
      }
    },
  );
}
