import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_invalidation.dart';
import 'package:mobile/features/calendar/calendar_load_coordinator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('page wiring replaces load flag and invalidation flush helpers', () {
    final source = File('lib/features/calendar/calendar_page.dart').readAsStringSync();
    expect(source.contains('_isLoadingFromDisk'), isFalse);
    expect(source.contains('_flushCalendarInvalidationReload'), isFalse);
    expect(source.contains('_handleCalendarInvalidated'), isFalse);
    expect(source.contains('_scheduleCalendarInvalidationReload'), isFalse);
    expect(source.contains('CalendarLoadCoordinator _loadCoordinator'), isTrue);
    expect(source.contains('_loadCoordinator.attach()'), isTrue);
    expect(source.contains("_loadCoordinator.invalidate(reason: 'signed_out')"), isTrue);
    expect(source.contains('Future<void> _loadFromDiskInner({'), isTrue);
    expect(
      source.contains(
        "if (!_loadCoordinator.isCurrent(epoch)) return;\n"
        "        if (_activeWarmStartUserId() != loadUserId) return;",
      ),
      isTrue,
      reason: 'both commit and finish sites must share epoch+same-user guards',
    );
    expect(
      RegExp(
        r"if \(!_loadCoordinator\.isCurrent\(epoch\)\) return;\n"
        r"\s+if \(_activeWarmStartUserId\(\) != loadUserId\) return;",
      ).allMatches(source).length,
      2,
    );
  });

  late CalendarInvalidationBus bus;
  late bool mounted;
  late bool deferred;
  late List<({String source, bool preserveViewport, int epoch})> runs;
  late Completer<void>? gate;
  late Object? throwOnRun;

  CalendarLoadCoordinator buildCoordinator({
    Duration debounce = const Duration(milliseconds: 20),
  }) {
    return CalendarLoadCoordinator(
      bus: bus,
      isMounted: () => mounted,
      isDeferred: () => deferred,
      debounce: debounce,
      runner: ({
        required String source,
        required bool preserveViewport,
        required int epoch,
      }) async {
        runs.add((
          source: source,
          preserveViewport: preserveViewport,
          epoch: epoch,
        ));
        final wait = gate;
        if (wait != null) await wait.future;
        final err = throwOnRun;
        if (err != null) throw err;
      },
    );
  }

  setUp(() {
    bus = CalendarInvalidationBus();
    mounted = true;
    deferred = false;
    runs = <({String source, bool preserveViewport, int epoch})>[];
    gate = null;
    throwOnRun = null;
  });

  test('1. concurrent request drains queue and resolves waiters together', () async {
    gate = Completer<void>();
    final coordinator = buildCoordinator();

    final first = coordinator.request(source: 'a');
    final second = coordinator.request(source: 'b');

    await Future<void>.delayed(Duration.zero);
    expect(runs.length, 1);
    expect(runs.first.source, 'a');

    var firstDone = false;
    var secondDone = false;
    unawaited(first.then((_) => firstDone = true));
    unawaited(second.then((_) => secondDone = true));
    await Future<void>.delayed(Duration.zero);
    expect(firstDone, isFalse);
    expect(secondDone, isFalse);

    gate!.complete();
    await Future.wait(<Future<void>>[first, second]);

    expect(runs.length, 2);
    expect(runs.map((r) => r.source).toList(), <String>['a', 'b']);
    expect(firstDone, isTrue);
    expect(secondDone, isTrue);
    coordinator.dispose();
  });

  test('2a. runner throw sets lastPassSucceeded false', () async {
    throwOnRun = StateError('boom');
    final coordinator = buildCoordinator();

    await coordinator.request(source: 'fail');

    expect(coordinator.lastPassSucceeded, isFalse);
    expect(runs.length, 1);
    coordinator.dispose();
  });

  test('2b. failed invalidation pass does not markConsumed', () async {
    throwOnRun = StateError('boom');
    final coordinator = buildCoordinator(
      debounce: const Duration(milliseconds: 10),
    );
    coordinator.attach();

    bus.publish(
      const CalendarInvalidated(
        reason: CalendarInvalidationReason.eventSaved,
        clientEventIds: <String>['cid-1'],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(runs, isNotEmpty);
    expect(coordinator.lastPassSucceeded, isFalse);
    final pending = bus.peekPendingAfter(0);
    expect(pending, isNotNull, reason: 'failed pass must leave revision pending');
    expect(pending!.revision, 1);
    coordinator.dispose();
  });

  test('3. invalidate mid-pass retires that epoch', () async {
    gate = Completer<void>();
    final coordinator = buildCoordinator();

    final pending = coordinator.request(source: 'in-flight');
    await Future<void>.delayed(Duration.zero);
    expect(runs.length, 1);
    final inFlightEpoch = runs.first.epoch;
    expect(coordinator.isCurrent(inFlightEpoch), isTrue);

    coordinator.invalidate(reason: 'test');
    expect(coordinator.isCurrent(inFlightEpoch), isFalse);

    gate!.complete();
    await pending;
    coordinator.dispose();
  });

  test('4a. invalidation while deferred waits until gate clears', () async {
    deferred = true;
    final coordinator = buildCoordinator(
      debounce: const Duration(milliseconds: 10),
    );
    coordinator.attach();

    bus.publish(
      const CalendarInvalidated(
        reason: CalendarInvalidationReason.flowJoined,
        flowId: 9,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(runs, isEmpty);

    deferred = false;
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(runs.length, 1);
    expect(runs.first.source, startsWith('invalidation:'));
    expect(coordinator.lastPassSucceeded, isTrue);
    expect(bus.peekPendingAfter(0), isNull);
    coordinator.dispose();
  });

  test('4b. direct request while deferred runs immediately', () async {
    deferred = true;
    final coordinator = buildCoordinator();

    await coordinator.request(source: 'explicit');

    expect(runs.length, 1);
    expect(runs.first.source, 'explicit');
    coordinator.dispose();
  });
}
