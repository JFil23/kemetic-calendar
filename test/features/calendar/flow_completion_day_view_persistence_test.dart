import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/completion_status.dart';
import 'package:mobile/features/calendar/day_view.dart';
import 'package:mobile/features/calendar/evening_threshold_rite_flow.dart';
import 'package:mobile/features/calendar/maat_flow_completion_response_persistence.dart';
import 'package:mobile/features/calendar/maat_flow_interactive_primitives.dart';
import 'package:mobile/features/calendar/maat_flow_response_draft_store.dart';
import 'package:mobile/features/calendar/maat_flow_response_journal_blocks.dart';
import 'package:mobile/features/calendar/maat_flow_response_models.dart';
import 'package:mobile/features/calendar/maat_flow_response_resolver.dart';
import 'package:mobile/features/journal/journal_badge_utils.dart';
import 'package:mobile/features/journal/journal_v2_document_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const int _flowId = 917;
const String _clientEventId = 'cid-evening-threshold-rite-17-persistence';
const String _specId = 'closing-release-tonight';
const String _firstResponse = 'gate day view persistence marker.';
const String _updatedResponse = 'gate day view persistence marker updated.';

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
    kMaatFlowResponseDraftStore.clearForTesting();
    CalendarEventDetailSheetCoordinator.debugResetForTests();
  });

  tearDown(() {
    kMaatFlowResponseDraftStore.clearForTesting();
    CalendarEventDetailSheetCoordinator.debugResetForTests();
  });

  testWidgets(
    'Evening Threshold Rite Day 17 completion metadata hydrates and upserts journal state',
    (tester) async {
      await _setPhoneViewport(tester);

      final metadataByClientEventId = <String, Map<String, dynamic>>{};
      final metadataWrites = <Map<String, dynamic>>[];
      final badgeAppendRequests = <String>[];
      var document = _journalDocument('Existing journal body.');

      Future<void> pumpHarness() async {
        await tester.pumpWidget(
          _DayViewHarness(
            notes: <NoteData>[_hiddenPracticeNote()],
            flowIndex: _flowIndex,
            loadCompletionMetadata: ({required clientEventId}) async {
              return metadataByClientEventId[clientEventId];
            },
            onAppendToJournal: (text) async {
              final rawTokens = JournalBadgeUtils.extractRawTokens(text);
              badgeAppendRequests.addAll(rawTokens);
              document = JournalBadgeUtils.mergeBadges(document, rawTokens);
            },
            onWriteJournalResponse: (block) async {
              document = switch (block.projectionKind) {
                MaatJournalResponseProjectionKind.formatted =>
                  MaatJournalResponseBlockUtils.upsert(document, block),
                MaatJournalResponseProjectionKind.plainUserText =>
                  MaatJournalResponseBlockUtils.upsertPlainUserText(
                    document,
                    block,
                  ),
              };
            },
            onRecordCompletion:
                ({
                  required clientEventId,
                  required flowId,
                  required completedOnDate,
                  metadata,
                }) async {
                  final captured = Map<String, dynamic>.from(
                    metadata ?? const <String, dynamic>{},
                  );
                  metadataByClientEventId[clientEventId] = captured;
                  metadataWrites.add(captured);
                },
          ),
        );
        await _pumpInteraction(tester);
      }

      await pumpHarness();
      await _openDetailSheet(tester, _hiddenPracticeTitle);
      await _enterResponse(tester, _firstResponse);
      await _tapStatus(tester, 'Observed');

      expect(metadataWrites, hasLength(1));
      expect(metadataWrites.single['status'], 'observed');
      final firstValues = extractMaatCompletionResponseValues(
        metadataWrites.single,
        specs: _calendarSheetSpecs,
      ).values;
      expect(firstValues[_specId]?.text, _firstResponse);

      var responseBlocks = MaatJournalResponseBlockUtils.extract(document);
      expect(responseBlocks, hasLength(1));
      final firstBlock = responseBlocks.single;
      expect(firstBlock.text, contains(_firstResponse));
      final firstBlockId = firstBlock.blockId;
      final firstSourceId = firstBlock.sourceId;

      var badges = JournalBadgeUtils.completionTokensFromDocument(document);
      expect(badges, hasLength(1));
      final firstBadgeId = badges.single.id;
      expect(badges.single.completionStatus, CompletionStatus.observed);
      expect(badgeAppendRequests, hasLength(1));

      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpInteraction(tester);
      CalendarEventDetailSheetCoordinator.debugResetForTests();

      await pumpHarness();
      await _openDetailSheet(tester, _hiddenPracticeTitle);
      expect(_fieldText(tester), _firstResponse);

      await _enterResponse(tester, _updatedResponse);
      await _tapStatus(tester, 'Observed');

      expect(metadataWrites, hasLength(2));
      expect(metadataWrites.last['status'], 'observed');
      final updatedValues = extractMaatCompletionResponseValues(
        metadataWrites.last,
        specs: _calendarSheetSpecs,
      ).values;
      expect(updatedValues[_specId]?.text, _updatedResponse);

      responseBlocks = MaatJournalResponseBlockUtils.extract(document);
      expect(responseBlocks, hasLength(1));
      final updatedBlock = responseBlocks.single;
      expect(updatedBlock.blockId, firstBlockId);
      expect(updatedBlock.sourceId, firstSourceId);
      expect(updatedBlock.text, contains(_updatedResponse));
      expect(updatedBlock.text, isNot(contains(_firstResponse)));

      badges = JournalBadgeUtils.completionTokensFromDocument(document);
      expect(badges, hasLength(1));
      expect(badges.single.id, firstBadgeId);
      expect(badges.single.completionStatus, CompletionStatus.observed);
      expect(badgeAppendRequests, hasLength(2));
    },
  );
}

