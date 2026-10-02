import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/root_boot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final gentium = FontLoader('GentiumPlus')
      ..addFont(rootBundle.load('ios/Runner/Fonts/GentiumPlus-Regular.ttf'))
      ..addFont(rootBundle.load('ios/Runner/Fonts/GentiumPlus-Bold.ttf'));
    await gentium.load();

    // Use Flutter's real default Material font for the recovery action rather
    // than the widget-test Ahem font. Resolve the SDK from package_config so
    // this remains portable to the App gate's pinned Flutter installation.
    final configFile = File('.dart_tool/package_config.json');
    final config = jsonDecode(configFile.readAsStringSync()) as Map;
    final flutter = (config['packages'] as List).cast<Map>().singleWhere(
      (package) => package['name'] == 'flutter',
    );
    final flutterPackage = configFile.absolute.uri.resolve(
      '${flutter['rootUri']}/',
    );
    final fonts = flutterPackage.resolve(
      '../../bin/cache/artifacts/material_fonts/',
    );
    final roboto = FontLoader('Roboto');
    for (final name in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf']) {
      roboto.addFont(
        File.fromUri(
          fonts.resolve(name),
        ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
      );
    }
    await roboto.load();
  });

  for (final viewport in <String, Size>{
    'portrait': const Size(390, 844),
    'landscape': const Size(844, 390),
  }.entries) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('launch brand fits ${viewport.key} at text scale $scale', (
        tester,
      ) async {
        _configureViewport(tester, viewport.value, scale);
        await tester.pumpWidget(
          const RepaintBoundary(
            key: ValueKey('boot-capture'),
            child: RootBootShell(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);
        final word = find.text('ḥꜣw');
        expect(word, findsOneWidget);
        final renderedWord = tester.widget<RichText>(
          find.descendant(of: word, matching: find.byType(RichText)),
        );
        expect(
          renderedWord.text.style?.decoration,
          anyOf(isNull, TextDecoration.none),
          reason:
              'The launch word must not inherit the missing-Material '
              'yellow underline.',
        );
        final wordRect = tester.getRect(word);
        expect(wordRect.center.dx, closeTo(viewport.value.width / 2, 0.1));
        expect(wordRect.center.dy, closeTo(viewport.value.height / 2, 0.1));
        expect(wordRect.left, greaterThanOrEqualTo(32));
        expect(wordRect.right, lessThanOrEqualTo(viewport.value.width - 32));
        expect(wordRect.top, greaterThanOrEqualTo(0));
        expect(wordRect.bottom, lessThanOrEqualTo(viewport.value.height));
        await _capture(tester, 'launch-${viewport.key}-${scale.toInt()}x');
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets('recovery fits ${viewport.key} at text scale $scale', (
        tester,
      ) async {
        _configureViewport(tester, viewport.value, scale);
        var retries = 0;
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('boot-capture'),
            child: RootBootErrorShell(onRetry: () => retries += 1),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final heading = find.text('Unable to start');
        final retry = find.text('Retry');
        expect(heading, findsOneWidget);
        expect(retry, findsOneWidget);
        for (final finder in [heading, retry]) {
          final rect = tester.getRect(finder);
          expect(rect.left, greaterThanOrEqualTo(24));
          expect(rect.right, lessThanOrEqualTo(viewport.value.width - 24));
          expect(rect.top, greaterThanOrEqualTo(0));
          expect(rect.bottom, lessThanOrEqualTo(viewport.value.height));
        }
        expect(
          tester.getCenter(heading).dx,
          closeTo(viewport.value.width / 2, 0.1),
        );
        await _capture(tester, 'recovery-${viewport.key}-${scale.toInt()}x');
        await tester.tap(retry);
        expect(retries, 1);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets('native recovery explains how to reopen without unsafe retry', (
    tester,
  ) async {
    _configureViewport(tester, const Size(844, 390), 2);
    await tester.pumpWidget(
      const RepaintBoundary(
        key: ValueKey('boot-capture'),
        child: RootBootErrorShell(),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Close and reopen the app to try again.'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    await _capture(tester, 'recovery-native-landscape-2x');
  });
}

void _configureViewport(WidgetTester tester, Size size, double scale) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_ROOT_BOOT')) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('boot-capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('/tmp/haw-startup-repair/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}
