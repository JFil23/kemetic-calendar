import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
      anonKey: 'calendar-dormant-observer-benchmark',
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: false,
      ),
    );
    CalendarPage.debugCalendarTodayForTesting = KemeticMath.toGregorian(
      2027,
      9,
      15,
    );
  });

  tearDownAll(() {
    CalendarPage.debugCalendarTodayForTesting = null;
  });

  testWidgets('measure CalendarPage with benchmark harness dormant', (
    tester,
  ) async {
    final pageKey = GlobalKey<CalendarPageState>();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true),
        home: CalendarPage(key: pageKey),
      ),
    );
    await _pumpFrames(tester, 4);
    pageKey.currentState!.debugShowCalendarShellForTesting();
    await _pumpFrames(tester, 8);

    binding.reportData = <String, dynamic>{
      'benchmark': 'calendar_dormant_observer',
      'revision': _revision,
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'repetitions': _repetitions,
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
      'benchmark_define_enabled': const bool.fromEnvironment(
        'CALENDAR_BOUNDARY_BENCHMARK',
        defaultValue: false,
      ),
    };

    for (var repetition = 1; repetition <= _repetitions; repetition++) {
      await _prepareStart(tester);
      await binding.watchPerformance(
        () => _runWorkload(tester),
        reportKey: 'performance_dormant_r$repetition',
      );
    }
  });
}

Future<void> _prepareStart(WidgetTester tester) async {
  final surface = find.byType(CustomScrollView).first;
  expect(surface, findsOneWidget);
  await tester.drag(surface, const Offset(0, 220));
  await tester.pumpAndSettle(
    const Duration(milliseconds: 16),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 8),
  );
  await tester.pump(const Duration(milliseconds: 400));
  await _pumpFrames(tester, 4);
}

Future<void> _runWorkload(WidgetTester tester) async {
  final surface = find.byType(CustomScrollView).first;
  final gesture = await tester.startGesture(tester.getCenter(surface));
  await _moveGestureScrollBy(tester, gesture, 240, frames: 60);
  await _moveGestureScrollBy(tester, gesture, -96, frames: 24);
  await _moveGestureScrollBy(tester, gesture, 160, frames: 40);
  await gesture.up();
  await tester.pumpAndSettle(
    const Duration(milliseconds: 16),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 8),
  );
  await tester.fling(surface, const Offset(0, -720), 1900);
  await tester.pumpAndSettle(
    const Duration(milliseconds: 16),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 12),
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

Future<void> _pumpFrames(WidgetTester tester, int count) async {
  for (var frame = 0; frame < count; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}
