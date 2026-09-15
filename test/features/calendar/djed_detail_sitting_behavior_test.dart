import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/follow_sky_calendar_preview.dart';
import 'package:mobile/features/calendar/maat_flow_response_draft_store.dart';
import 'package:mobile/features/calendar/the_djed/presentation/djed_day_presentation.dart';
import 'package:mobile/features/calendar/day_view.dart';
import 'package:mobile/features/calendar/the_djed/presentation/djed_detail_page.dart';
import 'package:mobile/features/calendar/the_djed/presentation/djed_detail_sitting_presentation.dart';
import 'package:mobile/features/calendar/the_djed/presentation/djed_sitting_behavior_surface.dart';
import 'package:mobile/features/calendar/the_djed_v2_flow.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/maat_flow_visual_test_fonts.dart';

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
    try {
      Supabase.instance.client;
    } catch (_) {
      await Supabase.initialize(
        url: 'https://example.supabase.co',
        anonKey: 'anon-key-0123456789012345678901234567890123456789',
      );
    }
    await loadMaatFlowVisualTestFonts();
  });

  setUp(() {
    kMaatFlowResponseDraftStore.clearForTesting();
    CalendarPage.debugOwnedDjedSittingEventTargetForTesting = null;
  });
  tearDown(() {
    kMaatFlowResponseDraftStore.clearForTesting();
    CalendarPage.debugOwnedDjedSittingEventTargetForTesting = null;
  });

  Future<void> pumpJoinedDjed(
    WidgetTester tester, {
    FollowSkyCalendarPreview calendarPreview = FollowSkyCalendarPreview.empty,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: buildMaatFlowTemplateDetailPreviewForTesting(
          joinedStartDate: DateTime(2026, 9, 6),
          joinedFlowId: 42,
          calendarPreview: calendarPreview,
        ),
      ),
    );
    await tester.pump();
    Object? heroLoadError;
    await tester.runAsync(
      () => precacheImage(
        const AssetImage(DjedDetailTokens.heroAsset),
        tester.element(find.byType(DjedDetailSurface)),
        onError: (exception, stackTrace) => heroLoadError = exception,
      ),
    );
    expect(heroLoadError, isNull);
    await tester.pumpAndSettle();
  }

  Future<void> openSitting(WidgetTester tester, int number) async {
    final sitting = find.byKey(
      ValueKey<String>('djed-event-block-detail-$number'),
    );
    await Scrollable.ensureVisible(
      tester.element(sitting),
      alignment: .5,
      duration: Duration.zero,
    );
    await tester.pumpAndSettle();
    await tester.tap(sitting);
    await tester.pumpAndSettle();
  }

  Future<void> closeSitting(WidgetTester tester, int number) async {
    final sheet = find.byKey(
      ValueKey<String>('djed-detail-sitting-sheet-$number'),
    );
    Navigator.of(tester.element(sheet)).pop();
    await tester.pumpAndSettle();
  }

  DayViewSheetEventTarget sittingTarget(int flowId, int sittingNumber) {
    final event = djedV2EventByNumber(sittingNumber)!;
    return DayViewSheetEventTarget(
      ky: 1,
      km: 1,
      kd: sittingNumber == 2 ? 5 : 9,
      event: EventItem(
        title: event.title,
        startMin: 30,
        endMin: 35,
        color: const Color(0xFFE0873C),
        allDay: false,
        flowId: flowId,
        clientEventId: djedV2ClientEventId(flowId: flowId, event: event),
      ),
    );
  }

  TextButton actionButton(WidgetTester tester, String label) {
    return tester.widget<TextButton>(
      find.ancestor(of: find.text(label), matching: find.byType(TextButton)),
    );
  }

  test('owned sitting identity is unavailable without a calendar host', () {
    expect(
      CalendarPage.hasOwnedDjedSittingEventIdentity(
        flowId: 42,
        sittingNumber: 3,
      ),
      isFalse,
    );
  });

  testWidgets(
    'owned Djed sittings keep the detail sheet chrome and persist It helped',
    (tester) async {
      await pumpJoinedDjed(tester);
      await openSitting(tester, 3);

      expect(
        find.byKey(const ValueKey<String>('djed-detail-sitting-sheet-3')),
        findsOneWidget,
      );
      expect(find.byType(DjedSittingBehaviorSurface), findsOneWidget);
      expect(find.byType(DjedDetailSittingPresentation), findsOneWidget);
      expect(find.byType(DjedDayPresentation), findsNothing);
      expect(find.text('Calendar'), findsNothing);

      await tester.scrollUntilVisible(
        find.text('It helped'),
        120,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey<String>('djed-detail-sitting-sheet-3')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('It helped'));
      await tester.pump();
      final values = kMaatFlowResponseDraftStore.valuesForFlow(
        'the-djed:v2:42',
      );
      expect(values['support-1-result']?.optionIds, contains('helped'));

      await closeSitting(tester, 3);
      expect(find.byType(DjedSittingBehaviorSurface), findsNothing);

      await openSitting(tester, 3);
      expect(find.text('What worked?'), findsOneWidget);
      expect(
        kMaatFlowResponseDraftStore
            .valuesForFlow('the-djed:v2:42')['support-1-result']
            ?.optionIds,
        contains('helped'),
      );
    },
  );

  testWidgets(
    'the same owned sitting is scheduled through Calendar, /flows, and an imported share',
    (tester) async {
      Future<void> expectOwnedSitting(Widget home) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(debugShowCheckedModeBanner: false, home: home),
        );
        await tester.pump();
        Object? heroLoadError;
        await tester.runAsync(
          () => precacheImage(
            const AssetImage(DjedDetailTokens.heroAsset),
            tester.element(find.byType(DjedDetailSurface)),
            onError: (exception, stackTrace) => heroLoadError = exception,
          ),
        );
        expect(heroLoadError, isNull);
        await tester.pumpAndSettle();
        await openSitting(tester, 3);
        expect(find.byType(DjedSittingBehaviorSurface), findsOneWidget);
        expect(find.byType(DjedDetailSittingPresentation), findsOneWidget);
        expect(find.byType(DjedDayPresentation), findsNothing);
        await closeSitting(tester, 3);
      }

      await expectOwnedSitting(
        buildMaatFlowTemplateDetailPreviewForTesting(
          joinedStartDate: DateTime(2026, 9, 6),
          joinedFlowId: 42,
          calendarPreview: FollowSkyCalendarPreview(
            rows: <FollowSkyCalendarPreviewRow>[
              FollowSkyCalendarPreviewRow(
                localDay: DateTime(2026, 9, 14),
                start: DateTime(2026, 9, 14, 6, 30),
                end: DateTime(2026, 9, 14, 6, 35),
                title: 'Djed 3: Read the result',
                flowName: 'The Djed',
                eventColor: const Color(0xFFE0873C),
              ),
            ],
          ),
        ),
      );
      await expectOwnedSitting(
        buildMaatFlowTemplateDetailPreviewForTesting(
          joinedStartDate: DateTime(2026, 9, 6),
          joinedFlowId: 42,
        ),
      );
      await expectOwnedSitting(
        CalendarPage.buildCanonicalMaatFlowDetail(
          name: 'The Djed',
          notes: 'maat=the-djed',
          relation: MaatFlowDetailRelation.owned,
          intendedFlowId: 42,
          intendedStart: DateTime(2026, 9, 6),
        )!,
      );
    },
  );

  testWidgets(
    'Make-to-do reuses the calendar to-do action once sitting identity exists',
    (tester) async {
      CalendarPage.debugOwnedDjedSittingEventTargetForTesting =
          ({required flowId, required sittingNumber}) {
            expect(flowId, 42);
            expect(sittingNumber, 2);
            return sittingTarget(flowId, sittingNumber);
          };
      await pumpJoinedDjed(tester);
      await openSitting(tester, 2);
      expect(actionButton(tester, 'Put on calendar').onPressed, isNotNull);
    },
  );

  testWidgets('invited Djed sittings keep restricted capabilities', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: CalendarPage.buildCanonicalMaatFlowDetail(
          name: 'The Djed',
          notes: 'maat=the-djed',
          relation: MaatFlowDetailRelation.invited,
        ),
      ),
    );
    await tester.pump();
    Object? heroLoadError;
    await tester.runAsync(
      () => precacheImage(
        const AssetImage(DjedDetailTokens.heroAsset),
        tester.element(find.byType(DjedDetailSurface)),
        onError: (exception, stackTrace) => heroLoadError = exception,
      ),
    );
    expect(heroLoadError, isNull);
    await tester.pumpAndSettle();

    final carry = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey<String>('djed-carry')),
    );
    expect(carry.onPressed, isNull);

    await openSitting(tester, 2);
    expect(find.byType(DjedDetailSittingPresentation), findsOneWidget);
    expect(find.byType(DjedSittingBehaviorSurface), findsNothing);
    expect(find.byType(DjedDayPresentation), findsNothing);
    expect(actionButton(tester, 'Put on calendar').onPressed, isNull);
  });

  testWidgets(
    'Djed sitting cards use live calendar rows instead of fixture appointments',
    (tester) async {
      await pumpJoinedDjed(
        tester,
        calendarPreview: FollowSkyCalendarPreview(
          rows: <FollowSkyCalendarPreviewRow>[
            FollowSkyCalendarPreviewRow(
              localDay: DateTime(2026, 9, 6),
              start: DateTime(2026, 9, 6, 12),
              end: DateTime(2026, 9, 6, 13),
              title: 'Office hours',
              flowName: 'Work',
              eventColor: const Color(0xFF399BEA),
            ),
          ],
        ),
      );

      final sitting = find.byKey(
        const ValueKey<String>('djed-event-block-detail-1'),
      );
      await Scrollable.ensureVisible(
        tester.element(sitting),
        alignment: .35,
        duration: Duration.zero,
      );
      await tester.pumpAndSettle();
      expect(find.text('Office hours'), findsOneWidget);
      expect(find.text('Bits and Operations'), findsNothing);
      expect(find.text("The Spider's Shortcut"), findsNothing);
    },
  );

  testWidgets('Djed context excludes only the represented event identity', (
    tester,
  ) async {
    final represented = djedV2EventByNumber(1)!;
    await pumpJoinedDjed(
      tester,
      calendarPreview: FollowSkyCalendarPreview(
        rows: <FollowSkyCalendarPreviewRow>[
          FollowSkyCalendarPreviewRow(
            eventId: djedV2ClientEventId(flowId: 42, event: represented),
            localDay: DateTime(2026, 9, 6),
            start: DateTime(2026, 9, 6, 6, 30),
            end: DateTime(2026, 9, 6, 6, 35),
            title: 'Represented Djed sitting',
            flowName: 'The Djed',
            eventColor: const Color(0xFFE0873C),
          ),
          FollowSkyCalendarPreviewRow(
            eventId: djedV2ClientEventId(flowId: 99, event: represented),
            localDay: DateTime(2026, 9, 6),
            start: DateTime(2026, 9, 6, 8),
            end: DateTime(2026, 9, 6, 8, 5),
            title: 'Another Djed instance',
            flowName: 'The Djed',
            eventColor: const Color(0xFFE0873C),
          ),
        ],
      ),
    );

    final sitting = find.byKey(
      const ValueKey<String>('djed-event-block-detail-1'),
    );
    await Scrollable.ensureVisible(
      tester.element(sitting),
      alignment: .35,
      duration: Duration.zero,
    );
    await tester.pumpAndSettle();
    expect(find.text('Represented Djed sitting'), findsNothing);
    expect(find.text('Another Djed instance'), findsOneWidget);
  });

  testWidgets('detail event blocks receive their edited support names', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: DjedDetailSurface(
          supports: const <DjedSupportFixture>[
            DjedSupportFixture(
              name: 'Body',
              condition: DjedSupportCondition.holding,
            ),
            DjedSupportFixture(
              name: 'Family',
              condition: DjedSupportCondition.underPressure,
            ),
            DjedSupportFixture(
              name: 'Work',
              condition: DjedSupportCondition.wobbling,
            ),
            DjedSupportFixture(
              name: 'Practice',
              condition: DjedSupportCondition.holding,
            ),
          ],
          onCarry: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final block = find.byKey(
      const ValueKey<String>('djed-event-block-detail-2'),
    );
    await Scrollable.ensureVisible(
      tester.element(block),
      alignment: .5,
      duration: Duration.zero,
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: block, matching: find.text('Body')),
      findsOneWidget,
    );
  });

  testWidgets('detail disclosure survives ordinary form updates', (
    tester,
  ) async {
    await pumpJoinedDjed(tester);
    await openSitting(tester, 2);
    final onMoveChanged = tester
        .widget<TextFormField>(
          find.byKey(const ValueKey<String>('djed-move-field')),
        )
        .onChanged!;
    final scrollable = find.byKey(
      const PageStorageKey<String>('djed-detail-sitting-scroll'),
    );
    await tester.drag(scrollable, const Offset(0, -700));
    await tester.pumpAndSettle();
    final disclosure = find.byKey(
      const ValueKey<String>('djed-detail-source-disclosure'),
    );
    await tester.tap(disclosure);
    await tester.pumpAndSettle();
    final source = find.byKey(
      const ValueKey<String>('djed-detail-source-body'),
    );
    expect(source, findsOneWidget);
    final scrollPosition = find
        .descendant(of: scrollable, matching: find.byType(Scrollable))
        .first;
    final before = tester
        .state<ScrollableState>(scrollPosition)
        .position
        .pixels;

    onMoveChanged('one small action');
    await tester.pump();
    expect(source, findsOneWidget);
    expect(
      tester.state<ScrollableState>(scrollPosition).position.pixels,
      closeTo(before, .1),
    );
  });

  testWidgets('closing a sitting restores the Djed detail list offset', (
    tester,
  ) async {
    await pumpJoinedDjed(tester);
    final sitting = find.byKey(
      const ValueKey<String>('djed-event-block-detail-3'),
    );
    await Scrollable.ensureVisible(
      tester.element(sitting),
      alignment: .5,
      duration: Duration.zero,
    );
    await tester.pumpAndSettle();
    final detailScrollable = find
        .descendant(
          of: find.byKey(const ValueKey<String>('djed-detail-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    final before = tester
        .state<ScrollableState>(detailScrollable)
        .position
        .pixels;

    await tester.tap(sitting);
    await tester.pumpAndSettle();
    await closeSitting(tester, 3);

    expect(
      tester.state<ScrollableState>(detailScrollable).position.pixels,
      closeTo(before, .1),
    );
  });

  testWidgets('catalog preview sittings stay on the visual presentation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: DjedDetailSurface(onCarry: () {}, onBack: () {}),
      ),
    );
    await tester.pump();
    Object? heroLoadError;
    await tester.runAsync(
      () => precacheImage(
        const AssetImage(DjedDetailTokens.heroAsset),
        tester.element(find.byType(DjedDetailSurface)),
        onError: (exception, stackTrace) => heroLoadError = exception,
      ),
    );
    expect(heroLoadError, isNull);
    await tester.pumpAndSettle();

    final sitting = find.byKey(
      const ValueKey<String>('djed-event-block-detail-1'),
    );
    await Scrollable.ensureVisible(
      tester.element(sitting),
      alignment: .5,
      duration: Duration.zero,
    );
    await tester.pumpAndSettle();
    await tester.tap(sitting);
    await tester.pumpAndSettle();
    expect(find.byType(DjedDetailSittingPresentation), findsOneWidget);
    expect(find.byType(DjedSittingBehaviorSurface), findsNothing);
    expect(find.byType(DjedDayPresentation), findsNothing);
    expect(find.text('Calendar'), findsNothing);
  });
}
