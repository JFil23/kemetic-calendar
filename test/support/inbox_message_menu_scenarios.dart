import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/inbox/presentation/inbox_message_actions.dart';
import 'package:mobile/features/inbox/presentation/inbox_message_bubble.dart';

/// Exercise the same touch targets in widget tests and on the native device.
void inboxMessageMenuScenarios({Size? viewport}) {
  for (final outgoing in [true, false]) {
    for (final area in ['beside menu', 'preview', 'gap', 'background']) {
      testWidgets(
        '${outgoing ? 'outgoing' : 'incoming'} menu closes with one tap on $area',
        (tester) async {
          if (viewport != null) {
            tester.view.physicalSize = viewport;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
          }
          var actions = 0;
          var backgroundTaps = 0;
          var messageTaps = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.dark,
              home: Scaffold(
                appBar: AppBar(title: const Text('Alton Chislom')),
                body: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => backgroundTaps++,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Align(
                      alignment: outgoing
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: InboxMessageActions(
                        createdAt: DateTime(2026, 10, 7, 17, 6),
                        onTap: () => messageTaps++,
                        onReply: () => actions++,
                        onForward: () => actions++,
                        onCopy: () => actions++,
                        onDeleteForMe: () => actions++,
                        onUnsend: outgoing ? () => actions++ : null,
                        child: InboxMessageBubble(
                          text: 'test',
                          createdAt: DateTime(2026, 10, 7, 17, 6),
                          isMine: outgoing,
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
          await tester.pumpAndSettle();
          // Release the original hold after the overlay appears. That release
          // must not dismiss it or trigger an action.
          final hold = await tester.startGesture(
            tester.getCenter(find.text('test')),
          );
          await tester.pump(const Duration(seconds: 1));
          await hold.up();
          await tester.pumpAndSettle();
          expect(find.text('Reply'), findsOneWidget);
          final menu = find
              .ancestor(
                of: find.text('Reply'),
                matching: find.byType(Container),
              )
              .first;
          final menuRect = tester.getRect(menu);
          final previewRect = tester.getRect(find.text('test').last);
          final point = switch (area) {
            // This blank space belongs to the wider scrolling overlay, which
            // used to intercept touches before they reached the modal barrier.
            'beside menu' => Offset(
              outgoing ? menuRect.left - 8 : menuRect.right + 8,
              menuRect.center.dy,
            ),
            'preview' => previewRect.center,
            'gap' => Offset(menuRect.center.dx, menuRect.top - 4),
            _ => const Offset(8, 80),
          };
          expect(menuRect.contains(point), isFalse);
          final outsideTap = await tester.startGesture(point);
          await tester.pump(const Duration(milliseconds: 60));
          await outsideTap.up();
          await tester.pumpAndSettle();
          expect(find.text('Reply'), findsNothing);
          expect(find.text('test'), findsOneWidget);
          expect(actions, 0);
          expect(backgroundTaps, 0);
          expect(messageTaps, 0);
          expect(tester.takeException(), isNull);
          // The underlying conversation becomes usable immediately afterward.
          final nextTap = await tester.startGesture(
            tester.getCenter(find.text('test')),
          );
          await tester.pump(const Duration(milliseconds: 60));
          await nextTap.up();
          await tester.pumpAndSettle();
          expect(messageTaps, 1);
        },
      );
    }
  }
}
