import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/features/ask_haw/ask_haw_memory.dart';
import 'package:mobile/features/ask_haw/ask_haw_memory_repository.dart';
import 'package:mobile/features/ask_haw/ask_haw_settings_card.dart';
import 'package:mobile/features/calendar/the_reading_house_flow.dart'
    show kReadingHouseTitle;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SupabaseClient client;
  late _Repository store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    client = SupabaseClient(
      'https://example.supabase.test',
      'fixture',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async => http.Response('[]', 200)),
    );
    await client.auth.recoverSession(_session('account-a'));
    store = _Repository(client);
  });
  tearDown(() async => client.dispose());

  Future<void> show(
    WidgetTester tester, {
    AskHawMemoryRepositoryFactory? factory,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        body: SingleChildScrollView(
          child: AskHawSettingsCard(
            client: client,
            repositoryFactory: factory ?? (_) => store,
          ),
        ),
      ),
    ),
  );
  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('ask-haw-memory-open')));
    await tester.pump();
  }

  testWidgets('mount is lazy and failed reads do not show invented memory', (
    tester,
  ) async {
    var creations = 0;
    final read = Completer<AskHawMemory>();
    store.nextRead = read;
    await show(
      tester,
      factory: (_) {
        creations++;
        return store;
      },
    );
    expect(creations, 0);
    expect(store.reads, 0);
    await open(tester);
    expect(creations, 1);
    expect(find.text('Optional suggestions'), findsNothing);
    read.completeError(StateError('offline'));
    await tester.pump();
    expect(find.text('No phrases remembered yet.'), findsNothing);
    expect(find.text('Optional suggestions'), findsNothing);
    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(find.text('Optional suggestions'), findsOneWidget);
    expect(creations, 1);
  });

  testWidgets(
    'preferences wait for acknowledgement and preserve other fields',
    (tester) async {
      store.memory = AskHawMemory(
        payload: {
          'preferences': {
            'suggestionsEnabled': true,
            'interests': ['reading'],
            'preferredDurationMinutes': 15,
          },
          'bindings': {
            'evening reset': {
              'intent': 'find',
              'contentId': 'maat:the-reading-house',
            },
            'shared practice': {
              'intent': 'find',
              'contentId': 'post:published-fixture',
              'title': 'A quiet evening practice',
            },
          },
          'hidden': ['maat:the-reading-house'],
        },
      );
      await show(tester);
      await open(tester);
      expect(find.text('Find $kReadingHouseTitle.'), findsOneWidget);
      expect(find.text('Find A quiet evening practice.'), findsOneWidget);
      expect(find.text(kReadingHouseTitle), findsOneWidget);
      expect(find.text('maat:the-reading-house'), findsNothing);
      expect(find.text('15 minutes'), findsOneWidget);
      final write = Completer<AskHawMemory>();
      store.nextWrite = write;
      await tester.tap(
        find.byKey(const ValueKey('ask-haw-suggestions-toggle')),
      );
      await tester.pump();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );
      final preferences = store.lastPatch!['preferences'] as Map;
      expect(preferences['suggestionsEnabled'], isFalse);
      expect(preferences['interests'], ['reading']);
      write.complete(
        AskHawMemory(
          payload: {
            ...store.memory.payload,
            'preferences': {...preferences},
          },
        ),
      );
      await tester.pump();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
      expect(find.text('Remembered details updated.'), findsOneWidget);
    },
  );

  testWidgets(
    'custom planning window stays saved until acknowledged or reset',
    (tester) async {
      store.memory = AskHawMemory(
        payload: {
          'preferences': {
            'availableStartHour': 10,
            'availableEndHour': 16,
            'interests': ['reading'],
            'preferredDurationMinutes': 15,
          },
        },
      );
      await show(tester);
      await open(tester);
      expect(find.text('Custom · 10 a.m.–4 p.m.'), findsOneWidget);
      final firstWrite = Completer<AskHawMemory>();
      store.nextWrite = firstWrite;
      await tester.ensureVisible(
        find.byKey(const ValueKey('ask-haw-window-10:16-false')),
      );
      await tester.tap(
        find.byKey(const ValueKey('ask-haw-window-10:16-false')),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Evening · 6–9 p.m.').last);
      await tester.pump();
      expect(store.lastPatch, {
        'preferences': {'availableStartHour': 18, 'availableEndHour': 21},
      });
      expect(
        find.byKey(const ValueKey('ask-haw-window-10:16-true')),
        findsOneWidget,
      );
      firstWrite.completeError(StateError('offline'));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('ask-haw-window-10:16-false')),
        findsOneWidget,
      );
      expect(find.text('Remembered details updated.'), findsNothing);
      final confirmed = Completer<AskHawMemory>();
      store.nextWrite = confirmed;
      await tester.ensureVisible(find.text('Try again'));
      await tester.tap(find.text('Try again'));
      await tester.pump();
      confirmed.complete(
        AskHawMemory(
          payload: {
            'preferences': {
              ...store.memory.preferences,
              'availableStartHour': 18,
              'availableEndHour': 21,
            },
          },
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('ask-haw-window-18:21-false')),
        findsOneWidget,
      );
      expect(store.memory.preferences['interests'], ['reading']);
      expect(store.memory.preferences['preferredDurationMinutes'], 15);
      final reset = Completer<AskHawMemory>();
      store.nextWrite = reset;
      await tester.ensureVisible(
        find.byKey(const ValueKey('ask-haw-window-18:21-false')),
      );
      await tester.tap(
        find.byKey(const ValueKey('ask-haw-window-18:21-false')),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Ask each time').last);
      await tester.pump();
      expect(store.lastPatch, {
        'preferences': {'availableStartHour': null, 'availableEndHour': null},
      });
      expect(
        find.byKey(const ValueKey('ask-haw-window-18:21-true')),
        findsOneWidget,
      );
      reset.complete(
        AskHawMemory(
          payload: {
            'preferences': {...store.memory.preferences}
              ..remove('availableStartHour')
              ..remove('availableEndHour'),
          },
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('ask-haw-window--false')),
        findsOneWidget,
      );
      expect(store.memory.preferences['interests'], ['reading']);
    },
  );

  testWidgets(
    'per-Flow reset keeps acknowledged row on failure and removes only its key',
    (tester) async {
      store.memory = AskHawMemory(
        payload: {
          'preferences': {
            'flowDurationMinutes': {'42': 15},
            'flowDurationTitles': {'42': kReadingHouseTitle},
            'interests': ['reading'],
          },
        },
      );
      await show(tester);
      await open(tester);
      expect(find.text('$kReadingHouseTitle · 15 minutes'), findsOneWidget);
      // Another device adds a different Flow before this selective removal.
      store.memory = AskHawMemory(
        payload: {
          'preferences': {
            ...store.memory.preferences,
            'flowDurationMinutes': {'42': 15, '77': 20},
            'flowDurationTitles': {
              '42': kReadingHouseTitle,
              '77': 'Writing practice',
            },
          },
        },
      );
      final first = Completer<AskHawMemory>();
      store.nextWrite = first;
      await tester.ensureVisible(
        find.byKey(const ValueKey('ask-haw-remove-flow-duration-42')),
      );
      await tester.tap(
        find.byKey(const ValueKey('ask-haw-remove-flow-duration-42')),
      );
      await tester.pump();
      expect(store.lastPatch, {
        'preferences': {
          'flowDurationMinutes': {'42': null},
          'flowDurationTitles': {'42': null},
        },
      });
      expect(find.text('$kReadingHouseTitle · 15 minutes'), findsOneWidget);
      first.completeError(StateError('offline'));
      await tester.pump();
      expect(find.text('$kReadingHouseTitle · 15 minutes'), findsOneWidget);
      final acknowledged = Completer<AskHawMemory>();
      store.nextWrite = acknowledged;
      await tester.ensureVisible(find.text('Try again'));
      await tester.tap(find.text('Try again'));
      await tester.pump();
      acknowledged.complete(
        AskHawMemory(
          payload: {
            'preferences': {
              ...store.memory.preferences,
              'flowDurationMinutes': {'77': 20},
              'flowDurationTitles': {'77': 'Writing practice'},
            },
          },
        ),
      );
      await tester.pump();
      expect(find.text('$kReadingHouseTitle · 15 minutes'), findsNothing);
      expect(find.text('Writing practice · 20 minutes'), findsOneWidget);
      expect(store.memory.preferences['interests'], ['reading']);
    },
  );

  testWidgets(
    'a revision conflict shows saved truth and retries only on request',
    (tester) async {
      store.memory = AskHawMemory(
        payload: {
          'preferences': {'suggestionsEnabled': true},
        },
      );
      await show(tester);
      await open(tester);
      final write = Completer<AskHawMemory>();
      store.nextWrite = write;
      await tester.tap(
        find.byKey(const ValueKey('ask-haw-suggestions-toggle')),
      );
      await tester.pump();
      final newer = AskHawMemory(
        revision: 4,
        payload: {
          'preferences': {
            'suggestionsEnabled': true,
            'interests': ['journaling'],
          },
        },
      );
      store.memory = newer;
      write.completeError(AskHawMemoryConflict(newer));
      await tester.pump();
      expect(find.textContaining('Review the saved version'), findsOneWidget);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );
      await tester.ensureVisible(find.text('Try again'));
      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect((store.lastPatch!['preferences'] as Map)['interests'], [
        'journaling',
      ]);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
    },
  );

  testWidgets(
    'exact usual time edits and resets wait for saved acknowledgement',
    (tester) async {
      store.memory = AskHawMemory(
        payload: {
          'preferences': {
            'preferredHour': 20,
            'preferredMinute': 15,
            'preferredTimeOfDay': 'evening',
            'interests': ['reading'],
          },
        },
      );
      await show(tester);
      await open(tester);
      AskHawSettingsView view() =>
          tester.widget(find.byType(AskHawSettingsView));
      expect(view().usualStartTime, const TimeOfDay(hour: 20, minute: 15));
      await tester.ensureVisible(
        find.byKey(const ValueKey('ask-haw-usual-time-change')),
      );
      await tester.tap(find.byKey(const ValueKey('ask-haw-usual-time-change')));
      await tester.pump(const Duration(milliseconds: 300));
      final picker = find.byType(TimePickerDialog);
      expect(
        tester.widget<TimePickerDialog>(picker).initialTime,
        const TimeOfDay(hour: 20, minute: 15),
      );
      final write = Completer<AskHawMemory>();
      store.nextWrite = write;
      Navigator.of(
        tester.element(picker),
      ).pop(const TimeOfDay(hour: 9, minute: 45));
      await tester.pump(const Duration(milliseconds: 300));
      expect(store.lastPatch, {
        'preferences': {'preferredHour': 9, 'preferredMinute': 45},
      });
      expect(view().usualStartTime, const TimeOfDay(hour: 20, minute: 15));
      write.completeError(StateError('offline'));
      await tester.pump();
      expect(view().usualStartTime, const TimeOfDay(hour: 20, minute: 15));
      final confirmed = Completer<AskHawMemory>();
      store.nextWrite = confirmed;
      await tester.ensureVisible(find.text('Try again'));
      await tester.tap(find.text('Try again'));
      await tester.pump();
      confirmed.complete(
        AskHawMemory(
          payload: {
            'preferences': {
              ...store.memory.preferences,
              'preferredHour': 9,
              'preferredMinute': 45,
            },
          },
        ),
      );
      await tester.pump();
      expect(view().usualStartTime, const TimeOfDay(hour: 9, minute: 45));
      final reset = Completer<AskHawMemory>();
      store.nextWrite = reset;
      await tester.ensureVisible(
        find.byKey(const ValueKey('ask-haw-usual-time-reset')),
      );
      await tester.tap(find.byKey(const ValueKey('ask-haw-usual-time-reset')));
      await tester.pump();
      expect(store.lastPatch, {
        'preferences': {'preferredHour': null, 'preferredMinute': null},
      });
      expect(view().usualStartTime, const TimeOfDay(hour: 9, minute: 45));
      reset.complete(
        AskHawMemory(
          payload: {
            'preferences': {...store.memory.preferences}
              ..remove('preferredHour')
              ..remove('preferredMinute'),
          },
        ),
      );
      await tester.pump();
      expect(view().usualStartTime, isNull);
      expect(find.text('Usual start time'), findsNothing);
      expect(store.memory.preferences['preferredTimeOfDay'], 'evening');
      expect(store.memory.preferences['interests'], ['reading']);
    },
  );

  testWidgets(
    'choosing a time category clears the exact override in one write',
    (tester) async {
      store.memory = AskHawMemory(
        payload: {
          'preferences': {
            'preferredHour': 20,
            'preferredMinute': 15,
            'preferredTimeOfDay': 'evening',
            'interests': ['reading'],
          },
        },
      );
      await show(tester);
      await open(tester);
      final write = Completer<AskHawMemory>();
      store.nextWrite = write;
      await tester.ensureVisible(
        find.byKey(const ValueKey('ask-haw-time-evening-false')),
      );
      await tester.tap(
        find.byKey(const ValueKey('ask-haw-time-evening-false')),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Morning').last);
      await tester.pump();
      expect(store.lastPatch, {
        'preferences': {
          'preferredTimeOfDay': 'morning',
          'preferredHour': null,
          'preferredMinute': null,
        },
      });
      expect(
        tester
            .widget<AskHawSettingsView>(find.byType(AskHawSettingsView))
            .usualStartTime,
        const TimeOfDay(hour: 20, minute: 15),
      );
      write.complete(
        AskHawMemory(
          payload: {
            'preferences': {
              'preferredTimeOfDay': 'morning',
              'interests': ['reading'],
            },
          },
        ),
      );
      await tester.pump();
      expect(find.text('Usual start time'), findsNothing);
      expect(store.memory.preferences['interests'], ['reading']);
    },
  );

  testWidgets('an open time picker cannot save after A to B to A', (
    tester,
  ) async {
    store.memory = AskHawMemory(
      payload: {
        'preferences': {'preferredHour': 20, 'preferredMinute': 15},
      },
    );
    await show(tester);
    await open(tester);
    await tester.ensureVisible(
      find.byKey(const ValueKey('ask-haw-usual-time-change')),
    );
    await tester.tap(find.byKey(const ValueKey('ask-haw-usual-time-change')));
    await tester.pump(const Duration(milliseconds: 300));
    await client.auth.recoverSession(_session('account-b'));
    await tester.pump();
    await client.auth.recoverSession(_session('account-a'));
    await tester.pump();
    Navigator.of(
      tester.element(find.byType(TimePickerDialog)),
    ).pop(const TimeOfDay(hour: 9, minute: 45));
    await tester.pump(const Duration(milliseconds: 300));
    expect(store.lastPatch, isNull);
    expect(find.byKey(const ValueKey('ask-haw-memory-open')), findsOneWidget);
    expect(find.text('Usual start time'), findsNothing);
  });

  testWidgets('forget and restore rebase only selected items on fresh memory', (
    tester,
  ) async {
    store.memory = AskHawMemory(
      payload: {
        'bindings': {
          'reset': {'intent': 'find', 'query': 'rest'},
        },
        'hidden': ['maat:the-reading-house', 'library:decans'],
      },
    );
    await show(tester);
    await open(tester);
    // Another device added a phrase after the displayed read.
    store.memory = AskHawMemory(
      payload: {
        ...store.memory.payload,
        'bindings': {
          ...store.memory.bindings,
          'study': {'intent': 'find', 'query': 'reading'},
        },
      },
    );
    final removal = Completer<AskHawMemory>();
    store.nextWrite = removal;
    await tester.ensureVisible(
      find.byKey(const ValueKey('ask-haw-forget-reset')),
    );
    await tester.tap(find.byKey(const ValueKey('ask-haw-forget-reset')));
    await tester.pump();
    expect(store.lastPatch, {
      'bindings': {'reset': null},
    });
    expect(find.text('reset'), findsOneWidget);
    removal.complete(
      AskHawMemory(
        payload: {
          ...store.memory.payload,
          'bindings': {
            'study': {'intent': 'find', 'query': 'reading'},
          },
        },
      ),
    );
    await tester.pump();
    expect(store.memory.bindings.containsKey('reset'), isFalse);
    expect(store.memory.bindings.containsKey('study'), isTrue);
    await tester.ensureVisible(
      find.byKey(const ValueKey('ask-haw-restore-maat:the-reading-house')),
    );
    await tester.tap(
      find.byKey(const ValueKey('ask-haw-restore-maat:the-reading-house')),
    );
    await tester.pump();
    expect(store.memory.hiddenSuggestions, {'library:decans'});
  });

  testWidgets(
    'clear failure retains memory and retry waits for acknowledgement',
    (tester) async {
      store.memory = AskHawMemory(
        payload: {
          'bindings': {
            'reset': {'intent': 'find', 'query': 'rest'},
          },
        },
      );
      await show(tester);
      await open(tester);
      final clear = Completer<AskHawMemory>();
      store.nextClear = clear;
      await tester.ensureVisible(
        find.byKey(const ValueKey('ask-haw-memory-clear')),
      );
      await tester.tap(find.byKey(const ValueKey('ask-haw-memory-clear')));
      await tester.pump();
      expect(find.text('reset'), findsOneWidget);
      clear.completeError(StateError('offline'));
      await tester.pump();
      expect(find.text('Remembered details cleared.'), findsNothing);
      expect(find.text('reset'), findsOneWidget);
      await tester.ensureVisible(find.text('Try again'));
      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect(find.text('reset'), findsNothing);
      expect(find.text('Remembered details cleared.'), findsOneWidget);
    },
  );

  testWidgets('A to B to A rejects held memory and clears private controls', (
    tester,
  ) async {
    final read = Completer<AskHawMemory>();
    store.nextRead = read;
    await show(tester);
    await open(tester);
    await client.auth.recoverSession(_session('account-b'));
    await tester.pump();
    await client.auth.recoverSession(_session('account-a'));
    await tester.pump();
    read.complete(
      AskHawMemory(
        payload: {
          'bindings': {
            'private old phrase': {'intent': 'find'},
          },
        },
      ),
    );
    await tester.pump();
    expect(find.text('private old phrase'), findsNothing);
    expect(find.byKey(const ValueKey('ask-haw-memory-open')), findsOneWidget);
    expect(store.disposed, isTrue);
  });
}

