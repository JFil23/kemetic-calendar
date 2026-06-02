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
  });
}
