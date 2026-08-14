import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String _revision = String.fromEnvironment(
  'CALENDAR_BENCHMARK_REVISION',
  defaultValue: 'unlabeled',
);
const int _repetitions = int.fromEnvironment(
  'CALENDAR_BENCHMARK_REPETITIONS',
  defaultValue: 5,
);
const String _scenarioFilter = String.fromEnvironment(
  'CALENDAR_BENCHMARK_SCENARIO_FILTER',
  defaultValue: '',
);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final benchmarkView = binding.platformDispatcher.implicitView;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app:has_seen_onboarding': true,
      'app:onboarding:completed': true,
    });
    await Supabase.initialize(
      url: 'http://127.0.0.1:9',
      anonKey: 'calendar-boundary-benchmark',
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: false,
      ),
    );
    // Month 9 keeps a long far-past Today path inside the mounted center year.
    CalendarPage.debugCalendarTodayForTesting = KemeticMath.toGregorian(
      2027,
      9,
      15,
    );
  });

  tearDownAll(() {
    CalendarPage.debugCalendarTodayForTesting = null;
  });

  testWidgets('profile the ratified boundary and Today workloads', (
    tester,
  ) async {
    binding.reportData = <String, dynamic>{
      'benchmark': 'calendar_banner_boundary',
      'revision': _revision,
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'repetitions': _repetitions,
      'instrumentation_contract': 'timing_only_gates_full_probe_isolation',
      'refresh_rate_hz': benchmarkView?.display.refreshRate,
      'device_pixel_ratio': benchmarkView?.devicePixelRatio,
      'physical_width': benchmarkView?.physicalSize.width,
      'physical_height': benchmarkView?.physicalSize.height,
      'web_renderer_use_skia': const bool.fromEnvironment(
        'FLUTTER_WEB_USE_SKIA',
        defaultValue: false,
      ),
      'web_renderer_use_skwasm': const bool.fromEnvironment(
        'FLUTTER_WEB_USE_SKWASM',
        defaultValue: false,
      ),
      'scenario_filter': _scenarioFilter,
    };

    try {
      if (_scenarioFilter == 'today_delay_diagnostic_early') {
        binding.reportData!['current_phase'] = 'today_delay_diagnostic_early';
        await _runTodayDelayDiagnostic(binding, tester);
        binding.reportData!['current_phase'] = 'complete';
        return;
      }
      for (final scenario in _boundaryScenarios) {
        if (_scenarioFilter.isNotEmpty && _scenarioFilter != scenario.name) {
          continue;
        }
        binding.reportData!['current_phase'] =
            'boundary_timing_${scenario.name}';
        await _runBoundaryTimingPass(binding, tester, scenario);
        binding.reportData!['current_phase'] =
            'boundary_probe_${scenario.name}';
        await _runBoundaryProbePass(binding, tester, scenario);
      }
      for (final scenario in _todayScenarios) {
        if (_scenarioFilter.isNotEmpty &&
            _scenarioFilter != 'today_${scenario.name}') {
          continue;
        }
        binding.reportData!['current_phase'] = 'today_${scenario.name}';
        await _runTodayScenario(binding, tester, scenario);
      }
      binding.reportData!['current_phase'] = 'complete';
    } catch (error, stackTrace) {
      binding.reportData!['failure_error'] = error.toString();
      binding.reportData!['failure_stack'] = stackTrace.toString();
      rethrow;
    }
  });
}

const List<_BoundaryScenario> _boundaryScenarios = <_BoundaryScenario>[
  _BoundaryScenario(
    name: 'compact_empty',
    expansion: MonthExpansionLevel.compact,
    content: CalendarBoundaryHarnessContent.empty,
  ),
  _BoundaryScenario(
    name: 'compact_event_heavy',
    expansion: MonthExpansionLevel.compact,
    content: CalendarBoundaryHarnessContent.eventHeavy,
  ),
  _BoundaryScenario(
    name: 'details_empty',
    expansion: MonthExpansionLevel.details,
    content: CalendarBoundaryHarnessContent.empty,
  ),
  _BoundaryScenario(
    name: 'details_event_heavy',
    expansion: MonthExpansionLevel.details,
    content: CalendarBoundaryHarnessContent.eventHeavy,
  ),
];

