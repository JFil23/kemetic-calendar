import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/share_models.dart';
import 'package:mobile/data/user_events_repo.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
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

  test('canonical action resolver preserves source-specific policy', () {
    final inboxImport = CalendarPage.resolveCanonicalCustomFlowActionPolicy(
      source: FlowDetailSource.inboxShare,
      isLocalFlow: false,
    );
    expect(inboxImport.kind, FlowDetailActionKind.importFlow);
    expect(inboxImport.label, 'Import Flow');

    final inboxImported = CalendarPage.resolveCanonicalCustomFlowActionPolicy(
      source: FlowDetailSource.inboxShare,
      isLocalFlow: true,
      isImported: true,
    );
    expect(inboxImported.kind, FlowDetailActionKind.openImported);
    expect(inboxImported.label, 'Manage Flow');

    final profileAdd = CalendarPage.resolveCanonicalCustomFlowActionPolicy(
      source: FlowDetailSource.profilePost,
      isLocalFlow: false,
    );
    expect(profileAdd.kind, FlowDetailActionKind.addToMyFlows);
    expect(profileAdd.label, 'Add to My Flows');

    final profileSaved = CalendarPage.resolveCanonicalCustomFlowActionPolicy(
      source: FlowDetailSource.profilePost,
      isLocalFlow: true,
      isSaved: true,
    );
    expect(profileSaved.kind, FlowDetailActionKind.openSaved);
    expect(profileSaved.label, 'Manage Flow');

    final communityExcluded =
        CalendarPage.resolveCanonicalCustomFlowActionPolicy(
          source: FlowDetailSource.communityFeed,
          isLocalFlow: false,
          isReadOnly: true,
        );
    expect(communityExcluded.source, FlowDetailSource.communityFeed);
    expect(communityExcluded.kind, FlowDetailActionKind.viewOnly);

    final localOwner = CalendarPage.resolveCanonicalCustomFlowActionPolicy(
      source: FlowDetailSource.myFlows,
      isLocalFlow: true,
      isOwner: true,
    );
    expect(localOwner.kind, FlowDetailActionKind.manage);
    expect(localOwner.label, 'Manage Flow');
  });

  testWidgets('share payload renders Manage Flow once imported flow is known', (
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
    expect(find.text('Manage Flow'), findsOneWidget);
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
    expect(find.text('Overview'), findsNothing);
    expect(find.text('Schedule'), findsNothing);
    expect(find.text('Import Flow'), findsOneWidget);
    expect(find.text('Manage Flow'), findsNothing);
  });

  testWidgets('profile-posted payload renders Add to My Flows action policy', (
    tester,
  ) async {
    var pressed = false;
    final policy = CalendarPage.resolveCanonicalCustomFlowActionPolicy(
      source: FlowDetailSource.profilePost,
      isLocalFlow: false,
      isSaved: false,
      onPressed: () {
        pressed = true;
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SharedFlowDetailsPage(
          payloadJson: _profilePayload(),
          showImportFooter: false,
          actionPolicy: policy,
          fallbackLocation: '/profile/source-user',
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('CODEX_PROFILE_POLICY_SMOKE'), findsOneWidget);
    expect(find.text('Add to My Flows'), findsOneWidget);
    expect(find.text('Import Flow'), findsNothing);

    await tester.tap(find.text('Add to My Flows'), warnIfMissed: false);
    await tester.pump();
    expect(pressed, isTrue);
  });

  testWidgets(
    'profile-posted saved payload renders Manage Flow action policy',
    (tester) async {
      final policy = CalendarPage.resolveCanonicalCustomFlowActionPolicy(
        source: FlowDetailSource.profilePost,
        isLocalFlow: true,
        isSaved: true,
        onPressed: () {},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SharedFlowDetailsPage(
            payloadJson: _profilePayload(),
            showImportFooter: false,
            actionPolicy: policy,
            fallbackLocation: '/profile/source-user',
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('CODEX_PROFILE_POLICY_SMOKE'), findsOneWidget);
      expect(find.text('Manage Flow'), findsOneWidget);
      expect(find.text('Add to My Flows'), findsNothing);
    },
  );

  testWidgets(
    'Ma’at payload renders canonical Ma’at detail before custom policy',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SharedFlowDetailsPage(
            payloadJson: const {
              'name': 'Dawn House Rite',
              'color': 4293890652,
              'notes': '',
              'rules': [],
              'events': [],
            },
            showImportFooter: false,
            actionPolicy: FlowDetailActionPolicy(
              source: FlowDetailSource.profilePost,
              kind: FlowDetailActionKind.manage,
              label: 'Remove from profile',
              icon: Icons.delete_outline,
              onPressed: () {},
            ),
            fallbackLocation: '/profile/source-user',
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Dawn House Rite'), findsWidgets);
      expect(find.text('Join Flow'), findsOneWidget);
      expect(find.text('Remove from profile'), findsNothing);
      expect(find.text('Overview'), findsNothing);
    },
  );
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

Map<String, dynamic> _profilePayload() {
  return const {
    'flow_id': 888,
    'name': 'CODEX_PROFILE_POLICY_SMOKE',
    'color': 4283289825,
    'notes': 'profile payload preview',
    'rules': [],
    'events': [
      {
        'offset_days': 0,
        'title': 'CODEX_PROFILE_POLICY_SMOKE opening',
        'detail': 'first profile snapshot',
        'all_day': false,
        'start_time': '09:15',
        'end_time': '10:00',
      },
    ],
  };
}
