import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/completion_status.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/day_view.dart';
import 'package:mobile/features/calendar/landscape_month_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    CalendarEventDetailSheetCoordinator.debugResetForTests();
  });

  tearDown(CalendarEventDetailSheetCoordinator.debugResetForTests);

  group('LandscapeMonthPager rotation handoff', () {
    testWidgets(
      'reports the current month when disposed after a settled swipe',
      (tester) async {
        await _setLandscapeViewport(tester);

        ({int ky, int km})? committedMonth;

        await tester.pumpWidget(
          _LandscapePagerHarness(
            onVisibleMonthCommitted: (ky, km) {
              committedMonth = (ky: ky, km: km);
            },
          ),
        );
        await tester.pumpAndSettle();

        final controller = _landscapePagerController(tester);
        controller.jumpToPage(controller.initialPage + 1);
        await tester.pumpAndSettle();

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();

        expect(committedMonth, isNotNull);
        expect(committedMonth!.ky, 6267);
        expect(committedMonth!.km, 5);
      },
    );

    testWidgets(
      'reports the rounded visible month when disposed during a swipe',
      (tester) async {
        await _setLandscapeViewport(tester);

        ({int ky, int km})? committedMonth;

        await tester.pumpWidget(
          _LandscapePagerHarness(
            onVisibleMonthCommitted: (ky, km) {
              committedMonth = (ky: ky, km: km);
            },
          ),
        );
        await tester.pumpAndSettle();

        final controller = _landscapePagerController(tester);
        controller.jumpTo(
          controller.position.pixels +
              (controller.position.viewportDimension * 0.6),
        );
        await tester.pump();

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();

        expect(committedMonth, isNotNull);
        expect(committedMonth!.ky, 6267);
        expect(committedMonth!.km, 5);
      },
    );

    testWidgets('detail sheets match day view action placement', (
      tester,
    ) async {
      await _setLandscapeViewport(tester);
      EventItem? sharedEvent;

      await tester.pumpWidget(
        _LandscapePagerHarness(
          notesForDay: (ky, km, kd) => kd == 1
              ? const [
                  NoteData(
                    clientEventId: 'landscape-note',
                    title: 'Landscape note',
                    allDay: false,
                    start: TimeOfDay(hour: 0, minute: 0),
                    end: TimeOfDay(hour: 1, minute: 0),
                  ),
                ]
              : const <NoteData>[],
          onShareNote: (event) async {
            sharedEvent = event;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Landscape note'));
      await tester.pumpAndSettle();

      expect(find.text('Make to-do'), findsOneWidget);
      expect(find.text('Share Note'), findsNothing);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('Share Note'), findsOneWidget);
      await tester.tap(find.text('Share Note'));
      await tester.pumpAndSettle();

      expect(sharedEvent, isNotNull);
      expect(sharedEvent!.title, 'Landscape note');
      expect(sharedEvent!.clientEventId, 'landscape-note');
    });

    testWidgets(
      'detail sheet clears selected completion and removes completion badge',
      (tester) async {
        await _setLandscapeViewport(tester);
        final recordedStatuses = <CompletionStatus>[];
        final appendedBadges = <String>[];
        final unrecordedClientEventIds = <String>[];
        final removedBadgeIds = <String>[];

        await tester.pumpWidget(
          _LandscapePagerHarness(
            flowIndex: const {
              1: FlowData(
                id: 1,
                name: 'Practice',
                color: Colors.green,
                active: true,
              ),
            },
            notesForDay: (ky, km, kd) => kd == 1
                ? const [
                    NoteData(
                      clientEventId: 'landscape-completion',
                      title: 'Landscape completion',
                      allDay: false,
                      start: TimeOfDay(hour: 0, minute: 0),
                      end: TimeOfDay(hour: 1, minute: 0),
                      flowId: 1,
                    ),
                  ]
                : const <NoteData>[],
            onAppendToJournal: (text) async {
              appendedBadges.add(text);
            },
            onRecordCompletion:
                ({
                  required String clientEventId,
                  required int flowId,
                  required DateTime completedOnDate,
                  Map<String, dynamic>? metadata,
                }) async {
                  recordedStatuses.add(
                    CompletionStatusX.fromWireName(
                      metadata?['completion_status']?.toString() ??
                          metadata?['status']?.toString(),
                    ),
                  );
                },
            onUnrecordCompletion: (clientEventId) async {
              unrecordedClientEventIds.add(clientEventId);
            },
            onRemoveCompletionBadge: (badgeId) async {
              removedBadgeIds.add(badgeId);
            },
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Landscape completion'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Observed').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Observed').last);
        await tester.pumpAndSettle();

        expect(recordedStatuses, <CompletionStatus>[CompletionStatus.observed]);
        expect(appendedBadges, hasLength(1));
        expect(unrecordedClientEventIds, <String>['landscape-completion']);
        expect(removedBadgeIds, <String>[
          'calendar:user_flow:cid:landscape-completion',
        ]);
      },
    );

    testWidgets('detail sheet matches day view pulse and haptic behavior', (
      tester,
    ) async {
      await _setLandscapeViewport(tester);
      final recordedStatuses = <CompletionStatus>[];

      await tester.pumpWidget(
        _LandscapePagerHarness(
          flowIndex: const {
            1: FlowData(
              id: 1,
              name: 'Practice',
              color: Colors.green,
              active: true,
            ),
          },
          notesForDay: (ky, km, kd) => kd == 1
              ? const [
                  NoteData(
                    clientEventId: 'landscape-pulse',
                    title: 'Landscape pulse',
                    allDay: false,
                    start: TimeOfDay(hour: 0, minute: 0),
                    end: TimeOfDay(hour: 1, minute: 0),
                    flowId: 1,
                  ),
                ]
              : const <NoteData>[],
          onRecordCompletion:
              ({
                required String clientEventId,
                required int flowId,
                required DateTime completedOnDate,
                Map<String, dynamic>? metadata,
              }) async {
                recordedStatuses.add(
                  CompletionStatusX.fromWireName(
                    metadata?['completion_status']?.toString() ??
                        metadata?['status']?.toString(),
                  ),
                );
              },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Landscape pulse'));
      await tester.pumpAndSettle();

      final hapticCalls = _capturePlatformHaptics(tester);
      expect(_ritualRimIntensity(tester), 0);
      expect(_ritualPulsePaintsFill(tester), isFalse);

      await tester.tap(find.text('Observed').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 140));
      final observedRimIntensity = _ritualRimIntensity(tester);

      expect(_ritualPulseMode(tester), 'observed');
      expect(observedRimIntensity, greaterThan(0));
      expect(_ritualPulseFillAlpha(tester), 0);
      expect(_ritualPulsePaintsFill(tester), isFalse);
      expect(
        _hapticArguments(hapticCalls),
        contains('HapticFeedbackType.mediumImpact'),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Partly').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 140));
      final partialRimIntensity = _ritualRimIntensity(tester);

      expect(_ritualPulseMode(tester), 'partial');
      expect(partialRimIntensity, greaterThan(0));
      expect(partialRimIntensity, lessThan(observedRimIntensity));
      expect(_ritualPulseFillAlpha(tester), 0);
      expect(_ritualPulsePaintsFill(tester), isFalse);
      expect(
        _hapticArguments(hapticCalls),
        contains('HapticFeedbackType.lightImpact'),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Skipped').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 140));

      expect(recordedStatuses, <CompletionStatus>[
        CompletionStatus.observed,
        CompletionStatus.partial,
        CompletionStatus.skipped,
      ]);
      expect(_ritualRimIntensity(tester), 0);
      expect(_ritualPulsePaintsFill(tester), isFalse);
      expect(
        _hapticArguments(
          hapticCalls,
        ).where((argument) => argument == 'HapticFeedbackType.mediumImpact'),
        hasLength(1),
      );
      expect(
        _hapticArguments(
          hapticCalls,
        ).where((argument) => argument == 'HapticFeedbackType.lightImpact'),
        hasLength(1),
      );
    });
  });

  group('Calendar month grid tablet layout', () {
    testWidgets('all four pinch expansion states render distinctly', (
      tester,
    ) async {
      await _setViewport(tester, const Size(430, 932));

      final heights = <MonthExpansionLevel, double>{};
      for (final level in MonthExpansionLevel.values) {
        await _pumpMonthCard(
          tester,
          expansionLevel: level,
          notesForDay: (day) => day == 4
              ? const [
                  NoteData(
                    title: 'Alpha event',
                    allDay: false,
                    start: TimeOfDay(hour: 9, minute: 0),
                    end: TimeOfDay(hour: 10, minute: 0),
                    manualColor: Colors.purple,
                  ),
                  NoteData(
                    title: 'Beta event',
                    allDay: false,
                    start: TimeOfDay(hour: 11, minute: 0),
                    end: TimeOfDay(hour: 12, minute: 0),
                    manualColor: Colors.green,
                  ),
                ]
              : const <NoteData>[],
        );

        final dayCell = find.byKey(const ValueKey<String>('k:6267-1-4|K'));
        heights[level] = tester.getSize(dayCell).height;

        switch (level) {
          case MonthExpansionLevel.compact:
          case MonthExpansionLevel.stacked:
            expect(find.text('Alpha event'), findsNothing);
            expect(find.text('Beta event'), findsNothing);
          case MonthExpansionLevel.labeled:
          case MonthExpansionLevel.details:
            expect(find.text('Alpha event'), findsOneWidget);
            expect(find.text('Beta event'), findsOneWidget);
        }
      }

      expect(
        heights[MonthExpansionLevel.compact]!,
        lessThan(heights[MonthExpansionLevel.stacked]!),
      );
      expect(
        heights[MonthExpansionLevel.stacked]!,
        lessThan(heights[MonthExpansionLevel.labeled]!),
      );
      expect(
        heights[MonthExpansionLevel.labeled]!,
        lessThan(heights[MonthExpansionLevel.details]!),
      );
    });

    testWidgets('non-compact event pills match mockup sizing steps', (
      tester,
    ) async {
      await _setViewport(tester, const Size(390, 844));
      List<NoteData> notesForDay(int day) => day == 4
          ? const [
              NoteData(
                title: 'Alpha event',
                allDay: false,
                start: TimeOfDay(hour: 9, minute: 0),
                end: TimeOfDay(hour: 10, minute: 0),
                manualColor: Colors.purple,
              ),
              NoteData(
                title: 'Beta event',
                allDay: false,
                start: TimeOfDay(hour: 11, minute: 0),
                end: TimeOfDay(hour: 12, minute: 0),
                manualColor: Colors.green,
              ),
            ]
          : const <NoteData>[];

      const dayCellKey = ValueKey<String>('k:6267-1-4|K');

      await _pumpMonthCard(
        tester,
        expansionLevel: MonthExpansionLevel.stacked,
        notesForDay: notesForDay,
      );
      final stackedPills = _eventPillContainersInDay(find.byKey(dayCellKey));
      expect(stackedPills, findsNWidgets(2));
      expect(find.text('Alpha event'), findsNothing);
      for (final size in _eventPillSizes(tester, stackedPills)) {
        expect(size.height, closeTo(12.0, 0.1));
        expect(size.width, greaterThanOrEqualTo(27.0));
      }

      await _pumpMonthCard(
        tester,
        expansionLevel: MonthExpansionLevel.labeled,
        notesForDay: notesForDay,
      );
      final labeledPills = _eventPillContainersInDay(find.byKey(dayCellKey));
      expect(labeledPills, findsNWidgets(2));
      for (final size in _eventPillSizes(tester, labeledPills)) {
        expect(size.height, closeTo(30.0, 0.1));
        expect(size.width, greaterThanOrEqualTo(27.0));
      }
      final labeledText = tester.widget<Text>(find.text('Alpha event'));
      expect(labeledText.maxLines, 1);
      expect(labeledText.textAlign, TextAlign.center);

      await _pumpMonthCard(
        tester,
        expansionLevel: MonthExpansionLevel.details,
        notesForDay: notesForDay,
      );
      final detailPills = _eventPillContainersInDay(find.byKey(dayCellKey));
      expect(detailPills, findsNWidgets(2));
      for (final size in _eventPillSizes(tester, detailPills)) {
        expect(size.height, closeTo(52.0, 0.1));
        expect(size.width, greaterThanOrEqualTo(27.0));
      }
      final detailText = tester.widget<Text>(find.text('Alpha event'));
      expect(detailText.maxLines, 3);
      expect(detailText.textAlign, TextAlign.center);
    });

    testWidgets('collapsed soft day tiles use visible filled surfaces', (
      tester,
    ) async {
      await _setViewport(tester, const Size(430, 932));
      await _pumpMonthCard(
        tester,
        expansionLevel: MonthExpansionLevel.compact,
        notesForDay: (day) => day == 4
            ? const [
                NoteData(
                  title: 'Marker event',
                  allDay: true,
                  manualColor: Colors.green,
                ),
              ]
            : const <NoteData>[],
      );

      final dayCell = find.byKey(const ValueKey<String>('k:6267-1-4|K'));
      final dayNumber = find.descendant(of: dayCell, matching: find.text('4'));
      final marker = find.byKey(const ValueKey<String>('k:6267-1-4-marker|K'));
      final monthCard = tester.widget<Card>(find.byType(Card).first);
      final tileBox = tester.widget<DecoratedBox>(
        find.descendant(of: dayCell, matching: find.byType(DecoratedBox)).first,
      );
      final decoration = tileBox.decoration as BoxDecoration;
      final tileFill = decoration.color!;
      final radius = decoration.borderRadius! as BorderRadius;
      final border = decoration.border! as Border;

      expect(monthCard.color, Colors.transparent);
      expect(tileFill, isNot(Colors.transparent));
      expect(tileFill.computeLuminance(), lessThan(0.006));
      expect(tileFill.computeLuminance(), greaterThan(0));
      expect(decoration.borderRadius, isNotNull);
      expect(radius.topLeft.x, equals(3));
      expect(radius.topLeft.y, equals(3));
      expect(border.top.width, greaterThan(0));
      expect(border.top.width, lessThanOrEqualTo(0.45));
      expect(
        border.top.color.computeLuminance(),
        greaterThan(tileFill.computeLuminance()),
      );

      expect(marker, findsOneWidget);
      expect(dayNumber, findsOneWidget);
      final numberRect = tester.getRect(dayNumber);
      final markerRect = tester.getRect(marker);
      expect(markerRect.center.dy, greaterThan(numberRect.center.dy));
    });

    testWidgets('kemetic weekday labels use the warm mockup grid color', (
      tester,
    ) async {
      await _setViewport(tester, const Size(430, 932));
      await _pumpMonthCard(tester, expansionLevel: MonthExpansionLevel.compact);

      final dayCell = find.byKey(const ValueKey<String>('k:6267-1-1|K'));
      final tileBox = tester.widget<DecoratedBox>(
        find.descendant(of: dayCell, matching: find.byType(DecoratedBox)).first,
      );
      final tileDecoration = tileBox.decoration as BoxDecoration;
      final tileFill = tileDecoration.color!;

      expect(tileFill.computeLuminance(), lessThan(0.006));
      expect(tileFill.computeLuminance(), greaterThan(0));

      final weekdayLabels = tester
          .widgetList<Text>(find.byType(Text))
          .where(
            (text) =>
                text.style?.fontSize == 11 &&
                text.style?.fontWeight == FontWeight.w600,
          )
          .toList();

      expect(weekdayLabels, isNotEmpty);
      for (final label in weekdayLabels) {
        expect(label.style?.color, const Color(0xFF756238));
        expect(
          label.style!.color!.computeLuminance(),
          greaterThan(tileFill.computeLuminance()),
        );
      }
    });

    testWidgets('month card does not add an expansion control', (tester) async {
      await _setViewport(tester, const Size(430, 932));
      await _pumpMonthCard(tester, expansionLevel: MonthExpansionLevel.details);

      expect(find.byType(IconButton), findsNothing);
      expect(find.byType(TextButton), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.byType(PopupMenuButton), findsNothing);
      expect(find.textContaining('Expand'), findsNothing);
      expect(find.textContaining('Collapse'), findsNothing);
    });

    testWidgets('expanded month layout has no overflows across target sizes', (
      tester,
    ) async {
      for (final viewport in const <({String name, Size size})>[
        (name: 'phone portrait', size: Size(390, 844)),
        (name: 'phone landscape', size: Size(844, 390)),
        (name: 'tablet portrait', size: Size(834, 1194)),
        (name: 'tablet landscape', size: Size(1194, 834)),
      ]) {
        await _setViewport(tester, viewport.size);
        await _pumpMonthCard(
          tester,
          expansionLevel: MonthExpansionLevel.details,
          notesForDay: _denseNotesForLayoutGuard,
        );

        expect(tester.takeException(), isNull, reason: viewport.name);
        _expectDecanCellsDoNotOverlap(tester);
      }
    });

    testWidgets(
      'full-expanded event pills stay inside day tiles across target sizes',
      (tester) async {
        for (final viewport in const <({String name, Size size})>[
          (name: 'phone portrait', size: Size(390, 844)),
          (name: 'phone landscape', size: Size(844, 390)),
          (name: 'tablet portrait', size: Size(834, 1194)),
          (name: 'tablet landscape', size: Size(1194, 834)),
        ]) {
          await _setViewport(tester, viewport.size);
          await _pumpMonthCard(
            tester,
            expansionLevel: MonthExpansionLevel.details,
            notesForDay: _denseNotesForLayoutGuard,
          );

          final dayCell = tester.getRect(
            find.byKey(const ValueKey<String>('k:6267-1-4|K')),
          );
          final eventTexts = find.byWidgetPredicate(
            (widget) =>
                widget is Text &&
                (widget.data?.startsWith('Contained event') ?? false),
          );
          expect(eventTexts, findsWidgets, reason: viewport.name);

          for (final element in tester.elementList(eventTexts)) {
            final box = element.renderObject! as RenderBox;
            final rect = box.localToGlobal(Offset.zero) & box.size;
            _expectRectInside(
              rect,
              dayCell,
              reason:
                  '${viewport.name}: ${tester.widget<Text>(find.byWidget(element.widget)).data}',
            );
          }

          final overflowCount = find.textContaining('+');
          if (overflowCount.evaluate().isNotEmpty) {
            final countRect = tester.getRect(overflowCount.first);
            _expectRectInside(countRect, dayCell, reason: viewport.name);
          }
        }
      },
    );

    testWidgets(
      'tablet landscape event chips stay inside day cells and overflow cleanly',
      (tester) async {
        await _setTabletLandscapeViewport(tester);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: buildCalendarMonthCardLayoutForTesting(
                  kYear: 6267,
                  kMonth: 1,
                  notesForDay: (day) => day == 4
                      ? List<NoteData>.generate(
                          6,
                          (index) => NoteData(
                            title: 'Tablet event ${index + 1}',
                            allDay: false,
                            start: TimeOfDay(hour: 8 + index, minute: 0),
                            end: TimeOfDay(hour: 9 + index, minute: 0),
                            manualColor: Colors.purple,
                          ),
                        )
                      : const <NoteData>[],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Tablet event 1'), findsOneWidget);
        expect(find.text('Tablet event 2'), findsOneWidget);
        expect(find.text('Tablet event 3'), findsOneWidget);
        expect(find.text('Tablet event 4'), findsOneWidget);
        expect(find.text('Tablet event 5'), findsNothing);
        expect(find.text('Tablet event 6'), findsNothing);
        expect(find.text('+2'), findsOneWidget);

        final dayCell = tester.getRect(
          find.byKey(const ValueKey<String>('k:6267-1-4|K')),
        );
        for (final label in const [
          'Tablet event 1',
          'Tablet event 2',
          'Tablet event 3',
          'Tablet event 4',
          '+2',
        ]) {
          final rect = tester.getRect(find.text(label));
          expect(rect.top, greaterThanOrEqualTo(dayCell.top));
          expect(rect.bottom, lessThanOrEqualTo(dayCell.bottom));
        }
      },
    );
  });

  group('Calendar month grid source guards', () {
    test('pinch expansion has four persisted states and no action control', () {
      final source = File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsStringSync();

      expect(MonthExpansionLevel.values, hasLength(4));
      expect(MonthExpansionLevel.values.map((level) => level.name), [
        'compact',
        'stacked',
        'labeled',
        'details',
      ]);
      expect(source, contains('PinchGestureSurface('));
      expect(source, contains('onScaleStart: _onScaleStart'));
      expect(source, contains('onScaleUpdate: _onScaleUpdate'));
      expect(source, contains('onScaleEnd: _onScaleEnd'));

      final appBar = _sourceBetween(
        source,
        'PreferredSizeWidget _buildCalendarAppBar',
        'Future<void> _openProfile',
      );
      final actions = _sourceBetween(
        source,
        'List<_CalendarAction> _calendarActions',
        'Future<void> _showActionsMenu',
      );
      final detachedActions = _sourceBetween(
        source,
        'static List<_CalendarAction> _detachedCalendarActions',
        'static Future<void> _openDetachedSharedCalendarsSheet',
      );
      for (final block in [appBar, actions, detachedActions]) {
        expect(block, isNot(contains('MonthExpansionLevel')));
        expect(block, isNot(contains('_setExpansionLevelSmooth')));
        expect(block, isNot(contains('_monthExpansion')));
      }
    });

    test('calendar expansion restoration uses interrupted settle target', () {
      expect(
        monthExpansionRestorationLevelForTesting(
          currentLevel: MonthExpansionLevel.compact,
          settleTarget: MonthExpansionLevel.details,
        ),
        MonthExpansionLevel.details,
      );

      expect(
        monthExpansionRestorationLevelForTesting(
          currentLevel: MonthExpansionLevel.compact,
          isPinching: true,
          pinchProgress: 1.2,
          pinchStartLevel: MonthExpansionLevel.compact,
        ),
        MonthExpansionLevel.stacked,
      );
    });

    test('existing calendar buttons and menu controls remain present', () {
      final source = File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsStringSync();

      for (final tooltip in const [
        "tooltip: 'New note'",
        "tooltip: 'Search notes'",
        "tooltip: 'Today'",
        "tooltip: 'My Profile'",
      ]) {
        expect(source, contains(tooltip));
      }

      for (final label in const [
        "label: 'Planner'",
        "label: 'Flow Studio'",
        "label: 'Library'",
        "label: 'Journal'",
        "label: 'Inbox'",
        "label: 'Calendars'",
        "label: 'Reflections'",
        "label: 'Home'",
        "label: 'Settings'",
        "label: 'New note'",
      ]) {
        expect(source, contains(label));
      }
    });

    test('calendar date system toggle does not post-frame repair scroll', () {
      final source = File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsStringSync();

      final handler = _sourceBetween(
        source,
        'void _handleCalendarToggleTapped() {',
        'GlobalKey? get _calendarMonthCoachmarkTargetKey',
      );

      expect(handler, contains('_showGregorian = !_showGregorian;'));
      expect(handler, contains('_scheduleCalendarRestorationSave'));
      expect(handler, isNot(contains('_currentViewportCalendarAnchor()')));
      expect(
        handler,
        isNot(contains('WidgetsBinding.instance.addPostFrameCallback')),
      );
      expect(handler, isNot(contains('_jumpToCalendarAnchorAtAlignmentNow')));
      expect(handler, isNot(contains('_jumpToTodayNow')));
    });

    test('month grid preserves established typography style references', () {
      final pageSource = File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsStringSync();
      final gridSource = File(
        'lib/features/calendar/calendar_grid_widgets.dart',
      ).readAsStringSync();
      final detailSource = File(
        'lib/features/calendar/calendar_month_detail.dart',
      ).readAsStringSync();

      for (final styleDefinition in const [
        'const TextStyle _monthTitleGold = TextStyle(',
        'const TextStyle _seasonStyle = TextStyle(',
        'const TextStyle _decanStyle = TextStyle(',
        'const TextStyle _weekdayLabelStyle = TextStyle(',
      ]) {
        expect(pageSource, contains(styleDefinition));
      }

      final monthCardBlock = _sourceBetween(
        gridSource,
        'class _MonthCard extends StatelessWidget',
        '/// Helper function to generate Kemetic day keys',
      );
      expect(monthCardBlock, contains('_SoftMonthNameTitle'));
      expect(monthCardBlock, contains('_CalendarScale.monthTitleMain'));
      expect(monthCardBlock, contains('opacity: framedSurface ? 0.98 : 0.96'));
      expect(monthCardBlock, contains('alpha: 0.029'));
      expect(monthCardBlock, contains('final rightLabelStyle = TextStyle('));
      expect(monthCardBlock, contains('final decanLabelStyle = TextStyle('));
      expect(monthCardBlock, contains('alpha: framedSurface ? 0.92 : 0.86'));
      expect(monthCardBlock, contains('final gregorianDecanLabelStyle ='));
      expect(monthCardBlock, contains('_CalendarTone.gregorianBlue'));
      expect(monthCardBlock, contains('final decanLabelRowHeight ='));
      expect(monthCardBlock, contains('final decanLabelStrut = StrutStyle('));
      expect(monthCardBlock, contains('height: decanLabelRowHeight'));
      expect(monthCardBlock, contains('strutStyle: decanLabelStrut'));
      expect(monthCardBlock, contains('fontFamilyFallback: const ['));
      expect(monthCardBlock, contains('letterSpacing: 0,'));
      expect(monthCardBlock, contains('decanLabelText('));
      expect(monthCardBlock, contains('decanLabelStyle'));
      expect(monthCardBlock, contains('gregorianDecanLabelStyle'));
      expect(
        monthCardBlock,
        isNot(
          contains(
            'GlossyText(\n                                text: gregDecanLabel',
          ),
        ),
      );

      final softTitleBlock = _sourceBetween(
        gridSource,
        'class _SoftMonthNameTitle extends StatelessWidget',
        'class _MonthCard extends StatelessWidget',
      );
      expect(softTitleBlock, contains('0.04,'));
      expect(softTitleBlock, contains('alpha: 0.88'));

      final seasonHeaderBlock = _sourceBetween(
        pageSource,
        'class _SeasonHeader extends StatelessWidget',
        '/* ─────────── Shared dark input',
      );
      expect(seasonHeaderBlock, contains('_CalendarTone.sectionLabel'));
      expect(seasonHeaderBlock, isNot(contains('GlossyText(')));

      final epagomenalBlock = _sourceBetween(
        gridSource,
        'class _EpagomenalCard extends StatelessWidget',
        '/* ───────────── Detail Page',
      );
      expect(epagomenalBlock, contains('_SoftMonthNameTitle('));
      expect(epagomenalBlock, contains('_CalendarTone.gregorianBlue'));
      expect(epagomenalBlock, isNot(contains("text: 'Heriu Renpet")));

      final infoTabBlock = _sourceBetween(
        detailSource,
        'class _InfoTab extends StatefulWidget',
        'class _InfoNodeEntry',
      );
      expect(infoTabBlock, contains('monthTitleShort'));
      expect(infoTabBlock, contains('_SoftMonthNameTitle('));
      expect(infoTabBlock, contains('_transliterationFontFallback'));
      expect(infoTabBlock, contains('GentiumPlus'));
      expect(
        infoTabBlock,
        contains('fontFamilyFallback: _transliterationFontFallback'),
      );

      final weekdayBlock = _sourceBetween(
        gridSource,
        'class _WeekdayRow extends StatelessWidget',
        'class _DecanRow extends StatelessWidget',
      );
      expect(weekdayBlock, contains('final labelColor = _softDayTileLabel();'));
      expect(weekdayBlock, contains('_weekdayLabelStyle.copyWith('));
      expect(weekdayBlock, contains('color: labelColor'));
      expect(weekdayBlock, isNot(contains('_blueLight')));
      expect(weekdayBlock, isNot(contains('_goldLight')));

      final epagomenalWeekdayBlock = _sourceBetween(
        gridSource,
        'Widget _epagomenalWeekdayRow',
        'String? _gregMonthForEpagomenal',
      );
      expect(
        epagomenalWeekdayBlock,
        contains('final labelColor = _softDayTileLabel();'),
      );
      expect(epagomenalWeekdayBlock, contains('_weekdayLabelStyle.copyWith('));
      expect(epagomenalWeekdayBlock, contains('color: labelColor'));
      expect(epagomenalWeekdayBlock, isNot(contains('_blueLight')));
      expect(epagomenalWeekdayBlock, isNot(contains('_goldLight')));

      final dayChipBlock = _sourceBetween(
        gridSource,
        'class _DayChip extends StatelessWidget',
        'class _MiniEventBlock extends StatelessWidget',
      );
      expect(dayChipBlock, contains('final textStyle = const TextStyle('));
      expect(dayChipBlock, contains('fontWeight: FontWeight.w500,'));
      expect(dayChipBlock, contains('fontSize: _CalendarScale.dayNumber,'));
      expect(dayChipBlock, contains('letterSpacing: 0.0,'));
      expect(dayChipBlock, contains('final numberColor = showGregorian'));
      expect(dayChipBlock, contains('_CalendarTone.gregorianBlue.withValues'));
      expect(dayChipBlock, contains('style: labelStyle'));
      expect(dayChipBlock, isNot(contains('DefaultTextStyle(')));
      expect(dayChipBlock, isNot(contains('ThemeData(')));
    });

    test('month layout constants use warm rectangular mockup grid colors', () {
      final source = File(
        'lib/features/calendar/calendar_grid_widgets.dart',
      ).readAsStringSync();
      final constantsBlock = _sourceBetween(
        source,
        'const Color _kSoftGridBackground',
        'bool _usesTabletLandscapeMonthGrid',
      );

      expect(constantsBlock, contains('_kSoftGridBackground'));
      expect(constantsBlock, contains('_kSoftDayTileFill'));
      expect(constantsBlock, contains('_kSoftDayTileLabel'));
      expect(constantsBlock, contains('_kDayTileRadius'));
      expect(constantsBlock, contains('_kLabeledPillVisibleCap'));
      expect(constantsBlock, contains('_kTextlessPillHeight'));
      expect(constantsBlock, contains('_kLabeledPillHeight'));
      expect(constantsBlock, contains('_kDetailsPillHeight'));
      expect(
        constantsBlock,
        contains(
          'const Color _kSoftGridBackground = _CalendarTone.previewCardBase;',
        ),
      );
      expect(
        constantsBlock,
        contains('final Color _kSoftDayTileFill = _CalendarTone.dayCellFill;'),
      );
      expect(
        constantsBlock,
        contains('const Color _kSoftDayTileLabel = _CalendarTone.weekday;'),
      );
      expect(constantsBlock, contains('const double _kDayTileRadius = 3.0;'));
      expect(
        constantsBlock,
        contains('const double _kDayTileBorderWidth = 0.45;'),
      );
      expect(
        constantsBlock,
        contains('const double _kMonthCardHorizontalInset = 16.0;'),
      );
      expect(
        constantsBlock,
        contains('const double _kMonthCardInnerPadding = 10.0;'),
      );
      expect(constantsBlock, contains('const double _kDecanColumnGap = 3.0;'));
      expect(
        constantsBlock,
        contains('const double _kDayTileCompactPadding = 4.0;'),
      );
      expect(
        constantsBlock,
        contains('const double _kDayTileExpandedHorizontalPadding = 1.5;'),
      );
      expect(
        constantsBlock,
        contains('const double _kDayTileExpandedVerticalPadding = 4.0;'),
      );
      expect(
        constantsBlock,
        contains('const double _kCompactMarkerGap = 1.0;'),
      );
      expect(
        constantsBlock,
        contains('const double _kTextlessPillHeight = 12.0;'),
      );
      expect(
        constantsBlock,
        contains('const double _kLabeledPillHeight = 30.0;'),
      );
      expect(
        constantsBlock,
        contains('const double _kDetailsPillHeight = 52.0;'),
      );
      expect(
        constantsBlock,
        contains('const double _kDetailsPillRadius = 7.0;'),
      );
      expect(constantsBlock, isNot(contains('TextStyle(')));
      expect(constantsBlock, isNot(contains('ThemeData(')));

      final dayChipBlock = _sourceBetween(
        source,
        'class _DayChip extends StatelessWidget',
        'class _MiniEventBlock extends StatelessWidget',
      );
      final sharedTileFillBlock = _sourceBetween(
        source,
        'Color _softDayTileFill()',
        'Color _softDayTileLabel()',
      );
      expect(sharedTileFillBlock, contains('=> _kSoftDayTileFill'));
      expect(sharedTileFillBlock, isNot(contains('Colors.')));
      expect(sharedTileFillBlock, isNot(contains('TextStyle(')));
      expect(sharedTileFillBlock, isNot(contains('ThemeData(')));

      final sharedTileLabelBlock = _sourceBetween(
        source,
        'Color _softDayTileLabel()',
        'enum _CalendarDayTone',
      );
      expect(sharedTileLabelBlock, contains('=> _kSoftDayTileLabel'));
      expect(sharedTileLabelBlock, isNot(contains('Colors.')));
      expect(sharedTileLabelBlock, isNot(contains('Color(0x')));
      expect(sharedTileLabelBlock, isNot(contains('TextStyle(')));
      expect(sharedTileLabelBlock, isNot(contains('ThemeData(')));

      final tileColorBlock = _sourceBetween(
        dayChipBlock,
        'final toneSpec = _calendarDayToneSpec(tone);',
        'final tilePadding = isCompact',
      );
      expect(tileColorBlock, contains('final tileFill = toneSpec.fill;'));
      expect(
        tileColorBlock,
        contains('final tileBorderColor = toneSpec.border;'),
      );
      expect(tileColorBlock, isNot(contains('Colors.')));
      expect(tileColorBlock, isNot(contains('Color(')));
      expect(tileColorBlock, isNot(contains('TextStyle(')));
      expect(tileColorBlock, isNot(contains('ThemeData(')));

      final tileDecorationBlock = _sourceBetween(
        dayChipBlock,
        'decoration: BoxDecoration(',
        'child: Stack(',
      );
      expect(tileDecorationBlock, contains('color: tileFill'));
      expect(tileDecorationBlock, contains('color: tileBorderColor'));
      expect(tileDecorationBlock, isNot(contains('Colors.')));
      expect(tileDecorationBlock, isNot(contains('Color(')));
      expect(tileDecorationBlock, isNot(contains('TextStyle(')));
      expect(tileDecorationBlock, isNot(contains('ThemeData(')));
    });
  });
}

Future<void> _pumpMonthCard(
  WidgetTester tester, {
  required MonthExpansionLevel expansionLevel,
  List<NoteData> Function(int day)? notesForDay,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: buildCalendarMonthCardLayoutForTesting(
            kYear: 6267,
            kMonth: 1,
            expansionLevel: expansionLevel,
            notesForDay: notesForDay ?? ((_) => const <NoteData>[]),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<NoteData> _denseNotesForLayoutGuard(int day) {
  if (day != 4) return const <NoteData>[];
  return List<NoteData>.generate(
    6,
    (index) => NoteData(
      title: 'Contained event ${index + 1}',
      allDay: false,
      start: TimeOfDay(hour: 8 + index, minute: 0),
      end: TimeOfDay(hour: 9 + index, minute: 0),
      manualColor: Colors.purple,
    ),
  );
}

void _expectDecanCellsDoNotOverlap(WidgetTester tester) {
  for (var day = 1; day < 10; day++) {
    final current = tester.getRect(
      find.byKey(ValueKey<String>('k:6267-1-$day|K')),
    );
    final next = tester.getRect(
      find.byKey(ValueKey<String>('k:6267-1-${day + 1}|K')),
    );
    expect(current.right, lessThanOrEqualTo(next.left));
  }
}

void _expectRectInside(Rect inner, Rect outer, {required String reason}) {
  const epsilon = 0.5;
  expect(
    inner.left,
    greaterThanOrEqualTo(outer.left - epsilon),
    reason: reason,
  );
  expect(inner.top, greaterThanOrEqualTo(outer.top - epsilon), reason: reason);
  expect(inner.right, lessThanOrEqualTo(outer.right + epsilon), reason: reason);
  expect(
    inner.bottom,
    lessThanOrEqualTo(outer.bottom + epsilon),
    reason: reason,
  );
}

Finder _eventPillContainersInDay(Finder dayCell) {
  return find.descendant(
    of: dayCell,
    matching: find.byWidgetPredicate((widget) {
      if (widget is! Container) return false;
      final decoration = widget.decoration;
      if (decoration is! BoxDecoration) return false;
      final border = decoration.border;
      if (border is! Border) return false;
      final constraints = widget.constraints;
      return constraints != null &&
          constraints.hasTightHeight &&
          decoration.borderRadius != null &&
          border.top.width >= 1.0;
    }),
  );
}

List<Size> _eventPillSizes(WidgetTester tester, Finder pillFinder) {
  return [
    for (final element in pillFinder.evaluate())
      (element.renderObject! as RenderBox).size,
  ];
}

String _sourceBetween(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  final endIndex = source.indexOf(end, startIndex + start.length);
  expect(startIndex, isNot(-1), reason: start);
  expect(endIndex, isNot(-1), reason: end);
  return source.substring(startIndex, endIndex);
}

class _LandscapePagerHarness extends StatelessWidget {
  const _LandscapePagerHarness({
    this.notesForDay,
    this.flowIndex = const <int, FlowData>{},
    this.onVisibleMonthCommitted,
    this.onShareNote,
    this.onAppendToJournal,
    this.onRecordCompletion,
    this.onUnrecordCompletion,
    this.onRemoveCompletionBadge,
  });

  final List<NoteData> Function(int ky, int km, int kd)? notesForDay;
  final Map<int, FlowData> flowIndex;
  final void Function(int ky, int km)? onVisibleMonthCommitted;
  final Future<void> Function(EventItem event)? onShareNote;
  final Future<void> Function(String text)? onAppendToJournal;
  final Future<void> Function({
    required String clientEventId,
    required int flowId,
    required DateTime completedOnDate,
    Map<String, dynamic>? metadata,
  })?
  onRecordCompletion;
  final Future<void> Function(String clientEventId)? onUnrecordCompletion;
  final Future<void> Function(String badgeId)? onRemoveCompletionBadge;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: LandscapeMonthPager(
          initialKy: 6267,
          initialKm: 4,
          showGregorian: false,
          notesForDay: notesForDay ?? ((_, _, _) => const <NoteData>[]),
          flowIndex: flowIndex,
          getMonthName: (km) => 'Month $km',
          onVisibleMonthCommitted: onVisibleMonthCommitted,
          onShareNote: onShareNote,
          onAppendToJournal: onAppendToJournal,
          onRecordCompletion: onRecordCompletion,
          onUnrecordCompletion: onUnrecordCompletion,
          onRemoveCompletionBadge: onRemoveCompletionBadge,
        ),
      ),
    );
  }
}

List<MethodCall> _capturePlatformHaptics(WidgetTester tester) {
  final calls = <MethodCall>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        calls.add(call);
      }
      return null;
    },
  );
  addTearDown(() {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });
  return calls;
}

Iterable<Object?> _hapticArguments(List<MethodCall> calls) {
  return calls.map((call) => call.arguments);
}

String _ritualPulseDiagnostics(WidgetTester tester) {
  final painters = tester.widgetList<CustomPaint>(
    find.byKey(
      const ValueKey<String>('day-view-ritual-completion-feedback-rim'),
    ),
  );
  return painters.map((paint) => paint.painter.toString()).join('\n');
}

double _ritualPulseDiagnosticDouble(WidgetTester tester, String field) {
  final diagnostics = _ritualPulseDiagnostics(tester);
  final matches = RegExp('$field: ([0-9.]+)').allMatches(diagnostics);
  return matches.fold<double>(0, (maxValue, match) {
    final value = double.tryParse(match.group(1) ?? '') ?? 0;
    return math.max(maxValue, value);
  });
}

double _ritualRimIntensity(WidgetTester tester) {
  return _ritualPulseDiagnosticDouble(tester, 'rimIntensity');
}

double _ritualPulseFillAlpha(WidgetTester tester) {
  return _ritualPulseDiagnosticDouble(tester, 'fillAlpha');
}

bool _ritualPulsePaintsFill(WidgetTester tester) {
  return _ritualPulseDiagnostics(tester).contains('paintsFill: true');
}

String? _ritualPulseMode(WidgetTester tester) {
  final diagnostics = _ritualPulseDiagnostics(tester);
  return RegExp('mode: ([a-z]+)').firstMatch(diagnostics)?.group(1);
}

Future<void> _setLandscapeViewport(WidgetTester tester) async {
  final binding = tester.binding;
  await binding.setSurfaceSize(const Size(1000, 420));
  binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
  addTearDown(() async {
    await binding.setSurfaceSize(null);
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  final binding = tester.binding;
  await binding.setSurfaceSize(size);
  binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
  addTearDown(() async {
    await binding.setSurfaceSize(null);
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });
}

Future<void> _setTabletLandscapeViewport(WidgetTester tester) async {
  final binding = tester.binding;
  await binding.setSurfaceSize(const Size(1194, 834));
  binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
  addTearDown(() async {
    await binding.setSurfaceSize(null);
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });
}

PageController _landscapePagerController(WidgetTester tester) {
  final pageView = tester.widget<PageView>(
    find.descendant(
      of: find.byType(LandscapeMonthPager),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is PageView && widget.scrollDirection == Axis.horizontal,
      ),
    ),
  );
  return pageView.controller!;
}
