import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/completion_status.dart';
import 'package:mobile/features/calendar/calendar_page.dart' show KemeticMath;
import 'package:mobile/features/calendar/dawn_house_rite_flow.dart';
import 'package:mobile/features/calendar/day_view.dart';
import 'package:mobile/features/calendar/evening_threshold_rite_flow.dart';
import 'package:mobile/features/calendar/maat_decan_flow.dart';
import 'package:mobile/features/calendar/maat_flow_interactive_primitives.dart';
import 'package:mobile/features/calendar/maat_flow_response_journal_blocks.dart';
import 'package:mobile/features/calendar/moon_return_flow.dart';
import 'package:mobile/features/calendar/the_days_outside_year_flow.dart';
import 'package:mobile/features/calendar/the_course_flow.dart';
import 'package:mobile/features/calendar/the_decan_watch_flow.dart';
import 'package:mobile/features/calendar/the_decan_watch_local_store.dart';
import 'package:mobile/features/calendar/the_djed_flow.dart';
import 'package:mobile/features/calendar/the_kept_word_flow.dart';
import 'package:mobile/features/calendar/the_kept_word_local_store.dart';
import 'package:mobile/features/calendar/the_offering_table_flow.dart';
import 'package:mobile/features/calendar/the_open_hand_flow.dart';
import 'package:mobile/features/calendar/the_tending_flow.dart';
import 'package:mobile/features/calendar/the_tending_local_store.dart';
import 'package:mobile/features/calendar/the_wag_flow.dart';
import 'package:mobile/features/calendar/the_wag_local_store.dart';
import 'package:mobile/features/calendar/the_weighing_flow.dart';
import 'package:mobile/features/calendar/track_sky_flow.dart';
import 'package:mobile/features/journal/journal_badge_utils.dart';
import 'package:mobile/features/journal/journal_v2_document_model.dart';
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

  testWidgets('Moon Return response renders and previews journal text', (
    tester,
  ) async {
    await _setPhoneViewport(tester);

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _moonReturnFlowIndex,
        notes: <NoteData>[_moonReturnNote(kind: MoonReturnEventKind.emptyEye)],
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, MoonReturnEventKind.emptyEye.title);

    expect(find.byKey(kMaatFlowResponseSectionKey), findsOneWidget);
    expect(find.text('What do you set down?'), findsOneWidget);
    expect(find.text('What has filled?'), findsNothing);

    await _enterPilotResponse(
      tester,
      specId: 'moon-return-set-down',
      text: 'Lay down the old burden.',
    );

    expect(find.byKey(kMaatFlowResponseJournalPreviewKey), findsOneWidget);
    expect(find.text('Moon Return: Lay down the old burden.'), findsOneWidget);
  });

  testWidgets('Moon Return completion writes response body beside badges', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    var document = _journalDocument('User text before the response.');
    final badgeAppends = <String>[];
    final recorded = <CompletionStatus>[];

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _moonReturnFlowIndex,
        notes: <NoteData>[_moonReturnNote(kind: MoonReturnEventKind.emptyEye)],
        onAppendToJournal: (text) async => badgeAppends.add(text),
        onWriteJournalResponse: (block) async {
          document = MaatJournalResponseBlockUtils.upsert(document, block);
        },
        onRecordCompletion:
            ({
              required String clientEventId,
              required int flowId,
              required DateTime completedOnDate,
              Map<String, dynamic>? metadata,
            }) async {
              recorded.add(
                CompletionStatusX.fromWireName(
                  metadata?['completion_status']?.toString(),
                ),
              );
            },
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, MoonReturnEventKind.emptyEye.title);
    await _enterPilotResponse(
      tester,
      specId: 'moon-return-set-down',
      text: 'Set down haste.',
    );
    await _tapStatus(tester, 'Observed');

    expect(recorded, <CompletionStatus>[CompletionStatus.observed]);
    expect(document.toPlainText(), contains('User text before the response.'));
    expect(document.toPlainText(), contains('Moon Return: Set down haste.'));
    expect(MaatJournalResponseBlockUtils.extract(document), hasLength(1));
    expect(JournalBadgeUtils.hasBadges(document.toPlainText()), isFalse);
    expect(badgeAppends, hasLength(1));
    expect(JournalBadgeUtils.hasBadges(badgeAppends.single), isTrue);
  });

  testWidgets('Moon Return repeat completion updates one response block', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    var document = _journalDocument('User text survives before and after.');

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _moonReturnFlowIndex,
        notes: <NoteData>[_moonReturnNote(kind: MoonReturnEventKind.emptyEye)],
        onAppendToJournal: (_) async {},
        onWriteJournalResponse: (block) async {
          document = MaatJournalResponseBlockUtils.upsert(document, block);
        },
        onRecordCompletion:
            ({
              required String clientEventId,
              required int flowId,
              required DateTime completedOnDate,
              Map<String, dynamic>? metadata,
            }) async {},
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, MoonReturnEventKind.emptyEye.title);
    await _enterPilotResponse(
      tester,
      specId: 'moon-return-set-down',
      text: 'First response.',
    );
    await _tapStatus(tester, 'Observed');

    await _enterPilotResponse(
      tester,
      specId: 'moon-return-set-down',
      text: 'Updated response.',
    );
    await _tapStatus(tester, 'Observed');

    final responseBlocks = MaatJournalResponseBlockUtils.extract(document);
    expect(responseBlocks, hasLength(1));
    expect(responseBlocks.single.text, 'Moon Return: Updated response.');
    expect(
      document.toPlainText(),
      contains('User text survives before and after.'),
    );
    expect(document.toPlainText(), isNot(contains('First response.')));
    expect(JournalBadgeUtils.hasBadges(document.toPlainText()), isFalse);
  });

  testWidgets(
    'The Course response renders and writes with partial completion',
    (tester) async {
      await _setPhoneViewport(tester);
      var document = _journalDocument('Course journal body stays.');
      final recorded = <CompletionStatus>[];

      await tester.pumpWidget(
        _DayViewHarness(
          flowIndex: _courseFlowIndex,
          notes: <NoteData>[_courseNote()],
          onAppendToJournal: (_) async {},
          onWriteJournalResponse: (block) async {
            document = MaatJournalResponseBlockUtils.upsert(document, block);
          },
          onRecordCompletion:
              ({
                required String clientEventId,
                required int flowId,
                required DateTime completedOnDate,
                Map<String, dynamic>? metadata,
              }) async {
                recorded.add(
                  CompletionStatusX.fromWireName(
                    metadata?['completion_status']?.toString(),
                  ),
                );
              },
        ),
      );
      await tester.pumpAndSettle();

      await _openDetailSheet(tester, _courseTitle);

      expect(find.byKey(kMaatFlowResponseSectionKey), findsOneWidget);
      expect(find.text('What action fits this hour?'), findsOneWidget);

      await _enterPilotResponse(
        tester,
        specId: 'course-hour-action',
        text: 'Send the letter now.',
      );
      await _tapStatus(tester, 'Partly');

      expect(recorded, <CompletionStatus>[CompletionStatus.partial]);
      expect(document.toPlainText(), contains('Course journal body stays.'));
      expect(
        document.toPlainText(),
        contains('The Course: Send the letter now.'),
      );
      expect(MaatJournalResponseBlockUtils.extract(document), hasLength(1));
      expect(JournalBadgeUtils.hasBadges(document.toPlainText()), isFalse);
    },
  );

  testWidgets('Decan Watch response renders and previews grouped journal text', (
    tester,
  ) async {
    await _setPhoneViewport(tester);

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _decanWatchFlowIndex,
        notes: <NoteData>[_decanWatchNote()],
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _decanWatchTitle);

    expect(find.byKey(kMaatFlowResponseSectionKey), findsOneWidget);
    expect(find.text('Visibility'), findsOneWidget);
    for (final optionId in const <String>[
      kDecanWatchVisibilityOutside,
      kDecanWatchVisibilityInside,
      kDecanWatchVisibilityClouded,
      kDecanWatchVisibilityNotVisible,
    ]) {
      expect(
        find.byKey(
          maatFlowResponseFieldKey(
            '$kDecanWatchResponseVisibilitySpecId:$optionId',
          ),
        ),
        findsOneWidget,
      );
    }
    expect(find.text('What did the sky show?'), findsOneWidget);
    expect(
      find.text('What bearing do you carry into the next ten days?'),
      findsOneWidget,
    );
    expect(find.text('Decan Watch notes'), findsNothing);

    await _choosePilotOption(
      tester,
      specId: kDecanWatchResponseVisibilitySpecId,
      optionId: kDecanWatchVisibilityOutside,
    );
    expect(
      find.text('The Decan Watch: I watched from outside.'),
      findsOneWidget,
    );

    await _enterPilotResponse(
      tester,
      specId: kDecanWatchResponseSkyNoteSpecId,
      text: 'a clear western glow',
    );
    expect(
      find.textContaining('The sky showed a clear western glow.'),
      findsOneWidget,
    );

    await _enterPilotResponse(
      tester,
      specId: kDecanWatchResponseBearingSpecId,
      text: 'steadiness',
    );
    expect(
      find.text(
        'The Decan Watch: I watched from outside. The sky showed a clear western glow. I carry steadiness into the next ten days.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Decan Watch completion writes one response block beside badges', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    var document = _journalDocument('Decan journal body stays.');
    final badgeAppends = <String>[];
    final recorded = <Map<String, dynamic>>[];

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _decanWatchFlowIndex,
        notes: <NoteData>[_decanWatchNote()],
        onAppendToJournal: (text) async => badgeAppends.add(text),
        onWriteJournalResponse: (block) async {
          document = MaatJournalResponseBlockUtils.upsert(document, block);
        },
        onRecordCompletion:
            ({
              required String clientEventId,
              required int flowId,
              required DateTime completedOnDate,
              Map<String, dynamic>? metadata,
            }) async {
              recorded.add(Map<String, dynamic>.from(metadata ?? const {}));
            },
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _decanWatchTitle);
    await _choosePilotOption(
      tester,
      specId: kDecanWatchResponseVisibilitySpecId,
      optionId: kDecanWatchVisibilityOutside,
    );
    await _enterPilotResponse(
      tester,
      specId: kDecanWatchResponseSkyNoteSpecId,
      text: 'a clear western glow',
    );
    await _enterPilotResponse(
      tester,
      specId: kDecanWatchResponseBearingSpecId,
      text: 'steadiness',
    );
    await _tapStatus(tester, 'Observed');

    expect(recorded, hasLength(1));
    expect(
      recorded.single['completion_status'],
      CompletionStatus.observed.wireName,
    );
    expect(recorded.single.toString(), isNot(contains('sky_note')));
    expect(recorded.single.toString(), isNot(contains('decan_intention')));
    expect(document.toPlainText(), contains('Decan journal body stays.'));
    expect(
      document.toPlainText(),
      contains(
        'The Decan Watch: I watched from outside. The sky showed a clear western glow. I carry steadiness into the next ten days.',
      ),
    );
    expect(MaatJournalResponseBlockUtils.extract(document), hasLength(1));
    expect(JournalBadgeUtils.hasBadges(document.toPlainText()), isFalse);
    expect(badgeAppends, hasLength(1));
    expect(JournalBadgeUtils.hasBadges(badgeAppends.single), isTrue);

    final prefs = await SharedPreferences.getInstance();
    final record = await DecanWatchLocalStore(
      prefs: prefs,
    ).loadRecord(flowId: _decanWatchFlowId, kYear: 1, globalDecanId: 1);
    expect(record.responseVisibility, kDecanWatchVisibilityOutside);
    expect(record.skyNote, 'a clear western glow');
    expect(record.decanIntention, 'steadiness');
  });

  testWidgets('Decan Watch repeat completion updates one response block', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    var document = _journalDocument('Existing Decan journal text.');

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _decanWatchFlowIndex,
        notes: <NoteData>[_decanWatchNote()],
        onAppendToJournal: (_) async {},
        onWriteJournalResponse: (block) async {
          document = MaatJournalResponseBlockUtils.upsert(document, block);
        },
        onRecordCompletion:
            ({
              required String clientEventId,
              required int flowId,
              required DateTime completedOnDate,
              Map<String, dynamic>? metadata,
            }) async {},
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _decanWatchTitle);
    await _choosePilotOption(
      tester,
      specId: kDecanWatchResponseVisibilitySpecId,
      optionId: kDecanWatchVisibilityInside,
    );
    await _enterPilotResponse(
      tester,
      specId: kDecanWatchResponseSkyNoteSpecId,
      text: 'first sky',
    );
    await _enterPilotResponse(
      tester,
      specId: kDecanWatchResponseBearingSpecId,
      text: 'first bearing',
    );
    await _tapStatus(tester, 'Observed');

    await _enterPilotResponse(
      tester,
      specId: kDecanWatchResponseSkyNoteSpecId,
      text: 'updated sky',
    );
    await _enterPilotResponse(
      tester,
      specId: kDecanWatchResponseBearingSpecId,
      text: 'updated bearing',
    );
    await _tapStatus(tester, 'Observed');

    final responseBlocks = MaatJournalResponseBlockUtils.extract(document);
    expect(responseBlocks, hasLength(1));
    expect(
      responseBlocks.single.text,
      'The Decan Watch: I watched from inside. The sky showed updated sky. I carry updated bearing into the next ten days.',
    );
    expect(document.toPlainText(), contains('Existing Decan journal text.'));
    expect(document.toPlainText(), isNot(contains('first sky')));
  });

  testWidgets('Decan Watch response hydrates existing local store values', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await DecanWatchLocalStore(prefs: prefs).saveRecord(
      flowId: _decanWatchFlowId,
      kYear: 1,
      globalDecanId: 1,
      record: const DecanWatchRecord(
        skyNote: 'clouded western horizon',
        decanIntention: 'steadiness',
        observedFromInside: true,
      ),
    );
    await _setPhoneViewport(tester);

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _decanWatchFlowIndex,
        notes: <NoteData>[_decanWatchNote()],
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _decanWatchTitle);
    await _pumpInteraction(tester);

    final insideFinder = find.byKey(
      maatFlowResponseFieldKey(
        '$kDecanWatchResponseVisibilitySpecId:$kDecanWatchVisibilityInside',
      ),
    );
    await _pumpUntil(
      tester,
      () =>
          insideFinder.evaluate().isNotEmpty &&
          tester.widget<ChoiceChip>(insideFinder).selected,
    );
    final insideChip = tester.widget<ChoiceChip>(insideFinder);
    expect(insideChip.selected, isTrue);
    expect(find.text('clouded western horizon'), findsOneWidget);
    expect(find.text('steadiness'), findsOneWidget);
    expect(
      find.text(
        'The Decan Watch: I watched from inside. The sky showed clouded western horizon. I carry steadiness into the next ten days.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Dawn House Rite response renders and previews journal text', (
    tester,
  ) async {
    await _setPhoneViewport(tester);

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _dawnHouseRiteFlowIndex,
        notes: <NoteData>[_dawnHouseRiteNote()],
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _dawnHouseRiteTitle);

    expect(find.byKey(kMaatFlowResponseSectionKey), findsOneWidget);
    expect(find.text('One act of order today'), findsOneWidget);

    await _enterPilotResponse(
      tester,
      specId: 'dawn-house-order-act',
      text: 'clearing the table before the day began.',
    );

    expect(find.byKey(kMaatFlowResponseJournalPreviewKey), findsOneWidget);
    expect(
      find.text(
        'Dawn House Rite: I brought order by clearing the table before the day began.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Dawn House Rite completion writes response body beside badges', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    var document = _journalDocument('Dawn journal body stays.');
    final badgeAppends = <String>[];

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _dawnHouseRiteFlowIndex,
        notes: <NoteData>[_dawnHouseRiteNote()],
        onAppendToJournal: (text) async => badgeAppends.add(text),
        onWriteJournalResponse: (block) async {
          document = MaatJournalResponseBlockUtils.upsert(document, block);
        },
        onRecordCompletion:
            ({
              required String clientEventId,
              required int flowId,
              required DateTime completedOnDate,
              Map<String, dynamic>? metadata,
            }) async {},
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _dawnHouseRiteTitle);
    await _enterPilotResponse(
      tester,
      specId: 'dawn-house-order-act',
      text: 'sweeping the entry.',
    );
    await _tapStatus(tester, 'Observed');

    expect(document.toPlainText(), contains('Dawn journal body stays.'));
    expect(
      document.toPlainText(),
      contains('Dawn House Rite: I brought order by sweeping the entry.'),
    );
    expect(MaatJournalResponseBlockUtils.extract(document), hasLength(1));
    expect(JournalBadgeUtils.hasBadges(document.toPlainText()), isFalse);
    expect(badgeAppends, hasLength(1));
    expect(JournalBadgeUtils.hasBadges(badgeAppends.single), isTrue);
  });

  testWidgets('Dawn House Rite repeat completion updates one response block', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    var document = _journalDocument('Existing Dawn journal text.');

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _dawnHouseRiteFlowIndex,
        notes: <NoteData>[_dawnHouseRiteNote()],
        onAppendToJournal: (_) async {},
        onWriteJournalResponse: (block) async {
          document = MaatJournalResponseBlockUtils.upsert(document, block);
        },
        onRecordCompletion:
            ({
              required String clientEventId,
              required int flowId,
              required DateTime completedOnDate,
              Map<String, dynamic>? metadata,
            }) async {},
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _dawnHouseRiteTitle);
    await _enterPilotResponse(
      tester,
      specId: 'dawn-house-order-act',
      text: 'first ordered act.',
    );
    await _tapStatus(tester, 'Observed');

    await _enterPilotResponse(
      tester,
      specId: 'dawn-house-order-act',
      text: 'clearing the sink.',
    );
    await _tapStatus(tester, 'Observed');

    final responseBlocks = MaatJournalResponseBlockUtils.extract(document);
    expect(responseBlocks, hasLength(1));
    expect(
      responseBlocks.single.text,
      'Dawn House Rite: I brought order by clearing the sink.',
    );
    expect(document.toPlainText(), contains('Existing Dawn journal text.'));
    expect(document.toPlainText(), isNot(contains('first ordered act')));
  });

  testWidgets('Evening Threshold Rite response renders and writes', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    var document = _journalDocument('Closing journal body stays.');

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _eveningThresholdRiteFlowIndex,
        notes: <NoteData>[_eveningThresholdRiteNote()],
        onAppendToJournal: (_) async {},
        onWriteJournalResponse: (block) async {
          document = MaatJournalResponseBlockUtils.upsert(document, block);
        },
        onRecordCompletion:
            ({
              required String clientEventId,
              required int flowId,
              required DateTime completedOnDate,
              Map<String, dynamic>? metadata,
            }) async {},
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _eveningThresholdRiteTitle);

    expect(find.byKey(kMaatFlowResponseSectionKey), findsOneWidget);
    expect(find.text('What do you release tonight?'), findsOneWidget);

    await _enterPilotResponse(
      tester,
      specId: 'closing-release-tonight',
      text: 'the unfinished worry and leave it for tomorrow\'s light.',
    );
    expect(
      find.text(
        'The Closing: I release the unfinished worry and leave it for tomorrow\'s light.',
      ),
      findsOneWidget,
    );

    await _tapStatus(tester, 'Observed');

    expect(document.toPlainText(), contains('Closing journal body stays.'));
    expect(
      document.toPlainText(),
      contains(
        'The Closing: I release the unfinished worry and leave it for tomorrow\'s light.',
      ),
    );
    expect(MaatJournalResponseBlockUtils.extract(document), hasLength(1));
    expect(JournalBadgeUtils.hasBadges(document.toPlainText()), isFalse);
  });

  testWidgets('Offering Table response renders and previews journal text', (
    tester,
  ) async {
    await _setPhoneViewport(tester);

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _offeringTableFlowIndex,
        notes: <NoteData>[_offeringTableNote()],
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _offeringTableTitle);

    expect(find.byKey(kMaatFlowResponseSectionKey), findsOneWidget);
    expect(find.text('What was fed?'), findsOneWidget);
    expect(find.text('What did you provide today?'), findsOneWidget);
    for (final optionId in const <String>['water', 'rest', 'care']) {
      expect(
        find.byKey(maatFlowResponseFieldKey('offering-table-fed:$optionId')),
        findsOneWidget,
      );
    }

    await _choosePilotOption(
      tester,
      specId: 'offering-table-fed',
      optionId: 'rest',
    );
    expect(
      find.text('The Offering Table: I provided rest today.'),
      findsOneWidget,
    );

    await _enterPilotResponse(
      tester,
      specId: 'offering-table-provided',
      text: 'closing the laptop early and letting the house settle.',
    );

    expect(find.byKey(kMaatFlowResponseJournalPreviewKey), findsOneWidget);
    expect(
      find.text(
        'The Offering Table: I fed rest by closing the laptop early and letting the house settle.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Offering Table completion writes response body beside badges', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    var document = _journalDocument('Offering journal body stays.');
    final badgeAppends = <String>[];
    final responseWrites = <MaatJournalResponseBlock>[];
    final expectedEventDate = DateUtils.dateOnly(
      KemeticMath.toGregorian(1, 1, 1),
    );

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _offeringTableFlowIndex,
        notes: <NoteData>[_offeringTableNote()],
        onAppendToJournal: (text) async => badgeAppends.add(text),
        onWriteJournalResponse: (block) async {
          responseWrites.add(block);
          document = MaatJournalResponseBlockUtils.upsert(document, block);
        },
        onRecordCompletion:
            ({
              required String clientEventId,
              required int flowId,
              required DateTime completedOnDate,
              Map<String, dynamic>? metadata,
            }) async {},
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _offeringTableTitle);
    await _choosePilotOption(
      tester,
      specId: 'offering-table-fed',
      optionId: 'water',
    );
    await _choosePilotOption(
      tester,
      specId: 'offering-table-fed',
      optionId: 'care',
    );
    await _tapStatus(tester, 'Observed');

    expect(document.toPlainText(), contains('Offering journal body stays.'));
    expect(
      document.toPlainText(),
      contains('The Offering Table: I provided water and care today.'),
    );
    expect(MaatJournalResponseBlockUtils.extract(document), hasLength(1));
    expect(responseWrites, hasLength(1));
    expect(
      DateUtils.dateOnly(responseWrites.single.localDate!),
      expectedEventDate,
    );
    expect(JournalBadgeUtils.hasBadges(document.toPlainText()), isFalse);
    expect(badgeAppends, hasLength(1));
    expect(JournalBadgeUtils.hasBadges(badgeAppends.single), isTrue);
  });

  testWidgets('Offering Table repeat completion updates one response block', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    var document = _journalDocument('Existing Offering journal text.');

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _offeringTableFlowIndex,
        notes: <NoteData>[_offeringTableNote()],
        onAppendToJournal: (_) async {},
        onWriteJournalResponse: (block) async {
          document = MaatJournalResponseBlockUtils.upsert(document, block);
        },
        onRecordCompletion:
            ({
              required String clientEventId,
              required int flowId,
              required DateTime completedOnDate,
              Map<String, dynamic>? metadata,
            }) async {},
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _offeringTableTitle);
    await _choosePilotOption(
      tester,
      specId: 'offering-table-fed',
      optionId: 'rest',
    );
    await _enterPilotResponse(
      tester,
      specId: 'offering-table-provided',
      text: 'first provision.',
    );
    await _tapStatus(tester, 'Observed');

    await _enterPilotResponse(
      tester,
      specId: 'offering-table-provided',
      text: 'closing the kitchen before night.',
    );
    await _tapStatus(tester, 'Observed');

    final responseBlocks = MaatJournalResponseBlockUtils.extract(document);
    expect(responseBlocks, hasLength(1));
    expect(
      responseBlocks.single.text,
      'The Offering Table: I fed rest by closing the kitchen before night.',
    );
    expect(document.toPlainText(), contains('Existing Offering journal text.'));
    expect(document.toPlainText(), isNot(contains('first provision')));
  });

  testWidgets('Days Outside response renders and writes receipt block', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    var document = _journalDocument('Days Outside journal body stays.');
    final badgeAppends = <String>[];
    final responseWrites = <MaatJournalResponseBlock>[];
    final expectedEventDate = DateUtils.dateOnly(
      KemeticMath.toGregorian(1, 1, 1),
    );

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _daysOutsideFlowIndex,
        notes: <NoteData>[_daysOutsideNote()],
        onAppendToJournal: (text) async => badgeAppends.add(text),
        onWriteJournalResponse: (block) async {
          responseWrites.add(block);
          document = MaatJournalResponseBlockUtils.upsert(document, block);
        },
        onRecordCompletion:
            ({
              required String clientEventId,
              required int flowId,
              required DateTime completedOnDate,
              Map<String, dynamic>? metadata,
            }) async {},
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _daysOutsideTitle);

    expect(find.byKey(kMaatFlowResponseSectionKey), findsOneWidget);
    expect(
      find.text('What receipt do you carry from this threshold?'),
      findsOneWidget,
    );

    await _enterPilotResponse(
      tester,
      specId: 'days-outside-receipt',
      text: 'I survived the old year with more clarity than I entered it.',
    );
    expect(
      find.text(
        'The Days Outside the Year: I carry the receipt that I survived the old year with more clarity than I entered it.',
      ),
      findsOneWidget,
    );

    await _tapStatus(tester, 'Observed');

    expect(
      document.toPlainText(),
      contains('Days Outside journal body stays.'),
    );
    expect(
      document.toPlainText(),
      contains(
        'The Days Outside the Year: I carry the receipt that I survived the old year with more clarity than I entered it.',
      ),
    );
    expect(MaatJournalResponseBlockUtils.extract(document), hasLength(1));
    expect(responseWrites, hasLength(1));
    expect(
      DateUtils.dateOnly(responseWrites.single.localDate!),
      expectedEventDate,
    );
    expect(JournalBadgeUtils.hasBadges(document.toPlainText()), isFalse);
    expect(badgeAppends, hasLength(1));
    expect(JournalBadgeUtils.hasBadges(badgeAppends.single), isTrue);
  });

  testWidgets('Days Outside repeat completion updates one response block', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    var document = _journalDocument('Existing Days Outside journal text.');

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _daysOutsideFlowIndex,
        notes: <NoteData>[_daysOutsideNote()],
        onAppendToJournal: (_) async {},
        onWriteJournalResponse: (block) async {
          document = MaatJournalResponseBlockUtils.upsert(document, block);
        },
        onRecordCompletion:
            ({
              required String clientEventId,
              required int flowId,
              required DateTime completedOnDate,
              Map<String, dynamic>? metadata,
            }) async {},
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _daysOutsideTitle);
    await _enterPilotResponse(
      tester,
      specId: 'days-outside-receipt',
      text: 'first threshold receipt.',
    );
    await _tapStatus(tester, 'Observed');

    await _enterPilotResponse(
      tester,
      specId: 'days-outside-receipt',
      text: 'I carried one clear receipt across the threshold.',
    );
    await _tapStatus(tester, 'Observed');

    final responseBlocks = MaatJournalResponseBlockUtils.extract(document);
    expect(responseBlocks, hasLength(1));
    expect(
      responseBlocks.single.text,
      'The Days Outside the Year: I carry the receipt that I carried one clear receipt across the threshold.',
    );
    expect(
      document.toPlainText(),
      contains('Existing Days Outside journal text.'),
    );
    expect(document.toPlainText(), isNot(contains('first threshold receipt')));
  });

  testWidgets('Wep Ronpet response uses opening prompt and journal text', (
    tester,
  ) async {
    await _setPhoneViewport(tester);

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _daysOutsideFlowIndex,
        notes: <NoteData>[_daysOutsideNote(event: _wepRonpetEvent)],
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _wepRonpetTitle);

    expect(find.byKey(kMaatFlowResponseSectionKey), findsOneWidget);
    expect(find.text('What intention opens the year?'), findsOneWidget);
    expect(
      find.text('What receipt do you carry from this threshold?'),
      findsNothing,
    );

    await _enterPilotResponse(
      tester,
      specId: 'wep-ronpet-year-intention',
      text: 'steadiness, clean speech, and finished work.',
    );

    expect(
      find.text(
        'Wep Ronpet: I open the year with steadiness, clean speech, and finished work.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Open Hand response renders and previews offered journal text', (
    tester,
  ) async {
    await _setPhoneViewport(tester);

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _openHandFlowIndex,
        notes: <NoteData>[_openHandNote()],
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _openHandTitle);

    expect(find.byKey(kMaatFlowResponseSectionKey), findsOneWidget);
    expect(find.text('What was given?'), findsOneWidget);
    expect(find.text('What moved through your hand?'), findsOneWidget);
    for (final optionId in const <String>['time', 'attention', 'labor']) {
      expect(
        find.byKey(maatFlowResponseFieldKey('open-hand-given:$optionId')),
        findsOneWidget,
      );
    }

    await _choosePilotOption(
      tester,
      specId: 'open-hand-given',
      optionId: 'time',
    );
    await _choosePilotOption(
      tester,
      specId: 'open-hand-given',
      optionId: 'attention',
    );
    await _enterPilotResponse(
      tester,
      specId: 'open-hand-moved',
      text: 'where need was visible.',
    );

    expect(find.byKey(kMaatFlowResponseJournalPreviewKey), findsOneWidget);
    expect(find.text('Journal preview'), findsOneWidget);
    expect(
      find.text(
        'The Open Hand: I gave time and attention where need was visible.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Open Hand completion writes one offered response block', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    var document = _journalDocument('Open Hand journal body stays.');
    final badgeAppends = <String>[];

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _openHandFlowIndex,
        notes: <NoteData>[_openHandNote()],
        onAppendToJournal: (text) async => badgeAppends.add(text),
        onWriteJournalResponse: (block) async {
          document = MaatJournalResponseBlockUtils.upsert(document, block);
        },
        onRecordCompletion:
            ({
              required String clientEventId,
              required int flowId,
              required DateTime completedOnDate,
              Map<String, dynamic>? metadata,
            }) async {},
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _openHandTitle);
    await _choosePilotOption(
      tester,
      specId: 'open-hand-given',
      optionId: 'food',
    );
    await _choosePilotOption(
      tester,
      specId: 'open-hand-given',
      optionId: 'connection',
    );
    await _tapStatus(tester, 'Observed');

    expect(document.toPlainText(), contains('Open Hand journal body stays.'));
    expect(
      document.toPlainText(),
      contains(
        'The Open Hand: I gave food and connection where need was visible.',
      ),
    );
    expect(MaatJournalResponseBlockUtils.extract(document), hasLength(1));
    expect(JournalBadgeUtils.hasBadges(document.toPlainText()), isFalse);
    expect(badgeAppends, hasLength(1));
    expect(JournalBadgeUtils.hasBadges(badgeAppends.single), isTrue);
  });

  testWidgets('Open Hand offer can suppress journal response body', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    var document = _journalDocument('Open Hand manual journal body.');
    final badgeAppends = <String>[];
    final responseWrites = <MaatJournalResponseBlock>[];

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _openHandFlowIndex,
        notes: <NoteData>[_openHandNote()],
        onAppendToJournal: (text) async => badgeAppends.add(text),
        onWriteJournalResponse: (block) async {
          responseWrites.add(block);
          document = MaatJournalResponseBlockUtils.upsert(document, block);
        },
        onRecordCompletion:
            ({
              required String clientEventId,
              required int flowId,
              required DateTime completedOnDate,
              Map<String, dynamic>? metadata,
            }) async {},
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _openHandTitle);
    await _choosePilotOption(
      tester,
      specId: 'open-hand-given',
      optionId: 'attention',
    );

    expect(find.text('Add to journal'), findsOneWidget);
    await _toggleOfferJournalWrite(tester);
    await _tapStatus(tester, 'Observed');

    expect(responseWrites, hasLength(1));
    expect(responseWrites.single.text, isEmpty);
    expect(document.toPlainText(), 'Open Hand manual journal body.');
    expect(MaatJournalResponseBlockUtils.extract(document), isEmpty);
    expect(badgeAppends, hasLength(1));
    expect(JournalBadgeUtils.hasBadges(badgeAppends.single), isTrue);
  });

  testWidgets('Open Hand repeat completion updates one response block', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    var document = _journalDocument('Existing Open Hand journal text.');

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _openHandFlowIndex,
        notes: <NoteData>[_openHandNote()],
        onAppendToJournal: (_) async {},
        onWriteJournalResponse: (block) async {
          document = MaatJournalResponseBlockUtils.upsert(document, block);
        },
        onRecordCompletion:
            ({
              required String clientEventId,
              required int flowId,
              required DateTime completedOnDate,
              Map<String, dynamic>? metadata,
            }) async {},
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _openHandTitle);
    await _choosePilotOption(
      tester,
      specId: 'open-hand-given',
      optionId: 'labor',
    );
    await _enterPilotResponse(
      tester,
      specId: 'open-hand-moved',
      text: 'first offered detail.',
    );
    await _tapStatus(tester, 'Observed');

    await _enterPilotResponse(
      tester,
      specId: 'open-hand-moved',
      text: 'through one concrete act of help.',
    );
    await _tapStatus(tester, 'Observed');

    final responseBlocks = MaatJournalResponseBlockUtils.extract(document);
    expect(responseBlocks, hasLength(1));
    expect(
      responseBlocks.single.text,
      'The Open Hand: I gave labor through one concrete act of help.',
    );
    expect(
      document.toPlainText(),
      contains('Existing Open Hand journal text.'),
    );
    expect(document.toPlainText(), isNot(contains('first offered detail')));
  });

  testWidgets('Djed response renders and previews offered journal text', (
    tester,
  ) async {
    await _setPhoneViewport(tester);

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _djedFlowIndex,
        notes: <NoteData>[_djedNote()],
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _djedTitle);

    expect(find.byKey(kMaatFlowResponseSectionKey), findsOneWidget);
    expect(find.text('What needed to stand upright?'), findsOneWidget);
    expect(find.text('What did you raise or restore?'), findsOneWidget);
    for (final optionId in const <String>['body', 'boundary', 'practice']) {
      expect(
        find.byKey(maatFlowResponseFieldKey('djed-stood-upright:$optionId')),
        findsOneWidget,
      );
    }

    await _choosePilotOption(
      tester,
      specId: 'djed-stood-upright',
      optionId: 'body',
    );
    await _choosePilotOption(
      tester,
      specId: 'djed-stood-upright',
      optionId: 'boundary',
    );
    await _enterPilotResponse(
      tester,
      specId: 'djed-restored',
      text: 'setting a load-bearing practice back in place.',
    );

    expect(find.byKey(kMaatFlowResponseJournalPreviewKey), findsOneWidget);
    expect(find.text('Journal preview'), findsOneWidget);
    expect(
      find.text(
        'The Djed: I restored body and boundary by setting a load-bearing practice back in place and stood it upright again.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Djed completion writes one offered response block', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    var document = _journalDocument('Djed journal body stays.');

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _djedFlowIndex,
        notes: <NoteData>[_djedNote()],
        onAppendToJournal: (_) async {},
        onWriteJournalResponse: (block) async {
          document = MaatJournalResponseBlockUtils.upsert(document, block);
        },
        onRecordCompletion:
            ({
              required String clientEventId,
              required int flowId,
              required DateTime completedOnDate,
              Map<String, dynamic>? metadata,
            }) async {},
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _djedTitle);
    await _choosePilotOption(
      tester,
      specId: 'djed-stood-upright',
      optionId: 'practice',
    );
    await _enterPilotResponse(
      tester,
      specId: 'djed-restored',
      text: 'one load-bearing part of my life.',
    );
    await _tapStatus(tester, 'Partly');

    expect(document.toPlainText(), contains('Djed journal body stays.'));
    expect(
      document.toPlainText(),
      contains(
        'The Djed: I restored practice by restoring one load-bearing part of my life and stood it upright again.',
      ),
    );
    expect(MaatJournalResponseBlockUtils.extract(document), hasLength(1));
    expect(JournalBadgeUtils.hasBadges(document.toPlainText()), isFalse);
  });

  testWidgets('Djed repeat completion updates one response block', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    var document = _journalDocument('Existing Djed journal text.');

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _djedFlowIndex,
        notes: <NoteData>[_djedNote()],
        onAppendToJournal: (_) async {},
        onWriteJournalResponse: (block) async {
          document = MaatJournalResponseBlockUtils.upsert(document, block);
        },
        onRecordCompletion:
            ({
              required String clientEventId,
              required int flowId,
              required DateTime completedOnDate,
              Map<String, dynamic>? metadata,
            }) async {},
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _djedTitle);
    await _choosePilotOption(
      tester,
      specId: 'djed-stood-upright',
      optionId: 'rest',
    );
    await _enterPilotResponse(
      tester,
      specId: 'djed-restored',
      text: 'first private detail.',
    );
    await _tapStatus(tester, 'Observed');

    await _enterPilotResponse(
      tester,
      specId: 'djed-restored',
      text: 'an evening practice.',
    );
    await _tapStatus(tester, 'Observed');

    final responseBlocks = MaatJournalResponseBlockUtils.extract(document);
    expect(responseBlocks, hasLength(1));
    expect(
      responseBlocks.single.text,
      'The Djed: I restored rest by restoring an evening practice and stood it upright again.',
    );
    expect(document.toPlainText(), contains('Existing Djed journal text.'));
    expect(document.toPlainText(), isNot(contains('first private detail')));
  });

  testWidgets('Tending response renders with default-off journal offer', (
    tester,
  ) async {
    await _setPhoneViewport(tester);

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _tendingFlowIndex,
        notes: <NoteData>[_tendingNote()],
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _tendingTitle);

    expect(find.byKey(kMaatFlowResponseSectionKey), findsOneWidget);
    expect(find.text('What care became specific?'), findsOneWidget);
    expect(find.text('What tending act did you complete?'), findsOneWidget);
    for (final optionId in const <String>['seen', 'repaired', 'returned']) {
      expect(
        find.byKey(maatFlowResponseFieldKey('tending-care-specific:$optionId')),
        findsOneWidget,
      );
    }

    await _choosePilotOption(
      tester,
      specId: 'tending-care-specific',
      optionId: 'seen',
    );
    await _choosePilotOption(
      tester,
      specId: 'tending-care-specific',
      optionId: 'repaired',
    );
    await _enterPilotResponse(
      tester,
      specId: 'tending-act-completed',
      text: 'calling before the day closed.',
    );

    expect(find.byKey(kMaatFlowResponseJournalPreviewKey), findsOneWidget);
    expect(find.text('Journal preview'), findsOneWidget);
    expect(
      find.text(
        'The Tending: I made care specific through seen and repaired and completed calling before the day closed.',
      ),
      findsOneWidget,
    );
    expect(find.text('Add to journal'), findsOneWidget);
    final addToggle = tester.widget<Checkbox>(find.byType(Checkbox).last);
    expect(addToggle.value, isFalse);
  });

  testWidgets('Tending can suppress journal response body', (tester) async {
    await _setPhoneViewport(tester);
    var document = _journalDocument('Tending manual journal body.');
    final badgeAppends = <String>[];
    final responseWrites = <MaatJournalResponseBlock>[];

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _tendingFlowIndex,
        notes: <NoteData>[_tendingNote()],
        onAppendToJournal: (text) async => badgeAppends.add(text),
        onWriteJournalResponse: (block) async {
          responseWrites.add(block);
          document = MaatJournalResponseBlockUtils.upsert(document, block);
        },
        onRecordCompletion:
            ({
              required String clientEventId,
              required int flowId,
              required DateTime completedOnDate,
              Map<String, dynamic>? metadata,
            }) async {},
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _tendingTitle);
    await _choosePilotOption(
      tester,
      specId: 'tending-care-specific',
      optionId: 'fed',
    );
    await _enterPilotResponse(
      tester,
      specId: 'tending-act-completed',
      text: 'checking on Alex and the appointment.',
    );
    await _tapStatus(tester, 'Observed');

    expect(responseWrites, hasLength(1));
    expect(responseWrites.single.text, isEmpty);
    expect(document.toPlainText(), 'Tending manual journal body.');
    expect(MaatJournalResponseBlockUtils.extract(document), isEmpty);
    expect(badgeAppends, hasLength(1));
    expect(JournalBadgeUtils.hasBadges(badgeAppends.single), isTrue);
  });

  testWidgets('Tending completion writes one opted-in response block', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    var document = _journalDocument('Tending journal body stays.');

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _tendingFlowIndex,
        notes: <NoteData>[_tendingNote()],
        onAppendToJournal: (_) async {},
        onWriteJournalResponse: (block) async {
          document = MaatJournalResponseBlockUtils.upsert(document, block);
        },
        onRecordCompletion:
            ({
              required String clientEventId,
              required int flowId,
              required DateTime completedOnDate,
              Map<String, dynamic>? metadata,
            }) async {},
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _tendingTitle);
    await _choosePilotOption(
      tester,
      specId: 'tending-care-specific',
      optionId: 'protected',
    );
    await _enterPilotResponse(
      tester,
      specId: 'tending-act-completed',
      text: 'one concrete tending act.',
    );
    await _toggleOfferJournalWrite(tester);
    await _tapStatus(tester, 'Observed');

    expect(document.toPlainText(), contains('Tending journal body stays.'));
    expect(
      document.toPlainText(),
      contains(
        'The Tending: I made care specific through protected and completed one concrete tending act.',
      ),
    );
    expect(MaatJournalResponseBlockUtils.extract(document), hasLength(1));
    expect(JournalBadgeUtils.hasBadges(document.toPlainText()), isFalse);
  });

  testWidgets('Tending repeat completion updates one opted-in response block', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    var document = _journalDocument('Existing Tending journal text.');

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _tendingFlowIndex,
        notes: <NoteData>[_tendingNote()],
        onAppendToJournal: (_) async {},
        onWriteJournalResponse: (block) async {
          document = MaatJournalResponseBlockUtils.upsert(document, block);
        },
        onRecordCompletion:
            ({
              required String clientEventId,
              required int flowId,
              required DateTime completedOnDate,
              Map<String, dynamic>? metadata,
            }) async {},
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _tendingTitle);
    await _choosePilotOption(
      tester,
      specId: 'tending-care-specific',
      optionId: 'cleaned',
    );
    await _enterPilotResponse(
      tester,
      specId: 'tending-act-completed',
      text: 'first care detail.',
    );
    await _toggleOfferJournalWrite(tester);
    await _tapStatus(tester, 'Observed');

    await _enterPilotResponse(
      tester,
      specId: 'tending-act-completed',
      text: 'clearing one practical obstacle.',
    );
    await _tapStatus(tester, 'Observed');

    final responseBlocks = MaatJournalResponseBlockUtils.extract(document);
    expect(responseBlocks, hasLength(1));
    expect(
      responseBlocks.single.text,
      'The Tending: I made care specific through cleaned and completed clearing one practical obstacle.',
    );
    expect(document.toPlainText(), contains('Existing Tending journal text.'));
    expect(document.toPlainText(), isNot(contains('first care detail')));
  });

  testWidgets('Tending local values hydrate and clearing remains local', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    final prefs = await SharedPreferences.getInstance();
    final store = TheTendingLocalStore(prefs: prefs);
    await store.savePromptText(
      _tendingFlowId,
      TheTendingLocalPromptKind.careInventory,
      'Name One - medicine',
    );

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _tendingFlowIndex,
        notes: <NoteData>[_tendingNote()],
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _tendingTitle);
    await _pumpUntil(
      tester,
      () => find.text('Name One - medicine').evaluate().isNotEmpty,
    );

    expect(find.text('Care inventory'), findsOneWidget);
    expect(find.text('Name One - medicine'), findsOneWidget);
    expect(
      prefs.getString('tending_${_tendingFlowId}_prompt_care_inventory'),
      'Name One - medicine',
    );

    final clear = find.widgetWithText(OutlinedButton, 'Clear').last;
    await tester.ensureVisible(clear);
    await tester.tap(clear);
    await _pumpInteraction(tester);

    expect(
      prefs.getString('tending_${_tendingFlowId}_prompt_care_inventory'),
      isNull,
    );
    final retainedCareList = await store.loadCareList(_tendingFlowId);
    expect(retainedCareList, hasLength(1));
    expect(retainedCareList.single.name, 'Name One');
    expect(retainedCareList.single.perceivedNeed, 'medicine');
  });

  testWidgets('Kept Word response renders with default-off journal offer', (
    tester,
  ) async {
    await _setPhoneViewport(tester);

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _keptWordFlowIndex,
        notes: <NoteData>[_keptWordNote()],
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _keptWordTitle);

    expect(find.byKey(kMaatFlowResponseSectionKey), findsOneWidget);
    expect(find.text('What happened with the word?'), findsOneWidget);
    expect(
      find.text('What word, repair, or conversation needs to be remembered?'),
      findsOneWidget,
    );
    for (final optionId in const <String>[
      'kept',
      'renegotiated',
      'still_in_process',
    ]) {
      expect(
        find.byKey(maatFlowResponseFieldKey('kept-word-status:$optionId')),
        findsOneWidget,
      );
    }

    await _choosePilotOption(
      tester,
      specId: 'kept-word-status',
      optionId: 'renegotiated',
    );
    await _enterPilotResponse(
      tester,
      specId: 'kept-word-remembered',
      text: 'the repaired conversation belongs in memory.',
    );

    expect(find.byKey(kMaatFlowResponseJournalPreviewKey), findsOneWidget);
    expect(find.text('Journal preview'), findsOneWidget);
    expect(
      find.text(
        'The Kept Word: I brought one agreement back into clearer order; the word is renegotiated, and I remember the repaired conversation belongs in memory.',
      ),
      findsOneWidget,
    );
    expect(find.text('Add to journal'), findsOneWidget);
    final addToggle = tester.widget<Checkbox>(find.byType(Checkbox).last);
    expect(addToggle.value, isFalse);
  });

  testWidgets('Kept Word can suppress journal response body', (tester) async {
    await _setPhoneViewport(tester);
    var document = _journalDocument('Kept Word manual journal body.');
    final badgeAppends = <String>[];
    final responseWrites = <MaatJournalResponseBlock>[];

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _keptWordFlowIndex,
        notes: <NoteData>[_keptWordNote()],
        onAppendToJournal: (text) async => badgeAppends.add(text),
        onWriteJournalResponse: (block) async {
          responseWrites.add(block);
          document = MaatJournalResponseBlockUtils.upsert(document, block);
        },
        onRecordCompletion:
            ({
              required String clientEventId,
              required int flowId,
              required DateTime completedOnDate,
              Map<String, dynamic>? metadata,
            }) async {},
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _keptWordTitle);
    await _choosePilotOption(
      tester,
      specId: 'kept-word-status',
      optionId: 'repaired',
    );
    await _enterPilotResponse(
      tester,
      specId: 'kept-word-remembered',
      text: 'private relationship detail.',
    );
    await _tapStatus(tester, 'Observed');

    expect(responseWrites, hasLength(1));
    expect(responseWrites.single.text, isEmpty);
    expect(document.toPlainText(), 'Kept Word manual journal body.');
    expect(MaatJournalResponseBlockUtils.extract(document), isEmpty);
    expect(badgeAppends, hasLength(1));
    expect(JournalBadgeUtils.hasBadges(badgeAppends.single), isTrue);
  });

  testWidgets('Kept Word completion writes one opted-in response block', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    var document = _journalDocument('Kept Word journal body stays.');

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _keptWordFlowIndex,
        notes: <NoteData>[_keptWordNote()],
        onAppendToJournal: (_) async {},
        onWriteJournalResponse: (block) async {
          document = MaatJournalResponseBlockUtils.upsert(document, block);
        },
        onRecordCompletion:
            ({
              required String clientEventId,
              required int flowId,
              required DateTime completedOnDate,
              Map<String, dynamic>? metadata,
            }) async {},
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _keptWordTitle);
    await _choosePilotOption(
      tester,
      specId: 'kept-word-status',
      optionId: 'kept',
    );
    await _enterPilotResponse(
      tester,
      specId: 'kept-word-remembered',
      text: 'the repair stayed plain and accountable.',
    );
    await _toggleOfferJournalWrite(tester);
    await _tapStatus(tester, 'Observed');

    expect(document.toPlainText(), contains('Kept Word journal body stays.'));
    expect(
      document.toPlainText(),
      contains(
        'The Kept Word: I brought one agreement back into clearer order; the word is kept, and I remember the repair stayed plain and accountable.',
      ),
    );
    expect(MaatJournalResponseBlockUtils.extract(document), hasLength(1));
    expect(JournalBadgeUtils.hasBadges(document.toPlainText()), isFalse);
  });

  testWidgets('Kept Word repeat completion updates one opted-in response block', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    var document = _journalDocument('Existing Kept Word journal text.');

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _keptWordFlowIndex,
        notes: <NoteData>[_keptWordNote()],
        onAppendToJournal: (_) async {},
        onWriteJournalResponse: (block) async {
          document = MaatJournalResponseBlockUtils.upsert(document, block);
        },
        onRecordCompletion:
            ({
              required String clientEventId,
              required int flowId,
              required DateTime completedOnDate,
              Map<String, dynamic>? metadata,
            }) async {},
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _keptWordTitle);
    await _choosePilotOption(
      tester,
      specId: 'kept-word-status',
      optionId: 'still_in_process',
    );
    await _enterPilotResponse(
      tester,
      specId: 'kept-word-remembered',
      text: 'first agreement detail.',
    );
    await _toggleOfferJournalWrite(tester);
    await _tapStatus(tester, 'Observed');

    await _enterPilotResponse(
      tester,
      specId: 'kept-word-remembered',
      text: 'the next repair step is named.',
    );
    await _tapStatus(tester, 'Observed');

    final responseBlocks = MaatJournalResponseBlockUtils.extract(document);
    expect(responseBlocks, hasLength(1));
    expect(
      responseBlocks.single.text,
      'The Kept Word: I brought one agreement back into clearer order; the word is still in process, and I remember the next repair step is named.',
    );
    expect(
      document.toPlainText(),
      contains('Existing Kept Word journal text.'),
    );
    expect(document.toPlainText(), isNot(contains('first agreement detail')));
  });

  testWidgets('Kept Word local values hydrate and clearing remains local', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    final prefs = await SharedPreferences.getInstance();
    final store = TheKeptWordLocalStore(prefs: prefs);
    await store.savePromptText(
      _keptWordFlowId,
      KeptWordLocalPromptKind.agreementInventory,
      'Name One - dishes - broken',
    );

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _keptWordFlowIndex,
        notes: <NoteData>[_keptWordNote()],
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _keptWordTitle);
    await _pumpUntil(
      tester,
      () => find.text('Name One - dishes - broken').evaluate().isNotEmpty,
    );

    expect(find.text('Agreement inventory'), findsOneWidget);
    expect(find.text('Name One - dishes - broken'), findsOneWidget);
    expect(
      prefs.getString(
        'kept_word_${_keptWordFlowId}_prompt_agreement_inventory',
      ),
      'Name One - dishes - broken',
    );

    final clear = find.widgetWithText(OutlinedButton, 'Clear').last;
    await tester.ensureVisible(clear);
    await tester.tap(clear);
    await _pumpInteraction(tester);

    expect(
      prefs.getString(
        'kept_word_${_keptWordFlowId}_prompt_agreement_inventory',
      ),
      isNull,
    );
    expect(await store.loadAgreementInventory(_keptWordFlowId), isEmpty);
  });

  testWidgets('Kept Word conversation gate remains intact', (tester) async {
    await _setPhoneViewport(tester);
    final recorded = <CompletionStatus>[];

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _keptWordFlowIndex,
        notes: <NoteData>[_keptWordNote(event: _keptWordConversationEvent)],
        onAppendToJournal: (_) async {},
        onRecordCompletion:
            ({
              required String clientEventId,
              required int flowId,
              required DateTime completedOnDate,
              Map<String, dynamic>? metadata,
            }) async {
              recorded.add(
                CompletionStatusX.fromWireName(
                  metadata?['completion_status']?.toString(),
                ),
              );
            },
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _keptWordConversationTitle);
    await _choosePilotOption(
      tester,
      specId: 'kept-word-status',
      optionId: 'still_in_process',
    );
    await _tapStatus(tester, 'Observed');

    expect(recorded, isEmpty);
    expect(
      find.text(
        'Mark the conversation complete locally, or choose Conversation pending.',
      ),
      findsOneWidget,
    );

    await _tapStatus(tester, 'Conversation pending');
    expect(recorded, <CompletionStatus>[CompletionStatus.partial]);
  });

  testWidgets('Wag response renders with default-off journal offer', (
    tester,
  ) async {
    await _setPhoneViewport(tester);

    await tester.pumpWidget(
      _DayViewHarness(flowIndex: _wagFlowIndex, notes: <NoteData>[_wagNote()]),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _wagTitle);

    expect(find.byKey(kMaatFlowResponseSectionKey), findsOneWidget);
    expect(find.text('What was remembered?'), findsOneWidget);
    expect(
      find.text('What gift, memory, or legacy did you carry?'),
      findsOneWidget,
    );
    for (final optionId in const <String>['water', 'name', 'legacy']) {
      expect(
        find.byKey(maatFlowResponseFieldKey('wag-remembered:$optionId')),
        findsOneWidget,
      );
    }

    await _choosePilotOption(
      tester,
      specId: 'wag-remembered',
      optionId: 'table',
    );
    await _choosePilotOption(
      tester,
      specId: 'wag-remembered',
      optionId: 'legacy',
    );
    await _enterPilotResponse(
      tester,
      specId: 'wag-carried',
      text: 'one remembered gift.',
    );

    expect(find.byKey(kMaatFlowResponseJournalPreviewKey), findsOneWidget);
    expect(find.text('Journal preview'), findsOneWidget);
    expect(
      find.text(
        'The Wag: I kept table and legacy at the table and carried one remembered gift forward.',
      ),
      findsOneWidget,
    );
    expect(find.text('Add to journal'), findsOneWidget);
    final addToggle = tester.widget<Checkbox>(find.byType(Checkbox).last);
    expect(addToggle.value, isFalse);
  });

  testWidgets('Wag can suppress journal response body', (tester) async {
    await _setPhoneViewport(tester);
    var document = _journalDocument('Wag manual journal body.');
    final badgeAppends = <String>[];
    final responseWrites = <MaatJournalResponseBlock>[];

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _wagFlowIndex,
        notes: <NoteData>[_wagNote()],
        onAppendToJournal: (text) async => badgeAppends.add(text),
        onWriteJournalResponse: (block) async {
          responseWrites.add(block);
          document = MaatJournalResponseBlockUtils.upsert(document, block);
        },
        onRecordCompletion:
            ({
              required String clientEventId,
              required int flowId,
              required DateTime completedOnDate,
              Map<String, dynamic>? metadata,
            }) async {},
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _wagTitle);
    await _choosePilotOption(
      tester,
      specId: 'wag-remembered',
      optionId: 'name',
    );
    await _enterPilotResponse(
      tester,
      specId: 'wag-carried',
      text: 'private ancestor name and story.',
    );
    await _tapStatus(tester, 'Observed');

    expect(responseWrites, hasLength(1));
    expect(responseWrites.single.text, isEmpty);
    expect(document.toPlainText(), 'Wag manual journal body.');
    expect(MaatJournalResponseBlockUtils.extract(document), isEmpty);
    expect(badgeAppends, hasLength(1));
    expect(JournalBadgeUtils.hasBadges(badgeAppends.single), isTrue);
  });

  testWidgets('Wag completion writes one opted-in response block', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    var document = _journalDocument('Wag journal body stays.');

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _wagFlowIndex,
        notes: <NoteData>[_wagNote()],
        onWriteJournalResponse: (block) async {
          document = MaatJournalResponseBlockUtils.upsert(document, block);
        },
        onRecordCompletion:
            ({
              required String clientEventId,
              required int flowId,
              required DateTime completedOnDate,
              Map<String, dynamic>? metadata,
            }) async {},
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _wagTitle);
    await _choosePilotOption(
      tester,
      specId: 'wag-remembered',
      optionId: 'gift',
    );
    await _enterPilotResponse(
      tester,
      specId: 'wag-carried',
      text: 'one remembered gift.',
    );
    await _toggleOfferJournalWrite(tester);
    await _tapStatus(tester, 'Observed');

    final blocks = MaatJournalResponseBlockUtils.extract(document);
    expect(blocks, hasLength(1));
    expect(document.toPlainText(), contains('Wag journal body stays.'));
    expect(
      blocks.single.text,
      'The Wag: I kept gift at the table and carried one remembered gift forward.',
    );
  });

  testWidgets('Wag repeat completion updates one opted-in response block', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    var document = _journalDocument('Existing Wag journal text.');

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _wagFlowIndex,
        notes: <NoteData>[_wagNote()],
        onWriteJournalResponse: (block) async {
          document = MaatJournalResponseBlockUtils.upsert(document, block);
        },
        onRecordCompletion:
            ({
              required String clientEventId,
              required int flowId,
              required DateTime completedOnDate,
              Map<String, dynamic>? metadata,
            }) async {},
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _wagTitle);
    await _choosePilotOption(
      tester,
      specId: 'wag-remembered',
      optionId: 'story',
    );
    await _enterPilotResponse(
      tester,
      specId: 'wag-carried',
      text: 'the first remembered story.',
    );
    await _toggleOfferJournalWrite(tester);
    await _tapStatus(tester, 'Observed');

    await _enterPilotResponse(
      tester,
      specId: 'wag-carried',
      text: 'the updated remembered story.',
    );
    await _tapStatus(tester, 'Observed');

    final blocks = MaatJournalResponseBlockUtils.extract(document);
    expect(blocks, hasLength(1));
    expect(
      blocks.single.text,
      'The Wag: I kept story at the table and carried the updated remembered story forward.',
    );
    expect(document.toPlainText(), contains('Existing Wag journal text.'));
    expect(document.toPlainText().split('The Wag:').length - 1, 1);
  });

  testWidgets('Wag local values hydrate and clearing remains local', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    final prefs = await SharedPreferences.getInstance();
    final store = TheWagLocalStore(prefs: prefs);
    await store.savePromptText(
      _wagFlowId,
      WagLocalPromptKind.ancestorNames,
      'Ancestor One\nPractice ancestor - elder',
    );
    await store.saveWagFocusName(_wagFlowId, 'Family table');
    await store.saveNextWagDateIso(_wagFlowId, '2027-07-26');

    await tester.pumpWidget(
      _DayViewHarness(flowIndex: _wagFlowIndex, notes: <NoteData>[_wagNote()]),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _wagTitle);
    await _pumpUntil(
      tester,
      () => find.textContaining('Ancestor One').evaluate().isNotEmpty,
    );
    expect(find.text('Ancestor names'), findsOneWidget);
    expect(find.textContaining('Ancestor One'), findsOneWidget);
    expect(find.textContaining('Practice ancestor - elder'), findsOneWidget);
    expect(await store.loadAncestorNames(_wagFlowId), hasLength(2));
    expect(await store.loadWagFocusName(_wagFlowId), 'Family table');
    expect(await store.loadNextWagDateIso(_wagFlowId), '2027-07-26');

    final clear = find.widgetWithText(OutlinedButton, 'Clear').last;
    await tester.ensureVisible(clear);
    await tester.tap(clear);
    await _pumpInteraction(tester);

    expect(
      prefs.getString('the_wag_${_wagFlowId}_prompt_ancestor_names'),
      isNull,
    );
    expect(prefs.getString('the_wag_${_wagFlowId}_ancestor_names'), isNull);
    expect(await store.loadWagFocusName(_wagFlowId), 'Family table');
    expect(await store.loadNextWagDateIso(_wagFlowId), '2027-07-26');
  });

  testWidgets('Khat response renders with default-off journal offer', (
    tester,
  ) async {
    await _setPhoneViewport(tester);

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _khatFlowIndex,
        notes: <NoteData>[_khatNote()],
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _khatTitle);

    expect(find.byKey(kMaatFlowResponseSectionKey), findsOneWidget);
    expect(find.text('What did the body ask for?'), findsOneWidget);
    expect(find.text('What care did you give the body?'), findsOneWidget);
    for (final optionId in const <String>['water', 'rest', 'sleep']) {
      expect(
        find.byKey(maatFlowResponseFieldKey('khat-body-asked:$optionId')),
        findsOneWidget,
      );
    }

    await _choosePilotOption(
      tester,
      specId: 'khat-body-asked',
      optionId: 'water',
    );
    await _choosePilotOption(
      tester,
      specId: 'khat-body-asked',
      optionId: 'rest',
    );
    await _enterPilotResponse(
      tester,
      specId: 'khat-care-given',
      text: 'one honest act of care.',
    );

    expect(find.byKey(kMaatFlowResponseJournalPreviewKey), findsOneWidget);
    expect(
      find.text(
        'The Khat: I listened to the body asking for water and rest and answered with one honest act of care.',
      ),
      findsOneWidget,
    );
    final addToggle = tester.widget<Checkbox>(find.byType(Checkbox).last);
    expect(addToggle.value, isFalse);
  });

  testWidgets('Khat can suppress journal response body', (tester) async {
    await _setPhoneViewport(tester);
    var document = _journalDocument('Khat manual journal body.');
    final badgeAppends = <String>[];
    final responseWrites = <MaatJournalResponseBlock>[];

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _khatFlowIndex,
        notes: <NoteData>[_khatNote()],
        onAppendToJournal: (text) async => badgeAppends.add(text),
        onWriteJournalResponse: (block) async {
          responseWrites.add(block);
          document = MaatJournalResponseBlockUtils.upsert(document, block);
        },
        onRecordCompletion:
            ({
              required String clientEventId,
              required int flowId,
              required DateTime completedOnDate,
              Map<String, dynamic>? metadata,
            }) async {},
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _khatTitle);
    await _choosePilotOption(
      tester,
      specId: 'khat-body-asked',
      optionId: 'sleep',
    );
    await _enterPilotResponse(
      tester,
      specId: 'khat-care-given',
      text: 'private body detail.',
    );
    await _tapStatus(tester, 'Observed');

    expect(responseWrites, hasLength(1));
    expect(responseWrites.single.text, isEmpty);
    expect(document.toPlainText(), 'Khat manual journal body.');
    expect(MaatJournalResponseBlockUtils.extract(document), isEmpty);
    expect(badgeAppends, hasLength(1));
    expect(JournalBadgeUtils.hasBadges(badgeAppends.single), isTrue);
  });

  testWidgets('Khat completion writes one opted-in response block', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    var document = _journalDocument('Khat journal body stays.');

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _khatFlowIndex,
        notes: <NoteData>[_khatNote()],
        onWriteJournalResponse: (block) async {
          document = MaatJournalResponseBlockUtils.upsert(document, block);
        },
        onRecordCompletion:
            ({
              required String clientEventId,
              required int flowId,
              required DateTime completedOnDate,
              Map<String, dynamic>? metadata,
            }) async {},
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _khatTitle);
    await _choosePilotOption(
      tester,
      specId: 'khat-body-asked',
      optionId: 'breath',
    );
    await _enterPilotResponse(
      tester,
      specId: 'khat-care-given',
      text: 'five slow breaths.',
    );
    await _toggleOfferJournalWrite(tester);
    await _tapStatus(tester, 'Observed');

    final blocks = MaatJournalResponseBlockUtils.extract(document);
    expect(blocks, hasLength(1));
    expect(document.toPlainText(), contains('Khat journal body stays.'));
    expect(
      blocks.single.text,
      'The Khat: I listened to the body asking for breath and answered with five slow breaths.',
    );
  });

  testWidgets('Khat repeat completion updates one opted-in response block', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    var document = _journalDocument('Existing Khat journal text.');

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _khatFlowIndex,
        notes: <NoteData>[_khatNote()],
        onWriteJournalResponse: (block) async {
          document = MaatJournalResponseBlockUtils.upsert(document, block);
        },
        onRecordCompletion:
            ({
              required String clientEventId,
              required int flowId,
              required DateTime completedOnDate,
              Map<String, dynamic>? metadata,
            }) async {},
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _khatTitle);
    await _choosePilotOption(
      tester,
      specId: 'khat-body-asked',
      optionId: 'care',
    );
    await _enterPilotResponse(
      tester,
      specId: 'khat-care-given',
      text: 'the first body-care note.',
    );
    await _toggleOfferJournalWrite(tester);
    await _tapStatus(tester, 'Observed');

    await _enterPilotResponse(
      tester,
      specId: 'khat-care-given',
      text: 'the updated body-care note.',
    );
    await _tapStatus(tester, 'Observed');

    final blocks = MaatJournalResponseBlockUtils.extract(document);
    expect(blocks, hasLength(1));
    expect(
      blocks.single.text,
      'The Khat: I listened to the body asking for care and answered with the updated body-care note.',
    );
    expect(document.toPlainText(), contains('Existing Khat journal text.'));
    expect(document.toPlainText().split('The Khat:').length - 1, 1);
  });

  testWidgets('Khat existing special completion status remains intact', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    final moveEvent = _khatDefinition.events.singleWhere(
      (event) => event.extraCompletionStatusLabels.containsKey('moved'),
    );

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _khatFlowIndex,
        notes: <NoteData>[_khatNote(event: moveEvent)],
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(
      tester,
      maatDecanFlowEventTitle(_khatDefinition, moveEvent),
    );

    expect(find.byKey(kMaatFlowResponseSectionKey), findsOneWidget);
    expect(find.text('Moved'), findsWidgets);
  });

  testWidgets('Oracle response renders with default-off journal offer', (
    tester,
  ) async {
    await _setPhoneViewport(tester);

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _oracleFlowIndex,
        notes: <NoteData>[_oracleNote()],
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _oracleTitle);

    expect(find.byKey(kMaatFlowResponseSectionKey), findsOneWidget);
    expect(find.text('What question did you carry?'), findsOneWidget);
    expect(find.text('What shape did the sign take?'), findsOneWidget);
    expect(
      find.text('What did you receive, without forcing meaning too early?'),
      findsOneWidget,
    );
    for (final optionId in const <String>['dream', 'image', 'action']) {
      expect(
        find.byKey(maatFlowResponseFieldKey('oracle-sign-shape:$optionId')),
        findsOneWidget,
      );
    }

    await _enterPilotResponse(
      tester,
      specId: 'oracle-question-carried',
      text: 'What did the private dream mean?',
    );
    await _choosePilotOption(
      tester,
      specId: 'oracle-sign-shape',
      optionId: 'dream',
    );
    await _choosePilotOption(
      tester,
      specId: 'oracle-sign-shape',
      optionId: 'image',
    );
    await _enterPilotResponse(
      tester,
      specId: 'oracle-received',
      text: 'raw dream image with a private name.',
    );

    expect(find.byKey(kMaatFlowResponseJournalPreviewKey), findsOneWidget);
    expect(
      find.text(
        'The Oracle: I received one sign through dream and image and will test it through grounded action.',
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(kMaatFlowResponseJournalPreviewKey),
        matching: find.textContaining('private name'),
      ),
      findsNothing,
    );
    final addToggle = tester.widget<Checkbox>(find.byType(Checkbox).last);
    expect(addToggle.value, isFalse);
  });

  testWidgets('Oracle can suppress journal response body', (tester) async {
    await _setPhoneViewport(tester);
    var document = _journalDocument('Oracle manual journal body.');
    final badgeAppends = <String>[];
    final responseWrites = <MaatJournalResponseBlock>[];

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _oracleFlowIndex,
        notes: <NoteData>[_oracleNote()],
        onAppendToJournal: (text) async => badgeAppends.add(text),
        onWriteJournalResponse: (block) async {
          responseWrites.add(block);
          document = MaatJournalResponseBlockUtils.upsert(document, block);
        },
        onRecordCompletion:
            ({
              required String clientEventId,
              required int flowId,
              required DateTime completedOnDate,
              Map<String, dynamic>? metadata,
            }) async {},
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _oracleTitle);
    await _choosePilotOption(
      tester,
      specId: 'oracle-sign-shape',
      optionId: 'warning',
    );
    await _enterPilotResponse(
      tester,
      specId: 'oracle-received',
      text: 'raw disturbing dream detail.',
    );
    await _tapStatus(tester, 'Observed');

    expect(responseWrites, hasLength(1));
    expect(responseWrites.single.text, isEmpty);
    expect(document.toPlainText(), 'Oracle manual journal body.');
    expect(MaatJournalResponseBlockUtils.extract(document), isEmpty);
    expect(badgeAppends, hasLength(1));
    expect(JournalBadgeUtils.hasBadges(badgeAppends.single), isTrue);
  });

  testWidgets('Oracle completion writes one opted-in safe response block', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    var document = _journalDocument('Oracle journal body stays.');

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _oracleFlowIndex,
        notes: <NoteData>[_oracleNote()],
        onWriteJournalResponse: (block) async {
          document = MaatJournalResponseBlockUtils.upsert(document, block);
        },
        onRecordCompletion:
            ({
              required String clientEventId,
              required int flowId,
              required DateTime completedOnDate,
              Map<String, dynamic>? metadata,
            }) async {},
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _oracleTitle);
    await _choosePilotOption(
      tester,
      specId: 'oracle-sign-shape',
      optionId: 'invitation',
    );
    await _enterPilotResponse(
      tester,
      specId: 'oracle-received',
      text: 'a private dream sentence.',
    );
    await _toggleOfferJournalWrite(tester);
    await _tapStatus(tester, 'Observed');

    final blocks = MaatJournalResponseBlockUtils.extract(document);
    expect(blocks, hasLength(1));
    expect(document.toPlainText(), contains('Oracle journal body stays.'));
    expect(
      blocks.single.text,
      'The Oracle: I received one sign through invitation and will test it through grounded action.',
    );
    expect(blocks.single.text, isNot(contains('private dream')));
  });

  testWidgets('Oracle repeat completion updates one safe response block', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    var document = _journalDocument('Existing Oracle journal text.');

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _oracleFlowIndex,
        notes: <NoteData>[_oracleNote()],
        onWriteJournalResponse: (block) async {
          document = MaatJournalResponseBlockUtils.upsert(document, block);
        },
        onRecordCompletion:
            ({
              required String clientEventId,
              required int flowId,
              required DateTime completedOnDate,
              Map<String, dynamic>? metadata,
            }) async {},
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _oracleTitle);
    await _choosePilotOption(
      tester,
      specId: 'oracle-sign-shape',
      optionId: 'dream',
    );
    await _enterPilotResponse(
      tester,
      specId: 'oracle-received',
      text: 'first private oracle detail.',
    );
    await _toggleOfferJournalWrite(tester);
    await _tapStatus(tester, 'Observed');

    await _choosePilotOption(
      tester,
      specId: 'oracle-sign-shape',
      optionId: 'action',
    );
    await _enterPilotResponse(
      tester,
      specId: 'oracle-received',
      text: 'updated private oracle detail.',
    );
    await _tapStatus(tester, 'Observed');

    final blocks = MaatJournalResponseBlockUtils.extract(document);
    expect(blocks, hasLength(1));
    expect(
      blocks.single.text,
      'The Oracle: I received one sign through dream and action and will test it through grounded action.',
    );
    expect(document.toPlainText(), contains('Existing Oracle journal text.'));
    expect(document.toPlainText(), isNot(contains('first private')));
    expect(document.toPlainText(), isNot(contains('updated private')));
  });

  testWidgets('Wandering response renders with default-off journal offer', (
    tester,
  ) async {
    await _setPhoneViewport(tester);

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _wanderingFlowIndex,
        notes: <NoteData>[_wanderingNote()],
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _wanderingTitle);

    expect(find.byKey(kMaatFlowResponseSectionKey), findsOneWidget);
    expect(find.text('What remains with you?'), findsOneWidget);
    expect(find.text('What did you find in the wandering?'), findsOneWidget);
    for (final optionId in const <String>['loss', 'support', 'return']) {
      expect(
        find.byKey(maatFlowResponseFieldKey('wandering-remains:$optionId')),
        findsOneWidget,
      );
    }

    await _choosePilotOption(
      tester,
      specId: 'wandering-remains',
      optionId: 'loss',
    );
    await _choosePilotOption(
      tester,
      specId: 'wandering-remains',
      optionId: 'support',
    );
    await _enterPilotResponse(
      tester,
      specId: 'wandering-found',
      text: 'raw grief language with a private name.',
    );

    expect(find.byKey(kMaatFlowResponseJournalPreviewKey), findsOneWidget);
    expect(
      find.text(
        'The Wandering: I honored loss and support and noticed one thing that remains.',
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(kMaatFlowResponseJournalPreviewKey),
        matching: find.textContaining('private name'),
      ),
      findsNothing,
    );
    final addToggle = tester.widget<Checkbox>(find.byType(Checkbox).last);
    expect(addToggle.value, isFalse);
  });

  testWidgets('Wandering can suppress journal response body', (tester) async {
    await _setPhoneViewport(tester);
    var document = _journalDocument('Wandering manual journal body.');
    final badgeAppends = <String>[];
    final responseWrites = <MaatJournalResponseBlock>[];

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _wanderingFlowIndex,
        notes: <NoteData>[_wanderingNote()],
        onAppendToJournal: (text) async => badgeAppends.add(text),
        onWriteJournalResponse: (block) async {
          responseWrites.add(block);
          document = MaatJournalResponseBlockUtils.upsert(document, block);
        },
        onRecordCompletion:
            ({
              required String clientEventId,
              required int flowId,
              required DateTime completedOnDate,
              Map<String, dynamic>? metadata,
            }) async {},
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _wanderingTitle);
    await _choosePilotOption(
      tester,
      specId: 'wandering-remains',
      optionId: 'memory',
    );
    await _enterPilotResponse(
      tester,
      specId: 'wandering-found',
      text: 'raw grief detail.',
    );
    await _tapStatus(tester, 'Observed');

    expect(responseWrites, hasLength(1));
    expect(responseWrites.single.text, isEmpty);
    expect(document.toPlainText(), 'Wandering manual journal body.');
    expect(MaatJournalResponseBlockUtils.extract(document), isEmpty);
    expect(badgeAppends, hasLength(1));
    expect(JournalBadgeUtils.hasBadges(badgeAppends.single), isTrue);
  });

  testWidgets('Wandering completion writes one opted-in safe response block', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    var document = _journalDocument('Wandering journal body stays.');

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _wanderingFlowIndex,
        notes: <NoteData>[_wanderingNote()],
        onWriteJournalResponse: (block) async {
          document = MaatJournalResponseBlockUtils.upsert(document, block);
        },
        onRecordCompletion:
            ({
              required String clientEventId,
              required int flowId,
              required DateTime completedOnDate,
              Map<String, dynamic>? metadata,
            }) async {},
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _wanderingTitle);
    await _choosePilotOption(
      tester,
      specId: 'wandering-remains',
      optionId: 'capacity',
    );
    await _enterPilotResponse(
      tester,
      specId: 'wandering-found',
      text: 'a private grief sentence.',
    );
    await _toggleOfferJournalWrite(tester);
    await _tapStatus(tester, 'Observed');

    final blocks = MaatJournalResponseBlockUtils.extract(document);
    expect(blocks, hasLength(1));
    expect(document.toPlainText(), contains('Wandering journal body stays.'));
    expect(
      blocks.single.text,
      'The Wandering: I honored capacity and noticed one thing that remains.',
    );
    expect(blocks.single.text, isNot(contains('private grief')));
  });

  testWidgets('Wandering repeat completion updates one safe response block', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    var document = _journalDocument('Existing Wandering journal text.');

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _wanderingFlowIndex,
        notes: <NoteData>[_wanderingNote()],
        onWriteJournalResponse: (block) async {
          document = MaatJournalResponseBlockUtils.upsert(document, block);
        },
        onRecordCompletion:
            ({
              required String clientEventId,
              required int flowId,
              required DateTime completedOnDate,
              Map<String, dynamic>? metadata,
            }) async {},
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _wanderingTitle);
    await _choosePilotOption(
      tester,
      specId: 'wandering-remains',
      optionId: 'absence',
    );
    await _enterPilotResponse(
      tester,
      specId: 'wandering-found',
      text: 'first grief detail.',
    );
    await _toggleOfferJournalWrite(tester);
    await _tapStatus(tester, 'Observed');

    await _choosePilotOption(
      tester,
      specId: 'wandering-remains',
      optionId: 'return',
    );
    await _enterPilotResponse(
      tester,
      specId: 'wandering-found',
      text: 'updated grief detail.',
    );
    await _tapStatus(tester, 'Observed');

    final blocks = MaatJournalResponseBlockUtils.extract(document);
    expect(blocks, hasLength(1));
    expect(
      blocks.single.text,
      'The Wandering: I honored absence and return and noticed one thing that remains.',
    );
    expect(
      document.toPlainText(),
      contains('Existing Wandering journal text.'),
    );
    expect(document.toPlainText(), isNot(contains('first grief')));
    expect(document.toPlainText(), isNot(contains('updated grief')));
  });

  testWidgets('Follow the Sky response renders and previews journal text', (
    tester,
  ) async {
    await _setPhoneViewport(tester);

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _trackSkyFlowIndex,
        notes: <NoteData>[_trackSkyNote()],
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _trackSkyEventTitle);

    expect(find.byKey(kMaatFlowResponseSectionKey), findsOneWidget);
    expect(find.text('What did the sky show?'), findsOneWidget);
    expect(find.text('What changed above you?'), findsOneWidget);
    for (final optionId in const <String>['clear', 'horizon', 'change']) {
      expect(
        find.byKey(maatFlowResponseFieldKey('follow-sky-shown:$optionId')),
        findsOneWidget,
      );
    }

    await _choosePilotOption(
      tester,
      specId: 'follow-sky-shown',
      optionId: 'horizon',
    );
    await _choosePilotOption(
      tester,
      specId: 'follow-sky-shown',
      optionId: 'change',
    );
    await _enterPilotResponse(
      tester,
      specId: 'follow-sky-changed',
      text: 'the western horizon change',
    );

    expect(find.byKey(kMaatFlowResponseJournalPreviewKey), findsOneWidget);
    expect(
      find.text(
        'Follow the Sky: I noticed horizon and change and kept the western horizon change.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Follow the Sky completion writes one response block', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    var document = _journalDocument('Sky journal body stays.');

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _trackSkyFlowIndex,
        notes: <NoteData>[_trackSkyNote()],
        onWriteJournalResponse: (block) async {
          document = MaatJournalResponseBlockUtils.upsert(document, block);
        },
        onRecordCompletion:
            ({
              required String clientEventId,
              required int flowId,
              required DateTime completedOnDate,
              Map<String, dynamic>? metadata,
            }) async {},
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _trackSkyEventTitle);
    await _choosePilotOption(
      tester,
      specId: 'follow-sky-shown',
      optionId: 'horizon',
    );
    await _enterPilotResponse(
      tester,
      specId: 'follow-sky-changed',
      text: 'the low color change.',
    );
    await _tapStatus(tester, 'Observed');

    final blocks = MaatJournalResponseBlockUtils.extract(document);
    expect(blocks, hasLength(1));
    expect(document.toPlainText(), contains('Sky journal body stays.'));
    expect(
      blocks.single.text,
      'Follow the Sky: I noticed horizon and kept the low color change.',
    );
  });

  testWidgets('Follow the Sky repeat completion updates one response block', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    var document = _journalDocument('Existing sky journal text.');

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _trackSkyFlowIndex,
        notes: <NoteData>[_trackSkyNote()],
        onWriteJournalResponse: (block) async {
          document = MaatJournalResponseBlockUtils.upsert(document, block);
        },
        onRecordCompletion:
            ({
              required String clientEventId,
              required int flowId,
              required DateTime completedOnDate,
              Map<String, dynamic>? metadata,
            }) async {},
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _trackSkyEventTitle);
    await _choosePilotOption(
      tester,
      specId: 'follow-sky-shown',
      optionId: 'moon',
    );
    await _enterPilotResponse(
      tester,
      specId: 'follow-sky-changed',
      text: 'first sky line.',
    );
    await _tapStatus(tester, 'Observed');

    await _choosePilotOption(
      tester,
      specId: 'follow-sky-shown',
      optionId: 'planet',
    );
    await _enterPilotResponse(
      tester,
      specId: 'follow-sky-changed',
      text: 'updated sky line.',
    );
    await _tapStatus(tester, 'Observed');

    final blocks = MaatJournalResponseBlockUtils.extract(document);
    expect(blocks, hasLength(1));
    expect(
      blocks.single.text,
      'Follow the Sky: I noticed moon and planet and kept updated sky line.',
    );
    expect(document.toPlainText(), contains('Existing sky journal text.'));
    expect(document.toPlainText(), isNot(contains('first sky line')));
  });

  testWidgets('The Weighing response renders with default-off journal offer', (
    tester,
  ) async {
    await _setPhoneViewport(tester);

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _weighingFlowIndex,
        notes: <NoteData>[_weighingNote()],
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _weighingTitle);

    expect(find.byKey(kMaatFlowResponseSectionKey), findsOneWidget);
    expect(find.text('What did the scale reveal?'), findsOneWidget);
    expect(
      find.text('What record, number, or correction needs to be witnessed?'),
      findsOneWidget,
    );
    for (final optionId in const <String>['record', 'correction', 'truth']) {
      expect(
        find.byKey(
          maatFlowResponseFieldKey('weighing-scale-revealed:$optionId'),
        ),
        findsOneWidget,
      );
    }

    await _choosePilotOption(
      tester,
      specId: 'weighing-scale-revealed',
      optionId: 'record',
    );
    await _choosePilotOption(
      tester,
      specId: 'weighing-scale-revealed',
      optionId: 'correction',
    );
    await _enterPilotResponse(
      tester,
      specId: 'weighing-record-witnessed',
      text: 'private money number and conflict detail.',
    );

    expect(find.byKey(kMaatFlowResponseJournalPreviewKey), findsOneWidget);
    expect(
      find.text(
        'The Weighing: I placed record and correction on the scale and named one correction.',
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(kMaatFlowResponseJournalPreviewKey),
        matching: find.textContaining('money number'),
      ),
      findsNothing,
    );
    final addToggle = tester.widget<Checkbox>(find.byType(Checkbox).last);
    expect(addToggle.value, isFalse);
  });

  testWidgets('The Weighing can suppress journal response body', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    var document = _journalDocument('Weighing manual journal body.');
    final badgeAppends = <String>[];
    final responseWrites = <MaatJournalResponseBlock>[];

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _weighingFlowIndex,
        notes: <NoteData>[_weighingNote()],
        onAppendToJournal: (text) async => badgeAppends.add(text),
        onWriteJournalResponse: (block) async {
          responseWrites.add(block);
          document = MaatJournalResponseBlockUtils.upsert(document, block);
        },
        onRecordCompletion:
            ({
              required String clientEventId,
              required int flowId,
              required DateTime completedOnDate,
              Map<String, dynamic>? metadata,
            }) async {},
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _weighingTitle);
    await _choosePilotOption(
      tester,
      specId: 'weighing-scale-revealed',
      optionId: 'debt',
    );
    await _enterPilotResponse(
      tester,
      specId: 'weighing-record-witnessed',
      text: 'private amount owed.',
    );
    await _tapStatus(tester, 'Observed');

    expect(responseWrites, hasLength(1));
    expect(responseWrites.single.text, isEmpty);
    expect(document.toPlainText(), 'Weighing manual journal body.');
    expect(MaatJournalResponseBlockUtils.extract(document), isEmpty);
    expect(badgeAppends, hasLength(1));
    expect(JournalBadgeUtils.hasBadges(badgeAppends.single), isTrue);
  });

  testWidgets(
    'The Weighing completion writes one opted-in safe response block',
    (tester) async {
      await _setPhoneViewport(tester);
      var document = _journalDocument('Weighing journal body stays.');

      await tester.pumpWidget(
        _DayViewHarness(
          flowIndex: _weighingFlowIndex,
          notes: <NoteData>[_weighingNote()],
          onWriteJournalResponse: (block) async {
            document = MaatJournalResponseBlockUtils.upsert(document, block);
          },
          onRecordCompletion:
              ({
                required String clientEventId,
                required int flowId,
                required DateTime completedOnDate,
                Map<String, dynamic>? metadata,
              }) async {},
        ),
      );
      await tester.pumpAndSettle();

      await _openDetailSheet(tester, _weighingTitle);
      await _choosePilotOption(
        tester,
        specId: 'weighing-scale-revealed',
        optionId: 'truth',
      );
      await _enterPilotResponse(
        tester,
        specId: 'weighing-record-witnessed',
        text: 'private ledger sentence.',
      );
      await _toggleOfferJournalWrite(tester);
      await _tapStatus(tester, 'Partly');

      final blocks = MaatJournalResponseBlockUtils.extract(document);
      expect(blocks, hasLength(1));
      expect(document.toPlainText(), contains('Weighing journal body stays.'));
      expect(
        blocks.single.text,
        'The Weighing: I placed truth on the scale and named one correction.',
      );
      expect(blocks.single.text, isNot(contains('private ledger')));
    },
  );

  testWidgets('The Weighing repeat completion updates one safe response block', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    var document = _journalDocument('Existing Weighing journal text.');

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _weighingFlowIndex,
        notes: <NoteData>[_weighingNote()],
        onWriteJournalResponse: (block) async {
          document = MaatJournalResponseBlockUtils.upsert(document, block);
        },
        onRecordCompletion:
            ({
              required String clientEventId,
              required int flowId,
              required DateTime completedOnDate,
              Map<String, dynamic>? metadata,
            }) async {},
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _weighingTitle);
    await _choosePilotOption(
      tester,
      specId: 'weighing-scale-revealed',
      optionId: 'record',
    );
    await _enterPilotResponse(
      tester,
      specId: 'weighing-record-witnessed',
      text: 'first private ledger detail.',
    );
    await _toggleOfferJournalWrite(tester);
    await _tapStatus(tester, 'Observed');

    await _choosePilotOption(
      tester,
      specId: 'weighing-scale-revealed',
      optionId: 'correction',
    );
    await _enterPilotResponse(
      tester,
      specId: 'weighing-record-witnessed',
      text: 'updated private ledger detail.',
    );
    await _tapStatus(tester, 'Observed');

    final blocks = MaatJournalResponseBlockUtils.extract(document);
    expect(blocks, hasLength(1));
    expect(
      blocks.single.text,
      'The Weighing: I placed record and correction on the scale and named one correction.',
    );
    expect(document.toPlainText(), contains('Existing Weighing journal text.'));
    expect(document.toPlainText(), isNot(contains('first private')));
    expect(document.toPlainText(), isNot(contains('updated private')));
  });

  testWidgets('First Arrangement response renders and previews journal text', (
    tester,
  ) async {
    await _setPhoneViewport(tester);

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _firstArrangementFlowIndex,
        notes: <NoteData>[_firstArrangementNote()],
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _firstArrangementTitle);

    expect(find.byKey(kMaatFlowResponseSectionKey), findsOneWidget);
    expect(find.text('What did you put in order?'), findsOneWidget);
    expect(find.text('What changed in the space?'), findsOneWidget);
    for (final optionId in const <String>['cleared', 'made_visible']) {
      expect(
        find.byKey(
          maatFlowResponseFieldKey('first-arrangement-ordered:$optionId'),
        ),
        findsOneWidget,
      );
    }

    await _choosePilotOption(
      tester,
      specId: 'first-arrangement-ordered',
      optionId: 'cleared',
    );
    await _choosePilotOption(
      tester,
      specId: 'first-arrangement-ordered',
      optionId: 'made_visible',
    );
    await _enterPilotResponse(
      tester,
      specId: 'first-arrangement-space-changed',
      text: 'the entry shelf',
    );

    expect(find.byKey(kMaatFlowResponseJournalPreviewKey), findsOneWidget);
    expect(
      find.text(
        'The First Arrangement: I put cleared and made visible into order and made the entry shelf visible.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('First Arrangement repeat completion updates one response block', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    var document = _journalDocument('First Arrangement journal text.');

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _firstArrangementFlowIndex,
        notes: <NoteData>[_firstArrangementNote()],
        onWriteJournalResponse: (block) async {
          document = MaatJournalResponseBlockUtils.upsert(document, block);
        },
        onRecordCompletion:
            ({
              required String clientEventId,
              required int flowId,
              required DateTime completedOnDate,
              Map<String, dynamic>? metadata,
            }) async {},
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _firstArrangementTitle);
    await _choosePilotOption(
      tester,
      specId: 'first-arrangement-ordered',
      optionId: 'arranged',
    );
    await _enterPilotResponse(
      tester,
      specId: 'first-arrangement-space-changed',
      text: 'the desk surface',
    );
    await _tapStatus(tester, 'Observed');

    await _choosePilotOption(
      tester,
      specId: 'first-arrangement-ordered',
      optionId: 'returned',
    );
    await _enterPilotResponse(
      tester,
      specId: 'first-arrangement-space-changed',
      text: 'the desk and tray',
    );
    await _tapStatus(tester, 'Observed');

    final blocks = MaatJournalResponseBlockUtils.extract(document);
    expect(blocks, hasLength(1));
    expect(
      blocks.single.text,
      'The First Arrangement: I put arranged and returned into order and made the desk and tray visible.',
    );
    expect(document.toPlainText(), contains('First Arrangement journal text.'));
    expect(document.toPlainText(), isNot(contains('the desk surface')));
  });

  testWidgets('Living Pattern response renders and writes one response block', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    var document = _journalDocument('Living Pattern journal body.');

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _livingPatternFlowIndex,
        notes: <NoteData>[_livingPatternNote()],
        onWriteJournalResponse: (block) async {
          document = MaatJournalResponseBlockUtils.upsert(document, block);
        },
        onRecordCompletion:
            ({
              required String clientEventId,
              required int flowId,
              required DateTime completedOnDate,
              Map<String, dynamic>? metadata,
            }) async {},
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _livingPatternTitle);

    expect(find.byKey(kMaatFlowResponseSectionKey), findsOneWidget);
    expect(find.text('What pattern did you observe?'), findsOneWidget);
    expect(find.text('What principle did the pattern teach?'), findsOneWidget);
    await _choosePilotOption(
      tester,
      specId: 'living-pattern-observed',
      optionId: 'growth',
    );
    await _choosePilotOption(
      tester,
      specId: 'living-pattern-observed',
      optionId: 'return',
    );
    await _enterPilotResponse(
      tester,
      specId: 'living-pattern-principle',
      text: 'patient timing',
    );

    expect(
      find.text(
        'The Living Pattern: I observed growth and return and carried patient timing into action.',
      ),
      findsOneWidget,
    );
    await _tapStatus(tester, 'Observed');

    await _choosePilotOption(
      tester,
      specId: 'living-pattern-observed',
      optionId: 'cycle',
    );
    await _enterPilotResponse(
      tester,
      specId: 'living-pattern-principle',
      text: 'cyclical attention',
    );
    await _tapStatus(tester, 'Observed');

    final blocks = MaatJournalResponseBlockUtils.extract(document);
    expect(blocks, hasLength(1));
    expect(
      blocks.single.text,
      'The Living Pattern: I observed growth, return, and cycle and carried cyclical attention into action.',
    );
    expect(document.toPlainText(), contains('Living Pattern journal body.'));
    expect(document.toPlainText(), isNot(contains('patient timing')));
  });

  testWidgets('House of Life response renders and writes one response block', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    var document = _journalDocument('House of Life journal body.');

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _houseOfLifeFlowIndex,
        notes: <NoteData>[_houseOfLifeNote()],
        onWriteJournalResponse: (block) async {
          document = MaatJournalResponseBlockUtils.upsert(document, block);
        },
        onRecordCompletion:
            ({
              required String clientEventId,
              required int flowId,
              required DateTime completedOnDate,
              Map<String, dynamic>? metadata,
            }) async {},
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _houseOfLifeTitle);

    expect(find.byKey(kMaatFlowResponseSectionKey), findsOneWidget);
    expect(find.text('What knowledge became clearer?'), findsOneWidget);
    expect(
      find.text('What did you learn, write, recite, or transmit?'),
      findsOneWidget,
    );
    await _choosePilotOption(
      tester,
      specId: 'house-of-life-clearer',
      optionId: 'question',
    );
    await _choosePilotOption(
      tester,
      specId: 'house-of-life-clearer',
      optionId: 'source',
    );
    await _enterPilotResponse(
      tester,
      specId: 'house-of-life-learned',
      text: 'copying the source note',
    );
    await _tapStatus(tester, 'Observed');

    await _choosePilotOption(
      tester,
      specId: 'house-of-life-clearer',
      optionId: 'application',
    );
    await _enterPilotResponse(
      tester,
      specId: 'house-of-life-learned',
      text: 'transmitting the useful note',
    );
    await _tapStatus(tester, 'Observed');

    final blocks = MaatJournalResponseBlockUtils.extract(document);
    expect(blocks, hasLength(1));
    expect(
      blocks.single.text,
      'The House of Life: I made question, source, and application clearer and preserved transmitting the useful note.',
    );
    expect(document.toPlainText(), contains('House of Life journal body.'));
    expect(document.toPlainText(), isNot(contains('copying the source note')));
  });

  testWidgets('Hotep response offer can suppress and update one safe block', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    var document = _journalDocument('Hotep journal body.');
    final responseWrites = <MaatJournalResponseBlock>[];

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _hotepFlowIndex,
        notes: <NoteData>[_hotepNote()],
        onWriteJournalResponse: (block) async {
          responseWrites.add(block);
          document = MaatJournalResponseBlockUtils.upsert(document, block);
        },
        onRecordCompletion:
            ({
              required String clientEventId,
              required int flowId,
              required DateTime completedOnDate,
              Map<String, dynamic>? metadata,
            }) async {},
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _hotepTitle);

    expect(find.byKey(kMaatFlowResponseSectionKey), findsOneWidget);
    expect(find.text('What cooled into peace?'), findsOneWidget);
    expect(find.text('What did you let be enough tonight?'), findsOneWidget);
    await _choosePilotOption(tester, specId: 'hotep-cooled', optionId: 'given');
    await _enterPilotResponse(
      tester,
      specId: 'hotep-enough-tonight',
      text: 'private obligation detail.',
    );
    expect(
      find.text(
        'Hotep: I named given, let enough be enough, and let the heart cool.',
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(kMaatFlowResponseJournalPreviewKey),
        matching: find.textContaining('private obligation'),
      ),
      findsNothing,
    );
    final addToggle = tester.widget<Checkbox>(find.byType(Checkbox).last);
    expect(addToggle.value, isFalse);

    await _tapStatus(tester, 'Observed');
    expect(responseWrites, hasLength(1));
    expect(responseWrites.single.text, isEmpty);
    expect(MaatJournalResponseBlockUtils.extract(document), isEmpty);
    expect(document.toPlainText(), 'Hotep journal body.');

    await _toggleOfferJournalWrite(tester);
    await _tapStatus(tester, 'Observed');
    var blocks = MaatJournalResponseBlockUtils.extract(document);
    expect(blocks, hasLength(1));
    expect(
      blocks.single.text,
      'Hotep: I named given, let enough be enough, and let the heart cool.',
    );

    await _choosePilotOption(
      tester,
      specId: 'hotep-cooled',
      optionId: 'settled',
    );
    await _enterPilotResponse(
      tester,
      specId: 'hotep-enough-tonight',
      text: 'updated private obligation detail.',
    );
    await _tapStatus(tester, 'Observed');

    blocks = MaatJournalResponseBlockUtils.extract(document);
    expect(blocks, hasLength(1));
    expect(
      blocks.single.text,
      'Hotep: I named given and settled, let enough be enough, and let the heart cool.',
    );
    expect(document.toPlainText(), contains('Hotep journal body.'));
    expect(document.toPlainText(), isNot(contains('private obligation')));
  });

  testWidgets('Shore response offer can suppress and update one safe block', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    var document = _journalDocument('Shore journal body.');
    final responseWrites = <MaatJournalResponseBlock>[];

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _shoreFlowIndex,
        notes: <NoteData>[_shoreNote()],
        onWriteJournalResponse: (block) async {
          responseWrites.add(block);
          document = MaatJournalResponseBlockUtils.upsert(document, block);
        },
        onRecordCompletion:
            ({
              required String clientEventId,
              required int flowId,
              required DateTime completedOnDate,
              Map<String, dynamic>? metadata,
            }) async {},
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _shoreTitle);

    expect(find.byKey(kMaatFlowResponseSectionKey), findsOneWidget);
    expect(find.text('What exchange became honest?'), findsOneWidget);
    expect(
      find.text('What was given, received, or measured clearly?'),
      findsOneWidget,
    );
    await _choosePilotOption(
      tester,
      specId: 'shore-exchange-honest',
      optionId: 'offer',
    );
    await _choosePilotOption(
      tester,
      specId: 'shore-exchange-honest',
      optionId: 'measure',
    );
    await _enterPilotResponse(
      tester,
      specId: 'shore-exchange-measured',
      text: 'private invoice details.',
    );
    expect(
      find.text(
        'The Shore: I brought offer and measure closer to honest measure.',
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(kMaatFlowResponseJournalPreviewKey),
        matching: find.textContaining('private invoice'),
      ),
      findsNothing,
    );
    final addToggle = tester.widget<Checkbox>(find.byType(Checkbox).last);
    expect(addToggle.value, isFalse);

    await _tapStatus(tester, 'Observed');
    expect(responseWrites, hasLength(1));
    expect(responseWrites.single.text, isEmpty);
    expect(MaatJournalResponseBlockUtils.extract(document), isEmpty);
    expect(document.toPlainText(), 'Shore journal body.');

    await _toggleOfferJournalWrite(tester);
    await _tapStatus(tester, 'Observed');
    var blocks = MaatJournalResponseBlockUtils.extract(document);
    expect(blocks, hasLength(1));
    expect(
      blocks.single.text,
      'The Shore: I brought offer and measure closer to honest measure.',
    );

    await _choosePilotOption(
      tester,
      specId: 'shore-exchange-honest',
      optionId: 'accounted',
    );
    await _enterPilotResponse(
      tester,
      specId: 'shore-exchange-measured',
      text: 'updated private invoice details.',
    );
    await _tapStatus(tester, 'Observed');

    blocks = MaatJournalResponseBlockUtils.extract(document);
    expect(blocks, hasLength(1));
    expect(
      blocks.single.text,
      'The Shore: I brought offer, measure, and accounted closer to honest measure.',
    );
    expect(document.toPlainText(), contains('Shore journal body.'));
    expect(document.toPlainText(), isNot(contains('private invoice')));
  });

  testWidgets('Living Text response renders and writes one response block', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    var document = _journalDocument('Living Text journal body.');

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _livingTextFlowIndex,
        notes: <NoteData>[_livingTextNote()],
        onWriteJournalResponse: (block) async {
          document = MaatJournalResponseBlockUtils.upsert(document, block);
        },
        onRecordCompletion:
            ({
              required String clientEventId,
              required int flowId,
              required DateTime completedOnDate,
              Map<String, dynamic>? metadata,
            }) async {},
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _livingTextTitle);

    expect(find.byKey(kMaatFlowResponseSectionKey), findsOneWidget);
    expect(find.text('What did the text add to your life?'), findsOneWidget);
    expect(
      find.text('What did you read, question, connect, or apply?'),
      findsOneWidget,
    );
    await _choosePilotOption(
      tester,
      specId: 'living-text-added',
      optionId: 'question',
    );
    await _choosePilotOption(
      tester,
      specId: 'living-text-added',
      optionId: 'application',
    );
    await _enterPilotResponse(
      tester,
      specId: 'living-text-applied',
      text: 'copying a line into practice',
    );
    expect(
      find.text(
        'The Living Text: I received question and application from the text and added copying a line into practice back to life.',
      ),
      findsOneWidget,
    );
    await _tapStatus(tester, 'Observed');

    await _enterPilotResponse(
      tester,
      specId: 'living-text-applied',
      text: 'testing a line in action',
    );
    await _tapStatus(tester, 'Observed');

    final blocks = MaatJournalResponseBlockUtils.extract(document);
    expect(blocks, hasLength(1));
    expect(
      blocks.single.text,
      'The Living Text: I received question and application from the text and added testing a line in action back to life.',
    );
    expect(document.toPlainText(), contains('Living Text journal body.'));
    expect(
      document.toPlainText(),
      isNot(contains('copying a line into practice')),
    );
  });

  testWidgets('Clearing response offer can suppress and write one safe block', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    var document = _journalDocument('Clearing journal body.');
    final responseWrites = <MaatJournalResponseBlock>[];

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _clearingFlowIndex,
        notes: <NoteData>[_clearingNote()],
        onWriteJournalResponse: (block) async {
          responseWrites.add(block);
          document = MaatJournalResponseBlockUtils.upsert(document, block);
        },
        onRecordCompletion:
            ({
              required String clientEventId,
              required int flowId,
              required DateTime completedOnDate,
              Map<String, dynamic>? metadata,
            }) async {},
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _clearingTitle);

    expect(find.byKey(kMaatFlowResponseSectionKey), findsOneWidget);
    expect(find.text('What cleared before you acted?'), findsOneWidget);
    expect(
      find.text('What changed because you waited before responding?'),
      findsOneWidget,
    );
    await _choosePilotOption(
      tester,
      specId: 'clearing-cleared',
      optionId: 'heat',
    );
    await _choosePilotOption(
      tester,
      specId: 'clearing-cleared',
      optionId: 'pause',
    );
    await _enterPilotResponse(
      tester,
      specId: 'clearing-waited-response',
      text: 'private conflict details.',
    );
    expect(
      find.text(
        'The Clearing: I cleared heat and pause before response and acted from the cleared place.',
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(kMaatFlowResponseJournalPreviewKey),
        matching: find.textContaining('private conflict'),
      ),
      findsNothing,
    );
    final addToggle = tester.widget<Checkbox>(find.byType(Checkbox).last);
    expect(addToggle.value, isFalse);

    await _tapStatus(tester, 'Observed');
    expect(responseWrites, hasLength(1));
    expect(responseWrites.single.text, isEmpty);
    expect(MaatJournalResponseBlockUtils.extract(document), isEmpty);
    expect(document.toPlainText(), 'Clearing journal body.');

    await _toggleOfferJournalWrite(tester);
    await _tapStatus(tester, 'Observed');
    var blocks = MaatJournalResponseBlockUtils.extract(document);
    expect(blocks, hasLength(1));
    expect(
      blocks.single.text,
      'The Clearing: I cleared heat and pause before response and acted from the cleared place.',
    );

    await _choosePilotOption(
      tester,
      specId: 'clearing-cleared',
      optionId: 'breath',
    );
    await _enterPilotResponse(
      tester,
      specId: 'clearing-waited-response',
      text: 'updated private conflict details.',
    );
    await _tapStatus(tester, 'Observed');

    blocks = MaatJournalResponseBlockUtils.extract(document);
    expect(blocks, hasLength(1));
    expect(
      blocks.single.text,
      'The Clearing: I cleared heat, pause, and breath before response and acted from the cleared place.',
    );
    expect(document.toPlainText(), contains('Clearing journal body.'));
    expect(document.toPlainText(), isNot(contains('private conflict')));
  });

  testWidgets('Het-Heru response offer can suppress and update one safe block', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    var document = _journalDocument('Het-Heru journal body.');
    final responseWrites = <MaatJournalResponseBlock>[];

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _hetHeruFlowIndex,
        notes: <NoteData>[_hetHeruNote()],
        onWriteJournalResponse: (block) async {
          responseWrites.add(block);
          document = MaatJournalResponseBlockUtils.upsert(document, block);
        },
        onRecordCompletion:
            ({
              required String clientEventId,
              required int flowId,
              required DateTime completedOnDate,
              Map<String, dynamic>? metadata,
            }) async {},
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _hetHeruTitle);

    expect(find.byKey(kMaatFlowResponseSectionKey), findsOneWidget);
    expect(find.text('What cooled the hot force?'), findsOneWidget);
    expect(
      find.text('What brought the force back toward joy?'),
      findsOneWidget,
    );
    await _choosePilotOption(
      tester,
      specId: 'het-heru-force-cooled',
      optionId: 'music',
    );
    await _choosePilotOption(
      tester,
      specId: 'het-heru-force-cooled',
      optionId: 'beauty',
    );
    await _enterPilotResponse(
      tester,
      specId: 'het-heru-joy-returned',
      text: 'private anger details.',
    );
    expect(
      find.text(
        'Het-Heru: I cooled the hot force with music and beauty and made room for beauty, joy, or rest.',
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(kMaatFlowResponseJournalPreviewKey),
        matching: find.textContaining('private anger'),
      ),
      findsNothing,
    );
    final addToggle = tester.widget<Checkbox>(find.byType(Checkbox).last);
    expect(addToggle.value, isFalse);

    await _tapStatus(tester, 'Observed');
    expect(responseWrites, hasLength(1));
    expect(responseWrites.single.text, isEmpty);
    expect(MaatJournalResponseBlockUtils.extract(document), isEmpty);
    expect(document.toPlainText(), 'Het-Heru journal body.');

    await _toggleOfferJournalWrite(tester);
    await _tapStatus(tester, 'Observed');
    var blocks = MaatJournalResponseBlockUtils.extract(document);
    expect(blocks, hasLength(1));
    expect(
      blocks.single.text,
      'Het-Heru: I cooled the hot force with music and beauty and made room for beauty, joy, or rest.',
    );

    await _choosePilotOption(
      tester,
      specId: 'het-heru-force-cooled',
      optionId: 'food',
    );
    await _enterPilotResponse(
      tester,
      specId: 'het-heru-joy-returned',
      text: 'updated private anger details.',
    );
    await _tapStatus(tester, 'Observed');

    blocks = MaatJournalResponseBlockUtils.extract(document);
    expect(blocks, hasLength(1));
    expect(
      blocks.single.text,
      'Het-Heru: I cooled the hot force with music, beauty, and food and made room for beauty, joy, or rest.',
    );
    expect(document.toPlainText(), contains('Het-Heru journal body.'));
    expect(document.toPlainText(), isNot(contains('private anger')));
  });

  testWidgets('Fair Hearing response offer can suppress and update one safe block', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    var document = _journalDocument('Fair Hearing journal body.');
    final responseWrites = <MaatJournalResponseBlock>[];

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _fairHearingFlowIndex,
        notes: <NoteData>[_fairHearingNote()],
        onWriteJournalResponse: (block) async {
          responseWrites.add(block);
          document = MaatJournalResponseBlockUtils.upsert(document, block);
        },
        onRecordCompletion:
            ({
              required String clientEventId,
              required int flowId,
              required DateTime completedOnDate,
              Map<String, dynamic>? metadata,
            }) async {},
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _fairHearingTitle);

    expect(find.byKey(kMaatFlowResponseSectionKey), findsOneWidget);
    expect(find.text('What did you hear before deciding?'), findsOneWidget);
    expect(
      find.text(
        'What decision, measure, or unheard side needs to be remembered?',
      ),
      findsOneWidget,
    );
    await _choosePilotOption(
      tester,
      specId: 'fair-hearing-heard-before-deciding',
      optionId: 'heard_fully',
    );
    await _choosePilotOption(
      tester,
      specId: 'fair-hearing-heard-before-deciding',
      optionId: 'same_measure',
    );
    await _enterPilotResponse(
      tester,
      specId: 'fair-hearing-remembered',
      text: 'private decision details.',
    );
    expect(
      find.text(
        'The Fair Hearing: I listened before deciding, marked heard fully and same measure, and kept the measure even.',
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(kMaatFlowResponseJournalPreviewKey),
        matching: find.textContaining('private decision'),
      ),
      findsNothing,
    );
    final addToggle = tester.widget<Checkbox>(find.byType(Checkbox).last);
    expect(addToggle.value, isFalse);

    await _tapStatus(tester, 'Observed');
    expect(responseWrites, hasLength(1));
    expect(responseWrites.single.text, isEmpty);
    expect(MaatJournalResponseBlockUtils.extract(document), isEmpty);
    expect(document.toPlainText(), 'Fair Hearing journal body.');

    await _toggleOfferJournalWrite(tester);
    await _tapStatus(tester, 'Observed');
    var blocks = MaatJournalResponseBlockUtils.extract(document);
    expect(blocks, hasLength(1));
    expect(
      blocks.single.text,
      'The Fair Hearing: I listened before deciding, marked heard fully and same measure, and kept the measure even.',
    );

    await _choosePilotOption(
      tester,
      specId: 'fair-hearing-heard-before-deciding',
      optionId: 'repaired',
    );
    await _enterPilotResponse(
      tester,
      specId: 'fair-hearing-remembered',
      text: 'updated private decision details.',
    );
    await _tapStatus(tester, 'Observed');

    blocks = MaatJournalResponseBlockUtils.extract(document);
    expect(blocks, hasLength(1));
    expect(
      blocks.single.text,
      'The Fair Hearing: I listened before deciding, marked heard fully, same measure, and repaired, and kept the measure even.',
    );
    expect(document.toPlainText(), contains('Fair Hearing journal body.'));
    expect(document.toPlainText(), isNot(contains('private decision')));
  });

  testWidgets(
    'Boundary Stone response offer can suppress and update one safe block',
    (tester) async {
      await _setPhoneViewport(tester);
      var document = _journalDocument('Boundary Stone journal body.');
      final responseWrites = <MaatJournalResponseBlock>[];

      await tester.pumpWidget(
        _DayViewHarness(
          flowIndex: _boundaryStoneFlowIndex,
          notes: <NoteData>[_boundaryStoneNote()],
          onWriteJournalResponse: (block) async {
            responseWrites.add(block);
            document = MaatJournalResponseBlockUtils.upsert(document, block);
          },
          onRecordCompletion:
              ({
                required String clientEventId,
                required int flowId,
                required DateTime completedOnDate,
                Map<String, dynamic>? metadata,
              }) async {},
        ),
      );
      await tester.pumpAndSettle();

      await _openDetailSheet(tester, _boundaryStoneTitle);

      expect(find.byKey(kMaatFlowResponseSectionKey), findsOneWidget);
      expect(
        find.text('What boundary marker needed restoring?'),
        findsOneWidget,
      );
      expect(
        find.text('What moved, and what did you restore?'),
        findsOneWidget,
      );
      await _choosePilotOption(
        tester,
        specId: 'boundary-stone-marker-restored',
        optionId: 'labor',
      );
      await _choosePilotOption(
        tester,
        specId: 'boundary-stone-marker-restored',
        optionId: 'ownership',
      );
      await _enterPilotResponse(
        tester,
        specId: 'boundary-stone-restored',
        text: 'private resource dispute.',
      );
      expect(
        find.text(
          'The Boundary Stone: I restored labor and ownership to its rightful place.',
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(kMaatFlowResponseJournalPreviewKey),
          matching: find.textContaining('private resource'),
        ),
        findsNothing,
      );
      final addToggle = tester.widget<Checkbox>(find.byType(Checkbox).last);
      expect(addToggle.value, isFalse);

      await _tapStatus(tester, 'Observed');
      expect(responseWrites, hasLength(1));
      expect(responseWrites.single.text, isEmpty);
      expect(MaatJournalResponseBlockUtils.extract(document), isEmpty);
      expect(document.toPlainText(), 'Boundary Stone journal body.');

      await _toggleOfferJournalWrite(tester);
      await _tapStatus(tester, 'Observed');
      var blocks = MaatJournalResponseBlockUtils.extract(document);
      expect(blocks, hasLength(1));
      expect(
        blocks.single.text,
        'The Boundary Stone: I restored labor and ownership to its rightful place.',
      );

      await _choosePilotOption(
        tester,
        specId: 'boundary-stone-marker-restored',
        optionId: 'returned',
      );
      await _enterPilotResponse(
        tester,
        specId: 'boundary-stone-restored',
        text: 'updated private resource dispute.',
      );
      await _tapStatus(tester, 'Observed');

      blocks = MaatJournalResponseBlockUtils.extract(document);
      expect(blocks, hasLength(1));
      expect(
        blocks.single.text,
        'The Boundary Stone: I restored labor, ownership, and returned to its rightful place.',
      );
      expect(document.toPlainText(), contains('Boundary Stone journal body.'));
      expect(document.toPlainText(), isNot(contains('private resource')));
    },
  );

  testWidgets('Open Mouth response offer can suppress and update one safe block', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    var document = _journalDocument('Open Mouth journal body.');
    final responseWrites = <MaatJournalResponseBlock>[];

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _openMouthFlowIndex,
        notes: <NoteData>[_openMouthNote()],
        onWriteJournalResponse: (block) async {
          responseWrites.add(block);
          document = MaatJournalResponseBlockUtils.upsert(document, block);
        },
        onRecordCompletion:
            ({
              required String clientEventId,
              required int flowId,
              required DateTime completedOnDate,
              Map<String, dynamic>? metadata,
            }) async {},
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, _openMouthTitle);

    expect(find.byKey(kMaatFlowResponseSectionKey), findsOneWidget);
    expect(find.text('What word needed discipline?'), findsOneWidget);
    expect(
      find.text('What needed to be spoken, withheld, repaired, or governed?'),
      findsOneWidget,
    );
    await _choosePilotOption(
      tester,
      specId: 'open-mouth-word-disciplined',
      optionId: 'silence',
    );
    await _choosePilotOption(
      tester,
      specId: 'open-mouth-word-disciplined',
      optionId: 'repair',
    );
    await _enterPilotResponse(
      tester,
      specId: 'open-mouth-governed',
      text: 'private conflict language.',
    );
    expect(
      find.text(
        'The Open Mouth: I governed silence and repair and let speech serve Ma\'at.',
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(kMaatFlowResponseJournalPreviewKey),
        matching: find.textContaining('private conflict'),
      ),
      findsNothing,
    );
    final addToggle = tester.widget<Checkbox>(find.byType(Checkbox).last);
    expect(addToggle.value, isFalse);

    await _tapStatus(tester, 'Observed');
    expect(responseWrites, hasLength(1));
    expect(responseWrites.single.text, isEmpty);
    expect(MaatJournalResponseBlockUtils.extract(document), isEmpty);
    expect(document.toPlainText(), 'Open Mouth journal body.');

    await _toggleOfferJournalWrite(tester);
    await _tapStatus(tester, 'Observed');
    var blocks = MaatJournalResponseBlockUtils.extract(document);
    expect(blocks, hasLength(1));
    expect(
      blocks.single.text,
      'The Open Mouth: I governed silence and repair and let speech serve Ma\'at.',
    );

    await _choosePilotOption(
      tester,
      specId: 'open-mouth-word-disciplined',
      optionId: 'truth',
    );
    await _enterPilotResponse(
      tester,
      specId: 'open-mouth-governed',
      text: 'updated private conflict language.',
    );
    await _tapStatus(tester, 'Observed');

    blocks = MaatJournalResponseBlockUtils.extract(document);
    expect(blocks, hasLength(1));
      expect(
        blocks.single.text,
        'The Open Mouth: I governed silence, repair, and truth and let speech serve Ma\'at.',
      );
    expect(document.toPlainText(), contains('Open Mouth journal body.'));
    expect(document.toPlainText(), isNot(contains('private conflict')));
  });

  testWidgets('unsupported Ma_at flow remains without response fields', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    const title = 'Unsupported Ma\'at practice';

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: const <int, FlowData>{
          90: FlowData(
            id: 90,
            name: 'Unsupported Ma\'at',
            color: Colors.amber,
            active: true,
            notes: 'maat=unsupported-maat-flow',
          ),
        },
        notes: <NoteData>[
          const NoteData(
            clientEventId: 'cid-unsupported-maat',
            title: title,
            detail: 'Unsupported Ma\'at detail.',
            category: 'Unsupported Ma\'at',
            allDay: false,
            start: TimeOfDay(hour: 10, minute: 0),
            end: TimeOfDay(hour: 10, minute: 10),
            flowId: 90,
            behaviorPayload: <String, dynamic>{
              'flow_key': 'unsupported-maat-flow',
              'kind': 'unsupported_maat_flow',
            },
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await _openDetailSheet(tester, title);

    expect(find.byKey(kMaatFlowResponseSectionKey), findsNothing);
    expect(find.text('Observed'), findsWidgets);
    expect(find.text('Partly'), findsWidgets);
    expect(find.text('Skipped'), findsWidgets);
  });
}

