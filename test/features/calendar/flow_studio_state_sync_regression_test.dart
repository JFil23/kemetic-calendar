import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/share_models.dart';
import 'package:mobile/features/calendar/calendar_page.dart'
    show ImportFlowData, debugBuildFlowStudioPageForTest;
import 'package:mobile/models/ai_flow_generation_response.dart';
import 'package:mobile/services/ai_flow_generation_service.dart';
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
    SharedPreferences.setMockInitialValues({});
    await _ensureSupabaseInitialized();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AIFlowGenerationService.debugFlowStudioOverride = null;
  });

  tearDown(() async {
    AIFlowGenerationService.debugFlowStudioOverride = null;
  });

  testWidgets('single day deselect removes the visible editor', (tester) async {
    _useLargeSurface(tester);
    final draft = _buildDraft(
      startDate: DateTime(2026, 6, 15),
      endDate: DateTime(2026, 6, 21),
    );
    await _openFlowStudio(tester, initialDraftJson: draft);

    await _tapChip(tester, 'Tue');
    expect(find.text('Notes for selection'), findsOneWidget);
    expect(_editorTitleFields(), findsOneWidget);

    await _tapChip(tester, 'Tue');
    expect(find.text('Notes for selection'), findsNothing);
    expect(_editorTitleFields(), findsNothing);

    await _closeFlowStudio(tester);
  });

  testWidgets('multi-day deselect middle hides only that editor', (
    tester,
  ) async {
    _useLargeSurface(tester);
    final draft = _buildDraft(
      startDate: DateTime(2026, 6, 15),
      endDate: DateTime(2026, 6, 21),
    );
    await _openFlowStudio(tester, initialDraftJson: draft);

    await _tapChip(tester, 'Mon');
    await _tapChip(tester, 'Tue');
    await _tapChip(tester, 'Wed');
    expect(_editorTitleFields(), findsNWidgets(3));

    await tester.enterText(_editorTitleFields().at(0), 'First practice');
    await tester.enterText(_editorTitleFields().at(1), 'Middle practice');
    await tester.enterText(_editorTitleFields().at(2), 'Last practice');
    await tester.pump();

    await _tapChip(tester, 'Tue');
    expect(_editorTitleFields(), findsNWidgets(2));
    expect(find.text('First practice'), findsOneWidget);
    expect(find.text('Middle practice'), findsNothing);
    expect(find.text('Last practice'), findsOneWidget);

    await _tapChip(tester, 'Tue');
    expect(_editorTitleFields(), findsNWidgets(3));
    expect(find.text('First practice'), findsOneWidget);
    expect(find.text('Middle practice'), findsOneWidget);
    expect(find.text('Last practice'), findsOneWidget);

    await _tapChip(tester, 'Tue');
    expect(_editorTitleFields(), findsNWidgets(2));
    expect(find.text('Middle practice'), findsNothing);

    await _closeFlowStudio(tester);
  });

  testWidgets('deselected cached draft is excluded from save payload', (
    tester,
  ) async {
    _useLargeSurface(tester);
    dynamic savedResult;
    final draft = _buildDraft(
      startDate: DateTime(2026, 6, 15),
      endDate: DateTime(2026, 6, 21),
    );
    await _openFlowStudio(
      tester,
      initialDraftJson: draft,
      onRouteResult: (result) async {
        savedResult = result;
      },
    );

    await tester.enterText(_nameField(), 'Payload Guard');
    await _tapChip(tester, 'Mon');
    await _tapChip(tester, 'Tue');
    expect(_editorTitleFields(), findsNWidgets(2));

    await tester.enterText(_editorTitleFields().at(0), 'Visible practice');
    await tester.enterText(_editorDetailFields().at(0), 'Keep this detail');
    await tester.enterText(_editorTitleFields().at(1), 'Hidden practice');
    await tester.enterText(
      _editorDetailFields().at(1),
      'This detail must not save',
    );
    await tester.pump();

    await _tapChip(tester, 'Tue');
    expect(_editorTitleFields(), findsOneWidget);
    expect(find.text('Visible practice'), findsOneWidget);
    expect(find.text('Hidden practice'), findsNothing);
    expect(find.text('This detail must not save'), findsNothing);

    await tester.tap(find.text('Save').first);
    await _pumpFlowStudio(tester);

    expect(savedResult, isNotNull);
    expect(savedResult.savedFlow.isSaved, isFalse);
    final planned = List<dynamic>.from(savedResult.plannedNotes as Iterable);
    expect(planned, hasLength(1));
    final savedNote = planned.single.note;
    expect(savedNote.title, 'Visible practice');
    expect(savedNote.detail, 'Keep this detail');
    expect(
      planned.map((plannedNote) => plannedNote.note.title),
      isNot(contains('Hidden practice')),
    );
    expect(
      planned.map((plannedNote) => plannedNote.note.detail),
      isNot(contains('This detail must not save')),
    );

    await _closeFlowStudio(tester);
  });

  testWidgets('manual no-schedule save creates a saved template payload', (
    tester,
  ) async {
    _useLargeSurface(tester);
    dynamic savedResult;
    await _openFlowStudio(
      tester,
      onRouteResult: (result) async {
        savedResult = result;
      },
    );

    await tester.enterText(_nameField(), 'CODEX_NO_SCHEDULE_FLOW_VISIBILITY');
    await tester.tap(find.text('Save').first);
    await _pumpFlowStudio(tester);

    expect(savedResult, isNotNull);
    expect(savedResult.savedFlow.name, 'CODEX_NO_SCHEDULE_FLOW_VISIBILITY');
    expect(savedResult.savedFlow.active, isTrue);
    expect(savedResult.savedFlow.isSaved, isTrue);
    expect(savedResult.savedFlow.start, isNull);
    expect(savedResult.savedFlow.end, isNull);
    expect(savedResult.savedFlow.rules, isEmpty);
    expect(List<dynamic>.from(savedResult.plannedNotes as Iterable), isEmpty);

    await _closeFlowStudio(tester);
  });

  testWidgets('shared import snapshot events save without weekday selection', (
    tester,
  ) async {
    _useLargeSurface(tester);
    dynamic savedResult;
    final importData = _buildSharedImportData(
      events: const [
        {
          'offset_days': 0,
          'title': 'CODEX_INBOX_IMPORT_SMOKE opening',
          'detail': 'first imported snapshot',
          'location': 'Audit room',
          'all_day': false,
          'start_time': '09:15',
          'end_time': '10:00',
          'action_id': 'tap-one',
          'behavior_payload': {'kind': 'tap'},
        },
        {
          'offset_days': 1,
          'title': 'CODEX_INBOX_IMPORT_SMOKE closing',
          'detail': 'second imported snapshot',
          'all_day': false,
          'start_time': '18:30',
          'end_time': '19:05',
        },
      ],
    );

    await _openFlowStudio(
      tester,
      importData: importData,
      onRouteResult: (result) async {
        savedResult = result;
      },
    );

    await tester.tap(find.text('Save').first);
    await _pumpFlowStudio(tester);

    expect(savedResult, isNotNull);
    expect(savedResult.savedFlow.name, 'CODEX_INBOX_IMPORT_SMOKE');
    expect(savedResult.savedFlow.isSaved, isFalse);
    expect(savedResult.savedFlow.shareId, _testShareId);
    expect(savedResult.originType, 'share_import');
    expect(savedResult.originFlowId, 765);
    expect(savedResult.rootFlowId, 765);
    expect(savedResult.originShareId, _testShareId);
    expect(savedResult.savedFlow.rules, isEmpty);

    final planned = List<dynamic>.from(savedResult.plannedNotes as Iterable);
    expect(planned, hasLength(2));
    expect(
      planned.map((plannedNote) => plannedNote.note.title),
      containsAll(<String>[
        'CODEX_INBOX_IMPORT_SMOKE opening',
        'CODEX_INBOX_IMPORT_SMOKE closing',
      ]),
    );

    final opening = planned.firstWhere(
      (plannedNote) =>
          plannedNote.note.title == 'CODEX_INBOX_IMPORT_SMOKE opening',
    );
    expect(opening.note.detail, 'first imported snapshot');
    expect(opening.note.location, 'Audit room');
    expect(opening.note.allDay, isFalse);
    expect(opening.note.start.hour, 9);
    expect(opening.note.start.minute, 15);
    expect(opening.note.end.hour, 10);
    expect(opening.note.end.minute, 0);
    expect(opening.note.actionId, 'tap-one');
    expect(opening.note.behaviorPayload, {'kind': 'tap'});

    await _closeFlowStudio(tester);
  });

  testWidgets('no-schedule shared import saves as a findable template', (
    tester,
  ) async {
    _useLargeSurface(tester);
    dynamic savedResult;
    final importData = _buildSharedImportData(events: const []);

    await _openFlowStudio(
      tester,
      importData: importData,
      onRouteResult: (result) async {
        savedResult = result;
      },
    );

    await tester.tap(find.text('Save').first);
    await _pumpFlowStudio(tester);

    expect(savedResult, isNotNull);
    expect(savedResult.savedFlow.name, 'CODEX_INBOX_IMPORT_SMOKE');
    expect(savedResult.savedFlow.active, isTrue);
    expect(savedResult.savedFlow.isSaved, isTrue);
    expect(savedResult.savedFlow.shareId, _testShareId);
    expect(savedResult.originType, 'share_import');
    expect(savedResult.originShareId, _testShareId);
    expect(savedResult.savedFlow.rules, isEmpty);
    expect(List<dynamic>.from(savedResult.plannedNotes as Iterable), isEmpty);

    await _closeFlowStudio(tester);
  });

  testWidgets('date system toggle hides inactive editors and restores them', (
    tester,
  ) async {
    _useLargeSurface(tester);
    final draft = _buildDraft(
      startDate: DateTime(2026, 6, 15),
      endDate: DateTime(2026, 6, 21),
    );
    await _openFlowStudio(tester, initialDraftJson: draft);

    await _tapChip(tester, 'Tue');
    await tester.enterText(_editorTitleFields().first, 'Scale work');
    await tester.pump();

    expect(find.text('2026-06-15'), findsOneWidget);
    expect(find.text('2026-06-21'), findsOneWidget);

    await tester.tap(find.text('Kemetic'));
    await _pumpFlowStudio(tester);
    expect(find.text('2026-06-15'), findsNothing);
    expect(find.text('Notes for selection'), findsNothing);
    expect(find.text('Scale work'), findsNothing);

    await tester.tap(find.text('Gregorian'));
    await _pumpFlowStudio(tester);
    expect(find.text('2026-06-15'), findsOneWidget);
    expect(find.text('2026-06-21'), findsOneWidget);
    expect(find.text('Notes for selection'), findsOneWidget);
    expect(find.text('Scale work'), findsOneWidget);
    expect(_editorTitleFields(), findsOneWidget);

    await _closeFlowStudio(tester);
  });

  testWidgets('Compose failure preserves prompt and exposes manual recovery', (
    tester,
  ) async {
    _useLargeSurface(tester);
    final draft = _buildDraft(
      studioMode: 'compose',
      composePrompt: 'practice piano',
      startDate: DateTime(2026, 6, 13),
      endDate: DateTime(2026, 6, 22),
    );
    AIFlowGenerationService
        .debugFlowStudioOverride = _FakeAIFlowGenerationService(
      const AIFlowGenerationResponse(
        success: false,
        errorMessage:
            'notes[0].details too generic: warm-up guidance needs named movements: "warm up"',
      ),
    );
    await _openFlowStudio(tester, initialDraftJson: draft);

    expect(find.text('Save'), findsNothing);
    expect(find.text('practice piano'), findsOneWidget);
    expect(find.text('Build manually'), findsOneWidget);
    expect(find.text('Save becomes available in Build mode.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('flow-studio-shape-cta')));
    await _pumpFlowStudio(tester);
    expect(
      find.textContaining('warm-up guidance needs named movements'),
      findsOneWidget,
    );
    expect(find.text('practice piano'), findsOneWidget);
    expect(find.text('Notes for selection'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('flow-studio-build-manually')));
    await _pumpFlowStudio(tester);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Save Flow'), findsOneWidget);
    expect(find.text('Practice Piano'), findsOneWidget);
    expect(find.text('2026-06-13'), findsOneWidget);
    expect(find.text('2026-06-22'), findsOneWidget);

    await _closeFlowStudio(tester);
  });

  testWidgets('generated import initializes selected editors without fallback', (
    tester,
  ) async {
    _useLargeSurface(tester);
    final draft = _buildDraft(
      studioMode: 'compose',
      composePrompt: 'practice piano',
      startDate: DateTime(2026, 6, 15),
      endDate: DateTime(2026, 6, 16),
    );
    AIFlowGenerationService
        .debugFlowStudioOverride = _FakeAIFlowGenerationService(
      AIFlowGenerationResponse(
        success: true,
        flowName: 'Piano Practice',
        flowColor: '#55dde0',
        overviewSummary: 'Two focused piano practice days.',
        notes: jsonEncode([
          {
            'day_index': 0,
            'title': 'Five-finger pattern',
            'details':
                'Play C-D-E-F-G and back to C for 6 slow passes with a 60 BPM metronome.',
            'all_day': false,
            'start_time': '18:00',
            'end_time': '18:35',
          },
          {
            'day_index': 1,
            'title': 'C major scale',
            'details':
                'Play the C major scale one octave up and down for 4 slow passes, then record one clean run-through.',
            'all_day': false,
            'start_time': '18:00',
            'end_time': '18:35',
          },
        ]),
      ),
    );
    await _openFlowStudio(tester, initialDraftJson: draft);

    await tester.tap(find.byKey(const ValueKey('flow-studio-shape-cta')));
    await _pumpFlowStudio(tester, const Duration(milliseconds: 1200));

    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Piano Practice'), findsOneWidget);
    expect(find.text('Notes for selection'), findsOneWidget);
    expect(_editorTitleFields(), findsNWidgets(2));
    expect(find.text('Five-finger pattern'), findsOneWidget);
    expect(find.text('C major scale'), findsOneWidget);

    await _closeFlowStudio(tester);
  });

  testWidgets(
    'generated Spanish flow save emits durable planned-note payload',
    (tester) async {
      _useLargeSurface(tester);
      dynamic savedResult;
      final draft = _buildDraft(
        studioMode: 'compose',
        composePrompt: 'learn Spanish conjugations',
        startDate: DateTime(2026, 6, 13),
        endDate: DateTime(2026, 6, 22),
      );
      AIFlowGenerationService.debugFlowStudioOverride =
          _FakeAIFlowGenerationService(_spanishConjugationResponse());
      await _openFlowStudio(
        tester,
        initialDraftJson: draft,
        onRouteResult: (result) async {
          savedResult = result;
        },
      );

      await tester.tap(find.byKey(const ValueKey('flow-studio-shape-cta')));
      await _pumpFlowStudio(tester, const Duration(milliseconds: 1200));
      expect(find.text('Spanish Conjugation Practice'), findsOneWidget);

      await tester.tap(find.text('Save').first);
      await _pumpFlowStudio(tester);

      expect(tester.takeException(), isNull);
      expect(savedResult, isNotNull);
      expect(savedResult.savedFlow.name, 'Spanish Conjugation Practice');
      final planned = List<dynamic>.from(savedResult.plannedNotes as Iterable);
      expect(planned, hasLength(3));
      expect(
        planned.map((plannedNote) => plannedNote.note.title),
        containsAll(<String>[
          'Present tense -ar reps',
          'Ser and estar contrast',
          'Preterite sentence drill',
        ]),
      );
      for (final plannedNote in planned) {
        expect(plannedNote.note.detail, isNotNull);
        expect(plannedNote.note.detail.toString().trim(), isNotEmpty);
        expect(plannedNote.note.start, isNotNull);
        expect(plannedNote.note.end, isNotNull);
        expect(plannedNote.note.allDay, isFalse);
      }

      await _closeFlowStudio(tester);
    },
  );

  testWidgets('generated planned-note time edits enter save payload', (
    tester,
  ) async {
    _useLargeSurface(tester);
    dynamic savedResult;
    final pickedTimes = <TimeOfDay>[
      const TimeOfDay(hour: 19, minute: 15),
      const TimeOfDay(hour: 20, minute: 45),
    ];
    AIFlowGenerationService.debugFlowStudioOverride =
        _FakeAIFlowGenerationService(_spanishConjugationResponse());
    await _openFlowStudio(
      tester,
      initialDraftJson: _buildDraft(
        studioMode: 'compose',
        composePrompt: 'learn Spanish conjugations',
        startDate: DateTime(2026, 6, 13),
        endDate: DateTime(2026, 6, 22),
      ),
      onRouteResult: (result) async {
        savedResult = result;
      },
      debugTimePicker: (_, _) async => pickedTimes.removeAt(0),
    );

    await tester.tap(find.byKey(const ValueKey('flow-studio-shape-cta')));
    await _pumpFlowStudio(tester, const Duration(milliseconds: 1200));
    _expectEnabledTimeEditors(expectedCount: 3);

    await tester.tap(_noteTimeButtons('start').first);
    await _pumpFlowStudio(tester);
    await tester.tap(_noteTimeButtons('end').first);
    await _pumpFlowStudio(tester);

    expect(find.text('Starts: 7:15 PM'), findsOneWidget);
    expect(find.text('Ends: 8:45 PM'), findsOneWidget);

    await tester.tap(find.text('Save').first);
    await _pumpFlowStudio(tester);

    expect(savedResult, isNotNull);
    final planned = List<dynamic>.from(savedResult.plannedNotes as Iterable);
    final edited = planned.firstWhere(
      (plannedNote) => plannedNote.note.title == 'Present tense -ar reps',
    );
    expect(edited.note.start.hour, 19);
    expect(edited.note.start.minute, 15);
    expect(edited.note.end.hour, 20);
    expect(edited.note.end.minute, 45);
    expect(
      planned
          .where(
            (plannedNote) => plannedNote.note.title == 'Present tense -ar reps',
          )
          .map(
            (plannedNote) =>
                plannedNote.note.start.hour * 60 +
                plannedNote.note.start.minute,
          ),
      isNot(contains(18 * 60)),
    );

    await _closeFlowStudio(tester);
  });

  testWidgets('generated save failure keeps Flow Studio visible with error', (
    tester,
  ) async {
    _useLargeSurface(tester);
    var saveAttempts = 0;
    final draft = _buildDraft(
      studioMode: 'compose',
      composePrompt: 'learn Spanish conjugations',
      startDate: DateTime(2026, 6, 13),
      endDate: DateTime(2026, 6, 22),
    );
    AIFlowGenerationService.debugFlowStudioOverride =
        _FakeAIFlowGenerationService(_spanishConjugationResponse());
    await _openFlowStudio(
      tester,
      initialDraftJson: draft,
      onRouteResult: (_) async {
        saveAttempts += 1;
        throw StateError('planned note insert failed');
      },
    );

    await tester.tap(find.byKey(const ValueKey('flow-studio-shape-cta')));
    await _pumpFlowStudio(tester, const Duration(milliseconds: 1200));
    await tester.tap(find.text('Save').first);
    await _pumpFlowStudio(tester);

    expect(tester.takeException(), isNull);
    expect(saveAttempts, 1);
    expect(find.text('Flow Studio'), findsOneWidget);
    expect(find.text('Spanish Conjugation Practice'), findsOneWidget);
    expect(find.textContaining('planned note insert failed'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);

    await _closeFlowStudio(tester);
  });

  testWidgets(
    'manual and generated saves share renderable planned-note shape',
    (tester) async {
      _useLargeSurface(tester);
      dynamic manualResult;
      await _openFlowStudio(
        tester,
        initialDraftJson: _buildDraft(
          startDate: DateTime(2026, 6, 15),
          endDate: DateTime(2026, 6, 21),
        ),
        onRouteResult: (result) async {
          manualResult = result;
        },
      );
      await tester.enterText(_nameField(), 'Manual Spanish Practice');
      await _tapChip(tester, 'Mon');
      await tester.enterText(_editorTitleFields().first, 'Manual conjugation');
      await tester.enterText(
        _editorDetailFields().first,
        'Conjugate hablar in six present-tense forms.',
      );
      _expectEnabledTimeEditors(expectedCount: 1);
      await tester.tap(find.text('Save').first);
      await _pumpFlowStudio(tester);
      _expectRenderablePlannedNotes(manualResult);

      await _closeFlowStudio(tester);

      dynamic generatedResult;
      AIFlowGenerationService.debugFlowStudioOverride =
          _FakeAIFlowGenerationService(_spanishConjugationResponse());
      await _openFlowStudio(
        tester,
        initialDraftJson: _buildDraft(
          studioMode: 'compose',
          composePrompt: 'learn Spanish conjugations',
          startDate: DateTime(2026, 6, 13),
          endDate: DateTime(2026, 6, 22),
        ),
        onRouteResult: (result) async {
          generatedResult = result;
        },
      );
      await tester.tap(find.byKey(const ValueKey('flow-studio-shape-cta')));
      await _pumpFlowStudio(tester, const Duration(milliseconds: 1200));
      _expectEnabledTimeEditors(expectedCount: 3);
      await tester.tap(find.text('Save').first);
      await _pumpFlowStudio(tester);
      _expectRenderablePlannedNotes(generatedResult);

      await _closeFlowStudio(tester);
    },
  );

  test('Flow Studio render and save paths use active editor groups', () {
    final source = File(
      'lib/features/calendar/calendar_flow_studio_page.dart',
    ).readAsStringSync();
    final calendar = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();

    final notesPanel = _sliceBetween(
      source,
      'Widget _notesEditorsPanel()',
      '// ---------- save/delete ----------',
    );
    expect(notesPanel, contains('final groups = _buildEditorGroups();'));
    expect(notesPanel, contains('if (groups.isEmpty) return'));
    expect(notesPanel, contains('flow-studio-note-start-'));
    expect(notesPanel, contains('flow-studio-note-end-'));
    expect(notesPanel, isNot(contains('_groupsFromDraftsFallback')));

    final pickStartBody = _sliceBetween(
      source,
      'Future<void> _pickStartFor(_NoteDraft draft) async',
      'Future<void> _pickEndFor(_NoteDraft draft) async',
    );
    expect(pickStartBody, contains('_showFlowTimePicker'));
    expect(pickStartBody, contains('_schedulePersistentDraftSave();'));

    final pickEndBody = _sliceBetween(
      source,
      'Future<void> _pickEndFor(_NoteDraft draft) async',
      'Future<TimeOfDay?> _showFlowTimePicker',
    );
    expect(pickEndBody, contains('_showFlowTimePicker'));
    expect(pickEndBody, contains('_schedulePersistentDraftSave();'));

    final aiGeneratedLoadBody = _sliceBetween(
      source,
      'Future<void> _loadAIGeneratedFlow(int flowId) async',
      '/// Load a flow by ID from database',
    );
    expect(aiGeneratedLoadBody, contains('forceTimedDrafts: true'));

    final saveBody = _sliceBetween(
      source,
      'Future<void> _save() async',
      'Future<void> _finishWithResult',
    );
    expect(saveBody, contains('final groups = _buildEditorGroups();'));
    expect(saveBody, isNot(contains('_draftsByDay.entries')));

    final finishBody = _sliceBetween(
      source,
      'Future<void> _finishWithResult(_FlowStudioResult result) async',
      'void _delete()',
    );
    expect(finishBody, contains('await routeResultHandler(result);'));
    expect(finishBody, contains('Unable to save flow'));
    expect(finishBody.indexOf('_clearSessionDraft()'), greaterThan(0));

    final applyBody = _sliceBetween(
      calendar,
      'Future<void> _applyFlowStudioResult(_FlowStudioResult edited) async',
      '// Slide-up Flow Studio shell',
    );
    expect(applyBody, contains('if (edited.plannedNotes.isNotEmpty)'));
    expect(applyBody, contains('await _persistFlowStudioResult(edited);'));

    final persistBody = _sliceBetween(
      calendar,
      'Future<int?> _persistFlowStudioResult(_FlowStudioResult r) async',
      '/// Schedules all note occurrences for a flow to the calendar',
    );
    expect(persistBody, contains('rollbackNewFlowSave'));
    expect(persistBody, contains('isSaved: r.savedFlow!.isSaved'));
    expect(persistBody, contains("deleteScope: 'failed_new_flow_save'"));
    expect(persistBody, contains('await commitGenerationIfNeeded();'));

    final headlessPersistBody = _sliceBetween(
      calendar,
      'static Future<int?> _persistFlowStudioResultHeadless',
      'static Future<int?> importFlowFromShare',
    );
    expect(headlessPersistBody, contains('isSaved: f.isSaved'));
  });
}

class _FakeAIFlowGenerationService extends AIFlowGenerationService {
  _FakeAIFlowGenerationService(this.response) : super(Supabase.instance.client);

  final AIFlowGenerationResponse response;

  @override
  Future<AIFlowGenerationResponse> generate({
    required String description,
    required DateTime startDate,
    required DateTime endDate,
    String? flowColor,
    String? timezone,
    String? sourceText,
    String? maatDeliveryId,
    String? maatBriefId,
    bool forceRefresh = false,
  }) async {
    return response;
  }
}

AIFlowGenerationResponse _spanishConjugationResponse() {
  return AIFlowGenerationResponse(
    success: true,
    flowName: 'Spanish Conjugation Practice',
    flowColor: '#55dde0',
    overviewSummary: 'Practice common Spanish conjugation patterns.',
    notes: jsonEncode([
      {
        'day_index': 0,
        'title': 'Present tense -ar reps',
        'details':
            'Conjugate hablar, estudiar, and practicar in all six present-tense forms, then say one original sentence for each verb.',
        'all_day': false,
        'start_time': '18:00',
        'end_time': '18:30',
      },
      {
        'day_index': 2,
        'title': 'Ser and estar contrast',
        'details':
            'Write five paired sentences using ser for identity or traits and estar for location or temporary state, then read them aloud.',
        'all_day': false,
        'start_time': '18:00',
        'end_time': '18:35',
      },
      {
        'day_index': 4,
        'title': 'Preterite sentence drill',
        'details':
            'Conjugate comer, vivir, and hablar in the preterite, then make eight short yesterday sentences with time cues.',
        'all_day': false,
        'start_time': '18:00',
        'end_time': '18:40',
      },
    ]),
  );
}

void _expectRenderablePlannedNotes(dynamic result) {
  expect(result, isNotNull);
  expect(result.savedFlow, isNotNull);
  final planned = List<dynamic>.from(result.plannedNotes as Iterable);
  expect(planned, isNotEmpty);
  for (final plannedNote in planned) {
    expect(plannedNote.note.title.toString().trim(), isNotEmpty);
    expect(plannedNote.note.detail.toString().trim(), isNotEmpty);
    expect(plannedNote.note.start, isNotNull);
    expect(plannedNote.note.end, isNotNull);
    expect(plannedNote.note.allDay, isFalse);
  }
}

Finder _editorTitleFields() {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == 'Title',
  );
}

Finder _editorDetailFields() {
  return find.byWidgetPredicate(
    (widget) =>
        widget is TextField &&
        widget.decoration?.labelText == 'Details (optional)',
  );
}

Finder _nameField() {
  return find.byWidgetPredicate(
    (widget) =>
        widget is TextField && widget.decoration?.hintText == 'FLOW TITLE',
  );
}

Finder _noteTimeButtons(String kind) {
  return find.byWidgetPredicate((widget) {
    final key = widget.key;
    return widget is OutlinedButton &&
        key is ValueKey<String> &&
        key.value.startsWith('flow-studio-note-$kind-');
  });
}

void _expectEnabledTimeEditors({required int expectedCount}) {
  final startButtons = _noteTimeButtons('start');
  final endButtons = _noteTimeButtons('end');
  expect(startButtons, findsNWidgets(expectedCount));
  expect(endButtons, findsNWidgets(expectedCount));
  for (var i = 0; i < expectedCount; i += 1) {
    expect(
      testerWidget<OutlinedButton>(startButtons.at(i)).onPressed,
      isNotNull,
    );
    expect(testerWidget<OutlinedButton>(endButtons.at(i)).onPressed, isNotNull);
  }
}

T testerWidget<T extends Widget>(Finder finder) {
  final element = finder.evaluate().single;
  return element.widget as T;
}

Map<String, dynamic> _buildDraft({
  String studioMode = 'build',
  required DateTime startDate,
  required DateTime endDate,
  String composePrompt = '',
}) {
  String date(DateTime value) => DateUtils.dateOnly(value).toIso8601String();

  return <String, dynamic>{
    'name': '',
    'active': true,
    'selectedColorIndex': 0,
    'studioMode': studioMode,
    'buildColorArgb': 0xFF55DDE0,
    'buildColorWasDragged': false,
    'composeColorArgb': 0xFF55DDE0,
    'composeColorWasDragged': false,
    'composePrompt': composePrompt,
    'composeUseKemetic': false,
    'composeStartDate': date(startDate),
    'composeEndDate': date(endDate),
    'composeManualDateRangeEdited': true,
    'useKemetic': false,
    'startDate': date(startDate),
    'endDate': date(endDate),
    'splitByPeriod': true,
    'selectedDecanDays': const <int>[],
    'selectedWeekdays': const <int>[],
    'perDecanSel': const <String, List<int>>{},
    'perWeekSel': const <String, List<int>>{},
    'draftsByDay': const <String, List<Map<String, dynamic>>>{},
    'draftsByPattern': const <String, Map<String, dynamic>>{},
    'overview': '',
    'isAIGeneratedFlow': false,
    'flowAlertMinutesBefore': -1,
    'flowAlertMixed': false,
  };
}

Future<void> _openFlowStudio(
  WidgetTester tester, {
  ImportFlowData? importData,
  Map<String, dynamic>? initialDraftJson,
  Future<void> Function(dynamic result)? onRouteResult,
  Future<TimeOfDay?> Function(BuildContext context, TimeOfDay initialTime)?
  debugTimePicker,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: debugBuildFlowStudioPageForTest(
        importData: importData,
        initialDraftJson: initialDraftJson,
        onRouteResult: onRouteResult,
        debugTimePicker: debugTimePicker,
      ),
    ),
  );

  await _pumpFlowStudio(tester, const Duration(milliseconds: 900));
  expect(find.text('Flow Studio'), findsOneWidget);
}

