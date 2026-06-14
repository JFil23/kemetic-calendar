import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart'
    show debugBuildFlowStudioPageForTest;
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

    await tester.ensureVisible(
      find.byKey(const ValueKey('flow-studio-save-cta')),
    );
    await tester.tap(find.byKey(const ValueKey('flow-studio-save-cta')));
    await _pumpFlowStudio(tester);

    expect(savedResult, isNotNull);
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

  test('Flow Studio render and save paths use active editor groups', () {
    final source = File(
      'lib/features/calendar/calendar_flow_studio_page.dart',
    ).readAsStringSync();

    final notesPanel = _sliceBetween(
      source,
      'Widget _notesEditorsPanel()',
      '// ---------- save/delete ----------',
    );
    expect(notesPanel, contains('final groups = _buildEditorGroups();'));
    expect(notesPanel, contains('if (groups.isEmpty) return'));
    expect(notesPanel, isNot(contains('_groupsFromDraftsFallback')));

    final saveBody = _sliceBetween(
      source,
      'Future<void> _save() async',
      'Future<void> _finishWithResult',
    );
    expect(saveBody, contains('final groups = _buildEditorGroups();'));
    expect(saveBody, isNot(contains('_draftsByDay.entries')));
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
  Map<String, dynamic>? initialDraftJson,
  Future<void> Function(dynamic result)? onRouteResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: debugBuildFlowStudioPageForTest(
        initialDraftJson: initialDraftJson,
        onRouteResult: onRouteResult,
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

String _sliceBetween(String source, String startNeedle, String endNeedle) {
  final start = source.indexOf(startNeedle);
  expect(start, isNonNegative, reason: startNeedle);
  final end = source.indexOf(endNeedle, start);
  expect(end, greaterThan(start), reason: endNeedle);
  return source.substring(start, end);
}