const List<_TodayScenario> _todayScenarios = <_TodayScenario>[
  _TodayScenario(
    name: 'far_past',
    expansion: MonthExpansionLevel.compact,
    start: _TodayStart.farPast,
    hydrationTrigger: CalendarTodayHydrationTrigger.none,
  ),
  _TodayScenario(
    name: 'near_target',
    expansion: MonthExpansionLevel.compact,
    start: _TodayStart.nearTarget,
    hydrationTrigger: CalendarTodayHydrationTrigger.none,
  ),
  _TodayScenario(
    name: 'unhydrated_early',
    expansion: MonthExpansionLevel.details,
    start: _TodayStart.farPast,
    hydrationTrigger: CalendarTodayHydrationTrigger.early,
    targetStartsUnhydrated: true,
  ),
  _TodayScenario(
    name: 'unhydrated_late',
    expansion: MonthExpansionLevel.details,
    start: _TodayStart.farPast,
    hydrationTrigger: CalendarTodayHydrationTrigger.late,
    targetStartsUnhydrated: true,
  ),
];

Future<void> _runBoundaryTimingPass(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  _BoundaryScenario scenario,
) async {
  final controller = await _mountCalendar(
    tester,
    expansion: scenario.expansion,
    content: scenario.content,
    instrumentation: CalendarBoundaryInstrumentation.timingOnly,
  );
  for (var repetition = 1; repetition <= _repetitions; repetition++) {
    await _prepareBoundaryStart(tester, controller);
    await binding.watchPerformance(
      () => _runBoundaryWorkload(tester),
      reportKey: 'performance_${scenario.name}_r$repetition',
    );
  }
  await _unmountCalendar(tester, controller);
}

Future<void> _runBoundaryProbePass(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  _BoundaryScenario scenario,
) async {
  final controller = await _mountCalendar(
    tester,
    expansion: scenario.expansion,
    content: scenario.content,
    instrumentation: CalendarBoundaryInstrumentation.fullProbe,
  );
  for (var repetition = 1; repetition <= _repetitions; repetition++) {
    final transitionOffset = await _prepareBoundaryStart(tester, controller);
    controller.resetMeasurements();
    controller.beginFrameTimingCapture();
    await _runBoundaryWorkload(tester, controller: controller);
    final idleFrameCount = await _countIdleFrames();
    controller.endFrameTimingCapture();
    binding.reportData!['harness_${scenario.name}_r$repetition'] = controller
        .measurementReport(
          scenario: scenario.name,
          transitionOffset: transitionOffset,
          idleFrameCount: idleFrameCount,
        );
  }
  await _unmountCalendar(tester, controller);
}

