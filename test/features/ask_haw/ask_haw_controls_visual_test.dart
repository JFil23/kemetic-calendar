import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/ask_haw/ask_haw_settings_card.dart';
import 'package:mobile/features/reflections/decan_review_views.dart';
import 'package:mobile/features/calendar/the_reading_house_flow.dart'
    show kReadingHouseTitle;
import '../../support/maat_flow_visual_test_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadMaatFlowVisualTestFonts);
  for (final size in [
    const Size(390, 844),
    const Size(844, 390),
    const Size(768, 1024),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Ask controls fit $size at $scale', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        for (final state in [
          'collapsed',
          'loading',
          'empty',
          'populated',
          'usual_time',
          'flow_preferences',
          'failure',
          'continuation',
        ]) {
          final populated =
              state == 'populated' ||
              state == 'usual_time' ||
              state == 'flow_preferences';
          final capture = GlobalKey();
          var actions = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.dark,
              home: RepaintBoundary(
                key: capture,
                child: Scaffold(
                  appBar: AppBar(title: const Text('Settings')),
                  body: state == 'continuation'
                      ? DecanReviewContinuation(
                          suggestions: const [],
                          onOpen: (_) {},
                          onDismiss: (_) {},
                          onDone: () {},
                          onAsk: (_) => actions++,
                          onShorterSessions: () => actions++,
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: AskHawSettingsView(
                            expanded: state != 'collapsed',
                            loading: state == 'loading',
                            available: state != 'failure',
                            preferredDurationMinutes: populated ? 15 : null,
                            planningWindowKey: populated ? '10:16' : null,
                            usualStartTime: populated
                                ? const TimeOfDay(hour: 20, minute: 15)
                                : null,
                            onChangeUsualTime: () {},
                            onResetUsualTime: () {},
                            flowDurationMinutes: populated
                                ? const {'42': 15, '77': 20}
                                : const {},
                            flowDurationTitles: const {
                              '42': kReadingHouseTitle,
                              '77': 'Writing practice',
                            },
                            onPlanningWindowChanged: (_) {},
                            onRemoveFlowDuration: (_) {},
                            bindings: populated
                                ? const {
                                    'evening reset': {
                                      'intent': 'discover',
                                      'query': 'rest',
                                    },
                                    'a little room to read and reflect': {
                                      'intent': 'fit',
                                    },
                                  }
                                : const {},
                            hiddenSuggestions: populated
                                ? const {'maat:the-reading-house'}
                                : const {},
                            contentTitles: const {
                              'maat:the-reading-house': kReadingHouseTitle,
                            },
                            notice: state == 'failure'
                                ? 'Remembered details could not be loaded. Try again.'
                                : null,
                            onRetry: state == 'failure' ? () {} : null,
                            onOpen: () => actions++,
                            onSuggestionsChanged: (_) {},
                            onDurationChanged: (_) {},
                            onTimeOfDayChanged: (_) {},
                            onRemoveBinding: (_) {},
                            onRestoreSuggestion: (_) {},
                            onClear: () {},
                          ),
                        ),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          if (state == 'flow_preferences') {
            await tester.ensureVisible(find.text('Session lengths for Flows'));
            await tester.pump();
          }
          if (state == 'usual_time') {
            await tester.ensureVisible(find.text('Usual start time'));
            await tester.pump();
          }
          expect(tester.takeException(), isNull, reason: '$state $size $scale');
          if (Platform.environment['HAW_ASK_CONTROLS_CAPTURE_DIR']
              case final String path when path.isNotEmpty) {
            await tester.runAsync(() async {
              final boundary =
                  capture.currentContext!.findRenderObject()
                      as RenderRepaintBoundary;
              final image = await boundary.toImage(pixelRatio: 1);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File(
                '$path/$state-${size.width.toInt()}-$scale.png',
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          if (state == 'collapsed') {
            await tester.tap(find.byKey(const ValueKey('ask-haw-memory-open')));
            expect(actions, 1);
          }
          if (state == 'continuation') {
            await tester.ensureVisible(find.text('Explore flows'));
            await tester.tap(find.text('Explore flows'));
            expect(actions, 1);
            await tester.ensureVisible(
              find.text('Find time for a personal activity'),
            );
            await tester.tap(find.text('Find time for a personal activity'));
            expect(actions, 2);
            await tester.ensureVisible(find.text('Use shorter sessions'));
            await tester.tap(find.text('Use shorter sessions'));
            expect(actions, 3);
          }
        }
      });
    }
  }
}
