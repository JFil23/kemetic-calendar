import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/app_link_intent.dart';

void main() {
  group('AppLinkIntent.parse', () {
    test('parses auth callbacks', () {
      final intent = AppLinkIntent.parse(
        Uri.parse('kemet.app://login-callback?code=abc123'),
      );

      expect(intent, isA<AuthAppLinkIntent>());
      expect((intent as AuthAppLinkIntent).uri.queryParameters['code'], 'abc123');
    });

    test('parses auth callbacks from fragment tokens', () {
      final intent = AppLinkIntent.parse(
        Uri.parse(
          'kemet.app://login-callback#access_token=abc123&refresh_token=xyz456',
        ),
      );

      expect(intent, isA<AuthAppLinkIntent>());
    });

    test('parses share links from query parameters', () {
      final intent = AppLinkIntent.parse(
        Uri.parse('https://maat.app/inbox?share=share-123&token=secret'),
      );

      expect(intent, isA<ShareAppLinkIntent>());
      expect((intent as ShareAppLinkIntent).routeLocation, '/share/share-123?token=secret');
    });

    test('trims share ids and prefers explicit query share ids', () {
      final intent = AppLinkIntent.parse(
        Uri.parse('https://maat.app/share/path-share?share=%20share-123%20&t=%20secret%20'),
      );

      expect(intent, isA<ShareAppLinkIntent>());
      expect((intent as ShareAppLinkIntent).routeLocation, '/share/share-123?token=secret');
    });

    test('parses share links from maat.app path segments', () {
      final intent = AppLinkIntent.parse(
        Uri.parse('https://maat.app/share/share-456'),
      );

      expect(intent, isA<ShareAppLinkIntent>());
      expect((intent as ShareAppLinkIntent).routeLocation, '/share/share-456');
    });

    test('parses custom-scheme share links', () {
      final intent = AppLinkIntent.parse(
        Uri.parse('maat://share/share-789?t=invite-token'),
      );

      expect(intent, isA<ShareAppLinkIntent>());
      expect((intent as ShareAppLinkIntent).routeLocation, '/share/share-789?token=invite-token');
    });

    test('parses documented maat flow links', () {
      final intent = AppLinkIntent.parse(
        Uri.parse('maat://flow/123?share=share-999&token=secret-token'),
      );

      expect(intent, isA<ShareAppLinkIntent>());
      expect((intent as ShareAppLinkIntent).routeLocation, '/share/share-999?token=secret-token');
    });

    test('parses maat.app short links', () {
      final intent = AppLinkIntent.parse(
        Uri.parse('https://www.maat.app/f/share-short-id'),
      );

      expect(intent, isA<ShareAppLinkIntent>());
      expect((intent as ShareAppLinkIntent).routeLocation, '/share/share-short-id');
    });

    test('parses maat custom-scheme short links', () {
      final intent = AppLinkIntent.parse(
        Uri.parse('maat://f/share-short-id?t=short-token'),
      );

      expect(intent, isA<ShareAppLinkIntent>());
      expect(
        (intent as ShareAppLinkIntent).routeLocation,
        '/share/share-short-id?token=short-token',
      );
    });

    test('ignores empty share identifiers', () {
      final intent = AppLinkIntent.parse(
        Uri.parse('https://maat.app/share/%20%20?t=secret'),
      );

      expect(intent, isNull);
    });

    test('ignores unsupported links', () {
      final intent = AppLinkIntent.parse(Uri.parse('file:///tmp/example.ics'));

      expect(intent, isNull);
    });
  });
}
