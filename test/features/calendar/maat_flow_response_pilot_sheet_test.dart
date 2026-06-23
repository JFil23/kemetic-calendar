import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/completion_status.dart';
import 'package:mobile/features/calendar/day_view.dart';
import 'package:mobile/features/calendar/maat_flow_interactive_primitives.dart';
import 'package:mobile/features/calendar/maat_flow_response_journal_blocks.dart';
import 'package:mobile/features/calendar/moon_return_flow.dart';
import 'package:mobile/features/calendar/the_course_flow.dart';
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
  await tester.pumpAndSettle();
}

Future<void> _enterPilotResponse(
  WidgetTester tester, {
  required String specId,
  required String text,
}) async {
  final field = find.byKey(maatFlowResponseFieldKey(specId));
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
}

Future<void> _tapStatus(WidgetTester tester, String label) async {
  final button = find.text(label).last;
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
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
