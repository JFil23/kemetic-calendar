import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/follow_sky_calendar_preview.dart';
import 'package:mobile/features/calendar/the_djed_flow.dart';
import 'package:mobile/features/calendar/the_kar/the_kar.dart';
import 'package:mobile/features/calendar/the_offering_table_flow.dart';
import 'package:mobile/features/calendar/the_reading_house_flow.dart';
import 'package:mobile/widgets/keyboard_aware.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/maat_flow_visual_test_fonts.dart';

const _captureKarVisuals = bool.fromEnvironment('CAPTURE_KAR_VISUALS');

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
    await loadMaatFlowVisualTestFonts();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    try {
      Supabase.instance.client;
    } catch (_) {
      await Supabase.initialize(
        url: 'https://example.supabase.co',
        anonKey: 'anon-key-0123456789012345678901234567890123456789',
      );
    }
  });

  test('the six authored netjer images are exact mockup extractions', () {
    const expectedHashes = <String, String>{
      'djehuty.png':
          '98b651be5dd8517c700c070f4b32d3205a45d2ad4631be21f95392be59a5e474',
      'maat.png':
          '282c5af4ebd68ec045105ccfbf3b1472679b7b788d09774057f8831b5071db98',
      'sekhmet.png':
          'c23030237f90e5a0a0dc7b0c6e6e56d33bdef60a6a29c65a509d24916553bcb1',
      'hetheru.png':
          '6a6e3b6d7f428720d0a682f6cc1013435a8ecfb7e527c39643ed10c2385d770b',
      'khepri.png':
          'bde2ade18c8ac40fb7c825ffdba545e11613b930b8b14c7edc02bc3c59755086',
      'ptah.png':
          '009beb5c9525dcdc03e3e4ebd439229f19e4368249d3124115689bc833f0fdf1',
    };
    expect(KarNetjer.values.map((value) => value.name), <String>[
      'Djehuty',
      'Maat',
      'Sekhmet',
      'Het-Heru',
      'Khepri',
      'Ptah',
    ]);
    for (final entry in expectedHashes.entries) {
      final bytes = File('assets/the_kar/${entry.key}').readAsBytesSync();
      expect(sha256.convert(bytes).toString(), entry.value, reason: entry.key);
    }
  });

  test('Kꜣr and Offering Table receive the shared calendar preview', () {
    expect(maatFlowDetailUsesCalendarPreview(kKarFlowKey), isTrue);
    expect(maatFlowDetailUsesCalendarPreview(kOfferingTableFlowKey), isTrue);
    expect(maatFlowDetailUsesCalendarPreview(kTheDjedFlowKey), isFalse);
    expect(maatFlowDetailUsesCalendarPreview(kReadingHouseFlowKey), isFalse);
  });

  testWidgets('Discovery taps Kꜣr into the existing shared detail host', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(home: buildMaatFlowsListPreviewForTesting()),
    );
    await tester.pumpAndSettle();

    final card = find.byKey(
      const ValueKey<String>('maat-flow-discovery-card-the-kar'),
    );
    await tester.scrollUntilVisible(
      card,
      460,
      scrollable: find.byType(Scrollable).first,
    );
    final visiblePoint = tester.getTopLeft(card) + const Offset(20, 20);
    expect(visiblePoint.dy, inInclusiveRange(0, 843));
    await tester.tapAt(visiblePoint);
    await tester.pumpAndSettle();

    expect(find.byType(KarDetailSurface), findsOneWidget);
    expect(find.byKey(kMaatFlowDetailSurfaceHostKey), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('kar-shared-sheet')),
      findsOneWidget,
    );
    expect(find.byType(ModalBottomSheetRoute), findsNothing);
    expect(find.byKey(const ValueKey<String>('kar-back')), findsOneWidget);
  });

  test('Kꜣr owns no competing page or modal presentation', () {
    final source = Directory('lib/features/calendar/the_kar')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');

    expect(source, isNot(contains('class KarDetailPage')));
    expect(source, isNot(contains('showModalBottomSheet')));
    expect(source, isNot(contains('Navigator.push')));
    expect(source, contains('MaatFlowDetailShell('));
    expect(source, contains('showCalendarEventDetailSheetModal'));
    expect(source, contains('InstrumentEventSheetHost('));
  });

  testWidgets(
    'detail event blocks open their existing preview sheet before a cycle exists',
    (tester) async {
      _setPhoneViewport(tester);
      final repository = MemoryKarRepository();
      await _pumpDetail(tester, repository);

      expect(
        tester
            .widgetList<KarEventBlockVisual>(find.byType(KarEventBlockVisual))
            .every((block) => block.onTap != null),
        isTrue,
      );

      final eventBlock = find.byKey(
        const ValueKey<String>('kar-event-block-0'),
      );
      await _openDetailEventSheet(tester, eventBlock, stageIndex: 0);

      expect(
        find.descendant(
          of: find.byType(KarDayBehaviorSurface),
          matching: find.text('Wisdom'),
        ),
        findsOneWidget,
      );
      expect(find.byTooltip('Event options'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('kar-completion-picker')),
        findsNothing,
      );
      expect(find.text('Draw'), findsNothing);
      expect(find.text('Describe'), findsNothing);
      expect(
        (await repository.loadOrCreate(KarNetjer.djehuty)).cycles,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'detail event sheet saves a draft and places it through shared behavior',
    (tester) async {
      _setPhoneViewport(tester);
      final repository = MemoryKarRepository(
        initial: <KarNetjer, KarShrine>{KarNetjer.djehuty: _activeShrine()},
      );
      await _pumpDetail(tester, repository);

      await _openDetailEventSheet(
        tester,
        find.byKey(const ValueKey<String>('kar-arrival-card')),
        stageIndex: 0,
      );
      expect(find.byTooltip('Event options'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('kar-completion-picker')),
        findsNothing,
      );
      await _raiseKarEventContent(tester);
      await tester.tap(find.text('Describe'));
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey<String>('kar-describe-field'));
      await tester.enterText(
        field,
        'A dark robe covered in handwritten notes.',
      );
      final save = find.byKey(const ValueKey<String>('kar-save-draft'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      var stored = await repository.loadOrCreate(KarNetjer.djehuty);
      expect(stored.activeCycle!.placements.first.activeVersion, isNull);
      expect(stored.drafts, hasLength(1));

      final place = find.byKey(const ValueKey<String>('kar-place-draft'));
      await tester.ensureVisible(place);
      await tester.tap(place);
      await tester.pumpAndSettle();

      stored = await repository.loadOrCreate(KarNetjer.djehuty);
      expect(stored.drafts, isEmpty);
      expect(
        stored.activeCycle!.placements.first.activeVersion!.content,
        'A dark robe covered in handwritten notes.',
      );
      expect(find.byType(KeyboardAwareEditableSurface), findsOneWidget);
    },
  );

  testWidgets('capture offers authored Describe and Draw modes', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    final repository = MemoryKarRepository(
      initial: <KarNetjer, KarShrine>{KarNetjer.djehuty: _activeShrine()},
    );
    await _pumpDetail(tester, repository);
    await _openDetailEventSheet(
      tester,
      find.byKey(const ValueKey<String>('kar-arrival-card')),
      stageIndex: 0,
    );

    final draw = find.text('Draw');
    await _raiseKarEventContent(tester);
    expect(find.text('Describe'), findsOneWidget);
    await tester.tap(draw);
    await tester.pumpAndSettle();
    final captureWindow = find.byKey(
      const ValueKey<String>('kar-capture-window'),
    );
    final captureRect = tester.getRect(captureWindow);
    expect(captureRect.size, const Size(354, 690));
    expect(captureRect.center, const Offset(195, 422));
    expect(
      find.ancestor(
        of: captureWindow,
        matching: find.byType(KarDayBehaviorSurface),
      ),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('kar-drawing-pad')),
      findsOneWidget,
    );
    expect(find.text('Bad drawings welcome.'), findsNWidgets(2));
  });

  testWidgets(
    'detail uses three aligned decans and dated calendar cards before behavior',
    (tester) async {
      _setPhoneViewport(tester);
      final repository = MemoryKarRepository(
        initial: <KarNetjer, KarShrine>{
          KarNetjer.djehuty: _place(
            _activeShrine(),
            stageIndex: 0,
            content: 'A blue robe, circular room, and silver pipe.',
          ),
        },
      );
      await _pumpDetail(
        tester,
        repository,
        calendarPreview: FollowSkyCalendarPreview(
          rows: <FollowSkyCalendarPreviewRow>[
            FollowSkyCalendarPreviewRow(
              localDay: DateTime(2026, 9, 9),
              start: DateTime(2026, 9, 9, 8),
              end: DateTime(2026, 9, 9, 8, 30),
              title: 'journal every day',
              flowName: 'Journal',
              eventColor: const Color(0xFF72C766),
            ),
            FollowSkyCalendarPreviewRow(
              localDay: DateTime(2026, 9, 9),
              start: DateTime(2026, 9, 9, 12),
              end: DateTime(2026, 9, 9, 13),
              title: 'Bits and Operations',
              flowName: 'Work',
              eventColor: const Color(0xFF4EA8DE),
            ),
            FollowSkyCalendarPreviewRow(
              localDay: DateTime(2026, 9, 9),
              start: DateTime(2026, 9, 9, 21, 30),
              end: DateTime(2026, 9, 9, 22),
              title: 'journal every night',
              flowName: 'Journal',
              eventColor: const Color(0xFF72C766),
            ),
          ],
        ),
      );

      final calendar = find.byKey(
        const ValueKey<String>('kar-thirty-day-calendar'),
      );
      await _reveal(tester, calendar);
      expect(find.text('Decan I'), findsOneWidget);
      expect(find.text('Decan II'), findsOneWidget);
      expect(find.text('Decan III'), findsOneWidget);
      expect(find.text('days 1–10'), findsOneWidget);
      expect(find.text('days 21–30'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('kar-calendar-day-30')),
        findsOneWidget,
      );
      if (_captureKarVisuals) {
        await expectLater(
          find.byKey(const ValueKey<String>('kar-detail-surface')),
          matchesGoldenFile('/tmp/kar-detail-calendar-flutter.png'),
        );
        await expectLater(
          calendar,
          matchesGoldenFile('/tmp/kar-detail-calendar-element-flutter.png'),
        );
      }

      final firstRowY = tester
          .getCenter(find.byKey(const ValueKey<String>('kar-calendar-day-1')))
          .dy;
      for (var day = 2; day <= 10; day++) {
        final center = tester.getCenter(
          find.byKey(ValueKey<String>('kar-calendar-day-$day')),
        );
        expect(center.dy, closeTo(firstRowY, .01));
      }

      for (var stage = 0; stage < 5; stage++) {
        final schedule = find.byKey(
          ValueKey<String>('kar-schedule-day-$stage'),
        );
        expect(schedule, findsOneWidget);
        final eventBlock = find.descendant(
          of: schedule,
          matching: find.byKey(ValueKey<String>('kar-event-block-$stage')),
        );
        expect(tester.getSize(eventBlock).height, 106);
      }
      expect(
        find.byKey(const ValueKey<String>('kar-closing-walk-row')),
        findsOneWidget,
      );
      expect(find.text('Bits and Operations'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('kar-schedule-calendar-empty-1')),
        findsOneWidget,
      );
      if (_captureKarVisuals) {
        await _reveal(
          tester,
          find.byKey(const ValueKey<String>('kar-schedule-day-0')),
        );
        await expectLater(
          find.byKey(const ValueKey<String>('kar-schedule-day-0')),
          matchesGoldenFile('/tmp/kar-detail-schedule-day-1-flutter.png'),
        );
        await expectLater(
          find.byKey(const ValueKey<String>('kar-closing-walk-row')),
          matchesGoldenFile('/tmp/kar-detail-day-30-flutter.png'),
        );
        await expectLater(
          find.byKey(const ValueKey<String>('kar-detail-surface')),
          matchesGoldenFile('/tmp/kar-detail-events-flutter.png'),
        );
      }
    },
  );

  testWidgets('dated cards distinguish loading from a genuinely empty day', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    final repository = MemoryKarRepository(
      initial: <KarNetjer, KarShrine>{KarNetjer.djehuty: _activeShrine()},
    );
    await _pumpDetail(
      tester,
      repository,
      calendarPreview: const FollowSkyCalendarPreview(coverageComplete: false),
    );

    final firstDay = find.byKey(const ValueKey<String>('kar-schedule-day-0'));
    await _reveal(tester, firstDay);
    expect(
      find.byKey(const ValueKey<String>('kar-schedule-calendar-loading-0')),
      findsOneWidget,
    );
    expect(find.text('Loading calendar…'), findsWidgets);
    expect(find.text('No other calendar entries'), findsNothing);
  });

  testWidgets(
    'Discovery calendar event uses the shared resizable sheet and restores list position',
    (tester) async {
      _setPhoneViewport(tester);
      final repository = MemoryKarRepository(
        initial: <KarNetjer, KarShrine>{KarNetjer.djehuty: _activeShrine()},
      );
      await tester.pumpWidget(
        MaterialApp(
          home: buildMaatFlowsListPreviewForTesting(
            joinedKeys: const <String>{kKarFlowKey},
            karRepository: repository,
            calendarPreview: FollowSkyCalendarPreview(
              rows: <FollowSkyCalendarPreviewRow>[
                FollowSkyCalendarPreviewRow(
                  localDay: DateTime(2026, 9, 9),
                  start: DateTime(2026, 9, 9, 12),
                  end: DateTime(2026, 9, 9, 13),
                  title: 'Bits and Operations',
                  flowName: 'Work',
                  eventColor: const Color(0xFF4EA8DE),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final discoveryCard = find.byKey(
        const ValueKey<String>('maat-flow-discovery-card-the-kar'),
      );
      await tester.scrollUntilVisible(
        discoveryCard,
        460,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tapAt(
        tester.getTopLeft(discoveryCard) + const Offset(20, 20),
      );
      await tester.pumpAndSettle();

      final schedule = find.byKey(const ValueKey<String>('kar-schedule-day-0'));
      await _reveal(tester, schedule);
      expect(find.text('Bits and Operations'), findsOneWidget);
      final detailScroll = find.byKey(
        const ValueKey<String>('kar-detail-scroll'),
      );
      final before = tester
          .widget<CustomScrollView>(detailScroll)
          .controller!
          .offset;
      final eventBlock = find.descendant(
        of: schedule,
        matching: find.byKey(const ValueKey<String>('kar-event-block-0')),
      );
      await tester.tap(eventBlock);
      await tester.pumpAndSettle();

      final sheet = find.byKey(
        const ValueKey<String>('kar-detail-event-sheet-0'),
      );
      expect(sheet, findsOneWidget);
      expect(find.byType(KarDayBehaviorSurface), findsOneWidget);
      final expandedHeight = tester.getSize(sheet).height;
      expect(expandedHeight, closeTo((844 - 12) * .71, 1.5));
      await tester.drag(
        find.byKey(const ValueKey<String>('follow-sky-sheet-resize-handle')),
        const Offset(0, 180),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(sheet).height, lessThan(expandedHeight));

      await tester.tap(
        find.byKey(const ValueKey<String>('kar-detail-event-sheet-close-0')),
      );
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
      final after = tester
          .widget<CustomScrollView>(detailScroll)
          .controller!
          .offset;
      expect(after, closeTo(before, .01));
    },
  );

  testWidgets(
    'netjer cards omit source pills and keep cycle status at top right',
    (tester) async {
      _setPhoneViewport(tester);
      final repository = MemoryKarRepository(
        initial: <KarNetjer, KarShrine>{KarNetjer.djehuty: _activeShrine()},
      );
      await _pumpDetail(tester, repository);

      final source = find.byKey(
        const ValueKey<String>('kar-netjer-source-djehuty'),
      );
      final cycle = find.byKey(
        const ValueKey<String>('kar-netjer-cycle-djehuty'),
      );
      final card = find.byKey(const ValueKey<String>('kar-netjer-djehuty'));
      expect(source, findsNothing);
      expect(cycle, findsOneWidget);
      final cycleRect = tester.getRect(cycle);
      final cardRect = tester.getRect(card);
      expect(cycleRect.top, closeTo(cardRect.top + 13, 2));
      expect(cycleRect.right, closeTo(cardRect.right - 13, 2));
    },
  );

  testWidgets(
    'Discovery path centers all six authored netjer cards and omits source pills',
    (tester) async {
      _setPhoneViewport(tester);
      final repository = MemoryKarRepository(
        initial: <KarNetjer, KarShrine>{
          for (final netjer in KarNetjer.values)
            netjer: _activeShrineFor(netjer, flowId: 100 + netjer.index),
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: buildMaatFlowsListPreviewForTesting(
            joinedKeys: const <String>{kKarFlowKey},
            karRepository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final discoveryCard = find.byKey(
        const ValueKey<String>('maat-flow-discovery-card-the-kar'),
      );
      await tester.scrollUntilVisible(
        discoveryCard,
        460,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tapAt(
        tester.getTopLeft(discoveryCard) + const Offset(20, 20),
      );
      await tester.pumpAndSettle();

      final detailContext = tester.element(find.byType(KarDetailSurface));
      await tester.runAsync(() async {
        await precacheImage(
          const AssetImage('assets/the_kar/hero.png'),
          detailContext,
        );
        for (final netjer in KarNetjer.values) {
          await precacheImage(AssetImage(netjer.asset), detailContext);
        }
      });
      await tester.pumpAndSettle();

      final carousel = find.byKey(
        const ValueKey<String>('kar-netjer-carousel'),
      );
      final scrollable = find.descendant(
        of: carousel,
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scrollable).position;
      for (final netjer in KarNetjer.values) {
        position.jumpTo(
          (netjer.index * position.viewportDimension * .92)
              .clamp(position.minScrollExtent, position.maxScrollExtent)
              .toDouble(),
        );
        await tester.pumpAndSettle();
        final card = find.byKey(ValueKey<String>('kar-netjer-${netjer.key}'));
        expect(card, findsOneWidget);
        await tester.tap(card);
        await tester.pumpAndSettle();

        final cycle = find.byKey(
          ValueKey<String>('kar-netjer-cycle-${netjer.key}'),
        );
        expect(
          find.byKey(ValueKey<String>('kar-netjer-source-${netjer.key}')),
          findsNothing,
        );
        expect(cycle, findsOneWidget);
        expect(tester.getSize(card), const Size(306, 408));
        expect(
          tester.getCenter(card).dx,
          closeTo(tester.getCenter(carousel).dx, .75),
        );
        expect(find.text('${netjer.index + 1} of 6'), findsOneWidget);
        if (_captureKarVisuals) {
          await expectLater(
            card,
            matchesGoldenFile('/tmp/kar-netjer-${netjer.key}-flutter.png'),
          );
        }
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('recall hides the cue and artifact until the reader asks', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    final repository = MemoryKarRepository(
      initial: <KarNetjer, KarShrine>{
        KarNetjer.djehuty: _place(
          _activeShrine(),
          stageIndex: 0,
          content: 'A blue robe, circular room, and silver pipe.',
        ),
      },
    );
    await _pumpDay(tester, repository: repository, flowId: 91, stageIndex: 0);

    expect(find.text('It’s here'), findsOneWidget);
    expect(find.text('I have a piece'), findsOneWidget);
    expect(find.text('Not yet'), findsOneWidget);
    expect(find.text(KarNetjer.djehuty.partials.first), findsNothing);
    expect(
      find.text('A blue robe, circular room, and silver pipe.'),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey<String>('kar-return-piece')));
    await tester.pump();
    expect(find.text(KarNetjer.djehuty.partials.first), findsOneWidget);
    expect(
      find.text('A blue robe, circular room, and silver pipe.'),
      findsNothing,
    );

    final dayScroll = find.byKey(
      const ValueKey<String>('kar-day-sheet-scroll'),
    );
    await tester.drag(dayScroll, const Offset(0, -360));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show me'));
    await tester.pumpAndSettle();
    expect(
      find.text('A blue robe, circular room, and silver pipe.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'Day 30 walk stays in the same sheet and ignores older-cycle scenes',
    (tester) async {
      _setPhoneViewport(tester);
      var old = _place(
        _activeShrine(),
        stageIndex: 0,
        content: 'An earlier threshold that must stay behind.',
      );
      old = old.completeWalk(
        now: DateTime.utc(2026, 10, 9),
        outcomes: const <String>['recalled', 'open', 'open', 'open', 'open'],
      );
      final current = old.beginCycle(
        cycleId: 'cycle-2',
        anchorDate: DateTime(2026, 11, 1),
        flowId: 92,
      );
      final repository = MemoryKarRepository(
        initial: <KarNetjer, KarShrine>{KarNetjer.djehuty: current},
      );
      await _pumpDay(tester, repository: repository, flowId: 92, stageIndex: 5);

      expect(
        find.byKey(const ValueKey<String>('kar-begin-walk')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey<String>('kar-begin-walk')));
      await tester.pump();

      expect(find.byType(KarDayBehaviorSurface), findsOneWidget);
      expect(find.byType(ModalBottomSheetRoute), findsNothing);
      expect(find.text('This place is open.'), findsOneWidget);
      expect(
        find.text('An earlier threshold that must stay behind.'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'completed history can be selected and replaced without erasing its first version',
    (tester) async {
      _setPhoneViewport(tester);
      var completed = _place(
        _activeShrine(),
        stageIndex: 0,
        content: 'First completed threshold.',
      );
      completed = completed.completeWalk(
        now: DateTime.utc(2026, 10, 9),
        outcomes: const <String>['recalled', 'open', 'open', 'open', 'open'],
      );
      final repository = MemoryKarRepository(
        initial: <KarNetjer, KarShrine>{KarNetjer.djehuty: completed},
      );
      await _pumpDetail(tester, repository);

      final history = find.byKey(
        const ValueKey<String>('kar-history-cycle-cycle-1'),
      );
      await _reveal(tester, history);
      await tester.tap(history);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('kar-detail-event-sheet-0')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('kar-return-not-yet')),
      );
      await tester.pumpAndSettle();
      await _raiseKarEventContent(tester, distance: 240);
      final replace = find.text('Make this place again');
      await tester.ensureVisible(replace);
      await tester.tap(replace);
      await tester.pumpAndSettle();
      final describe = find.text('Describe');
      await tester.ensureVisible(describe);
      await tester.tap(describe);
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey<String>('kar-describe-field'));
      await tester.enterText(field, 'Replacement after completion.');
      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('kar-save-draft')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('kar-save-draft')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('kar-place-draft')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('kar-place-draft')));
      await tester.pumpAndSettle();

      final stored = await repository.loadOrCreate(KarNetjer.djehuty);
      final versions = stored.cycles.single.placements.first.versions;
      expect(versions, hasLength(2));
      expect(versions.first.content, 'First completed threshold.');
      expect(versions.last.content, 'Replacement after completion.');
      expect(versions.last.supersedesId, versions.first.id);
    },
  );

  testWidgets('Kꜣr detail visual evidence at the reference viewport', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    var completed = _activeShrine();
    for (var stage = 0; stage < 5; stage++) {
      completed = _place(
        completed,
        stageIndex: stage,
        content: 'Earlier reference scene ${stage + 1}.',
      );
    }
    completed = completed.completeWalk(
      now: DateTime.utc(2026, 1, 30),
      outcomes: const <String>[
        'recalled',
        'recalled',
        'recalled',
        'recalled',
        'recalled',
      ],
    );
    var shrine = completed.beginCycle(
      cycleId: 'cycle-2',
      anchorDate: DateTime(2026, 2, 1),
      flowId: 92,
    );
    for (var stage = 0; stage < 3; stage++) {
      shrine = _place(
        shrine,
        stageIndex: stage,
        content: 'Reference scene ${stage + 1}.',
      );
    }
    final repository = MemoryKarRepository(
      initial: <KarNetjer, KarShrine>{KarNetjer.djehuty: shrine},
    );
    await tester.pumpWidget(
      MaterialApp(
        home: buildMaatFlowsListPreviewForTesting(
          joinedKeys: const <String>{kKarFlowKey},
          karRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final card = find.byKey(
      const ValueKey<String>('maat-flow-discovery-card-the-kar'),
    );
    await tester.scrollUntilVisible(
      card,
      460,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tapAt(tester.getTopLeft(card) + const Offset(20, 20));
    await tester.pumpAndSettle();
    final detailContext = tester.element(find.byType(KarDetailSurface));
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/the_kar/hero.png'),
        detailContext,
      );
      for (final netjer in KarNetjer.values) {
        await precacheImage(AssetImage(netjer.asset), detailContext);
      }
    });
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('kar-hero-layer')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('kar-shared-sheet')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey<String>('kar-back')), findsOneWidget);
    if (_captureKarVisuals) {
      await expectLater(
        find.byKey(const ValueKey<String>('kar-detail-surface')),
        matchesGoldenFile('/tmp/kar-detail-flutter.png'),
      );
    }
  });
}

KarShrine _activeShrine() => KarShrine(
  id: 'kar-user-djehuty',
  netjer: KarNetjer.djehuty,
  revision: 0,
  cycles: const <KarCycle>[],
).beginCycle(cycleId: 'cycle-1', anchorDate: DateTime(2026, 9, 9), flowId: 91);

KarShrine _activeShrineFor(KarNetjer netjer, {required int flowId}) =>
    KarShrine(
      id: 'kar-user-${netjer.key}',
      netjer: netjer,
      revision: 0,
      cycles: const <KarCycle>[],
    ).beginCycle(
      cycleId: 'cycle-${netjer.key}',
      anchorDate: DateTime(2026, 9, 10),
      flowId: flowId,
    );

KarShrine _place(
  KarShrine shrine, {
  required int stageIndex,
  required String content,
}) {
  final cycle = shrine.activeCycle!;
  return shrine
      .saveDraft(
        cycleId: cycle.id,
        stageIndex: stageIndex,
        draft: KarDraft(
          kind: 'description',
          content: content,
          savedAt: DateTime.utc(2026, 9, 10),
        ),
      )
      .placeDraft(
        cycleId: cycle.id,
        stageIndex: stageIndex,
        versionId: 'entry-${cycle.id}-$stageIndex',
        now: DateTime.utc(2026, 9, 10, 12),
      );
}

Future<void> _pumpDetail(
  WidgetTester tester,
  MemoryKarRepository repository, {
  FollowSkyCalendarPreview calendarPreview = FollowSkyCalendarPreview.empty,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: KarDetailSurface(
          repository: repository,
          calendarPreview: calendarPreview,
          onJoin:
              ({
                required netjer,
                required cycleId,
                required cycleSequence,
                required startDate,
              }) async => 91,
          clock: () => DateTime(2026, 9, 9),
        ),
      ),
    ),
  );
  await tester.pump();
  final context = tester.element(find.byType(KarDetailSurface));
  await tester.runAsync(() async {
    await precacheImage(const AssetImage('assets/the_kar/hero.png'), context);
    for (final netjer in KarNetjer.values) {
      await precacheImage(AssetImage(netjer.asset), context);
    }
  });
  await tester.pumpAndSettle();
}

Future<void> _pumpDay(
  WidgetTester tester, {
  required MemoryKarRepository repository,
  required int flowId,
  required int stageIndex,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: KarDayBehaviorSurface(
          repository: repository,
          netjer: KarNetjer.djehuty,
          flowId: flowId,
          stageIndex: stageIndex,
          clock: () => DateTime(2026, 10, 9),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    360,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> _openDetailEventSheet(
  WidgetTester tester,
  Finder target, {
  required int stageIndex,
}) async {
  await _reveal(tester, target);
  await tester.tap(target);
  await tester.pumpAndSettle();
  expect(
    find.byKey(ValueKey<String>('kar-detail-event-sheet-$stageIndex')),
    findsOneWidget,
  );
  expect(find.byType(KarDayBehaviorSurface), findsOneWidget);
}

Future<void> _raiseKarEventContent(
  WidgetTester tester, {
  double distance = 380,
}) async {
  await tester.drag(
    find.byKey(const ValueKey<String>('kar-day-sheet-scroll')),
    Offset(0, -distance),
  );
  await tester.pumpAndSettle();
}

void _setPhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
