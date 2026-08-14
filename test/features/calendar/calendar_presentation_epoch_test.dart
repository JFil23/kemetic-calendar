import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_presentation_epoch.dart';

void main() {
  test(
    'extent projection and geometry stage together until gesture settles',
    () {
      final activated = <CalendarPresentationEpoch<String>>[];
      final coordinator = CalendarPresentationEpochCoordinator<String>(
        activate: activated.add,
        clearUserScope: (_) {},
      );
      final gesture = coordinator.begin(
        kind: CalendarPresentationTransactionKind.gesture,
        userScope: 'user-a',
      );

      expect(coordinator.publish(_epoch(1, projection: 'first')), isFalse);
      expect(coordinator.publish(_epoch(2, projection: 'latest')), isFalse);
      expect(activated, isEmpty);

      coordinator.settle(gesture);

      expect(activated.map((epoch) => epoch.projection), <String>['latest']);
      expect(activated.single.geometryRevision, 'geometry-2');
    },
  );

  test('non-extent update can publish during a gesture', () {
    final activated = <CalendarPresentationEpoch<String>>[];
    final coordinator = CalendarPresentationEpochCoordinator<String>(
      activate: activated.add,
      clearUserScope: (_) {},
    );
    coordinator.begin(
      kind: CalendarPresentationTransactionKind.gesture,
      userScope: 'user-a',
    );

    expect(
      coordinator.publish(
        _epoch(1, projection: 'color-only', extentAffecting: false),
      ),
      isTrue,
    );
    expect(activated.single.projection, 'color-only');
  });

  test('non-extent update coalesces after an extent epoch is staged', () {
    final activated = <CalendarPresentationEpoch<String>>[];
    final coordinator = CalendarPresentationEpochCoordinator<String>(
      activate: activated.add,
      clearUserScope: (_) {},
    );
    final gesture = coordinator.begin(
      kind: CalendarPresentationTransactionKind.gesture,
      userScope: 'user-a',
    );
    coordinator.publish(_epoch(1, projection: 'extent'));

    expect(
      coordinator.publish(
        _epoch(2, projection: 'extent-plus-color', extentAffecting: false),
      ),
      isFalse,
    );
    coordinator.settle(gesture);

    expect(activated.single.projection, 'extent-plus-color');
  });

  test(
    'nested Today and gesture transactions flush only after both settle',
    () {
      final activated = <CalendarPresentationEpoch<String>>[];
      final coordinator = CalendarPresentationEpochCoordinator<String>(
        activate: activated.add,
        clearUserScope: (_) {},
      );
      final gesture = coordinator.begin(
        kind: CalendarPresentationTransactionKind.gesture,
        userScope: 'user-a',
      );
      final today = coordinator.begin(
        kind: CalendarPresentationTransactionKind.today,
        userScope: 'user-a',
      );
      coordinator.publish(_epoch(1, projection: 'arrival'));

      coordinator.settle(gesture);
      expect(activated, isEmpty);
      coordinator.settle(today);
      expect(activated.single.projection, 'arrival');
    },
  );

  test('account switch discards pending previous-user projection', () {
    final activated = <CalendarPresentationEpoch<String>>[];
    final cleared = <String>[];
    final coordinator = CalendarPresentationEpochCoordinator<String>(
      activate: activated.add,
      clearUserScope: cleared.add,
    );
    final gesture = coordinator.begin(
      kind: CalendarPresentationTransactionKind.gesture,
      userScope: 'user-a',
    );
    coordinator.publish(_epoch(1, projection: 'private-a'));

    coordinator.changeUserScope('user-b');
    coordinator.settle(gesture);

    expect(activated, isEmpty);
    expect(cleared, <String>['user-a']);
    expect(coordinator.pending, isNull);
  });

  test('stale epoch cannot replace a newer active projection', () {
    final activated = <CalendarPresentationEpoch<String>>[];
    final coordinator = CalendarPresentationEpochCoordinator<String>(
      activate: activated.add,
      clearUserScope: (_) {},
    );

    expect(coordinator.publish(_epoch(4, projection: 'new')), isTrue);
    expect(coordinator.publish(_epoch(3, projection: 'old')), isFalse);
    expect(activated.map((epoch) => epoch.projection), <String>['new']);
  });
}

CalendarPresentationEpoch<String> _epoch(
  int sequence, {
  required String projection,
  bool extentAffecting = true,
}) => CalendarPresentationEpoch<String>(
  userScope: 'user-a',
  sequence: sequence,
  viewRevision: 'view-$sequence',
  geometryRevision: 'geometry-$sequence',
  extentAffecting: extentAffecting,
  affectedSections: extentAffecting ? <String>{'139-1'} : const <String>{},
  projection: projection,
);
