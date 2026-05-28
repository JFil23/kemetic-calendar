import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_invalidation.dart';

void main() {
  test('published invalidation remains pending without a listener', () {
    final bus = CalendarInvalidationBus();

    bus.publish(
      const CalendarInvalidated(
        reason: CalendarInvalidationReason.flowJoined,
        flowId: 42,
        clientEventIds: <String>['event-a'],
      ),
    );

    final pending = bus.peekPendingAfter(0);
    expect(pending, isNotNull);
    expect(pending!.revision, 1);
    expect(pending.invalidation.reason, CalendarInvalidationReason.flowJoined);
    expect(pending.invalidation.flowId, 42);
    expect(pending.invalidation.clientEventIds, <String>['event-a']);
  });

  test(
    'multiple off-home invalidations collapse into one pending revision',
    () {
      final bus = CalendarInvalidationBus();

      bus
        ..publish(
          const CalendarInvalidated(
            reason: CalendarInvalidationReason.flowJoined,
            flowId: 1,
            clientEventIds: <String>['event-a'],
          ),
        )
        ..publish(
          const CalendarInvalidated(
            reason: CalendarInvalidationReason.flowStudioPersisted,
            flowId: 2,
            clientEventIds: <String>['event-b'],
          ),
        )
        ..publish(
          const CalendarInvalidated(
            reason: CalendarInvalidationReason.flowJoined,
            flowId: 3,
            clientEventIds: <String>['event-c'],
          ),
        );

      final pending = bus.peekPendingAfter(0);
      expect(pending, isNotNull);
      expect(pending!.revision, 3);
      expect(
        pending.invalidation.reason,
        CalendarInvalidationReason.flowJoined,
      );
      expect(pending.invalidation.flowId, 3);
      expect(pending.invalidation.clientEventIds, <String>[
        'event-a',
        'event-b',
        'event-c',
      ]);
    },
  );

  test(
    'pending invalidation is cleared only after its revision is consumed',
    () {
      final bus = CalendarInvalidationBus();

      bus.publish(
        const CalendarInvalidated(
          reason: CalendarInvalidationReason.flowJoined,
          flowId: 1,
        ),
      );
      final first = bus.peekPendingAfter(0);
      expect(first, isNotNull);

      bus.publish(
        const CalendarInvalidated(
          reason: CalendarInvalidationReason.eventSaved,
          flowId: 2,
        ),
      );
      final second = bus.peekPendingAfter(first!.revision);
      expect(second, isNotNull);
      expect(second!.revision, 2);

      bus.markConsumed(first.revision);
      expect(bus.peekPendingAfter(first.revision), isNotNull);

      bus.markConsumed(second.revision);
      expect(bus.peekPendingAfter(0), isNull);
    },
  );

  test('publish still streams invalidations to mounted consumers', () async {
    final bus = CalendarInvalidationBus();
    final seen = <CalendarInvalidated>[];
    final sub = bus.stream.listen(seen.add);

    bus.publish(
      const CalendarInvalidated(
        reason: CalendarInvalidationReason.flowJoined,
        flowId: 7,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(seen, hasLength(1));
    expect(seen.single.flowId, 7);
    await sub.cancel();
  });
}
