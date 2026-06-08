import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/page_navigation_swipe.dart';

void main() {
  testWidgets('left calendar edge swipe commits Planner navigation', (
    tester,
  ) async {
    var openedPlanner = false;
    var openedProfile = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              const Positioned.fill(child: Text('Calendar content')),
              PageNavigationEdgeSwipe(
                direction: PageNavigationSwipeDirection.leftToRight,
                onCommit: () => openedPlanner = true,
              ),
              PageNavigationEdgeSwipe(
                direction: PageNavigationSwipeDirection.rightToLeft,
                onCommit: () => openedProfile = true,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.dragFrom(const Offset(8, 320), const Offset(76, 0));
    await tester.pump();

    expect(openedPlanner, isTrue);
    expect(openedProfile, isFalse);
  });

  testWidgets('right calendar edge swipe commits Profile navigation', (
    tester,
  ) async {
    var openedPlanner = false;
    var openedProfile = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              const Positioned.fill(child: Text('Calendar content')),
              PageNavigationEdgeSwipe(
                direction: PageNavigationSwipeDirection.leftToRight,
                onCommit: () => openedPlanner = true,
              ),
              PageNavigationEdgeSwipe(
                direction: PageNavigationSwipeDirection.rightToLeft,
                onCommit: () => openedProfile = true,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.dragFrom(const Offset(792, 320), const Offset(-76, 0));
    await tester.pump();

    expect(openedPlanner, isFalse);
    expect(openedProfile, isTrue);
  });

  testWidgets(
    'center horizontal drag does not trigger calendar edge navigation',
    (tester) async {
      var openedPlanner = false;
      var openedProfile = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                const Positioned.fill(child: Text('Calendar content')),
                PageNavigationEdgeSwipe(
                  direction: PageNavigationSwipeDirection.leftToRight,
                  onCommit: () => openedPlanner = true,
                ),
                PageNavigationEdgeSwipe(
                  direction: PageNavigationSwipeDirection.rightToLeft,
                  onCommit: () => openedProfile = true,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.dragFrom(const Offset(400, 320), const Offset(120, 0));
      await tester.dragFrom(const Offset(400, 320), const Offset(-120, 0));
      await tester.pump();

      expect(openedPlanner, isFalse);
      expect(openedProfile, isFalse);
    },
  );
}
