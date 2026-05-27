import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('inbox push pipeline guardrails', () {
    test('flow share pushes route to shared flow details', () async {
      final edgeSource = await File(
        '../supabase/functions/create_flow_share/index.ts',
      ).readAsString();
      final clientSource = await File(
        'lib/data/share_repo.dart',
      ).readAsString();
      final sendPushSource = await File(
        '../supabase/functions/send_push/index.ts',
      ).readAsString();
      final mainSource = await File('lib/main.dart').readAsString();

      expect(edgeSource, contains('type: "flow_share"'));
      expect(edgeSource, contains('kind: "flow_share"'));
      expect(clientSource, contains("'type': 'flow_share'"));
      expect(clientSource, contains("'kind': 'flow_share'"));
      expect(sendPushSource, contains('kind === "flow_share"'));
      expect(sendPushSource, contains('push_kind: "flow_share"'));
      expect(mainSource, contains("kind == 'flow_share'"));
      expect(mainSource, contains("'/shared-flow/"));
    });

    test(
      'legacy native flow share payloads no longer open a DM thread',
      () async {
        final mainSource = await File('lib/main.dart').readAsString();
        final pushNavigationSource = _sourceBetween(
          mainSource,
          'Future<bool> _handlePushNavigation(Map<String, dynamic> data) async {',
          'void _openSharedFlow(String shareId) {',
        );

        expect(pushNavigationSource, contains("shareKind == 'flow'"));
        expect(pushNavigationSource, contains('_openSharedFlow(shareId)'));
        expect(
          pushNavigationSource.indexOf("shareKind == 'flow'"),
          lessThan(pushNavigationSource.indexOf("if (kind == 'dm')")),
        );
      },
    );

    test('follow pushes are sent and routed to the inbox', () async {
      final profileSource = await File(
        'lib/data/profile_repo.dart',
      ).readAsString();
      final sendPushSource = await File(
        '../supabase/functions/send_push/index.ts',
      ).readAsString();
      final mainSource = await File('lib/main.dart').readAsString();

      expect(profileSource, contains('sendFollowPush'));
      expect(profileSource, contains("'type': 'follow'"));
      expect(profileSource, contains("'kind': 'follow'"));
      expect(sendPushSource, contains('kind === "follow"'));
      expect(sendPushSource, contains('push_kind: "follow"'));
      expect(mainSource, contains("if (kind == 'follow')"));
      expect(mainSource, contains("_router.go('/inbox')"));
    });

    test('notification taps remain explicit navigation commands', () async {
      final mainSource = await File('lib/main.dart').readAsString();
      final pushNavigationSource = _sourceBetween(
        mainSource,
        'Future<bool> _handlePushNavigation(Map<String, dynamic> data) async {',
        'void _openSharedFlow(String shareId) {',
      );

      expect(pushNavigationSource, contains("kind == 'maat_guidance'"));
      expect(
        pushNavigationSource,
        contains("deliveryKey.startsWith('maat_guidance:')"),
      );
      expect(pushNavigationSource, contains("'/maat-guidance/"));
      expect(pushNavigationSource, contains("kind == 'decan_reflection'"));
      expect(pushNavigationSource, contains("'/reflections/"));
      expect(pushNavigationSource, contains("kind == 'calendar_event'"));
      expect(
        pushNavigationSource,
        contains("kind == 'scheduled_notification'"),
      );
      expect(pushNavigationSource, contains("kind == 'reminder_10min'"));
      expect(
        pushNavigationSource,
        contains('await _openCalendarEventFromPush(clientEventId)'),
      );
      expect(pushNavigationSource, contains("_router.go('/')"));
    });
  });
}

String _sourceBetween(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  final endIndex = source.indexOf(end, startIndex + start.length);
  if (startIndex < 0 || endIndex < 0) {
    fail('Could not find source range between "$start" and "$end".');
  }
  return source.substring(startIndex, endIndex);
}
