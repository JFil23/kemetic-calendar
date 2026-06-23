import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/completion_status.dart';
import 'package:mobile/features/calendar/day_view.dart';
import 'package:mobile/features/calendar/maat_flow_interactive_primitives.dart';
import 'package:mobile/features/calendar/maat_flow_response_journal_blocks.dart';
import 'package:mobile/features/calendar/moon_return_flow.dart';
import 'package:mobile/features/calendar/the_course_flow.dart';
import 'package:mobile/features/calendar/the_decan_watch_flow.dart';
import 'package:mobile/features/calendar/the_decan_watch_local_store.dart';
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

const Map<int, FlowData> _decanWatchFlowIndex = <int, FlowData>{
  _decanWatchFlowId: FlowData(
    id: _decanWatchFlowId,
    name: kDecanWatchTitle,
    color: Colors.indigo,
    active: true,
    notes: 'maat=$kDecanWatchFlowKey',
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
