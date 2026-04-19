import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/touch_targets.dart';

void main() {
  test('expanded touch targets are enabled for tablet-sized web layouts', () {
    expect(
      shouldUseExpandedTouchTargets(
        mediaQuery: const MediaQueryData(size: Size(834, 1194)),
        isWeb: true,
      ),
      isTrue,
    );
  });

  test('expanded touch targets stay off for phone web layouts', () {
    expect(
      shouldUseExpandedTouchTargets(
        mediaQuery: const MediaQueryData(size: Size(390, 844)),
        isWeb: true,
      ),
      isFalse,
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
}
