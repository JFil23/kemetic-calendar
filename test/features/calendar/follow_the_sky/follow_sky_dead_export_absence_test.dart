import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Follow Sky V2 flags and cut-freeze exports are absent', () {
    expect(
      File(
        'lib/features/calendar/follow_the_sky/follow_sky_v2_flags.dart',
      ).existsSync(),
      isFalse,
    );
    expect(
      File(
        'lib/features/calendar/follow_the_sky/follow_sky_cut_freeze.dart',
      ).existsSync(),
      isFalse,
    );

    final barrel = File(
      'lib/features/calendar/follow_the_sky/follow_the_sky.dart',
    ).readAsStringSync();
    expect(barrel, isNot(contains('follow_sky_v2_flags.dart')));
    expect(barrel, isNot(contains('follow_sky_cut_freeze.dart')));
    expect(barrel, isNot(contains('FollowSkyV2Flags')));
    expect(barrel, isNot(contains('FollowSkyCutFreeze')));
  });
}