Future<void> _runTodayScenario(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  _TodayScenario scenario,
) async {
  for (var repetition = 1; repetition <= _repetitions; repetition++) {
    final timingController = await _mountCalendar(
      tester,
      expansion: scenario.expansion,
      content: CalendarBoundaryHarnessContent.empty,
      instrumentation: CalendarBoundaryInstrumentation.timingOnly,
    );
    final timingStart = await _prepareTodayStart(
      tester,
      timingController,
      scenario,
    );
    timingController.armTodayTravel(
      startOffset: timingStart,
      hydrationTrigger: scenario.hydrationTrigger,
      captureArrival: false,
    );
    await binding.watchPerformance(
      () => _runTodayWorkload(tester, timingController, requireArrival: false),
      reportKey: 'performance_today_${scenario.name}_r$repetition',
    );
    final timingTreatment = timingController.todayTreatmentReport();
    binding.reportData!['treatment_today_${scenario.name}_r$repetition'] =
        timingTreatment;
    _expectValidTodayTreatment(timingTreatment, scenario);
    await _unmountCalendar(tester, timingController);

    if (scenario.hydrationTrigger != CalendarTodayHydrationTrigger.none) {
      final windowController = await _mountCalendar(
        tester,
        expansion: scenario.expansion,
        content: CalendarBoundaryHarnessContent.empty,
        instrumentation: CalendarBoundaryInstrumentation.timingOnly,
      );
      final windowStart = await _prepareTodayStart(
        tester,
        windowController,
        scenario,
      );
      windowController.armTodayTravel(
        startOffset: windowStart,
        hydrationTrigger: scenario.hydrationTrigger,
        captureArrival: false,
      );
      final displayInterval = Duration(
        microseconds: windowController.todayDisplayIntervalMicros.round(),
      );
      await binding.watchPerformance(
        () async {
          await _startTodayAnimation(tester, windowController);
          await _waitForTodayHydrationCommit(tester, windowController);
          await tester.pump(displayInterval);
          await tester.pump(displayInterval);
        },
        reportKey:
            'performance_today_${scenario.name}_hydration_window_r$repetition',
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 8),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 8),
      );
      final windowTreatment = windowController.todayTreatmentReport();
      binding.reportData!['treatment_today_${scenario.name}_hydration_window_r$repetition'] =
          windowTreatment;
      _expectValidTodayTreatment(windowTreatment, scenario);
      await _unmountCalendar(tester, windowController);
    }

    final probeController = await _mountCalendar(
      tester,
      expansion: scenario.expansion,
      content: CalendarBoundaryHarnessContent.empty,
      instrumentation: CalendarBoundaryInstrumentation.fullProbe,
    );
    final probeStart = await _prepareTodayStart(
      tester,
      probeController,
      scenario,
    );
    probeController.resetMeasurements();
    probeController.armTodayTravel(
      startOffset: probeStart,
      hydrationTrigger: scenario.hydrationTrigger,
    );
    probeController.beginFrameTimingCapture();
    await _runTodayWorkload(tester, probeController, requireArrival: true);
    final idleFrameCount = await _countIdleFrames();
    probeController.endFrameTimingCapture();
    binding.reportData!['harness_today_${scenario.name}_r$repetition'] =
        probeController.todayMeasurementReport(
          scenario: 'today_${scenario.name}',
          idleFrameCount: idleFrameCount,
        );
    _expectValidTodayTreatment(
      binding.reportData!['harness_today_${scenario.name}_r$repetition']
          as Map<String, Object?>,
      scenario,
    );
    await _unmountCalendar(tester, probeController);
  }
}

Future<void> _runTodayDelayDiagnostic(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
) async {
  const scenario = _TodayScenario(
    name: 'unhydrated_early',
    expansion: MonthExpansionLevel.details,
    start: _TodayStart.farPast,
    hydrationTrigger: CalendarTodayHydrationTrigger.early,
    targetStartsUnhydrated: true,
  );
  final controller = await _mountCalendar(
    tester,
    expansion: scenario.expansion,
    content: CalendarBoundaryHarnessContent.empty,
    instrumentation: CalendarBoundaryInstrumentation.fullProbe,
  );
  final start = await _prepareTodayStart(tester, controller, scenario);
  final previousFramePolicy = binding.framePolicy;
  try {
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
    controller.resetMeasurements();
    controller.beginFrameTimingCapture();
    controller.markDiagnosticEvent('driver.diagnostic.begin');
    controller.armTodayTravel(
      startOffset: start,
      hydrationTrigger: scenario.hydrationTrigger,
      captureArrival: false,
    );
    controller.markDiagnosticEvent('driver.isolated_invoke.begin');
    controller.invokeToday();
    controller.markDiagnosticEvent('driver.isolated_invoke.end');
    final commit = controller.todayHydrationCommitFuture;
    if (commit == null) {
      throw StateError(
        'The isolated Today diagnostic has no hydration commit.',
      );
    }
    controller.markDiagnosticEvent('driver.isolated_await_commit.begin');
    await commit.timeout(const Duration(seconds: 2));
    controller.markDiagnosticEvent('driver.isolated_await_commit.end');
    controller.markDiagnosticEvent('driver.isolated_frame_flush.begin');
    await Future<void>.delayed(const Duration(seconds: 2));
    controller.markDiagnosticEvent('driver.isolated_frame_flush.end');
    controller.markDiagnosticEvent('driver.diagnostic.end');
    controller.endFrameTimingCapture();
    binding.reportData!['today_delay_diagnostic_early'] = controller
        .todayDelayDiagnosticReport();
  } finally {
    binding.framePolicy = previousFramePolicy;
    await _unmountCalendar(tester, controller);
  }
}

