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

    test('extractWebPushEndpoint reads endpoint from subscription json', () {
      expect(
        extractWebPushEndpoint(
          '{"endpoint":"https://web.push.apple.com/example","keys":{"p256dh":"a","auth":"b"}}',
        ),
        'https://web.push.apple.com/example',
      );
      expect(extractWebPushEndpoint('not-json'), isNull);
      expect(extractWebPushEndpoint(null), isNull);
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

    test('web readiness fails when browser subscription is missing', () {
      final diagnostics = _diagnostics(
        platform: 'web_push',
        databaseRegistered: true,
        registeredToken: _webSubscriptionJson('https://push.example/stale'),
      );

      expect(diagnostics.currentDeviceReadyForPush, isFalse);
      expect(
        diagnostics.currentDeviceReadinessIssue,
        contains('browser subscription is missing'),
      );
    });

    test('web readiness requires the server token to match the browser', () {
      final token = _webSubscriptionJson('https://push.example/current');

      expect(
        _diagnostics(
          platform: 'web_push',
          databaseRegistered: true,
          registeredToken: token,
          browserSubscriptionToken: token,
        ).currentDeviceReadyForPush,
        isTrue,
      );
      expect(
        _diagnostics(
          platform: 'web_push',
          databaseRegistered: true,
          registeredToken: _webSubscriptionJson('https://push.example/stale'),
          browserSubscriptionToken: token,
        ).currentDeviceReadyForPush,
        isFalse,
      );
    });

    test('native readiness does not require a browser subscription', () {
      final diagnostics = _diagnostics(
        platform: 'ios',
        databaseRegistered: true,
        registeredToken: 'native-fcm-token',
      );

      expect(diagnostics.currentDeviceReadyForPush, isTrue);
      expect(diagnostics.currentDeviceReadinessIssue, isNull);
    });

    test('delivery receipt helpers read delivery keys and kinds', () {
      expect(
        pushDeliveryKeyFromData({'delivery_key': 'reminder:abc'}),
        'reminder:abc',
      );
      expect(
        pushDeliveryKeyFromData({'deliveryKey': 'maat_guidance:def'}),
        'maat_guidance:def',
      );
      expect(
        pushDeliveryKindFromData({
          'delivery_key': 'reminder:abc',
          'kind': 'calendar_event',
        }),
        'calendar_event',
      );
      expect(
        pushDeliveryKindFromData({'delivery_key': 'decan_reflection:abc'}),
        'decan_reflection',
      );
      expect(isPushDeliveryReceiptEvent('opened'), isTrue);
      expect(isPushDeliveryReceiptEvent('invented'), isFalse);
    });

    test('delivery receipt status parses function response rows', () {
      final status = PushDeliveryReceiptStatus.fromFunctionData({
        'delivery_key': 'push_test:user:device:time',
        'status': 'found',
        'receipt': {
          'delivery_key': 'push_test:user:device:time',
          'delivery_kind': 'push_test',
          'receipt_status': 'opened',
          'sent_at': '2026-05-23T05:00:00.000Z',
          'first_opened_at': '2026-05-23T05:00:12.000Z',
          'receipt_event_count': 2,
          'open_latency_seconds': 12,
        },
      });

      expect(status.found, isTrue);
      expect(status.opened, isTrue);
      expect(status.deliveryKind, 'push_test');
      expect(status.receiptStatus, 'opened');
      expect(status.receiptEventCount, 2);
      expect(status.openLatencySeconds, 12);
      expect(
        status.firstOpenedAt?.toUtc().toIso8601String(),
        '2026-05-23T05:00:12.000Z',
      );
    });
  });
}

PushRegistrationDiagnostics _diagnostics({
  required String platform,
  bool hasSession = true,
  bool firebaseReady = true,
  bool permissionGranted = true,
  String permissionStatus = 'granted',
  bool databaseRegistered = false,
  String? registeredToken,
  String? browserSubscriptionToken,
}) {
  return PushRegistrationDiagnostics(
    checkedAt: DateTime.utc(2026, 6, 10),
    firebaseReady: firebaseReady,
    permissionStatus: permissionStatus,
    permissionGranted: permissionGranted,
    platform: platform,
    hasSession: hasSession,
    databaseRegistered: databaseRegistered,
    browserSubscriptionPresent:
        browserSubscriptionToken != null && browserSubscriptionToken.isNotEmpty,
    registeredToken: registeredToken,
    browserSubscriptionToken: browserSubscriptionToken,
  );
}

String _webSubscriptionJson(String endpoint) {
  return '{"endpoint":"$endpoint","keys":{"p256dh":"a","auth":"b"}}';
}
