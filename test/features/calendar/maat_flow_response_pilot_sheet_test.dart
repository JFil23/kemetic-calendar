import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/completion_status.dart';
import 'package:mobile/features/calendar/dawn_house_rite_flow.dart';
import 'package:mobile/features/calendar/day_view.dart';
import 'package:mobile/features/calendar/evening_threshold_rite_flow.dart';
import 'package:mobile/features/calendar/maat_flow_interactive_primitives.dart';
import 'package:mobile/features/calendar/maat_flow_response_journal_blocks.dart';
import 'package:mobile/features/calendar/moon_return_flow.dart';
import 'package:mobile/features/calendar/the_days_outside_year_flow.dart';
import 'package:mobile/features/calendar/the_course_flow.dart';
import 'package:mobile/features/calendar/the_decan_watch_flow.dart';
import 'package:mobile/features/calendar/the_decan_watch_local_store.dart';
import 'package:mobile/features/calendar/the_offering_table_flow.dart';
import 'package:mobile/features/calendar/the_weighing_flow.dart';
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

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _offeringTableFlowIndex,
        notes: <NoteData>[_offeringTableNote()],
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

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: _daysOutsideFlowIndex,
        notes: <NoteData>[_daysOutsideNote()],
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

  testWidgets('unsupported Ma_at flow remains without response fields', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    final event = kTheWeighingEvents.singleWhere(
      (event) => event.eventNumber == 9,
    );
    final title = theWeighingEventTitle(event);

    await tester.pumpWidget(
      _DayViewHarness(
        flowIndex: const <int, FlowData>{
          90: FlowData(
            id: 90,
            name: kTheWeighingTitle,
            color: Colors.amber,
            active: true,
            notes: 'weighing_lens=neutral',
          ),
        },
        notes: <NoteData>[
          NoteData(
            clientEventId: 'cid-the-weighing-9',
            title: title,
            detail: theWeighingDetailText(event, lens: TheWeighingLens.neutral),
            category: event.decanSection,
            allDay: false,
            start: const TimeOfDay(hour: 10, minute: 0),
            end: const TimeOfDay(hour: 10, minute: 10),
            flowId: 90,
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
  final button = find.text(label).last;
  await tester.ensureVisible(button);
  await _pumpInteraction(tester);
  await tester.tap(button);
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
