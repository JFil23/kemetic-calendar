import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/reflections/decan_review_models.dart';
import 'package:mobile/features/reflections/decan_review_views.dart';
import 'package:mobile/features/reflections/decan_review_widgets.dart';
import 'package:mobile/widgets/kemetic_keyboard.dart';
import 'package:mobile/widgets/keyboard_viewport_metrics.dart';
import 'package:mobile/widgets/utility_sheet_route_scaffold.dart';
import '../../support/maat_flow_visual_test_fonts.dart';

void main() {
  setUpAll(loadMaatFlowVisualTestFonts);
  for (final form in ['answer', 'moment', 'post']) {
    for (final mode in ['native', 'web-layout', 'web-visual']) {
      for (final landscape in [false, true]) {
        testWidgets(
          '$form field is visible with $mode keyboard, landscape=$landscape',
          (tester) async {
            final size = landscape
                ? const Size(852, 393)
                : const Size(402, 874);
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final inset = ValueNotifier<double>(0);
            final input = TextEditingController(text: 'My words stay with me.');
            addTearDown(inset.dispose);
            addTearDown(input.dispose);
            var writing = false;
            var saves = 0;
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData.dark(),
                builder: (_, child) => ValueListenableBuilder<double>(
                  valueListenable: inset,
                  builder: (_, height, __) => KemeticKeyboardHost(
                    viewportMetricsResolver:
                        (media, {required hasFocusedEditable}) =>
                            KeyboardViewportMetrics.resolve(
                              media: media,
                              hasFocusedEditable: hasFocusedEditable,
                              webViewport: mode == 'native'
                                  ? null
                                  : (
                                      height: size.height - height,
                                      layoutHeight: size.height,
                                      offsetTop: 0,
                                    ),
                            ),
                    child: child!,
                  ),
                ),
                home: RepaintBoundary(
                  key: const ValueKey('capture'),
                  child: StatefulBuilder(
                    builder: (context, setState) => UtilitySheetRouteScaffold(
                      semanticLabel: 'reflection',
                      maxWidth: 640,
                      onClose: () {},
                      child: form == 'moment'
                          ? DecanReviewChooser(
                              moments: const [],
                              selectedIds: const {},
                              onToggle: (_) {},
                              onOpen: (_) {},
                              ownController: input,
                              onOwnChanged: (_) {},
                              onKeep: () => saves++,
                              onBack: () {},
                            )
                          : form == 'post'
                          ? DecanReviewPublish(
                              controller: input,
                              onChanged: (_) {},
                              question: 'What would you like to carry forward?',
                              includeQuestion: true,
                              onQuestionChanged: (_) {},
                              author: 'You',
                              onPublish: () => saves++,
                              onBack: () {},
                            )
                          : DecanReviewOpening(
                              moments: [
                                DecanMoment(
                                  id: 'm',
                                  kind: 'flow',
                                  sourceId: 'm',
                                  occurredOn: DateTime(2026, 10, 2),
                                  sourceLabel: 'Your flow',
                                  actionLabel: 'Completed',
                                  text: 'A walk that made room for thought.',
                                ),
                              ],
                              decanStart: DateTime(2026, 10, 1),
                              question: 'What would you like to carry forward?',
                              onChoose: () {},
                              onWrite: () => setState(() => writing = true),
                              onLeave: () {},
                              onOpenMoment: (_) {},
                              answerController: writing ? input : null,
                              onSave: () => saves++,
                            ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final field = find.byType(TextField);
            if (form == 'answer') {
              await tester.ensureVisible(find.text('Leave a few words  →'));
              await tester.tap(find.text('Leave a few words  →'));
            } else {
              await tester.ensureVisible(field);
              await tester.tap(field);
            }
            await tester.pumpAndSettle();
            final editable = tester.state<EditableTextState>(
              find.byType(EditableText),
            );
            expect(editable.widget.focusNode.hasFocus, isTrue);
            final reviewScroll = tester
                .widget<SingleChildScrollView>(
                  find.descendant(
                    of: find.byType(DecanReviewCanvas),
                    matching: find.byType(SingleChildScrollView),
                  ),
                )
                .controller!;
            final reviewOffset = reviewScroll.offset;
            for (final height in [
              landscape ? 240.0 : 320.0,
              landscape ? 270.0 : 360.0,
              if (landscape) 310.0, // Safari chrome + native keyboard: 83px.
            ]) {
              inset.value = height;
              tester.view.viewInsets = FakeViewPadding(
                bottom: mode == 'web-layout' ? 0 : height,
              );
              if (mode == 'web-visual')
                tester.view.physicalSize = Size(
                  size.width,
                  size.height - height,
                );
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 450));
              await tester.pump(const Duration(milliseconds: 450));
              final rect = tester.getRect(field);
              final close = tester.getRect(
                find.byKey(utilitySheetRouteCloseButtonKey),
              );
              expect(
                rect.top,
                greaterThanOrEqualTo(close.bottom),
                reason: 'Entire field must clear fixed sheet header.',
              );
              expect(
                rect.bottom,
                lessThanOrEqualTo(size.height - height),
                reason: 'Entire field must clear keyboard.',
              );
              expect(field.hitTestable(), findsOneWidget);
              expect(editable.widget.controller.text, 'My words stay with me.');
              expect(editable.widget.focusNode.hasFocus, isTrue);
              expect(tester.takeException(), isNull);
              if (Platform.environment['HAW_DECAN_CAPTURE_DIR']
                  case final String path) {
                await tester.runAsync(() async {
                  final image =
                      await (tester.renderObject(
                                find.byKey(const ValueKey('capture')),
                              )
                              as RenderRepaintBoundary)
                          .toImage();
                  final bytes = await image.toByteData(
                    format: ui.ImageByteFormat.png,
                  );
                  await Directory(path).create(recursive: true);
                  await File(
                    '$path/keyboard-$form-$mode-$landscape-${height.toInt()}.png',
                  ).writeAsBytes(bytes!.buffer.asUint8List());
                  image.dispose();
                });
              }
            }
            await tester.tap(find.byTooltip('Done writing'));
            inset.value = 0;
            tester.view.viewInsets = const FakeViewPadding();
            tester.view.physicalSize = size;
            editable.widget.focusNode.unfocus();
            await tester.pumpAndSettle();
            expect(
              reviewScroll.offset,
              closeTo(reviewOffset, 1),
              reason: 'Done returns to the writing position, not the top.',
            );
            await tester.ensureVisible(
              find.text(
                form == 'answer'
                    ? 'Keep in Journal'
                    : form == 'moment'
                    ? 'Keep these moments'
                    : 'Post reflection',
              ),
            );
            await tester.tap(
              find.text(
                form == 'answer'
                    ? 'Keep in Journal'
                    : form == 'moment'
                    ? 'Keep these moments'
                    : 'Post reflection',
              ),
            );
            await tester.pump();
            expect(saves, 1);
            expect(input.text, 'My words stay with me.');
            // Switch to the real custom keyboard through the existing toggle.
            await tester.ensureVisible(field);
            await tester.tap(field);
            await tester.pumpAndSettle();
            await tester.tap(
              find.byKey(const ValueKey('kemetic-toggle-hit-target')),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 500));
            final scope = KemeticKeyboardScope.maybeOf(tester.element(field))!;
            expect(scope.isCustomKeyboardVisible, isTrue);
            final customRect = tester.getRect(field);
            expect(
              customRect.top,
              greaterThanOrEqualTo(
                tester
                    .getRect(find.byKey(utilitySheetRouteCloseButtonKey))
                    .bottom,
              ),
            );
            expect(customRect.bottom, lessThanOrEqualTo(scope.visibleBottom));
            expect(editable.widget.focusNode.hasFocus, isTrue);
            expect(
              tester.state<EditableTextState>(find.byType(EditableText)),
              same(editable),
            );
            expect(tester.takeException(), isNull);
            await tester.tap(find.byTooltip('Done writing'));
            await tester.pumpAndSettle();

            expect(
              find.byKey(utilitySheetRouteCloseButtonKey).hitTestable(),
              findsOneWidget,
            );
            await tester.pumpWidget(const SizedBox.shrink());
          },
        );
      }
    }
  }
}