final EveningThresholdRiteDay _hiddenPracticeDay = kEveningThresholdRiteDays
    .singleWhere((day) => day.dayNumber == 17);
final String _hiddenPracticeTitle = eveningThresholdRiteEventTitle(
  _hiddenPracticeDay,
);
final List<MaatFlowResponseSpec> _calendarSheetSpecs =
    resolveMaatFlowResponseSpecs(
      flowKey: kEveningThresholdRiteFlowKey,
      surface: MaatFlowResponseSurface.calendarSheet,
      eventKey: 'day-17',
    );
final Map<int, FlowData> _flowIndex = <int, FlowData>{
  _flowId: FlowData(
    id: _flowId,
    name: kEveningThresholdRiteTitle,
    color: const Color(0xFF2D2B7A),
    active: true,
    notes: 'flow_key=$kEveningThresholdRiteFlowKey',
  ),
};

NoteData _hiddenPracticeNote() {
  return NoteData(
    clientEventId: _clientEventId,
    title: _hiddenPracticeTitle,
    detail: eveningThresholdRiteDetailText(
      _hiddenPracticeDay,
      discreet: false,
      lens: EveningThresholdRiteLens.neutral,
    ),
    category: _hiddenPracticeDay.section,
    allDay: false,
    start: const TimeOfDay(hour: 19, minute: 20),
    end: const TimeOfDay(hour: 19, minute: 23),
    flowId: _flowId,
    behaviorPayload: <String, dynamic>{
      'flow_key': kEveningThresholdRiteFlowKey,
      'kind': 'maat_evening_threshold_rite_day',
      'day': _hiddenPracticeDay.dayNumber,
    },
  );
}

class _DayViewHarness extends StatelessWidget {
  const _DayViewHarness({
    required this.notes,
    required this.flowIndex,
    required this.loadCompletionMetadata,
    required this.onAppendToJournal,
    required this.onWriteJournalResponse,
    required this.onRecordCompletion,
  });

  final List<NoteData> notes;
  final Map<int, FlowData> flowIndex;
  final MaatCompletionMetadataLoader loadCompletionMetadata;
  final Future<void> Function(String text) onAppendToJournal;
  final MaatJournalResponseBlockWriter onWriteJournalResponse;
  final Future<void> Function({
    required String clientEventId,
    required int flowId,
    required DateTime completedOnDate,
    Map<String, dynamic>? metadata,
  })
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
          initialScrollOffset: 18 * 60,
          loadCompletionMetadata: loadCompletionMetadata,
          onAppendToJournal: onAppendToJournal,
          onWriteJournalResponse: onWriteJournalResponse,
          onRecordCompletion: onRecordCompletion,
        ),
      ),
    );
  }
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

Future<void> _enterResponse(WidgetTester tester, String text) async {
  final field = find.byKey(maatFlowResponseFieldKey(_specId));
  await tester.ensureVisible(field);
  await _pumpInteraction(tester);
  await tester.enterText(field, text);
  await _pumpInteraction(tester);
}

String? _fieldText(WidgetTester tester) {
  final field = find.byKey(maatFlowResponseFieldKey(_specId));
  return tester.widget<TextFormField>(field).controller?.text;
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

Future<void> _pumpInteraction(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 650));
  await tester.pump();
}

Future<void> _setPhoneViewport(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(() async {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
