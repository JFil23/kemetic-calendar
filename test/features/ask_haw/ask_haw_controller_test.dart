import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/data/external_calendar_repository.dart';
import 'package:mobile/features/ask_haw/ask_haw_controller.dart';
import 'package:mobile/features/ask_haw/ask_haw_memory.dart';
import 'package:mobile/features/ask_haw/ask_haw_memory_repository.dart';
import 'package:mobile/features/ask_haw/ask_haw_response.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/profile_post_removal_test.dart' show session;

class _Memory extends AskHawMemoryRepository {
  _Memory(super.client, this.value);
  AskHawMemory value;
  int reads = 0, restores = 0;
  AskHawMemory? remote;
  Completer<void>? holdRead;
  final readStarted = Completer<void>();
  bool failRead = false, failUpdate = false;
  Completer<void>? holdUpdate;
  final updateStarted = Completer<void>();
  final patches = <Map<String, dynamic>>[];
  @override
  Future<AskHawMemory> restore() async {
    restores++;
    return value;
  }

  @override
  Future<AskHawMemory> read() async {
    reads++;
    final snapshot = remote ?? value;
    if (!readStarted.isCompleted) readStarted.complete();
    await holdRead?.future;
    if (failRead) throw const SocketException('Memory read unavailable');
    value = snapshot;
    return snapshot;
  }

  @override
  Future<AskHawMemory> update(Map<String, dynamic> patch) async {
    patches.add(_copy(patch));
    if (!updateStarted.isCompleted) updateStarted.complete();
    await holdUpdate?.future;
    if (failUpdate) {
      throw const SocketException('Memory acknowledgement unavailable');
    }
    value = AskHawMemory(
      revision: value.revision + 1,
      epoch: value.epoch,
      payload: _memoryPatch(value.payload, patch),
    );
    return value;
  }
}

Map<String, dynamic> _copy(Map<String, dynamic> value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);

// The account contract uses recursive JSON merge patches: omission preserves a
// key and an explicit null removes it. Exercise the real controller against
// those semantics instead of replacing whole nested sections in this fake.
Map<String, dynamic> _memoryPatch(
  Map<String, dynamic> before,
  Map<String, dynamic> patch,
) {
  final result = _copy(before);
  for (final entry in patch.entries) {
    final value = entry.value;
    if (value == null) {
      result.remove(entry.key);
    } else if (value is Map) {
      result[entry.key] = _memoryPatch(
        result[entry.key] is Map
            ? Map<String, dynamic>.from(result[entry.key] as Map)
            : {},
        Map<String, dynamic>.from(value),
      );
    } else {
      result[entry.key] = value;
    }
  }
  return result;
}

