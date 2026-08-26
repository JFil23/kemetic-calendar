import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('web runtime config guard', () {
    late String mainSource;
    late String runtimeGuardSource;
    late String webIndexSource;
    late String buildScriptSource;
    late String deployScriptSource;
    late String pipelineSource;
    late String stagingConfigSource;
    late String productionConfigSource;

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
      pipelineSource = await File(
        'scripts/web_release_pipeline.py',
      ).readAsString();
      stagingConfigSource = await File(
        'config/web/staging.public.json',
      ).readAsString();
      productionConfigSource = await File(
        'config/web/production.public.json',
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

    test('web direct routes win over passive restoration on boot', () {
      expect(
        mainSource,
        contains(
          '_bootExplicitIntentLocation ??= '
          '_initialLocationFromWebBrowserLocation();',
        ),
      );
      expect(
        mainSource,
        contains('String? _initialLocationFromWebBrowserLocation()'),
      );
      expect(mainSource, contains('if (!kIsWeb) return null;'));
      expect(mainSource, contains('final uri = Uri.base;'));
      expect(mainSource, contains("if (path.isEmpty || path == '/')"));
      expect(mainSource, contains("query: uri.query.trim().isEmpty"));

      final webRouteIndex = mainSource.indexOf(
        '_bootExplicitIntentLocation ??= '
        '_initialLocationFromWebBrowserLocation();',
      );
      final restoreIndex = mainSource.indexOf(
        '_bootRestoredLocation = await _readBootRestoredLocation();',
      );
      expect(webRouteIndex, greaterThanOrEqualTo(0));
      expect(restoreIndex, greaterThan(webRouteIndex));
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

    test('web release build accepts only named public environments', () {
      expect(buildScriptSource, contains('--dart-define-from-file'));
      expect(
        buildScriptSource,
        contains('--dart-define="HYDRATION_DIAGNOSTIC_BUILD=\$BUILD_VERSION"'),
      );
      expect(
        buildScriptSource,
        contains('scripts/web_release_pipeline.py prepare'),
      );
      expect(
        buildScriptSource,
        contains('scripts/build_web_release.sh <staging|production>'),
      );
      expect(buildScriptSource, isNot(contains('ENV_FILE')));
      expect(buildScriptSource, isNot(contains('WEB_BUILD_VERSION')));
      expect(buildScriptSource, isNot(contains('WEB_SOURCE_MAPS')));
      expect(buildScriptSource, isNot(contains('web/env.json')));
      expect(pipelineSource, contains('"config/web/staging.public.json"'));
      expect(pipelineSource, contains('"config/web/production.public.json"'));
      expect(pipelineSource, contains('"SUPABASE_URL"'));
      expect(pipelineSource, contains('"SUPABASE_ANON_KEY"'));
      expect(pipelineSource, contains('"APP_ENV"'));
      expect(pipelineSource, contains('"APP_SITE_URL"'));
      expect(pipelineSource, contains('reject_forbidden_environment'));
      expect(pipelineSource, contains('require_clean_paired_repositories'));
      expect(stagingConfigSource, contains('"environment": "staging"'));
      expect(productionConfigSource, contains('"environment": "production"'));
    });

    test('web release identity and archive are deterministic', () {
      expect(pipelineSource, contains('"parent_tree"'));
      expect(pipelineSource, contains('"mobile_tree"'));
      expect(pipelineSource, contains('"config_sha256"'));
      expect(pipelineSource, contains('"builder_sha256"'));
      expect(pipelineSource, contains('"lockfile_sha256"'));
      expect(pipelineSource, contains('"toolchain_sha256"'));
      expect(pipelineSource, contains('iso_utc_from_epoch'));
      expect(pipelineSource, isNot(contains('datetime.now')));
      expect(buildScriptSource, contains('git archive --format=tar HEAD'));
      expect(buildScriptSource, contains('flutter pub get --enforce-lockfile'));
      expect(buildScriptSource, contains('PUB_CACHE="\$STATE_DIR/pub-cache"'));
      expect(buildScriptSource, contains('PUB_HOSTED_URL="https://pub.dev"'));
      expect(buildScriptSource, contains('verify-lockfile'));
      expect(buildScriptSource, contains('--no-pub'));
      expect(buildScriptSource, isNot(contains('flutter clean')));
      expect(pipelineSource, contains('require_prepared_current'));
      expect(pipelineSource, contains('dist/web-releases'));
      expect(pipelineSource, contains('flutter_tools_snapshot'));
      expect(pipelineSource, contains('"const_finder_snapshot"'));
      expect(pipelineSource, contains('"font_subset"'));
      expect(pipelineSource, contains('"dart_sdk": sha256_tree'));
      expect(pipelineSource, contains('"python_stdlib": sha256_tree'));
      expect(pipelineSource, contains('"host_executables"'));
      expect(pipelineSource, contains('create_deterministic_archive'));
      expect(
        pipelineSource,
        contains('DEPLOYMENT_OMISSIONS = (".last_build_id",)'),
      );
      expect(pipelineSource, contains('gzip.GzipFile'));
      expect(pipelineSource, contains('mtime=0'));
    });

    test('Cloudflare Pages deploy uploads one authorized artifact', () {
      expect(deployScriptSource, contains('<authorized-archive-sha256>'));
      expect(
        deployScriptSource,
        contains('scripts/web_release_pipeline.py verify'),
      );
      expect(deployScriptSource, contains('wrangler@\$WRANGLER_VERSION'));
      expect(deployScriptSource, contains('WRANGLER_VERSION="4.114.0"'));
      expect(deployScriptSource, isNot(contains('wrangler@latest')));
      expect(
        deployScriptSource,
        isNot(contains('scripts/build_web_release.sh')),
      );
    });

    test('web bootstrap versions every Flutter asset by release identity', () {
      expect(webIndexSource, contains('withFlutterAssetVersion'));
      expect(webIndexSource, contains('__kemeticFlutterAssetFetchPatched'));
      expect(webIndexSource, contains('__kemeticFlutterAssetXhrPatched'));
      expect(webIndexSource, contains('__kemeticFontAssetFontFacePatched'));
      expect(
        webIndexSource,
        contains("url.pathname.indexOf('/assets/') !== -1"),
      );
      expect(webIndexSource, contains('isSameOrigin && isFlutterAsset'));
      expect(
        webIndexSource,
        contains("url.searchParams.set('v', String(buildVersion))"),
      );
      expect(
        webIndexSource.indexOf('const buildVersion ='),
        lessThan(webIndexSource.indexOf('__kemeticFlutterAssetFetchPatched')),
      );
      expect(
        webIndexSource.indexOf('__kemeticFlutterAssetFetchPatched'),
        lessThan(webIndexSource.indexOf("s.src = 'flutter_bootstrap.js")),
      );
    });
  });
}
