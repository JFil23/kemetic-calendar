import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/settings/speech_settings_card.dart';
import 'package:mobile/services/speech/speech_voice.dart';
import '../../support/maat_flow_visual_test_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadMaatFlowVisualTestFonts);
  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Speech card fits $size at $scale', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        var selected = SpeechVoiceOption.g;
        var previews = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: StatefulBuilder(
              builder: (context, setState) => RepaintBoundary(
                key: const ValueKey('capture'),
                child: Scaffold(
                  appBar: AppBar(
                    title: const Text('Settings'),
                    centerTitle: true,
                  ),
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    child: SpeechSettingsCard(
                      selectedVoice: selected,
                      onChanged: (value) => setState(() => selected = value),
                      onPreview: () => previews++,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          tester
              .getRect(find.byKey(const ValueKey('speech-settings-card')))
              .left,
          16,
        );
        if (const bool.fromEnvironment('CAPTURE_SPEECH')) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('capture')),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File(
              '/tmp/haw-speech-visuals/card-${size.width.toInt()}-$scale.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        expect(find.text('System default'), findsNothing);
        expect(find.text('F · Deep & grounded'), findsNothing);
        expect(find.text('G · Sahidic man'), findsWidgets);
        expect(find.text('H · Sahidic woman'), findsOneWidget);
        await tester.ensureVisible(find.text('H · Sahidic woman'));
        await tester.tap(find.text('H · Sahidic woman'));
        await tester.pumpAndSettle();
        expect(selected, SpeechVoiceOption.h);
        await tester.ensureVisible(find.text('Preview selected voice'));
        await tester.tap(find.text('Preview selected voice'));
        expect(previews, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('retry and stop states remain usable at large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SingleChildScrollView(
            child: SpeechSettingsCard(
              selectedVoice: SpeechVoiceOption.h,
              onChanged: (_) {},
              onPreview: () {},
              previewActive: true,
              status:
                  'Some recordings could not be saved. Reconnect and try again.',
              onRetry: () => retries++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Stop voice preview'), findsOneWidget);
    await tester.ensureVisible(find.text('Try again'));
    await tester.tap(find.text('Try again'));
    expect(retries, 1);
    expect(tester.takeException(), isNull);
  });
}
