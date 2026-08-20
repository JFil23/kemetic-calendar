import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('calendar sync authority contract', () {
    test('locks the one-way authority and staged release rules', () async {
      final authority = await File(
        'docs/calendar_sync/authority_map.md',
      ).readAsString();
      final release = await File(
        'docs/calendar_sync/release_cutover.md',
      ).readAsString();

      expect(authority, contains('Apple / Google calendar -> HAw projection'));
      expect(
        authority,
        contains('HAw calendar           -X-> Apple / Google calendar'),
      );
      expect(
        authority,
        contains('OFF pauses monitoring and retains imported rows'),
      );
      expect(authority, contains('removes only imported HAw rows'));
      expect(authority, contains('Runtime files: none.'));
      expect(release, contains('one closed calendar-sync delta'));
      expect(
        release,
        contains('git diff CANDIDATE_SHA...ACTUAL_MERGE_SHA --name-only'),
      );
      expect(
        release,
        contains('Prepared later-cut patches are source material only.'),
      );
    });

    test('assigns physical acceptance to the owning cut', () async {
      final release = await File(
        'docs/calendar_sync/release_cutover.md',
      ).readAsString();
      final cut1 = _section(
        release,
        '### Cut 1 — read-only boundary and controls',
        '### Cut 2 — reconciliation and occurrence identity',
      );
      final cut2 = _section(
        release,
        '### Cut 2 — reconciliation and occurrence identity',
        '### Cut 3 — automatic freshness and publication',
      );
      final cut3 = _section(
        release,
        '### Cut 3 — automatic freshness and publication',
        '### Cut 4 — range and coverage',
      );
      final cut4 = _section(
        release,
        '### Cut 4 — range and coverage',
        '## Never',
      );

      expect(cut1, contains('native write capability is gone'));
      expect(cut1, contains('basic existing native-to-HAw import'));
      expect(cut1, contains('imported rows remain'));
      expect(cut1, contains('only imported HAw rows'));
      expect(cut1, isNot(contains('recurring occurrence identity')));
      expect(cut1, isNot(contains('killed-app/reopen catch-up')));

      expect(cut2, contains('recurring occurrence identity'));
      expect(cut2, contains('external-source-wins reconciliation'));
      expect(cut2, contains('suppression removal'));
      expect(cut3, contains('native observer updates and debounce'));
      expect(cut3, contains('foreground catch-up'));
      expect(cut3, contains('killed-app/reopen catch-up'));
      expect(cut3, contains('one publication'));
      expect(cut4, contains('30-day-past/180-day-future'));
      expect(cut4, matches(RegExp(r'no load or performance\s+regression')));
    });

    test('locks Cut 0 parity, Cut 0A, and separate approvals', () async {
      final release = await File(
        'docs/calendar_sync/release_cutover.md',
      ).readAsString();

      expect(release, contains('## Cut 0 baseline-parity gate'));
      expect(release, contains('served failures: N'));
      expect(release, contains('candidate failures: N'));
      expect(release, contains('new failure identities: 0'));
      expect(release, contains('removed/reclassified identities: 0'));
      expect(release, contains('baseline parity: PASS'));
      expect(
        release,
        matches(RegExp(r'it is not a hard-coded expected\s+count')),
      );
      expect(
        release,
        contains(
          'Cut 0A is mandatory after Cut 0 is served and before Cut 1 begins.',
        ),
      );
      expect(release, contains('repair stale hydration baseline'));
      expect(release, contains('repair obsolete quick-add source guard'));
      expect(
        release,
        contains(
          'repair the time-dependent Day View Today-scroll source guard',
        ),
      );
      expect(release, contains('candidate tree approved: YES/NO'));
      expect(release, contains('production promotion authorized: YES/NO'));
      expect(
        release,
        contains('A tree-approved candidate is not yet promotion-authorized.'),
      );
    });

    test('pins the exact served-production violation inventory', () async {
      final sources = <String, String>{
        for (final path in _guardedSourcePaths)
          path: await File(path).readAsString(),
      };

      final violations = <String>{
        if (sources[_androidManifest]!.contains(
          'android.permission.WRITE_CALENDAR',
        ))
          'android:write-permission',
        if (sources[_androidBridge]!.contains(
          'Manifest.permission.WRITE_CALENDAR',
        ))
          'android:write-permission-request',
        if (sources[_androidBridge]!.contains('"upsertEvent" ->'))
          'android:upsert-channel',
        if (sources[_androidBridge]!.contains('"deleteEvent" ->'))
          'android:delete-channel',
        if (sources[_androidBridge]!.contains('"purgeKemeticEvents" ->'))
          'android:purge-channel',
        if (sources[_androidBridge]!.contains('cr.insert('))
          'android:native-insert',
        if (sources[_androidBridge]!.contains('cr.update('))
          'android:native-update',
        if (sources[_androidBridge]!.contains('contentResolver.delete('))
          'android:native-delete',
        if (sources[_iosBridge]!.contains('case "upsertEvent"'))
          'ios:upsert-channel',
        if (sources[_iosBridge]!.contains('case "deleteEvent"'))
          'ios:delete-channel',
        if (sources[_iosBridge]!.contains('case "purgeKemeticEvents"'))
          'ios:purge-channel',
        if (sources[_iosBridge]!.contains('eventStore.save('))
          'ios:native-save',
        if (sources[_iosBridge]!.contains('eventStore.remove('))
          'ios:native-remove',
        if (sources[_syncService]!.contains('Future<bool> deleteEvent('))
          'dart:native-delete-bridge',
        if (sources[_syncService]!.contains('Future<int> purgeKemeticEvents('))
          'dart:native-purge-bridge',
        if (sources[_syncService]!.contains('_platform.purgeKemeticEvents()'))
          'dart:unlink-purges-native',
        if (sources[_syncService]!.contains('recordDeletedInApp('))
          'dart:haw-delete-suppresses-native',
        if (sources[_settingsPage]!.contains('sync.unlinkAndPurge('))
          'settings:unlink-calls-native-purge-path',
        if (sources[_calendarPage]!.contains('detachImportedDeviceEvent'))
          'calendar:import-detach-mutation',
        if (sources[_calendarPage]!.contains('.recordDeletedInApp('))
          'calendar:import-delete-suppression',
      };

      expect(violations, _servedProductionViolations);
    });

    test('does not allow an un-inventoried native write primitive', () async {
      final android = await File(_androidBridge).readAsString();
      final ios = await File(_iosBridge).readAsString();

      final androidWritePrimitives = RegExp(
        r'(?:contentResolver|\bcr)\.(insert|update|delete)\s*\(',
      ).allMatches(android).map((match) => match.group(1)!).toSet();
      final iosWritePrimitives = RegExp(
        r'eventStore\.(save|remove)\s*\(',
      ).allMatches(ios).map((match) => match.group(1)!).toSet();

      expect(androidWritePrimitives, <String>{'insert', 'update', 'delete'});
      expect(iosWritePrimitives, <String>{'save', 'remove'});
    });
  });
}

