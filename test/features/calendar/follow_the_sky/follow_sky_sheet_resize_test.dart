import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/calendar/day_view.dart';
import 'package:mobile/features/calendar/follow_the_sky/domain/sky_catalog.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/widgets/track_sky_event_block_visual.dart';
import 'package:mobile/features/calendar/follow_the_sky/services/sky_catalog_repository.dart';
import 'package:mobile/features/calendar/follow_the_sky/services/sky_instrument_data_provider.dart';
import 'package:mobile/features/calendar/follow_the_sky/services/track_sky_materializer.dart';
import 'package:mobile/features/calendar/presentation/instrument_event_presentation_frame.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../support/maat_flow_visual_goldens.dart';
import '../../../support/maat_flow_visual_test_fonts.dart';

const _viewport = Size(390, 844);
const _flowId = 73;
const _minimumExtent = 0.58;
const _reservedChromeHeight = 120.0;
const _visualCaptureKey = ValueKey<String>('follow-sky-housing-visual-capture');
final _goldenRoot = '../$maatFlowVisualGoldenRoot';
late SkyCatalog _catalog;

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
    const appLinksMessages = MethodChannel('com.llfbandit.app_links/messages');
    const appLinksEvents = MethodChannel('com.llfbandit.app_links/events');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(appLinksMessages, (_) async => null);
    messenger.setMockMethodCallHandler(appLinksEvents, (_) async {
      scheduleMicrotask(
        () =>
            messenger.handlePlatformMessage(appLinksEvents.name, null, (_) {}),
      );
      return null;
    });
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await _ensureSupabaseInitialized();
    _catalog = await SkyCatalogRepository().load();
    await loadMaatFlowVisualTestFonts();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    CalendarEventDetailSheetCoordinator.debugResetForTests();
  });
  tearDown(() {
    CalendarEventDetailSheetCoordinator.debugResetForTests();
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

  testWidgets('Follow Sky defines the shared lowered and raised housing', (
    tester,
  ) async {
    await _pumpFollowSkySheet(tester);

    expect(find.byType(MaatDayViewSheetHost), findsOneWidget);
    expect(find.byType(MaatDayViewForegroundShell), findsOneWidget);
    expect(find.byType(MaatDayViewForegroundContent), findsOneWidget);

    final foreground = find.byKey(
      const ValueKey<String>('follow-sky-static-lower-sheet'),
    );
    final loweredRect = tester.getRect(foreground);
    await tester.dragFrom(
      Offset(loweredRect.center.dx, loweredRect.top + 24),
      const Offset(0, -250),
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(foreground).top, lessThan(loweredRect.top));
  });

  testWidgets('V2 ownership opens the sheet after the Flow is renamed', (
    tester,
  ) async {
    await _pumpFollowSkySheet(tester, flowName: 'My own night practice');

    expect(_sheet, findsOneWidget);
    expect(_resizeHandle, findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('follow-sky-observation-presentation')),
      findsOneWidget,
    );
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

  testWidgets(
    'Day View Follow Sky block reopens after shared barrier dismissal',
    (tester) async {
      tester.view.physicalSize = _viewport;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final behaviorPayload = TrackSkyEventOwnership.behaviorPayload(
        skyEventId: 'full-moon-2026-08-28',
        resolvedFunction: 'ENDURE',
        intention: 'self confidence',
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: _visualCaptureKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark,
            home: Scaffold(
              body: DayViewGrid(
                ky: 1,
                km: 1,
                kd: 1,
                notes: <NoteData>[
                  NoteData(
                    clientEventId: 'follow-sky-day-view-fixture',
                    title: 'Full Moon + Partial Lunar Eclipse',
                    allDay: false,
                    start: const TimeOfDay(hour: 21, minute: 12),
                    end: const TimeOfDay(hour: 22, minute: 0),
                    flowId: _flowId,
                    behaviorPayload: behaviorPayload,
                  ),
                ],
                showGregorian: false,
                flowIndex: const <int, FlowData>{
                  _flowId: FlowData(
                    id: _flowId,
                    name: 'Follow the Sky',
                    color: Color(0xFF9DA8FF),
                    active: true,
                  ),
                },
                activeLedgerFlowIds: const <int>{_flowId},
                initialScrollOffset: 20 * 60,
                followSkyCatalog: _catalog,
                followSkyInstrumentProvider:
                    const CatalogSkyInstrumentDataProvider(),
                followSkyNow: () => DateTime(2026, 8, 27, 12),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final eventLayer = find.byKey(dayViewTimelineEventLayerKey);
      final previewLayer = find.byKey(dayViewTimelinePreviewLayerKey);
      Finder followSkyBlocksIn(Finder layer) => find.descendant(
        of: layer,
        matching: find.byType(TrackSkyEventBlockVisual),
      );
      expect(followSkyBlocksIn(eventLayer), findsOneWidget);
      expect(followSkyBlocksIn(previewLayer), findsNothing);

      await tester.tap(followSkyBlocksIn(eventLayer));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(_sheet, findsOneWidget);
      expect(CalendarEventDetailSheetCoordinator.isOpenOrOpening, isTrue);
      await expectLater(
        find.byKey(_visualCaptureKey),
        matchesGoldenFile(
          '$_goldenRoot/maat-day-housing-follow-sky-lowered-390x844.png',
        ),
      );

      final foreground = find.byKey(
        const ValueKey<String>('follow-sky-static-lower-sheet'),
      );
      final loweredRect = tester.getRect(foreground);
      await tester.dragFrom(
        Offset(loweredRect.center.dx, loweredRect.top + 24),
        const Offset(0, -250),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(foreground).top, lessThan(loweredRect.top));
      await expectLater(
        find.byKey(_visualCaptureKey),
        matchesGoldenFile(
          '$_goldenRoot/maat-day-housing-follow-sky-raised-390x844.png',
        ),
      );

      final sheetTop = tester.getTopLeft(_sheet).dy;
      expect(sheetTop, greaterThan(0));
      await tester.tapAt(Offset(_viewport.width / 2, sheetTop / 2));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(_sheet, findsNothing);
      expect(CalendarEventDetailSheetCoordinator.isOpenOrOpening, isFalse);

      await tester.tap(followSkyBlocksIn(eventLayer));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(_sheet, findsOneWidget);
      expect(CalendarEventDetailSheetCoordinator.isOpenOrOpening, isTrue);
    },
  );
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
  String flowName = 'Follow the Sky',
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
    RepaintBoundary(
      key: _visualCaptureKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: Builder(
          builder: (context) => Scaffold(
            backgroundColor: Colors.black,
            resizeToAvoidBottomInset: false,
            body: CalendarEventDetailSheet(
              hostContext: context,
              initialTarget: target,
              followSkyCatalog: _catalog,
              followSkyInstrumentProvider:
                  const CatalogSkyInstrumentDataProvider(),
              followSkyNow: () => DateTime(2026, 8, 27, 12),
              flowResolver: (flowId) => flowId == _flowId
                  ? FlowData(
                      id: _flowId,
                      name: flowName,
                      color: Color(0xFF9DA8FF),
                      active: true,
                    )
                  : null,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
