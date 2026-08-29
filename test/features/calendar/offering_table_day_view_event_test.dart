import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/day_view.dart';
import 'package:mobile/features/calendar/maat_flow_response_journal_blocks.dart';
import 'package:mobile/features/calendar/the_offering_table/presentation/offering_table_event_block_visual.dart';
import 'package:mobile/features/calendar/the_offering_table_flow.dart';
import 'package:mobile/features/calendar/the_offering_table_local_store.dart';
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
  });

  testWidgets('Offering event block resolves its private need by flow id', (
    tester,
  ) async {
    await _pumpDayView(tester, flowId: 71, initialNeed: 'Protect my sleep.');

    expect(find.text(kOfferingTableTitle), findsOneWidget);
    expect(find.text(kOfferingTableDays.first.title), findsWidgets);
    expect(find.text('“Protect my sleep.”'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('legacy Offering event without a local need remains safe', (
    tester,
  ) async {
    await _pumpDayView(tester, flowId: 72);

    expect(find.text(kOfferingTableDays.first.title), findsWidgets);
    expect(find.textContaining('No need was named'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Day View Reflect writes through the shared Journal authority', (
    tester,
  ) async {
    final blocks = <MaatJournalResponseBlock>[];
    await _pumpDayView(
      tester,
      flowId: 73,
      initialNeed: 'Protect my sleep.',
      onWriteJournalResponse: (block) async => blocks.add(block),
    );

    await tester.tap(find.byType(OfferingTableEventBlockVisual));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey<String>('offering-table-presentation-body')),
      const Offset(0, -1200),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reflect'));
    await tester.pumpAndSettle();

    final field = find.byKey(
      const ValueKey<String>('offering-table-reflection-field'),
    );
    await tester.ensureVisible(field);
    await tester.enterText(field, 'I made room for rest before work.');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(blocks, hasLength(1));
    expect(blocks.single.text, 'I made room for rest before work.');
    expect(
      blocks.single.sourceId,
      'maat_response:the-offering-table:cid:offering-table-event-73:offering-table-reflection',
    );
  });
}

Future<void> _pumpDayView(
  WidgetTester tester, {
  required int flowId,
  String? initialNeed,
  MaatJournalResponseBlockWriter? onWriteJournalResponse,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  if (initialNeed != null) {
    await const OfferingTableLocalStore().saveNeed(flowId, initialNeed);
  }
  final day = kOfferingTableDays.first;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DayViewGrid(
          ky: 1,
          km: 1,
          kd: 1,
          notes: <NoteData>[
            NoteData(
              clientEventId: 'offering-table-event-$flowId',
              title: offeringTableEventTitle(day),
              allDay: false,
              start: const TimeOfDay(hour: 7, minute: 30),
              end: const TimeOfDay(hour: 8, minute: 30),
              flowId: flowId,
              behaviorPayload: <String, dynamic>{
                'kind': 'maat_offering_table_day',
                'flow_key': kOfferingTableFlowKey,
                'day': day.dayNumber,
              },
            ),
          ],
          showGregorian: false,
          flowIndex: <int, FlowData>{
            flowId: FlowData(
              id: flowId,
              name: kOfferingTableTitle,
              color: const Color(0xFFC99A3D),
              active: true,
              notes: 'mode=gregorian;maat=$kOfferingTableFlowKey',
            ),
          },
          activeLedgerFlowIds: <int>{flowId},
          initialScrollOffset: 6 * 60,
          onWriteJournalResponse: onWriteJournalResponse,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
