import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/touch_targets.dart';

void main() {
  test('expanded touch targets stay on for iPhone-sized web layouts', () {
    expect(
      shouldUseExpandedTouchTargets(
        mediaQuery: const MediaQueryData(size: Size(390, 844)),
        isWeb: true,
        platform: TargetPlatform.iOS,
      ),
      isTrue,
    );
  });

  test('expanded touch targets stay on for tablet-sized web layouts', () {
    expect(
      shouldUseExpandedTouchTargets(
        mediaQuery: const MediaQueryData(size: Size(834, 1194)),
        isWeb: true,
        platform: TargetPlatform.iOS,
      ),
      isTrue,
    );
  });

  test('expanded touch targets stay off for desktop web layouts', () {
    expect(
      shouldUseExpandedTouchTargets(
        mediaQuery: const MediaQueryData(size: Size(1440, 900)),
        isWeb: true,
        platform: TargetPlatform.macOS,
      ),
      isFalse,
    );
  });

  test('expanded touch targets stay on for native mobile layouts', () {
    expect(
      shouldUseExpandedTouchTargets(
        mediaQuery: const MediaQueryData(size: Size(390, 844)),
        isWeb: false,
        platform: TargetPlatform.iOS,
      ),
      isTrue,
    );
  });

  test('global scale gestures stay off for touch-first platforms', () {
    expect(
      shouldEnableGlobalScaleGestures(
        mediaQuery: const MediaQueryData(size: Size(390, 844)),
        isWeb: true,
        platform: TargetPlatform.iOS,
      ),
      isFalse,
    );
    expect(
      shouldEnableGlobalScaleGestures(
        mediaQuery: const MediaQueryData(size: Size(834, 1194)),
        isWeb: true,
        platform: TargetPlatform.android,
      ),
      isFalse,
    );
  });

  test('global scale gestures stay on for desktop platforms', () {
    expect(
      shouldEnableGlobalScaleGestures(
        mediaQuery: const MediaQueryData(size: Size(1440, 900)),
        isWeb: true,
        platform: TargetPlatform.macOS,
      ),
      isTrue,
    );
  });

  test('app theme keeps Material buttons at padded touch target sizes', () {
    final theme = AppTheme.dark;

    expect(theme.materialTapTargetSize, MaterialTapTargetSize.padded);
    expect(
      theme.iconButtonTheme.style?.minimumSize?.resolve(<WidgetState>{}),
      const Size.square(kMinInteractiveDimension),
    );
    expect(
      theme.outlinedButtonTheme.style?.minimumSize?.resolve(<WidgetState>{}),
      const Size(56, kMinInteractiveDimension),
    );
  });

  testWidgets('edge swipe gesture width stays narrow on touch layouts', (
    tester,
  ) async {
    double? edgeWidth;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: Builder(
            builder: (context) {
              edgeWidth = edgeSwipeGestureWidth(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(edgeWidth, 18);
  });
}
