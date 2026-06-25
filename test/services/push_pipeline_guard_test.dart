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

    test('direct message pushes route to the sender conversation', () async {
      final inboxRepoSource = await File(
        'lib/repositories/inbox_repo.dart',
      ).readAsString();
      final sendDmSource = await File(
        '../supabase/functions/send_dm_message/index.ts',
      ).readAsString();
      final sendPushSource = await File(
        '../supabase/functions/send_push/index.ts',
      ).readAsString();
      final mainSource = await File('lib/main.dart').readAsString();
      final initialRouteSource = _sourceBetween(
        mainSource,
        'String? _initialLocationFromPushData(',
        "  if (kind == 'event_invite') {",
      );
      final pushNavigationSource = _sourceBetween(
        mainSource,
        'Future<bool> _handlePushNavigation(Map<String, dynamic> data) async {',
        'void _openSharedFlow(String shareId) {',
      );

      expect(inboxRepoSource, contains("'send_dm_message'"));
      expect(sendDmSource, contains('notification_type: "direct_message"'));
      expect(sendDmSource, contains('conversation_user_id: senderId'));
      expect(sendDmSource, contains('headers.Authorization'));
      expect(sendPushSource, contains('kind === "dm"'));
      expect(sendPushSource, contains('push_kind: "dm"'));
      expect(initialRouteSource, contains("kind == 'dm'"));
      expect(
        initialRouteSource,
        contains("'/inbox/conversation/\${Uri.encodeComponent(senderId)}'"),
      );
      expect(pushNavigationSource, contains("if (kind == 'dm')"));
      expect(
        pushNavigationSource,
        contains('await _openDmConversation(senderId)'),
      );
    });

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
        contains('CalendarPushOpenIntent.fromNotificationData(data)'),
      );
      expect(
        pushNavigationSource,
        contains('await _openCalendarEventFromPush('),
      );
      expect(pushNavigationSource, contains("_router.go('/')"));

      final calendarSource = await File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsString();
      final calendarPushOpenSource = _sourceBetween(
        calendarSource,
        'Future<void> _openCalendarEventFromPush(',
        'TimeOfDay? _timeOfDayFromSession(',
      );
      expect(
        calendarPushOpenSource,
        contains('initialEventDetailRestorationState'),
      );
      expect(calendarPushOpenSource, isNot(contains('_openDaySheet(')));
      expect(calendarSource, contains('onAddNote: (ky, km, kd) =>'));
      expect(calendarSource, contains('_openDaySheet(ky, km, kd'));
    });

    test('decan reflection pushes route directly to reflection detail', () async {
      final mainSource = await File('lib/main.dart').readAsString();
      final initialRouteSource = _sourceBetween(
        mainSource,
        'String? _initialLocationFromPushData(',
        "  final shareKind = _trimmedPushValue(data['share_kind'] ?? data['shareKind']);",
      );
      final pushNavigationSource = _sourceBetween(
        mainSource,
        'Future<bool> _handlePushNavigation(Map<String, dynamic> data) async {',
        'void _openSharedFlow(String shareId) {',
      );

      expect(initialRouteSource, contains("kind == 'decan_reflection'"));
      expect(
        initialRouteSource,
        contains("'/reflections/\${Uri.encodeComponent(reflectionId)}'"),
      );
      expect(initialRouteSource, isNot(contains('node_ref')));
      expect(initialRouteSource, isNot(contains('/nodes/')));
      expect(pushNavigationSource, contains("kind == 'decan_reflection'"));
      expect(
        pushNavigationSource,
        contains(
          "_router.go('/reflections/\${Uri.encodeComponent(reflectionId)}')",
        ),
      );
      final decanReflectionNavigationSource = _sourceBetween(
        pushNavigationSource,
        "if (kind == 'decan_reflection' && reflectionId != null) {",
        "if (kind == 'flow_share'",
      );
      expect(decanReflectionNavigationSource, isNot(contains('node_ref')));
      expect(decanReflectionNavigationSource, isNot(contains('/nodes/')));
    });

    test(
      'cold-start notification intent wins over passive restoration',
      () async {
        final mainSource = await File('lib/main.dart').readAsString();
        final pushSource = await File(
          'lib/services/push_notifications.dart',
        ).readAsString();
        final initialLocationSource = _sourceBetween(
          mainSource,
          'String _resolveInitialLocation()',
          'Future<void> _readBootInitialPushIntent() async',
        );
        final bootPushSource = _sourceBetween(
          mainSource,
          'Future<void> _readBootInitialPushIntent() async',
          'Future<String?> _readBootRestoredLocation() async',
        );
        final launchSuppressionSource = _sourceBetween(
          mainSource,
          'void _suppressPassiveLaunchSurfacesForExplicitIntentIfNeeded()',
          'Future<String?> _readBootRestoredLocation() async',
        );
        final initialTasksSource = _sourceBetween(
          mainSource,
          'void _startInitialTasks()',
          'void _consumePendingWebPushIntent()',
        );
        final mainBootReadSource = _sourceBetween(
          mainSource,
          'await AppWindowService.instance.ensureInitialized();',
          'final initialLocation = _resolveInitialLocation();',
        );
        final normalBootReadSource = _sourceBetween(
          mainBootReadSource,
          '} else {',
          '}\n    ',
        );

        expect(pushSource, contains('class PushInitialMessage'));
        expect(
          pushSource,
          contains('Future<PushInitialMessage?> takeInitialMessage()'),
        );
        expect(bootPushSource, contains('takeInitialMessage'));
        expect(bootPushSource, contains('_pushIntentDataFromQuery'));
        expect(bootPushSource, contains('_initialLocationFromPushData'));
        expect(
          initialLocationSource.indexOf('_bootExplicitIntentLocation'),
          lessThan(initialLocationSource.indexOf('_bootRestoredLocation')),
        );
        expect(
          normalBootReadSource.indexOf('await _readBootInitialPushIntent();'),
          lessThan(normalBootReadSource.indexOf('_bootRestoredLocation =')),
        );
        expect(
          launchSuppressionSource,
          contains('suppressRestoreForExplicitIntent'),
        );
        expect(
          launchSuppressionSource,
          isNot(contains('_deferSessionResumeForPushNavigation')),
        );
        expect(bootPushSource, contains('_consumeBootOneShotLocation'));
        expect(
          launchSuppressionSource,
          contains('RestorationCoordinator.calendarDayViewSurface'),
        );
        expect(
          launchSuppressionSource,
          contains('RestorationCoordinator.calendarOverlayStackSurface'),
        );
        expect(initialTasksSource, contains('_bootInitialPushMessage'));
        expect(
          initialTasksSource,
          contains('recordDeliveryReceiptFromPayload'),
        );
        expect(initialTasksSource, contains('_queueOrHandlePushData'));
      },
    );
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
