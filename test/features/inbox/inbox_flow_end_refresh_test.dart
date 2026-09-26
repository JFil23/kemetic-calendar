import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/data/share_models.dart';
import 'package:mobile/data/shared_practice_models.dart';
import 'package:mobile/features/calendar/calendar_invalidation.dart';
import 'package:mobile/features/inbox/inbox_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    try {
      Supabase.instance.client;
    } catch (_) {
      await Supabase.initialize(
        url: 'https://example.supabase.test',
        anonKey: 'test-anon-key',
        httpClient: _RejectingClient(),
        authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      );
    }
  });

  testWidgets('an already-open Inbox refreshes after committed End Flow', (
    tester,
  ) async {
    final inboxStream = StreamController<List<InboxShareItem>>.broadcast();
    final flowLifecycleStream = StreamController<CalendarInvalidated>.broadcast(
      sync: true,
    );
    addTearDown(inboxStream.close);
    addTearDown(flowLifecycleStream.close);
    final applied = <List<InboxShareItem>>[];
    final committedLoadObserved = Completer<void>();
    var committedLoads = 0;
    final active = _flowShare(currentlyActiveImportedFlowId: 73);
    final ended = _flowShare();

    await tester.pumpWidget(
      MaterialApp(
        home: InboxPage(
          inboxItemsStreamForTesting: inboxStream.stream,
          committedFlowItemsLoaderForTesting: () async {
            committedLoads += 1;
            if (!committedLoadObserved.isCompleted) {
              committedLoadObserved.complete();
            }
            return <InboxShareItem>[ended];
          },
          onInboxItemsAppliedForTesting: applied.add,
          flowLifecycleStreamForTesting: flowLifecycleStream.stream,
          disableAuxiliarySubscriptionsForTesting: true,
        ),
      ),
    );

    inboxStream.add(<InboxShareItem>[active]);
    await tester.pump();
    expect(applied.last.single.isCurrentlyImported, isTrue);
    expect(flowLifecycleStream.hasListener, isTrue);

    flowLifecycleStream.add(
      const CalendarInvalidated(
        reason: CalendarInvalidationReason.flowEndedCommitted,
        flowId: 73,
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => committedLoadObserved.future.timeout(const Duration(seconds: 2)),
    );
    await tester.pumpAndSettle();

    expect(committedLoads, 1);
    expect(applied.last.single.isCurrentlyImported, isFalse);
  });

  testWidgets('an already-open Inbox receives a Together request', (
    tester,
  ) async {
    final inboxStream = StreamController<List<InboxShareItem>>.broadcast();
    final togetherChanges = StreamController<void>.broadcast();
    addTearDown(inboxStream.close);
    addTearDown(togetherChanges.close);
    var togetherLoads = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: InboxPage(
          inboxItemsStreamForTesting: inboxStream.stream,
          flowLifecycleStreamForTesting:
              const Stream<CalendarInvalidated>.empty(),
          disableAuxiliarySubscriptionsForTesting: true,
          togetherInboxChangesStreamForTesting: togetherChanges.stream,
          togetherInboxLoaderForTesting: () async {
            togetherLoads += 1;
            return const TogetherInboxSnapshot(
              joinRequests: <SharedPracticeJoinRequest>[
                SharedPracticeJoinRequest(
                  id: 'request-1',
                  roomId: 'room-1',
                  requesterId: 'friend-1',
                  status: 'pending',
                  requesterDisplayName: 'Amina',
                  title: 'Dawn Strength Practice',
                ),
              ],
            );
          },
        ),
      ),
    );
    inboxStream.add(const <InboxShareItem>[]);
    await tester.pump();
    expect(find.text('PRACTICE TOGETHER'), findsNothing);

    togetherChanges.add(null);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();

    expect(togetherLoads, 1);
    await tester.drag(find.byType(ListView).first, const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('PRACTICE TOGETHER'), findsWidgets);
    expect(find.text('Amina wants to practice together'), findsOneWidget);
    expect(find.text('Dawn Strength Practice'), findsOneWidget);
  });
}

InboxShareItem _flowShare({int? currentlyActiveImportedFlowId}) {
  return InboxShareItem(
    shareId: '11111111-1111-4111-8111-111111111111',
    kind: InboxShareKind.flow,
    recipientId: 'recipient',
    senderId: 'sender',
    payloadId: 'shared-flow',
    title: 'Shared practice',
    createdAt: DateTime.utc(2026, 8, 9),
    importedAt: DateTime.utc(2026, 8, 8),
    currentlyActiveImportedFlowId: currentlyActiveImportedFlowId,
  );
}

class _RejectingClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream<List<int>>.value(const <int>[]),
      500,
      request: request,
    );
  }
}