const Map<int, FlowData> _moonReturnFlowIndex = <int, FlowData>{
  42: FlowData(
    id: 42,
    name: kMoonReturnTitle,
    color: Colors.indigo,
    active: true,
    notes: 'maat=$kMoonReturnFlowKey',
  ),
};

const Map<int, FlowData> _courseFlowIndex = <int, FlowData>{
  77: FlowData(
    id: 77,
    name: kTheCourseTitle,
    color: Colors.teal,
    active: true,
    notes: 'maat=$kTheCourseFlowKey',
  ),
};

final String _courseTitle = 'Course 1: ${kTheCourseEvents.first.title}';
const int _decanWatchFlowId = 88;
const String _decanWatchTitle = 'Decan Watch: First Decan';
const int _dawnHouseRiteFlowId = 89;
final String _dawnHouseRiteTitle = dawnHouseRiteEventTitle(
  kDawnHouseRiteDays.first,
);
const int _eveningThresholdRiteFlowId = 91;
final String _eveningThresholdRiteTitle = eveningThresholdRiteEventTitle(
  kEveningThresholdRiteDays.first,
);
const int _offeringTableFlowId = 92;
final String _offeringTableTitle = offeringTableEventTitle(
  kOfferingTableDays.first,
);
const int _daysOutsideFlowId = 93;
final DaysOutsideEvent _daysOutsideEvent = kDaysOutsideEvents[1];
final DaysOutsideEvent _wepRonpetEvent = kDaysOutsideEvents.last;
final String _daysOutsideTitle = daysOutsideEventTitle(_daysOutsideEvent);
final String _wepRonpetTitle = daysOutsideEventTitle(_wepRonpetEvent);
const int _openHandFlowId = 94;
final OpenHandEvent _openHandEvent = kOpenHandEvents.first;
final String _openHandTitle = openHandEventTitle(_openHandEvent);
const int _djedFlowId = 95;
final DjedEvent _djedEvent = kDjedEvents.first;
final String _djedTitle = djedEventTitle(_djedEvent);
const int _tendingFlowId = 96;
final TheTendingEvent _tendingEvent = kTheTendingEvents.first;
final String _tendingTitle = theTendingEventTitle(_tendingEvent);
const int _keptWordFlowId = 97;
final KeptWordEvent _keptWordEvent = kKeptWordEvents.first;
final String _keptWordTitle = keptWordEventTitle(_keptWordEvent);
final KeptWordEvent _keptWordConversationEvent = kKeptWordEvents.singleWhere(
  (event) => event.eventNumber == 5,
);
final String _keptWordConversationTitle = keptWordEventTitle(
  _keptWordConversationEvent,
);
const int _wagFlowId = 98;
final WagEvent _wagEvent = kWagEvents.first;
final String _wagTitle = wagEventTitle(_wagEvent);
const int _khatFlowId = 99;
final MaatDecanFlowDefinition _khatDefinition = maatDecanFlowDefinitionForKey(
  kKhatFlowKey,
)!;
final MaatDecanFlowEvent _khatEvent = _khatDefinition.events.first;
final String _khatTitle = maatDecanFlowEventTitle(_khatDefinition, _khatEvent);
const int _oracleFlowId = 100;
final MaatDecanFlowDefinition _oracleDefinition = maatDecanFlowDefinitionForKey(
  kOracleFlowKey,
)!;
final MaatDecanFlowEvent _oracleEvent = _oracleDefinition.events.first;
final String _oracleTitle = maatDecanFlowEventTitle(
  _oracleDefinition,
  _oracleEvent,
);
const int _wanderingFlowId = 101;
final MaatDecanFlowDefinition _wanderingDefinition =
    maatDecanFlowDefinitionForKey(kWanderingFlowKey)!;
