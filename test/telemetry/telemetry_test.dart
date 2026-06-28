import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/telemetry/telemetry.dart';

void main() {
  group('redactLogText', () {
    test('redacts bearer tokens, url tokens, uuids, and emails', () {
      final redacted = redactLogText(
        'Bearer abc.def token=secret access_token=abc '
        'user=123e4567-e89b-12d3-a456-426614174000 hi@example.com',
      );

      expect(redacted, contains('Bearer <redacted>'));
      expect(redacted, contains('token=<redacted>'));
      expect(redacted, contains('access_token=<redacted>'));
      expect(redacted, contains('user=<uuid>'));
      expect(redacted, contains('<email>'));
      expect(redacted, isNot(contains('secret')));
      expect(redacted, isNot(contains('hi@example.com')));
    });

    test('summarizes payload maps without private event content', () {
      final summary = safeLogMapSummary({
        'user_id': '123e4567-e89b-12d3-a456-426614174000',
        'title': 'Therapy appointment',
        'location': 'Private office',
        'detail': 'Discuss sensitive notes',
        'payload_json': {
          'name': 'Hidden flow name',
          'body': 'Private event body',
        },
        'starts_at': '2026-06-01T12:00:00Z',
        'all_day': false,
      });

      expect(summary, contains('redactedKeys='));
      expect(summary, contains('title'));
      expect(summary, contains('location'));
      expect(summary, contains('payload_json'));
      expect(summary, contains('safeKeys=all_day,starts_at'));
      expect(summary, isNot(contains('Therapy appointment')));
      expect(summary, isNot(contains('Private office')));
      expect(summary, isNot(contains('Hidden flow name')));
      expect(summary, isNot(contains('123e4567')));
    });

    test('summarizes collections without row payload values', () {
      final summary = safeLogCollectionSummary([
        {'title': 'Recital', 'location': 'Private hall'},
      ]);

      expect(summary, 'list<size=1>');
      expect(summary, isNot(contains('Recital')));
      expect(summary, isNot(contains('Private hall')));
    });
  });

  group('ScreenViewDedupe', () {
    test('dedupes the same route within the visible session window', () {
      final dedupe = ScreenViewDedupe(window: const Duration(seconds: 2));
      final start = DateTime(2026);

      expect(dedupe.shouldTrack('/calendar', start), isTrue);
      expect(
        dedupe.shouldTrack(
          '/calendar',
          start.add(const Duration(milliseconds: 500)),
        ),
        isFalse,
      );
      expect(
        dedupe.shouldTrack('/calendar', start.add(const Duration(seconds: 3))),
        isTrue,
      );
    });

    test('allows a different route immediately', () {
      final dedupe = ScreenViewDedupe();
      final start = DateTime(2026);

      expect(dedupe.shouldTrack('/calendar', start), isTrue);
      expect(dedupe.shouldTrack('/inbox', start), isTrue);
    });
  });
}
