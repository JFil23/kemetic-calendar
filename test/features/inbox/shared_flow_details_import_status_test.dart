import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/share_models.dart';
import 'package:mobile/data/user_events_repo.dart';
import 'package:mobile/features/inbox/shared_flow_details_page.dart';
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

  setUp(() {
    UserEventsRepo.setTelemetryEnabledForTesting(false);
  });

  tearDown(() {
    UserEventsRepo.setTelemetryEnabledForTesting(null);
  });

  testWidgets('share payload renders Edit Flow once imported flow is known', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SharedFlowDetailsPage(
          share: _share(),
          importedFlowId: 766,
          fallbackLocation: '/inbox',
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('CODEX_INBOX_IMPORT_SMOKE'), findsOneWidget);
    expect(find.text('Edit Flow'), findsOneWidget);
    expect(find.text('Import Flow'), findsNothing);
  });

  testWidgets('share payload still renders Import Flow before import', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SharedFlowDetailsPage(
          share: _share(),
          fallbackLocation: '/inbox',
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('CODEX_INBOX_IMPORT_SMOKE'), findsOneWidget);
    expect(find.text('Import Flow'), findsOneWidget);
    expect(find.text('Edit Flow'), findsNothing);
  });
}

InboxShareItem _share() {
  return InboxShareItem(
    shareId: '11111111-1111-4111-8111-111111111111',
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
    payloadJson: const {
      'flow_id': 765,
      'name': 'CODEX_INBOX_IMPORT_SMOKE',
      'color': 4283289825,
      'notes': '',
      'rules': [],
      'events': [
        {
          'offset_days': 0,
          'title': 'CODEX_INBOX_IMPORT_SMOKE opening',
          'detail': 'first imported snapshot',
          'all_day': false,
          'start_time': '09:15',
          'end_time': '10:00',
        },
      ],
    },
  );
}
