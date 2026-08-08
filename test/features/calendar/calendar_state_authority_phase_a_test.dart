import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Behavior-preserving guards for calendar state-authority work.
///
/// Grows with each independently revertable commit. Phase 0 is the harness;
/// later commits add their control-point assertions.
void main() {
  late String calendarPageSource;

  setUpAll(() async {
    calendarPageSource = await File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsString();
  });

  test('Phase 0 baseline encoder exists for CI capture', () {
    expect(
      calendarPageSource,
      contains('debugCanonicalHydrationBaselineJson'),
    );
    expect(calendarPageSource, contains("copy.remove('resolvedColor')"));
    expect(
      File('test/features/calendar/fixtures/hydration_baseline.json').existsSync(),
      isTrue,
    );
  });
}
