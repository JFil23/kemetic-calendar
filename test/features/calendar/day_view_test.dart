import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/completion_status.dart';
import 'package:mobile/features/calendar/calendar_completion.dart';
import 'package:mobile/features/calendar/calendar_page.dart' show KemeticMath;
import 'package:mobile/features/calendar/day_view.dart';
import 'package:mobile/features/calendar/landscape_month_view.dart';
import 'package:mobile/features/calendar/living_text_day_one_node_store.dart';
import 'package:mobile/features/calendar/maat_decan_flow.dart';
import 'package:mobile/features/calendar/maat_flow_palette.dart';
import 'package:mobile/features/calendar/the_weighing_flow.dart';
import 'package:mobile/features/journal/journal_badge_utils.dart';
import 'package:mobile/features/journal/journal_event_badge.dart';
import 'package:mobile/services/app_restoration_service.dart';
import 'package:mobile/shared/glossy_text.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    CalendarEventDetailSheetCoordinator.debugResetForTests();
  });
  tearDown(CalendarEventDetailSheetCoordinator.debugResetForTests);

  group('DayViewGrid overlapping event gestures', () {
    testWidgets(
      'saved initial scroll offset is clamped to the current extent',
      (tester) async {
        await _setPhoneViewport(tester);

        await tester.pumpWidget(
          const _DayViewHarness(notes: [], initialScrollOffset: 999999),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('first visible minute restores before raw pixel offset', (
      tester,
    ) async {
      await _setPhoneViewport(tester);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DayViewGrid(
              ky: 1,
              km: 1,
              kd: 1,
              notes: [],
              showGregorian: false,
              flowIndex: {},
              initialFirstVisibleMinute: 8 * 60,
              initialScrollOffset: 120,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      expect(scrollable.position.pixels, closeTo(8 * 60, 0.001));
    });

    testWidgets('timeline reserves room above the global drawer bubble', (
      tester,
    ) async {
      await _setPhoneViewport(tester);

      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(390, 844),
              padding: EdgeInsets.only(bottom: 34),
            ),
            child: Scaffold(
              body: DayViewGrid(
                ky: 1,
                km: 1,
                kd: 1,
                notes: [],
                showGregorian: false,
                flowIndex: {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final listView = tester.widget<ListView>(
        find.byKey(const PageStorageKey<String>('day_timeline_list')),
      );
      final padding = listView.padding as EdgeInsets;

      expect(padding.bottom, 130);
    });

    testWidgets(
      'tablet landscape event layout uses constraint width and keeps bottom inset clear',
      (tester) async {
        await _setTabletLandscapeViewport(tester);

        await tester.pumpWidget(
          _DayViewHarness(
            notes: [
              _timedNote(
                title: 'Arrive in NYC',
                startHour: 10,
                startMinute: 0,
                endHour: 11,
                endMinute: 0,
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        final listView = tester.widget<ListView>(
          find.byKey(const PageStorageKey<String>('day_timeline_list')),
        );
        final padding = listView.padding as EdgeInsets;
        expect(padding.bottom, 96);

        final eventSizedBoxes = tester.widgetList<SizedBox>(
          find.ancestor(
            of: find.text('Arrive in NYC'),
            matching: find.byType(SizedBox),
          ),
        );

        expect(
          eventSizedBoxes.any(
            (box) => box.width != null && (box.width! - 1122).abs() < 0.001,
          ),
          isTrue,
        );
      },
    );

    testWidgets('Track Sky event cards fit long moon copy without overflow', (
      tester,
    ) async {
      await _setPhoneViewport(tester);

      await tester.pumpWidget(
        _DayViewHarness(
          initialScrollOffset: 15 * 60,
          flowIndex: const <int, FlowData>{
            99: FlowData(
              id: 99,
              name: 'Follow the sky',
              color: Colors.indigo,
              active: true,
              notes: 'sky_tz=pacific',
            ),
          },
          notes: [
            _timedNote(
              title: 'Strawberry Moon + Micromoon (Full)',
              startHour: 15,
              startMinute: 30,
              endHour: 16,
              endMinute: 15,
              flowId: 99,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Follow the sky'), findsWidgets);
      expect(find.text('Strawberry Moon + Micromoon (Full)'), findsWidgets);
    });

    testWidgets('phone landscape Day View uses the landscape month surface', (
      tester,
    ) async {
      await _setPhoneLandscapeViewport(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: DayViewPage(
            initialKy: 1,
            initialKm: 2,
            initialKd: 5,
            showGregorian: false,
            notesForDay: (_, _, _) => const [],
            flowIndex: const {},
            getMonthName: (month) => 'Month $month',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(LandscapeMonthView), findsOneWidget);
      expect(find.byType(DayViewGrid), findsNothing);
    });

    test(
      'single non-overlapping events keep the phone width factor by default',
      () {
        final blocks = EventLayoutEngine.layoutEventItems(
          events: const [
            EventItem(
              title: 'Phone Width Event',
              startMin: 10 * 60,
              endMin: 11 * 60,
              color: Colors.green,
              allDay: false,
            ),
          ],
          availableWidth: 314,
          columnGap: 4,
          textScale: 1.0,
          day: 1,
        );

        expect(blocks.single.width, closeTo(314 * 0.8, 0.001));
      },
    );

    test('tablet landscape single events can use the full timeline lane', () {
      final blocks = EventLayoutEngine.layoutEventItems(
        events: const [
          EventItem(
            title: 'Tablet Width Event',
            startMin: 10 * 60,
            endMin: 11 * 60,
            color: Colors.green,
            allDay: false,
          ),
        ],
        availableWidth: 1118,
        columnGap: 4,
        textScale: 1.0,
        day: 1,
        singleEventWidthFactor: 1.0,
      );

      expect(blocks.single.width, closeTo(1118, 0.001));
    });

    test('staggered overlapping events are assigned separate lanes', () {
      final blocks = EventLayoutEngine.layoutEventItems(
        events: const [
          EventItem(
            title: 'First Event',
            startMin: 16 * 60 + 45,
            endMin: 17 * 60 + 30,
            flowId: 1,
            color: Colors.green,
            allDay: false,
          ),
          EventItem(
            title: 'Second Event',
            startMin: 17 * 60,
            endMin: 18 * 60,
            flowId: 2,
            color: Colors.red,
            allDay: false,
          ),
        ],
        availableWidth: 314,
        columnGap: 4,
        textScale: 1.0,
        day: 1,
      );

      final first = blocks.firstWhere(
        (block) => block.event.title == 'First Event',
      );
      final second = blocks.firstWhere(
        (block) => block.event.title == 'Second Event',
      );

      expect(first.leftOffset, 0);
      expect(second.leftOffset, greaterThan(0));
      expect(first.width, closeTo(second.width, 0.001));
    });

    test(
      'events with non-overlapping times still split lanes when their rendered cards would collide',
      () {
        final blocks = EventLayoutEngine.layoutEventItems(
          events: const [
            EventItem(
              title: 'Short Top Event',
              startMin: 13 * 60,
              endMin: 13 * 60 + 30,
              flowId: 1,
              color: Colors.green,
              allDay: false,
            ),
            EventItem(
              title: 'Later Event',
              startMin: 13 * 60 + 45,
              endMin: 14 * 60 + 30,
              flowId: 2,
              color: Colors.red,
              allDay: false,
            ),
          ],
          availableWidth: 314,
          columnGap: 4,
          textScale: 1.0,
          day: 1,
        );

        final top = blocks.firstWhere(
          (block) => block.event.title == 'Short Top Event',
        );
        final later = blocks.firstWhere(
          (block) => block.event.title == 'Later Event',
        );

        expect(top.leftOffset, 0);
        expect(later.leftOffset, greaterThan(0));
        expect(top.width, closeTo(later.width, 0.001));
      },
    );

    test(
      'flow-owned events keep the flow chrome color even when not ledger-active',
      () {
        final blocks = EventLayoutEngine.layoutEventsForDay(
          notes: [
            _timedNote(
              title: 'Archived Practice',
              startHour: 10,
              startMinute: 0,
              endHour: 11,
              endMinute: 0,
              flowId: 9,
            ),
          ],
          flowIndex: const {
            9: FlowData(
              id: 9,
              name: 'Archived Practice Flow',
              color: Colors.green,
              active: false,
            ),
          },
          availableWidth: 314,
          columnGap: 4,
          textScale: 1.0,
          day: 1,
        );

        expect(blocks, hasLength(1));
        expect(blocks.single.event.color, Colors.green);
      },
    );

    testWidgets(
      'a short event card inherits the tallest hit height in its overlap row',
      (tester) async {
        await _setPhoneViewport(tester);

        await tester.pumpWidget(
          _DayViewHarness(
            notes: [
              _timedNote(
                title: 'Kung Fu Practice',
                startHour: 10,
                startMinute: 0,
                endHour: 10,
                endMinute: 30,
                flowId: 1,
              ),
              _timedNote(
                title: 'Tax Day',
                startHour: 10,
                startMinute: 0,
                endHour: 13,
                endMinute: 0,
                flowId: 2,
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final ancestorBoxes = tester.widgetList<SizedBox>(
          find.ancestor(
            of: find.text('Kung Fu Practice'),
            matching: find.byType(SizedBox),
          ),
        );

        expect(ancestorBoxes.any((box) => box.height == 182), isTrue);
      },
    );

    testWidgets(
      'new event preview stays single while crossing into the next hour',
      (tester) async {
        await _setPhoneViewport(tester);

        await tester.pumpWidget(const _DayViewHarness(notes: []));
        await tester.pumpAndSettle();

        final gesture = await tester.startGesture(const Offset(200, 450));
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));

        expect(find.text('New Event'), findsOneWidget);
        expect(find.text('4:30 PM'), findsOneWidget);

        await gesture.moveBy(const Offset(0, 45));
        await tester.pump();

        expect(find.text('New Event'), findsOneWidget);
        expect(find.text('5:15 PM'), findsOneWidget);

        await gesture.up();
        await tester.pumpAndSettle();
      },
    );

    testWidgets('late-start real cards repaint into the next hour row', (
      tester,
    ) async {
      await _setPhoneViewport(tester);

      await tester.pumpWidget(
        const _DayViewHarness(
          initialScrollOffset: 8 * 60,
          notes: [
            NoteData(
              clientEventId: 'late-reminder',
              title: 'journal every night',
              allDay: false,
              start: TimeOfDay(hour: 8, minute: 30),
              end: TimeOfDay(hour: 9, minute: 0),
              manualColor: Colors.green,
              isReminder: true,
            ),
            NoteData(
              clientEventId: 'late-math-card',
              title: 'Explain the Mystery',
              category: 'Daily Math Visuals · 30-Day Path',
              allDay: false,
              start: TimeOfDay(hour: 9, minute: 42),
              end: TimeOfDay(hour: 10, minute: 0),
              manualColor: Colors.blue,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('journal every night'), findsWidgets);
      expect(find.text('Explain the Mystery'), findsWidgets);
      expect(
        find.byKey(dayViewOverflowVisualKey('cid:late-reminder', 9)),
        findsOneWidget,
      );
      expect(
        find.byKey(dayViewOverflowVisualKey('cid:late-math-card', 10)),
        findsOneWidget,
      );
    });
  });

  group('DayViewGrid detail sheet refresh', () {
    testWidgets('reminder previews keep category and title visible', (
      tester,
    ) async {
      await _setPhoneViewport(tester);

      await tester.pumpWidget(
        const _DayViewHarness(
          initialScrollOffset: 7 * 60,
          notes: [
            NoteData(
              clientEventId: 'cid-journal-every-day',
              title: 'journal every day',
              allDay: false,
              start: TimeOfDay(hour: 8, minute: 0),
              end: TimeOfDay(hour: 9, minute: 0),
              manualColor: Colors.green,
              isReminder: true,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('REMINDER'), findsWidgets);
      expect(find.text('journal every day'), findsWidgets);
    });

    testWidgets(
      'timeline and detail sheet replace raw YouTube URL with smart action',
      (tester) async {
        await _setPhoneViewport(tester);
        const url = 'https://www.youtube.com/watch?v=abc123';

        await tester.pumpWidget(
          const _DayViewHarness(
            initialScrollOffset: 11 * 60,
            notes: [
              NoteData(
                clientEventId: 'cid-daily-math-youtube',
                title: 'Explain the Mystery',
                detail:
                    'Watch the linked video. Focus: explain the basic mystery.',
                location: url,
                category: 'Daily Math Visuals · 30-Day Path',
                allDay: false,
                start: TimeOfDay(hour: 12, minute: 0),
                end: TimeOfDay(hour: 13, minute: 0),
                manualColor: Colors.blue,
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('DAILY MATH VISUALS · 30-DAY PATH'), findsWidgets);
        expect(find.text('Explain the Mystery'), findsWidgets);
        expect(find.text(url), findsNothing);

        await tester.tap(find.text('Explain the Mystery').first);
        await tester.pumpAndSettle();

        expect(find.text('Watch on YouTube'), findsOneWidget);
        expect(find.text(url), findsNothing);
      },
    );

    testWidgets(
      'Ma_at flow detail sheet uses gold section headers without duplicate labels',
      (tester) async {
        await _setPhoneViewport(tester);
        final event = kTheWeighingEvents.singleWhere(
          (event) => event.eventNumber == 9,
        );
        final title = theWeighingEventTitle(event);
        final recordedStatuses = <CompletionStatus>[];

        await tester.pumpWidget(
          _DayViewHarness(
            initialScrollOffset: 9 * 60,
            flowIndex: const <int, FlowData>{
              90: FlowData(
                id: 90,
                name: kTheWeighingTitle,
                color: Colors.amber,
                active: true,
                notes: 'weighing_lens=neutral',
              ),
            },
            notes: [
              NoteData(
                clientEventId: 'cid-the-weighing-9',
                title: title,
                detail: theWeighingDetailText(
                  event,
                  lens: TheWeighingLens.neutral,
                ),
                category: event.decanSection,
                allDay: false,
                start: const TimeOfDay(hour: 10, minute: 0),
                end: const TimeOfDay(hour: 10, minute: 10),
                flowId: 90,
              ),
            ],
            onRecordCompletion:
                ({
                  required String clientEventId,
                  required int flowId,
                  required DateTime completedOnDate,
                  Map<String, dynamic>? metadata,
                }) async {
                  recordedStatuses.add(
                    CompletionStatusX.fromWireName(
                      metadata?['completion_status']?.toString(),
                    ),
                  );
                },
          ),
        );
        await tester.pumpAndSettle();

        final eventSurface = find
            .ancestor(
              of: find.text(title).first,
              matching: find.byType(GestureDetector),
            )
            .last;
        await tester.tap(eventSurface);
        await tester.pumpAndSettle();

        for (final label in const <String>['PURPOSE', 'WORDS', 'STEPS']) {
          final finder = find.text(label);
          expect(finder, findsOneWidget);
          final text = tester.widget<Text>(finder);
          expect(text.style?.color, MaatFlowPalette.interiorLabel);
          expect(text.style?.letterSpacing, 1.6);
        }
        expect(find.text('Purpose'), findsNothing);

        final bodyFinder = find.textContaining(
          'These lines are not aspirational',
        );
        expect(bodyFinder, findsOneWidget);
        final bodyText = tester.widget<Text>(bodyFinder);
        expect(bodyText.style?.color, isNot(MaatFlowPalette.interiorLabel));

        expect(find.text('Observed'), findsWidgets);
        expect(find.text('Partly'), findsWidgets);
        expect(find.text('Skipped'), findsWidgets);

        await tester.ensureVisible(find.text('Observed').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Observed').last);
        await tester.pumpAndSettle();

        expect(recordedStatuses, <CompletionStatus>[CompletionStatus.observed]);
      },
    );

    testWidgets('overlapping math cards remain visible as compact previews', (
      tester,
    ) async {
      await _setPhoneViewport(tester);
      const url = 'https://www.youtube.com/watch?v=abc123';

      await tester.pumpWidget(
        const _DayViewHarness(
          initialScrollOffset: 11 * 60,
          notes: [
            NoteData(
              title: 'Explain the Mystery',
              location: url,
              category: '30-Day Path',
              allDay: false,
              start: TimeOfDay(hour: 12, minute: 0),
              end: TimeOfDay(hour: 13, minute: 0),
              manualColor: Colors.blue,
            ),
            NoteData(
              title: 'sin(a+b) Formula',
              location: url,
              category: '90-Day Ladder',
              allDay: false,
              start: TimeOfDay(hour: 12, minute: 0),
              end: TimeOfDay(hour: 13, minute: 0),
              manualColor: Colors.deepOrange,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('30-DAY PATH'), findsWidgets);
      expect(find.text('Explain the Mystery'), findsWidgets);
      expect(find.text('90-DAY LADDER'), findsWidgets);
      expect(find.text('sin(a+b) Formula'), findsWidgets);
      expect(find.text(url), findsNothing);
    });

    testWidgets(
      'completion buttons toggle off and replace journal badges by source id',
      (tester) async {
        await _setPhoneViewport(tester);

        final appendedBadges = <String>[];
        final recordedStatuses = <CompletionStatus>[];
        final unrecordedClientEventIds = <String>[];
        final removedBadgeIds = <String>[];

        await tester.pumpWidget(
          _DayViewHarness(
            notes: [
              _timedNote(
                clientEventId: 'cid-focus-completion',
                title: 'Focus Completion',
                startHour: 10,
                startMinute: 0,
                endHour: 11,
                endMinute: 0,
                flowId: 1,
              ),
            ],
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

        await tester.tap(find.text('Focus Completion'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Observed').last);
        await tester.pumpAndSettle();

        expect(recordedStatuses, <CompletionStatus>[CompletionStatus.observed]);
        expect(appendedBadges, hasLength(1));
        var tokens = appendedBadges
            .map(JournalBadgeUtils.parseRawToken)
            .whereType<EventBadgeToken>()
            .toList();
        expect(tokens.single.completionStatus, CompletionStatus.observed);

        await tester.tap(find.text('Observed').last);
        await tester.pumpAndSettle();

        expect(unrecordedClientEventIds, <String>['cid-focus-completion']);
        expect(removedBadgeIds, <String>[tokens.single.id]);

        await tester.tap(find.text('Partly').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Skipped').last);
        await tester.pumpAndSettle();

        expect(recordedStatuses, <CompletionStatus>[
          CompletionStatus.observed,
          CompletionStatus.partial,
          CompletionStatus.skipped,
        ]);
        expect(appendedBadges, hasLength(3));
        tokens = appendedBadges
            .map(JournalBadgeUtils.parseRawToken)
            .whereType<EventBadgeToken>()
            .toList();
        expect(tokens.map((token) => token.id).toSet(), hasLength(1));
        expect(tokens.last.completionStatus, CompletionStatus.skipped);
      },
    );

    testWidgets(
      'ordinary flow observed completion pulses the rim and requests medium haptic',
      (tester) async {
        await _setPhoneViewport(tester);

        final recordedStatuses = <CompletionStatus>[];

        await tester.pumpWidget(
          _DayViewHarness(
            notes: [
              _timedNote(
                clientEventId: 'cid-ritual-observed',
                title: 'Ritual Observed',
                startHour: 10,
                startMinute: 0,
                endHour: 11,
                endMinute: 0,
                flowId: 1,
              ),
            ],
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

        await tester.tap(find.text('Ritual Observed'));
        await tester.pumpAndSettle();

        final hapticCalls = _capturePlatformHaptics(tester);
        final stableCardFill = _ritualCardFillColor(tester);
        expect(stableCardFill, isNotNull);
        expect(_ritualRimIntensity(tester), 0);
        expect(_ritualPulsePaintsFill(tester), isFalse);

        await tester.tap(find.text('Observed').last);
        await tester.pump();
        await tester.pump(
          kCalendarCompletionFeedbackDelay - const Duration(milliseconds: 1),
        );
        expect(_ritualRimIntensity(tester), 0);
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump(const Duration(milliseconds: 140));

        expect(recordedStatuses, <CompletionStatus>[CompletionStatus.observed]);
        expect(_ritualPulseMode(tester), 'observed');
        expect(_ritualRimIntensity(tester), greaterThan(0));
        expect(_ritualPulseFillAlpha(tester), 0);
        expect(_ritualPulsePaintsFill(tester), isFalse);
        expect(_ritualCardFillColor(tester), stableCardFill);
        expect(
          _hapticArguments(hapticCalls),
          contains('HapticFeedbackType.mediumImpact'),
        );

        await tester.pumpAndSettle();
        expect(_ritualRimIntensity(tester), 0);
        expect(_ritualCardFillColor(tester), stableCardFill);
      },
    );

    testWidgets(
      'ordinary flow partly completion pulses the rim weaker and requests light haptic',
      (tester) async {
        await _setPhoneViewport(tester);

        final recordedStatuses = <CompletionStatus>[];

        await tester.pumpWidget(
          _DayViewHarness(
            notes: [
              _timedNote(
                clientEventId: 'cid-ritual-partly',
                title: 'Ritual Partly',
                startHour: 10,
                startMinute: 0,
                endHour: 11,
                endMinute: 0,
                flowId: 1,
              ),
            ],
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

        await tester.tap(find.text('Ritual Partly'));
        await tester.pumpAndSettle();

        final hapticCalls = _capturePlatformHaptics(tester);
        final stableCardFill = _ritualCardFillColor(tester);
        expect(stableCardFill, isNotNull);

        await tester.tap(find.text('Observed').last);
        await tester.pump();
        await tester.pump(kCalendarCompletionFeedbackDelay);
        await tester.pump(const Duration(milliseconds: 140));
        final observedRimIntensity = _ritualRimIntensity(tester);
        expect(_ritualPulseMode(tester), 'observed');
        expect(_ritualPulseFillAlpha(tester), 0);
        expect(_ritualPulsePaintsFill(tester), isFalse);
        expect(_ritualCardFillColor(tester), stableCardFill);

        await tester.pumpAndSettle();
        await tester.tap(find.text('Partly').last);
        await tester.pump();
        await tester.pump(kCalendarCompletionFeedbackDelay);
        await tester.pump(const Duration(milliseconds: 140));
        final partialRimIntensity = _ritualRimIntensity(tester);

        expect(recordedStatuses, <CompletionStatus>[
          CompletionStatus.observed,
          CompletionStatus.partial,
        ]);
        expect(_ritualPulseMode(tester), 'partial');
        expect(partialRimIntensity, greaterThan(0));
        expect(partialRimIntensity, lessThan(observedRimIntensity));
        expect(_ritualPulseFillAlpha(tester), 0);
        expect(_ritualPulsePaintsFill(tester), isFalse);
        expect(_ritualCardFillColor(tester), stableCardFill);
        expect(
          _hapticArguments(hapticCalls),
          contains('HapticFeedbackType.lightImpact'),
        );
      },
    );

    testWidgets(
      'ordinary flow skipped completion pulses and requests light haptic',
      (tester) async {
        await _setPhoneViewport(tester);

        final appendedBadges = <String>[];
        final recordedStatuses = <CompletionStatus>[];

        await tester.pumpWidget(
          _DayViewHarness(
            notes: [
              _timedNote(
                clientEventId: 'cid-ritual-skipped',
                title: 'Ritual Skipped',
                startHour: 10,
                startMinute: 0,
                endHour: 11,
                endMinute: 0,
                flowId: 1,
              ),
            ],
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
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Ritual Skipped'));
        await tester.pumpAndSettle();

        final hapticCalls = _capturePlatformHaptics(tester);

        await tester.tap(find.text('Skipped').last);
        await tester.pump();
        await tester.pump(kCalendarCompletionFeedbackDelay);
        await tester.pump(const Duration(milliseconds: 140));

        expect(recordedStatuses, <CompletionStatus>[CompletionStatus.skipped]);
        expect(appendedBadges, hasLength(1));
        expect(_ritualPulseMode(tester), 'skipped');
        expect(_ritualRimIntensity(tester), greaterThan(0));
        expect(_ritualPulsePaintsFill(tester), isFalse);
        expect(
          _hapticArguments(hapticCalls),
          contains('HapticFeedbackType.lightImpact'),
        );
      },
    );

    testWidgets('restored flow completion state does not pulse the card', (
      tester,
    ) async {
      await _setPhoneViewport(tester);

      SharedPreferences.setMockInitialValues(<String, Object>{
        'calendar_completion:local:cid:cid-ritual-restored': 'observed',
      });

      await tester.pumpWidget(
        _DayViewHarness(
          notes: [
            _timedNote(
              clientEventId: 'cid-ritual-restored',
              title: 'Ritual Restored',
              startHour: 10,
              startMinute: 0,
              endHour: 11,
              endMinute: 0,
              flowId: 1,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ritual Restored'));
      await tester.pumpAndSettle();

      expect(find.text('Observed'), findsWidgets);
      expect(_ritualRimIntensity(tester), 0);
      expect(_ritualPulsePaintsFill(tester), isFalse);
    });

    testWidgets(
      'flow event notification restoration opens the matching detail sheet',
      (tester) async {
        await _setPhoneViewport(tester);

        await tester.pumpWidget(
          _RestoredDetailGridHarness(
            notes: [
              _timedNote(
                clientEventId: 'cid-flow-target',
                title: 'Dawn Practice',
                startHour: 6,
                startMinute: 0,
                endHour: 6,
                endMinute: 30,
                flowId: 42,
              ),
              _timedNote(
                clientEventId: 'cid-flow-other',
                title: 'Evening Practice',
                startHour: 18,
                startMinute: 0,
                endHour: 18,
                endMinute: 30,
                flowId: 42,
              ),
            ],
            flowIndex: const {
              42: FlowData(
                id: 42,
                name: 'Daily Practice Flow',
                color: Colors.green,
                active: true,
              ),
            },
            restoration: const EventDetailRestorationState(
              kYear: 1,
              kMonth: 1,
              kDay: 1,
              identityType: eventDetailIdentityClientEventId,
              identityValue: 'cid-flow-target',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(BottomSheet), findsOneWidget);
        expect(find.text('Dawn Practice'), findsWidgets);
        expect(find.text('6:00 AM – 6:30 AM'), findsOneWidget);
        expect(find.text('Daily Practice Flow'), findsWidgets);
        expect(find.text('New Event'), findsNothing);
      },
    );

    testWidgets(
      'note notification restoration opens existing note detail, not creation',
      (tester) async {
        await _setPhoneViewport(tester);

        await tester.pumpWidget(
          _RestoredDetailGridHarness(
            notes: [
              _timedNote(
                id: 'event-note-target',
                clientEventId: 'cid-note-target',
                title: 'Existing Note',
                startHour: 10,
                startMinute: 0,
                endHour: 10,
                endMinute: 45,
              ),
            ],
            restoration: const EventDetailRestorationState(
              kYear: 1,
              kMonth: 1,
              kDay: 1,
              identityType: eventDetailIdentityClientEventId,
              identityValue: 'cid-note-target',
            ),
            onDeleteNote: (_, _, _, _) async {},
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(BottomSheet), findsOneWidget);
        expect(find.text('Existing Note'), findsWidgets);
        expect(find.text('10:00 AM – 10:45 AM'), findsOneWidget);
        expect(find.text('Add reflection'), findsOneWidget);
        expect(find.text('End Note'), findsNothing);

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        expect(find.text('End Note'), findsOneWidget);
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        expect(find.text('New Event'), findsNothing);
      },
    );

    testWidgets(
      'reminder notification restoration opens the matching reminder detail',
      (tester) async {
        await _setPhoneViewport(tester);

        await tester.pumpWidget(
          _RestoredDetailGridHarness(
            notes: [
              _timedReminderNote(
                clientEventId: 'cid-reminder-target',
                reminderId: 'reminder-target',
                title: 'Hydrate',
                startHour: 9,
              ),
              _timedReminderNote(
                clientEventId: 'cid-reminder-other',
                reminderId: 'reminder-other',
                title: 'Stretch',
                startHour: 10,
              ),
            ],
            restoration: const EventDetailRestorationState(
              kYear: 1,
              kMonth: 1,
              kDay: 1,
              identityType: eventDetailIdentityReminderId,
              identityValue: 'reminder-target',
            ),
            onEndReminder: (_) async {},
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(BottomSheet), findsOneWidget);
        expect(find.text('Hydrate'), findsWidgets);
        expect(find.text('9:00 AM – 9:30 AM'), findsOneWidget);
        expect(find.text('Add reflection'), findsOneWidget);
        expect(find.text('End Reminder'), findsNothing);

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        expect(find.text('End Reminder'), findsOneWidget);
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        expect(find.text('Stretch'), findsOneWidget);
        expect(find.text('New Event'), findsNothing);
      },
    );

    testWidgets('generic new-note UI still invokes the create-note action', (
      tester,
    ) async {
      await _setPhoneViewport(tester);
      var openedCreateNote = false;

      await tester.pumpWidget(
        MaterialApp(
          home: DayViewPage(
            initialKy: 1,
            initialKm: 1,
            initialKd: 1,
            showGregorian: false,
            notesForDay: (_, _, _) => const <NoteData>[],
            flowIndex: const {},
            getMonthName: _gregorianMonthName,
            onOpenQuickAdd: (_) async {
              openedCreateNote = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('New note'));
      await tester.pumpAndSettle();

      expect(openedCreateNote, isTrue);
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets(
      'tap consumes echoed detail restoration state without opening a second sheet',
      (tester) async {
        await _setPhoneViewport(tester);
        CalendarEventDetailSheetCoordinator.debugResetForTests();

        final restoration = ValueNotifier<EventDetailRestorationState?>(null);
        var disposed = false;
        addTearDown(() {
          disposed = true;
          restoration.dispose();
          CalendarEventDetailSheetCoordinator.debugResetForTests();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ValueListenableBuilder<EventDetailRestorationState?>(
                valueListenable: restoration,
                builder: (context, eventDetail, _) {
                  return DayViewGrid(
                    ky: 1,
                    km: 1,
                    kd: 1,
                    notes: [
                      _timedNote(
                        clientEventId: 'cid-focus',
                        title: 'Focus Block',
                        startHour: 10,
                        startMinute: 0,
                        endHour: 11,
                        endMinute: 0,
                      ),
                    ],
                    showGregorian: false,
                    flowIndex: const {},
                    initialScrollOffset: 9 * 60,
                    initialEventDetailRestorationState: eventDetail,
                    onEventDetailRestorationChanged: (state) {
                      if (!disposed) {
                        restoration.value = state;
                      }
                    },
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Focus Block'));
        await tester.pumpAndSettle();

        expect(find.byType(BottomSheet), findsOneWidget);
        expect(find.text('10:00 AM – 11:00 AM'), findsOneWidget);
        expect(find.text('Make to-do'), findsOneWidget);
      },
    );

    testWidgets(
      'detail sheet refreshes stale event data before showing time and share actions',
      (tester) async {
        await _setPhoneViewport(tester);

        final notes = ValueNotifier<List<NoteData>>([
          _timedNote(
            title: 'Focus Block',
            startHour: 10,
            startMinute: 0,
            endHour: 11,
            endMinute: 0,
            clientEventId: 'cid-focus',
          ),
        ]);
        final dataVersion = ValueNotifier<int>(0);
        EventItem? sharedEvent;

        addTearDown(() {
          notes.dispose();
          dataVersion.dispose();
        });

        await tester.pumpWidget(
          _MutableDayViewHarness(
            notes: notes,
            dataVersion: dataVersion,
            onShareNote: (event) async {
              sharedEvent = event;
            },
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Focus Block'));
        await tester.pumpAndSettle();

        expect(find.text('10:00 AM – 11:00 AM'), findsOneWidget);

        notes.value = [
          _timedNote(
            id: 'evt-focus',
            clientEventId: 'cid-focus',
            title: 'Focus Block',
            startHour: 13,
            startMinute: 0,
            endHour: 14,
            endMinute: 0,
          ),
        ];
        dataVersion.value++;
        await tester.pumpAndSettle();

        expect(find.text('1:00 PM – 2:00 PM'), findsOneWidget);
        expect(find.text('Make to-do'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        expect(find.text('Share Note'), findsOneWidget);
        await tester.tap(find.text('Share Note'));
        await tester.pumpAndSettle();

        expect(sharedEvent, isNotNull);
        expect(sharedEvent!.id, 'evt-focus');
        expect(sharedEvent!.clientEventId, 'cid-focus');
        expect(sharedEvent!.startMin, 13 * 60);
        expect(sharedEvent!.endMin, 14 * 60);
      },
    );

    testWidgets(
      'detail sheet survives source grid disposal and notifier rebuilds',
      (tester) async {
        await _setPhoneViewport(tester);

        final showGrid = ValueNotifier<bool>(true);
        final dataVersion = ValueNotifier<int>(0);

        addTearDown(() {
          showGrid.dispose();
          dataVersion.dispose();
        });

        await tester.pumpWidget(
          _SheetPersistenceHarness(
            showGrid: showGrid,
            dataVersion: dataVersion,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Flow Block'));
        await tester.pumpAndSettle();

        expect(find.text('Add reflection'), findsOneWidget);
        expect(find.text('End Flow'), findsNothing);

        showGrid.value = false;
        await tester.pump();

        dataVersion.value++;
        await tester.pump();
        expect(tester.takeException(), isNull);

        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Add reflection'), findsOneWidget);
        expect(find.text('End Flow'), findsNothing);
      },
    );

    testWidgets(
      'detail sheet keeps inactive chrome flow ending out of the primary slot',
      (tester) async {
        await _setPhoneViewport(tester);
        int? endedFlowId;

        await tester.pumpWidget(
          _DayViewHarness(
            notes: const [
              NoteData(
                title: 'Archived Practice',
                allDay: false,
                start: TimeOfDay(hour: 10, minute: 0),
                end: TimeOfDay(hour: 11, minute: 0),
                flowId: 9,
              ),
            ],
            flowIndex: const {
              9: FlowData(
                id: 9,
                name: 'Archived Practice Flow',
                color: Colors.green,
                active: false,
              ),
            },
            activeLedgerFlowIds: const <int>{},
            onEndFlow: (flowId) {
              endedFlowId = flowId;
            },
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Archived Practice'));
        await tester.pumpAndSettle();

        expect(find.text('Archived Practice Flow'), findsWidgets);
        expect(find.text('Make to-do'), findsOneWidget);
        expect(find.text('Share Flow'), findsNothing);
        expect(find.text('Add reflection'), findsOneWidget);
        expect(find.text('End Flow'), findsNothing);
        expect(find.text('End Note'), findsNothing);

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        expect(find.text('Share Flow'), findsOneWidget);
        expect(find.text('End Flow'), findsNothing);
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        expect(endedFlowId, isNull);
      },
    );

    testWidgets(
      'detail sheet keeps End Flow in overflow for active chrome flows outside the active ledger',
      (tester) async {
        await _setPhoneViewport(tester);

        await tester.pumpWidget(
          _DayViewHarness(
            notes: const [
              NoteData(
                title: 'Evening Reflection',
                allDay: false,
                start: TimeOfDay(hour: 20, minute: 0),
                end: TimeOfDay(hour: 20, minute: 12),
                flowId: 11,
              ),
            ],
            flowIndex: {
              11: FlowData(
                id: 11,
                name: 'Cooking and Art Mastery',
                color: Colors.teal,
                active: true,
              ),
            },
            activeLedgerFlowIds: const <int>{},
            onEndFlow: (_) {},
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Evening Reflection'));
        await tester.pumpAndSettle();

        expect(find.text('Cooking and Art Mastery'), findsWidgets);
        expect(find.text('Make to-do'), findsOneWidget);
        expect(find.text('Share Flow'), findsNothing);
        expect(find.text('Add reflection'), findsOneWidget);
        expect(find.text('End Flow'), findsNothing);
        expect(find.text('End Note'), findsNothing);

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        expect(find.text('Share Flow'), findsOneWidget);
        expect(find.text('End Flow'), findsOneWidget);
      },
    );

    testWidgets(
      'End Flow falls back to onEndFlow when CalendarPage is not the host',
      (tester) async {
        await _setPhoneViewport(tester);

        int? endedFlowId;

        await tester.pumpWidget(
          _DayViewHarness(
            notes: [
              _timedNote(
                title: 'Local Flow',
                startHour: 10,
                startMinute: 0,
                endHour: 11,
                endMinute: 0,
                flowId: 1,
              ),
            ],
            onEndFlow: (flowId) {
              endedFlowId = flowId;
            },
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Local Flow'));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        await tester.tap(find.text('End Flow'));
        await tester.pumpAndSettle();

        expect(endedFlowId, 1);
      },
    );

    testWidgets('Living Text CTA routes to fixed node slug from payload', (
      tester,
    ) async {
      await _setPhoneViewport(tester);

      await tester.pumpWidget(
        _DayViewRouterHarness(
          notes: [
            _livingTextNote(
              title: 'Living Text 4: Add Your First Reflection',
              label: 'Add your insight',
              nodeSlug: 'ptah',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Living Text 4: Add Your First Reflection'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add your insight'));
      await tester.pumpAndSettle();

      expect(find.text('Node target: ptah action:add_insight'), findsOneWidget);
    });

    testWidgets(
      'Living Text CTA routes to stored Day 1 slug when payload is null',
      (tester) async {
        await _setPhoneViewport(tester);
        await const LivingTextDayOneNodeStore().writeSlug(
          userId: 'local',
          flowInstanceId: '77',
          nodeSlug: 'maat',
        );

        await tester.pumpWidget(
          _DayViewRouterHarness(
            notes: [
              _livingTextNote(
                title: 'Living Text 4: Add Your First Reflection',
                label: 'Add your insight',
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Living Text 4: Add Your First Reflection'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Add your insight'));
        await tester.pumpAndSettle();

        expect(
          find.text('Node target: maat action:add_insight'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Living Text CTA falls back to Library root without Day 1 slug',
      (tester) async {
        await _setPhoneViewport(tester);

        await tester.pumpWidget(
          _DayViewRouterHarness(
            notes: [
              _livingTextNote(
                title: 'Living Text 7: Return to Day 1’s Entry',
                label: 'Revise your insight',
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Living Text 7: Return to Day 1’s Entry'));
        await tester.pumpAndSettle();
        expect(
          find.text(
            'Choose the Day 1 entry you read, then open Your Insights.',
          ),
          findsOneWidget,
        );
        await tester.tap(find.text('Revise your insight'));
        await tester.pumpAndSettle();

        expect(find.text('Library root'), findsOneWidget);
      },
    );

    testWidgets('event without library CTA does not render CTA panel', (
      tester,
    ) async {
      await _setPhoneViewport(tester);

      await tester.pumpWidget(
        _DayViewRouterHarness(
          notes: [
            _timedNote(
              clientEventId: 'the-living-text:77:event-3',
              title: 'Living Text 3: Find What You Don’t Understand',
              startHour: 10,
              startMinute: 0,
              endHour: 10,
              endMinute: 30,
              flowId: 77,
              behaviorPayload: const <String, dynamic>{
                'flow_key': kLivingTextFlowKey,
                'event_number': 3,
              },
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.text('Living Text 3: Find What You Don’t Understand'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add your insight'), findsNothing);
      expect(find.text('Library'), findsNothing);
    });

    testWidgets(
      'detail sheet keeps a stable height when paging through same-sized reminders',
      (tester) async {
        await _setPhoneViewport(tester);

        final notes = [
          _timedReminderNote(
            clientEventId: 'cid-reminder-1',
            reminderId: 'reminder-family-salon-1',
            title: 'Family Salon A',
            startHour: 10,
          ),
          _timedReminderNote(
            clientEventId: 'cid-reminder-2',
            reminderId: 'reminder-family-salon-2',
            title: 'Family Salon B',
            startHour: 11,
          ),
          _timedReminderNote(
            clientEventId: 'cid-reminder-3',
            reminderId: 'reminder-family-salon-3',
            title: 'Family Salon C',
            startHour: 12,
          ),
          _timedReminderNote(
            clientEventId: 'cid-reminder-4',
            reminderId: 'reminder-family-salon-4',
            title: 'Family Salon D',
            startHour: 13,
          ),
        ];

        await tester.pumpWidget(_PagedReminderDayViewHarness(notes: notes));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Family Salon B'));
        await tester.pumpAndSettle();

        final initialHeight = _detailSheetPageHeight(tester);
        expect(find.text('Family Salon B'), findsWidgets);

        await tester.drag(find.byType(PageView), const Offset(-320, 0));
        await tester.pumpAndSettle();
        await tester.drag(find.byType(PageView), const Offset(-320, 0));
        await tester.pumpAndSettle();

        final finalHeight = _detailSheetPageHeight(tester);
        expect(find.text('Family Salon D'), findsWidgets);
        expect(finalHeight, closeTo(initialHeight, 0.01));
      },
    );

    testWidgets(
      'reminder detail sheet exposes make todo and shares from the menu',
      (tester) async {
        await _setPhoneViewport(tester);
        EventItem? sharedReminder;

        await tester.pumpWidget(
          _PagedReminderDayViewHarness(
            notes: [
              _timedReminderNote(
                clientEventId: 'cid-reminder-share',
                reminderId: 'reminder-share',
                title: 'Journal every day',
                startHour: 10,
              ),
            ],
            onShareReminder: (event) async {
              sharedReminder = event;
            },
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Journal every day'));
        await tester.pumpAndSettle();

        expect(find.text('Make to-do'), findsOneWidget);
        expect(find.text('Share Reminder'), findsNothing);

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        expect(find.text('Share Reminder'), findsOneWidget);
        await tester.tap(find.text('Share Reminder'));
        await tester.pumpAndSettle();

        expect(sharedReminder, isNotNull);
        expect(sharedReminder!.title, 'Journal every day');
        expect(sharedReminder!.reminderId, 'reminder-share');
      },
    );
  });

  group('DayViewPage header toggle', () {
    testWidgets('close button dismisses a pushed day view route', (
      tester,
    ) async {
      await _setPhoneViewport(tester);
      final closeEvents = <String>[];
      var userCloseReported = false;
      var lateRestorationReports = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (routeContext) => DayViewPage(
                          initialKy: 1,
                          initialKm: 2,
                          initialKd: 5,
                          showGregorian: false,
                          notesForDay: (ky, km, kd) => const [],
                          flowIndex: const {},
                          getMonthName: (month) => 'Month $month',
                          onUserClose: () async {
                            userCloseReported = true;
                            closeEvents.add('userClose');
                          },
                          onClose: () {
                            closeEvents.add('close');
                            Navigator.of(routeContext).pop();
                          },
                          onRestorationStateChanged:
                              ({
                                required int kYear,
                                required int kMonth,
                                required int kDay,
                                required bool showGregorian,
                                int? firstVisibleMinute,
                                double? scrollOffset,
                                EventDetailRestorationState? eventDetail,
                              }) {
                                if (userCloseReported) {
                                  lateRestorationReports += 1;
                                }
                              },
                        ),
                      ),
                    );
                  },
                  child: const Text('Open day view'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open day view'));
      await tester.pumpAndSettle();

      expect(find.byType(DayViewPage), findsOneWidget);
      expect(find.text('Open day view'), findsNothing);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(DayViewPage), findsNothing);
      expect(find.text('Open day view'), findsOneWidget);
      expect(closeEvents, <String>['userClose', 'close']);
      expect(lateRestorationReports, 0);
    });

    testWidgets('header omits duplicate global menu action', (tester) async {
      await _setPhoneViewport(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: DayViewPage(
            initialKy: 1,
            initialKm: 2,
            initialKd: 5,
            showGregorian: false,
            notesForDay: (ky, km, kd) => const [],
            flowIndex: const {},
            getMonthName: (month) => 'Month $month',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Menu'), findsNothing);
      expect(find.byIcon(Icons.more_vert), findsNothing);
      expect(find.byTooltip('New note'), findsOneWidget);
      expect(find.byTooltip('Search notes'), findsOneWidget);
      expect(find.byTooltip('Today'), findsOneWidget);
      expect(find.byTooltip('My Profile'), findsOneWidget);
    });

    testWidgets('system back reports user close for restoration clearing', (
      tester,
    ) async {
      await _setPhoneViewport(tester);
      var userCloseCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => DayViewPage(
                          initialKy: 1,
                          initialKm: 2,
                          initialKd: 5,
                          showGregorian: false,
                          notesForDay: (ky, km, kd) => const [],
                          flowIndex: const {},
                          getMonthName: (month) => 'Month $month',
                          onUserClose: () async {
                            userCloseCalls += 1;
                          },
                        ),
                      ),
                    );
                  },
                  child: const Text('Open day view'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open day view'));
      await tester.pumpAndSettle();

      expect(find.byType(DayViewPage), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(DayViewPage), findsNothing);
      expect(userCloseCalls, 1);
    });

    testWidgets('reopening after user close allows restoration reports again', (
      tester,
    ) async {
      await _setPhoneViewport(tester);
      var openSerial = 0;
      var secondOpenRestorationReports = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    final serial = ++openSerial;
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (routeContext) => DayViewPage(
                          initialKy: 1,
                          initialKm: 2,
                          initialKd: 5,
                          showGregorian: false,
                          notesForDay: (ky, km, kd) => const [],
                          flowIndex: const {},
                          getMonthName: (month) => 'Month $month',
                          onUserClose: () async {},
                          onClose: () => Navigator.of(routeContext).pop(),
                          onRestorationStateChanged:
                              ({
                                required int kYear,
                                required int kMonth,
                                required int kDay,
                                required bool showGregorian,
                                int? firstVisibleMinute,
                                double? scrollOffset,
                                EventDetailRestorationState? eventDetail,
                              }) {
                                if (serial == 2) {
                                  secondOpenRestorationReports += 1;
                                }
                              },
                        ),
                      ),
                    );
                  },
                  child: const Text('Open day view'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open day view'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Open day view'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('day_view_month_toggle')));
      await tester.pumpAndSettle();

      expect(find.byType(DayViewPage), findsOneWidget);
      expect(secondOpenRestorationReports, greaterThan(0));
    });

    testWidgets(
      'tapping the month label toggles the day header between Kemetic and Gregorian labels',
      (tester) async {
        await _setPhoneViewport(tester);

        const ky = 1;
        const km = 2;
        const kd = 5;
        final gregorian = KemeticMath.toGregorian(ky, km, kd);

        await tester.pumpWidget(
          MaterialApp(
            home: DayViewPage(
              initialKy: ky,
              initialKm: km,
              initialKd: kd,
              showGregorian: false,
              notesForDay: (_, _, _) => const [],
              flowIndex: const {},
              getMonthName: (month) {
                switch (month) {
                  case 1:
                    return 'Thoth (Tḥwty)';
                  case 2:
                    return 'Paopi (Mnḫt)';
                  default:
                    return 'Month $month';
                }
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        final localizations = MaterialLocalizations.of(
          tester.element(find.byType(Scaffold)),
        );
        final gregorianLabel = localizations.formatMediumDate(gregorian);
        final legacyGridHeader =
            '${gregorian.month}/${gregorian.day}/${gregorian.year}';
        final kemeticLabel = 'Paopi 5, ${gregorian.year}';
        final gregorianMonthLabel = _gregorianMonthName(gregorian.month);

        expect(find.text('Paopi (Mnḫt)'), findsOneWidget);
        expect(find.text(kemeticLabel), findsOneWidget);
        expect(find.text(gregorianLabel), findsNothing);
        expect(find.text(legacyGridHeader), findsNothing);

        await tester.tap(find.byKey(const ValueKey('day_view_month_toggle')));
        await tester.pumpAndSettle();

        expect(find.text(gregorianMonthLabel), findsOneWidget);
        expect(find.text(gregorianLabel), findsOneWidget);
        expect(find.text(legacyGridHeader), findsNothing);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is GlossyText &&
                widget.text == gregorianLabel &&
                widget.gradient == blueGloss,
          ),
          findsOneWidget,
        );
        expect(find.text(kemeticLabel), findsNothing);

        await tester.tap(find.byKey(const ValueKey('day_view_month_toggle')));
        await tester.pumpAndSettle();

        expect(find.text('Paopi (Mnḫt)'), findsOneWidget);
        expect(find.text(kemeticLabel), findsOneWidget);
      },
    );

    testWidgets('toggling to Gregorian updates the mini day strip labels too', (
      tester,
    ) async {
      await _setPhoneViewport(tester);

      const ky = 1;
      const km = 2;
      const kd = 5;
      final selectedGregorian = KemeticMath.toGregorian(ky, km, kd);
      final previousGregorian = KemeticMath.toGregorian(ky, km, kd - 1);

      await tester.pumpWidget(
        MaterialApp(
          home: DayViewPage(
            initialKy: ky,
            initialKm: km,
            initialKd: kd,
            showGregorian: false,
            notesForDay: (_, _, _) => const [],
            flowIndex: const {},
            getMonthName: (month) {
              switch (month) {
                case 1:
                  return 'Thoth (Tḥwty)';
                case 2:
                  return 'Paopi (Mnḫt)';
                default:
                  return 'Month $month';
              }
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('$kd'), findsWidgets);
      expect(find.text('${selectedGregorian.day}'), findsNothing);
      expect(find.text('${previousGregorian.day}'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('day_view_month_toggle')));
      await tester.pumpAndSettle();

      expect(find.text('${selectedGregorian.day}'), findsOneWidget);
      expect(find.text('${previousGregorian.day}'), findsOneWidget);
    });

    testWidgets(
      'current day stays centered in the mini date strip by default',
      (tester) async {
        await _setPhoneViewport(tester);

        await tester.pumpWidget(
          MaterialApp(
            home: DayViewPage(
              initialKy: 1,
              initialKm: 2,
              initialKd: 10,
              showGregorian: false,
              notesForDay: (_, _, _) => const [],
              flowIndex: const {},
              getMonthName: (month) => 'Month $month',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          tester
              .getCenter(find.byKey(const ValueKey('day_view_mini_chip_10')))
              .dx,
          closeTo(_screenCenterX(tester), 1.0),
        );

        await tester.drag(find.byType(PageView), const Offset(-320, 0));
        await tester.pumpAndSettle();

        expect(
          tester
              .getCenter(find.byKey(const ValueKey('day_view_mini_chip_11')))
              .dx,
          closeTo(_screenCenterX(tester), 1.0),
        );
      },
    );

    testWidgets(
      'manual mini date strip movement disables further auto-centering',
      (tester) async {
        await _setPhoneViewport(tester);

        await tester.pumpWidget(
          MaterialApp(
            home: DayViewPage(
              initialKy: 1,
              initialKm: 2,
              initialKd: 10,
              showGregorian: false,
              notesForDay: (_, _, _) => const [],
              flowIndex: const {},
              getMonthName: (month) => 'Month $month',
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.drag(
          find.byKey(const ValueKey('day_view_mini_calendar')),
          const Offset(-120, 0),
        );
        await tester.pumpAndSettle();

        final screenCenter = _screenCenterX(tester);
        expect(
          (tester
                      .getCenter(
                        find.byKey(const ValueKey('day_view_mini_chip_10')),
                      )
                      .dx -
                  screenCenter)
              .abs(),
          greaterThan(40.0),
        );

        await tester.drag(find.byType(PageView), const Offset(-320, 0));
        await tester.pumpAndSettle();

        expect(
          (tester
                      .getCenter(
                        find.byKey(const ValueKey('day_view_mini_chip_11')),
                      )
                      .dx -
                  screenCenter)
              .abs(),
          greaterThan(40.0),
        );
      },
    );
  });
}

String _gregorianMonthName(int month) {
  const monthNames = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  return monthNames[month - 1];
}

Future<void> _setPhoneViewport(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(() async {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _setPhoneLandscapeViewport(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(844, 390);
  addTearDown(() async {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _setTabletLandscapeViewport(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1194, 834);
  addTearDown(() async {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

NoteData _timedNote({
  String? id,
  String? clientEventId,
  required String title,
  required int startHour,
  required int startMinute,
  required int endHour,
  required int endMinute,
  int? flowId,
  Map<String, dynamic>? behaviorPayload,
}) {
  return NoteData(
    id: id,
    clientEventId: clientEventId,
    title: title,
    allDay: false,
    start: TimeOfDay(hour: startHour, minute: startMinute),
    end: TimeOfDay(hour: endHour, minute: endMinute),
    flowId: flowId,
    behaviorPayload: behaviorPayload,
  );
}

NoteData _livingTextNote({
  required String title,
  required String label,
  String? nodeSlug,
}) {
  return _timedNote(
    clientEventId: 'the-living-text:77:${title.toLowerCase()}',
    title: title,
    startHour: 10,
    startMinute: 0,
    endHour: 10,
    endMinute: 30,
    flowId: 77,
    behaviorPayload: <String, dynamic>{
      'flow_key': kLivingTextFlowKey,
      'event_number': title.contains(' 7:') ? 7 : 4,
      'library_cta': <String, dynamic>{
        'type': kMaatLibraryCtaAddInsight,
        'node_slug': nodeSlug,
        'label': label,
      },
    },
  );
}

NoteData _timedReminderNote({
  required String clientEventId,
  required String reminderId,
  required String title,
  required int startHour,
}) {
  return NoteData(
    clientEventId: clientEventId,
    title: title,
    allDay: false,
    start: TimeOfDay(hour: startHour, minute: 0),
    end: TimeOfDay(hour: startHour, minute: 30),
    isReminder: true,
    reminderId: reminderId,
  );
}

double _detailSheetPageHeight(WidgetTester tester) {
  final sizedBox = find.byWidgetPredicate(
    (widget) => widget is SizedBox && widget.child is PageView,
  );
  return tester.getSize(sizedBox).height;
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

Color? _ritualCardFillColor(WidgetTester tester) {
  final containers = tester.widgetList<Container>(
    find.byKey(
      const ValueKey<String>('day-view-ritual-completion-feedback-card'),
    ),
  );
  if (containers.isEmpty) return null;
  final container = containers.last;
  final decoration = container.decoration;
  if (decoration is! BoxDecoration) return null;
  return decoration.color;
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

double _screenCenterX(WidgetTester tester) =>
    tester.getSize(find.byType(Scaffold)).width / 2;

const Map<int, FlowData> _defaultFlowIndex = {
  1: FlowData(id: 1, name: 'Practice', color: Colors.green, active: true),
  2: FlowData(id: 2, name: 'Focus', color: Colors.red, active: true),
  3: FlowData(id: 3, name: 'Taxes', color: Colors.blue, active: true),
  4: FlowData(id: 4, name: 'Overflow', color: Colors.purple, active: true),
};

class _DayViewHarness extends StatelessWidget {
  const _DayViewHarness({
    required this.notes,
    this.initialScrollOffset = 9 * 60,
    this.flowIndex = _defaultFlowIndex,
    this.activeLedgerFlowIds,
    this.onEndFlow,
    this.onAppendToJournal,
    this.onRecordCompletion,
    this.onUnrecordCompletion,
    this.onRemoveCompletionBadge,
  });

  final List<NoteData> notes;
  final double initialScrollOffset;
  final Map<int, FlowData> flowIndex;
  final Set<int>? activeLedgerFlowIds;
  final void Function(int flowId)? onEndFlow;
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
        body: DayViewGrid(
          ky: 1,
          km: 1,
          kd: 1,
          notes: notes,
          showGregorian: false,
          flowIndex: flowIndex,
          activeLedgerFlowIds: activeLedgerFlowIds ?? flowIndex.keys.toSet(),
          initialScrollOffset: initialScrollOffset,
          onEndFlow: onEndFlow,
          onAppendToJournal: onAppendToJournal,
          onRecordCompletion: onRecordCompletion,
          onUnrecordCompletion: onUnrecordCompletion,
          onRemoveCompletionBadge: onRemoveCompletionBadge,
        ),
      ),
    );
  }
}

class _DayViewRouterHarness extends StatelessWidget {
  const _DayViewRouterHarness({required this.notes});

  final List<NoteData> notes;

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: DayViewGrid(
              ky: 1,
              km: 1,
              kd: 1,
              notes: notes,
              showGregorian: false,
              flowIndex: const {
                77: FlowData(
                  id: 77,
                  name: kLivingTextTitle,
                  color: Colors.amber,
                  active: true,
                ),
              },
              activeLedgerFlowIds: const <int>{77},
              initialScrollOffset: 9 * 60,
            ),
          ),
        ),
        GoRoute(
          path: '/nodes',
          builder: (context, state) =>
              const Scaffold(body: Text('Library root')),
        ),
        GoRoute(
          path: '/nodes/:nodeId',
          builder: (context, state) {
            final nodeId = state.pathParameters['nodeId']!;
            final action = state.uri.queryParameters['action'] ?? '';
            return Scaffold(body: Text('Node target: $nodeId action:$action'));
          },
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router);
  }
}

class _RestoredDetailGridHarness extends StatelessWidget {
  const _RestoredDetailGridHarness({
    required this.notes,
    required this.restoration,
    this.flowIndex = const <int, FlowData>{},
    this.onDeleteNote,
    this.onEndReminder,
  });

  final List<NoteData> notes;
  final EventDetailRestorationState restoration;
  final Map<int, FlowData> flowIndex;
  final Future<void> Function(int ky, int km, int kd, EventItem event)?
  onDeleteNote;
  final Future<void> Function(String reminderId)? onEndReminder;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: DayViewGrid(
          ky: 1,
          km: 1,
          kd: 1,
          notes: notes,
          showGregorian: false,
          flowIndex: flowIndex,
          activeLedgerFlowIds: flowIndex.keys.toSet(),
          initialScrollOffset: 8 * 60,
          initialEventDetailRestorationState: restoration,
          onDeleteNote: onDeleteNote,
          onEndReminder: onEndReminder,
        ),
      ),
    );
  }
}

class _MutableDayViewHarness extends StatelessWidget {
  const _MutableDayViewHarness({
    required this.notes,
    required this.dataVersion,
    this.onShareNote,
  });

  final ValueNotifier<List<NoteData>> notes;
  final ValueNotifier<int> dataVersion;
  final Future<void> Function(EventItem event)? onShareNote;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: ValueListenableBuilder<int>(
          valueListenable: dataVersion,
          builder: (context, _, child) {
            return DayViewGrid(
              ky: 1,
              km: 1,
              kd: 1,
              notes: notes.value,
              dataVersion: dataVersion,
              showGregorian: false,
              flowIndex: const {},
              initialScrollOffset: 9 * 60,
              onShareNote: onShareNote,
              resolveCurrentEventTarget: (target) {
                for (final note in notes.value) {
                  final sameId =
                      target.event.id != null &&
                      target.event.id!.isNotEmpty &&
                      note.id == target.event.id;
                  final sameClientId =
                      target.event.clientEventId != null &&
                      target.event.clientEventId!.isNotEmpty &&
                      note.clientEventId == target.event.clientEventId;
                  if (!sameId && !sameClientId) continue;
                  return DayViewSheetEventTarget(
                    ky: target.ky,
                    km: target.km,
                    kd: target.kd,
                    event: _eventFromNote(note),
                  );
                }
                return target;
              },
            );
          },
        ),
      ),
    );
  }
}

class _SheetPersistenceHarness extends StatelessWidget {
  const _SheetPersistenceHarness({
    required this.showGrid,
    required this.dataVersion,
  });

  final ValueNotifier<bool> showGrid;
  final ValueNotifier<int> dataVersion;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: ValueListenableBuilder<bool>(
          valueListenable: showGrid,
          builder: (context, isVisible, _) {
            if (!isVisible) {
              return const SizedBox.expand();
            }

            return DayViewGrid(
              ky: 1,
              km: 1,
              kd: 1,
              notes: [
                _timedNote(
                  title: 'Flow Block',
                  startHour: 10,
                  startMinute: 0,
                  endHour: 11,
                  endMinute: 0,
                  flowId: 1,
                ),
              ],
              dataVersion: dataVersion,
              showGregorian: false,
              flowIndex: const {
                1: FlowData(
                  id: 1,
                  name: 'Practice',
                  color: Colors.green,
                  active: true,
                ),
              },
              activeLedgerFlowIds: const {1},
              initialScrollOffset: 9 * 60,
            );
          },
        ),
      ),
    );
  }
}

class _PagedReminderDayViewHarness extends StatelessWidget {
  const _PagedReminderDayViewHarness({
    required this.notes,
    this.onShareReminder,
  });

  final List<NoteData> notes;
  final Future<void> Function(EventItem event)? onShareReminder;

  @override
  Widget build(BuildContext context) {
    final events = notes.map(_eventFromNote).toList()
      ..sort((a, b) => a.startMin.compareTo(b.startMin));

    DayViewSheetEventTarget? resolveAdjacent({
      required int ky,
      required int km,
      required int kd,
      required EventItem event,
      required bool forward,
    }) {
      final index = events.indexWhere(
        (candidate) => candidate.clientEventId == event.clientEventId,
      );
      if (index < 0) return null;
      final nextIndex = forward ? index + 1 : index - 1;
      if (nextIndex < 0 || nextIndex >= events.length) return null;
      return DayViewSheetEventTarget(
        ky: ky,
        km: km,
        kd: kd,
        event: events[nextIndex],
      );
    }

    DayViewSheetEventTarget resolveCurrent(DayViewSheetEventTarget target) {
      for (final event in events) {
        if (event.clientEventId != target.event.clientEventId) continue;
        return DayViewSheetEventTarget(
          ky: target.ky,
          km: target.km,
          kd: target.kd,
          event: event,
        );
      }
      return target;
    }

    return MaterialApp(
      home: Scaffold(
        body: DayViewGrid(
          ky: 1,
          km: 1,
          kd: 1,
          notes: notes,
          showGregorian: false,
          flowIndex: const {},
          initialScrollOffset: 9 * 60,
          onShareReminder: onShareReminder,
          resolveAdjacentEvent: resolveAdjacent,
          resolveCurrentEventTarget: resolveCurrent,
        ),
      ),
    );
  }
}

EventItem _eventFromNote(NoteData note) {
  final startMin = (note.start?.hour ?? 9) * 60 + (note.start?.minute ?? 0);
  final endMin = (note.end?.hour ?? 17) * 60 + (note.end?.minute ?? 0);
  return EventItem(
    id: note.id,
    clientEventId: note.clientEventId,
    title: note.title,
    detail: note.detail,
    location: note.location,
    startMin: startMin,
    endMin: endMin,
    flowId: note.flowId,
    color: note.manualColor ?? Colors.blue,
    manualColor: note.manualColor,
    allDay: note.allDay,
    category: note.category,
    isReminder: note.isReminder,
    reminderId: note.reminderId,
    behaviorPayload: note.behaviorPayload,
  );
}
