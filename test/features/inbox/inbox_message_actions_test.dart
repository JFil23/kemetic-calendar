import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/inbox/presentation/inbox_message_actions.dart';
import 'package:mobile/features/inbox/presentation/inbox_message_bubble.dart';
import '../../support/maat_flow_visual_test_fonts.dart';

void main() {
  setUpAll(loadMaatFlowVisualTestFonts);
  for (final width in [320.0, 390.0, 844.0]) {
    testWidgets('lifted menu core actions at $width', (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var copied = 0;
      await tester.pumpWidget(
        RepaintBoundary(
          key: const Key('capture'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark,
            home: Scaffold(
              backgroundColor: const Color(0xFF100C03),
              appBar: AppBar(title: const Text('Alton Chislom')),
              body: Padding(
                padding: const EdgeInsets.all(24),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: InboxMessageActions(
                    createdAt: DateTime(2026, 10, 7, 15, 48),
                    onReply: () {},
                    onForward: () {},
                    onCopy: () => copied++,
                    onDeleteForMe: () {},
                    onUnsend: () {},
                    child: InboxMessageBubble(
                      text: "I'll check it out",
                      createdAt: DateTime(2026, 10, 7, 15, 48),
                      isMine: true,
                      likesCount: 0,
                      likedByMe: false,
                      likeUpdating: false,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final hold = await tester.startGesture(
        tester.getCenter(find.text("I'll check it out")),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await hold.up();
      await tester.pumpAndSettle();
      for (final label in [
        'Reply',
        'Forward',
        'Copy',
        'Delete for me',
        'Unsend',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      if (Platform.environment['HAW_MESSAGE_ACTION_CAPTURE_DIR'] != null) {
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const Key('capture')),
          );
          final shot = await boundary.toImage();
          final bytes = await shot.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '${Platform.environment['HAW_MESSAGE_ACTION_CAPTURE_DIR']}/menu-${width.toInt()}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          shot.dispose();
        });
      }
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();
      expect(copied, 1);
      expect(find.text('Unsend'), findsNothing);
    });
  }
}
