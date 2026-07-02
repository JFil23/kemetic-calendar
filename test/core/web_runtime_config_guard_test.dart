import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('web runtime config guard', () {
    late String mainSource;
    late String runtimeGuardSource;
    late String webIndexSource;
    late String buildScriptSource;
    late String deployScriptSource;

    setUpAll(() async {
      mainSource = await File('lib/main.dart').readAsString();
      runtimeGuardSource = await File(
        'lib/core/supabase_runtime_config_guard.dart',
      ).readAsString();
      webIndexSource = await File('web/index.html').readAsString();
      buildScriptSource = await File(
        'scripts/build_web_release.sh',
      ).readAsString();
      deployScriptSource = await File(
        'scripts/deploy_cloudflare_pages.sh',
      ).readAsString();
    });

    test('web startup can read env.json without bypassing validation', () {
      expect(mainSource, contains("Uri.base.resolve('/env.json')"));
      expect(mainSource, isNot(contains("Uri.base.resolve('env.json')")));
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
      final combinedSource = '$mainSource\n$runtimeGuardSource';
      expect(
        runtimeGuardSource,
        contains('bool hasValidSupabaseUrl(String url)'),
      );
      expect(
        runtimeGuardSource,
        contains('bool hasValidSupabaseAnonKey(String anonKey)'),
      );
      expect(combinedSource, contains("parsed.host.endsWith('.supabase.co')"));
      expect(combinedSource, contains("!lower.contains('service_role')"));
      expect(combinedSource, contains("!lower.contains('service-role')"));
      expect(
        combinedSource,
        contains('SUPABASE_ANON_KEY still looks like a placeholder.'),
      );
    });

    test('local Supabase override remains explicit and debug only', () {
      expect(
        mainSource,
        contains("bool.fromEnvironment('ALLOW_LOCAL_SUPABASE')"),
      );
      expect(runtimeGuardSource, contains('allowLocalSupabase'));
      expect(runtimeGuardSource, contains('debugMode'));
      expect(runtimeGuardSource, contains('releaseMode'));
      expect(
        runtimeGuardSource,
        contains('ALLOW_LOCAL_SUPABASE is only available in debug builds.'),
      );
      expect(runtimeGuardSource, contains("'10.0.2.2'"));
      expect(runtimeGuardSource, contains("'127.0.0.1'"));
      expect(runtimeGuardSource, contains("'localhost'"));
      expect(runtimeGuardSource, contains('localSupabasePort = 54321'));
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

    test('Cloudflare Pages deploy refuses dirty source trees by default', () {
      expect(deployScriptSource, contains('git status --porcelain'));
      expect(deployScriptSource, contains('ALLOW_DIRTY_DEPLOY'));
      expect(
        deployScriptSource,
        contains('ERROR: Refusing to deploy from a dirty git tree.'),
      );
      expect(
        deployScriptSource,
        contains('deployed build matches source control.'),
      );
      expect(deployScriptSource, contains('scripts/build_web_release.sh'));
      expect(
        deployScriptSource.indexOf('git status --porcelain'),
        lessThan(deployScriptSource.indexOf('if [[ -n "\$ENV_FILE_ARG" ]]')),
      );
    });

    test(
      'web bootstrap versions Flutter font asset loads for installed PWAs',
      () {
        expect(webIndexSource, contains('__kemeticFontAssetFetchPatched'));
        expect(webIndexSource, contains('__kemeticFontAssetXhrPatched'));
        expect(webIndexSource, contains('__kemeticFontAssetFontFacePatched'));
        expect(webIndexSource, contains('/assets/FontManifest.json'));
        expect(webIndexSource, contains('/assets/ios/Runner/Fonts/'));
        expect(
          webIndexSource,
          contains("url.searchParams.set('v', String(buildVersion))"),
        );
        expect(
          webIndexSource.indexOf('const buildVersion ='),
          lessThan(webIndexSource.indexOf('__kemeticFontAssetFetchPatched')),
        );
        expect(
          webIndexSource.indexOf('__kemeticFontAssetFetchPatched'),
          lessThan(webIndexSource.indexOf("s.src = 'flutter_bootstrap.js")),
        );
      },
    );
  });
}
