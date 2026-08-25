import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('V11 does not import the V2 Course/Connect presentation', () {
    final source = File(
      'lib/features/calendar/follow_the_sky/presentation/'
      'follow_sky_detail_page.dart',
    ).readAsStringSync();

    expect(source, isNot(contains("import 'course_picker.dart'")));
    expect(source, isNot(contains('FollowSkyCoursePicker')));
    expect(source, contains('FollowSkyTurningExample'));
  });
}