Future<CalendarBoundaryHarnessController> _mountCalendar(
  WidgetTester tester, {
  required MonthExpansionLevel expansion,
  required CalendarBoundaryHarnessContent content,
  required CalendarBoundaryInstrumentation instrumentation,
}) async {
  final controller = CalendarBoundaryHarnessController(
    expansionLevel: expansion,
    content: content,
    instrumentation: instrumentation,
  );
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: CalendarPage(
        key: GlobalKey<CalendarPageState>(),
        calendarBoundaryHarnessController: controller,
      ),
    ),
  );
  await _pumpCoordinator(tester, frames: 8);
  expect(controller.isAttached, isTrue);
  return controller;
}

Future<void> _unmountCalendar(
  WidgetTester tester,
  CalendarBoundaryHarnessController controller,
) async {
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  controller.dispose();
}

Future<double> _prepareBoundaryStart(
  WidgetTester tester,
  CalendarBoundaryHarnessController controller,
) async {
  final transitionOffset = await _findForwardTransition(tester, controller);
  final position = controller.scrollController.position;
  position.jumpTo(
    (transitionOffset - 40)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble(),
  );
  await _flushPositioningWork(tester);
  return transitionOffset;
}

Future<double> _prepareTodayStart(
  WidgetTester tester,
  CalendarBoundaryHarnessController controller,
  _TodayScenario scenario,
) async {
  if (scenario.targetStartsUnhydrated) {
    controller.prepareTodayTargetUnhydrated();
    await _pumpCoordinator(tester, frames: 4);
  }
  final start = switch (scenario.start) {
    _TodayStart.farPast => controller.farPastTodayStartOffset,
    _TodayStart.nearTarget => controller.nearTodayStartOffset,
  };
  controller.scrollController.position.jumpTo(start);
  await _flushPositioningWork(tester);
  return start;
}

Future<void> _flushPositioningWork(WidgetTester tester) async {
  await _pumpCoordinator(tester, frames: 6);
  // Setup jumps arm the real restoration/hydration debounces. Flush them so
  // positioning work cannot be attributed to the measured action.
  await tester.pump(const Duration(milliseconds: 400));
  await _pumpCoordinator(tester, frames: 4);
}

Future<double> _findForwardTransition(
  WidgetTester tester,
  CalendarBoundaryHarnessController controller,
) async {
  final outgoing = controller.snapshot?.geometryFor(controller.outgoingMonth);
  expect(outgoing, isNotNull, reason: 'Outgoing month must be mounted.');

  final position = controller.scrollController.position;
  final scanStart = (outgoing!.extent.leading + 1).clamp(
    position.minScrollExtent,
    position.maxScrollExtent,
  );
  final scanEnd = (outgoing.extent.trailing + 32).clamp(
    position.minScrollExtent,
    position.maxScrollExtent,
  );
  position.jumpTo(scanStart.toDouble());
  await _pumpCoordinator(tester, frames: 5);

  var sawOutgoing = false;
  for (var offset = scanStart.toDouble(); offset <= scanEnd; offset += 4) {
    position.jumpTo(offset);
    await _pumpCoordinator(tester, frames: 3);
    final activeMonth = controller.activeBannerMonth;
    if (activeMonth == controller.outgoingMonth) {
      sawOutgoing = true;
    } else if (sawOutgoing && activeMonth == controller.incomingMonth) {
      return offset;
    }
  }
  fail(
    'Could not find the outgoing-to-incoming banner transition '
    '(saw outgoing: $sawOutgoing, final active: '
    '${controller.activeBannerMonth}).',
  );
}

