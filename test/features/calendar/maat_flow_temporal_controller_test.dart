import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/maat_flow_identity.dart';
import 'package:mobile/features/calendar/maat_flow_temporal_controller.dart';
import 'package:mobile/features/calendar/maat_flow_temporal_policy.dart';
import 'package:mobile/features/calendar/maat_flow_temporal_resolver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MaatFlowTemporalResolution? resolveOffering(
    MaatFlowTemporalContext context,
  ) => const MaatFlowTemporalResolver().resolve(
    kind: MaatFlowKind.offeringTable,
    context: context,
  );

  test('present day accepts an arbitrary non-US IANA timezone', () {
    final kathmandu = MaatFlowTemporalContext.fromInstant(
      nowUtc: DateTime.utc(2026, 9, 2, 18, 30),
      ianaTimeZone: 'Asia/Kathmandu',
    );
    final reykjavik = MaatFlowTemporalContext.fromInstant(
      nowUtc: DateTime.utc(2026, 9, 2, 23, 30),
      ianaTimeZone: 'Atlantic/Reykjavik',
    );

    expect(kathmandu.ianaTimeZone, 'Asia/Kathmandu');
    expect(kathmandu.presentLocalDate, DateTime(2026, 9, 3));
    expect(resolveOffering(kathmandu)!.startDate, DateTime(2026, 9, 4));
    expect(reykjavik.presentLocalDate, DateTime(2026, 9, 2));
    expect(resolveOffering(reykjavik)!.startDate, DateTime(2026, 9, 3));
  });

  test('foreground local-midnight timer advances an unlocked preview', () {
    var nowUtc = DateTime.utc(2026, 9, 2, 18, 14);
    final scheduled = <_ScheduledTemporalCallback>[];
    final controller = MaatFlowTemporalController(
      ianaTimeZone: 'Asia/Kathmandu',
      clock: () => nowUtc,
      resolve: resolveOffering,
      scheduler: (delay, callback) {
        final scheduledCallback = _ScheduledTemporalCallback(delay, callback);
        scheduled.add(scheduledCallback);
        return scheduledCallback;
      },
    );
    addTearDown(controller.dispose);

    controller.start();
    expect(controller.renderedStartDate, DateTime(2026, 9, 3));
    expect(
      scheduled.single.delay,
      const Duration(minutes: 1, milliseconds: 50),
    );

    nowUtc = DateTime.utc(2026, 9, 2, 18, 16);
    scheduled.first.fire();

    expect(controller.context.presentLocalDate, DateTime(2026, 9, 3));
    expect(controller.renderedStartDate, DateTime(2026, 9, 4));
    expect(scheduled, hasLength(2));
  });

  test(
    'explicit and carried dates stay locked across timer and resume',
    () async {
      var nowUtc = DateTime.utc(2026, 9, 2, 18, 14);
      final scheduled = <_ScheduledTemporalCallback>[];
      final controller = MaatFlowTemporalController(
        ianaTimeZone: 'Asia/Kathmandu',
        ianaTimeZoneProvider: () async => 'Pacific/Auckland',
        clock: () => nowUtc,
        resolve: resolveOffering,
        scheduler: (delay, callback) {
          final scheduledCallback = _ScheduledTemporalCallback(delay, callback);
          scheduled.add(scheduledCallback);
          return scheduledCallback;
        },
      );
      addTearDown(controller.dispose);
      controller.start();

      controller.lockExplicitDate(DateTime(2026, 10, 12));
      nowUtc = DateTime.utc(2026, 9, 3, 18, 16);
      scheduled.last.fire();
      await controller.refreshAfterResume();

      expect(controller.lock, MaatFlowTemporalLock.explicitDate);
      expect(controller.ianaTimeZone, 'Pacific/Auckland');
      expect(controller.renderedStartDate, DateTime(2026, 10, 12));

      controller.lockCarried();
      nowUtc = DateTime.utc(2026, 9, 5, 18, 16);
      scheduled.last.fire();

      expect(controller.lock, MaatFlowTemporalLock.carried);
      expect(controller.renderedStartDate, DateTime(2026, 10, 12));
    },
  );

  test('Carry returns the rendered date without a tap-time rebase', () {
    var nowUtc = DateTime.utc(2026, 9, 2, 18, 14);
    final controller = MaatFlowTemporalController(
      ianaTimeZone: 'Asia/Kathmandu',
      clock: () => nowUtc,
      resolve: resolveOffering,
    );
    addTearDown(controller.dispose);

    final rendered = controller.renderedStartDate;
    nowUtc = DateTime.utc(2026, 9, 2, 18, 16);

    expect(controller.startDateForCarry, rendered);
    expect(controller.startDateForCarry, DateTime(2026, 9, 3));
  });
}

class _ScheduledTemporalCallback implements MaatFlowTemporalTimerHandle {
  _ScheduledTemporalCallback(this.delay, this.callback);

  final Duration delay;
  final VoidCallback callback;
  bool _cancelled = false;

  void fire() {
    if (!_cancelled) callback();
  }

  @override
  void cancel() => _cancelled = true;
}