final MaatDecanFlowEvent _wanderingEvent = _wanderingDefinition.events.first;
final String _wanderingTitle = maatDecanFlowEventTitle(
  _wanderingDefinition,
  _wanderingEvent,
);
const int _trackSkyFlowId = 102;
const String _trackSkyEventTitle = 'Western Horizon Watch';
const TrackSkyEvent _trackSkyEvent = TrackSkyEvent(
  category: 'Planetary Events',
  title: _trackSkyEventTitle,
  exactLabel: 'June 23, 2026, 8:00 PM PDT',
  scientificBreakdown: 'A bright horizon event.',
  whatToSee: 'A steady light near the western horizon.',
  bestViewing: 'Step outside after sunset and look west.',
  significance: 'Witness the sky without forcing a conclusion.',
  notes: 'Future.',
  schedule: TrackSkyEventSchedule(
    dateIso: '2026-06-23',
    startTime24: '20:00',
    endTime24: '21:00',
    allDay: false,
  ),
);
const int _weighingFlowId = 103;
final TheWeighingEvent _weighingEvent = kTheWeighingEvents.first;
final String _weighingTitle = theWeighingEventTitle(_weighingEvent);
const int _firstArrangementFlowId = 104;
final MaatDecanFlowDefinition _firstArrangementDefinition =
    maatDecanFlowDefinitionForKey(kFirstArrangementFlowKey)!;