Future<void> _runBoundaryWorkload(
  WidgetTester tester, {
  CalendarBoundaryHarnessController? controller,
}) async {
  void mark(String name) => controller?.markDiagnosticEvent(name);

  mark('workload.start');
  final surface = find.byType(CustomScrollView).first;
  expect(surface, findsOneWidget);

  // One uninterrupted gesture hovers just outside and inside the eight-pixel
  // deadband, crosses, reverses, and crosses forward again.
  mark('slow_scrub.start');
  final gesture = await tester.startGesture(tester.getCenter(surface));
  mark('slow_scrub.forward_30.start');
  await _moveGestureScrollBy(tester, gesture, 30, frames: 24);
  mark('slow_scrub.forward_30.end');
  await Future<void>.delayed(const Duration(milliseconds: 96));
  mark('slow_scrub.forward_6.start');
  await _moveGestureScrollBy(tester, gesture, 6, frames: 8);
  mark('slow_scrub.forward_6.end');
  await Future<void>.delayed(const Duration(milliseconds: 96));
  mark('slow_scrub.forward_12.start');
  await _moveGestureScrollBy(tester, gesture, 12, frames: 12);
  mark('slow_scrub.forward_12.end');
  await Future<void>.delayed(const Duration(milliseconds: 96));
  mark('slow_scrub.reverse_12_a.start');
  await _moveGestureScrollBy(tester, gesture, -12, frames: 12);
  mark('slow_scrub.reverse_12_a.end');
  await Future<void>.delayed(const Duration(milliseconds: 96));
  mark('slow_scrub.reverse_12_b.start');
  await _moveGestureScrollBy(tester, gesture, -12, frames: 12);
  mark('slow_scrub.reverse_12_b.end');
  await Future<void>.delayed(const Duration(milliseconds: 96));
  mark('slow_scrub.forward_32.start');
  await _moveGestureScrollBy(tester, gesture, 32, frames: 24);
  mark('slow_scrub.forward_32.end');
  await gesture.up();
  mark('slow_scrub.end');
  mark('scrub_settle.start');
  await tester.pumpAndSettle(
    const Duration(milliseconds: 16),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 4),
  );
  mark('scrub_settle.end');

  mark('fling_dispatch.start');
  await tester.fling(surface, const Offset(0, -720), 1900);
  mark('fling_dispatch.end');
  mark('fling_settle.start');
  await tester.pumpAndSettle(
    const Duration(milliseconds: 16),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 12),
  );
  mark('fling_settle.end');
  mark('workload.end');
}

Future<void> _runTodayWorkload(
  WidgetTester tester,
  CalendarBoundaryHarnessController controller, {
  required bool requireArrival,
}) async {
  await _startTodayAnimation(tester, controller);
  final hydrationCommit = controller.todayHydrationCommitFuture;
  if (hydrationCommit != null) {
    await _waitForTodayHydrationCommit(tester, controller);
  }
  await tester.pumpAndSettle(
    const Duration(milliseconds: 8),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 8),
  );
  if (requireArrival) {
    for (var frame = 0; frame < 8 && !controller.todayArrivalReady; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final asynchronousException = tester.takeException();
    expect(
      asynchronousException,
      isNull,
      reason:
          'Today arrival sampling threw. ${controller.debugTodayTravelState}',
    );
    expect(
      controller.todayArrivalReady,
      isTrue,
      reason:
          'Today must publish A/B/C arrival samples even when interrupted. '
          '${controller.debugTodayTravelState}',
    );
  }
}