class _Fixture {
  _Fixture._(this.client, this.memory) {
    controller = AskHawController(
      client: client,
      memoryRepository: memory,
      clock: () => now,
      dateMode: 'gregorian',
      selectedEventId: 'event-1',
      parseTime: (text) =>
          parsedTime ??
          (
            day: text.toLowerCase().contains('tomorrow')
                ? DateTime(2026, 10, 28)
                : DateTime(2026, 10, 27),
            hour: 15,
            minute: 0,
          ),
      onAccountChanged: () {
        accountChanges++;
        draft = '';
      },
      readPendingActions: () async => [],
      navigate: (route) async {
        routes.add(route);
      },
      setInput: (value) {
        inputs.add(value);
        draft = value;
      },
      addEvent: () async {
        eventAdds++;
      },
      readContext: (from, until) async {
        contextReads++;
        bounds.add((from, until));
        final snapshot = _copy(raw);
        if (!readStarted.isCompleted) readStarted.complete();
        final reply = contextReplies[contextReads];
        if (reply != null) return await reply;
        await holdRead?.future;
        return snapshot;
      },
      readExternal: (from, until) async {
        externalReads++;
        return external;
      },
      execute: (id, actions) async {
        mutationIds.add(id);
        mutations.add([for (final action in actions) _copy(action)]);
        if (!executeStarted.isCompleted) executeStarted.complete();
        await holdExecute?.future;
        if (failNextExecute) {
          failNextExecute = false;
          onLostAcknowledgement?.call(actions);
          throw const SocketException('Lost acknowledgement');
        }
        return receipt?.call(id) ??
            {'status': 'applied', 'mutation_id': id, 'results': []};
      },
      syncReminders: () async {
        reminderSyncs++;
      },
    );
  }
  static final now = DateTime.utc(2026, 10, 27, 15);
  final SupabaseClient client;
  final _Memory memory;
  late final AskHawController controller;
  final routes = <String>[], inputs = <String>[], mutationIds = <String>[];
  final mutations = <List<Map<String, dynamic>>>[];
  final bounds = <(DateTime, DateTime)>[];
  final readStarted = Completer<void>(), executeStarted = Completer<void>();
  Completer<void>? holdRead, holdExecute;
  final contextReplies = <int, Future<Map<String, dynamic>>>{};
  void Function(List<Map<String, dynamic>>)? onLostAcknowledgement;
  ({DateTime day, int? hour, int? minute})? parsedTime;
  int accountChanges = 0;
  String draft = '';
  bool failNextExecute = false;
  Map<String, dynamic> Function(String)? receipt;
  int eventAdds = 0, contextReads = 0, externalReads = 0, reminderSyncs = 0;
  List<ExternalCalendarEvent> external = [];
  Map<String, dynamic> raw = {
    'timezone': 'America/Los_Angeles',
    'personal_calendar_id': 'calendar-personal',
    'coverage': {'complete': true},
    'flows': [],
    'step_completions': {},
    'events': [
      {
        'id': 'event-1',
        'client_event_id': 'stable-id',
        'title': 'Dentist',
        'starts_at': '2026-10-27T17:00:00Z',
        'ends_at': '2026-10-27T18:00:00Z',
        'all_day': false,
        'event_revision': 7,
        'can_edit': true,
        'calendar_id': 'calendar-personal',
      },
    ],
  };
  static Future<_Fixture> create({
    bool signedIn = true,
    Map<String, dynamic> payload = const {},
    Future<http.Response?> Function(http.Request)? onHttp,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final client = SupabaseClient(
      'https://example.supabase.co',
      'fixture-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        final supplied = await onHttp?.call(request);
        if (supplied != null) return supplied;
        if (request.url.path.endsWith('search_ask_haw_flows_v1')) {
          return http.Response(
            '{"results":[]}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        throw StateError('Unexpected real repository read ${request.url}');
      }),
    );
    if (signedIn) {
      await client.auth.recoverSession(session('ask-haw-controller-owner'));
    }
    final fixture = _Fixture._(
      client,
      _Memory(client, AskHawMemory(payload: payload)),
    );
    addTearDown(() async {
      fixture.controller.dispose();
      await client.dispose();
    });
    return fixture;
  }

  Future<void> prepareMove() async {
    await controller.ask('Move this to tomorrow at 3pm');
    final option = controller.response!.options.firstWhere(
      (value) => value.id.startsWith('action:'),
    );
    await controller.choose(option.id);
    expect(
      controller.response!.options.any((value) => value.id == 'apply'),
      isTrue,
    );
  }
}

Map<String, dynamic> _contract() => {
  'version': 1,
  'adaptations': ['shorten', 'reschedule', 'pause', 'resume'],
  'steps': [
    {
      'id': 'first',
      'title': 'First practice',
      'guidance': 'Authored first guidance.',
      'minutes': 20,
      'prerequisites': [],
      'alternatives': [
        {
          'id': 'first-small',
          'label': 'Small first practice',
          'minutes': 5,
          'guidance': 'Short first guidance.',
          'countsAsCompletion': true,
        },
      ],
    },
    {
      'id': 'second',
      'title': 'Second practice',
      'guidance': 'Authored second guidance.',
      'minutes': 30,
      'prerequisites': ['first'],
      'alternatives': [
        {
          'id': 'second-small',
          'label': 'Small second practice',
          'minutes': 10,
          'guidance': 'Short second guidance.',
          'countsAsCompletion': false,
        },
      ],
    },
  ],
};
Map<String, dynamic> _flow() => {
  'id': 71,
  'user_id': 'ask-haw-controller-owner',
  'name': 'Authored practice',
  'color': 1,
  'active': true,
  'is_saved': false,
  'rules': [],
  'can_edit': true,
  'calendar_id': 'calendar-personal',
  'assistance_revision': 4,
  'assistance': _contract(),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'ordinary event and public explanation do not read private context or memory',
    () async {
      final f = await _Fixture.create();
      await f.controller.ask('Dentist Friday at 3');
      expect(f.controller.response, isNull);
      await f.controller.ask('What is a decan?');
      expect(f.controller.response!.options.single.id, 'open:library:decans');
      expect(f.contextReads, 0);
      expect(f.externalReads, 0);
      expect(f.memory.reads, 0);
      expect(f.memory.restores, 0);
      expect(f.mutations, isEmpty);
      expect(f.eventAdds, 0);
    },
  );
  test(
    'visitor can find real content and fit a reading without account reads',
    () async {
      final f = await _Fixture.create(signedIn: false);
      await f.controller.ask('Find reading flows');
      expect(
        f.controller.response!.options.any(
          (option) => option.id == 'open:maat:the-reading-house',
        ),
        isTrue,
      );
      await f.controller.ask('I have 10 minutes');
      expect(f.controller.response!.kind, AskHawResponseKind.results);
      expect(f.contextReads, 0);
      expect(f.externalReads, 0);
      expect(f.memory.reads, 0);
    },
  );
  test(
    'selected occurrence retains identity, revision and all original duration',
    () async {
      final f = await _Fixture.create();
      await f.prepareMove();
      expect(f.mutations, isEmpty);
      expect(f.controller.response!.body, contains('Only this occurrence'));
      await f.controller.choose('apply');
      final action = f.mutations.single.single;
      expect(action['id'], 'event-1');
      expect(action['expected_revision'], 7);
      expect(action['kind'], 'event_patch');
      final patch = action['patch'] as Map;
      expect(patch.keys.toSet(), {'starts_at', 'ends_at'});
      expect(
        DateTime.parse(
          patch['ends_at'] as String,
        ).difference(DateTime.parse(patch['starts_at'] as String)),
        const Duration(hours: 1),
      );
    },
  );
  for (final request in [
    'Move this to tomorrow at 3pm',
    'Shorten this to 10 minutes',
  ]) {
    test('missing confirmed end cannot prepare or apply: $request', () async {
      final f = await _Fixture.create();
      f.raw['events'] = [
        <String, dynamic>{
          ...Map<String, dynamic>.from((f.raw['events'] as List).single as Map),
          'ends_at': null,
        },
      ];
      final original = _copy(
        (f.raw['events'] as List).single as Map<String, dynamic>,
      );
      await f.controller.ask(request);
      expect(
        f.controller.response!.options.any((o) => o.id == 'apply'),
        isFalse,
      );
      final review = f.controller.response!.options.firstWhere(
        (o) => o.id.startsWith('action:'),
      );
      await f.controller.choose(review.id);
      expect(
        f.controller.response!.title,
        'Confirm this event’s end time first',
      );
      expect(f.controller.response!.kind, AskHawResponseKind.unavailable);
      expect(f.controller.response!.body, contains('existing editor'));
      expect(
        f.controller.response!.options.any((o) => o.id == 'apply'),
        isFalse,
      );
      await f.controller.choose('apply');
      expect(f.mutations, isEmpty);
      expect(f.mutationIds, isEmpty);
      expect(f.eventAdds, 0);
      expect(f.raw['events'], [original]);
      expect(f.reminderSyncs, 0);
    });
  }

