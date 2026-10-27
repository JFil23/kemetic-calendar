import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/data/flows_repo.dart';
import 'package:mobile/data/user_events_repo.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/pages/pages_resource_test.dart' show session, uid;

const _mutation = '40000000-0000-4000-8000-00000000ac21';
const _event = '30000000-0000-4000-8000-00000000ac21';

List<Map<String, dynamic>> _move({String title = 'Existing commitment'}) => [
  {
    'kind': 'event_patch',
    'id': _event,
    'expected_revision': 7,
    'avoid_conflicts': true,
    'patch': {
      'title': title,
      'starts_at': '2026-11-02T18:00:00Z',
      'ends_at': '2026-11-02T18:20:00Z',
    },
  },
];

Map<String, dynamic> _receipt({
  String status = 'applied',
  String mutation = _mutation,
}) => {
  'status': status,
  'mutation_id': mutation,
  'rows': [
    {
      'kind': 'event_patch',
      'row': {
        'id': _event,
        'client_event_id': 'existing-occurrence',
        'event_revision': 8,
      },
    },
  ],
};

Map<String, dynamic> _document(SharedPreferences prefs) =>
    Map<String, dynamic>.from(
      jsonDecode(prefs.getString(AskHawEventActions.actionStorageKey(uid))!)
          as Map,
    );

