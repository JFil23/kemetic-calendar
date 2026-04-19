import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mobile/services/push_notifications.dart';

void main() {
  group('buildPushOpenedMessageSignature', () {
    test('prefers the message id when present', () {
      final signature = buildPushOpenedMessageSignature({
        'kind': 'decan_reflection',
        'reflectionId': 'abc',
      }, messageId: 'firebase-message-123');

      expect(signature, 'id:firebase-message-123');
    });

    test('normalizes payload maps with different key order', () {
      final first = buildPushOpenedMessageSignature({
        'kind': 'decan_reflection',
        'meta': {'screen': 'profile', 'priority': 1},
        'reflectionId': 'abc',
      });
      final second = buildPushOpenedMessageSignature({
        'reflectionId': 'abc',
        'meta': {'priority': 1, 'screen': 'profile'},
        'kind': 'decan_reflection',
      });

      expect(first, second);
    });
  });

  group('push helper formatting', () {
    test('summarizePushToken keeps long tokens readable', () {
      expect(
        summarizePushToken('abcdefghijklmnopqrstuvwxyz012345'),
        'abcdefgh...yz012345',
      );
      expect(summarizePushToken(null), 'not available');
    });

    test('describePushAuthorizationStatus maps firebase statuses', () {
      expect(
        describePushAuthorizationStatus(AuthorizationStatus.authorized),
        'authorized',
      );
      expect(
        describePushAuthorizationStatus(AuthorizationStatus.denied),
        'denied',
      );
      expect(pushAuthorizationAllowsRegistration(null), isFalse);
      expect(
        pushAuthorizationAllowsRegistration(AuthorizationStatus.provisional),
        isTrue,
      );
    });

    test('retries legacy web push platform constraint failures as unknown', () {
      expect(
        shouldRetryWebPushPlatformAsUnknown(
          'new row for relation "push_tokens" violates check constraint "push_tokens_platform_check"',
        ),
        isTrue,
      );
      expect(
        shouldRetryWebPushPlatformAsUnknown(
          'Check constraint failed for platform value web_push',
        ),
        isTrue,
      );
      expect(
        shouldRetryWebPushPlatformAsUnknown(
          'new row violates row-level security policy',
        ),
        isFalse,
      );
    });

    test('resets browser subscription only when the web push key changed', () {
      expect(
        shouldResetWebPushSubscriptionForKeyChange(null, 'new-public-key'),
        isFalse,
      );
      expect(
        shouldResetWebPushSubscriptionForKeyChange(
          'same-public-key',
          'same-public-key',
        ),
        isFalse,
      );
      expect(
        shouldResetWebPushSubscriptionForKeyChange(
          'old-public-key',
          'new-public-key',
        ),
        isTrue,
      );
    });

    test('auto-recovery only runs when browser permission is granted', () {
      expect(shouldAttemptWebPushAutoRecovery('granted'), isTrue);
      expect(shouldAttemptWebPushAutoRecovery('default'), isFalse);
      expect(shouldAttemptWebPushAutoRecovery('denied'), isFalse);
      expect(shouldAttemptWebPushAutoRecovery(null), isFalse);
    });
  });
}
