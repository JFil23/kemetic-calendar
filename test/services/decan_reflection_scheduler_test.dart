import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/services/decan_reflection_scheduler.dart';
import '../features/pages/pages_resource_test.dart' show session, uid;

void main() {
  late SupabaseClient client;
  late DecanReflectionScheduler scheduler;
  late List<Completer<http.Response>> requests;
  late int refreshed;
  late StreamController<int> arrivals;
  setUp(() async {
    requests = [];
    arrivals = StreamController<int>.broadcast();
    refreshed = 0;
    client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) {
        final result = Completer<http.Response>();
        requests.add(result);
        arrivals.add(requests.length);
        return result.future;
      }),
    );
    await client.auth.recoverSession(session());
    scheduler = DecanReflectionScheduler(
      client,
      onMaatGuidanceEnsured: () => refreshed++,
    );
  });
  tearDown(() async {
    await client.dispose();
    await arrivals.close();
  });
  Future<void> dispatched([int count = 1]) async {
    if (requests.length < count) {
      await arrivals.stream
          .firstWhere((value) => value >= count)
          .timeout(const Duration(seconds: 5));
    }
  }

  void reply(int index, [int status = 200]) => requests[index].complete(
    http.Response('{}', status, headers: {'content-type': 'application/json'}),
  );

  test(
    'successful ensure can be forced again and otherwise remains throttled',
    () async {
      final first = scheduler.ensureCurrentAndNextScheduled();
      await dispatched();
      reply(0);
      await first;
      await scheduler.ensureCurrentAndNextScheduled();
      expect(requests, hasLength(1));
      final next = scheduler.ensureCurrentAndNextScheduled(force: true);
      await dispatched(2);
      expect(requests, hasLength(2));
      reply(1);
      await next;
      expect(refreshed, 2);
    },
  );
  test('failed ensure retries without force', () async {
    final first = scheduler.ensureCurrentAndNextScheduled();
    await dispatched();
    reply(0, 503);
    await first;
    final next = scheduler.ensureCurrentAndNextScheduled();
    await dispatched(2);
    expect(requests, hasLength(2));
    reply(1);
    await next;
    expect(refreshed, 1);
  });
  test('overlapping forced requests share the in-flight operation', () async {
    final first = scheduler.ensureCurrentAndNextScheduled(force: true);
    final second = scheduler.ensureCurrentAndNextScheduled(force: true);
    expect(identical(first, second), isTrue);
    await dispatched();
    expect(requests, hasLength(1));
    reply(0);
    await Future.wait([first, second]);
    expect(refreshed, 1);
  });
  test(
    'account switch neither inherits throttle nor accepts old completion',
    () async {
      final old = scheduler.ensureCurrentAndNextScheduled();
      await dispatched();
      await client.auth.recoverSession(
        session().replaceAll(uid, '27d63169-a28a-4550-a0a0-8fee0e8e7b96'),
      );
      final next = scheduler.ensureCurrentAndNextScheduled();
      await dispatched(2);
      expect(requests, hasLength(2));
      reply(0);
      await old;
      expect(refreshed, 0);
      final duplicate = scheduler.ensureCurrentAndNextScheduled(force: true);
      expect(identical(next, duplicate), isTrue);
      reply(1);
      await next;
      expect(refreshed, 1);
    },
  );
  test('signed-out scheduler sends no request', () async {
    final anonymous = SupabaseClient(
      'https://example.supabase.co',
      'test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((_) async {
        fail('No signed-out network request');
      }),
    );
    await DecanReflectionScheduler(
      anonymous,
    ).ensureCurrentAndNextScheduled(force: true);
    await anonymous.dispose();
  });
}