  test(
    'two reviews do not execute until Apply and duplicate Apply is consumed',
    () async {
      final f = await _Fixture.create();
      await f.prepareMove();
      expect(f.mutations, isEmpty);
      f.holdExecute = Completer<void>();
      final applying = f.controller.choose('apply');
      await f.executeStarted.future;
      await f.controller.choose('apply');
      expect(f.mutations, hasLength(1));
      f.holdExecute!.complete();
      await applying;
      expect(f.controller.response!.kind, AskHawResponseKind.success);
      await f.controller.choose('apply');
      expect(f.mutations, hasLength(1));
      expect(f.reminderSyncs, 1);
    },
  );
  test(
    'lost acknowledgement retries the same logical mutation and exact actions',
    () async {
      final f = await _Fixture.create();
      await f.prepareMove();
      f.failNextExecute = true;
      await f.controller.choose('apply');
      expect(f.controller.response!.kind, AskHawResponseKind.unavailable);
      expect(
        f.controller.response!.options.any((value) => value.id == 'apply'),
        isTrue,
      );
      await f.controller.choose('apply');
      expect(f.controller.response!.kind, AskHawResponseKind.success);
      expect(f.mutationIds, hasLength(2));
      expect(f.mutationIds[1], f.mutationIds[0]);
      expect(f.mutations[1], f.mutations[0]);
    },
  );
  test(
    'unconfirmed or mismatched execution receipts never claim a saved change',
    () async {
      for (final invalid in [
        (String id) => <String, dynamic>{
          'status': 'conflict',
          'mutation_id': id,
        },
        (String id) => <String, dynamic>{
          'status': 'applied',
          'mutation_id': 'another-request',
        },
        (String id) => <String, dynamic>{},
      ]) {
        final f = await _Fixture.create();
        f.receipt = invalid;
        await f.prepareMove();
        await f.controller.choose('apply');
        expect(f.controller.response!.kind, AskHawResponseKind.unavailable);
        expect(f.reminderSyncs, 0);
      }
    },
  );
  test(
    'account A to B to A fences private read and any old response/action',
    () async {
      final f = await _Fixture.create();
      f.holdRead = Completer<void>();
      final asking = f.controller.ask("What's next?");
      await f.readStarted.future;
      await f.client.auth.recoverSession(session('replacement-account'));
      await f.client.auth.recoverSession(session('ask-haw-controller-owner'));
      await Future<void>.delayed(Duration.zero);
      f.holdRead!.complete();
      await asking;
      expect(f.controller.response!.title, 'Your account changed');
      expect(f.controller.response!.body, isNot(contains('Dentist')));
      await f.controller.choose('action:move:event-1');
      await f.controller.choose('apply');
      expect(f.mutations, isEmpty);
      expect(f.externalReads, 0);
    },
  );
  test(
    'late successful acknowledgement after account replacement stays fenced',
    () async {
      final f = await _Fixture.create();
      await f.prepareMove();
      f.holdExecute = Completer<void>();
      final applying = f.controller.choose('apply');
      await f.executeStarted.future;
      await f.client.auth.recoverSession(session('replacement-account'));
      await f.client.auth.recoverSession(session('ask-haw-controller-owner'));
      await Future<void>.delayed(Duration.zero);
      f.holdExecute!.complete();
      await applying;
      expect(f.controller.response!.title, 'Your account changed');
      expect(f.reminderSyncs, 0);
    },
  );
  test(
    'shortening uses the selected step, never a different step alternative',
    () async {
      final f = await _Fixture.create();
      f.raw['flows'] = [_flow()];
      final event = (f.raw['events'] as List).single as Map;
      event['flow_local_id'] = 71;
      event['filed_flow_id'] = 71;
      event['ends_at'] = '2026-10-27T17:20:00Z';
      event['behavior_payload'] = {
        'ask_haw': {'step_id': 'first'},
      };
      await f.controller.ask('Shorten this to 10 minutes');
      expect(
        f.controller.response!.options.any(
          (value) => value.id.startsWith('action:'),
        ),
        isFalse,
      );
      await f.controller.choose('action:shorten:event-1');
      expect(
        f.controller.response!.options.any((value) => value.id == 'apply'),
        isFalse,
      );
      await f.controller.ask('Shorten this to 5 minutes');
      await f.controller.choose('action:shorten:event-1');
      expect(
        f.controller.response!.options.any((value) => value.id == 'apply'),
        isTrue,
      );
      expect(f.controller.response!.body, contains('Short first guidance.'));
      await f.controller.choose('apply');
      final patch = f.mutations.single.single['patch'] as Map;
      expect(patch['ends_at'], '2026-10-27T17:05:00.000Z');
    },
  );
  test(
    'confirmed availability and time preference bound proposals in account timezone',
    () async {
      final f = await _Fixture.create(
        payload: {
          'preferences': {
            'availableStartHour': 9,
            'availableEndHour': 21,
            'preferredTimeOfDay': 'evening',
            'preferredDurationMinutes': 10,
            'suggestionsEnabled': true,
          },
          'bindings': {
            'old phrase': {'intent': 'find', 'query': 'sky'},
          },
        },
      );
      f.raw['flows'] = [_flow()];
      f.raw['events'] = [];
      await f.controller.restoreMemory();
      await f.controller.ask('I have 10 minutes');
      final proposal = f.controller.response!.options.firstWhere(
        (value) => value.id.startsWith('proposal:'),
      );
      await f.controller.choose(proposal.id);
      await f.controller.choose('apply');
      final event = f.mutations.single.single['event'] as Map;
      final start = DateTime.parse(event['starts_at'] as String);
      expect(start.isBefore(DateTime.utc(2026, 10, 28, 1)), isFalse);
      expect(start.isAfter(DateTime.utc(2026, 10, 28, 4)), isFalse);
      expect(
        DateTime.parse(event['ends_at'] as String).difference(start).inMinutes,
        5,
      );
      expect(event['detail'], 'Short first guidance.');
      expect(
        (event['behavior_payload'] as Map)['ask_haw']['counts_as_completion'],
        isTrue,
      );
    },
  );
  test(
    'new availability keeps confirmed preferences and phrase bindings',
    () async {
      final f = await _Fixture.create(
        payload: {
          'preferences': {
            'suggestionsEnabled': true,
            'preferredDurationMinutes': 20,
            'preferredTimeOfDay': 'evening',
          },
          'bindings': {
            'reset': {'intent': 'find', 'query': 'stability'},
          },
        },
      );
      f.raw['events'] = [];
      f.raw['flows'] = [_flow()];
      await f.controller.restoreMemory();
      await f.controller.ask('Help me plan today');
      expect(
        f.controller.response!.options.any(
          (value) => value.id == 'availability',
        ),
        isTrue,
      );
      await f.controller.choose('availability');
      await f.controller.choose('availability:18:21');
      expect(f.memory.value.preferences['preferredDurationMinutes'], 20);
      expect(f.memory.value.preferences['preferredTimeOfDay'], 'evening');
      expect(f.memory.value.preferences['availableStartHour'], 18);
      expect(f.memory.value.preferences['availableEndHour'], 21);
      expect(f.memory.value.bindings.containsKey('reset'), isTrue);
    },
  );
  test(
    'remote account memory loads lazily on first personal request only',
    () async {
      final f = await _Fixture.create();
      f.memory.remote = AskHawMemory(
        revision: 8,
        epoch: 3,
        payload: {
          'bindings': {
            'my quiet return': {'intent': 'explain', 'query': 'decan'},
          },
          'preferences': {'availableStartHour': 18, 'availableEndHour': 21},
        },
      );
      await f.controller.restoreMemory();
      expect(f.memory.restores, 1);
      expect(f.memory.reads, 0);
      await f.controller.ask('Dentist tomorrow at 3');
      await f.controller.ask('What is a decan?');
      expect(f.memory.reads, 0);
      expect(f.contextReads, 0);
      await f.controller.ask("What's next?");
      expect(f.memory.reads, 1);
      expect(f.contextReads, 1);
      await f.controller.ask("What's next?");
      expect(f.memory.reads, 1);
      await f.controller.ask('My quiet return');
      expect(f.controller.response!.options.first.id, 'open:library:decans');
    },
  );

