import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/user_events_repo.dart';
import 'package:mobile/features/calendar/calendar_hydration_diagnostics.dart';
import 'package:mobile/features/calendar/hydration/calendar_hydration_models.dart';
import 'package:mobile/features/calendar/hydration/calendar_hydration_repository.dart';

void main() {
  final interval = CalendarHydrationInterval(
    startUtc: DateTime.utc(2026, 8, 1),
    endUtc: DateTime.utc(2026, 8, 2),
  );

  test('runs lanes sequentially and returns one atomic result', () async {
    final calls = <String>[];
    final repo = CalendarHydrationRepository(
      loadCatalog: (_) async => CalendarHydrationCatalogSnapshot(const []),
      loadFlowLane: (ids, range, context) async {
        calls.add('flow');
        return const HydrationFetchResult.successfulEmpty(<FlowEventRow>[]);
      },
      loadStandaloneLane: (range, owners, context) async {
        calls.add('standalone');
        return const HydrationFetchResult.successfulEmpty((
          events: <StandaloneEventRow>[],
          ghostEventIds: <String>[],
          pageCount: 1,
          rawCount: 0,
        ));
      },
    );

    final result = await repo.fetchWindow(
      interval: interval,
      catalogFingerprint: 'catalog',
      flowIds: const <int>{1},
      flowOwnersById: const {},
      cancellationCheck: () => calls.add('check'),
    );

    expect(calls, <String>['check', 'flow', 'check', 'standalone', 'check']);
    expect(result.succeeded, isTrue);
  });

  test(
    'failed flow lane prevents standalone request and cannot succeed',
    () async {
      var standaloneCalls = 0;
      final repo = CalendarHydrationRepository(
        loadCatalog: (_) async => CalendarHydrationCatalogSnapshot(const []),
        loadFlowLane: (ids, range, context) async =>
            const HydrationFetchResult.failed(<FlowEventRow>[]),
        loadStandaloneLane: (range, owners, context) async {
          standaloneCalls++;
          return const HydrationFetchResult.successfulEmpty((
            events: <StandaloneEventRow>[],
            ghostEventIds: <String>[],
            pageCount: 1,
            rawCount: 0,
          ));
        },
      );

      final result = await repo.fetchWindow(
        interval: interval,
        catalogFingerprint: 'catalog',
        flowIds: const <int>{1},
        flowOwnersById: const {},
        cancellationCheck: () {},
      );

      expect(result.succeeded, isFalse);
      expect(standaloneCalls, 0);
    },
  );
}
