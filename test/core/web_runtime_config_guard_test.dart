import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('web runtime config guard', () {
    late String mainSource;
    late String buildScriptSource;

    setUpAll(() async {
      mainSource = await File('lib/main.dart').readAsString();
      buildScriptSource = await File(
        'scripts/build_web_release.sh',
      ).readAsString();
    });

    test('web startup can read env.json without bypassing validation', () {
      expect(mainSource, contains("Uri.base.resolve('env.json')"));
      expect(mainSource, contains('http.get'));
      expect(mainSource, contains("webEnv['SUPABASE_URL']"));
      expect(mainSource, contains("webEnv['SUPABASE_ANON_KEY']"));
      expect(mainSource, contains("webEnv['APP_ENV']"));
      expect(mainSource, contains("webEnv['APP_SITE_URL']"));
      expect(mainSource, contains('_runtimeConfigErrors(supabaseConfig)'));
      expect(
        mainSource,
        contains('Production app configuration is incomplete'),
      );
    });

    test('web release can derive defaults from raw Supabase dart defines', () {
      expect(mainSource, contains('kIsWeb &&'));
      expect(mainSource, contains('kReleaseMode &&'));
      expect(
        mainSource,
        contains('_hasValidSupabaseRuntimeConfig(url, anonKey)'),
      );
      expect(mainSource, contains("appEnvironment = 'prod';"));
      expect(mainSource, contains('appSiteUrl = defaultProductionAppSiteUrl;'));
      expect(
        mainSource,
        contains("defaultProductionAppSiteUrl = 'https://maat.app'"),
      );
    });

    test('web env.json fallback runs before release default derivation', () {
      final webEnvIndex = mainSource.indexOf('_loadWebRuntimeEnvJson');
      final defaultIndex = mainSource.indexOf(
        '_hasValidSupabaseRuntimeConfig(url, anonKey)',
      );

      expect(webEnvIndex, greaterThanOrEqualTo(0));
      expect(defaultIndex, greaterThan(webEnvIndex));
    });

    test('release defaults still depend on strict Supabase validation', () {
      expect(mainSource, contains('_hasValidSupabaseUrl(url)'));
      expect(mainSource, contains('_hasValidSupabaseAnonKey(anonKey)'));
      expect(mainSource, contains("parsed.host.endsWith('.supabase.co')"));
      expect(mainSource, contains("!lower.contains('service_role')"));
      expect(mainSource, contains("!lower.contains('service-role')"));
      expect(
        mainSource,
        contains('SUPABASE_ANON_KEY still looks like a placeholder.'),
      );
    });

    test('web release build still emits env.json and dart defines', () {
      expect(buildScriptSource, contains('--dart-define-from-file'));
      expect(
        buildScriptSource,
        contains(r'cp "$BUILD_ENV_FILE" build/web/env.json'),
      );
      expect(buildScriptSource, contains('"SUPABASE_URL"'));
      expect(buildScriptSource, contains('"SUPABASE_ANON_KEY"'));
      expect(buildScriptSource, contains('"APP_ENV"'));
      expect(buildScriptSource, contains('"APP_SITE_URL"'));
    });

    test('web release build stamps deploy marker output', () {
      expect(buildScriptSource, contains('build/web/version.json'));
      expect(buildScriptSource, contains('version_payload["build_version"]'));
      expect(buildScriptSource, contains('version_payload["build_timestamp"]'));
      expect(buildScriptSource, contains('version_payload["app_env"]'));
      expect(
        buildScriptSource,
        contains('build/web/version.json is missing build_version.'),
      );
      expect(
        buildScriptSource,
        contains('build/web/env.json APP_ENV must be staging or prod.'),
      );
    });
  });
}