  test(
    'failed remote account memory does not fabricate personal readiness',
    () async {
      final f = await _Fixture.create();
      f.memory.failRead = true;
      await f.controller.ask('Help me plan today');
      expect(f.controller.response!.kind, AskHawResponseKind.unavailable);
      expect(f.contextReads, 0);
      expect(f.mutations, isEmpty);
      await f.controller.ask('What is a decan?');
      expect(f.controller.response!.options.single.id, 'open:library:decans');
      expect(f.memory.reads, 1);
    },
  );

  test('late remote memory cannot publish after account A to B to A', () async {
    final f = await _Fixture.create();
    f.memory.remote = AskHawMemory(
      payload: {
        'bindings': {
          'private phrase': {'intent': 'explain', 'query': 'decan'},
        },
      },
    );
    f.memory.holdRead = Completer<void>();
    final asking = f.controller.ask("What's next?");
    await f.memory.readStarted.future;
    await f.client.auth.recoverSession(session('replacement-account'));
    await f.client.auth.recoverSession(session('ask-haw-controller-owner'));
    await Future<void>.delayed(Duration.zero);
    f.memory.holdRead!.complete();
    await asking;
    expect(f.controller.response!.title, 'Your account changed');
    expect(f.contextReads, 0);
    expect(f.mutations, isEmpty);
  });

