import 'dart:io';

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
    expect(kReadingHouseSittings.last.sharePromptOnComplete, isFalse);
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

  test('timezone reconstruction uses the Reading House timezone', () {
    final local = readingHouseLocalDateTimeForUtc(
      DateTime.utc(2026, 1, 1, 2, 30),
      TrackSkyTimeZone.pacific,
    );

    expect(local, DateTime(2025, 12, 31, 18, 30));
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
    expect(payload['host_note'], contains('Shared surfaces come later'));
    expect(payload['sitting_source'], 'starter_default');
    expect(payload['host_editable'], isFalse);
    expect(payload['host_authoring_phase'], 'future');
    expect(payload['book_title'], 'The Book of Gates');
    expect(payload['private_first'], isTrue);
    expect(payload['reader_sitting_phase'], 'enabled');
    expect(payload['writing_required'], isFalse);
    expect(payload['unlock_gate'], 'reading_position_mark');
    expect(payload['completion_options'], <String>[
      'observed',
      'observed_partly',
      'skipped',
    ]);
    expect(payload['presence_options'], <String>['carrying', 'not_yet']);
    expect(payload['private_margin'], <String, dynamic>{
      'phase': 'enabled',
      'storage': 'local_only',
      'shared_fragments': 'future',
    });
    expect(payload['share_prompt_on_complete'], isFalse);
    expect(payload['share_prompt_future'], isFalse);

    final discussion = payload['discussion_model'] as Map<String, dynamic>;
    expect(discussion['phase'], 'future');
    expect(discussion['reply_depth'], 1);
    expect(discussion['likes'], isFalse);
    expect(discussion['ranking'], isFalse);

    final schedule = payload['schedule'] as Map<String, dynamic>;
    expect(schedule['timezone'], TrackSkyTimeZone.eastern.key);
    expect(schedule['hour'], kReadingHouseDefaultHour);
  });

  test(
    'host edits flip sitting metadata without rewriting untouched defaults',
    () {
      final edited = editReadingHouseSitting(
        readingHouseStarterSittingsForAuthoring(),
        1,
        kReadingHouseSittings.first.copyWith(
          title: 'Chapters 1-3',
          section: 'Pages 1-42',
          theme: 'Where does the book begin?',
          privatePrompt: 'Mark one private line before discussion exists.',
          hostNote: 'Bring the paperback.',
          scheduledDate: DateTime(2026, 6, 9),
          flowDay: 4,
          hour: 20,
          minute: 15,
        ),
      );

      expect(edited, hasLength(3));
      expect(edited.first.title, 'Chapters 1-3');
      expect(
        edited.first.sittingSource,
        kReadingHouseSittingSourceHostAuthored,
      );
      expect(edited.first.hostEditable, isTrue);
      expect(
        edited.first.hostAuthoringPhase,
        kReadingHouseHostAuthoringPhaseEnabled,
      );
      expect(edited.first.scheduledDate, DateTime(2026, 6, 9));
      expect(edited.first.hour, 20);
      expect(edited.first.minute, 15);
      expect(edited[1].sittingSource, kReadingHouseSittingSourceStarterDefault);
    },
  );

  test('host can add, reorder, and delete sittings', () {
    final withAdded = addReadingHouseSitting(
      readingHouseStarterSittingsForAuthoring(),
    );
    expect(withAdded, hasLength(4));
    expect(withAdded.last.eventNumber, 4);
    expect(withAdded.last.flowDay, 21);
    expect(
      withAdded.last.sittingSource,
      kReadingHouseSittingSourceHostAuthored,
    );

    final reordered = reorderReadingHouseSitting(withAdded, 3, 0);
    expect(reordered.first.title, 'New Sitting');
    expect(reordered.map((sitting) => sitting.eventNumber), <int>[1, 2, 3, 4]);
    expect(
      reordered.every(
        (sitting) =>
            sitting.sittingSource == kReadingHouseSittingSourceHostAuthored,
      ),
      isTrue,
    );

    final deleted = deleteReadingHouseSitting(reordered, 2);
    expect(deleted, hasLength(3));
    expect(deleted.map((sitting) => sitting.eventNumber), <int>[1, 2, 3]);
    expect(
      deleted.every(
        (sitting) =>
            sitting.hostAuthoringPhase ==
            kReadingHouseHostAuthoringPhaseEnabled,
      ),
      isTrue,
    );
  });

  test('host-authored payloads carry enabled authoring metadata', () {
    const plan = ReadingHousePlan(bookTitle: 'The Host Book');
    final sitting = kReadingHouseSittings.first
        .copyWith(
          title: 'Read the Opening',
          scheduledDate: DateTime(2026, 6, 20),
          flowDay: 5,
          hour: 18,
          minute: 30,
        )
        .asHostAuthored();
    final schedule = readingHouseScheduleForSitting(
      sitting,
      DateTime(2026, 6, 16),
      TrackSkyTimeZone.pacific,
    );
    final payload = readingHouseBehaviorPayload(
      sitting: sitting,
      schedule: schedule,
      plan: plan,
    );

    expect(payload['sitting_source'], kReadingHouseSittingSourceHostAuthored);
    expect(payload['host_editable'], isTrue);
    expect(
      payload['host_authoring_phase'],
      kReadingHouseHostAuthoringPhaseEnabled,
    );
    expect(payload['scheduled_local_date'], '2026-06-20');
    expect(payload['share_prompt_on_complete'], isFalse);
    final schedulePayload = payload['schedule'] as Map<String, dynamic>;
    expect(schedulePayload['local_date'], '2026-06-20');
    expect(schedulePayload['hour'], 18);
    expect(schedulePayload['minute'], 30);
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

  test('sitting resolver accepts added host-authored payload snapshots', () {
    final sitting = readingHouseSittingForEvent(
      behaviorPayload: const <String, dynamic>{
        'event_number': 4,
        'flow_day': 21,
        'sitting_title': 'Carry Forward',
        'section': 'Appendix',
        'theme': 'What remains usable?',
        'private_prompt': 'Name the practice that survives the book.',
        'host_note': 'Optional closing note.',
        'sitting_source': kReadingHouseSittingSourceHostAuthored,
        'host_editable': true,
        'host_authoring_phase': kReadingHouseHostAuthoringPhaseEnabled,
        'scheduled_local_date': '2026-07-09',
        'schedule': <String, dynamic>{'hour': 19, 'minute': 45},
      },
    );

    expect(sitting, isNotNull);
    expect(sitting!.eventNumber, 4);
    expect(sitting.title, 'Carry Forward');
    expect(sitting.scheduledDate, DateTime(2026, 7, 9));
    expect(sitting.hour, 19);
    expect(sitting.minute, 45);
    expect(sitting.sittingSource, kReadingHouseSittingSourceHostAuthored);
    expect(sitting.hostEditable, isTrue);
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

  test('public copy stays honest about the Phase 2 boundary', () {
    expect(kReadingHouseOverview, contains('host-authored private sittings'));
    expect(kReadingHouseOverview, contains('local private margin'));
    expect(kReadingHouseOverview, contains('Shared fragments'));
    expect(kReadingHouseEnrollmentCopy, contains('Phase 2'));
    expect(kReadingHouseEnrollmentCopy, contains('intent only'));
    expect(kReadingHouseEnrollmentCopy, contains('writing stays optional'));
    final detail = readingHouseDetailText(
      kReadingHouseSittings.first,
      plan: const ReadingHousePlan(),
    );
    expect(detail, contains('Section\nOpening section'));
    expect(detail, contains('Theme\nWhat is the text asking you to carry?'));
    expect(detail, contains('Private prompt\nBefore company shapes'));
    expect(detail, contains('Host note\nBegin with your own encounter'));
    expect(detail, contains('private reading position only'));
  });

  test('payload does not enable social/company surfaces in Phase 2', () {
    final payload = readingHouseBehaviorPayload(
      sitting: kReadingHouseSittings.first.asHostAuthored(),
      schedule: readingHouseScheduleForDate(
        kReadingHouseSittings.first,
        DateTime(2026, 6),
        TrackSkyTimeZone.pacific,
      ),
      plan: const ReadingHousePlan(mode: kReadingHouseDefaultMode),
    );

    expect(payload.containsKey('company_room_id'), isFalse);
    expect(payload.containsKey('discussion_thread_id'), isFalse);
    expect(payload.containsKey('house_chat_id'), isFalse);
    expect(payload.containsKey('global_commons_share'), isFalse);
    final discussion = payload['discussion_model'] as Map<String, dynamic>;
    expect(discussion['phase'], 'future');
    expect(discussion['likes'], isFalse);
    expect(discussion['ranking'], isFalse);
  });

  test('authoring edit sheet keeps text entry local until Save', () {
    final authoringSource = File(
      'lib/features/calendar/reading_house_authoring_page.dart',
    ).readAsStringSync();
    final setupSource = File(
      'lib/features/calendar/calendar_maat_flows.dart',
    ).readAsStringSync();

    final directEdit = _sourceBetween(
      authoringSource,
      'Future<void> _editSitting',
      '  void _addSitting',
    );
    expect(directEdit, contains('_ReadingHouseSittingDraftSheet'));
    expect(directEdit, isNot(contains('TextEditingController')));
    expect(directEdit, isNot(contains('StatefulBuilder')));

    final setupEdit = _sourceBetween(
      setupSource,
      'Future<void> _editReadingHouseSitting',
      '  void _addReadingHouseSitting',
    );
    expect(setupEdit, contains('_ReadingHouseSittingDraftSheet'));
    expect(setupEdit, isNot(contains('TextEditingController')));
    expect(setupEdit, isNot(contains('StatefulBuilder')));

    final draftSheet = _sourceBetween(
      authoringSource,
      'class _ReadingHouseSittingDraftSheet',
      'String? _readingHouseFlowNoteToken',
    );
    expect(draftSheet, contains('late final TextEditingController _titleCtrl'));
    expect(draftSheet, contains('void dispose()'));
    expect(draftSheet, contains('ReadingHouseSitting _draftSitting()'));
    expect(draftSheet, contains('Navigator.of(context).pop(_draftSitting())'));
    expect(draftSheet, isNot(contains('onChanged:')));
    expect(
      draftSheet.indexOf('TextEditingController(text: sitting.title)'),
      lessThan(draftSheet.indexOf('Widget build')),
    );
  });
}

String _sourceBetween(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  expect(startIndex, isNonNegative, reason: 'Missing source start: $start');
  final endIndex = source.indexOf(end, startIndex);
  expect(endIndex, isNonNegative, reason: 'Missing source end: $end');
  return source.substring(startIndex, endIndex);
}