final MaatDecanFlowEvent _firstArrangementEvent =
    _firstArrangementDefinition.events.first;
final String _firstArrangementTitle = maatDecanFlowEventTitle(
  _firstArrangementDefinition,
  _firstArrangementEvent,
);
const int _livingPatternFlowId = 105;
final MaatDecanFlowDefinition _livingPatternDefinition =
    maatDecanFlowDefinitionForKey(kLivingPatternFlowKey)!;
final MaatDecanFlowEvent _livingPatternEvent =
    _livingPatternDefinition.events.first;
final String _livingPatternTitle = maatDecanFlowEventTitle(
  _livingPatternDefinition,
  _livingPatternEvent,
);
const int _houseOfLifeFlowId = 106;
final MaatDecanFlowDefinition _houseOfLifeDefinition =
    maatDecanFlowDefinitionForKey(kHouseOfLifeFlowKey)!;
final MaatDecanFlowEvent _houseOfLifeEvent =
    _houseOfLifeDefinition.events.first;
final String _houseOfLifeTitle = maatDecanFlowEventTitle(
  _houseOfLifeDefinition,
  _houseOfLifeEvent,
);
const int _hotepFlowId = 107;
final MaatDecanFlowDefinition _hotepDefinition = maatDecanFlowDefinitionForKey(
  kHotepFlowKey,
)!;
final MaatDecanFlowEvent _hotepEvent = _hotepDefinition.events.first;
final String _hotepTitle = maatDecanFlowEventTitle(
  _hotepDefinition,
  _hotepEvent,
);
const int _shoreFlowId = 108;
final MaatDecanFlowDefinition _shoreDefinition = maatDecanFlowDefinitionForKey(
  kTheShoreFlowKey,
)!;
final MaatDecanFlowEvent _shoreEvent = _shoreDefinition.events.first;
final String _shoreTitle = maatDecanFlowEventTitle(
  _shoreDefinition,
  _shoreEvent,
);
const int _livingTextFlowId = 109;
final MaatDecanFlowDefinition _livingTextDefinition =
    maatDecanFlowDefinitionForKey(kLivingTextFlowKey)!;
