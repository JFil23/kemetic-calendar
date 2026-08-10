import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_invalidation.dart';
import 'package:mobile/features/calendar/calendar_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    CalendarPage.debugResetEndFlowCoordinatorForTesting();
    CalendarPage.debugFlowEndUserScopeForTesting = 'end-flow-test-user';
    CalendarPage.debugClearFlowEndCacheForTesting = () async {};
  });

  tearDown(CalendarPage.debugResetEndFlowCoordinatorForTesting);

  test(
    'same-flow callers join and publish only after the RPC commits',
    () async {
      final rpc = Completer<EndFlowActionResult>();
      final published = <CalendarInvalidated>[];
      var rpcCalls = 0;
      CalendarPage.debugEndFlowRpcForTesting = (flowId, endedAtLocal) {
        rpcCalls += 1;
        return rpc.future;
      };
      CalendarPage.debugPublishFlowEndForTesting = published.add;

      final first = CalendarPage.debugRunEndFlowForTesting(41);
      final joined = CalendarPage.debugRunEndFlowForTesting(41);

      expect(identical(first, joined), isTrue);
      expect(rpcCalls, 1);
      expect(CalendarPage.debugIsFlowEndPendingForTesting(41), isTrue);
      expect(published, isEmpty);

      rpc.complete(EndFlowActionResult.success);

      expect(await first, EndFlowActionResult.success);
      expect(await joined, EndFlowActionResult.success);
      expect(CalendarPage.debugIsFlowEndPendingForTesting(41), isFalse);
      expect(published, hasLength(1));
      expect(
        published.single.reason,
        CalendarInvalidationReason.flowEndedCommitted,
      );
      expect(published.single.flowId, 41);
    },
  );

  test(
    'simultaneous ends retain independent pending and commit state',
    () async {
      final rpcs = <int, Completer<EndFlowActionResult>>{
        51: Completer<EndFlowActionResult>(),
        52: Completer<EndFlowActionResult>(),
      };
      final publishedFlowIds = <int>[];
      CalendarPage.debugEndFlowRpcForTesting = (flowId, endedAtLocal) =>
          rpcs[flowId]!.future;
      CalendarPage.debugPublishFlowEndForTesting = (invalidation) {
        publishedFlowIds.add(invalidation.flowId!);
      };

      final first = CalendarPage.debugRunEndFlowForTesting(51);
      final second = CalendarPage.debugRunEndFlowForTesting(52);

      expect(CalendarPage.debugIsFlowEndPendingForTesting(51), isTrue);
      expect(CalendarPage.debugIsFlowEndPendingForTesting(52), isTrue);

      rpcs[51]!.complete(EndFlowActionResult.success);
      expect(await first, EndFlowActionResult.success);
      expect(publishedFlowIds, <int>[51]);
      expect(CalendarPage.debugIsFlowEndPendingForTesting(51), isFalse);
      expect(CalendarPage.debugIsFlowEndPendingForTesting(52), isTrue);

      rpcs[52]!.complete(EndFlowActionResult.success);
      expect(await second, EndFlowActionResult.success);
      expect(publishedFlowIds, <int>[51, 52]);
      expect(CalendarPage.debugIsFlowEndPendingForTesting(52), isFalse);
    },
  );
}
