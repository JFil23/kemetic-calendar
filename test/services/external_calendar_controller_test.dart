import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/data/external_calendar_repository.dart';
import 'package:mobile/services/external_calendar_controller.dart';
import 'package:mobile/features/calendar/calendar_invalidation.dart';

Map<String, dynamic> snapshot({
  bool automatic = false,
  String state = 'paused',
  int revision = 1,
}) => {
  'available': true,
  'connection': {
    'id': 'connection',
    'status': state,
    'automatic': automatic,
    'account_label': 'calendar@example.test',
    'revision': revision,
  },
  'sources': [
    {'id': 'source', 'label': 'Work', 'selected': false},
  ],
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SupabaseClient client;
  late String? owner;
  late ExternalCalendarController controller;
  var now = DateTime.utc(2026, 10, 2);
  setUp(() {
    client = SupabaseClient(
      'https://example.supabase.co',
      'key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    owner = 'a';
  });
  tearDown(() async {
    controller.dispose();
    await client.dispose();
  });
  ExternalCalendarController make(ExternalCalendarRequest request) =>
      ExternalCalendarController(
        ExternalCalendarRepository(
          client,
          lane: 'staging',
          currentAccount: () => owner,
          request: request,
          requestTimeout: const Duration(milliseconds: 50),
          refreshTimeout: const Duration(milliseconds: 60),
        ),
        retryInterval: const Duration(milliseconds: 100),
        now: () => now,
      );

  test(
    'observing a newer server completion invalidates copies without issuing a provider refresh',
    () async {
      final actions = <String>[];
      var syncedAt = '2026-10-02T10:00:00Z';
      controller = make((body) async {
        actions.add(body['action'] as String);
        final value = snapshot(automatic: true, state: 'connected');
        (value['connection'] as Map)['last_synced_at'] = syncedAt;
        return value;
      });
      await controller.loadStatus();
      final events = <CalendarInvalidated>[];
      final subscription = CalendarInvalidationBus.instance.stream.listen(
        events.add,
      );
      addTearDown(subscription.cancel);
      await controller.loadStatus();
      await Future<void>.delayed(Duration.zero);
      expect(events, isEmpty);
      syncedAt = '2026-10-02T10:15:00Z';
      await controller.loadStatus();
      await Future<void>.delayed(Duration.zero);
      expect(events, hasLength(1));
      expect(events.single.externalCalendar?.accountId, 'a');
      expect(events.single.externalCalendar?.lane, 'staging');
      expect(actions, ['status', 'status', 'status']);
    },
  );

  testWidgets('first status failure retains resume and timer recovery', (
    tester,
  ) async {
    var calls = 0;
    controller = make((_) async {
      calls++;
      if (calls == 1) throw StateError('offline');
      return snapshot();
    });
    controller.start();
    await tester.pump();
    expect(controller.error?.code, 'unavailable');
    expect(controller.busy, false);
    now = now.add(const Duration(milliseconds: 110));
    await tester.pump(const Duration(milliseconds: 110));
    expect(calls, 2);
    expect(controller.status?.connected, true);
    controller.didChangeAppLifecycleState(AppLifecycleState.paused);
    await tester.pump(const Duration(milliseconds: 200));
    expect(calls, 2);
    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(calls, 3);
    controller.stop();
  });
  testWidgets(
    'restart catches a resume missed while its observer was stopped',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      addTearDown(() {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      });
      var calls = 0;
      controller = make((_) async => snapshot(revision: ++calls));
      controller.start();
      await tester.pump();
      expect(calls, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      controller.stop();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(
        calls,
        1,
        reason: 'The stopped controller has no resume observer.',
      );
      expect(controller.status, isNull);

      controller.start();
      await tester.pump();
      expect(calls, 2);
      expect(controller.status?.revision, 2);
      expect(controller.busy, isFalse);
      controller.stop();
    },
  );

  testWidgets('restart remains idle while the app is actually paused', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    addTearDown(() {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
    var calls = 0;
    controller = make((_) async => snapshot(revision: ++calls));
    controller.start();
    await tester.pump();
    expect(calls, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    controller.stop();
    controller.start();
    await tester.pump(const Duration(milliseconds: 250));
    expect(calls, 1, reason: 'Restart must not turn background work back on.');
    expect(controller.status, isNull);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(calls, 2);
    expect(controller.status?.revision, 2);
    controller.stop();
  });

  testWidgets(
    'a never-ending request times out and allows a successful retry',
    (tester) async {
      var calls = 0;
      final pending = Completer<Map<String, dynamic>>();
      controller = make(
        (_) =>
            ++calls == 1 ? pending.future : Future.value(snapshot(revision: 2)),
      );
      final first = controller.loadStatus();
      await tester.pump(const Duration(milliseconds: 60));
      await first;
      expect(controller.busy, false);
      expect(controller.error?.code, 'timeout');
      await controller.loadStatus();
      expect(controller.status?.revision, 2);
      pending.complete(snapshot(revision: 1));
      await tester.pump();
      expect(controller.status?.revision, 2);
    },
  );
  test(
    'account switch rejects old completion and frees the new account',
    () async {
      final pending = Completer<Map<String, dynamic>>();
      var calls = 0;
      controller = make(
        (_) =>
            ++calls == 1 ? pending.future : Future.value(snapshot(revision: 2)),
      );
      final old = controller.loadStatus();
      owner = 'b';
      await controller.loadStatus();
      pending.complete(snapshot(revision: 1));
      await old;
      expect(controller.status?.revision, 2);
      expect(controller.busy, false);
    },
  );
  test('pause and resume are acknowledged revision-fenced commands', () async {
    final sent = <Map<String, dynamic>>[];
    controller = make((body) async {
      sent.add(body);
      if (body['action'] == 'pause') return snapshot(revision: 2);
      if (body['action'] == 'resume') {
        throw const ExternalCalendarFailure(code: 'offline', retryable: true);
      }
      return snapshot(automatic: true);
    });
    await controller.loadStatus();
    await controller.setAutomatic(false);
    expect(controller.status?.automatic, false);
    expect(sent.last['expected_revision'], 1);
    await controller.setAutomatic(true);
    expect(sent.last['expected_revision'], 2);
    expect(controller.status?.automatic, false);
    expect(sent.map((b) => b['action']), ['status', 'pause', 'resume']);
  });
  test(
    'calendar draft does not write until Save and sends only chosen sources',
    () async {
      final sent = <Map<String, dynamic>>[];
      controller = make((body) async {
        sent.add(body);
        return snapshot(revision: sent.length);
      });
      await controller.chooseCalendars();
      expect(controller.selectedSourceIds, isEmpty);
      controller.setSourceSelected('source', true);
      controller.setSourceSelected('unknown', true);
      expect(sent, hasLength(1));
      await controller.saveSelection();
      expect(sent.map((b) => b['action']), [
        'sources',
        'select_sources',
        'refresh',
      ]);
      expect(sent[1]['source_ids'], ['source']);
      expect(sent[1]['expected_revision'], 1);
      expect(controller.choosingCalendars, false);
    },
  );
  test(
    'stop fences a pending result and clears account presentation',
    () async {
      final pending = Completer<Map<String, dynamic>>();
      controller = make((_) => pending.future);
      final task = controller.loadStatus();
      controller.stop();
      pending.complete(snapshot());
      await task;
      expect(controller.status, null);
      expect(controller.busy, false);
    },
  );
  test(
    'connect accepts only Google HTTPS authorization URLs without changing app auth',
    () async {
      var url = 'https://attacker.test/authorize';
      controller = make((_) async => {'authorization_url': url});
      expect(await controller.connect(), null);
      expect(controller.error?.code, 'invalid_authorization_url');
      url = 'https://accounts.google.com/o/oauth2/v2/auth?state=opaque';
      expect((await controller.connect())?.host, 'accounts.google.com');
      expect(client.auth.currentSession, null);
      expect(owner, 'a');
    },
  );
}
