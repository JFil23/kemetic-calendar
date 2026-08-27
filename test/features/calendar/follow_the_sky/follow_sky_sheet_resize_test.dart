import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/day_view.dart';
import 'package:mobile/features/calendar/follow_the_sky/services/track_sky_materializer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _viewport = Size(390, 844);
const _flowId = 73;
const _minimumExtent = 0.58;
const _reservedChromeHeight = 120.0;

Future<void> _ensureSupabaseInitialized() async {
  try {
    Supabase.instance.client;
    return;
  } catch (_) {}

  await Supabase.initialize(
    url: 'https://example.supabase.co',
    anonKey: 'anon-key-0123456789012345678901234567890123456789',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await _ensureSupabaseInitialized();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'top handle expands continuously and clamps between approved minimum and maximum',
    (tester) async {
      await _pumpFollowSkySheet(tester);

      final availableHeight = _viewport.height - 12;
      final minimumPageHeight =
          availableHeight * _minimumExtent - _reservedChromeHeight;
      expect(_pageHeight(tester), closeTo(minimumPageHeight, 0.1));

      await tester.drag(_resizeHandle, const Offset(0, -120));
      await tester.pumpAndSettle();
      expect(_pageHeight(tester), closeTo(minimumPageHeight + 120, 0.1));

      await tester.drag(_resizeHandle, const Offset(0, 60));
      await tester.pumpAndSettle();
      expect(_pageHeight(tester), closeTo(minimumPageHeight + 60, 0.1));

      await tester.drag(_resizeHandle, const Offset(0, 2000));
      await tester.pumpAndSettle();
      expect(_pageHeight(tester), closeTo(minimumPageHeight, 0.1));
      expect(_sheet, findsOneWidget);

      await tester.drag(_resizeHandle, const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(
        _pageHeight(tester),
        closeTo(availableHeight - _reservedChromeHeight, 0.1),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Moon and ENDURE gestures stay independent from outer sheet resizing',
    (tester) async {
      await _pumpFollowSkySheet(tester);
      final initialHeight = _pageHeight(tester);
      final initialViewTime = _viewTime(tester);

      await tester.drag(_moonSurface, const Offset(120, 0));
      await tester.pump();
      expect(_pageHeight(tester), closeTo(initialHeight, 0.1));
      expect(_viewTime(tester), isNot(initialViewTime));
      final selectedViewTime = _viewTime(tester);

      await tester.drag(_resizeHandle, const Offset(0, -120));
      await tester.pumpAndSettle();
      final expandedHeight = _pageHeight(tester);
      expect(expandedHeight, greaterThan(initialHeight));
      expect(_viewTime(tester), selectedViewTime);

      await tester.drag(_presentationBody, const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(_pageHeight(tester), closeTo(expandedHeight, 0.1));
      expect(_viewTime(tester), selectedViewTime);
    },
  );

  testWidgets('overflow remains tappable beside the resize handle', (
    tester,
  ) async {
    await _pumpFollowSkySheet(tester);

    expect(_resizeHandle, findsOneWidget);
    await tester.tap(find.byTooltip('Event options'));
    await tester.pumpAndSettle();

    expect(find.byType(PopupMenuItem<String>), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keyboard preserves manual extent and reopening resets it', (
    tester,
  ) async {
    await _pumpFollowSkySheet(tester);
    final initialHeight = _pageHeight(tester);

    await tester.drag(_resizeHandle, const Offset(0, -120));
    await tester.pumpAndSettle();
    final expandedHeight = _pageHeight(tester);
    expect(expandedHeight, greaterThan(initialHeight));

    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pumpAndSettle();
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle();
    expect(_pageHeight(tester), closeTo(expandedHeight, 0.1));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await _pumpFollowSkySheet(tester, configureViewport: false);
    expect(_pageHeight(tester), closeTo(initialHeight, 0.1));
  });
}

Finder get _sheet =>
    find.byKey(const ValueKey<String>('follow-sky-resizable-sheet'));
Finder get _resizeHandle =>
    find.byKey(const ValueKey<String>('follow-sky-sheet-resize-handle'));
Finder get _moonSurface =>
    find.byKey(const ValueKey<String>('follow-sky-hero-drag'));
Finder get _presentationBody =>
    find.byKey(const ValueKey<String>('follow-sky-presentation-body'));

double _pageHeight(WidgetTester tester) {
  final pageView = find.descendant(of: _sheet, matching: find.byType(PageView));
  expect(pageView, findsOneWidget);
  return tester.getSize(pageView).height;
}

String? _viewTime(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey<String>('follow-sky-view-time')))
    .data;

Future<void> _pumpFollowSkySheet(
  WidgetTester tester, {
  bool configureViewport = true,
}) async {
  if (configureViewport) {
    tester.view.physicalSize = _viewport;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
  }

  final behaviorPayload = TrackSkyEventOwnership.behaviorPayload(
    skyEventId: 'full-moon-2026-08-28',
    resolvedFunction: 'ENDURE',
    intention: 'self confidence',
  );
  final target = DayViewSheetEventTarget(
    ky: 1,
    km: 1,
    kd: 1,
    event: EventItem(
      clientEventId: 'follow-sky-resize-fixture',
      title: 'Full Moon + Partial Lunar Eclipse',
      startMin: 21 * 60 + 12,
      endMin: 22 * 60,
      flowId: _flowId,
      color: const Color(0xFF9DA8FF),
      allDay: false,
      behaviorPayload: behaviorPayload,
    ),
  );

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(),
      home: Builder(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          resizeToAvoidBottomInset: false,
          body: CalendarEventDetailSheet(
            hostContext: context,
            initialTarget: target,
            flowResolver: (flowId) => flowId == _flowId
                ? const FlowData(
                    id: _flowId,
                    name: 'Follow the Sky',
                    color: Color(0xFF9DA8FF),
                    active: true,
                  )
                : null,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
