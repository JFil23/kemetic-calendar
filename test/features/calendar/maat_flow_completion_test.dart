import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('day view shows tri-state Ma_at completion for every Ma_at flow', () {
    final source = File(
      'lib/features/calendar/day_view.dart',
    ).readAsStringSync();

    expect(source, contains('class _MaatFlowCompletionPanel'));
    expect(source, contains('completionContext != null'));
    expect(source, contains("_statusButton('observed', 'Observed')"));
    expect(source, contains("_statusButton('observed_partly', 'Partly')"));
    expect(source, contains("_statusButton('skipped', 'Skipped')"));

    expect(source, contains("flowKey: kDawnHouseRiteFlowKey"));
    expect(source, contains("flowKey: kEveningThresholdRiteFlowKey"));
    expect(source, contains("flowKey: 'track-the-sky'"));
    expect(source, contains("flowKey: kTheWeighingFlowKey"));
    expect(source, contains("flowKey: kOfferingTableFlowKey"));
    expect(source, contains("flowKey: kTheTendingFlowKey"));
    expect(source, contains("flowKey: kKeptWordFlowKey"));
    expect(source, contains("flowKey: kTheCourseFlowKey"));
    expect(source, contains("flowKey: kMoonReturnFlowKey"));
    expect(source, contains("flowKey: kTheWagFlowKey"));
    expect(source, contains("flowKey: kDecanWatchFlowKey"));
    expect(source, contains("flowKey: kDaysOutsideTheYearFlowKey"));
    expect(source, contains("flowKey: kTheOpenHandFlowKey"));
    expect(source, contains("flowKey: kTheDjedFlowKey"));
    expect(source, contains('flowKey: maatDecanDefinition.key'));
    expect(source, contains('showPartly: false'));
    expect(source, contains("'conversation_pending': 'Conversation pending'"));
    expect(source, contains("'names_spoken': 'Names spoken'"));
    expect(source, contains("'observed_from_inside': 'Inside'"));
    expect(source, contains("'raised': 'Raised'"));
    expect(source, contains("'decision_pronounced'"));
    expect(source, contains("'transmitted'"));
    expect(source, contains("'stones_placed'"));
    expect(source, contains("'cooled'"));
    expect(source, contains("'spoken'"));
    expect(source, contains("'record_complete'"));
    expect(source, contains("'beer_poured'"));
    expect(source, contains("'golden_one_present'"));
  });

  test(
    'Ma_at completion metadata is graph-readable and refreshes the graph',
    () {
      final dayView = File(
        'lib/features/calendar/day_view.dart',
      ).readAsStringSync();
      final repo = File('lib/data/user_events_repo.dart').readAsStringSync();

      expect(dayView, contains("'knowledge_graph': <String, dynamic>"));
      expect(dayView, contains("'version': 'maat_flow_completion_v1'"));
      expect(dayView, contains("'node_slugs': graphNodeSlugs"));
      expect(repo, contains("'rebuild_personal_graph'"));
      expect(repo, contains('_isMaatFlowCompletionMetadata'));
    },
  );

  test(
    'The Course event detail opens the day card and tracks non-PII telemetry',
    () {
      final source = File(
        'lib/features/calendar/day_view.dart',
      ).readAsStringSync();

      expect(source, contains('class _TheCourseDayCardPanel'));
      expect(source, contains('KemeticDayButton'));
      expect(source, contains("event: 'day_card_opened_from_course'"));
      expect(source, contains("'event_number': event.eventNumber"));
      expect(source, isNot(contains("'note_text'")));
    },
  );

  test(
    'Decan Watch detail opens the day card and keeps sky notes local only',
    () {
      final source = File(
        'lib/features/calendar/day_view.dart',
      ).readAsStringSync();

      expect(source, contains('class _DecanWatchDayCardPanel'));
      expect(source, contains('class _DecanWatchLocalNotesPanel'));
      expect(source, contains('class _DecanWatchMilestonePanel'));
      expect(source, contains("event: 'day_card_opened_from_decan_watch'"));
      expect(source, contains('DecanWatchLocalStore'));
      expect(source, contains('decanWatchMilestoneMessage'));
      expect(source, isNot(contains("'sky_note':")));
    },
  );

  test('Days Outside detail keeps year threshold notes out of shares', () {
    final source = File(
      'lib/features/calendar/day_view.dart',
    ).readAsStringSync();

    expect(source, contains('class _DaysOutsideYearLocalNotesPanel'));
    expect(source, contains('DaysOutsideYearLocalStore'));
    expect(
      source,
      contains('Record the threshold note for this year-opening step.'),
    );
    expect(source, contains("shareButtonLabel: 'Share one word'"));
    expect(source, isNot(contains("'year_intention':")));
  });

  test(
    'Open Hand detail gates outward acts and keeps provision records local',
    () {
      final source = File(
        'lib/features/calendar/day_view.dart',
      ).readAsStringSync();

      expect(source, contains('class _OpenHandLocalNotesPanel'));
      expect(source, contains('TheOpenHandLocalStore'));
      expect(source, contains('I completed the outward act'));
      expect(source, contains("shareButtonLabel: 'Share continuing practice'"));
      expect(source, isNot(contains("'recipient_names':")));
      expect(source, isNot(contains("'giving_records':")));
    },
  );

  test('Djed detail gates raising and keeps spine records local', () {
    final source = File(
      'lib/features/calendar/day_view.dart',
    ).readAsStringSync();

    expect(source, contains('class _DjedLocalNotesPanel'));
    expect(source, contains('TheDjedLocalStore'));
    expect(
      source,
      contains('I stood upright and raised my arms for at least 30 seconds'),
    );
    expect(source, contains("'completion': 'raised'"));
    expect(source, contains("'raising_seconds': kDjedRaisingSeconds"));
    expect(source, contains("shareButtonLabel: 'Share what holds'"));
    expect(source, isNot(contains("'spine_labels':")));
    expect(source, isNot(contains("'battle_commitment':")));
  });
}
