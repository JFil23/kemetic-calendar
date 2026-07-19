import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Android launch continuity guard', () {
    test('native launch and Flutter boot surfaces share one background', () {
      final colors = File(
        'android/app/src/main/res/values/colors.xml',
      ).readAsStringSync();
      final rootBoot = File('lib/root_boot.dart').readAsStringSync();

      expect(colors, contains('<color name="boot_background">#171518</color>'));
      expect(rootBoot, contains('Color(0xFF171518)'));
    });

    test('pre-Android 12 launch and normal themes are not transparent', () {
      for (final path in const <String>[
        'android/app/src/main/res/values/styles.xml',
        'android/app/src/main/res/values-night/styles.xml',
      ]) {
        final source = File(path).readAsStringSync();

        _expectLaunchStyle(
          _style(source, 'LaunchTheme'),
          path,
          windowBackground: '@drawable/launch_background',
        );
        _expectLaunchStyle(
          _style(source, 'NormalTheme'),
          path,
          windowBackground: '@color/boot_background',
        );
      }
    });

    test(
      'MainActivity hands off from launch theme to matching normal theme',
      () {
        final manifest = File(
          'android/app/src/main/AndroidManifest.xml',
        ).readAsStringSync();

        expect(manifest, contains('android:theme="@style/LaunchTheme"'));
        expect(
          manifest,
          contains('android:name="io.flutter.embedding.android.NormalTheme"'),
        );
        expect(manifest, contains('android:resource="@style/NormalTheme"'));
      },
    );

    test('Android 12 splash uses the matching launch surface', () {
      for (final path in const <String>[
        'android/app/src/main/res/values-v31/styles.xml',
        'android/app/src/main/res/values-night-v31/styles.xml',
      ]) {
        final source = File(path).readAsStringSync();
        final launch = _style(source, 'LaunchTheme');
        final normal = _style(source, 'NormalTheme');

        expect(
          launch,
          contains(
            '<item name="android:windowSplashScreenBackground">@color/boot_background</item>',
          ),
        );
        expect(
          launch,
          contains(
            '<item name="android:windowSplashScreenAnimatedIcon">@drawable/launch_word</item>',
          ),
        );
        _expectLaunchStyle(
          launch,
          path,
          windowBackground: '@color/boot_background',
        );
        _expectLaunchStyle(
          normal,
          path,
          windowBackground: '@color/boot_background',
        );
      }
    });

    test('launch drawables use the same boot background token', () {
      for (final path in const <String>[
        'android/app/src/main/res/drawable/launch_background.xml',
        'android/app/src/main/res/drawable-v21/launch_background.xml',
      ]) {
        final source = File(path).readAsStringSync();

        expect(
          source,
          contains('<item android:drawable="@color/boot_background"'),
        );
        expect(source, contains('android:src="@drawable/launch_word"'));
        expect(source, isNot(contains('@android:color/transparent')));
      }
    });
  });
}

String _style(String source, String name) {
  final start = source.indexOf('<style name="$name"');
  expect(start, isNonNegative, reason: 'Missing style $name');
  final end = source.indexOf('</style>', start);
  expect(end, isNonNegative, reason: 'Missing end for style $name');
  return source.substring(start, end + '</style>'.length);
}

void _expectLaunchStyle(
  String source,
  String path, {
  required String windowBackground,
}) {
  expect(
    source,
    contains('<item name="android:windowBackground">$windowBackground</item>'),
    reason: '$path window background must be explicit.',
  );
  expect(
    source,
    contains(
      '<item name="android:statusBarColor">@color/boot_background</item>',
    ),
    reason: '$path status bar must match the boot surface.',
  );
  expect(
    source,
    contains(
      '<item name="android:navigationBarColor">@color/boot_background</item>',
    ),
    reason: '$path navigation bar must match the boot surface.',
  );
  expect(
    source,
    contains('<item name="android:windowLightStatusBar">false</item>'),
  );
  expect(
    source,
    contains('<item name="android:windowLightNavigationBar">false</item>'),
  );
  expect(source, isNot(contains('@android:color/transparent')));
  expect(source, isNot(contains('windowIsTranslucent">true')));
}