final MaatDecanFlowEvent _livingTextEvent = _livingTextDefinition.events.first;
final String _livingTextTitle = maatDecanFlowEventTitle(
  _livingTextDefinition,
  _livingTextEvent,
);
const int _clearingFlowId = 110;
final MaatDecanFlowDefinition _clearingDefinition =
    maatDecanFlowDefinitionForKey(kClearingFlowKey)!;
final MaatDecanFlowEvent _clearingEvent = _clearingDefinition.events.first;
final String _clearingTitle = maatDecanFlowEventTitle(
  _clearingDefinition,
  _clearingEvent,
);
const int _hetHeruFlowId = 111;
final MaatDecanFlowDefinition _hetHeruDefinition =
    maatDecanFlowDefinitionForKey(kHetHeruFlowKey)!;
final MaatDecanFlowEvent _hetHeruEvent = _hetHeruDefinition.events.first;
final String _hetHeruTitle = maatDecanFlowEventTitle(
  _hetHeruDefinition,
  _hetHeruEvent,
);
const int _fairHearingFlowId = 112;
final MaatDecanFlowDefinition _fairHearingDefinition =
    maatDecanFlowDefinitionForKey(kFairHearingFlowKey)!;
final MaatDecanFlowEvent _fairHearingEvent =
    _fairHearingDefinition.events.first;
