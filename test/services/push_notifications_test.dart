import 'package:flutter_test/flutter_test.dart';
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
}
