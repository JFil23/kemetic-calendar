import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/widgets/follow_sky_v11_tokens.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_detail_shell.dart';
import 'package:mobile/widgets/kemetic_keyboard.dart';

void main() {
  const theme = MaatFlowDetailTheme(
    pageBackground: Color(0xFF050504),
    sheetBackground: Color(0xFF080706),
    sheetBorder: Color(0x2ED4AE43),
    accent: Color(0xFFD4AE43),
    primaryText: Color(0xFFC8C4BC),
    secondaryText: Color(0xFF9E9A94),
    mutedText: Color(0xFF6A6660),
    separator: Color(0xFF2A2415),
    glow: Color(0xFFA4B1FF),
  );

  test('Follow Sky reference tokens remain aliases of shared geometry', () {
    expect(
      FollowSkyV11Tokens.referenceWidth,
      MaatFlowDetailGeometry.referenceWidth,
    );
    expect(
      FollowSkyV11Tokens.referenceHeight,
      MaatFlowDetailGeometry.referenceHeight,
    );
    expect(FollowSkyV11Tokens.heroHeight, MaatFlowDetailGeometry.heroHeight);
    expect(
      FollowSkyV11Tokens.sheetOverlap,
      MaatFlowDetailGeometry.sheetOverlap,
    );
    expect(
      FollowSkyV11Tokens.heroParallaxFactor,
      MaatFlowDetailGeometry.heroParallaxFactor,
    );
  });

  testWidgets('shell preserves overlap, parallax, fade, and fixed dock', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MaatFlowDetailShell(
            theme: theme,
            scrollKey: const ValueKey<String>('test-detail-scroll'),
            heroLayerKey: const ValueKey<String>('test-hero-layer'),
            sheetKey: const ValueKey<String>('test-sheet'),
            hero: const ColoredBox(color: Colors.blue),
            sheet: const SizedBox(height: 1000),
            bottomDock: const SizedBox(
              key: ValueKey<String>('test-dock'),
              height: 100,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.getTopLeft(find.byKey(const ValueKey<String>('test-sheet'))).dy,
      closeTo(406, 0.01),
    );
    final dockTop = tester
        .getTopLeft(find.byKey(const ValueKey<String>('test-dock')))
        .dy;
    final heroTop = tester
        .getTopLeft(find.byKey(const ValueKey<String>('test-hero-layer')))
        .dy;

    await tester.drag(
      find.byKey(const ValueKey<String>('test-detail-scroll')),
      const Offset(0, -180),
    );
    await tester.pump();

    expect(
      tester.getTopLeft(find.byKey(const ValueKey<String>('test-dock'))).dy,
      dockTop,
    );
    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey<String>('test-hero-layer')))
          .dy,
      lessThan(heroTop),
    );
    final opacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('test-hero-layer')),
        matching: find.byType(Opacity),
      ),
    );
    expect(opacity.opacity, lessThan(1));
  });

  testWidgets('shell hides its dock for the system keyboard and restores it', (
    tester,
  ) async {
    Widget harness({required bool keyboardVisible}) {
      return MaterialApp(
        home: KemeticKeyboardScope(
          isCustomKeyboardVisible: false,
          customKeyboardInset: 0,
          systemKeyboardInset: keyboardVisible ? 300 : 0,
          keyboardInset: keyboardVisible ? 300 : 0,
          visibleTop: 0,
          visibleBottom: keyboardVisible ? 544 : 844,
          isSystemKeyboardVisible: keyboardVisible,
          child: Scaffold(
            body: MaatFlowDetailShell(
              theme: theme,
              hero: const ColoredBox(color: Colors.blue),
              sheet: const SizedBox(height: 1000),
              bottomDock: const SizedBox(
                key: ValueKey<String>('system-keyboard-dock'),
                height: 100,
              ),
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(harness(keyboardVisible: true));

    expect(
      find.byKey(const ValueKey<String>('system-keyboard-dock')),
      findsNothing,
    );

    await tester.pumpWidget(harness(keyboardVisible: false));

    expect(
      find.byKey(const ValueKey<String>('system-keyboard-dock')),
      findsOneWidget,
    );
  });

  testWidgets('shell hides its dock for the Kemetic keyboard and restores it', (
    tester,
  ) async {
    Widget harness({required bool keyboardVisible}) {
      return MaterialApp(
        home: KemeticKeyboardScope(
          isCustomKeyboardVisible: keyboardVisible,
          customKeyboardInset: keyboardVisible ? 300 : 0,
          systemKeyboardInset: 0,
          keyboardInset: keyboardVisible ? 300 : 0,
          visibleTop: 0,
          visibleBottom: keyboardVisible ? 544 : 844,
          isSystemKeyboardVisible: false,
          child: Scaffold(
            body: MaatFlowDetailShell(
              theme: theme,
              hero: const ColoredBox(color: Colors.blue),
              sheet: const SizedBox(height: 1000),
              bottomDock: const SizedBox(
                key: ValueKey<String>('kemetic-keyboard-dock'),
                height: 100,
              ),
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(harness(keyboardVisible: true));
    expect(
      find.byKey(const ValueKey<String>('kemetic-keyboard-dock')),
      findsNothing,
    );

    await tester.pumpWidget(harness(keyboardVisible: false));
    expect(
      find.byKey(const ValueKey<String>('kemetic-keyboard-dock')),
      findsOneWidget,
    );
  });
}
