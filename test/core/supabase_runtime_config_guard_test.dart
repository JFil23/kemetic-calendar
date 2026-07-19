import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/supabase_runtime_config_guard.dart';

void main() {
  group('Supabase runtime config guard', () {
    const anonKey = 'sb_publishable_local_guard_test_key_1234567890';

    SupabaseRuntimeConfig configWithUrl(String url, {String env = 'dev'}) {
      return SupabaseRuntimeConfig(
        url: url,
        anonKey: anonKey,
        appEnvironment: env,
        appSiteUrl: 'https://maat.app',
        nativeAuthRedirectUrl: 'kemet.app://login-callback',
      );
    }

    List<String> errorsFor(
      String url, {
      bool allowLocalSupabase = false,
      bool debugMode = true,
      bool releaseMode = false,
      bool profileMode = false,
      String env = 'dev',
    }) {
      return supabaseRuntimeConfigErrors(
        configWithUrl(url, env: env),
        allowLocalSupabase: allowLocalSupabase,
        debugMode: debugMode,
        releaseMode: releaseMode,
        profileMode: profileMode,
      );
    }

    test('https Supabase project URLs pass', () {
      expect(errorsFor('https://abc123.supabase.co'), isEmpty);
    });

    test('local emulator URL fails by default', () {
      expect(
        errorsFor('http://10.0.2.2:54321'),
        contains('SUPABASE_URL must be a real https://*.supabase.co URL.'),
      );
    });

    test('local emulator URL passes with explicit debug override', () {
      expect(
        errorsFor(
          'http://10.0.2.2:54321',
          allowLocalSupabase: true,
          debugMode: true,
        ),
        isEmpty,
      );
    });

    test('local override cannot pass in release mode', () {
      expect(
        errorsFor(
          'http://10.0.2.2:54321',
          allowLocalSupabase: true,
          debugMode: false,
          releaseMode: true,
          env: 'prod',
        ),
        contains('ALLOW_LOCAL_SUPABASE is only available in debug builds.'),
      );
    });

    test('local override cannot pass outside debug mode', () {
      expect(
        errorsFor(
          'http://127.0.0.1:54321',
          allowLocalSupabase: true,
          debugMode: false,
          env: 'prod',
        ),
        contains('ALLOW_LOCAL_SUPABASE is only available in debug builds.'),
      );
    });

    test('random http URLs still fail even with local override', () {
      expect(
        errorsFor('http://example.com:54321', allowLocalSupabase: true),
        contains('SUPABASE_URL must be a real https://*.supabase.co URL.'),
      );
    });

    test('local override only allows known local Supabase hosts and port', () {
      expect(
        errorsFor('http://localhost:54321', allowLocalSupabase: true),
        isEmpty,
      );
      expect(
        errorsFor('http://127.0.0.1:54321', allowLocalSupabase: true),
        isEmpty,
      );
      expect(
        errorsFor('http://localhost:54322', allowLocalSupabase: true),
        contains('SUPABASE_URL must be a real https://*.supabase.co URL.'),
      );
    });
  });
}
