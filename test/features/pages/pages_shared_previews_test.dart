import 'package:mobile/features/profile/commons_rhythm_block.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:mobile/features/calendar/the_kar/the_kar_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/data/commons_models.dart';
import 'package:mobile/data/commons_question_selection.dart';
import 'package:mobile/data/flow_appearance.dart';
import '../../fixtures/follow_sky_observation_presentation_fixture.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/widgets/follow_sky_instrument_surface.dart';
import 'package:mobile/features/calendar/the_offering_table/presentation/offering_table_day_instrument.dart';
import 'package:mobile/features/calendar/the_offering_table/presentation/offering_table_day_state.dart';
import 'package:mobile/features/calendar/the_djed/presentation/djed_day_presentation.dart';
import 'package:mobile/features/calendar/the_reading_house/presentation/reading_house_day_presentation.dart';
import 'package:mobile/features/calendar/the_kar/presentation/kar_day_behavior_surface.dart';
import 'package:mobile/features/journal/journal_event_badge.dart';
import 'package:mobile/features/pages/pages_arrangement.dart';
import 'package:mobile/features/pages/pages_board.dart';
import 'package:mobile/features/pages/pages_models.dart';
import 'package:mobile/features/pages/pages_studio_graphic.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final fonts =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in fonts) {
      final loader = FontLoader(font['family']);
      for (final asset in font['fonts']) {
        loader.addFont(rootBundle.load(asset['asset']));
      }
      await loader.load();
    }
  });
  test('Commons selects today only and preserves the saved answer', () {
    final date = DateTime(2026, 9, 27),
        seed = commonsQuestionSeed(DateTime(2026, 9, 27));
    const answer = CommonsAnswer(
      id: 'a',
      questionId: 'q',
      userId: 'u',
      bodyText: 'Actual answer',
    );
    final snapshot = CommonsHomeSnapshot.fromJson({
      'questions': [
        {'id': 'yesterday', 'question': 'Old question'},
        {
          'id': seed.id,
          'question': 'Earlier cached editorial question',
          'my_answer': {'id': answer.id, 'body_text': answer.bodyText},
        },
      ],
    });
    final q = activeCommonsQuestion(snapshot, date);
    expect(q.id, seed.id);
    expect(q.question, seed.text);
    expect(q.myAnswer?.bodyText, answer.bodyText);
  });
  testWidgets('Commons card fills the pane and retains real answer states', (
    tester,
  ) async {
    for (final width in [150.0, 186.5]) {
      for (final answered in [false, true]) {
        const saved = CommonsAnswer(
          id: 'saved',
          questionId: 'today',
          userId: 'viewer',
          bodyText: 'A real saved reflection',
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: width,
                  height: width / 1.49 + 43,
                  child: PagesTile(
                    card: PagesCard(
                      PagesDestination.feed,
                      state: PagesLoadState.ready,
                      question: CommonsQuestion(
                        id: 'today',
                        question:
                            'What do my daily habits teach others to expect?',
                        myAnswer: answered ? saved : null,
                      ),
                    ),
                    onTap: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('II'), findsNothing);
        expect(find.text('QUESTION OF THE DAY'), findsNothing);
        expect(find.text("FROM TODAY'S DAILY REFLECTION"), findsOneWidget);
        expect(
          find.text('What do my daily habits teach others to expect?'),
          findsOneWidget,
        );
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text('What do my daily habits teach others to expect?'),
        );
        final lines = paragraph.getBoxesForSelection(
          const TextSelection(baseOffset: 0, extentOffset: 46),
        );
        for (final line in lines) {
          expect(line.bottom, lessThanOrEqualTo(paragraph.size.height + 1));
        }
        expect(
          find.text(answered ? saved.bodyText : 'Answer in the Commons'),
          findsOneWidget,
        );
        expect(find.byType(TextField), findsNothing);
        expect(find.byType(FittedBox), findsNothing);
        expect(tester.takeException(), isNull);
        if (width == 186.5) {
          await capturePane(tester, answered ? 'feed-saved' : 'feed-open');
        }
      }
    }
  });
  testWidgets(
    'shared badge area renders actual tokens without preview controls taking taps',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var taps = 0;
      final badge = EventBadgeToken(
        id: 'calendar:test',
        title: 'Day 11: The Household Table Opens',
        start: DateTime(2026, 9, 27, 7, 30),
        color: const Color(0xFFB98042),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 186.5,
                height: 170,
                child: PagesTile(
                  card: PagesCard(
                    PagesDestination.journal,
                    state: PagesLoadState.ready,
                    badges: [badge],
                  ),
                  onTap: () => taps++,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 badge'), findsOneWidget);
      expect(find.text(badge.title), findsOneWidget);
      expect(find.text('7:30a'), findsOneWidget);
      expect(
        tester.getCenter(find.text(badge.title)).dy,
        closeTo(tester.getCenter(find.text('7:30a')).dy, 1),
      );
      expect(
        find.descendant(
          of: find.byType(PagesTile),
          matching: find.byType(FittedBox),
        ),
        findsOneWidget,
      );
      final title = tester.renderObject<RenderParagraph>(
        find.text(badge.title),
      );
      expect(title.didExceedMaxLines, isFalse);
      final fitted = tester.widget<FittedBox>(find.byType(FittedBox));
      expect(fitted.fit, BoxFit.scaleDown);
      expect((fitted.child! as SizedBox).width, 321);
      await capturePane(tester, 'journal-populated');
      await tester.tap(find.byType(PagesTile));
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('public rhythm fits the pane with real Commons metric labels', (
    tester,
  ) async {
    const summary = CommonsRhythmSummary(
      activeUsersTodayLabel: '10–19',
      flowsKeptTodayLabel: '42',
      publicFragmentsTodayLabel: '0',
      publicRoomsOpenLabel: '3',
      topFlowTitle: 'Follow the Sky',
      topFlowCountLabel: '12',
    );
    for (final width in [150.0, 186.5]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: const ValueKey('rhythm-capture'),
                child: SizedBox(
                  width: width,
                  height: width / 1.49,
                  child: const CommonsRhythmBlock(summary: summary, pane: true),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('PUBLIC RHYTHM'), findsOneWidget);
      expect(find.text('10–19'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('Top flow: Follow the Sky'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (width == 186.5) {
        await capturePane(
          tester,
          'feed-rhythm',
          boundaryFinder: find.byKey(const ValueKey('rhythm-capture')),
        );
      }
    }
  });
  testWidgets('all five Ma’at previews mount their actual Day View graphics', (
    tester,
  ) async {
    final event = PagesUpcomingEvent(
      id: 'event',
      flowId: '1',
      title: 'Scheduled event',
      at: DateTime(2026, 9, 28),
      behavior: const {
        'djed_schema_version': 2,
        'event_number': 2,
        'kar_stage_index': 0,
        'house_mode': 'solo',
      },
    );
    for (final key in [
      'track-the-sky',
      'the-offering-table',
      'the-djed',
      'the-reading-house',
      'the-kar',
    ]) {
      final snapshot = PagesStudioSnapshot(
        sky: key == 'track-the-sky'
            ? losAngelesFullMoonPresentationFixture
            : null,
        offeringDay: key == 'the-offering-table' ? 12 : null,
        offeringStates: {12: OfferingTableDayViewState()},
        kar:
            const KarShrine(
              id: 'fixture',
              netjer: KarNetjer.djehuty,
              revision: 0,
              cycles: [],
            ).beginCycle(
              cycleId: 'cycle',
              anchorDate: DateTime(2026, 9, 28),
              flowId: 1,
            ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 186.5,
                height: 170,
                child: PagesTile(
                  card: PagesCard(
                    PagesDestination.studio,
                    state: PagesLoadState.ready,
                    flow: PagesFlow(
                      id: '1',
                      name: key,
                      appearance: FlowAppearance.empty,
                      maatKey: key,
                    ),
                    event: event,
                    studioSnapshot: snapshot,
                  ),
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final type = switch (key) {
        'track-the-sky' => FollowSkyInstrumentSurface,
        'the-offering-table' => OfferingTableDayInstrument,
        'the-djed' => DjedDayInstrument,
        'the-reading-house' => ReadingHouseChatRoom,
        _ => KarDayGraphic,
      };
      expect(find.byType(type), findsOneWidget, reason: key);
      expect(tester.takeException(), isNull, reason: key);
      if (key == 'the-djed') {
        expect(
          tester.getSize(find.byType(DjedSittingStage)).width,
          greaterThan(150),
        );
      }
      expect(
        find.descendant(
          of: find.byType(PagesTile),
          matching: find.byType(FittedBox),
        ),
        key == 'the-kar' ? findsOneWidget : findsNothing,
        reason: key,
      );
      await capturePane(tester, key);
    }
    await tester.pumpWidget(const SizedBox());
  });
}

Future<void> capturePane(
  WidgetTester tester,
  String name, {
  Finder? boundaryFinder,
}) async {
  final dir = Platform.environment['HAW_PANES_CAPTURE_DIR'];
  if (dir == null) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    boundaryFinder ??
        find
            .descendant(
              of: find.byType(PagesTile),
              matching: find.byType(RepaintBoundary),
            )
            .first,
  );
  void repaint(RenderObject node) {
    node.markNeedsPaint();
    node.visitChildren(repaint);
  }

  repaint(boundary);
  await tester.pump();
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(dir).create(recursive: true);
    await File('$dir/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
