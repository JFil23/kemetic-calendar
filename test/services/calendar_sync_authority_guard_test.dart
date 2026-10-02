import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('calendar sync authority contract', () {
    test('push retains stable device identity through the registered bridge', () {
      final push = File(
        'lib/services/push_notifications.dart',
      ).readAsStringSync();
      expect(push, contains("'com.kemetic.calendar/device_import_v1'"));
      expect(push, contains("'deviceId'"));
      expect(push, isNot(contains('com.kemetic.calendar/sync')));
      expect(push, isNot(contains('getStableDeviceId')));
      expect(push, contains("prefs.getString('push.deviceId')"));
      final ios = File(
        'ios/Runner/DeviceCalendarBridge.swift',
      ).readAsStringSync();
      final android = File(
        'android/app/src/main/kotlin/com/jaralephillips/hawcalendar/DeviceCalendarBridge.kt',
      ).readAsStringSync();
      expect(ios, contains('identifierForVendor'));
      expect(ios, contains('ios:'));
      expect(android, contains('Settings.Secure.ANDROID_ID'));
      expect(android, contains('android:'));
    });

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

    // Exact served test IDs are retained because the forward release comparison
    // treats previously served PASS identities as continuity contracts. Their
    // assertions now verify the stronger Cut 1 read-only state.
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

      expect(violations, isEmpty);
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

      expect(androidWritePrimitives, isEmpty);
      expect(iosWritePrimitives, isEmpty);
    });

    test('unlink clears only imported HAw rows without suppression', () async {
      final service = await File(_syncService).readAsString();
      final settings = await File(_settingsPage).readAsString();
      final unlink = _section(
        service,
        'Future<void> disconnect()',
        'void ensureRange(',
      );
      final binding = await File(
        'lib/features/settings/external_calendar_settings.dart',
      ).readAsString();
      expect(settings, contains('ExternalCalendarSettings('));
      expect(settings, isNot(contains('sharedCalendarSyncService')));
      expect(binding, contains('await _perform(controller.disconnect);'));
      expect(binding, contains('accountId != controller.accountId'));
      expect(binding, contains('generation != controller.generation'));
      expect(binding, contains('Hꜣw-created events stay unchanged.'));
      expect(settings, isNot(contains('sync.unlinkAndPurge(')));
      expect(unlink, contains("'device_disconnect'"));
      expect(
        unlink,
        contains('repository.projectionChanged(removedSources: true)'),
      );
      expect(unlink, isNot(contains('requestPermission')));
      expect(unlink, isNot(contains('bridge.')));
      expect(service, isNot(contains('UserEventsRepo')));
      expect(service, isNot(contains('user_events')));
      expect(service, isNot(contains('recordDeletedInApp')));
      expect(unlink, isNot(contains('MethodChannel')));
      expect(
        File('lib/services/calendar_sync_service.dart').existsSync(),
        isFalse,
      );
      final nativeBinding = File(
        'lib/features/settings/device_calendar_settings.dart',
      ).readAsStringSync();
      expect(nativeBinding, contains('controller.disconnect'));
      expect(nativeBinding, contains('controller.accountId'));
      expect(nativeBinding, contains('controller.generation'));
    });

    test('OFF preserves imports and failed enable stays visibly OFF', () async {
      final settings = await File(_settingsPage).readAsString();
      final prefs = await File(_settingsPrefs).readAsString();
      final controller = await File(
        'lib/services/external_calendar_controller.dart',
      ).readAsString();
      final binding = await File(
        'lib/features/settings/external_calendar_settings.dart',
      ).readAsString();
      final toggle = _section(
        controller,
        'Future<void> setAutomatic(bool enabled)',
        'Future<void> disconnect()',
      );

      expect(settings, isNot(contains('_setAutoCalendarSync')));
      expect(settings, isNot(contains('SettingsPrefs.autoCalendarSyncKey')));
      expect(binding, contains('automaticImport: status?.automatic ?? false'));
      expect(binding, contains('_controller.setAutomatic(enabled)'));
      expect(toggle, contains("enabled ? 'resume' : 'pause'"));
      expect(toggle, contains('arguments: _revision'));
      expect(toggle, contains('_accept(value);'));
      expect(controller, contains('status = value;'));
      expect(toggle, isNot(contains('disconnect')));
      expect(toggle, isNot(contains('delete')));
      expect(toggle, isNot(contains('automatic = enabled')));
      expect(prefs, isNot(contains('autoCalendarSync')));
      expect(serviceDefaults(), contains('this.automatic = false'));
    });

    test('imported projections cannot edit, move, detach, or suppress', () async {
      final calendar = await File(_calendarPage).readAsString();
      final service = await File(_syncService).readAsString();
      final delete = _section(
        calendar,
        'Future<bool> _deleteNote(',
        'Future<void> _deleteNoteByEvent(',
      );
      final move = _section(
        calendar,
        'Future<void> _moveEventInDayView(',
        'Future<bool> requestEndChange(',
      );
      final update = _section(
        calendar,
        'Future<({String clientEventId, String eventId})> _updateSingleNoteOnly(',
        'Future<String?> _saveRepeatingNoteAsHiddenFlow(',
      );

      expect(calendar, isNot(contains('detachImportedDeviceEvent')));
      expect(calendar, isNot(contains('move_event_detach')));
      expect(calendar, isNot(contains('.recordDeletedInApp(')));
      expect(service, isNot(contains('recordDeletedInApp(')));
      expect(
        delete.indexOf('isImportedDeviceCalendarEvent('),
        lessThan(delete.indexOf('_removeCalendarNotesWhere(')),
      );
      expect(
        move.indexOf('isImportedDeviceCalendarEvent('),
        lessThan(move.indexOf('_eventMoveInProgress.add(')),
      );
      expect(
        update.indexOf('isImportedDeviceCalendarEvent('),
        lessThan(update.indexOf('UserEventsRepo(')),
      );
      expect(
        calendar,
        contains('Imported device-calendar events are read-only in HAw.'),
      );
    });

    test('permission declarations describe a read-only import', () async {
      final manifest = await File(_androidManifest).readAsString();
      final plist = await File(_iosPlist).readAsString();

      expect(manifest, contains('android.permission.READ_CALENDAR'));
      expect(manifest, isNot(contains('android.permission.WRITE_CALENDAR')));
      expect(plist, contains('NSCalendarsFullAccessUsageDescription'));
      expect(plist, contains('one-way import'));
      expect(plist, contains('will not create, update, export, or delete'));
      expect(plist, isNot(contains('read and write your calendar')));
    });
  });
}

String serviceDefaults() =>
    File('lib/services/device_calendar_controller.dart').readAsStringSync();

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
    'android/app/src/main/kotlin/com/jaralephillips/hawcalendar/DeviceCalendarBridge.kt';
const _iosBridge = 'ios/Runner/DeviceCalendarBridge.swift';
const _iosPlist = 'ios/Runner/Info.plist';
const _syncService = 'lib/services/device_calendar_controller.dart';
const _settingsPage = 'lib/features/settings/settings_page.dart';
const _settingsPrefs = 'lib/features/settings/settings_prefs.dart';
const _calendarPage = 'lib/features/calendar/calendar_page.dart';

const _guardedSourcePaths = <String>[
  _androidManifest,
  _androidBridge,
  _iosBridge,
  _syncService,
  _settingsPage,
  _calendarPage,
];
