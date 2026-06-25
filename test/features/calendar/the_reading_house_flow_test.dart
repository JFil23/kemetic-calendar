import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/the_reading_house_flow.dart';
import 'package:mobile/features/calendar/track_sky_flow.dart';

void main() {
  test('Reading House has three starter sittings on the MVP rhythm', () {
    expect(kReadingHouseSittings, hasLength(3));
    expect(kReadingHouseSittings.map((sitting) => sitting.flowDay), <int>[
      1,
      7,
      14,
    ]);
    expect(kReadingHouseSittings.first.title, 'Open the Text');
    expect(kReadingHouseSittings.last.sharePromptOnComplete, isTrue);
  });

  test('schedule uses a fixed editable evening hour', () {
    final schedule = readingHouseScheduleForDate(
      kReadingHouseSittings.first,
      DateTime(2026, 6, 1),
      TrackSkyTimeZone.pacific,
    );

    expect(schedule.scheduleType, 'fixed_local_evening');
    expect(schedule.fallback, 'user_editable_local_time');
    expect(schedule.startLocal, DateTime(2026, 6, 1, 19));
    expect(schedule.endLocal, DateTime(2026, 6, 1, 20));
    expect(
      schedule.endUtc.difference(schedule.startUtc),
      const Duration(hours: 1),
    );
  });

  test('default start date advances after the evening sitting passes', () {
    expect(
      defaultReadingHouseStartDate(
        TrackSkyTimeZone.pacific,
        now: DateTime.utc(2026, 6, 2, 1, 30),
      ),
      DateTime(2026, 6, 1),
    );
    expect(
      defaultReadingHouseStartDate(
        TrackSkyTimeZone.pacific,
        now: DateTime.utc(2026, 6, 2, 3),
      ),
      DateTime(2026, 6, 2),
    );
  });

  test('payload preserves private-first book-club constraints', () {
    const plan = ReadingHousePlan(
      bookTitle: 'The Book of Gates',
      editionNote: 'Host packet, 2026',
      houseQuestion: 'What threshold is this text asking us to cross?',
      mode: kReadingHouseDefaultMode,
    );
    final sitting = kReadingHouseSittings.last;
    final payload = readingHouseBehaviorPayload(
      sitting: sitting,
      schedule: readingHouseScheduleForDate(
        sitting,
        DateTime(2026, 6, 14),
        TrackSkyTimeZone.eastern,
      ),
      plan: plan,
    );

    expect(payload['kind'], 'maat_reading_house_sitting');
    expect(payload['flow_key'], kReadingHouseFlowKey);
    expect(payload['sitting_title'], 'Seal the Reading');
    expect(payload['section'], 'Closing section');
    expect(payload['theme'], 'What fragment should the house keep?');
    expect(payload['private_prompt'], contains('Mark what remains'));
    expect(payload['host_note'], contains('Only share a fragment'));
    expect(payload['sitting_source'], 'starter_default');
    expect(payload['host_editable'], isFalse);
    expect(payload['host_authoring_phase'], 'future');
    expect(payload['book_title'], 'The Book of Gates');
    expect(payload['private_first'], isTrue);
    expect(payload['writing_required'], isFalse);
    expect(payload['unlock_gate'], 'reading_position_mark');
    expect(payload['completion_options'], <String>[
      'observed',
      'observed_partly',
      'skipped',
    ]);
    expect(payload['presence_options'], <String>['carrying', 'not_yet']);
    expect(payload['share_prompt_on_complete'], isTrue);

    final discussion = payload['discussion_model'] as Map<String, dynamic>;
    expect(discussion['phase'], 'future');
    expect(discussion['reply_depth'], 1);
    expect(discussion['likes'], isFalse);
    expect(discussion['ranking'], isFalse);

    final schedule = payload['schedule'] as Map<String, dynamic>;
    expect(schedule['timezone'], TrackSkyTimeZone.eastern.key);
    expect(schedule['hour'], kReadingHouseDefaultHour);
  });

  test('flow notes and payload restore canonical event details', () {
    const plan = ReadingHousePlan(
      bookTitle: 'A Season of Study',
      editionNote: 'Second edition',
      houseQuestion: 'What should the house keep?',
      mode: kReadingHouseSoloMode,
    );
    final notes = <String>[
      'mode=gregorian',
      'maat=$kReadingHouseFlowKey',
      ...readingHouseFlowNoteTokens(plan),
    ].join(';');
    final parsed = readingHousePlanFromFlowNotes(notes);

    expect(parsed.displayBookTitle, 'A Season of Study');
    expect(parsed.editionNote, 'Second edition');
    expect(parsed.displayQuestion, 'What should the house keep?');
    expect(parsed.normalizedMode, kReadingHouseSoloMode);

    final sitting = kReadingHouseSittings.first;
    final detail = canonicalReadingHouseDetailTextForEvent(
      flowNotes: notes,
      title: readingHouseSittingTitle(sitting),
      behaviorPayload: readingHouseBehaviorPayload(
        sitting: sitting,
        schedule: readingHouseScheduleForDate(
          sitting,
          DateTime(2026, 6),
          TrackSkyTimeZone.central,
        ),
        plan: plan,
      ),
    );

    expect(detail, isNotNull);
    expect(detail, contains('Book\nA Season of Study'));
    expect(detail, contains('Edition: Second edition'));
    expect(detail, contains('House question\nWhat should the house keep?'));
    expect(detail, contains('Position gate'));
  });

  test('sitting resolver accepts persisted payload snapshots', () {
    final sitting = readingHouseSittingForEvent(
      behaviorPayload: const <String, dynamic>{
        'event_number': 2,
        'flow_day': 9,
        'sitting_title': 'Cross the Middle',
        'section': 'Chapters 4-8',
        'theme': 'Where did the book resist you?',
        'private_prompt': 'Sit first, then mark the page.',
        'host_note': 'Bring only one page marker later.',
        'share_prompt_on_complete': true,
      },
    );

    expect(sitting, isNotNull);
    expect(sitting!.eventNumber, 2);
    expect(sitting.flowDay, 9);
    expect(sitting.title, 'Cross the Middle');
    expect(sitting.section, 'Chapters 4-8');
    expect(sitting.theme, 'Where did the book resist you?');
    expect(sitting.privatePrompt, 'Sit first, then mark the page.');
    expect(sitting.hostNote, 'Bring only one page marker later.');
    expect(sitting.sharePromptOnComplete, isTrue);
  });

  test('sitting resolver still accepts action ids and titles', () {
    expect(
      readingHouseSittingForEvent(
        actionId: readingHouseActionId(kReadingHouseSittings.last),
      )?.eventNumber,
      3,
    );
    expect(
      readingHouseSittingForEvent(
        title: 'Reading House 1: Open the Text',
      )?.eventNumber,
      1,
    );
  });

  test('public copy stays honest about the Phase 1A boundary', () {
    expect(kReadingHouseOverview, contains('Phase 1A'));
    expect(kReadingHouseOverview, contains('not yet a book-club engine'));
    expect(kReadingHouseEnrollmentCopy, contains('intent only'));
    expect(kReadingHouseEnrollmentCopy, contains('not live yet'));
    expect(
      readingHouseDetailText(
        kReadingHouseSittings.first,
        plan: const ReadingHousePlan(),
      ),
      contains('private reading position only'),
    );
  });
}