  test(
    'older private read cannot replace newer request context or selected revision',
    () async {
      final f = await _Fixture.create();
      final older = Completer<Map<String, dynamic>>();
      f.contextReplies[1] = older.future;
      final original = _copy(f.raw);
      final first = f.controller.ask('Move this to tomorrow at 3pm');
      await f.readStarted.future;
      final latest = (f.raw['events'] as List).single as Map;
      latest['event_revision'] = 8;
      latest['starts_at'] = '2026-10-27T18:00:00Z';
      latest['ends_at'] = '2026-10-27T19:00:00Z';
      await f.controller.ask('Shorten this to 5 minutes');
      older.complete(original);
      await first;
      expect(f.controller.response!.title, contains('Shorten'));
      await f.controller.choose('action:shorten:event-1');
      await f.controller.choose('apply');
      final action = f.mutations.single.single;
      expect(action['expected_revision'], 8);
      expect((action['patch'] as Map)['ends_at'], '2026-10-27T18:05:00.000Z');
    },
  );

  test(
    'plan lost acknowledgement retries exact committed receipt without a fresh proposal',
    () async {
      final f = await _Fixture.create(
        payload: {
          'preferences': {
            'availableStartHour': 18,
            'availableEndHour': 21,
            'suggestionsEnabled': true,
          },
        },
      );
      f.raw['events'] = [];
      f.raw['flows'] = [_flow()];
      await f.controller.ask('Help me plan today');
      final proposal = f.controller.response!.options.firstWhere(
        (option) => option.id.startsWith('proposal:'),
      );
      await f.controller.choose(proposal.id);
      f.onLostAcknowledgement = (actions) {
        final created = actions.single['event'] as Map;
        f.raw['events'] = [
          {
            ...created,
            'id': 'committed-event',
            'client_event_id': actions.single['client_event_id'],
            'event_revision': 1,
            'can_edit': true,
            'calendar_id': 'calendar-personal',
            'filed_flow_id': 71,
          },
        ];
      };
      f.failNextExecute = true;
      await f.controller.choose('apply');
      expect(f.controller.response!.kind, AskHawResponseKind.unavailable);
      final reads = f.contextReads;
      await f.controller.choose('apply');
      expect(f.controller.response!.kind, AskHawResponseKind.success);
      expect(f.contextReads, reads);
      expect(f.mutations, hasLength(2));
      expect(f.mutationIds[1], f.mutationIds[0]);
      expect(f.mutations[1], f.mutations[0]);
      expect(f.reminderSyncs, 1);
    },
  );

  test(
    'a move beyond loaded calendar coverage cannot be applied as conflict free',
    () async {
      final f = await _Fixture.create();
      f.parsedTime = (day: DateTime(2027, 3, 15), hour: 15, minute: 0);
      await f.controller.ask('Move this to March 15 at 3pm');
      await f.controller.choose('action:move:event-1');
      expect(
        f.controller.response!.options.any((option) => option.id == 'apply'),
        isFalse,
      );
      await f.controller.choose('apply');
      expect(f.mutations, isEmpty);
    },
  );