http.Response _json(Object value, {int status = 200}) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late SupabaseClient client;
  late UserEventsRepo repository;
  late List<http.Request> requests;
  late Future<http.Response> Function(http.Request) respond;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    requests = [];
    respond = (_) async => _json(_receipt());
    client = SupabaseClient(
      'https://example.supabase.co',
      'key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests.add(request);
        final response = await respond(request);
        return http.Response.bytes(
          response.bodyBytes,
          response.statusCode,
          headers: response.headers,
          request: request,
          reasonPhrase: response.reasonPhrase,
          isRedirect: response.isRedirect,
          persistentConnection: response.persistentConnection,
        );
      }),
    );
    await client.auth.recoverSession(session());
    repository = UserEventsRepo(client);
  });

  tearDown(() async => client.dispose());

  test(
    'checked action is durable before its sole owner RPC, with no event mirror',
    () async {
      final actions = _move();
      respond = (request) async {
        expect(request.url.path, '/rest/v1/rpc/apply_ask_haw_actions_v1');
        final sent = jsonDecode(request.body);
        expect((_document(prefs)['pending'] as List).single, sent);
        expect(sent, {
          'p_account': uid,
          'p_mutation': _mutation,
          'p_actions': actions,
        });
        return _json(_receipt());
      };
      final result = await repository.applyAskHawActions(
        mutationId: _mutation,
        actions: actions,
      );
      expect(result['status'], 'applied');
      expect(await repository.pendingAskHawActions(), isEmpty);
      final doc = _document(prefs);
      expect(
        doc.keys,
        unorderedEquals(['schema', 'account', 'pending', 'conflicts']),
      );
      expect(doc['pending'], isEmpty);
      expect(doc['conflicts'], isEmpty);
      expect(doc.containsKey('events'), isFalse);
      expect(doc.containsKey('flows'), isFalse);
      expect(doc.containsKey('rows'), isFalse);
      expect(requests.length, 1);
      expect(
        prefs.getKeys().where((key) => key.startsWith('ask_haw_')),
        unorderedEquals([AskHawEventActions.actionStorageKey(uid)]),
      );
    },
  );

  test(
    'lost acknowledgement reopens the exact request without another event write',
    () async {
      var committed = false;
      respond = (request) async {
        if (!committed) {
          committed = true;
          throw http.ClientException('Reply lost after commit');
        }
        expect(jsonDecode(request.body), jsonDecode(requests.first.body));
        return _json(_receipt());
      };
      await expectLater(
        repository.applyAskHawActions(mutationId: _mutation, actions: _move()),
        throwsA(anything),
      );
      final saved = (await repository.pendingAskHawActions()).single;
      final reopened = UserEventsRepo(client);
      expect((await reopened.pendingAskHawActions()).single, saved);
      final result = await reopened.applyAskHawActions(
        mutationId: saved['p_mutation'] as String,
        actions: [
          for (final value in saved['p_actions'] as List)
            Map<String, dynamic>.from(value as Map),
        ],
      );
      expect(result['status'], 'applied');
      expect(requests.length, 2);
      expect(jsonDecode(requests.last.body), jsonDecode(requests.first.body));
      expect(await reopened.pendingAskHawActions(), isEmpty);
      expect(
        requests.every((r) => r.url.path.endsWith('/apply_ask_haw_actions_v1')),
        isTrue,
      );
    },
  );

  test(
    'a pending identity cannot be repurposed for different content',
    () async {
      respond = (_) async => throw http.ClientException('Offline');
      await expectLater(
        repository.applyAskHawActions(mutationId: _mutation, actions: _move()),
        throwsA(anything),
      );
      final original = (await repository.pendingAskHawActions()).single;
      await expectLater(
        repository.applyAskHawActions(
          mutationId: _mutation,
          actions: _move(title: 'Different request'),
        ),
        throwsStateError,
      );
      expect(requests.length, 1);
      expect((await repository.pendingAskHawActions()).single, original);
    },
  );

  test('permission denial retains intent and never reports success', () async {
    respond = (_) async => _json({
      'code': '42501',
      'message': 'Event not editable',
      'details': null,
      'hint': null,
    }, status: 403);
    await expectLater(
      repository.applyAskHawActions(mutationId: _mutation, actions: _move()),
      throwsA(isA<PostgrestException>()),
    );
    expect(
      (await repository.pendingAskHawActions()).single['p_actions'],
      _move(),
    );
    expect(_document(prefs)['conflicts'], isEmpty);
  });

  test(
    'atomic conflict retains exact proposal and source receipt without a projection',
    () async {
      final conflict = _receipt(status: 'conflict');
      respond = (_) async => _json(conflict);
      final actions = [
        ..._move(),
        {
          'kind': 'event_create',
          'client_event_id': 'ask-haw:stable-new-occurrence',
          'calendar_id': '10000000-0000-4000-8000-00000000ac21',
          'event': {
            'title': 'Second proposed activity',
            'starts_at': '2026-11-02T19:00:00Z',
          },
        },
      ];
      await expectLater(
        repository.applyAskHawActions(mutationId: _mutation, actions: actions),
        throwsA(isA<AskHawActionConflict>()),
      );
      final doc = _document(prefs);
      expect(doc['pending'], isEmpty);
      final preserved = (doc['conflicts'] as List).single as Map;
      expect(preserved['result'], conflict);
      expect((preserved['request'] as Map)['p_actions'], actions);
      expect(
        doc.keys,
        unorderedEquals(['schema', 'account', 'pending', 'conflicts']),
      );
      expect(requests.length, 1);
    },
  );

  test(
    'wrong mutation acknowledgement leaves the exact request available for retry',
    () async {
      respond = (_) async => _json(_receipt(mutation: 'different-mutation'));
      await expectLater(
        repository.applyAskHawActions(mutationId: _mutation, actions: _move()),
        throwsStateError,
      );
      final saved = (await repository.pendingAskHawActions()).single;
      expect(saved['p_mutation'], _mutation);
      expect(saved['p_actions'], _move());
      expect(_document(prefs)['conflicts'], isEmpty);
    },
  );

  test('A to B to A cannot publish a late action acknowledgement', () async {
    final entered = Completer<void>();
    final response = Completer<http.Response>();
    respond = (_) {
      entered.complete();
      return response.future;
    };
    final pending = repository.applyAskHawActions(
      mutationId: _mutation,
      actions: _move(),
    );
    final rejected = expectLater(pending, throwsStateError);
    await entered.future;
    const other = '27d63169-a28a-4550-a0a0-8fee0e8e7b96';
    await client.auth.recoverSession(session().replaceAll(uid, other));
    await Future<void>.delayed(Duration.zero);
    await client.auth.recoverSession(session());
    await Future<void>.delayed(Duration.zero);
    response.complete(_json(_receipt()));
    await rejected;
    expect(
      (await repository.pendingAskHawActions()).single['p_mutation'],
      _mutation,
    );
    expect(prefs.getString(AskHawEventActions.actionStorageKey(other)), isNull);
    expect(_document(prefs)['conflicts'], isEmpty);
    final reopened = UserEventsRepo(client);
    expect(
      (await reopened.pendingAskHawActions()).single['p_actions'],
      _move(),
    );
  });

  test(
    'context rejects incomplete coverage and never creates a personal calendar',
    () async {
      final from = DateTime.utc(2026, 11, 2);
      final until = DateTime.utc(2026, 11, 3);
      respond = (request) async {
        expect(request.url.path, '/rest/v1/rpc/read_ask_haw_context_v1');
        expect(jsonDecode(request.body), {
          'p_account': uid,
          'p_from': from.toIso8601String(),
          'p_until': until.toIso8601String(),
        });
        return _json({
          'status': 'ready',
          'coverage': {
            'from': from.toIso8601String(),
            'until': until.toIso8601String(),
            'complete': false,
          },
          'personal_calendar_id': null,
          'events': [],
          'flows': [],
        });
      };
      await expectLater(
        repository.readAskHawContext(fromUtc: from, untilUtc: until),
        throwsStateError,
      );
      expect(requests.length, 1);
      expect(prefs.getString(AskHawEventActions.actionStorageKey(uid)), isNull);
    },
  );

  test(
    'complete context preserves actual account rows, timezone and source evidence',
    () async {
      final context = {
        'status': 'ready',
        'coverage': {'complete': true},
        'personal_calendar_id': null,
        'timezone': 'America/Los_Angeles',
        'events': [
          {
            'id': _event,
            'event_revision': 9,
            'completion_status': 'partial',
            'can_edit': false,
            'flow_suspended': true,
          },
        ],
        'flows': [],
        'step_completions': {
          '7': {'prepare': 'partial'},
        },
      };
      respond = (_) async => _json(context);
      final result = await repository.readAskHawContext(
        fromUtc: DateTime.utc(2026, 11, 2),
        untilUtc: DateTime.utc(2026, 11, 3),
      );
      expect(result, context);
      expect(requests.single.url.path, '/rest/v1/rpc/read_ask_haw_context_v1');
      expect(prefs.getString(AskHawEventActions.actionStorageKey(uid)), isNull);
    },
  );

  test(
    'old-release rows retain defaults and new optional fields roundtrip',
    () {
      final oldEvent = <String, dynamic>{
        'id': _event,
        'client_event_id': 'original-occurrence',
        'title': 'Original event',
        'starts_at': '2026-10-27T18:00:00Z',
        'ends_at': '2026-10-27T18:20:00Z',
        'flow_local_id': 7,
      };
      final event = UserEvent.fromRow(oldEvent);
      expect(event.eventRevision, 0);
      expect(event.flowSuspended, isFalse);
      expect(event.clientEventId, 'original-occurrence');
      final newEvent = UserEvent.fromRow({
        ...oldEvent,
        'event_revision': 12,
        'flow_suspended': true,
      });
      expect(newEvent.eventRevision, 12);
      expect(newEvent.flowSuspended, isTrue);
      expect(
        newEvent.toInsert(userId: uid).containsKey('event_revision'),
        isFalse,
      );
      final oldFlow = <String, dynamic>{
        'id': 7,
        'user_id': uid,
        'name': 'Original Flow',
        'rules': [
          {'opaque_old_schedule': true},
        ],
      };
      final flow = FlowRow.fromRow(oldFlow);
      expect(flow.assistance, isNull);
      expect(flow.assistanceRevision, 0);
      expect(flow.pausedAt, isNull);
      final authored = FlowRow.fromRow({
        ...oldFlow,
        'assistance': {'version': 2, 'opaque_future_contract': true},
        'assistance_revision': 4,
        'paused_at': '2026-10-27T18:00:00Z',
      });
      final restored = FlowRow.fromRow(authored.toCacheJson());
      expect(restored.assistance, authored.assistance);
      expect(restored.assistanceRevision, 4);
      expect(restored.pausedAt, DateTime.utc(2026, 10, 27, 18));
      expect(restored.rules, flow.rules);
    },
  );
}
