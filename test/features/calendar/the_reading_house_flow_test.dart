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
      'shared_fragments': kReadingHouseSharedFragmentsPhaseEnabled,
    });
    final presence = payload['house_presence'] as Map<String, dynamic>;
    expect(presence['phase'], 'phase_3c');
    expect(
      presence['membership_source'],
      kReadingHouseMembershipSourceSharedCalendar,
    );
    expect(presence['state_source'], 'active_joined_member_count');
    expect(presence['company_threshold'], 2);
    expect(presence['factual_summary_only'], isTrue);
    expect(
      presence['shared_fragments'],
      kReadingHouseSharedFragmentsPhaseEnabled,
    );
    expect(presence['shared_fragment_unlock'], 'carrying_position_mark');
    expect(
      presence['fragment_replies'],
      kReadingHouseFragmentRepliesPhaseEnabled,
    );
    expect(presence['reply_depth'], 1);
    expect(presence['private_reader_text_shared'], isFalse);
    expect(payload['share_prompt_on_complete'], isFalse);
    expect(payload['share_prompt_future'], isFalse);

    final discussion = payload['discussion_model'] as Map<String, dynamic>;
    expect(discussion['phase'], 'fragment_replies');
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

  test('house state is derived from active joined members', () {
    expect(
      readingHouseHouseStateFor(soloStudy: true, activeJoinedMemberCount: 3),
      kReadingHouseHouseStateSolo,
    );
    expect(
      readingHouseHouseStateFor(soloStudy: false, activeJoinedMemberCount: 1),
      kReadingHouseHouseStateOpen,
    );
    expect(
      readingHouseHouseStateFor(soloStudy: false, activeJoinedMemberCount: 2),
      kReadingHouseHouseStateCompany,
    );

    expect(
      readingHouseFactualSummaryLines(
        houseState: kReadingHouseHouseStateOpen,
        activeJoinedMemberCount: 1,
        nextSittingLabel: 'Reading House 1',
      ),
      <String>[
        'House open · waiting for readers',
        'Next sitting: Reading House 1',
      ],
    );
    expect(
      readingHouseFactualSummaryLines(
        houseState: kReadingHouseHouseStateCompany,
        activeJoinedMemberCount: 2,
        carryingCount: 1,
      ),
      <String>['2 members joined', '1 reader Carrying'],
    );
  });

  test('public copy stays honest about the Phase 3C boundary', () {
    expect(kReadingHouseOverview, contains('host-authored private sittings'));
    expect(kReadingHouseOverview, contains('local private margin'));
    expect(kReadingHouseOverview, contains('Phase 3C one-level replies'));
    expect(
      kReadingHouseOverview,
      contains('accepted shared-calendar membership'),
    );
    expect(
      kReadingHouseOverview,
      contains(
        'private reflection and short-note text are never copied automatically',
      ),
    );
    expect(kReadingHouseEnrollmentCopy, contains('Phase 3C'));
    expect(kReadingHouseEnrollmentCopy, contains('one-level replies'));
    expect(kReadingHouseEnrollmentCopy, contains('writing stays optional'));
    final detail = readingHouseDetailText(
      kReadingHouseSittings.first,
      plan: const ReadingHousePlan(),
    );
    expect(detail, contains('Section\nOpening section'));
    expect(detail, contains('Theme\nWhat is the text asking you to carry?'));
    expect(detail, contains('Private prompt\nBefore company shapes'));
    expect(detail, contains('Host note\nBegin with your own encounter'));
    expect(detail, contains('Carrying opens opt-in shared fragments'));
    expect(detail, contains('House presence'));
    expect(detail, contains('Shared fragments are chosen by the reader'));
    expect(detail, contains('Fragment replies'));
    expect(
      detail,
      contains('No likes, ranking, discussion room, or chat is active'),
    );
  });

  test(
    'payload enables fragment replies but not broader conversation surfaces',
    () {
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
      final presence = payload['house_presence'] as Map<String, dynamic>;
      expect(presence['member_list'], 'enabled');
      expect(presence['invite_join'], 'shared_calendar_invite');
      expect(
        presence['shared_fragments'],
        kReadingHouseSharedFragmentsPhaseEnabled,
      );
      expect(presence['shared_fragment_scope'], 'house_sitting');
      expect(presence['fragment_replies'], 'enabled');
      expect(presence['reply_depth'], 1);
      expect(presence['replies'], 'enabled');
      expect(presence['discussion'], 'future');
      expect(presence['house_chat'], 'future');
      expect(presence['global_commons_share'], isFalse);
      final discussion = payload['discussion_model'] as Map<String, dynamic>;
      expect(discussion['phase'], 'fragment_replies');
      expect(discussion['reply_depth'], 1);
      expect(discussion['likes'], isFalse);
      expect(discussion['ranking'], isFalse);
      expect(discussion['discussion_room'], isFalse);
      expect(discussion['house_chat'], 'future');
    },
  );

  test('Phase 3B fragment helpers require Carrying and stay factual', () {
    expect(
      readingHouseSharedFragmentUnlockPosition(kReadingHousePositionCarrying),
      kReadingHousePositionCarrying,
    );
    expect(
      readingHouseSharedFragmentUnlockPosition(kReadingHousePositionNotYet),
      isNull,
    );
    expect(
      readingHouseSharedFragmentCountSummary(0),
      '0 fragments shared for this sitting',
    );
    expect(
      readingHouseSharedFragmentCountSummary(1),
      '1 fragment shared for this sitting',
    );
    expect(
      readingHouseSharedFragmentCountSummary(2),
      '2 fragments shared for this sitting',
    );
  });

  test('Phase 3C shared fragment UI keeps replies one-level only', () {
    final dayViewSource = File(
      'lib/features/calendar/day_view.dart',
    ).readAsStringSync();
    final repoSource = File(
      'lib/features/calendar/reading_house_shared_fragments_repo.dart',
    ).readAsStringSync();

    final fragmentSection = _sourceBetween(
      dayViewSource,
      'Widget? _buildReadingHouseSharedFragmentsSection()',
      '  Widget? _buildCompletionLeadingContent',
    );
    expect(fragmentSection, contains('readingHouseSharedFragmentCountSummary'));
    expect(fragmentSection, contains('_readingHouseFragmentsUnlocked'));

    final composer = _sourceBetween(
      dayViewSource,
      'Widget _buildReadingHouseFragmentComposer',
      '  Widget _buildReadingHouseFragmentList',
    );
    expect(composer, contains('Bring a fragment to the house'));
    expect(composer, contains('Your private reflection stays private.'));
    expect(composer, contains('_readingHouseFragmentBodyController'));
    expect(composer, contains('_shareReadingHouseFragment()'));
    expect(composer, isNot(contains('Like')));
    expect(composer, isNot(contains('Chat')));

    final replies = _sourceBetween(
      dayViewSource,
      'Widget _buildReadingHouseReplies',
      '  Widget? _buildReadingHouseSharedFragmentsSection',
    );
    expect(replies, contains('Reply to fragment'));
    expect(replies, contains('Acknowledge fragment'));
    expect(replies, contains('Replies stay inside this house fragment.'));
    expect(replies, contains('_createReadingHouseReply(fragment)'));
    expect(replies, contains('_deleteReadingHouseReply(reply)'));
    expect(replies, isNot(contains('parentReply')));
    expect(replies, isNot(contains('nested')));
    expect(replies, isNot(contains('Like')));
    expect(replies, isNot(contains('Chat')));
    expect(replies, isNot(contains('Discussion')));

    expect(repoSource, contains('shareFragment'));
    expect(repoSource, contains('createReply'));
    expect(repoSource, contains('deleteReply'));
    expect(repoSource, contains('ReadingHouseFragmentReply'));
    expect(repoSource, contains('readingHouseSharedFragmentUnlockPosition'));
    expect(repoSource, contains('Choose Carrying before sharing a fragment.'));
    expect(repoSource, isNot(contains('privateReflection')));
    expect(repoSource, isNot(contains('shortNote')));
  });

  test('Phase 3B shared fragment RLS gates house membership and Carrying', () {
    final migration = File(
      '../supabase/migrations/20260625170000_reading_house_shared_fragments.sql',
    ).readAsStringSync();

    expect(migration, contains('reading_house_shared_fragments'));
    expect(migration, contains('reading_house_sitting_positions'));
    expect(migration, contains('reading_house_is_calendar_member'));
    expect(migration, contains('reading_house_can_moderate_calendar'));
    expect(migration, contains('reading_house_fragment_event_exists'));
    expect(migration, contains('reading_house_has_fragment_unlock'));
    expect(migration, contains("rhsp.reading_position = 'carrying'"));
    expect(
      migration,
      contains("uec.metadata ->> 'reading_position' = 'carrying'"),
    );
    expect(
      migration,
      contains('reading_house_shared_fragments_select_members_unlocked'),
    );
    expect(
      migration,
      contains('reading_house_shared_fragments_insert_author_unlocked'),
    );
    expect(migration, contains('author_id = auth.uid()'));
    expect(migration, contains('deleted_at is null'));
    expect(migration, contains('delete_reading_house_shared_fragment'));
    expect(migration, contains('FRAGMENT_NOT_EDITABLE'));
    expect(migration, isNot(contains('reply')));
    expect(migration, isNot(contains('likes')));
    expect(migration, isNot(contains('ranking')));
  });

  test('Phase 3C reply RLS keeps replies scoped to parent fragments', () {
    final migration = File(
      '../supabase/migrations/20260625203000_reading_house_fragment_replies.sql',
    ).readAsStringSync();

    expect(migration, contains('reading_house_fragment_replies'));
    expect(migration, contains('fragment_id uuid not null'));
    expect(
      migration,
      contains('references public.reading_house_shared_fragments'),
    );
    expect(migration, isNot(contains('parent_reply_id')));
    expect(migration, contains('is_host_ack boolean not null default false'));
    expect(migration, contains('reading_house_can_read_fragment'));
    expect(
      migration,
      contains('reading_house_fragment_replies_select_parent_visible'),
    );
    expect(migration, contains('create_reading_house_fragment_reply'));
    expect(migration, contains('delete_reading_house_fragment_reply'));
    expect(migration, contains('FRAGMENT_NOT_ACCESSIBLE'));
    expect(migration, contains('ACK_NOT_ALLOWED'));
    expect(migration, contains('REPLY_NOT_EDITABLE'));
    expect(migration, contains('v_reply.author_id <> v_uid'));
    expect(migration, contains('reading_house_can_moderate_calendar'));
    expect(
      migration,
      contains('grant select on public.reading_house_fragment_replies'),
    );
    expect(migration, isNot(contains('likes')));
    expect(migration, isNot(contains('reaction')));
    expect(migration, isNot(contains('ranking')));
    expect(migration, isNot(contains('commons')));
  });

  test('Phase 3A authoring reuses shared-calendar membership', () {
    final authoringSource = File(
      'lib/features/calendar/reading_house_authoring_page.dart',
    ).readAsStringSync();
    final calendarPageSource = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();

    expect(authoringSource, contains('listMembers('));
    expect(authoringSource, contains('inviteUser('));
    expect(authoringSource, contains('SharedCalendarRole.viewer'));
    expect(authoringSource, contains('CalendarMembersSheet.show'));
    expect(authoringSource, contains('readingHouseFactualSummaryLines'));
    expect(authoringSource, contains('readingHouseHouseStateFor'));
    expect(calendarPageSource, contains('_moveReadingHouseFlowToCalendar'));
    expect(calendarPageSource, contains('updateCalendarForFlowEvents'));

    final panel = _sourceBetween(
      authoringSource,
      'Widget _buildHousePresencePanel()',
      '  @override',
    );
    expect(panel, contains('Open on shared calendar'));
    expect(panel, contains('Invite reader'));
    expect(panel, contains('Members'));
    expect(
      panel,
      contains(
        'private reflections, notes, and local margin text stay private',
      ),
    );
    for (final forbidden in <String>[
      'Share fragment',
      'Reply',
      'Like',
      'House Chat',
      'Discussion',
      'Leader',
    ]) {
      expect(panel, isNot(contains(forbidden)));
    }
  });

  test('Reading House edit routes open the authoring surface', () {
    final calendarPageSource = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();

    final detachedRoute = _sourceBetween(
      calendarPageSource,
      'class _FlowEditorRoutePageState',
      'class CalendarPageState',
    );
    expect(detachedRoute, contains('_loadReadingHouseRouteFlow'));
    expect(detachedRoute, contains('getFlowById(widget.flowId)'));
    expect(
      detachedRoute,
      contains('resolveMaatFlowKind(flowNotes: flow.notes)'),
    );
    expect(detachedRoute, contains('isReadingHouseFlowReference('));
    expect(detachedRoute, contains('_buildReadingHouseAuthoringPage'));
    expect(detachedRoute, contains('_ReadingHouseAuthoringPage('));
    expect(detachedRoute, contains('onSave: _handleResult'));
    expect(detachedRoute, contains('_buildGenericFlowEditor'));

    final detachedGeneric = _sourceBetween(
      detachedRoute,
      'Widget _buildGenericFlowEditor()',
      '  Widget _buildReadingHouseAuthoringPage',
    );
    expect(detachedGeneric, contains('_FlowStudioPage('));
    expect(detachedGeneric, contains('editFlowId: widget.flowId'));

    final myFlowsEdit = _sourceBetween(
      calendarPageSource,
      'Future<_FlowStudioResult?> _pushFlowStudioEditor',
      '  _Flow? _readingHouseFlowForEditor',
    );
    expect(myFlowsEdit, contains('_ReadingHouseAuthoringPage('));
    expect(myFlowsEdit, contains('_moveReadingHouseFlowToCalendar'));
    expect(myFlowsEdit, contains('_FlowStudioPage('));

    final directEdit = _sourceBetween(
      calendarPageSource,
      'void _openFlowEditorDirectly',
      '  void _openFlowsViewer',
    );
    expect(directEdit, contains('_ReadingHouseAuthoringPage('));
    expect(directEdit, contains('_moveReadingHouseFlowToCalendar'));
    expect(directEdit, contains('_FlowStudioPage('));
  });

  test('joined readers keep Reading House flow context in Day View', () {
    final calendarPageSource = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();

    final sharedOpen = _sourceBetween(
      calendarPageSource,
      'static Future<void> openFiledCalendarEventFromAnyContext',
      '  static Future<void> openMyFlowsFromAnyContext',
    );
    expect(sharedOpen, contains('_loadSharedCalendarFlowsForFiledEvents'));
    expect(sharedOpen, contains('mountedHost._seedSharedCalendarFlows'));
    expect(sharedOpen, contains('sharedCalendarFlows: sharedCalendarFlows'));

    final flowHydration = _sourceBetween(
      calendarPageSource,
      'static Future<List<_Flow>> _loadSharedCalendarFlowsForFiledEvents',
      '  static int? _firstVisibleMinuteFromSharedCalendarSnapshot',
    );
    expect(flowHydration, contains('_positiveFiledFlowId'));
    expect(flowHydration, contains('getFlowById(flowId)'));
    expect(flowHydration, contains('_flowFromFiledRowDetached(row)'));

    final pendingIntent = _sourceBetween(
      calendarPageSource,
      'class _SharedCalendarRealDayViewIntent',
      'class _CalendarWarmStateSnapshot',
    );
    expect(pendingIntent, contains('final List<_Flow> sharedCalendarFlows'));

    final consumeIntent = _sourceBetween(
      calendarPageSource,
      'bool _consumePendingSharedCalendarRealDayViewIntentIfAny()',
      '  Future<void> _requestInitialStartupRun',
    );
    expect(
      consumeIntent,
      contains('_seedSharedCalendarFlows(intent.sharedCalendarFlows)'),
    );
  });

  test('Phase 3A viewer role cannot author sittings', () {
    final authoringSource = File(
      'lib/features/calendar/reading_house_authoring_page.dart',
    ).readAsStringSync();

    final authoringGate = _sourceBetween(
      authoringSource,
      'bool get _canAuthorSittings',
      '  String? get _nextSittingLabel',
    );
    expect(authoringGate, contains('calendar.canEdit'));
    expect(authoringGate, contains('View-only members can read the plan'));

    for (final methodStart in <String>[
      'Future<void> _editSitting',
      'void _addSitting',
      'void _deleteSitting',
      'void _moveSitting',
      'Future<void> _save',
    ]) {
      final method = _sourceBetween(
        authoringSource,
        methodStart,
        methodStart == 'Future<void> _save'
            ? '  Widget _sittingTile'
            : _nextAuthoringMethodBoundary(methodStart),
      );
      expect(method, contains('!_canAuthorSittings'));
      expect(method, contains('_showAuthoringLockedMessage'));
    }

    final tile = _sourceBetween(
      authoringSource,
      'Widget _sittingTile',
      '  Widget _buildMemberPreview',
    );
    expect(tile, contains('if (_canAuthorSittings)'));
    expect(tile, contains('Edit sitting'));
    expect(tile, contains('Delete sitting'));
    expect(tile, contains('View only · hosts and calendar editors'));

    final build = _sourceBetween(
      authoringSource,
      'Widget build(BuildContext context)',
      'class _ReadingHouseSittingDraftSheet',
    );
    expect(build, contains('if (_canAuthorSittings)'));
    expect(build, contains('Add Sitting'));
    expect(build, contains('Save'));
    expect(build, contains('Read the shared sitting plan'));
  });

  test('Phase 3A privacy uses shared-calendar RLS conventions', () {
    final schema = File('../db/schema.sql').readAsStringSync();
    final listMembers = _sourceBetween(
      schema,
      'CREATE OR REPLACE FUNCTION "public"."list_shared_calendar_members"',
      'ALTER FUNCTION "public"."list_shared_calendar_members"',
    );
    expect(listMembers, contains('v_actor_id uuid := auth.uid()'));
    expect(listMembers, contains("scm.status = 'accepted'"));
    expect(listMembers, contains('CALENDAR_NOT_ACCESSIBLE'));
    expect(listMembers, contains("or (v_is_owner and scm.status = 'pending')"));

    final invite = _sourceBetween(
      schema,
      'CREATE OR REPLACE FUNCTION "public"."invite_user_to_shared_calendar"',
      'ALTER FUNCTION "public"."invite_user_to_shared_calendar"',
    );
    expect(invite, contains("scm.status = 'accepted'"));
    expect(invite, contains("scm.role = 'owner'"));
    expect(invite, contains('CALENDAR_NOT_INVITABLE'));
    expect(invite, contains("v_role not in ('editor', 'viewer')"));

    final filingView = _sourceBetween(
      schema,
      'CREATE OR REPLACE VIEW "public"."shared_calendar_filing_items_client"',
      'ALTER VIEW "public"."shared_calendar_filing_items_client"',
    );
    expect(filingView, contains('"scm"."user_id" = "auth"."uid"()'));
    expect(filingView, contains('"scm"."status" = \'accepted\'::"text"'));
    expect(filingView, contains('"sc"."deleted_at" IS NULL'));

    final memberPolicy = _sourceBetween(
      schema,
      'CREATE POLICY "shared_calendar_members_select_visible"',
      'ALTER TABLE "public"."shared_calendar_notifications"',
    );
    expect(memberPolicy, contains('"user_id" = "auth"."uid"()'));
    expect(memberPolicy, contains('can_view_shared_calendar_member_row'));
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

String _nextAuthoringMethodBoundary(String methodStart) {
  switch (methodStart) {
    case 'Future<void> _editSitting':
      return '  void _addSitting';
    case 'void _addSitting':
      return '  void _deleteSitting';
    case 'void _deleteSitting':
      return '  void _moveSitting';
    case 'void _moveSitting':
      return '  Future<void> _save';
    default:
      return '  Widget _sittingTile';
  }
}
