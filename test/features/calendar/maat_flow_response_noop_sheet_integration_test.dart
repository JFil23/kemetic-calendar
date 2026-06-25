import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/completion_status.dart';
import 'package:mobile/features/calendar/day_view.dart';
import 'package:mobile/features/calendar/landscape_month_view.dart';
import 'package:mobile/features/calendar/maat_flow_interactive_primitives.dart';
import 'package:mobile/features/calendar/maat_flow_response_draft_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const int _unsupportedMaatFlowId = 90;
const String _unsupportedMaatFlowTitle = 'Unsupported Ma\'at practice';
const String _unsupportedMaatFlowKey = 'unsupported-maat-flow';

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
    'Day View unsupported Ma_at flow keeps completion picker without response UI',
    (tester) async {
      await _setPhoneViewport(tester);
      final recorded = <_CompletionWrite>[];

      await tester.pumpWidget(
        _DayViewHarness(
          flowIndex: const <int, FlowData>{
            _unsupportedMaatFlowId: FlowData(
              id: _unsupportedMaatFlowId,
              name: 'Unsupported Ma\'at',
              color: Colors.amber,
              active: true,
              notes: 'maat=$_unsupportedMaatFlowKey',
            ),
          },
          notes: <NoteData>[_unsupportedMaatNote()],
          onRecordCompletion:
              ({
                required String clientEventId,
                required int flowId,
                required DateTime completedOnDate,
                Map<String, dynamic>? metadata,
              }) async {
                recorded.add(
                  _CompletionWrite(
                    clientEventId: clientEventId,
                    flowId: flowId,
                    status: CompletionStatusX.fromWireName(
                      metadata?['completion_status']?.toString(),
                    ),
                  ),
                );
              },
        ),
      );
      await tester.pumpAndSettle();

      await _openDetailSheet(tester, _unsupportedMaatFlowTitle);

      expect(find.byKey(kMaatFlowResponseSectionKey), findsNothing);
      expect(find.text('Observed'), findsWidgets);
      expect(find.text('Partly'), findsWidgets);
      expect(find.text('Skipped'), findsWidgets);

      await tester.ensureVisible(find.text('Observed').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Observed').last);
      await tester.pumpAndSettle();

      expect(recorded, hasLength(1));
      expect(recorded.single.clientEventId, 'cid-unsupported-maat');
      expect(recorded.single.flowId, _unsupportedMaatFlowId);
      expect(recorded.single.status, CompletionStatus.observed);
    },
  );

  testWidgets(
    'Landscape month Ma_at sheet keeps existing completion behavior without response UI',
    (tester) async {
      await _setLandscapeViewport(tester);
      final recorded = <CompletionStatus>[];

      await tester.pumpWidget(
        _LandscapeHarness(
          flowIndex: const <int, FlowData>{
            _unsupportedMaatFlowId: FlowData(
              id: _unsupportedMaatFlowId,
              name: 'Unsupported Ma\'at',
              color: Colors.amber,
              active: true,
              notes: 'maat=$_unsupportedMaatFlowKey',
            ),
          },
          notesForDay: (ky, km, kd) =>
              kd == 1 ? <NoteData>[_unsupportedMaatNote()] : const <NoteData>[],
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

      await _openDetailSheet(tester, _unsupportedMaatFlowTitle);

      expect(find.byKey(kMaatFlowResponseSectionKey), findsNothing);
      expect(find.text('Observed'), findsWidgets);
      expect(find.text('Partly'), findsWidgets);
      expect(find.text('Skipped'), findsWidgets);

      await tester.ensureVisible(find.text('Observed').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Observed').last);
      await tester.pumpAndSettle();

      expect(recorded, <CompletionStatus>[CompletionStatus.observed]);
    },
  );

  testWidgets(
    'non-Ma_at event detail sheet uses ordinary completion panel without response UI',
    (tester) async {
      await _setPhoneViewport(tester);
      final recorded = <_CompletionWrite>[];

      await tester.pumpWidget(
        _DayViewHarness(
          flowIndex: const <int, FlowData>{
            7: FlowData(
              id: 7,
              name: 'Practice',
              color: Colors.green,
              active: true,
            ),
          },
          notes: const <NoteData>[
            NoteData(
              clientEventId: 'cid-ordinary-practice',
              title: 'Ordinary practice',
              allDay: false,
              start: TimeOfDay(hour: 10, minute: 0),
              end: TimeOfDay(hour: 10, minute: 30),
              flowId: 7,
            ),
          ],
          onRecordCompletion:
              ({
                required String clientEventId,
                required int flowId,
                required DateTime completedOnDate,
                Map<String, dynamic>? metadata,
              }) async {
                recorded.add(
                  _CompletionWrite(
                    clientEventId: clientEventId,
                    flowId: flowId,
                    status: CompletionStatusX.fromWireName(
                      metadata?['completion_status']?.toString(),
                    ),
                  ),
                );
              },
        ),
      );
      await tester.pumpAndSettle();

      await _openDetailSheet(tester, 'Ordinary practice');

      expect(find.byKey(kMaatFlowResponseSectionKey), findsNothing);
      expect(find.text('Observed'), findsWidgets);
      expect(find.text('Partly'), findsWidgets);
      expect(find.text('Skipped'), findsWidgets);

      await tester.tap(find.text('Observed').last);
      await tester.pumpAndSettle();

      expect(recorded, hasLength(1));
      expect(recorded.single.clientEventId, 'cid-ordinary-practice');
      expect(recorded.single.flowId, 7);
      expect(recorded.single.status, CompletionStatus.observed);
    },
  );
}

class _CompletionWrite {
  const _CompletionWrite({
    required this.clientEventId,
    required this.flowId,
    required this.status,
  });

  final String clientEventId;
  final int flowId;
  final CompletionStatus status;
}

NoteData _unsupportedMaatNote() {
  return const NoteData(
    clientEventId: 'cid-unsupported-maat',
    title: _unsupportedMaatFlowTitle,
    detail: 'Unsupported Ma\'at detail.',
    category: 'Unsupported Ma\'at',
    allDay: false,
    start: TimeOfDay(hour: 10, minute: 0),
    end: TimeOfDay(hour: 10, minute: 10),
    flowId: _unsupportedMaatFlowId,
    behaviorPayload: <String, dynamic>{
      'flow_key': _unsupportedMaatFlowKey,
      'kind': 'unsupported_maat_flow',
    },
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

Future<void> _setPhoneViewport(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(() async {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _setLandscapeViewport(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1194, 834);
  addTearDown(() async {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

class _DayViewHarness extends StatelessWidget {
  const _DayViewHarness({
    required this.notes,
    required this.flowIndex,
    this.onRecordCompletion,
  });

  final List<NoteData> notes;
  final Map<int, FlowData> flowIndex;
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
          initialScrollOffset: 9 * 60,
          onRecordCompletion: onRecordCompletion,
        ),
      ),
    );
  }
}

class _LandscapeHarness extends StatelessWidget {
  const _LandscapeHarness({
    required this.notesForDay,
    required this.flowIndex,
    this.onRecordCompletion,
  });

  final List<NoteData> Function(int ky, int km, int kd) notesForDay;
  final Map<int, FlowData> flowIndex;
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
        body: LandscapeMonthPager(
          initialKy: 6267,
          initialKm: 4,
          showGregorian: false,
          notesForDay: notesForDay,
          flowIndex: flowIndex,
          getMonthName: (km) => 'Month $km',
          onRecordCompletion: onRecordCompletion,
        ),
      ),
    );
  }
}
