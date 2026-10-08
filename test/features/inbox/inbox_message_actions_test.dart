import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:mobile/features/inbox/dm_conversation_models.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/inbox/presentation/inbox_message_actions.dart';
import 'package:mobile/features/inbox/presentation/inbox_message_bubble.dart';
import '../../support/maat_flow_visual_test_fonts.dart';

void main() {
  setUpAll(loadMaatFlowVisualTestFonts);
  testWidgets('group pending and failed messages retain the existing bubble', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Column(
            children: [
              for (final status in ['Sending…', 'Not sent'])
                InboxDmMessageRow(
                  message: DmConversationMessage(
                    id: status,
                    conversationId: 'group',
                    senderId: 'me',
                    body: 'Here is my reply',
                    kind: 'text',
                    createdAt: DateTime(2026, 10, 7),
                    payloadJson: const {
                      'reply_to': {'text': 'Follow the sky'},
                    },
                  ),
                  isMine: true,
                  showSender: false,
                  deliveryLabel: status,
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sending…'), findsOneWidget);
    expect(find.text('Not sent'), findsOneWidget);
    expect(find.text('Here is my reply'), findsNWidgets(2));
    expect(find.text('Replying to'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
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
  testWidgets('large text menu scrolls within a short landscape viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var removed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: InboxMessageActions(
                createdAt: DateTime(2026, 10, 7),
                onReply: () {},
                onForward: () {},
                onCopy: () {},
                onDeleteForMe: () => removed = true,
                child: const Text('An incoming message'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.longPress(find.text('An incoming message'));
    await tester.pumpAndSettle();
    expect(find.text('Unsend'), findsNothing);
    await tester.ensureVisible(find.text('Delete for me'));
    await tester.pumpAndSettle();
    expect(tester.getBottomRight(find.text('Delete for me')).dy, lessThan(390));
    await tester.tap(find.text('Delete for me'));
    await tester.pumpAndSettle();
    expect(removed, isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'quoted context stays readable inside dark and gold message bubbles',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        RepaintBoundary(
          key: const Key('quote-capture'),
          child: MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final color in [
                      const Color(0xFF302911),
                      const Color(0xFFD1AF32),
                    ])
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const InboxReplyPreview(
                          text:
                              'Follow the sky — a longer quoted message that wraps to the second line',
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Replying to'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      final folder = Platform.environment['HAW_MESSAGE_ACTION_CAPTURE_DIR'];
      if (folder != null) {
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const Key('quote-capture')),
          );
          final shot = await boundary.toImage();
          final data = await shot.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '$folder/reply-contrast.png',
          ).writeAsBytes(data!.buffer.asUint8List());
          shot.dispose();
        });
      }
    },
  );
}