final String _fairHearingTitle = maatDecanFlowEventTitle(
  _fairHearingDefinition,
  _fairHearingEvent,
);
const int _boundaryStoneFlowId = 113;
final MaatDecanFlowDefinition _boundaryStoneDefinition =
    maatDecanFlowDefinitionForKey(kBoundaryStoneFlowKey)!;
final MaatDecanFlowEvent _boundaryStoneEvent =
    _boundaryStoneDefinition.events.first;
final String _boundaryStoneTitle = maatDecanFlowEventTitle(
  _boundaryStoneDefinition,
  _boundaryStoneEvent,
);
const int _openMouthFlowId = 114;
final MaatDecanFlowDefinition _openMouthDefinition =
    maatDecanFlowDefinitionForKey(kOpenMouthFlowKey)!;
final MaatDecanFlowEvent _openMouthEvent = _openMouthDefinition.events.first;
final String _openMouthTitle = maatDecanFlowEventTitle(
  _openMouthDefinition,
  _openMouthEvent,
);

const Map<int, FlowData> _decanWatchFlowIndex = <int, FlowData>{
  _decanWatchFlowId: FlowData(
    id: _decanWatchFlowId,
    name: kDecanWatchTitle,
    color: Colors.indigo,
    active: true,
    notes: 'maat=$kDecanWatchFlowKey',
  ),
};

