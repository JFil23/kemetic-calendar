import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app:has_seen_onboarding': true,
      'app:onboarding:completed': true,
    });
    await Supabase.initialize(
      url: 'http://127.0.0.1:9',
      anonKey: 'test-anon-key',
      httpClient: _RejectingClient(),
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: false,
      ),
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app:has_seen_onboarding': true,
      'app:onboarding:completed': true,
    });
    CalendarPage.debugCalendarTodayForTesting = KemeticMath.toGregorian(
      2027,
      9,
      15,
    );
  });

  tearDown(() {
    CalendarPage.debugCalendarTodayForTesting = null;
  });

  testWidgets('boundary harness exercises the real banner coordinator', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = CalendarBoundaryHarnessController(
      expansionLevel: MonthExpansionLevel.compact,
      content: CalendarBoundaryHarnessContent.empty,
      instrumentation: CalendarBoundaryInstrumentation.fullProbe,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CalendarPage(
          key: GlobalKey<CalendarPageState>(),
          calendarBoundaryHarnessController: controller,
        ),
      ),
    );
    await _pumpFrames(tester, 8);

    expect(controller.isAttached, isTrue);
    final outgoing = controller.snapshot?.geometryFor(controller.outgoingMonth);
    expect(outgoing, isNotNull);

    final position = controller.scrollController.position;
    position.jumpTo(outgoing!.extent.leading + 1);
    await _pumpFrames(tester, 5);
    expect(controller.activeBannerMonth, controller.outgoingMonth);

    var crossed = false;
    for (
      var offset = outgoing.extent.leading + 1;
      offset <= outgoing.extent.trailing + 32;
      offset += 8
    ) {
      position.jumpTo(offset);
      await _pumpFrames(tester, 3);
      if (controller.activeBannerMonth == controller.incomingMonth) {
        crossed = true;
        break;
      }
    }
    expect(crossed, isTrue);

    final incoming = controller.snapshot?.geometryFor(controller.incomingMonth);
    expect(incoming, isNotNull);
    final centerBoundary =
        incoming!.extent.leading - (position.viewportDimension / 2);
    position.jumpTo(centerBoundary - 1);
    await _pumpFrames(tester, 4);
    expect(controller.activeCenteredMonth, controller.outgoingMonth);

    controller.resetMeasurements();
    position.jumpTo(centerBoundary + 1);
    await _pumpFrames(tester, 4);
    expect(controller.activeCenteredMonth, controller.incomingMonth);
    final report = controller.measurementReport(
      scenario: 'widget_sanity',
      transitionOffset: position.pixels,
      idleFrameCount: 0,
    );
    expect(report['samples'], isNotEmpty);
    expect(report['page'], isA<Map<String, int>>());
    expect(report['body'], isA<Map<String, int>>());
    expect(report['banner'], isA<Map<String, int>>());
    expect((report['page'] as Map<String, int>)['builds'], 0);
    expect((report['body'] as Map<String, int>)['builds'], 0);
    expect(report['restoration_schedule_count'], greaterThan(0));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    controller.dispose();
  });

  testWidgets(
    'Today records controlled early and late hydration transactions',
    (tester) async {
      tester.view.physicalSize = const Size(780, 1688);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final trigger in <CalendarTodayHydrationTrigger>[
        CalendarTodayHydrationTrigger.early,
        CalendarTodayHydrationTrigger.late,
      ]) {
        final controller = CalendarBoundaryHarnessController(
          expansionLevel: MonthExpansionLevel.details,
          content: CalendarBoundaryHarnessContent.empty,
          instrumentation: CalendarBoundaryInstrumentation.fullProbe,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: CalendarPage(
              key: GlobalKey<CalendarPageState>(),
              calendarBoundaryHarnessController: controller,
            ),
          ),
        );
        await _pumpFrames(tester, 8);

        controller.prepareTodayTargetUnhydrated();
        await _pumpFrames(tester, 4);
        final start = controller.farPastTodayStartOffset;
        controller.scrollController.position.jumpTo(start);
        await _pumpFrames(tester, 6);
        await tester.pump(const Duration(milliseconds: 400));
        await _pumpFrames(tester, 4);

        controller.resetMeasurements();
        controller.armTodayTravel(
          startOffset: start,
          hydrationTrigger: trigger,
        );
        controller.invokeToday();
        await tester.pump();
        expect(controller.todayAnimationStarted, isTrue);
        await tester.pump();
        expect(controller.todayAnimationEpochPrimed, isTrue);
        final requested = controller.todayRequestedHydrationElapsed;
        expect(requested, isNotNull);
        await tester.pump(requested!);
        for (
          var frame = 0;
          frame < 2 && controller.todayHydrationCommitFuture != null;
          frame++
        ) {
          await tester.pump(const Duration(milliseconds: 1));
        }
        await controller.todayHydrationCommitFuture;
        await tester.pumpAndSettle(const Duration(milliseconds: 8));
        await _pumpFrames(tester, 4);

        expect(
          controller.todayArrivalReady,
          isTrue,
          reason: controller.debugTodayTravelState.toString(),
        );
        final report = controller.todayMeasurementReport(
          scenario: 'today_${trigger.name}_widget_sanity',
          idleFrameCount: 0,
        );
        expect(report['today_hydration_trigger'], trigger.name);
        expect(report['today_hydration_commit_count'], 1);
        expect(
          report['today_requested_trigger_elapsed_us'],
          requested.inMicroseconds,
        );
        expect(report['today_actual_trigger_elapsed_us'], isA<int>());
        expect(report['today_actual_trigger_elapsed_us'] as int, isPositive);
        expect(report['today_original_animation_active_at_commit'], isTrue);
        expect(report['today_treatment_commit_valid'], isTrue);
        expect(report['today_trigger_wall_elapsed_us'], isNotNull);
        expect(report['today_final_target_offset'], isA<double>());
        expect(report['today_final_scroll_pixels'], isA<double>());
        expect(report['today_reached_target'], isA<bool>());
        expect(
          (report['arrival_samples'] as List<Object?>)
              .cast<Map<String, Object?>>()
              .map((sample) => sample['label']),
          <String>['A', 'B', 'C'],
        );
        expect(report['arrival_tolerance_logical_px'], 0.5);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 2));
        controller.dispose();
      }
    },
  );
}

Future<void> _pumpFrames(WidgetTester tester, int count) async {
  for (var frame = 0; frame < count; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

final class _RejectingClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream<List<int>>.fromIterable(const []),
      500,
      request: request,
    );
  }
}
