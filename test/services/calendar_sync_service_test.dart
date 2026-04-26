import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/calendar_sync_service.dart';

void main() {
  group('isImportedDeviceCalendarEvent', () {
    test('detects native cid imports', () {
      expect(
        isImportedDeviceCalendarEvent(
          clientEventId: 'native:ios:abc123',
          category: null,
        ),
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
          category: null,
        ),
        isFalse,
      );
    });
  });

  group('parseCalendarSyncTimestamp', () {
    test('parses stored ISO timestamps', () {
      final parsed = parseCalendarSyncTimestamp('2026-04-15T12:34:56.000Z');

      expect(parsed, isNotNull);
      expect(parsed!.toUtc().year, 2026);
      expect(parsed.toUtc().month, 4);
      expect(parsed.toUtc().day, 15);
    });

    test('returns null for unsupported values', () {
      expect(parseCalendarSyncTimestamp(null), isNull);
      expect(parseCalendarSyncTimestamp(123), isNull);
      expect(parseCalendarSyncTimestamp(''), isNull);
      expect(parseCalendarSyncTimestamp('not-a-date'), isNull);
    });
  });

  group('shouldBackOffCalendarPermissionRequest', () {
    test('backs off while denial is still recent', () {
      final now = DateTime.utc(2026, 4, 15, 20);
      final lastDenied = now.subtract(const Duration(hours: 2));

      final result = shouldBackOffCalendarPermissionRequest(
        now: now,
        lastPermissionDeniedAt: lastDenied,
      );

      expect(result, isTrue);
    });

    test('allows retry after cooldown', () {
      final now = DateTime.utc(2026, 4, 15, 20);
      final lastDenied = now.subtract(const Duration(hours: 13));

      final result = shouldBackOffCalendarPermissionRequest(
        now: now,
        lastPermissionDeniedAt: lastDenied,
      );

      expect(result, isFalse);
    });
  });

  group('shouldSkipCalendarAutoStartSync', () {
    test('skips auto-start when a sync just ran', () {
      final now = DateTime.utc(2026, 4, 15, 20, 0, 0);
      final lastSync = now.subtract(const Duration(seconds: 45));

      final result = shouldSkipCalendarAutoStartSync(
        now: now,
        lastSyncAt: lastSync,
      );

      expect(result, isTrue);
    });

    test('runs auto-start sync when last sync is stale', () {
      final now = DateTime.utc(2026, 4, 15, 20, 0, 0);
      final lastSync = now.subtract(const Duration(minutes: 10));

      final result = shouldSkipCalendarAutoStartSync(
        now: now,
        lastSyncAt: lastSync,
      );

      expect(result, isFalse);
    });
  });
}
