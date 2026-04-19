import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mobile/utils/external_link_utils.dart';

void main() {
  group('external link utils', () {
    test('normalizes trailing punctuation on pasted links', () {
      expect(
        normalizeExternalLinkToken('https://meet.google.com/abc-defg-hij).'),
        'https://meet.google.com/abc-defg-hij',
      );
    });

    test('builds https URI for bare service domains', () {
      final uri = buildExternalLaunchUri('zoom.us/j/123456789');
      expect(uri?.toString(), 'https://zoom.us/j/123456789');
    });

    test('builds maps URI for plain addresses', () {
      final uri = buildExternalLaunchUri('123 Main St Los Angeles CA');
      expect(
        uri?.toString(),
        'https://maps.google.com/?q=123%20Main%20St%20Los%20Angeles%20CA',
      );
    });

    test('matches direct links in freeform detail text', () {
      final matches = externalLinkPattern
          .allMatches(
            'Open www.youtube.com/watch?v=abc123, then join https://zoom.us/j/999.',
          )
          .map((match) => normalizeExternalLinkToken(match.group(0)!))
          .toList();

      expect(matches, [
        'www.youtube.com/watch?v=abc123',
        'https://zoom.us/j/999',
      ]);
    });

    test('prefers native app launch for supported service hosts', () {
      final modes = preferredLaunchModesForUri(
        Uri.parse('https://www.youtube.com/watch?v=abc123'),
      );

      expect(modes.first, LaunchMode.externalNonBrowserApplication);
      expect(modes, contains(LaunchMode.inAppBrowserView));
    });

    test('falls back to browser launch modes for generic web links', () {
      final modes = preferredLaunchModesForUri(
        Uri.parse('https://flutter.dev'),
      );

      expect(modes.first, LaunchMode.externalApplication);
      expect(modes, isNot(contains(LaunchMode.externalNonBrowserApplication)));
    });
  });
}
