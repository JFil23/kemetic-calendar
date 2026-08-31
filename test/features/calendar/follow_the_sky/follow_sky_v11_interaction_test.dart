import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/follow_the_sky/follow_the_sky.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/widgets/follow_sky_v11_dock.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/widgets/follow_sky_v11_tokens.dart';
import 'package:mobile/widgets/day_sheet_components.dart';
import 'package:mobile/widgets/kemetic_keyboard.dart';
import 'package:mobile/widgets/keyboard_viewport_metrics.dart';

void main() {
  late SkyCatalog catalog;

  setUpAll(() {
    catalog = SkyCatalogRepository.parseJsonString(
      File('assets/follow_the_sky/sky_catalog_v2.json').readAsStringSync(),
    );
  });

  // Keep this historical ID because the forward gate requires an additive
  // test inventory. The shared editor it originally covered was rolled back
  // at the user's direction; this contract now prevents that presentation
  // layer from returning while preserving the prior field ownership.
  test(
    'shared Follow the Sky intention editor commits from keyboard and button',
    () {
      final exampleSource = File(
        'lib/features/calendar/follow_the_sky/presentation/widgets/'
        'follow_sky_turning_example.dart',
      ).readAsStringSync();
      final sheetSource = File(
        'lib/features/calendar/follow_the_sky/presentation/widgets/'
        'follow_sky_turning_sheet.dart',
      ).readAsStringSync();
      final retiredSharedEditor = File(
        'lib/features/calendar/follow_the_sky/presentation/widgets/'
        'follow_sky_intention_editor.dart',
      );

      expect(retiredSharedEditor.existsSync(), isFalse);
      expect(exampleSource, contains('TextField('));
      expect(exampleSource, contains('UnderlineInputBorder('));
      expect(exampleSource, isNot(contains('FollowSkyIntentionEditor')));
      expect(sheetSource, contains('DaySheetTextField('));
      expect(sheetSource, contains("child: const Text('Set intention')"));
      expect(sheetSource, isNot(contains('FollowSkyIntentionEditor')));
    },
  );

  testWidgets(
    'V11 keeps intention, sheet, exclusion, chronology, and Carry in one flow',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);

      final now = DateTime.utc(2026, 8, 24, 12);
      final allUpcoming = catalog.upcomingNights(nowUtc: now);
      final previewNights = allUpcoming.take(5).toList(growable: false);
      final thirtyDayNights = catalog.upcomingNights(
        nowUtc: now,
        untilUtc: now.add(const Duration(days: 30)),
      );
      expect(previewNights, hasLength(5));
      expect(thirtyDayNights.length, lessThan(previewNights.length));
      final intentionNight = previewNights.firstWhere(
        (night) => night.companion != null,
        orElse: () => previewNights.first,
      );
      final excludedNight = previewNights.firstWhere(
        (night) => night.skyEventId != intentionNight.skyEventId,
      );
      final fifthNight = previewNights.last;
      TrackSkyEnrollmentDraft? capturedDraft;

      final preview = FollowSkyCalendarPreview(
        rows: [
          FollowSkyCalendarPreviewRow(
            localDay: intentionNight.primaryInstantUtc.toLocal(),
            start: intentionNight.primaryInstantUtc.toLocal().subtract(
              const Duration(hours: 2),
            ),
            end: intentionNight.primaryInstantUtc.toLocal().subtract(
              const Duration(hours: 1),
            ),
            title: 'Existing calendar event',
            eventColor: const Color(0xFF4E7A46),
          ),
          FollowSkyCalendarPreviewRow(
            localDay: DateTime(2026, 8, 25),
            start: DateTime(2026, 8, 25, 9),
            end: DateTime(2026, 8, 25, 10),
            title: 'Non-turning calendar event',
            eventColor: const Color(0xFF8E4B2E),
          ),
          FollowSkyCalendarPreviewRow(
            localDay: fifthNight.primaryInstantUtc.toLocal(),
            start: fifthNight.primaryInstantUtc.toLocal().subtract(
              const Duration(hours: 2),
            ),
            end: fifthNight.primaryInstantUtc.toLocal().subtract(
              const Duration(hours: 1),
            ),
            title: 'Fifth turning calendar context',
            eventColor: const Color(0xFF3B5D82),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: FollowSkyDetailPage(
            initialCatalog: catalog,
            calendarPreview: preview,
            now: now,
            onJoin: (draft) async {
              capturedDraft = draft;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_byKeyPrefix('follow-sky-strip-day-'), findsNWidgets(30));
      expect(_byKeyPrefix('follow-sky-strip-top-label-'), findsNothing);
      expect(find.text('START DATE'), findsNothing);
      final todayDateKey = _dateKey(DateUtils.dateOnly(now.toLocal()));
      final todayRing = find.byKey(
        ValueKey<String>('follow-sky-strip-ring-$todayDateKey'),
      );
      final todayTile = find.byKey(
        ValueKey<String>('follow-sky-strip-day-$todayDateKey'),
      );
      final todayNumber = find.byKey(
        ValueKey<String>('follow-sky-strip-number-$todayDateKey'),
      );
      final todayDots = find.byKey(
        ValueKey<String>('follow-sky-strip-dots-$todayDateKey'),
      );
      expect(todayRing, findsOneWidget);
      final todayRingRect = tester.getRect(todayRing);
      final todayTileRect = tester.getRect(todayTile);
      final todayNumberRect = tester.getRect(todayNumber);
      final todayDotsRect = tester.getRect(todayDots);
      expect(
        tester.widget<Text>(todayNumber).style?.fontSize,
        FollowSkyV11Tokens.todayLabelFontSize,
      );
      expect(todayRingRect.width, closeTo(todayRingRect.height, 0.001));
      expect(
        todayRingRect.width,
        lessThan(FollowSkyV11Tokens.todayRingDiameter),
      );
      expect(todayRingRect.left, greaterThan(todayTileRect.left));
      expect(todayRingRect.right, lessThan(todayTileRect.right));
      expect(todayRingRect.contains(todayNumberRect.topLeft), isTrue);
      expect(todayRingRect.contains(todayNumberRect.bottomRight), isTrue);
      expect(
        todayDotsRect.top - todayRingRect.bottom,
        greaterThanOrEqualTo(FollowSkyV11Tokens.ringDotGap),
      );

      final intentionDateKey = _dateKey(
        intentionNight.primaryInstantUtc.toLocal(),
      );
      final ringRect = tester.getRect(
        find.byKey(ValueKey<String>('follow-sky-strip-ring-$intentionDateKey')),
      );
      final tileRect = tester.getRect(
        find.byKey(ValueKey<String>('follow-sky-strip-day-$intentionDateKey')),
      );
      final numberRect = tester.getRect(
        find.byKey(
          ValueKey<String>('follow-sky-strip-number-$intentionDateKey'),
        ),
      );
      final dotsRect = tester.getRect(
        find.byKey(ValueKey<String>('follow-sky-strip-dots-$intentionDateKey')),
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(
                ValueKey<String>('follow-sky-strip-number-$intentionDateKey'),
              ),
            )
            .style
            ?.fontSize,
        FollowSkyV11Tokens.dayNumberFontSize,
      );
      expect(ringRect.width, closeTo(ringRect.height, 0.001));
      expect(ringRect.width, lessThan(FollowSkyV11Tokens.skyRingDiameter));
      expect(ringRect.left, greaterThan(tileRect.left));
      expect(ringRect.right, lessThan(tileRect.right));
      expect(
        ringRect.contains(numberRect.topLeft),
        isTrue,
        reason: 'ring=$ringRect number=$numberRect',
      );
      expect(
        ringRect.contains(numberRect.bottomRight),
        isTrue,
        reason: 'ring=$ringRect number=$numberRect',
      );
      expect(
        dotsRect.top - ringRect.bottom,
        greaterThanOrEqualTo(FollowSkyV11Tokens.ringDotGap),
      );

      expect(_byKeyPrefix('follow-sky-preview-day-'), findsNWidgets(5));
      expect(find.text('Non-turning calendar event'), findsNothing);
      expect(find.text('Fifth turning calendar context'), findsOneWidget);
      for (final night in previewNights) {
        expect(
          find.byKey(
            ValueKey<String>('follow-sky-preview-${night.skyEventId}'),
          ),
          findsOneWidget,
        );
      }

      final scrollable = find
          .descendant(
            of: find.byKey(const ValueKey<String>('follow-sky-scroll')),
            matching: find.byType(Scrollable),
          )
          .first;
      expect(scrollable, findsOneWidget);
      final scrollState = tester.state<ScrollableState>(scrollable);
      expect(scrollState.position.maxScrollExtent, greaterThan(0));

      final workedField = find.byKey(
        const ValueKey<String>('follow-sky-worked-intention'),
      );
      await tester.scrollUntilVisible(workedField, 300, scrollable: scrollable);
      await tester.enterText(workedField, 'Finish my book');
      await tester.pump();

      final intentionCard = find.byKey(
        ValueKey<String>('follow-sky-preview-${intentionNight.skyEventId}'),
      );
      await tester.scrollUntilVisible(
        intentionCard,
        400,
        scrollable: scrollable,
      );
      expect(find.text('“Finish my book”'), findsOneWidget);
      final offsetBeforeSheet = scrollState.position.pixels;
      final maxBeforeSheet = scrollState.position.maxScrollExtent;

      await tester.tap(intentionCard);
      await tester.pumpAndSettle();
      final sheetField = find.byKey(
        const ValueKey<String>('follow-sky-turning-intention'),
      );
      expect(sheetField, findsOneWidget);
      expect(find.text('Finish my book'), findsWidgets);

      final originalFlutterErrorHandler = FlutterError.onError;
      FlutterErrorDetails? keyboardErrorDetails;
      FlutterError.onError = (details) {
        keyboardErrorDetails = details;
        originalFlutterErrorHandler?.call(details);
      };
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      await tester.pump();
      await tester.enterText(sheetField, 'Finish my second draft');
      await tester.pump();
      final keyboardLayoutException = tester.takeException();
      FlutterError.onError = originalFlutterErrorHandler;
      if (keyboardLayoutException != null) {
        final renderTree = tester.binding.renderViews.single.toStringDeep();
        final overflowIndex = renderTree.indexOf('OVERFLOWING');
        final overflowContext = overflowIndex < 0
            ? ''
            : renderTree.substring(
                (overflowIndex - 1800).clamp(0, renderTree.length),
                (overflowIndex + 800).clamp(0, renderTree.length),
              );
        final diagnostics = keyboardLayoutException is FlutterError
            ? keyboardLayoutException.toDiagnosticsNode().toStringDeep()
            : keyboardLayoutException.toString();
        fail(
          'Keyboard layout exception:\n$diagnostics\n'
          '${keyboardErrorDetails?.toString() ?? ''}\n$overflowContext',
        );
      }
      tester.view.resetViewInsets();
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey<String>('follow-sky-turning-save')),
      );
      await tester.pumpAndSettle();
      expect(
        scrollState.position.pixels,
        closeTo(offsetBeforeSheet, 1),
        reason:
            'max before=$maxBeforeSheet after=${scrollState.position.maxScrollExtent}',
      );
      expect(find.text('“Finish my second draft”'), findsOneWidget);
      expect(
        tester.widget<TextField>(workedField).controller!.text,
        'Finish my second draft',
      );

      final exclude = find.byKey(
        ValueKey<String>('follow-sky-exclude-${excludedNight.skyEventId}'),
      );
      await tester.scrollUntilVisible(exclude, 400, scrollable: scrollable);
      await tester.tap(exclude);
      await tester.pump();
      expect(exclude, findsNothing);

      final allToggle = find.byKey(
        const ValueKey<String>('follow-sky-all-turnings-toggle'),
      );
      await tester.scrollUntilVisible(allToggle, 500, scrollable: scrollable);
      scrollState.position.jumpTo(
        (scrollState.position.pixels + 180).clamp(
          scrollState.position.minScrollExtent,
          scrollState.position.maxScrollExtent,
        ),
      );
      await tester.pump();
      await tester.tap(allToggle);
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      final firstAfterPreview = allUpcoming[previewNights.length];
      expect(
        find.byKey(
          ValueKey<String>('follow-sky-all-${firstAfterPreview.skyEventId}'),
        ),
        findsOneWidget,
      );
      for (final night in previewNights) {
        expect(
          find.byKey(ValueKey<String>('follow-sky-all-${night.skyEventId}')),
          findsNothing,
        );
      }

      await tester.tap(find.byKey(const ValueKey<String>('follow-sky-carry')));
      await tester.pumpAndSettle();
      expect(capturedDraft, isNotNull);
      expect(
        capturedDraft!.occurrences.map((occurrence) => occurrence.skyEventId),
        isNot(contains(excludedNight.skyEventId)),
      );
      final materializedIntention = capturedDraft!.occurrences.singleWhere(
        (occurrence) => occurrence.skyEventId == intentionNight.skyEventId,
      );
      expect(
        TrackSkyEventOwnership.intentionFromPayload(
          materializedIntention.behaviorPayload,
        ),
        'Finish my second draft',
      );
      expect(
        materializedIntention.detail,
        contains('Intention: Finish my second draft'),
      );
      expect(find.text('In your calendar'), findsOneWidget);
      expect(
        tester.widget<FollowSkyV11Dock>(find.byType(FollowSkyV11Dock)).joined,
        isTrue,
      );
    },
  );

  testWidgets('clearing either intention surface clears the canonical draft', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.utc(2026, 8, 24, 12);
    final intentionNight = catalog
        .upcomingNights(nowUtc: now)
        .take(5)
        .firstWhere((night) => night.companion != null);
    await tester.pumpWidget(
      MaterialApp(
        home: FollowSkyDetailPage(initialCatalog: catalog, now: now),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = _followSkyScrollable();
    final inlineField = find.byKey(
      const ValueKey<String>('follow-sky-worked-intention'),
    );
    final intentionCard = find.byKey(
      ValueKey<String>('follow-sky-preview-${intentionNight.skyEventId}'),
    );
    await tester.scrollUntilVisible(inlineField, 300, scrollable: scrollable);
    await tester.enterText(inlineField, 'Clear from the sheet');
    await tester.pump();
    expect(find.text('“Clear from the sheet”'), findsOneWidget);

    await tester.scrollUntilVisible(intentionCard, 300, scrollable: scrollable);
    await tester.tap(intentionCard);
    await tester.pumpAndSettle();
    final sheetField = find.byKey(
      const ValueKey<String>('follow-sky-turning-intention'),
    );
    await tester.enterText(sheetField, '');
    await tester.tap(
      find.byKey(const ValueKey<String>('follow-sky-turning-save')),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(inlineField).controller!.text, isEmpty);
    expect(find.text('“Clear from the sheet”'), findsNothing);

    await tester.enterText(inlineField, 'Clear from inline');
    await tester.pump();
    expect(find.text('“Clear from inline”'), findsOneWidget);
    await tester.enterText(inlineField, '   ');
    await tester.pump();
    expect(find.text('“Clear from inline”'), findsNothing);

    await tester.scrollUntilVisible(intentionCard, 300, scrollable: scrollable);
    final scrollState = tester.state<ScrollableState>(scrollable);
    scrollState.position.jumpTo(
      (scrollState.position.pixels - 100).clamp(
        scrollState.position.minScrollExtent,
        scrollState.position.maxScrollExtent,
      ),
    );
    await tester.pump();
    await tester.tap(intentionCard);
    await tester.pumpAndSettle();
    final sheetEditable = find.descendant(
      of: find.byKey(const ValueKey<String>('follow-sky-turning-intention')),
      matching: find.byType(EditableText),
    );
    expect(tester.widget<EditableText>(sheetEditable).controller.text, isEmpty);
  });

  testWidgets('inline-only intention is serialized by Carry', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.utc(2026, 8, 24, 12);
    final intentionNight = catalog
        .upcomingNights(nowUtc: now)
        .take(5)
        .firstWhere((night) => night.companion != null);
    TrackSkyEnrollmentDraft? capturedDraft;
    await tester.pumpWidget(
      MaterialApp(
        home: FollowSkyDetailPage(
          initialCatalog: catalog,
          now: now,
          onJoin: (draft) async => capturedDraft = draft,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final inlineField = find.byKey(
      const ValueKey<String>('follow-sky-worked-intention'),
    );
    await tester.scrollUntilVisible(
      inlineField,
      300,
      scrollable: _followSkyScrollable(),
    );
    await tester.enterText(inlineField, 'Inline path only');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('follow-sky-carry')));
    await tester.pumpAndSettle();

    expect(capturedDraft, isNotNull);
    final occurrence = capturedDraft!.occurrences.singleWhere(
      (candidate) => candidate.skyEventId == intentionNight.skyEventId,
    );
    expect(
      TrackSkyEventOwnership.intentionFromPayload(occurrence.behaviorPayload),
      'Inline path only',
    );
    expect(occurrence.detail, contains('Intention: Inline path only'));
    expect(
      find.byKey(const ValueKey<String>('follow-sky-turning-intention')),
      findsNothing,
    );
  });

  for (final scenario in _KeyboardViewportScenario.values) {
    testWidgets(
      'worked intention survives ${scenario.label} from the recorded reading position',
      (tester) => _expectWorkedIntentionKeyboardContract(
        tester,
        catalog: catalog,
        scenario: scenario,
      ),
    );
  }

  testWidgets(
    'worked intention stays visible above keyboard without focus-cycle drift',
    (tester) => _expectWorkedIntentionKeyboardContract(
      tester,
      catalog: catalog,
      scenario: _KeyboardViewportScenario.webLayoutSizedPanned,
      standalone: false,
    ),
  );

  testWidgets(
    'embedded worked intention reserves the shared keyboard occlusion once',
    (tester) => _expectWorkedIntentionKeyboardContract(
      tester,
      catalog: catalog,
      scenario: _KeyboardViewportScenario.webLayoutSized,
      standalone: false,
    ),
  );

  testWidgets(
    'focused embedded intention fills visual and layout-sized iOS viewports',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(home: _FollowSkyEditingSheetHarness(catalog: catalog)),
      );
      await tester.pumpAndSettle();

      final sheet = find.byKey(daySheetKeyboardSafeFrameKey);
      final tabs = find.byKey(_followSkyTestTabsKey);
      final field = find.byKey(
        const ValueKey<String>('follow-sky-worked-intention'),
      );
      final question = find.text(
        'What do you want to stay true to when conditions change?',
      );
      final dock = find.byType(FollowSkyV11Dock);
      final dockControl = find.byKey(
        const ValueKey<String>('follow-sky-carried'),
      );
      final scrollable = _followSkyScrollable();
      final scrollState = tester.state<ScrollableState>(scrollable);

      await tester.scrollUntilVisible(field, 100, scrollable: scrollable);
      await tester.pumpAndSettle();
      const recordedQuestionTop = 370.0;
      final readingOffset =
          (scrollState.position.pixels +
                  tester.getTopLeft(question).dy -
                  recordedQuestionTop)
              .clamp(
                scrollState.position.minScrollExtent,
                scrollState.position.maxScrollExtent,
              )
              .toDouble();
      scrollState.position.jumpTo(readingOffset);
      await tester.pump();

      final closedSheetRect = tester.getRect(sheet);
      expect(closedSheetRect.top, closeTo(84.4, 0.01));
      expect(closedSheetRect.height, closeTo(759.6, 0.01));

      await tester.tap(field);
      await tester.pump();

      final focusedSheetRect = tester.getRect(sheet);
      expect(focusedSheetRect.top, lessThan(closedSheetRect.top));
      expect(focusedSheetRect.top, closeTo(0, 0.01));
      expect(focusedSheetRect.height, closeTo(844, 0.01));

      tester.view.physicalSize = const Size(390, 500);
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pump();

      final visualSheetRect = tester.getRect(sheet);
      final visualTabsRect = tester.getRect(tabs);
      final visualQuestionRect = tester.getRect(question);
      final visualFieldRect = tester.getRect(field);
      final visualDockRect = tester.getRect(dock);
      final visualDockControlRect = tester.getRect(dockControl);
      final visualGeometry =
          'tabs=$visualTabsRect question=$visualQuestionRect '
          'field=$visualFieldRect dock=$visualDockRect '
          'dockControl=$visualDockControlRect';

      expect(visualSheetRect.top, closeTo(0, 0.01));
      expect(visualSheetRect.height, closeTo(500, 0.01));
      expect(visualSheetRect.height, isNot(closeTo(450, 0.01)));
      expect(
        visualTabsRect.bottom,
        lessThan(visualQuestionRect.top),
        reason: visualGeometry,
      );
      expect(
        visualQuestionRect.bottom,
        lessThan(visualFieldRect.top),
        reason: visualGeometry,
      );
      expect(
        visualFieldRect.bottom,
        lessThan(visualDockControlRect.top),
        reason: visualGeometry,
      );
      expect(
        visualDockRect.bottom,
        lessThanOrEqualTo(500),
        reason: visualGeometry,
      );

      await tester.enterText(field, 'Visible while typing');
      await tester.pump();
      expect(tester.getRect(question), visualQuestionRect);
      expect(tester.getRect(field).bottom, lessThan(visualDockControlRect.top));

      tester.view.physicalSize = const Size(390, 844);
      tester.view.viewInsets = const FakeViewPadding(bottom: 344);
      await tester.pump();

      final layoutSheetRect = tester.getRect(sheet);
      expect(layoutSheetRect.top, closeTo(0, 0.01));
      expect(layoutSheetRect.height, closeTo(500, 0.01));
      expect(layoutSheetRect.bottom, closeTo(500, 0.01));
      expect(tester.getRect(tabs), visualTabsRect);
      expect(tester.getRect(question), visualQuestionRect);
      expect(tester.getRect(field), visualFieldRect);
      expect(dock, findsNothing);
      expect(dockControl, findsNothing);

      FocusManager.instance.primaryFocus?.unfocus();
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pump();

      expect(tester.getRect(sheet).top, closeTo(closedSheetRect.top, 0.01));
      expect(
        tester.getRect(sheet).height,
        closeTo(closedSheetRect.height, 0.01),
      );
      expect(dock, findsOneWidget);
      expect(dockControl, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'standalone worked intention remains visible through Scaffold resize',
    (tester) => _expectWorkedIntentionKeyboardContract(
      tester,
      catalog: catalog,
      scenario: _KeyboardViewportScenario.webLayoutSized,
    ),
  );
}

