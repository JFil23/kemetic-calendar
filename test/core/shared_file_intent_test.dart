import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/shared_file_intent.dart';

void main() {
  group('buildSharedFileIntentSignature', () {
    test('normalizes path separators and ordering', () {
      final first = buildSharedFileIntentSignature([
        r'  /tmp/meeting.ics ',
        r'C:\Calendar\import.ics',
      ]);
      final second = buildSharedFileIntentSignature([
        r'C:\Calendar\import.ics',
        r'/tmp/meeting.ics',
      ]);

      expect(first, second);
      expect(first, contains('C:/Calendar/import.ics'));
    });

    test('drops empty entries', () {
      final signature = buildSharedFileIntentSignature([
        null,
        '',
        '   ',
        '/tmp/meeting.ics',
      ]);

      expect(signature, '/tmp/meeting.ics');
    });
  });

  group('shouldSkipDuplicateSharedFileIntent', () {
    test('skips recent duplicate deliveries', () {
      final now = DateTime.utc(2026, 4, 15, 21, 0, 0);

      final result = shouldSkipDuplicateSharedFileIntent(
        signature: '/tmp/meeting.ics',
        lastSignature: '/tmp/meeting.ics',
        lastHandledAt: now.subtract(const Duration(seconds: 2)),
        now: now,
      );

      expect(result, isTrue);
    });

    test('allows stale or different payloads', () {
      final now = DateTime.utc(2026, 4, 15, 21, 0, 0);

      expect(
        shouldSkipDuplicateSharedFileIntent(
          signature: '/tmp/meeting.ics',
          lastSignature: '/tmp/meeting.ics',
          lastHandledAt: now.subtract(const Duration(seconds: 5)),
          now: now,
        ),
        isFalse,
      );

      expect(
        shouldSkipDuplicateSharedFileIntent(
          signature: '/tmp/meeting-2.ics',
          lastSignature: '/tmp/meeting.ics',
          lastHandledAt: now.subtract(const Duration(seconds: 1)),
          now: now,
        ),
        isFalse,
      );
    });

    test('allows duplicates exactly at the window boundary', () {
      final now = DateTime.utc(2026, 4, 15, 21, 0, 0);

      final result = shouldSkipDuplicateSharedFileIntent(
        signature: '/tmp/meeting.ics',
        lastSignature: '/tmp/meeting.ics',
        lastHandledAt: now.subtract(const Duration(seconds: 3)),
        now: now,
      );

      expect(result, isFalse);
    });
  });

  group('isSupportedSharedCalendarFilePath', () {
    test('accepts ics files case-insensitively', () {
      expect(isSupportedSharedCalendarFilePath('/tmp/meeting.ics'), isTrue);
      expect(isSupportedSharedCalendarFilePath('/tmp/MEETING.ICS'), isTrue);
      expect(isSupportedSharedCalendarFilePath('  /tmp/MEETING.ICS  '), isTrue);
    });

    test('rejects non-ics files', () {
      expect(isSupportedSharedCalendarFilePath('/tmp/meeting.txt'), isFalse);
      expect(isSupportedSharedCalendarFilePath(null), isFalse);
    });
  });
}
