@TestOn('browser')
library;

import 'dart:convert';
// Use the same browser store as the deployed preferences plugin.
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/boot_diagnostics.dart';
import 'package:mobile/root_boot.dart';
import 'package:mobile/services/app_restoration_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_web/shared_preferences_web.dart';

import 'restoration_quota_test.dart'
    show quotaSnapshot, configureQuotaRestoration, resetQuotaRestoration;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real full localStorage still restores navigation without deleting data',
    (tester) async {
      configureQuotaRestoration();
      final fillerKeys = <String>[];
      const snapshotKey = 'app_restoration_v1:user-1:window-1';
      const draftKey = 'planner_account:v1:quota-browser-test';
      try {
        SharedPreferences.setMockInitialValues({});
        SharedPreferencesPlugin.registerWith(null);
        final original = jsonEncode(quotaSnapshot());
        await tester.runAsync(() async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(snapshotKey, original);
          await prefs.setString(draftKey, 'pending-authored-write');
        });
        var quotaSeen = false;
        // Fill only this disposable localhost test profile, leaving less space
        // than a migrated snapshot needs. Remove exactly these test keys below.
        for (final size in [65536, 4096, 256, 16, 1]) {
          for (var count = 0; count < 256; count++) {
            final key = '__haw_quota_fixture_${fillerKeys.length}';
            try {
              html.window.localStorage[key] = 'x' * size;
              fillerKeys.add(key);
            } catch (error) {
              expect(bootErrorCategory(error), 'QuotaExceededError');
              quotaSeen = true;
              break;
            }
          }
        }
        expect(quotaSeen, true);
        // Prove a write at the actual preferences boundary rejects before boot.
        await tester.runAsync(() async {
          final prefs = await SharedPreferences.getInstance();
          try {
            await prefs.setString('__quota_probe', 'x' * 1024);
            fail('Expected actual browser quota rejection');
          } catch (error) {
            expect(bootErrorCategory(error), 'QuotaExceededError');
          }
          await prefs.reload();
        });
        final service = AppRestorationService.forTesting();
        final coordinator = BootCoordinator();
        await tester.pumpWidget(RootBootApp(coordinator: coordinator));
        coordinator.start((attempt) async {
          final result = await attempt.run(
            'saved navigation',
            () => service.readBestSnapshot(includeRemote: true),
          );
          return MaterialApp(
            home: Text('Restored ${result.snapshot?.routeLocation}'),
          );
        });
        await tester.pumpAndSettle();
        expect(
          coordinator.phase,
          RootBootPhase.ready,
          reason: coordinator.error?.diagnostic,
        );
        expect(find.text('Restored /nodes'), findsOneWidget);
        expect(find.text('Unable to start'), findsNothing);
        expect(
          html.window.localStorage['flutter.$snapshotKey'],
          jsonEncode(original),
        );
        expect(
          html.window.localStorage['flutter.$draftKey'],
          jsonEncode('pending-authored-write'),
        );
        // ignore: avoid_print
        print(
          'Real QuotaExceededError reproduced; saved navigation reached ready; original snapshot and pending draft preserved.',
        );
        await tester.pumpWidget(const SizedBox.shrink());
        coordinator.dispose();
      } finally {
        for (final key in fillerKeys) {
          html.window.localStorage.remove(key);
        }
        for (final key in [snapshotKey, draftKey, '__quota_probe']) {
          html.window.localStorage.remove('flutter.$key');
        }
        resetQuotaRestoration();
      }
    },
  );
}