const Map<int, FlowData> _dawnHouseRiteFlowIndex = <int, FlowData>{
  _dawnHouseRiteFlowId: FlowData(
    id: _dawnHouseRiteFlowId,
    name: kDawnHouseRiteTitle,
    color: Colors.orange,
    active: true,
    notes: 'maat=$kDawnHouseRiteFlowKey',
  ),
};

const Map<int, FlowData> _eveningThresholdRiteFlowIndex = <int, FlowData>{
  _eveningThresholdRiteFlowId: FlowData(
    id: _eveningThresholdRiteFlowId,
    name: kEveningThresholdRiteTitle,
    color: Colors.deepPurple,
    active: true,
    notes: 'maat=$kEveningThresholdRiteFlowKey',
  ),
};

const Map<int, FlowData> _offeringTableFlowIndex = <int, FlowData>{
  _offeringTableFlowId: FlowData(
    id: _offeringTableFlowId,
    name: kOfferingTableTitle,
    color: Colors.brown,
    active: true,
    notes: 'maat=$kOfferingTableFlowKey',
  ),
};

const Map<int, FlowData> _daysOutsideFlowIndex = <int, FlowData>{
  _daysOutsideFlowId: FlowData(
    id: _daysOutsideFlowId,
    name: kDaysOutsideTheYearTitle,
    color: Colors.blueGrey,
    active: true,
    notes: 'maat=$kDaysOutsideTheYearFlowKey',
  ),
};

const Map<int, FlowData> _openHandFlowIndex = <int, FlowData>{
  _openHandFlowId: FlowData(
    id: _openHandFlowId,
    name: kTheOpenHandTitle,
    color: Colors.orange,
    active: true,
    notes: 'maat=$kTheOpenHandFlowKey',
  ),
};

const Map<int, FlowData> _djedFlowIndex = <int, FlowData>{
  _djedFlowId: FlowData(
    id: _djedFlowId,
    name: kTheDjedTitle,
    color: Colors.green,
    active: true,
    notes: 'maat=$kTheDjedFlowKey',
  ),
};

const Map<int, FlowData> _tendingFlowIndex = <int, FlowData>{
  _tendingFlowId: FlowData(
    id: _tendingFlowId,
    name: kTheTendingTitle,
    color: Colors.purple,
    active: true,
    notes: 'maat=$kTheTendingFlowKey;tending_lens=neutral',
  ),
};

const Map<int, FlowData> _keptWordFlowIndex = <int, FlowData>{
  _keptWordFlowId: FlowData(
    id: _keptWordFlowId,
    name: kKeptWordTitle,
    color: Colors.brown,
    active: true,
    notes: 'maat=$kKeptWordFlowKey;kept_word_lens=neutral',
  ),
};

const Map<int, FlowData> _wagFlowIndex = <int, FlowData>{
  _wagFlowId: FlowData(
    id: _wagFlowId,
    name: kTheWagTitle,
    color: Colors.deepOrange,
    active: true,
    notes: 'maat=$kTheWagFlowKey;wag_lens=neutral',
  ),
};

final Map<int, FlowData> _khatFlowIndex = <int, FlowData>{
  _khatFlowId: FlowData(
    id: _khatFlowId,
    name: kKhatTitle,
    color: Colors.lightBlue,
    active: true,
    notes: 'maat=$kKhatFlowKey;khat_lens=neutral',
  ),
};

final Map<int, FlowData> _oracleFlowIndex = <int, FlowData>{
  _oracleFlowId: FlowData(
    id: _oracleFlowId,
    name: kOracleTitle,
    color: Colors.indigo,
    active: true,
    notes: 'maat=$kOracleFlowKey;oracle_lens=neutral',
  ),
};

final Map<int, FlowData> _wanderingFlowIndex = <int, FlowData>{
  _wanderingFlowId: FlowData(
    id: _wanderingFlowId,
    name: kWanderingTitle,
    color: Colors.blueGrey,
    active: true,
    notes: 'maat=$kWanderingFlowKey;wandering_lens=neutral',
  ),
};

const Map<int, FlowData> _trackSkyFlowIndex = <int, FlowData>{
  _trackSkyFlowId: FlowData(
    id: _trackSkyFlowId,
    name: 'Follow the Sky',
    color: Colors.lightBlue,
    active: true,
    notes: 'maat=track-the-sky',
  ),
};

const Map<int, FlowData> _weighingFlowIndex = <int, FlowData>{
  _weighingFlowId: FlowData(
    id: _weighingFlowId,
    name: kTheWeighingTitle,
    color: Colors.amber,
    active: true,
    notes: 'maat=$kTheWeighingFlowKey;weighing_lens=neutral',
  ),
};

final Map<int, FlowData> _firstArrangementFlowIndex = <int, FlowData>{
  _firstArrangementFlowId: FlowData(
    id: _firstArrangementFlowId,
    name: kFirstArrangementTitle,
    color: Colors.green,
    active: true,
    notes: 'maat=$kFirstArrangementFlowKey',
  ),
};

final Map<int, FlowData> _livingPatternFlowIndex = <int, FlowData>{
  _livingPatternFlowId: FlowData(
    id: _livingPatternFlowId,
    name: kLivingPatternTitle,
    color: Colors.teal,
    active: true,
    notes: 'maat=$kLivingPatternFlowKey',
  ),
};

final Map<int, FlowData> _houseOfLifeFlowIndex = <int, FlowData>{
  _houseOfLifeFlowId: FlowData(
    id: _houseOfLifeFlowId,
    name: kHouseOfLifeTitle,
    color: Colors.indigo,
    active: true,
    notes: 'maat=$kHouseOfLifeFlowKey',
  ),
};

final Map<int, FlowData> _hotepFlowIndex = <int, FlowData>{
  _hotepFlowId: FlowData(
    id: _hotepFlowId,
    name: kHotepTitle,
    color: Colors.blueGrey,
    active: true,
    notes: 'maat=$kHotepFlowKey',
  ),
};

final Map<int, FlowData> _shoreFlowIndex = <int, FlowData>{
  _shoreFlowId: FlowData(
    id: _shoreFlowId,
    name: kTheShoreTitle,
    color: Colors.brown,
    active: true,
    notes: 'maat=$kTheShoreFlowKey',
  ),
};

final Map<int, FlowData> _livingTextFlowIndex = <int, FlowData>{
  _livingTextFlowId: FlowData(
    id: _livingTextFlowId,
    name: kLivingTextTitle,
    color: Colors.indigo,
    active: true,
    notes: 'maat=$kLivingTextFlowKey',
  ),
};

final Map<int, FlowData> _clearingFlowIndex = <int, FlowData>{
  _clearingFlowId: FlowData(
    id: _clearingFlowId,
    name: kClearingTitle,
    color: Colors.teal,
    active: true,
    notes: 'maat=$kClearingFlowKey',
  ),
};

final Map<int, FlowData> _hetHeruFlowIndex = <int, FlowData>{
  _hetHeruFlowId: FlowData(
    id: _hetHeruFlowId,
    name: kHetHeruTitle,
    color: Colors.pink,
    active: true,
    notes: 'maat=$kHetHeruFlowKey',
  ),
};

final Map<int, FlowData> _fairHearingFlowIndex = <int, FlowData>{
  _fairHearingFlowId: FlowData(
    id: _fairHearingFlowId,
    name: kFairHearingTitle,
    color: Colors.deepPurple,
    active: true,
    notes: 'maat=$kFairHearingFlowKey',
  ),
};

final Map<int, FlowData> _boundaryStoneFlowIndex = <int, FlowData>{
  _boundaryStoneFlowId: FlowData(
    id: _boundaryStoneFlowId,
    name: kBoundaryStoneTitle,
    color: Colors.brown,
    active: true,
    notes: 'maat=$kBoundaryStoneFlowKey',
  ),
};

final Map<int, FlowData> _openMouthFlowIndex = <int, FlowData>{
  _openMouthFlowId: FlowData(
    id: _openMouthFlowId,
    name: kOpenMouthTitle,
    color: Colors.orange,
    active: true,
    notes: 'maat=$kOpenMouthFlowKey',
  ),
};

NoteData _moonReturnNote({required MoonReturnEventKind kind}) {
  return NoteData(
    clientEventId: 'cid-moon-return-${kind.key}',
    title: kind.title,
    detail: 'Moon return detail.',
    category: 'Moon Return',
    allDay: false,
    start: const TimeOfDay(hour: 19, minute: 0),
    end: const TimeOfDay(hour: 19, minute: 5),
    flowId: 42,
    behaviorPayload: <String, dynamic>{
      'flow_key': kMoonReturnFlowKey,
      'phase': kind.key,
      'kind': kind.payloadKind,
    },
  );
}

