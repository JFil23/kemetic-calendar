import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_warm_start_cache_identity.dart';

void main() {
  group('calendar warm-start backend identity', () {
    test('keeps the canonical Supabase project-ref key stable', () {
      expect(
        calendarWarmStartProjectRefFromUrl(
          'https://abcdefghijklmnop.supabase.co',
        ),
        'abcdefghijklmnop',
      );
    });

    test('namespaces an authenticated custom HTTPS Supabase origin', () {
      expect(
        calendarWarmStartProjectRefFromUrl(
          'https://calendar-isolated.trycloudflare.com',
        ),
        'custom_https_calendar-isolated_trycloudflare_com_443',
      );
    });

    test('does not alias distinct custom backend origins', () {
      final first = calendarWarmStartProjectRefFromUrl(
        'https://calendar-a.example.test',
      );
      final second = calendarWarmStartProjectRefFromUrl(
        'https://calendar-b.example.test',
      );

      expect(first, isNotNull);
      expect(second, isNotNull);
      expect(first, isNot(second));
    });

    test('still rejects malformed and non-http backend URLs', () {
      expect(calendarWarmStartProjectRefFromUrl('not a url'), isNull);
      expect(
        calendarWarmStartProjectRefFromUrl('file:///tmp/supabase'),
        isNull,
      );
    });
  });
}
