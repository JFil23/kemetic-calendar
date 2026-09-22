import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/flow_appearance.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_preview_day.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_thirty_day_calendar.dart';

import '../../support/maat_flow_visual_test_fonts.dart';

const _captureUserFlowDetail = bool.fromEnvironment('CAPTURE_USER_FLOW_DETAIL');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Uint8List heroImage;

  setUpAll(() async {
    await loadMaatFlowVisualTestFonts();
    final data = await rootBundle.load(
      'assets/follow_the_sky/discovery_hero.jpg',
    );
    heroImage = data.buffer.asUint8List();
  });

  Future<void> pumpDetail(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double textScale = 1,
    bool saved = false,
    bool longTitle = false,
    int eventCount = 14,
    String? flowName,
    FlowAppearance appearance = FlowAppearance.empty,
    Uint8List? appearanceImageBytes,
    String? captureName,
    DateTime? now,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'GentiumPlus'),
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: RepaintBoundary(
            key: const ValueKey<String>('user-flow-detail-capture'),
            child: buildMyFlowDetailPreviewForTesting(
              saved: saved,
              longTitle: longTitle,
              eventCount: eventCount,
              flowName: flowName,
              appearance: appearance,
              appearanceImageBytes: appearanceImageBytes,
              nowOverride: now ?? DateTime(2026, 9, 20),
            ),
          ),
        ),
      ),
    );
    if (appearanceImageBytes != null) {
      final captureContext = tester.element(
        find.byKey(const ValueKey<String>('user-flow-detail-capture')),
      );
      await tester.runAsync(
        () => precacheImage(MemoryImage(appearanceImageBytes), captureContext),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    if (_captureUserFlowDetail && captureName != null) {
      await expectLater(
        find.byKey(const ValueKey<String>('user-flow-detail-capture')),
        matchesGoldenFile('/tmp/$captureName.png'),
      );
    }
  }

  Future<void> captureDetail(
    WidgetTester tester,
    String name, {
    Finder? finder,
  }) async {
    if (!_captureUserFlowDetail) return;
    await expectLater(
      finder ?? find.byKey(const ValueKey<String>('user-flow-detail-capture')),
      matchesGoldenFile('/tmp/$name.png'),
    );
  }

  testWidgets('image-only detail keeps the photo as the complete hero', (
    tester,
  ) async {
    await pumpDetail(
      tester,
      appearance: const FlowAppearance(
        imageObjectPath: 'visual-contract/river.png',
        accentArgb: 0xFF8FA88A,
      ),
      appearanceImageBytes: heroImage,
      flowName: 'Morning Swim',
      captureName: 'user-flow-detail-image-only-390x844',
    );

    expect(
      find.byKey(const ValueKey('user-flow-appearance-image-layer')),
      findsWidgets,
    );
    expect(
      find.byKey(const ValueKey('user-flow-appearance-sign-layer')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('user-flow-detail-initial-fallback')),
      findsNothing,
    );
    expect(find.byType(MaatFlowThirtyDayCalendar), findsOneWidget);
    expect(find.text('Manage flow'), findsOneWidget);
  });

  testWidgets('detail with no image does not put an initial behind its title', (
    tester,
  ) async {
    await pumpDetail(
      tester,
      flowName: 'Morning Swim',
      captureName: 'user-flow-detail-no-image-390x844',
    );

    expect(
      find.byKey(const ValueKey('user-flow-detail-initial-fallback')),
      findsNothing,
    );
    expect(find.text('Morning Swim'), findsOneWidget);
  });

  testWidgets(
    'smart calendar and next five event cards use hydrated scheduling data',
    (tester) async {
      await pumpDetail(
        tester,
        eventCount: 8,
        flowName: 'Daily Math Visuals',
        appearance: const FlowAppearance(
          signKind: FlowSignKind.palmCount,
          accentArgb: 0xFFC08E6E,
        ),
      );

      final calendar = tester.widget<MaatFlowThirtyDayCalendar>(
        find.byType(MaatFlowThirtyDayCalendar),
      );
      expect(calendar.windowStart, DateTime(2026, 9, 20));
      expect(calendar.markers, hasLength(30));
      expect(calendar.markers.first.date, DateTime(2026, 9, 20));
      expect(calendar.markers.last.date, DateTime(2026, 10, 19));
      expect(
        calendar.markers.where((marker) => marker.secondaryColors.isNotEmpty),
        hasLength(3),
      );
      expect(
        calendar.markers.where((marker) => marker.topLabel == 'START DATE'),
        isEmpty,
      );

      final detailScrollable = find
          .descendant(
            of: find.byKey(
              const ValueKey<String>('user-flow-detail-scroll-72'),
            ),
            matching: find.byType(Scrollable),
          )
          .first;
      if (_captureUserFlowDetail) {
        await tester.scrollUntilVisible(
          find.byType(MaatFlowThirtyDayCalendar),
          420,
          scrollable: detailScrollable,
        );
        await tester.pumpAndSettle();
        await captureDetail(tester, 'user-flow-detail-smart-calendar-390x844');
      }

      final schedule = find.byKey(
        const ValueKey<String>('user-flow-schedule-72'),
      );
      await tester.scrollUntilVisible(
        schedule,
        520,
        scrollable: detailScrollable,
      );
      await tester.pumpAndSettle();

      expect(find.byType(MaatFlowPreviewDayCard), findsNWidgets(5));
      for (var day = 3; day <= 7; day++) {
        expect(
          find.byKey(ValueKey<String>('user-flow-schedule-day-$day')),
          findsOneWidget,
        );
        expect(
          find.byKey(ValueKey<String>('user-flow-schedule-block-$day')),
          findsOneWidget,
        );
      }
      for (var day = 1; day <= 2; day++) {
        expect(
          find.byKey(ValueKey<String>('user-flow-schedule-day-$day')),
          findsNothing,
        );
      }
      expect(
        find.byKey(const ValueKey<String>('user-flow-schedule-day-8')),
        findsNothing,
      );
      expect(find.text('journal every day'), findsWidgets);
      expect(find.text('Reading hour'), findsWidgets);
      expect(
        find.byKey(const ValueKey<String>('user-flow-show-past')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('user-flow-show-later')),
        findsOneWidget,
      );
      await captureDetail(
        tester,
        'user-flow-detail-first-five-schedule-390x844',
      );
      if (_captureUserFlowDetail) {
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey<String>('user-flow-schedule-day-7')),
          420,
          scrollable: detailScrollable,
        );
        await tester.pumpAndSettle();
        await captureDetail(
          tester,
          'user-flow-detail-first-five-schedule-bottom-390x844',
        );
      }

      final showPast = find.byKey(
        const ValueKey<String>('user-flow-show-past'),
      );
      await Scrollable.ensureVisible(tester.element(showPast));
      await tester.pumpAndSettle();
      await tester.tap(showPast);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('my_flow_day_row_72:preview-72-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('my_flow_day_row_72:preview-72-1')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('user-flow-hide-past')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('my_flow_day_row_72:preview-72-0')),
        findsNothing,
      );

      final showLater = find.byKey(
        const ValueKey<String>('user-flow-show-later'),
      );
      tester.widget<InkWell>(showLater).onTap!();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('my_flow_day_row_72:preview-72-7')),
        findsOneWidget,
      );
    },
  );

  testWidgets('long title steps down only after the 40px contract overflows', (
    tester,
  ) async {
    await pumpDetail(
      tester,
      longTitle: true,
      appearance: const FlowAppearance(
        signKind: FlowSignKind.gatheringVessel,
        accentArgb: 0xFFA88AAE,
      ),
      captureName: 'user-flow-detail-long-title-390x844',
    );

    final title = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('user-flow-detail-title')),
        matching: find.byType(Text),
      ),
    );
    expect(title.style?.fontSize, 34);
    expect(title.maxLines, 3);
  });

  testWidgets(
    '200 percent text preserves full body scale and clamps geometry',
    (tester) async {
      await pumpDetail(
        tester,
        textScale: 2,
        eventCount: 28,
        flowName: 'Evening Walk',
        appearance: const FlowAppearance(
          signKind: FlowSignKind.palmCount,
          accentArgb: 0xFF6F93A8,
        ),
        captureName: 'user-flow-detail-text-200-390x844',
      );

      final titleContext = tester.element(
        find.descendant(
          of: find.byKey(const ValueKey('user-flow-detail-title')),
          matching: find.byType(Text),
        ),
      );
      final calendarContext = tester.element(
        find.byType(MaatFlowThirtyDayCalendar),
      );
      final dockContext = tester.element(find.text('Manage flow'));
      expect(MediaQuery.textScalerOf(titleContext).scale(10), 20);
      expect(MediaQuery.textScalerOf(calendarContext).scale(10), 13);
      expect(MediaQuery.textScalerOf(dockContext).scale(10), 14);
    },
  );

  testWidgets('90-day detail always shows today through the next 29 days', (
    tester,
  ) async {
    await pumpDetail(
      tester,
      eventCount: 90,
      flowName: 'Ninety Days of Drawing',
      appearance: const FlowAppearance(
        signKind: FlowSignKind.riverPath,
        accentArgb: 0xFFC08E6E,
      ),
    );

    var calendar = tester.widget<MaatFlowThirtyDayCalendar>(
      find.byType(MaatFlowThirtyDayCalendar),
    );
    expect(calendar.windowStart, DateTime(2026, 9, 20));
    expect(calendar.markers.first.date, DateTime(2026, 9, 20));
    expect(calendar.markers.last.date, DateTime(2026, 10, 19));
    expect(
      find.byKey(const ValueKey<String>('user-flow-calendar-next')),
      findsNothing,
    );
    expect(find.text('DAY 3 OF 90'), findsOneWidget);

    await pumpDetail(
      tester,
      eventCount: 90,
      flowName: 'Ninety Days of Drawing',
      appearance: const FlowAppearance(
        signKind: FlowSignKind.riverPath,
        accentArgb: 0xFFC08E6E,
      ),
      now: DateTime(2026, 9, 21),
    );
    calendar = tester.widget<MaatFlowThirtyDayCalendar>(
      find.byType(MaatFlowThirtyDayCalendar),
    );
    expect(calendar.windowStart, DateTime(2026, 9, 21));
    expect(calendar.markers.last.date, DateTime(2026, 10, 20));
    await captureDetail(tester, 'user-flow-detail-90-day-390x844');
  });

  testWidgets('Saved detail keeps the full sheet and Kemetic start control', (
    tester,
  ) async {
    await pumpDetail(
      tester,
      saved: true,
      eventCount: 6,
      flowName: 'Daily Math Visuals',
      appearance: const FlowAppearance(
        signKind: FlowSignKind.palmCount,
        accentArgb: 0xFFC08E6E,
      ),
    );

    expect(find.text('SAVED · 6 DAYS'), findsOneWidget);
    expect(find.text('Carry this flow'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('user-flow-saved-start-control')),
      findsOneWidget,
    );
    final savedCards = tester
        .widgetList<MaatFlowPreviewDayCard>(find.byType(MaatFlowPreviewDayCard))
        .toList(growable: false);
    expect(savedCards, hasLength(5));
    expect(savedCards.first.date, DateTime(2026, 9, 20));
    expect(savedCards.last.date, DateTime(2026, 9, 24));
    final calendar = tester.widget<MaatFlowThirtyDayCalendar>(
      find.byType(MaatFlowThirtyDayCalendar),
    );
    expect(calendar.windowStart, DateTime(2026, 9, 20));
    expect(calendar.markers.last.date, DateTime(2026, 10, 19));
    await tester.tap(
      find.byKey(const ValueKey('user-flow-saved-start-control')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Start date'), findsOneWidget);
    await captureDetail(
      tester,
      'user-flow-detail-saved-390x844',
      finder: find.byType(Overlay).last,
    );
  });

  for (final size in const <Size>[Size(844, 390), Size(834, 1194)]) {
    testWidgets('detail uses the established shell without overflow at $size', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        size: size,
        appearance: const FlowAppearance(
          signKind: FlowSignKind.shen,
          accentArgb: 0xFF8FA88A,
        ),
        captureName: size.width > size.height
            ? 'user-flow-detail-landscape-844x390'
            : 'user-flow-detail-tablet-834x1194',
      );
      expect(find.byType(MaatFlowThirtyDayCalendar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