  test(
    'account departure clears the visible draft and old controller remains fenced',
    () async {
      final f = await _Fixture.create();
      f.draft = 'A private unsent request';
      await f.controller.ask('What is a decan?');
      expect(f.draft, 'A private unsent request');
      expect(f.accountChanges, 0);
      await f.client.auth.recoverSession(session('replacement-account'));
      await Future<void>.delayed(Duration.zero);
      expect(f.draft, isEmpty);
      expect(f.accountChanges, 1);
      await f.controller.choose('input:I have 10 minutes');
      expect(f.inputs, isEmpty);
      expect(f.mutations, isEmpty);
    },
  );
  test(
    'older action acknowledgement settles without overwriting a newer answer',
    () async {
      final f = await _Fixture.create();
      await f.prepareMove();
      f.holdExecute = Completer<void>();
      final applying = f.controller.choose('apply');
      await f.executeStarted.future;
      await f.controller.ask('What is Maat?');
      expect(f.controller.response!.title, "Ma'at");
      f.holdExecute!.complete();
      await applying;
      expect(f.controller.response!.title, "Ma'at");
      expect(f.controller.response!.options.first.id, 'open:library:maat');
      expect(f.controller.busy, isFalse);
      expect(f.mutations, hasLength(1));
    },
  );

  test(
    'older memory acknowledgement keeps its confirmed meaning without replacing newer answer',
    () async {
      final f = await _Fixture.create();
      await f.controller.ask('What is a decan?');
      f.memory.holdUpdate = Completer<void>();
      final remembering = f.controller.choose('remember:library:decans');
      await f.memory.updateStarted.future;
      await f.controller.ask('What is Maat?');
      expect(f.controller.response!.title, "Ma'at");
      f.memory.holdUpdate!.complete();
      await remembering;
      expect(f.controller.response!.title, "Ma'at");
      expect(
        f.memory.value.bindingFor('what is a decan')!['contentId'],
        'library:decans',
      );
      expect(f.controller.busy, isFalse);
    },
  );
  test(
    'explicit shorter-session choice saves only acknowledged future preference',
    () async {
      final f = await _Fixture.create(
        payload: {
          'preferences': {
            'availableStartHour': 18,
            'availableEndHour': 21,
            'preferredTimeOfDay': 'evening',
          },
        },
      );
      f.raw['flows'] = [_flow()];
      f.raw['events'] = [];
      await f.controller.ask('Help me use shorter sessions');
      expect(f.memory.patches, isEmpty);
      expect(f.mutations, isEmpty);
      final choice = f.controller.response!.options.firstWhere(
        (option) => option.id == 'duration:71:first:first-small',
      );
      expect(choice.detail, contains('Short first guidance.'));
      f.memory.holdUpdate = Completer<void>();
      final saving = f.controller.choose(choice.id);
      await f.memory.updateStarted.future;
      expect(
        f.memory.value.preferences.containsKey('flowDurationMinutes'),
        isFalse,
      );
      expect(f.controller.response!.kind, isNot(AskHawResponseKind.success));
      expect(f.mutations, isEmpty);
      f.memory.holdUpdate!.complete();
      await saving;
      expect(f.controller.response!.kind, AskHawResponseKind.success);
      expect(
        f.controller.response!.body,
        contains('Existing sessions have not changed'),
      );
      expect(
        (f.memory.value.preferences['flowDurationMinutes'] as Map)['71'],
        5,
      );
      expect(f.memory.value.preferences['preferredTimeOfDay'], 'evening');
      expect(f.memory.patches.single.keys, ['preferences']);
      expect(f.mutations, isEmpty);
      await f.controller.ask('Help me plan today');
      final proposal = f.controller.response!.options.firstWhere(
        (option) => option.id.startsWith('proposal:'),
      );
      expect(proposal.detail, startsWith('5 minutes'));
      expect(f.mutations, isEmpty);
    },
  );

  test(
    'unacknowledged or unavailable shorter choices never change sessions or confirmed preference',
    () async {
      final f = await _Fixture.create();
      f.raw['events'] = [];
      f.raw['flows'] = [_flow()];
      await f.controller.ask('Help me use shorter sessions');
      await f.controller.choose('duration:71:first:missing-alternative');
      expect(f.memory.patches, isEmpty);
      f.memory.failUpdate = true;
      await f.controller.choose('duration:71:first:first-small');
      expect(f.controller.response!.kind, AskHawResponseKind.unavailable);
      expect(
        f.memory.value.preferences.containsKey('flowDurationMinutes'),
        isFalse,
      );
      expect(f.mutations, isEmpty);
      final unavailable = await _Fixture.create();
      unavailable.raw['events'] = [];
      unavailable.raw['flows'] = [
        {..._flow(), 'can_edit': false},
      ];
      await unavailable.controller.ask('Help me use shorter sessions');
      expect(
        unavailable.controller.response!.options.where(
          (option) => option.id.startsWith('duration:'),
        ),
        isEmpty,
      );
      await unavailable.controller.choose('duration:71:first:first-small');
      expect(unavailable.memory.patches, isEmpty);
      expect(unavailable.mutations, isEmpty);
    },
  );

