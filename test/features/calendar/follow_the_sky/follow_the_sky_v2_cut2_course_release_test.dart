import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('V11 does not import the V2 Course release presentation', () {
    final source = File(
      'lib/features/calendar/follow_the_sky/presentation/'
      'follow_sky_detail_page.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('course_release')));
    expect(source, isNot(contains('CourseRelease')));
    expect(source, contains('showFollowSkyTurningSheet'));
  });
}
