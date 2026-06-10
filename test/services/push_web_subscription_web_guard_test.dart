import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('web push subscription cleanup guard', () {
    late String source;

    setUpAll(() async {
      source = await File(
        'lib/services/push_web_subscription_web.dart',
      ).readAsString();
    });

    test(
      'legacy cleanup enumerates registrations instead of matching client URL',
      () {
        final cleanupSource = _sourceBetween(
          source,
          'Future<void> _clearLegacyRegistration(',
          '\nFuture<web.ServiceWorkerRegistration?> _ensureRegistration()',
        );

        expect(cleanupSource, contains('container.getRegistrations()'));
        expect(cleanupSource, isNot(contains('container.getRegistration(')));
        expect(
          cleanupSource,
          contains('_isExactLegacyScope(registration.scope)'),
        );
      },
    );

    test('legacy scope comparison cannot match the current root scope', () {
      final scopeSource = _sourceBetween(
        source,
        'bool _isExactLegacyScope(String scope) {',
        '\nFuture<void> _clearLegacyRegistration(',
      );

      expect(scopeSource, contains('_normalizedScopeUrl(scope)'));
      expect(scopeSource, contains('_normalizedScopeUrl(_workerScopeUrl())'));
      expect(
        scopeSource,
        contains('_normalizedScopeUrl(_legacyWorkerScopeUrl())'),
      );
      expect(
        scopeSource,
        contains(
          'normalizedScope == legacyScope && normalizedScope != rootScope',
        ),
      );
    });

    test(
      'subscribe verifies the root subscription still exists after cleanup',
      () {
        final subscribeSource = _sourceBetween(
          source,
          'Future<String?> subscribeBrowserPush(String publicKey) async {',
          '\nFuture<void> unsubscribeBrowserPush() async {',
        );

        expect(
          subscribeSource,
          contains('await _clearLegacyRegistration(container)'),
        );
        expect(
          subscribeSource,
          contains(
            'final verified = await registration.pushManager.getSubscription()',
          ),
        );
        expect(
          subscribeSource,
          contains('return _subscriptionToJson(verified)'),
        );
        expect(
          subscribeSource,
          contains(
            'Browser push subscription disappeared after legacy service worker cleanup.',
          ),
        );
        expect(
          subscribeSource,
          isNot(contains('return _subscriptionToJson(subscription)')),
        );
      },
    );
  });
}

String _sourceBetween(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  expect(startIndex, isNonNegative, reason: 'Missing source start: $start');
  final endIndex = source.indexOf(end, startIndex + start.length);
  expect(endIndex, isNonNegative, reason: 'Missing source end: $end');
  return source.substring(startIndex, endIndex);
}