NoteData _courseNote() {
  return NoteData(
    clientEventId: 'cid-the-course-1',
    title: _courseTitle,
    detail: 'Course detail.',
    category: kTheCourseEvents.first.decanSection,
    allDay: false,
    start: const TimeOfDay(hour: 6, minute: 0),
    end: const TimeOfDay(hour: 6, minute: 5),
    flowId: 77,
    behaviorPayload: const <String, dynamic>{
      'flow_key': kTheCourseFlowKey,
      'kind': 'maat_course_event',
      'event_number': 1,
    },
  );
}

NoteData _decanWatchNote() {
  return const NoteData(
    clientEventId: 'cid-the-decan-watch-1',
    title: _decanWatchTitle,
    detail: 'Decan Watch detail.',
    category: kDecanWatchTitle,
    allDay: false,
    start: TimeOfDay(hour: 19, minute: 0),
    end: TimeOfDay(hour: 19, minute: 15),
    flowId: _decanWatchFlowId,
    behaviorPayload: <String, dynamic>{
      'flow_key': kDecanWatchFlowKey,
      'kind': 'maat_decan_watch',
      'global_decan_id': 1,
    },
  );
}

NoteData _dawnHouseRiteNote() {
  final day = kDawnHouseRiteDays.first;
  return NoteData(
    clientEventId: 'cid-dawn-house-rite-1',
    title: _dawnHouseRiteTitle,
    detail: dawnHouseRiteDetailText(
      day,
      discreet: false,
      lens: DawnHouseRiteLens.neutral,
    ),
    category: day.section,
    allDay: false,
    start: const TimeOfDay(hour: 6, minute: 0),
    end: const TimeOfDay(hour: 6, minute: 3),
    flowId: _dawnHouseRiteFlowId,
    behaviorPayload: <String, dynamic>{
      'flow_key': kDawnHouseRiteFlowKey,
      'kind': 'maat_dawn_house_rite_day',
      'day': day.dayNumber,
    },
  );
}

NoteData _eveningThresholdRiteNote() {
  final day = kEveningThresholdRiteDays.first;
  return NoteData(
    clientEventId: 'cid-evening-threshold-rite-1',
    title: _eveningThresholdRiteTitle,
    detail: eveningThresholdRiteDetailText(
      day,
      discreet: false,
      lens: EveningThresholdRiteLens.neutral,
    ),
    category: day.section,
    allDay: false,
    start: const TimeOfDay(hour: 19, minute: 20),
    end: const TimeOfDay(hour: 19, minute: 23),
    flowId: _eveningThresholdRiteFlowId,
    behaviorPayload: <String, dynamic>{
      'flow_key': kEveningThresholdRiteFlowKey,
      'kind': 'maat_evening_threshold_rite_day',
      'day': day.dayNumber,
    },
  );
}

NoteData _offeringTableNote() {
  final day = kOfferingTableDays.first;
  return NoteData(
    clientEventId: 'cid-offering-table-1',
    title: _offeringTableTitle,
    detail: offeringTableDetailText(
      day,
      lens: OfferingTableLens.neutral,
      noCupMode: false,
    ),
    category: day.section,
    allDay: false,
    start: const TimeOfDay(hour: 7, minute: 30),
    end: const TimeOfDay(hour: 7, minute: 33),
    flowId: _offeringTableFlowId,
    behaviorPayload: <String, dynamic>{
      'flow_key': kOfferingTableFlowKey,
      'kind': 'maat_offering_table_day',
      'day': day.dayNumber,
    },
  );
}

NoteData _daysOutsideNote({DaysOutsideEvent? event}) {
  final target = event ?? _daysOutsideEvent;
  return NoteData(
    clientEventId: 'cid-days-outside-${target.eventNumber}',
    title: daysOutsideEventTitle(target),
    detail: daysOutsideDetailText(
      target,
      closingKYear: 1,
      variant: DaysOutsideCopyVariant.standard,
    ),
    category: target.qualityLabel,
    allDay: false,
    start: const TimeOfDay(hour: 6, minute: 0),
    end: const TimeOfDay(hour: 6, minute: 8),
    flowId: _daysOutsideFlowId,
    behaviorPayload: <String, dynamic>{
      'flow_key': kDaysOutsideTheYearFlowKey,
      'kind': 'maat_days_outside_year',
      'event_number': target.eventNumber,
      'event_kind': target.kind.key,
    },
  );
}

NoteData _openHandNote() {
  final event = _openHandEvent;
  return NoteData(
    clientEventId: 'cid-open-hand-${event.eventNumber}',
    title: _openHandTitle,
    detail: openHandDetailText(event, lens: OpenHandLens.neutral),
    category: event.decanSection,
    allDay: false,
    start: const TimeOfDay(hour: 11, minute: 0),
    end: const TimeOfDay(hour: 11, minute: 8),
    flowId: _openHandFlowId,
    behaviorPayload: <String, dynamic>{
      'flow_key': kTheOpenHandFlowKey,
      'kind': 'maat_open_hand_event',
      'event_number': event.eventNumber,
      'flow_day': event.flowDay,
    },
  );
}

NoteData _djedNote() {
  final event = _djedEvent;
  return NoteData(
    clientEventId: 'cid-djed-${event.eventNumber}',
    title: _djedTitle,
    detail: djedDetailText(event, lens: DjedLens.neutral),
    category: event.decanSection,
    allDay: false,
    start: const TimeOfDay(hour: 11, minute: 0),
    end: const TimeOfDay(hour: 11, minute: 10),
    flowId: _djedFlowId,
    behaviorPayload: <String, dynamic>{
      'flow_key': kTheDjedFlowKey,
      'kind': 'maat_djed_event',
      'event_number': event.eventNumber,
      'flow_day': event.flowDay,
    },
  );
}

NoteData _tendingNote({TheTendingEvent? event}) {
  final target = event ?? _tendingEvent;
  return NoteData(
    clientEventId: 'cid-tending-${target.eventNumber}',
    title: theTendingEventTitle(target),
    detail: theTendingDetailText(target, lens: TheTendingLens.neutral),
    category: target.decanSection,
    allDay: false,
    start: const TimeOfDay(hour: 11, minute: 0),
    end: const TimeOfDay(hour: 11, minute: 10),
    flowId: _tendingFlowId,
    behaviorPayload: <String, dynamic>{
      'flow_key': kTheTendingFlowKey,
      'kind': 'maat_the_tending_event',
      'event_number': target.eventNumber,
      'flow_day': target.flowDay,
      'local_prompt': target.localPrompt.key,
    },
  );
}

NoteData _keptWordNote({KeptWordEvent? event}) {
  final target = event ?? _keptWordEvent;
  return NoteData(
    clientEventId: 'cid-kept-word-${target.eventNumber}',
    title: keptWordEventTitle(target),
    detail: keptWordDetailText(target, lens: KeptWordLens.neutral),
    category: target.decanSection,
    allDay: false,
    start: const TimeOfDay(hour: 11, minute: 0),
    end: const TimeOfDay(hour: 11, minute: 10),
    flowId: _keptWordFlowId,
    behaviorPayload: <String, dynamic>{
      'flow_key': kKeptWordFlowKey,
      'kind': 'maat_kept_word_event',
      'event_number': target.eventNumber,
      'flow_day': target.flowDay,
      'local_prompt': target.localPrompt.key,
      'requires_conversation': target.requiresConversation,
    },
  );
}

NoteData _wagNote({WagEvent? event}) {
  final target = event ?? _wagEvent;
  return NoteData(
    clientEventId: 'cid-wag-${target.eventNumber}',
    title: wagEventTitle(target),
    detail: wagDetailText(target, lens: WagLens.neutral),
    category: target.decanSection,
    allDay: false,
    start: const TimeOfDay(hour: 7, minute: 0),
    end: const TimeOfDay(hour: 7, minute: 10),
    flowId: _wagFlowId,
    behaviorPayload: <String, dynamic>{
      'flow_key': kTheWagFlowKey,
      'kind': 'maat_wag_event',
      'event_number': target.eventNumber,
      'local_prompt': target.localPrompt.key,
    },
  );
}

NoteData _khatNote({MaatDecanFlowEvent? event}) {
  final target = event ?? _khatEvent;
  return NoteData(
    clientEventId: 'cid-khat-${target.eventNumber}',
    title: maatDecanFlowEventTitle(_khatDefinition, target),
    detail: maatDecanFlowDetailText(_khatDefinition, target),
    category: target.decanSection,
    allDay: false,
    start: const TimeOfDay(hour: 8, minute: 0),
    end: const TimeOfDay(hour: 8, minute: 8),
    flowId: _khatFlowId,
    behaviorPayload: <String, dynamic>{
      'flow_key': kKhatFlowKey,
      'kind': _khatDefinition.behaviorKind,
      'event_number': target.eventNumber,
      'flow_day': target.flowDay,
      'requires_real_world_action': target.requiresRealWorldAction,
    },
  );
}

NoteData _oracleNote({MaatDecanFlowEvent? event}) {
  final target = event ?? _oracleEvent;
  return NoteData(
    clientEventId: 'cid-oracle-${target.eventNumber}',
    title: maatDecanFlowEventTitle(_oracleDefinition, target),
    detail: maatDecanFlowDetailText(_oracleDefinition, target),
    category: target.decanSection,
    allDay: false,
    start: const TimeOfDay(hour: 9, minute: 0),
    end: const TimeOfDay(hour: 9, minute: 8),
    flowId: _oracleFlowId,
    behaviorPayload: <String, dynamic>{
      'flow_key': kOracleFlowKey,
      'kind': _oracleDefinition.behaviorKind,
      'event_number': target.eventNumber,
      'flow_day': target.flowDay,
      'requires_real_world_action': target.requiresRealWorldAction,
    },
  );
}

NoteData _wanderingNote({MaatDecanFlowEvent? event}) {
  final target = event ?? _wanderingEvent;
  return NoteData(
    clientEventId: 'cid-wandering-${target.eventNumber}',
    title: maatDecanFlowEventTitle(_wanderingDefinition, target),
    detail: maatDecanFlowDetailText(_wanderingDefinition, target),
    category: target.decanSection,
    allDay: false,
    start: const TimeOfDay(hour: 16, minute: 0),
    end: const TimeOfDay(hour: 16, minute: 8),
    flowId: _wanderingFlowId,
    behaviorPayload: <String, dynamic>{
      'flow_key': kWanderingFlowKey,
      'kind': _wanderingDefinition.behaviorKind,
      'event_number': target.eventNumber,
      'flow_day': target.flowDay,
      'requires_real_world_action': target.requiresRealWorldAction,
    },
  );
}

NoteData _trackSkyNote() {
  return NoteData(
    clientEventId: 'cid-track-sky-1',
    title: _trackSkyEventTitle,
    detail: _trackSkyEvent.detailText,
    category: _trackSkyEvent.category,
    allDay: false,
    start: const TimeOfDay(hour: 10, minute: 0),
    end: const TimeOfDay(hour: 10, minute: 10),
    flowId: _trackSkyFlowId,
    behaviorPayload: const <String, dynamic>{
      'flow_key': 'track-the-sky',
      'kind': 'track_sky_event',
    },
  );
}

NoteData _weighingNote({TheWeighingEvent? event}) {
  final target = event ?? _weighingEvent;
  final schedule = theWeighingScheduleForDate(
    target,
    DateTime(2026, 6, 23),
    TrackSkyTimeZone.pacific,
  );
  return NoteData(
    clientEventId: 'cid-weighing-${target.eventNumber}',
    title: theWeighingEventTitle(target),
    detail: theWeighingDetailText(target, lens: TheWeighingLens.neutral),
    category: target.decanSection,
    allDay: false,
    start: const TimeOfDay(hour: 10, minute: 0),
    end: const TimeOfDay(hour: 10, minute: 10),
    flowId: _weighingFlowId,
    behaviorPayload: theWeighingBehaviorPayload(
      event: target,
      schedule: schedule,
      lens: TheWeighingLens.neutral,
    ),
  );
}

NoteData _firstArrangementNote({MaatDecanFlowEvent? event}) {
  return _phase4ADecanNote(
    definition: _firstArrangementDefinition,
    event: event ?? _firstArrangementEvent,
    flowId: _firstArrangementFlowId,
    clientEventPrefix: 'first-arrangement',
  );
}

NoteData _livingPatternNote({MaatDecanFlowEvent? event}) {
  return _phase4ADecanNote(
    definition: _livingPatternDefinition,
    event: event ?? _livingPatternEvent,
    flowId: _livingPatternFlowId,
    clientEventPrefix: 'living-pattern',
  );
}

NoteData _houseOfLifeNote({MaatDecanFlowEvent? event}) {
  return _phase4ADecanNote(
    definition: _houseOfLifeDefinition,
    event: event ?? _houseOfLifeEvent,
    flowId: _houseOfLifeFlowId,
    clientEventPrefix: 'house-of-life',
  );
}

NoteData _hotepNote({MaatDecanFlowEvent? event}) {
  return _phase4ADecanNote(
    definition: _hotepDefinition,
    event: event ?? _hotepEvent,
    flowId: _hotepFlowId,
    clientEventPrefix: 'hotep',
  );
}

NoteData _shoreNote({MaatDecanFlowEvent? event}) {
  return _phase4ADecanNote(
    definition: _shoreDefinition,
    event: event ?? _shoreEvent,
    flowId: _shoreFlowId,
    clientEventPrefix: 'shore',
  );
}

NoteData _livingTextNote({MaatDecanFlowEvent? event}) {
  return _phase4ADecanNote(
    definition: _livingTextDefinition,
    event: event ?? _livingTextEvent,
    flowId: _livingTextFlowId,
    clientEventPrefix: 'living-text',
  );
}

NoteData _clearingNote({MaatDecanFlowEvent? event}) {
  return _phase4ADecanNote(
    definition: _clearingDefinition,
    event: event ?? _clearingEvent,
    flowId: _clearingFlowId,
    clientEventPrefix: 'clearing',
  );
}

NoteData _hetHeruNote({MaatDecanFlowEvent? event}) {
  return _phase4ADecanNote(
    definition: _hetHeruDefinition,
    event: event ?? _hetHeruEvent,
    flowId: _hetHeruFlowId,
    clientEventPrefix: 'het-heru',
  );
}

NoteData _fairHearingNote({MaatDecanFlowEvent? event}) {
  return _phase4ADecanNote(
    definition: _fairHearingDefinition,
    event: event ?? _fairHearingEvent,
    flowId: _fairHearingFlowId,
    clientEventPrefix: 'fair-hearing',
  );
}

NoteData _boundaryStoneNote({MaatDecanFlowEvent? event}) {
  return _phase4ADecanNote(
    definition: _boundaryStoneDefinition,
    event: event ?? _boundaryStoneEvent,
    flowId: _boundaryStoneFlowId,
    clientEventPrefix: 'boundary-stone',
  );
}

NoteData _openMouthNote({MaatDecanFlowEvent? event}) {
  return _phase4ADecanNote(
    definition: _openMouthDefinition,
    event: event ?? _openMouthEvent,
    flowId: _openMouthFlowId,
    clientEventPrefix: 'open-mouth',
  );
}

NoteData _phase4ADecanNote({
  required MaatDecanFlowDefinition definition,
  required MaatDecanFlowEvent event,
  required int flowId,
  required String clientEventPrefix,
}) {
  return NoteData(
    clientEventId: 'cid-$clientEventPrefix-${event.eventNumber}',
    title: maatDecanFlowEventTitle(definition, event),
    detail: maatDecanFlowDetailText(definition, event),
    category: event.decanSection,
    allDay: false,
    start: const TimeOfDay(hour: 10, minute: 0),
    end: const TimeOfDay(hour: 10, minute: 8),
    flowId: flowId,
    behaviorPayload: <String, dynamic>{
      'flow_key': definition.key,
      'kind': definition.behaviorKind,
      'event_number': event.eventNumber,
      'flow_day': event.flowDay,
      'requires_real_world_action': event.requiresRealWorldAction,
    },
  );
}

JournalDocument _journalDocument(String text) {
  return JournalDocument(
    version: kJournalDocVersion,
    blocks: <JournalBlock>[
      ParagraphBlock(
        id: 'user-body',
        ops: <TextOp>[TextOp(insert: text)],
      ),
    ],
  );
}

Future<void> _openDetailSheet(WidgetTester tester, String title) async {
  final eventSurface = find
      .ancestor(
        of: find.text(title).first,
        matching: find.byType(GestureDetector),
      )
      .last;
  await tester.tap(eventSurface);
  await _pumpInteraction(tester);
}

Future<void> _enterPilotResponse(
  WidgetTester tester, {
  required String specId,
  required String text,
}) async {
  final field = find.byKey(maatFlowResponseFieldKey(specId));
  await tester.ensureVisible(field);
  await _pumpInteraction(tester);
  await tester.enterText(field, text);
  await _pumpInteraction(tester);
}

Future<void> _choosePilotOption(
  WidgetTester tester, {
  required String specId,
  required String optionId,
}) async {
  final option = find.byKey(maatFlowResponseFieldKey('$specId:$optionId'));
  await tester.ensureVisible(option);
  await _pumpInteraction(tester);
  await tester.tap(option);
  await _pumpInteraction(tester);
}

Future<void> _tapStatus(WidgetTester tester, String label) async {
  FocusManager.instance.primaryFocus?.unfocus();
  tester.testTextInput.hide();
  await _pumpInteraction(tester);
  final button = find.widgetWithText(OutlinedButton, label).last;
  await tester.ensureVisible(button);
  await _pumpInteraction(tester);
  tester.widget<OutlinedButton>(button).onPressed?.call();
  await _pumpInteraction(tester);
}

Future<void> _toggleOfferJournalWrite(WidgetTester tester) async {
  final toggle = find.text('Add to journal').last;
  await tester.ensureVisible(toggle);
  await _pumpInteraction(tester);
  await tester.tap(toggle);
  await _pumpInteraction(tester);
}

Future<void> _pumpInteraction(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 650));
  await tester.pump();
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var i = 0; i < 12; i++) {
    if (condition()) return;
    await _pumpInteraction(tester);
  }
  fail('Condition was not met before the bounded pump timeout.');
}

Future<void> _setPhoneViewport(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(() async {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

class _DayViewHarness extends StatelessWidget {
  const _DayViewHarness({
    required this.notes,
    required this.flowIndex,
    this.onAppendToJournal,
    this.onWriteJournalResponse,
    this.onRecordCompletion,
  });

  final List<NoteData> notes;
  final Map<int, FlowData> flowIndex;
  final Future<void> Function(String text)? onAppendToJournal;
  final MaatJournalResponseBlockWriter? onWriteJournalResponse;
  final Future<void> Function({
    required String clientEventId,
    required int flowId,
    required DateTime completedOnDate,
    Map<String, dynamic>? metadata,
  })?
  onRecordCompletion;

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
          initialScrollOffset: 6 * 60,
          onAppendToJournal: onAppendToJournal,
          onWriteJournalResponse: onWriteJournalResponse,
          onRecordCompletion: onRecordCompletion,
        ),
      ),
    );
  }
}
