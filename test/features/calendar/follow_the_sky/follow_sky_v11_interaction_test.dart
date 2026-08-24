import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/follow_the_sky/follow_the_sky.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/widgets/follow_sky_v11_dock.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/widgets/follow_sky_v11_tokens.dart';

void main() {
  late SkyCatalog catalog;

  setUpAll(() {
    catalog = SkyCatalogRepository.parseJsonString(
      File('assets/follow_the_sky/sky_catalog_v2.json').readAsStringSync(),
    );
  });

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
      expect(ringRect.width, FollowSkyV11Tokens.skyRingDiameter);
      expect(ringRect.height, FollowSkyV11Tokens.skyRingDiameter);
      expect(ringRect.contains(numberRect.topLeft), isTrue);
      expect(ringRect.contains(numberRect.bottomRight), isTrue);
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
}

Finder _byKeyPrefix(String prefix) => find.byWidgetPredicate((widget) {
  final key = widget.key;
  return key is ValueKey<String> && key.value.startsWith(prefix);
});

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