const _followSkyTestTabsKey = ValueKey<String>('follow-sky-test-tabs');

class _FollowSkyEditingSheetHarness extends StatefulWidget {
  const _FollowSkyEditingSheetHarness({required this.catalog});

  final SkyCatalog catalog;

  @override
  State<_FollowSkyEditingSheetHarness> createState() =>
      _FollowSkyEditingSheetHarnessState();
}

class _FollowSkyEditingSheetHarnessState
    extends State<_FollowSkyEditingSheetHarness> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  var _editing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Align(
        alignment: Alignment.bottomCenter,
        child: NotificationListener<FollowSkyIntentionEditingNotification>(
          onNotification: (notification) {
            if (_editing != notification.editing) {
              setState(() => _editing = notification.editing);
            }
            return true;
          },
          child: DaySheetKeyboardSafeFrame(
            expanded: _editing,
            scrollable: false,
            scrollBottomPadding: 0,
            bottomPadding: 0,
            horizontalPadding: 0,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 44),
                      DaySheetTabBar(
                        key: _followSkyTestTabsKey,
                        activeTab: DaySheetTab.flows,
                        accent: DaySheetTokens.gold,
                        onSelected: (_) {},
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Navigator(
                    key: _navigatorKey,
                    onGenerateInitialRoutes: (_, _) => [
                      MaterialPageRoute<void>(
                        builder: (context) => MaatFlowsListDetailReveal<void>(
                          initialDetailBuilder: (context) =>
                              FollowSkyDetailPage(
                                initialCatalog: widget.catalog,
                                now: DateTime.utc(2026, 8, 24, 12),
                                isJoined: true,
                                standalone: false,
                              ),
                          foregroundBuilder: (context, revealDetail) =>
                              const ColoredBox(color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _KeyboardViewportScenario {
  nativeInset('native stable-height keyboard'),
  webResize('web shrunken visual viewport'),
  iosWebTransition('iOS web transitional viewport plus inset'),
  webLayoutSized('web visual viewport with layout-sized Flutter'),
  webLayoutSizedPanned('panned web viewport with layout-sized Flutter');

  const _KeyboardViewportScenario(this.label);

  final String label;
}

Future<void> _expectWorkedIntentionKeyboardContract(
  WidgetTester tester, {
  required SkyCatalog catalog,
  required _KeyboardViewportScenario scenario,
  bool standalone = true,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  WebKeyboardViewportSnapshot? webViewport;
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => KemeticKeyboardHost(
        viewportMetricsResolver: (media) => KeyboardViewportMetrics.resolve(
          media: media,
          webViewport: webViewport,
        ),
        child: child ?? const SizedBox.shrink(),
      ),
      home: standalone
          ? FollowSkyDetailPage(
              initialCatalog: catalog,
              now: DateTime.utc(2026, 8, 24, 12),
            )
          : _FollowSkyEditingSheetHarness(catalog: catalog),
    ),
  );
  await tester.pumpAndSettle();

  final field = find.byKey(
    const ValueKey<String>('follow-sky-worked-intention'),
  );
  final question = find.text(
    'What do you want to stay true to when conditions change?',
  );
  final preview = _byKeyPrefix('follow-sky-preview-day-').first;
  final dock = find.byType(FollowSkyV11Dock);
  final scrollable = _followSkyScrollable();
  final scrollState = tester.state<ScrollableState>(scrollable);

  await tester.scrollUntilVisible(field, 100, scrollable: scrollable);
  await tester.pumpAndSettle();
  const recordedQuestionTop = 190.0;
  final readingOffset =
      (scrollState.position.pixels +
              tester.getTopLeft(question).dy -
              recordedQuestionTop)
          .clamp(
            scrollState.position.minScrollExtent,
            scrollState.position.maxScrollExtent,
          )
          .toDouble();
  scrollState.position.jumpTo(readingOffset);
  await tester.pump();

  final initialQuestionRect = tester.getRect(question);
  final initialFieldRect = tester.getRect(field);
  expect(dock, findsOneWidget);
  expect(initialQuestionRect.top, closeTo(recordedQuestionTop, 0.5));
  expect(initialFieldRect.top, greaterThan(initialQuestionRect.bottom));
  expect(initialFieldRect.bottom, lessThan(tester.getRect(preview).top));

  Future<void> openKeyboard() async {
    webViewport = switch (scenario) {
      _KeyboardViewportScenario.nativeInset => null,
      _KeyboardViewportScenario.webResize ||
      _KeyboardViewportScenario.webLayoutSized => const (
        height: 500,
        layoutHeight: 844,
        offsetTop: 0,
      ),
      _KeyboardViewportScenario.iosWebTransition ||
      _KeyboardViewportScenario.webLayoutSizedPanned => const (
        height: 500,
        layoutHeight: 844,
        offsetTop: 100,
      ),
    };
    switch (scenario) {
      case _KeyboardViewportScenario.nativeInset:
        tester.view.viewInsets = const FakeViewPadding(bottom: 344);
      case _KeyboardViewportScenario.webResize:
        tester.view.physicalSize = const Size(390, 500);
        tester.view.viewInsets = FakeViewPadding.zero;
      case _KeyboardViewportScenario.iosWebTransition:
        tester.view.physicalSize = const Size(390, 500);
        tester.view.viewInsets = const FakeViewPadding(bottom: 344);
      case _KeyboardViewportScenario.webLayoutSized:
      case _KeyboardViewportScenario.webLayoutSizedPanned:
        tester.view.physicalSize = const Size(390, 844);
        tester.view.viewInsets = FakeViewPadding.zero;
    }
    await tester.pump();
  }

  Future<void> closeKeyboard() async {
    webViewport = null;
    tester.view.viewInsets = FakeViewPadding.zero;
    tester.view.physicalSize = const Size(390, 844);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
  }

  void expectVisibleGeometry(String phase) {
    final (visibleTop, visibleBottom) = switch (scenario) {
      _KeyboardViewportScenario.webLayoutSizedPanned => (100.0, 600.0),
      _ => (0.0, 500.0),
    };
    final questionRect = tester.getRect(question);
    final fieldRect = tester.getRect(field);
    final previewRect = tester.getRect(preview);
    final editable = tester.state<EditableTextState>(
      find.descendant(of: field, matching: find.byType(EditableText)),
    );
    final caretRect = editable.renderEditable.getLocalRectForCaret(
      editable.textEditingValue.selection.extent,
    );
    final caretTop = editable.renderEditable
        .localToGlobal(caretRect.topLeft)
        .dy;
    final caretBottom = editable.renderEditable
        .localToGlobal(caretRect.bottomLeft)
        .dy;

    expect(dock, findsNothing, reason: phase);
    expect(fieldRect.top, greaterThan(questionRect.bottom), reason: phase);
    expect(fieldRect.top, greaterThanOrEqualTo(visibleTop), reason: phase);
    expect(fieldRect.bottom, lessThanOrEqualTo(visibleBottom), reason: phase);
    expect(fieldRect.bottom, lessThan(previewRect.top), reason: phase);
    expect(caretTop, greaterThanOrEqualTo(fieldRect.top), reason: phase);
    expect(caretBottom, lessThanOrEqualTo(visibleBottom), reason: phase);
  }

  await tester.tap(field);
  await tester.pump();
  await openKeyboard();
  for (final elapsed in const [40, 80, 140, 260]) {
    await tester.pump(Duration(milliseconds: elapsed));
    expectVisibleGeometry('${scenario.label} after ${elapsed}ms');
  }

  await tester.enterText(field, 'Visible while typing');
  await tester.pump(const Duration(milliseconds: 400));
  expectVisibleGeometry('${scenario.label} while typing');
  expect(
    tester.widget<TextField>(field).controller!.text,
    'Visible while typing',
  );

  tester.widget<TextField>(field).controller!.selection =
      const TextSelection.collapsed(offset: 7);
  await tester.pump();
  expectVisibleGeometry('${scenario.label} after cursor movement');

  final openedOffsets = <double>[scrollState.position.pixels];
  final dismissedOffsets = <double>[];
  for (var cycle = 0; cycle < 3; cycle++) {
    await closeKeyboard();
    expect(dock, findsOneWidget, reason: '${scenario.label} cycle $cycle');
    dismissedOffsets.add(scrollState.position.pixels);

    await tester.tap(field);
    await tester.pump();
    await openKeyboard();
    await tester.pumpAndSettle();
    expectVisibleGeometry('${scenario.label} cycle $cycle');
    openedOffsets.add(scrollState.position.pixels);
  }

  for (final offset in openedOffsets.skip(1)) {
    expect(offset, closeTo(openedOffsets.last, 0.5), reason: '$openedOffsets');
  }
  for (final offset in dismissedOffsets.skip(1)) {
    expect(
      offset,
      closeTo(dismissedOffsets.last, 0.5),
      reason: '$dismissedOffsets',
    );
  }
}

Finder _followSkyScrollable() => find
    .descendant(
      of: find.byKey(const ValueKey<String>('follow-sky-scroll')),
      matching: find.byType(Scrollable),
    )
    .first;

Finder _byKeyPrefix(String prefix) => find.byWidgetPredicate((widget) {
  final key = widget.key;
  return key is ValueKey<String> && key.value.startsWith(prefix);
});

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