  test('plan tomorrow uses the requested account-local day', () async {
    final f = await _Fixture.create(
      payload: {
        'preferences': {'availableStartHour': 18, 'availableEndHour': 21},
      },
    );
    f.raw['events'] = [];
    f.raw['flows'] = [_flow()];
    await f.controller.ask('Help me plan tomorrow');
    final proposal = f.controller.response!.options.firstWhere(
      (option) => option.id.startsWith('proposal:'),
    );
    await f.controller.choose(proposal.id);
    await f.controller.choose('apply');
    final created = f.mutations.single.single['event'] as Map;
    expect(
      DateTime.parse(created['starts_at'] as String),
      DateTime.utc(2026, 10, 29, 1),
    );
    expect(
      DateTime.parse(created['ends_at'] as String),
      DateTime.utc(2026, 10, 29, 1, 20),
    );
  });
  for (final zone in ['America/New_York', 'Asia/Dubai']) {
    test(
      'external all-day civil dates block the account midnight window in $zone',
      () async {
        final f = await _Fixture.create(
          payload: {
            'preferences': {'availableStartHour': 0, 'availableEndHour': 2},
          },
        );
        f.raw['timezone'] = zone;
        f.raw['events'] = [];
        f.raw['flows'] = [_flow()];
        // Establish that a real authored practice fits the otherwise open window.
        await f.controller.ask('Help me plan tomorrow');
        expect(
          f.controller.response!.options.any(
            (o) => o.id.startsWith('proposal:'),
          ),
          isTrue,
        );

        // Use the external owner's actual date-only decoder, which projects to
        // device-local midnight. Ask must recover the civil dates for the account
        // timezone before claiming that any midnight window is free.
        f.external = [
          ExternalCalendarEvent.fromJson({
            'id': 'all-day-busy',
            'client_event_id': 'external:busy:all-day-busy',
            'source_id': 'selected-external-calendar',
            'title': 'Away all day',
            'all_day': true,
            'start_date': '2026-10-28',
            'end_date': '2026-10-29',
          }),
        ];
        await f.controller.ask('Help me plan tomorrow');
        expect(f.externalReads, 2);
        expect(f.controller.response!.kind, AskHawResponseKind.unavailable);
        expect(
          f.controller.response!.options.any(
            (o) => o.id.startsWith('proposal:'),
          ),
          isFalse,
        );
        expect(
          f.controller.response!.options.any((o) => o.id == 'apply'),
          isFalse,
        );
        expect(f.mutations, isEmpty);
        expect(f.eventAdds, 0);
      },
    );
  }

  test(
    'valid prerequisite graph chooses an eligible step even when authored order differs',
    () async {
      final f = await _Fixture.create(
        payload: {
          'preferences': {'availableStartHour': 18, 'availableEndHour': 21},
        },
      );
      f.raw['events'] = [];
      f.raw['flows'] = [
        {
          ..._flow(),
          'assistance': {
            'version': 1,
            'adaptations': [],
            'steps': [
              {
                'id': 'finish',
                'title': 'Finish',
                'guidance': 'Finish after preparation.',
                'minutes': 10,
                'prerequisites': ['prepare'],
              },
              {
                'id': 'prepare',
                'title': 'Prepare first',
                'guidance': 'The eligible preparation.',
                'minutes': 5,
                'prerequisites': [],
              },
            ],
          },
        },
      ];
      await f.controller.ask('Help me plan today');
      final proposals = f.controller.response!.options
          .where((option) => option.id.startsWith('proposal:'))
          .toList();
      expect(proposals.single.id, 'proposal:71:prepare');
      expect(proposals.single.detail, contains('The eligible preparation.'));
      await f.controller.choose(proposals.single.id);
      await f.controller.choose('apply');
      final created = f.mutations.single.single['event'] as Map;
      expect(
        (created['behavior_payload'] as Map)['ask_haw']['step_id'],
        'prepare',
      );
    },
  );
  for (final intent in ['find', 'event']) {
    test(
      'confirmed $intent correction removes the old learned target and duration',
      () async {
        final f = await _Fixture.create(
          payload: {
            'bindings': {
              'evening reset': {
                'intent': 'find',
                'query': 'decan',
                'contentId': 'library:decans',
                'title': 'Decans',
                'minutes': 20,
              },
              'another phrase': {'intent': 'find', 'query': 'stability'},
            },
            'preferences': {'preferredDurationMinutes': 30},
          },
        );
        // The shared Quick Add sheet restores confirmed device memory on open
        // before a saved bare phrase can be interpreted as an Ask request.
        await f.controller.restoreMemory();
        expect(f.memory.restores, 1);
        await f.controller.ask('Evening reset');
        expect(f.controller.response!.options.first.id, 'open:library:decans');
        await f.controller.choose('correct');
        await f.controller.choose('correction:$intent');
        final transport =
            (f.memory.patches.single['bindings'] as Map)['evening reset']
                as Map;
        for (final key in ['contentId', 'title', 'minutes']) {
          expect(
            transport.containsKey(key),
            isTrue,
            reason: '$key needs a removal tombstone',
          );
          expect(transport[key], isNull, reason: key);
        }
        final corrected = f.memory.value.bindingFor('evening reset')!;
        expect(corrected['intent'], intent);
        for (final key in ['contentId', 'title', 'minutes']) {
          expect(corrected.containsKey(key), isFalse, reason: key);
        }
        expect(f.memory.value.bindingFor('another phrase'), {
          'intent': 'find',
          'query': 'stability',
        });
        expect(f.memory.value.preferredDurationMinutes, 30);
        expect(f.eventAdds, intent == 'event' ? 1 : 0);
        await f.controller.ask('Evening reset');
        expect(
          f.controller.response?.options.any(
                (o) => o.id == 'open:library:decans',
              ) ??
              false,
          isFalse,
        );
      },
    );
  }

