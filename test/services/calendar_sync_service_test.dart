import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/imported_calendar_identity.dart';
import 'package:mobile/services/device_calendar_controller.dart';

void main() {
  group('isImportedDeviceCalendarEvent', () {
    test('detects native cid imports', () {
      expect(
        isImportedDeviceCalendarEvent(clientEventId: 'native:ios:abc123'),
        isTrue,
      );
    });
    test('detects legacy native_sync category imports', () {
      expect(
        isImportedDeviceCalendarEvent(
          clientEventId: 'ky=1-km=1-kd=1|s=540|t=test|f=-1',
          category: 'native_sync',
        ),
        isTrue,
      );
    });
    test('does not treat app-owned events as imported device events', () {
      expect(
        isImportedDeviceCalendarEvent(
          clientEventId: 'ky=1-km=1-kd=1|s=540|t=test|f=-1',
        ),
        isFalse,
      );
    });
    test('detects separate fresh external projections', () {
      expect(
        isImportedDeviceCalendarEvent(clientEventId: 'external:device:event'),
        isTrue,
      );
      expect(
        isImportedDeviceCalendarEvent(category: 'external_calendar'),
        isTrue,
      );
    });
  });
  group('last synced timestamp in actual device status', () {
    DeviceCalendarStatus parse(Object? value) => DeviceCalendarStatus.fromJson({
      'available': true,
      'connection': {'id': 'connection', 'last_synced_at': value},
      'sources': [],
    });
    test('parses stored ISO timestamps', () {
      final parsed = parse('2026-04-15T12:34:56.000Z').lastSyncedAt;
      expect(parsed, DateTime.utc(2026, 4, 15, 12, 34, 56));
    });
    test('returns null for unsupported values', () {
      for (final value in [null, 123, '', 'not-a-date']) {
        expect(parse(value).lastSyncedAt, isNull);
      }
    });
  });
  group('calendar sync log guardrails', () {
    test('debug logs summarize cids and titles instead of printing values', () {
      for (final path in [
        'lib/services/device_calendar_bridge.dart',
        'lib/services/device_calendar_controller.dart',
      ]) {
        final source = File(path).readAsStringSync();
        // The replacement is stricter: these account-data boundaries do not log.
        expect(
          source,
          isNot(matches(RegExp(r'\b(?:print|debugPrint|log)\s*\('))),
        );
        expect(source, isNot(contains(r'cid=$cid')));
        expect(source, isNot(contains(r'title=${native.title}')));
      }
    });
  });
}