Future<void> _waitForTodayHydrationCommit(
  WidgetTester tester,
  CalendarBoundaryHarnessController controller,
) async {
  final commit = controller.todayHydrationCommitFuture;
  if (commit == null) return;
  var completed = false;
  unawaited(commit.then((_) => completed = true));
  final displayInterval = Duration(
    microseconds: controller.todayDisplayIntervalMicros.round(),
  );
  final deadline = Stopwatch()..start();
  var driverIteration = 0;
  while (!completed && deadline.elapsed < const Duration(seconds: 2)) {
    controller.markDiagnosticEvent(
      'driver.wait_delay.begin',
      details: <String, Object?>{'iteration': driverIteration},
    );
    await Future<void>.delayed(displayInterval);
    controller.markDiagnosticEvent(
      'driver.wait_delay.end',
      details: <String, Object?>{'iteration': driverIteration},
    );
    controller.markDiagnosticEvent(
      'driver.pump.begin',
      details: <String, Object?>{'iteration': driverIteration},
    );
    await tester.pump(displayInterval);
    controller.markDiagnosticEvent(
      'driver.pump.end',
      details: <String, Object?>{'iteration': driverIteration},
    );
    driverIteration++;
  }
  deadline.stop();
  if (!completed) {
    throw TimeoutException(
      'Today hydration did not commit on a driven display frame.',
      deadline.elapsed,
    );
  }
  await commit;
}

Future<void> _startTodayAnimation(
  WidgetTester tester,
  CalendarBoundaryHarnessController controller,
) async {
  controller.markDiagnosticEvent('driver.invoke_today.begin');
  controller.invokeToday();
  controller.markDiagnosticEvent('driver.invoke_today.end');
  // `_scrollToToday` resolves its target in a post-frame callback. Pump that
  // frame explicitly before waiting for the resulting animation.
  controller.markDiagnosticEvent('driver.target_resolution_pump.begin');
  await tester.pump();
  controller.markDiagnosticEvent('driver.target_resolution_pump.end');
  expect(
    controller.todayAnimationStarted,
    isTrue,
    reason:
        'Today must expose the exact production animation transaction. '
        '${controller.debugTodayTravelState}',
  );
  // DrivenScrollActivity establishes its animation epoch on its first ticker
  // frame. Prime that frame before advancing the sealed elapsed duration.
  controller.markDiagnosticEvent('driver.ticker_epoch_pump.begin');
  await tester.pump();
  controller.markDiagnosticEvent('driver.ticker_epoch_pump.end');
  expect(
    controller.todayHydrationCommitFuture == null ||
        controller.todayAnimationEpochPrimed,
    isTrue,
    reason: 'Today must establish its controlled ticker epoch.',
  );
}

void _expectValidTodayTreatment(
  Map<String, Object?> treatment,
  _TodayScenario scenario,
) {
  expect(
    treatment['today_treatment_valid'],
    isTrue,
    reason:
        'Today ${scenario.name} treatment missed its sealed timing, spatial, '
        'commit, or transaction-active contract: $treatment',
  );
}

Future<void> _moveGestureScrollBy(
  WidgetTester tester,
  TestGesture gesture,
  double scrollDelta, {
  required int frames,
}) async {
  final pointerDelta = -scrollDelta / frames;
  for (var frame = 0; frame < frames; frame++) {
    await gesture.moveBy(Offset(0, pointerDelta));
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _pumpCoordinator(
  WidgetTester tester, {
  required int frames,
}) async {
  for (var frame = 0; frame < frames; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<int> _countIdleFrames() async {
  var frameCount = 0;
  void countFrames(List<FrameTiming> timings) {
    frameCount += timings.length;
  }

  SchedulerBinding.instance.addTimingsCallback(countFrames);
  await Future<void>.delayed(const Duration(seconds: 2));
  SchedulerBinding.instance.removeTimingsCallback(countFrames);
  return frameCount;
}

final class _BoundaryScenario {
  const _BoundaryScenario({
    required this.name,
    required this.expansion,
    required this.content,
  });

  final String name;
  final MonthExpansionLevel expansion;
  final CalendarBoundaryHarnessContent content;
}

enum _TodayStart { farPast, nearTarget }

final class _TodayScenario {
  const _TodayScenario({
    required this.name,
    required this.expansion,
    required this.start,
    required this.hydrationTrigger,
    this.targetStartsUnhydrated = false,
  });

  final String name;
  final MonthExpansionLevel expansion;
  final _TodayStart start;
  final CalendarTodayHydrationTrigger hydrationTrigger;
  final bool targetStartsUnhydrated;
}
