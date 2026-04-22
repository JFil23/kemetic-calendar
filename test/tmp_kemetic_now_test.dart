import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/widgets/kemetic_date_picker.dart';

void main() {
  test('print current kemetic date', () {
    final now = DateTime.now();
    final kNow = KemeticMath.fromGregorian(now);
    final sample = KemeticMath.fromGregorian(DateTime(2026, 4, 21));
    // ignore: avoid_print
    print('now=$now -> ${kNow.kYear}/${kNow.kMonth}/${kNow.kDay}');
    // ignore: avoid_print
    print('sample=2026-04-21 -> ${sample.kYear}/${sample.kMonth}/${sample.kDay}');
  });
}