  test(
    'remembered published result resolves the same currently visible post instead of repeating search ranking',
    () async {
      var searches = 0, postReads = 0, visible = true, blocked = false;
      var title = 'Unusual writing practice';
      final f = await _Fixture.create(
        onHttp: (request) async {
          http.Response reply(Object? body, [int status = 200]) =>
              http.Response(
                jsonEncode(body),
                status,
                request: request,
                headers: {'content-type': 'application/json'},
              );
          if (request.url.path.endsWith('/flows')) return reply([]);
          if (request.url.path.endsWith('search_ask_haw_flows_v1')) {
            searches++;
            return reply({
              'status': 'ready',
              'results': [
                {'id': 'remembered-post', 'name': 'Unusual writing practice'},
              ],
            });
          }
          if (request.url.path.endsWith('/flow_posts')) {
            postReads++;
            expect(request.url.queryParameters['id'], 'eq.remembered-post');
            return reply(
              visible
                  ? {
                      'id': 'remembered-post',
                      'user_id': 'published-author',
                      'flow_id': 99,
                      'name': title,
                      'color': 1,
                      'rules': [],
                      'created_at': '2026-10-27T00:00:00Z',
                      'payload': {'events': []},
                    }
                  : null,
            );
          }
          if (request.url.path.endsWith('/user_blocks')) {
            return reply(
              blocked
                  ? [
                      {'blocked_user_id': 'published-author'},
                    ]
                  : [],
            );
          }
          return null;
        },
      );
      await f.controller.ask('Find unusual writing practice');
      expect(
        f.controller.response!.options.first.id,
        'open:post:remembered-post',
      );
      await f.controller.choose('remember:post:remembered-post');
      final binding = f.memory.value.bindingFor(
        'find unusual writing practice',
      )!;
      expect(binding['contentId'], 'post:remembered-post');
      expect(binding['title'], 'Unusual writing practice');
      title = 'Current published title';
      await f.controller.ask('Find unusual writing practice');
      expect(
        f.controller.response!.options.first.id,
        'open:post:remembered-post',
      );
      expect(
        f.controller.response!.options.first.label,
        'Current published title',
      );
      expect(searches, 1);
      expect(postReads, 1);
      blocked = true;
      await f.controller.ask('Find unusual writing practice');
      expect(
        f.controller.response!.title,
        'That remembered Flow is unavailable',
      );
      expect(
        f.controller.response!.options.any(
          (option) => option.id.startsWith('open:post:'),
        ),
        isFalse,
      );
      blocked = false;
      visible = false;
      await f.controller.ask('Find unusual writing practice');
      expect(
        f.controller.response!.title,
        'That remembered Flow is unavailable',
      );
      expect(postReads, 3);
      expect(searches, 1);
      expect(f.routes, isEmpty);
      expect(f.mutations, isEmpty);
    },
  );

  test(
    'failed current published-post lookup does not trust remembered route or stale cached title',
    () async {
      final f = await _Fixture.create(
        payload: {
          'bindings': {
            'find my writing circle': {
              'intent': 'find',
              'query': 'writing circle',
              'contentId': 'post:unconfirmed-post',
              'title': 'An old title',
            },
          },
        },
        onHttp: (request) async {
          if (request.url.path.endsWith('/flows')) {
            return http.Response(
              '[]',
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.url.path.endsWith('/flow_posts')) {
            return http.Response(
              '{"message":"temporarily unavailable"}',
              503,
              headers: {'content-type': 'application/json'},
            );
          }
          return null;
        },
      );
      await f.controller.ask('Find my writing circle');
      expect(
        f.controller.response!.title,
        'I couldn’t confirm the remembered Flow',
      );
      expect(
        f.controller.response!.options.any(
          (option) => option.id.startsWith('open:'),
        ),
        isFalse,
      );
      expect(f.routes, isEmpty);
      expect(f.mutations, isEmpty);
    },
  );
}
