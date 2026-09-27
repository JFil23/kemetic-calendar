import 'package:mobile/features/calendar/the_kar/the_kar_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/data/commons_models.dart';
import 'package:mobile/data/commons_question_selection.dart';
import 'package:mobile/data/flow_appearance.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/fixtures/follow_sky_observation_presentation_fixture.dart';
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
          'question': '',
          'my_answer': {'id': answer.id, 'body_text': answer.bodyText},
        },
      ],
    });
    final q = activeCommonsQuestion(snapshot, date);
    expect(q.id, seed.id);
    expect(q.question, seed.text);
    expect(q.myAnswer?.bodyText, answer.bodyText);
  });
  testWidgets(
    'shared badge area renders actual tokens without preview controls taking taps',
    (tester) async {
      var taps = 0;
      const badge = EventBadgeToken(
        id: 'calendar:test',
        title: 'Actual badge',
        color: Colors.purple,
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
                  card: const PagesCard(
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
      expect(find.text('Actual badge'), findsOneWidget);
      await tester.tap(find.byType(EventBadgeWidget));
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    },
  );
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
    }
    await tester.pumpWidget(const SizedBox());
  });
}