class _Repository extends AskHawMemoryRepository {
  _Repository(super.client);
  AskHawMemory memory = AskHawMemory();
  Completer<AskHawMemory>? nextRead, nextWrite, nextClear;
  Map<String, dynamic>? lastPatch;
  int reads = 0;
  bool disposed = false;
  @override
  Future<AskHawMemory> read() async {
    reads++;
    final pending = nextRead;
    nextRead = null;
    return pending == null ? memory : pending.future;
  }

  @override
  Future<AskHawMemory> update(Map<String, dynamic> patch) async {
    lastPatch = patch;
    final pending = nextWrite;
    nextWrite = null;
    memory = pending == null
        ? AskHawMemory(payload: {...memory.payload, ...patch})
        : await pending.future;
    return memory;
  }

  @override
  Future<AskHawMemory> clear() async {
    final pending = nextClear;
    nextClear = null;
    memory = pending == null ? AskHawMemory() : await pending.future;
    return memory;
  }

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

String _session(String uid) {
  final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
  String enc(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return jsonEncode({
    'access_token':
        '${enc({'alg': 'HS256', 'typ': 'JWT'})}.${enc({'sub': uid, 'exp': exp})}.signature',
    'refresh_token': 'test',
    'token_type': 'bearer',
    'expires_at': exp,
    'expires_in': 3600,
    'user': {
      'id': uid,
      'aud': 'authenticated',
      'role': 'authenticated',
      'email': 'fixture@example.com',
      'app_metadata': {},
      'user_metadata': {},
      'created_at': '2026-01-01T00:00:00Z',
    },
  });
}