String _section(String source, String startHeading, String endHeading) {
  final start = source.indexOf(startHeading);
  final end = source.indexOf(endHeading, start + startHeading.length);
  if (start < 0 || end < 0) {
    throw StateError('Missing release section: $startHeading -> $endHeading');
  }
  return source.substring(start, end);
}

const _androidManifest = 'android/app/src/main/AndroidManifest.xml';
const _androidBridge =
    'android/app/src/main/kotlin/com/jaralephillips/hawcalendar/MainActivity.kt';
const _iosBridge = 'ios/Runner/AppDelegate.swift';
const _syncService = 'lib/services/calendar_sync_service.dart';
const _settingsPage = 'lib/features/settings/settings_page.dart';
const _calendarPage = 'lib/features/calendar/calendar_page.dart';

const _guardedSourcePaths = <String>[
  _androidManifest,
  _androidBridge,
  _iosBridge,
  _syncService,
  _settingsPage,
  _calendarPage,
];

const _servedProductionViolations = <String>{
  'android:write-permission',
  'android:write-permission-request',
  'android:upsert-channel',
  'android:delete-channel',
  'android:purge-channel',
  'android:native-insert',
  'android:native-update',
  'android:native-delete',
  'ios:upsert-channel',
  'ios:delete-channel',
  'ios:purge-channel',
  'ios:native-save',
  'ios:native-remove',
  'dart:native-delete-bridge',
  'dart:native-purge-bridge',
  'dart:unlink-purges-native',
  'dart:haw-delete-suppresses-native',
  'settings:unlink-calls-native-purge-path',
  'calendar:import-detach-mutation',
  'calendar:import-delete-suppression',
};
