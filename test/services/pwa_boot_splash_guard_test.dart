import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pre-Flutter splash uses the bundled wordmark font and shimmer', () {
    final source = File('web/index.html').readAsStringSync();

    expect(source, contains("font-family: 'KemeticBootGentium'"));
    expect(source, contains('assets/ios/Runner/Fonts/GentiumPlus-Regular.ttf'));
    expect(source, contains('rel="preload"'));
    expect(source, contains('@keyframes pwaBootShimmer'));
    expect(
      source,
      contains('animation: pwaBootShimmer 2600ms linear infinite'),
    );
    expect(source, contains('data-launch-word'));
  });
}
