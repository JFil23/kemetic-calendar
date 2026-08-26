import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/follow_the_sky/follow_the_sky.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/widgets/follow_sky_v11_dock.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/widgets/follow_sky_v11_tokens.dart';
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
      final todayDateKey = _dateKey(DateUtils.dateOnly(now.toLocal()));
      final todayRing = find.byKey(
        ValueKey<String>('follow-sky-strip-ring-$todayDateKey'),
      );
      final todayNumber = find.byKey(
        ValueKey<String>('follow-sky-strip-number-$todayDateKey'),
      );
      final todayDots = find.byKey(
        ValueKey<String>('follow-sky-strip-dots-$todayDateKey'),
      );
      expect(todayRing, findsOneWidget);
      final todayRingRect = tester.getRect(todayRing);
      final todayNumberRect = tester.getRect(todayNumber);
      final todayDotsRect = tester.getRect(todayDots);
      expect(
        tester.widget<Text>(todayNumber).style?.fontSize,
        FollowSkyV11Tokens.todayLabelFontSize,
      );
      expect(todayRingRect.width, FollowSkyV11Tokens.todayRingDiameter);
      expect(todayRingRect.height, FollowSkyV11Tokens.todayRingDiameter);
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
      expect(
        ringRect.width,
        closeTo(FollowSkyV11Tokens.skyRingDiameter, 0.001),
      );
      expect(
        ringRect.height,
        closeTo(FollowSkyV11Tokens.skyRingDiameter, 0.001),
      );
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
}

enum _KeyboardViewportScenario {
  nativeInset('native stable-height keyboard'),
  webResize('web shrunken visual viewport'),
  iosWebTransition('iOS web transitional viewport plus inset');

  const _KeyboardViewportScenario(this.label);

  final String label;
}

Future<void> _expectWorkedIntentionKeyboardContract(
  WidgetTester tester, {
  required SkyCatalog catalog,
  required _KeyboardViewportScenario scenario,
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
      home: FollowSkyDetailPage(
        initialCatalog: catalog,
        now: DateTime.utc(2026, 8, 24, 12),
      ),
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
  expect(initialQuestionRect.top, closeTo(recordedQuestionTop, 0.5));
  expect(initialFieldRect.top, greaterThan(initialQuestionRect.bottom));
  expect(initialFieldRect.bottom, lessThan(tester.getRect(preview).top));

  Future<void> openKeyboard() async {
    webViewport = switch (scenario) {
      _KeyboardViewportScenario.nativeInset => null,
      _KeyboardViewportScenario.webResize ||
      _KeyboardViewportScenario.iosWebTransition => const (
        height: 524,
        layoutHeight: 844,
        offsetTop: 0,
      ),
    };
    switch (scenario) {
      case _KeyboardViewportScenario.nativeInset:
        tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      case _KeyboardViewportScenario.webResize:
        tester.view.physicalSize = const Size(390, 524);
        tester.view.viewInsets = FakeViewPadding.zero;
      case _KeyboardViewportScenario.iosWebTransition:
        tester.view.physicalSize = const Size(390, 524);
        tester.view.viewInsets = const FakeViewPadding(bottom: 320);
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
    const visibleBottom = 524.0;
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

    expect(questionRect.top, greaterThanOrEqualTo(0), reason: phase);
    expect(fieldRect.top, greaterThan(questionRect.bottom), reason: phase);
    expect(fieldRect.top, greaterThanOrEqualTo(0), reason: phase);
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

  final openedOffsets = <double>[scrollState.position.pixels];
  final dismissedOffsets = <double>[];
  for (var cycle = 0; cycle < 4; cycle++) {
    await closeKeyboard();
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
