import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/services/app_restoration_service.dart';
import 'package:mobile/services/app_window_service.dart';
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
  });

  tearDown(() {
    CalendarPage.debugCalendarTodayForTesting = null;
    AppRestorationService.debugUserIdResolver = null;
    AppRestorationService.debugRemoteWindowSnapshotReader = null;
    AppRestorationService.debugRemoteLatestSnapshotReader = null;
    AppRestorationService.debugRemoteSnapshotWriter = null;
    AppRestorationService.debugCriticalSnapshotReader = null;
    AppRestorationService.debugCriticalSnapshotWriter = null;
    AppRestorationService.debugLatestCriticalSnapshotReader = null;
    AppRestorationService.debugLatestCriticalSnapshotWriter = null;
    AppRestorationService.debugPlatformLastActiveUserIdReader = null;
    AppRestorationService.debugPlatformLastActiveUserIdWriter = null;
    AppWindowService.debugWindowIdResolver = null;
    AppWindowService.instance.resetForTesting();
  });

  testWidgets(
    'old 32px compact offset restores the same semantic day in 36px layout',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const userId = 'calendar-cross-version-user';
      const windowId = 'calendar-cross-version-window';
      const savedAlignment = 0.38;
      final criticalSnapshots = <String, String>{};
      AppRestorationService.debugUserIdResolver = () => userId;
      AppWindowService.debugWindowIdResolver = () async => windowId;
      AppRestorationService.debugRemoteWindowSnapshotReader = (_, _, _) async =>
          null;
      AppRestorationService.debugRemoteLatestSnapshotReader = (_) async => null;
      AppRestorationService.debugRemoteSnapshotWriter = (_, _, _, _) async {};
      AppRestorationService.debugCriticalSnapshotReader = (id) =>
          criticalSnapshots[id];
      AppRestorationService.debugCriticalSnapshotWriter = (id, serialized) {
        if (serialized == null) {
          criticalSnapshots.remove(id);
        } else {
          criticalSnapshots[id] = serialized;
        }
      };
      AppRestorationService.debugLatestCriticalSnapshotReader = (_) => null;
      AppRestorationService.debugLatestCriticalSnapshotWriter = (_, _) {};
      AppRestorationService.debugPlatformLastActiveUserIdReader = () => userId;
      AppRestorationService.debugPlatformLastActiveUserIdWriter = (_) {};
      AppWindowService.instance.resetForTesting();

      final fixedToday = DateTime(2026, 8, 13);
      CalendarPage.debugCalendarTodayForTesting = fixedToday;
      final today = KemeticMath.fromGregorian(fixedToday);
      final targetYear = today.kYear + 1;
      const targetMonth = 1;
      const targetDay = 1;

      // Measure where the new build places the target. It lives in the next
      // lazy year, so a persisted raw offset must mount it before semantic
      // restoration can take over.
      final calibrationKey = GlobalKey<CalendarPageState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CalendarPage(key: calibrationKey)),
        ),
      );
      calibrationKey.currentState!.debugShowCalendarShellForTesting();
      await tester.pump();

      final scrollView = find.byKey(
        const PageStorageKey('calendar_portrait_scroll'),
      );
      for (
        var drag = 0;
        drag < 20 &&
            keyForMonth(targetYear, targetMonth).currentContext == null;
        drag++
      ) {
        await tester.drag(scrollView, const Offset(0, -700));
        await tester.pump(const Duration(milliseconds: 80));
      }
      expect(keyForMonth(targetYear, targetMonth).currentContext, isNotNull);

      final calibrationState = calibrationKey.currentState!;
      calibrationState.debugSetCurrentViewForTesting(
        kYear: targetYear,
        kMonth: targetMonth,
        kDay: targetDay,
      );
      await tester.pump();
      expect(
        calibrationState.debugJumpToCurrentViewAtAlignmentForTesting(
          savedAlignment,
        ),
        isTrue,
      );
      await tester.pump();
      final newGeometryOffset = calibrationState.debugCalendarScrollOffset!;
      final targetDayFinder = find.byKey(
        ValueKey<String>('k:$targetYear-$targetMonth-$targetDay|K'),
      );
      expect(targetDayFinder, findsOneWidget);
      final newGeometryAlignment = _verticalCenterAlignment(
        tester,
        target: targetDayFinder,
        viewport: scrollView,
      );

      // Compact geometry grew by 148px for the complete preceding year. The
      // center of day 1's own row moved another 2px when its tile grew 32->36.
      const oldToNewTargetDelta = 150.0;
      final oldGeometryOffset = newGeometryOffset - oldToNewTargetDelta;
      expect(oldGeometryOffset, greaterThan(0));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
      await AppRestorationService.instance.clearCurrentSnapshot();
      criticalSnapshots.clear();
      await AppRestorationService.instance.saveCalendarState(
        CalendarRestorationState(
          kYear: targetYear,
          kMonth: targetMonth,
          kDay: targetDay,
          showGregorian: false,
          expansion: 'compact',
          anchorTarget: 'dayChip',
          anchorAlignment: savedAlignment,
          viewportHeight: 1200,
          layoutRevision: 1,
          scrollOffset: oldGeometryOffset,
        ),
      );

      final restoredKey = GlobalKey<CalendarPageState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CalendarPage(key: restoredKey)),
        ),
      );
      for (
        var frame = 0;
        frame < 40 &&
            !(restoredKey.currentState?.debugInitialViewportSettled ?? false);
        frame++
      ) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump();

      final restoredState = restoredKey.currentState!;
      expect(restoredState.debugInitialViewportSettled, isTrue);
      expect(restoredState.debugCalendarRestorationLayoutRevision, 2);
      expect(restoredState.debugLastViewYear, targetYear);
      expect(restoredState.debugLastViewMonth, targetMonth);
      expect(restoredState.debugLastViewDay, targetDay);
      expect(
        restoredState.debugCalendarScrollOffset,
        closeTo(newGeometryOffset, 0.5),
      );
      expect(
        _verticalCenterAlignment(
          tester,
          target: targetDayFinder,
          viewport: find.byKey(
            const PageStorageKey('calendar_portrait_scroll'),
          ),
        ),
        closeTo(newGeometryAlignment, 0.002),
      );
      expect(
        (restoredState.debugCalendarScrollOffset! - oldGeometryOffset).abs(),
        greaterThan(100),
        reason: 'the revision-1 raw offset must not remain authoritative',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    },
  );
}

double _verticalCenterAlignment(
  WidgetTester tester, {
  required Finder target,
  required Finder viewport,
}) {
  final viewportBox = tester.renderObject<RenderBox>(viewport);
  final targetBox = tester.renderObject<RenderBox>(target);
  final targetTop = targetBox.localToGlobal(Offset.zero, ancestor: viewportBox);
  return (targetTop.dy + targetBox.size.height / 2) / viewportBox.size.height;
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
