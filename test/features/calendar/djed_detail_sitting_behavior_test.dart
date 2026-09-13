import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/follow_sky_calendar_preview.dart';
import 'package:mobile/features/calendar/maat_flow_response_draft_store.dart';
import 'package:mobile/features/calendar/the_djed/presentation/djed_day_behavior_surface.dart';
import 'package:mobile/features/calendar/the_djed/presentation/djed_day_presentation.dart';
import 'package:mobile/features/calendar/day_view.dart';
import 'package:mobile/features/calendar/the_djed/presentation/djed_detail_page.dart';
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
    await tester.tap(
      find.byKey(ValueKey<String>('djed-detail-sitting-close-$number')),
    );
    await tester.pumpAndSettle();
  }

  DayViewSheetEventTarget sittingTarget(int flowId) {
    return DayViewSheetEventTarget(
      ky: 1,
      km: 1,
      kd: 9,
      event: EventItem(
        title: 'Djed 3: Read the result',
        startMin: 30,
        endMin: 35,
        color: const Color(0xFFE0873C),
        allDay: false,
        flowId: flowId,
        clientEventId: 'djed-v2:$flowId:support-1-result',
      ),
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
      expect(find.byType(DjedDayBehaviorSurface), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>('djed-detail-make-todo-unavailable'),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextButton>(
              find.byKey(
                const ValueKey<String>('djed-detail-make-todo-unavailable'),
              ),
            )
            .onPressed,
        isNull,
      );
      expect(find.text('Calendar'), findsOneWidget);

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
      expect(find.byType(DjedDayBehaviorSurface), findsNothing);

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
        expect(find.byType(DjedDayBehaviorSurface), findsOneWidget);
        expect(
          find.byKey(
            const ValueKey<String>('djed-detail-make-todo-unavailable'),
          ),
          findsOneWidget,
        );
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
            expect(sittingNumber, 3);
            return sittingTarget(flowId);
          };
      await pumpJoinedDjed(tester);
      await openSitting(tester, 3);
      final makeTodo = tester.widget<TextButton>(
        find.byKey(const ValueKey<String>('djed-detail-make-todo')),
      );
      expect(makeTodo.onPressed, isNotNull);
      expect(
        find.byKey(
          const ValueKey<String>('djed-detail-make-todo-unavailable'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'invited Djed sittings keep restricted capabilities',
    (tester) async {
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

      await openSitting(tester, 3);
      expect(find.byType(DjedDayPresentation), findsOneWidget);
      expect(find.byType(DjedDayBehaviorSurface), findsNothing);
      final makeTodo = tester.widget<TextButton>(
        find.byKey(const ValueKey<String>('djed-detail-make-todo')),
      );
      expect(makeTodo.onPressed, isNull);
      expect(
        find.byKey(
          const ValueKey<String>('djed-detail-make-todo-unavailable'),
        ),
        findsNothing,
      );
    },
  );

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
    expect(find.byType(DjedDayPresentation), findsOneWidget);
    expect(find.byType(DjedDayBehaviorSurface), findsNothing);
    final makeTodo = tester.widget<TextButton>(
      find.byKey(const ValueKey<String>('djed-detail-make-todo')),
    );
    expect(makeTodo.onPressed, isNull);
  });
}
