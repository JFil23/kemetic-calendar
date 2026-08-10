import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/end_flow_visibility_store.dart';

void main() {
  final store = EndFlowVisibilityStore.instance;

  setUp(store.debugReset);
  tearDown(store.debugReset);

  test('pending, committed, and absent transitions are synchronous', () {
    var notifications = 0;
    void listener() => notifications += 1;
    store.addListener(listener);
    addTearDown(() => store.removeListener(listener));

    store.markPending(41);
    expect(store.stateFor(41), EndFlowVisibilityState.pending);
    expect(store.isHidden(41), isTrue);
    expect(store.hiddenFlowIds, <int>{41});

    store.markCommitted(41);
    expect(store.stateFor(41), EndFlowVisibilityState.committed);
    expect(store.isHidden(41), isTrue);

    store.remove(41);
    expect(store.stateFor(41), isNull);
    expect(store.isHidden(41), isFalse);
    expect(notifications, 3);
  });

  test('different flow ids remain isolated', () {
    store.markPending(51);
    store.markPending(52);
    store.markCommitted(51);
    store.remove(52);

    expect(store.stateFor(51), EndFlowVisibilityState.committed);
    expect(store.stateFor(52), isNull);
    expect(store.hiddenFlowIds, <int>{51});
  });

  test('duplicate transitions do not emit redundant notifications', () {
    var notifications = 0;
    void listener() => notifications += 1;
    store.addListener(listener);
    addTearDown(() => store.removeListener(listener));

    store.markPending(61);
    store.markPending(61);
    store.markCommitted(61);
    store.markCommitted(61);
    store.remove(61);
    store.remove(61);

    expect(notifications, 3);
  });

  test('committed entries cannot be downgraded to pending', () {
    store.markCommitted(71);
    store.markPending(71);
    store.removePending(71);

    expect(store.stateFor(71), EndFlowVisibilityState.committed);
  });
}
