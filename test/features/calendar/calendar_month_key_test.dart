import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart';

void main() {
  test('keyForMonth returns a stable key for the same month', () {
    final first = keyForMonth(2, 2);
    final second = keyForMonth(2, 2);
    final different = keyForMonth(2, 3);

    expect(first, same(second));
    expect(first, isA<GlobalKey>());
    expect(different, isNot(same(first)));
  });
}
