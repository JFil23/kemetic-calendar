import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/page_navigation_swipe.dart';
import 'package:mobile/services/navigation_trace.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    NavigationTrace.instance.resetForTesting();
  });

  tearDown(() {
    NavigationTrace.instance.resetForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

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

  testWidgets('threshold haptic fires once per drag and resets', (
    tester,
  ) async {
    var commitCount = 0;
    var hapticCount = 0;
    final hapticArguments = <Object?>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            hapticCount += 1;
            hapticArguments.add(call.arguments);
          }
          return null;
        });
    await NavigationTrace.instance.setEnabled(true);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              const Positioned.fill(child: Text('Calendar content')),
              PageNavigationEdgeSwipe(
                direction: PageNavigationSwipeDirection.leftToRight,
                onCommit: () => commitCount += 1,
              ),
            ],
          ),
        ),
      ),
    );

    final firstDrag = await tester.startGesture(const Offset(8, 320));
    await firstDrag.moveBy(const Offset(30, 0));
    await tester.pump();
    expect(hapticCount, 0);

    await firstDrag.moveBy(const Offset(26, 0));
    await tester.pump();
    expect(hapticCount, 1);

    await firstDrag.moveBy(const Offset(40, 0));
    await tester.pump();
    expect(hapticCount, 1);

    await firstDrag.up();
    await tester.pump();
    expect(commitCount, 1);

    final secondDrag = await tester.startGesture(const Offset(8, 320));
    await secondDrag.moveBy(const Offset(56, 0));
    await tester.pump();
    expect(hapticCount, 2);
    await secondDrag.up();
    await tester.pump();
    expect(commitCount, 2);

    expect(
      hapticArguments,
      everyElement(equals('HapticFeedbackType.selectionClick')),
    );
    final entries = NavigationTrace.instance.entries.join('\n');
    expect(entries, contains('edge swipe drag start'));
    expect(entries, contains('edge swipe threshold crossed'));
    expect(entries, contains('edge swipe drag end'));
    expect(entries, contains('edge swipe commit fired'));
    expect(entries, contains('timestampMs='));
    expect(entries, contains('elapsedMs='));
  });
}
