import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/external_calendar_repository.dart';
import 'package:mobile/services/external_calendar_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Harness {
  _Harness() {
    repository = ExternalCalendarRepository(
      client,
      lane: 'staging',
      currentAccount: () => owner,
      request: (body) async {
        sent.add(Map.of(body));
        return transport(body);
      },
    );
    controller = ExternalCalendarController(repository, now: () => now);
  }

  final client = SupabaseClient(
    'https://example.supabase.co',
    'fixture-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  late final ExternalCalendarRepository repository;
  late final ExternalCalendarController controller;
  final sent = <Map<String, dynamic>>[];
  String? owner = 'owner-a';
  DateTime now = DateTime.utc(2026, 10, 2, 12);
  late ExternalCalendarRequest transport;

  Map<String, dynamic> status({
    bool automatic = true,
    bool syncing = false,
    bool stale = false,
    bool selected = true,
    String state = 'connected',
    String? error,
    DateTime? retryAt,
    int revision = 4,
  }) => {
    'available': true,
    'syncing': syncing,
    'retry_at': retryAt?.toIso8601String(),
    'connection': {
      'id': 'connection-a',
      'provider': 'google',
      'status': state,
      'automatic': automatic,
      'account_label': 'fixture@example.test',
      'revision': revision,
      'last_synced_at': stale ? null : now.toIso8601String(),
      'error_code': error,
    },
    'sources': [
      {'id': 'source-a', 'label': 'Work', 'selected': selected},
    ],
  };

  List<Map<String, dynamic>> get refreshes =>
      sent.where((body) => body['action'] == 'refresh').toList();

  Future<void> advance(WidgetTester tester, Duration duration) async {
    now = now.add(duration);
    await tester.pump(duration);
    await tester.pump();
  }

  Future<void> dispose() async {
    controller.dispose();
    await client.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Harness h;
  setUp(() => h = _Harness());
  tearDown(() => h.dispose());

  testWidgets(
    'offline startup recovers on timer; server backoff survives resume',
    (tester) async {
      var statuses = 0;
      final retryAt = h.now.add(const Duration(minutes: 3));
      h.transport = (body) async {
        if (body['action'] == 'refresh') return h.status();
        if (++statuses == 1) throw StateError('offline');
        return h.status(stale: true, error: 'rate_limited', retryAt: retryAt);
      };

      h.controller.start();
      await tester.pump();
      expect(h.controller.error?.code, 'unavailable');
      expect(h.controller.busy, isFalse);
      await h.advance(tester, const Duration(minutes: 1));
      expect(statuses, 2);
      expect(h.controller.error?.code, 'rate_limited');
      expect(h.controller.status?.retryAt, retryAt);
      expect(h.refreshes, isEmpty);

      h.controller.didChangeAppLifecycleState(AppLifecycleState.paused);
      await h.advance(tester, const Duration(minutes: 1));
      expect(statuses, 2);
      h.controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      expect(statuses, 3);
      expect(h.controller.error?.code, 'rate_limited');
      expect(h.refreshes, isEmpty);

      await h.advance(tester, const Duration(minutes: 1));
      expect(h.refreshes, hasLength(1));
      expect(h.controller.error, isNull);
      expect(h.controller.busy, isFalse);
      h.controller.stop();
    },
  );

  testWidgets(
    'a server lease prevents duplicate foreground import until released',
    (tester) async {
      var syncing = true;
      h.transport = (body) async => body['action'] == 'refresh'
          ? h.status()
          : h.status(stale: true, syncing: syncing);
      h.controller.start();
      await tester.pump();
      expect(h.controller.status?.syncing, isTrue);
      expect(h.refreshes, isEmpty);
      await h.advance(tester, const Duration(minutes: 1));
      expect(h.refreshes, isEmpty);
      syncing = false;
      await h.advance(tester, const Duration(minutes: 1));
      expect(h.refreshes, hasLength(1));
      expect(h.controller.status?.syncing, isFalse);
      h.controller.stop();
    },
  );

  testWidgets(
    'failed visible range retries after one minute, success after fifteen',
    (tester) async {
      var rangeAttempts = 0;
      final from = DateTime.utc(2027, 7, 1);
      final until = DateTime.utc(2027, 8, 1);
      h.transport = (body) async {
        if (body['action'] == 'refresh' && ++rangeAttempts == 1) {
          throw const ExternalCalendarFailure(code: 'offline', retryable: true);
        }
        return h.status();
      };
      h.controller.start();
      await tester.pump();
      h.controller.ensureRange(from, until);
      await h.advance(tester, const Duration(milliseconds: 500));
      expect(rangeAttempts, 1);
      expect(h.controller.error?.code, 'offline');
      await h.advance(tester, const Duration(seconds: 59));
      expect(rangeAttempts, 1);
      await h.advance(tester, const Duration(seconds: 1));
      expect(rangeAttempts, 2);
      expect(h.controller.error, isNull);
      expect(h.refreshes.last['start'], from.toIso8601String());
      expect(h.refreshes.last['end'], until.toIso8601String());

      await h.advance(tester, const Duration(minutes: 14, seconds: 59));
      expect(rangeAttempts, 2);
      await h.advance(tester, const Duration(seconds: 1));
      // A resume probes the now-expired range independently of the ordinary
      // one-minute status polling cadence after the large fake-clock jump.
      h.controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      expect(rangeAttempts, 3);
      h.controller.stop();
    },
  );

  testWidgets(
    'range queued while another import is busy drains on recovery tick',
    (tester) async {
      final pending = Completer<Map<String, dynamic>>();
      var imports = 0;
      h.transport = (body) {
        if (body['action'] == 'refresh' && ++imports == 1) {
          return pending.future;
        }
        return Future.value(h.status());
      };
      h.controller.start();
      await tester.pump();
      final manual = h.controller.refresh();
      await tester.pump();
      expect(h.controller.busy, isTrue);
      final from = DateTime.utc(2027, 7, 1);
      final until = DateTime.utc(2027, 8, 1);
      h.controller.ensureRange(from, until);
      await h.advance(tester, const Duration(milliseconds: 500));
      expect(h.refreshes, hasLength(1));
      pending.complete(h.status());
      await manual;
      await tester.pump();
      expect(h.controller.busy, isFalse);
      await h.advance(tester, const Duration(minutes: 1));
      expect(h.refreshes, hasLength(2));
      expect(h.refreshes.last['start'], from.toIso8601String());
      expect(h.refreshes.last['end'], until.toIso8601String());
      h.controller.stop();
    },
  );

  testWidgets(
    'chooser retains its acknowledged revision and draft across timer and resume',
    (tester) async {
      var serverRevision = 4;
      h.transport = (body) async {
        if (body['action'] == 'select_sources') {
          throw const ExternalCalendarFailure(
            code: 'stale_attempt',
            retryable: true,
          );
        }
        return h.status(revision: serverRevision, selected: false);
      };
      h.controller.start();
      await tester.pump();
      await h.controller.chooseCalendars();
      h.controller.setSourceSelected('source-a', true);
      final before = h.sent.length;
      serverRevision = 5;
      await h.advance(tester, const Duration(minutes: 2));
      await h.controller.loadStatus();
      h.controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      expect(h.sent, hasLength(before));
      expect(h.controller.status?.revision, 4);
      expect(h.controller.selectedSourceIds, {'source-a'});

      await h.controller.saveSelection();
      expect(h.sent.last['action'], 'select_sources');
      expect(h.sent.last['expected_revision'], 4);
      expect(h.controller.error?.code, 'stale_attempt');
      expect(h.controller.choosingCalendars, isTrue);
      expect(h.controller.selectedSourceIds, {'source-a'});
      expect(h.refreshes, isEmpty);
      h.controller.cancelSelection();
      await h.controller.loadStatus();
      expect(h.controller.status?.revision, 5);
      expect(h.controller.selectedSourceIds, isEmpty);
      h.controller.stop();
    },
  );

  testWidgets(
    'revoked grant is visible and blocks timer, resume, and range imports',
    (tester) async {
      h.transport = (_) async => h.status(
        stale: true,
        state: 'reconnect_required',
        error: 'reconnect_required',
      );
      h.controller.start();
      await tester.pump();
      expect(h.controller.error?.code, 'reconnect_required');
      expect(h.controller.error?.retryable, isFalse);
      h.controller.ensureRange(DateTime.utc(2027, 7), DateTime.utc(2027, 8));
      await h.advance(tester, const Duration(minutes: 1));
      h.controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      expect(h.refreshes, isEmpty);
      expect(h.controller.status?.requiresReconnect, isTrue);
      h.controller.stop();
    },
  );
}
