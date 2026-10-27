import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/features/calendar/calendar_page.dart'
    show
        KemeticMath,
        CalendarPage,
        ImportFlowData,
        debugBuildFlowStudioPageForTest,
        debugFlowStudioDraftRoundTripForTest;
import 'package:mobile/features/ask_haw/ask_haw_flow_contract_editor.dart';
import 'package:mobile/data/share_models.dart';
import 'package:mobile/data/warm_state/warm_snapshot_store.dart';
import '../../support/ask_haw_flow_contract_fixture.dart';
import '../pages/pages_resource_test.dart' show session;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Map<String, dynamic>? importedDefinition;
  Map<String, dynamic>? freshFlowDefinition;
  var directFlowReads = 0;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    for (final name in ['messages', 'events']) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            MethodChannel('com.llfbandit.app_links/$name'),
            (_) async => null,
          );
    }
    await Supabase.initialize(
      url: 'https://example.supabase.test',
      anonKey: 'fixture',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/flows') &&
            request.method == 'GET' &&
            freshFlowDefinition != null) {
          directFlowReads++;
          return http.Response(
            jsonEncode(freshFlowDefinition),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/flows') && request.method == 'POST') {
          importedDefinition = Map<String, dynamic>.from(
            jsonDecode(request.body) as Map,
          );
          // Stop after inspecting the real repository boundary. No staged event
          // operation should begin when the definition is rejected.
          return http.Response(
            jsonEncode({
              'code': 'P0001',
              'message': 'fixture rejected definition after payload capture',
            }),
            400,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        return http.Response(
          '[]',
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await Supabase.instance.client.auth.recoverSession(session());
  });
  tearDownAll(() async => Supabase.instance.dispose());

  test(
    'shared import carries raw assistance to the actual definition writer',
    () async {
      const guidance = <String, dynamic>{
        'version': 42,
        'future': {
          'keep': ['authored', 'unchanged'],
        },
      };
      final share = InboxShareItem(
        shareId: '9e28f782-137a-4e19-a9f3-a77e03b53b6b',
        kind: InboxShareKind.flow,
        recipientId: Supabase.instance.client.auth.currentUser!.id,
        senderId: 'sender',
        payloadId: '42',
        title: 'A shared practice',
        createdAt: DateTime(2026, 10, 27),
        payloadJson: {
          'assistance': guidance,
          'events': [
            {
              'title': 'Read',
              'starts_at': '2026-10-27T09:00:00Z',
              'ends_at': '2026-10-27T09:20:00Z',
              'all_day': false,
            },
          ],
        },
      );
      var completed = false;
      await expectLater(
        CalendarPage.importFlowFromShare(
          ImportFlowData(
            share: share,
            name: share.title,
            color: 0xFF55DDE0,
            calendarId: 'selected-calendar',
            rules: const [],
            assistance: guidance,
            suggestedStartDate: DateTime(2026, 10, 27),
          ),
          completeAdd: (_) => completed = true,
        ),
        throwsA(isA<PostgrestException>()),
      );
      expect(importedDefinition?['assistance'], guidance);
      expect(importedDefinition?['calendar_id'], 'selected-calendar');
      expect(completed, isFalse);
    },
  );

  test(
    'existing editor draft roundtrips future guidance and incomplete fields',
    () {
      final raw = draft(
        assistance: const {
          'version': 42,
          'future': {
            'untouched': ['exact'],
          },
        },
      );
      raw['assistanceDraft'] = {
        'replacement': true,
        'contract': {
          'version': 1,
          'steps': [
            {'id': 'first', 'minutes': 'soon'},
          ],
        },
      };
      raw['assistanceRevision'] = 9;
      raw['pausedAt'] = '2026-10-27T18:00:00.000Z';
      final restored = debugFlowStudioDraftRoundTripForTest(raw)!;
      expect(restored['assistance'], raw['assistance']);
      expect(restored['assistanceDraft'], raw['assistanceDraft']);
      expect(restored['assistanceRevision'], 9);
      expect(restored['pausedAt'], raw['pausedAt']);
      final note = (restored['draftsByDay'] as Map).values.first.first;
      expect(note['behaviorPayload']['other_owner'], {'keep': true});
      expect(note['behaviorPayload']['ask_haw']['step_id'], 'prepare');
    },
  );

  testWidgets(
    'existing edit reads complete fresh metadata over an older warm row',
    (tester) async {
      final owner = Supabase.instance.client.auth.currentUser!.id;
      final old = <String, dynamic>{
        'id': 42,
        'user_id': owner,
        'name': 'Held practice',
        'color': 0x55DDE0,
        'active': true,
        'is_saved': false,
        'is_hidden': false,
        'rules': [],
      };
      await tester.runAsync(() async {
        WarmSnapshotStore.instance.invalidate(owner);
        await WarmSnapshotStore.instance.refresh(
          owner,
          'flow.detail.42',
          () async => old,
          isCurrent: () => true,
        );
        await WarmSnapshotStore.instance.flushed;
      });
      freshFlowDefinition = {
        ...old,
        'assistance': askHawFlowContractFixture,
        'assistance_revision': 9,
        'paused_at': '2026-10-27T18:00:00Z',
      };
      dynamic saved;
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: debugBuildFlowStudioPageForTest(
              editFlowId: 42,
              onRouteResult: (result) async => saved = result,
            ),
          ),
        );
        for (var frame = 0; frame < 20; frame++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)),
          );
          await tester.pump(const Duration(milliseconds: 50));
        }
        await scrollTo(tester, find.byType(AskHawFlowContractEditor));
        expect(directFlowReads, greaterThan(0));
        expect(
          tester
              .widget<AskHawFlowContractEditor>(
                find.byType(AskHawFlowContractEditor),
              )
              .value,
          askHawFlowContractFixture,
        );
        await scrollTo(
          tester,
          find.byKey(const ValueKey('flow-studio-save-cta')),
        );
        await tester.tap(find.byKey(const ValueKey('flow-studio-save-cta')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(saved, isNotNull);
        expect(saved.savedFlow.assistance, askHawFlowContractFixture);
        expect(saved.savedFlow.assistanceRevision, 9);
        expect(saved.savedFlow.pausedAt, DateTime.utc(2026, 10, 27, 18));
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        freshFlowDefinition = null;
        WarmSnapshotStore.instance.invalidate(owner);
      }
    },
  );

  testWidgets(
    'canonical note selector saves explicit step identity with other behavior',
    (tester) async {
      dynamic saved;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: debugBuildFlowStudioPageForTest(
            initialDraftJson: draft(assistance: askHawFlowContractFixture),
            onRouteResult: (result) async => saved = result,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 900));
      await scrollTo(tester, find.byType(AskHawStepSelector));
      expect(find.byType(AskHawStepSelector), findsOneWidget);
      await tester.tap(find.byType(AskHawStepSelector));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Spend time with the text · read').last);
      await tester.pumpAndSettle();
      await scrollTo(
        tester,
        find.byKey(const ValueKey('flow-studio-save-cta')),
      );
      await tester.tap(find.byKey(const ValueKey('flow-studio-save-cta')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(saved, isNotNull);
      expect(saved.savedFlow.assistance, askHawFlowContractFixture);
      final notes = (saved.plannedNotes as List);
      expect(notes, hasLength(1));
      expect(notes.single.note.behaviorPayload['ask_haw'], {
        'step_id': 'read',
        'contract_version': 1,
      });
      expect(notes.single.note.behaviorPayload['other_owner'], {'keep': true});
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'ordinary save preserves unsupported assistance without offering step links',
    (tester) async {
      const future = <String, dynamic>{
        'version': 42,
        'nested': {'keep': true},
      };
      dynamic saved;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: debugBuildFlowStudioPageForTest(
            initialDraftJson: draft(assistance: future),
            onRouteResult: (result) async => saved = result,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 900));
      await scrollTo(
        tester,
        find.byKey(const ValueKey('flow-studio-save-cta')),
      );
      expect(find.byType(AskHawStepSelector), findsNothing);
      await tester.tap(find.byKey(const ValueKey('flow-studio-save-cta')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(saved, isNotNull);
      expect(saved.savedFlow.assistance, future);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

Future<void> scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    420,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
}

Map<String, dynamic> draft({Map<String, dynamic>? assistance}) {
  final date = DateTime(2026, 10, 27);
  final k = KemeticMath.fromGregorian(date);
  final key = '${k.kYear}-${k.kMonth}-${k.kDay}';
  return {
    'name': 'A deliberate reading practice',
    'active': true,
    'studioMode': 'build',
    'useKemetic': false,
    'splitByPeriod': true,
    'startDate': date.toIso8601String(),
    'endDate': date.toIso8601String(),
    'perWeekSel': {
      '2026-10-26': [2],
    },
    'draftsByDay': {
      key: [
        {
          'title': 'A reading place',
          'location': '',
          'detail': '',
          'allDay': false,
          'startMinutes': 540,
          'endMinutes': 560,
          'alertMinutesBefore': -1,
          'behaviorPayload': {
            'other_owner': {'keep': true},
            'ask_haw': {'step_id': 'prepare', 'contract_version': 1},
          },
        },
      ],
    },
    if (assistance != null) 'assistance': jsonDecode(jsonEncode(assistance)),
  };
}