Future<void> _closeFlowStudio(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

Future<void> _tapChip(WidgetTester tester, String label) async {
  final chip = find.widgetWithText(FilterChip, label).first;
  await tester.tap(chip, warnIfMissed: false);
  await _pumpFlowStudio(tester);
}

Future<void> _pumpFlowStudio(
  WidgetTester tester, [
  Duration duration = const Duration(milliseconds: 250),
]) async {
  await tester.pump();
  await tester.pump(duration);
}

void _useLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

const _testShareId = '11111111-1111-4111-8111-111111111111';

ImportFlowData _buildSharedImportData({
  required List<Map<String, dynamic>> events,
}) {
  final share = InboxShareItem(
    shareId: _testShareId,
    kind: InboxShareKind.flow,
    recipientId: 'recipient',
    senderId: 'sender',
    payloadId: '765',
    title: 'CODEX_INBOX_IMPORT_SMOKE',
    createdAt: DateTime.utc(2026, 6, 19),
    suggestedSchedule: SuggestedSchedule(
      startDate: '2026-06-19',
      weekdays: const [],
    ),
    payloadJson: {
      'flow_id': 765,
      'name': 'CODEX_INBOX_IMPORT_SMOKE',
      'color': 0xFF4DD0E1,
      'notes': '',
      'rules': const [],
      'events': events,
    },
  );

  return ImportFlowData(
    share: share,
    name: 'CODEX_INBOX_IMPORT_SMOKE',
    color: 0xFF4DD0E1,
    notes: '',
    rules: const [],
    suggestedStartDate: DateTime(2026, 6, 19),
    suggestedEndDate: events.isEmpty ? null : DateTime(2026, 6, 20),
    originFlowId: 765,
    rootFlowId: 765,
    originType: 'share_import',
  );
}

String _sliceBetween(String source, String startNeedle, String endNeedle) {
  final start = source.indexOf(startNeedle);
  expect(start, isNonNegative, reason: startNeedle);
  final end = source.indexOf(endNeedle, start);
  expect(end, greaterThan(start), reason: endNeedle);
  return source.substring(start, end);
}
