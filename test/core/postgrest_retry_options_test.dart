import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart';

void main() {
  test('PostgrestClientOptions.retryEnabled is visible on client.rest', () {
    final client = SupabaseClient(
      'http://127.0.0.1:9',
      'anon-key',
      httpClient: _Count503Client(),
      postgrestOptions: const PostgrestClientOptions(retryEnabled: false),
    );
    addTearDown(client.dispose);
    expect(client.rest.retryEnabled, isFalse);
  });

  test('rest.from honors retryEnabled: false on GET 503', () {
    fakeAsync((async) {
      final httpClient = _Count503Client();
      final client = SupabaseClient(
        'http://127.0.0.1:9',
        'anon-key',
        httpClient: httpClient,
        postgrestOptions: const PostgrestClientOptions(retryEnabled: false),
      );

      Object? error;
      client.rest.from('t').select().then((_) {}, onError: (Object e, _) {
        error = e;
      });
      async.flushMicrotasks();
      expect(httpClient.calls, 1);

      async.elapse(const Duration(seconds: 8));
      async.flushMicrotasks();
      expect(httpClient.calls, 1);
      expect(error, isA<PostgrestException>());
      client.dispose();
    });
  });

  test('from() ignores retryEnabled: false and still retries GET 503', () {
    fakeAsync((async) {
      final httpClient = _Count503Client();
      final client = SupabaseClient(
        'http://127.0.0.1:9',
        'anon-key',
        httpClient: httpClient,
        postgrestOptions: const PostgrestClientOptions(retryEnabled: false),
      );

      Object? error;
      client.from('t').select().then((_) {}, onError: (Object e, _) {
        error = e;
      });
      async.flushMicrotasks();
      expect(httpClient.calls, 1);

      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      expect(httpClient.calls, 2);

      async.elapse(const Duration(seconds: 2));
      async.flushMicrotasks();
      expect(httpClient.calls, 3);

      async.elapse(const Duration(seconds: 4));
      async.flushMicrotasks();
      expect(httpClient.calls, 4);
      expect(error, isA<PostgrestException>());
      client.dispose();
    });
  });

  test('from().retry(enabled: false) disables GET 503 retries', () {
    fakeAsync((async) {
      final httpClient = _Count503Client();
      final client = SupabaseClient(
        'http://127.0.0.1:9',
        'anon-key',
        httpClient: httpClient,
        postgrestOptions: const PostgrestClientOptions(retryEnabled: true),
      );

      Object? error;
      client.from('t').select().retry(enabled: false).then((_) {},
          onError: (Object e, _) {
        error = e;
      });
      async.flushMicrotasks();
      expect(httpClient.calls, 1);

      async.elapse(const Duration(seconds: 8));
      async.flushMicrotasks();
      expect(httpClient.calls, 1);
      expect(error, isA<PostgrestException>());
      client.dispose();
    });
  });
}

final class _Count503Client extends http.BaseClient {
  int calls = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    calls += 1;
    return http.StreamedResponse(
      Stream<List<int>>.empty(),
      503,
      request: request,
      headers: const <String, String>{'content-type': 'application/json'},
    );
  }
}
