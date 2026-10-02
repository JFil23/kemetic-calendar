import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/web_runtime_environment.dart';

const _validUrl = 'https://abc123.supabase.co';
const _validKey = 'sb_publishable_runtime_test_key_1234567890';
const _validSite = 'https://kemet-rc.pages.dev';
final _runtimeUri = Uri.parse('https://kemet-rc.pages.dev/env.json');

void main() {
  group('web runtime environment fallback eligibility', () {
    bool needs({
      String url = _validUrl,
      String anonKey = _validKey,
      String environment = 'staging',
      String site = _validSite,
    }) => needsWebRuntimeEnvironment(
      url: url,
      anonKey: anonKey,
      appEnvironment: environment,
      appSiteUrl: site,
    );

    test('complete named release configuration skips runtime fetch', () {
      expect(needs(), isFalse);
      expect(
        needs(environment: 'prod', site: 'https://kemet.pages.dev'),
        isFalse,
      );
      expect(needs(environment: ' STAGING ', site: ' $_validSite '), isFalse);
    });

    test('missing or unsafe public Supabase configuration needs fallback', () {
      for (final url in [
        '',
        'https://YOUR_PROJECT.supabase.co',
        'http://abc123.supabase.co',
      ]) {
        expect(needs(url: url), isTrue, reason: url);
      }
      for (final key in [
        '',
        'short',
        'YOUR_SUPABASE_ANON_KEY',
        'service_role_key_not_allowed_123456',
      ]) {
        expect(needs(anonKey: key), isTrue, reason: key);
      }
    });

    test('unnamed environment and legacy site need runtime fallback', () {
      for (final environment in ['', 'dev', 'production', 'placeholder']) {
        expect(needs(environment: environment), isTrue, reason: environment);
      }
      for (final site in [
        '',
        'https://maat.app',
        'http://kemet.pages.dev',
        'https://',
        'https://your-project.pages.dev',
      ]) {
        expect(needs(site: site), isTrue, reason: site);
      }
    });
  });

  group('bounded runtime environment request', () {
    test(
      'public values are trimmed and non-string or empty values dropped',
      () async {
        final client = _TrackingClient((request) async {
          expect(request.method, 'GET');
          expect(request.url, _runtimeUri);
          return http.Response(
            '{"SUPABASE_URL":"  $_validUrl  ",'
            '"SUPABASE_ANON_KEY":" $_validKey ",'
            '"APP_ENV":" staging ","APP_SITE_URL":" $_validSite ",'
            '"empty":"  ","number":1,"flag":true,"nil":null,"map":{}}',
            200,
          );
        });
        expect(await loadWebRuntimeEnvironment(_runtimeUri, client: client), {
          'SUPABASE_URL': _validUrl,
          'SUPABASE_ANON_KEY': _validKey,
          'APP_ENV': 'staging',
          'APP_SITE_URL': _validSite,
        });
        expect(client.closeCount, 1);
      },
    );

    for (final status in [404, 500]) {
      test('HTTP $status preserves empty fallback and closes client', () async {
        final client = _TrackingClient(
          (_) async => http.Response('{"APP_ENV":"prod"}', status),
        );
        expect(
          await loadWebRuntimeEnvironment(_runtimeUri, client: client),
          isEmpty,
        );
        expect(client.closeCount, 1);
      });
    }

    for (final body in ['', '{', '[]', 'null', '42', '"config"']) {
      test('invalid or non-object JSON $body is a safe miss', () async {
        final client = _TrackingClient((_) async => http.Response(body, 200));
        expect(
          await loadWebRuntimeEnvironment(_runtimeUri, client: client),
          isEmpty,
        );
        expect(client.closeCount, 1);
      });
    }

    test('network failure returns empty fallback and closes client', () async {
      final client = _TrackingClient(
        (_) async => throw http.ClientException('offline'),
      );
      expect(
        await loadWebRuntimeEnvironment(_runtimeUri, client: client),
        isEmpty,
      );
      expect(client.closeCount, 1);
    });

    for (final lateFailure in [false, true]) {
      test(
        'default deadline closes request and ignores late ${lateFailure ? 'error' : 'success'}',
        () {
          fakeAsync((clock) {
            final pending = Completer<http.Response>();
            final client = _TrackingClient((_) => pending.future);
            Map<String, String>? result;
            var completions = 0;
            loadWebRuntimeEnvironment(_runtimeUri, client: client).then((
              value,
            ) {
              result = value;
              completions += 1;
            });
            clock.flushMicrotasks();
            clock.elapse(const Duration(milliseconds: 3999));
            expect(result, isNull);
            expect(client.closeCount, 0);
            clock.elapse(const Duration(milliseconds: 1));
            clock.flushMicrotasks();
            expect(result, isEmpty);
            expect(completions, 1);
            expect(client.closeCount, 1);

            if (lateFailure) {
              pending.completeError(http.ClientException('late failure'));
            } else {
              pending.complete(http.Response('{"APP_ENV":"prod"}', 200));
            }
            clock.flushMicrotasks();
            expect(result, isEmpty);
            expect(completions, 1);
            expect(client.closeCount, 1);
          });
        },
      );
    }
  });
}

class _TrackingClient extends MockClient {
  _TrackingClient(super.handler);

  int closeCount = 0;

  @override
  void close() {
    closeCount += 1;
    super.close();
  }
}
