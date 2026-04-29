import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/utils/local_end_date.dart';

void main() {
  test('flow stays active through its local end date', () {
    final endDate = DateTime(2026, 4, 28);

    expect(
      isActiveThroughLocalEndDate(endDate, now: DateTime(2026, 4, 28, 23, 59)),
      isTrue,
    );
  });

  test('flow expires on the next local day', () {
    final endDate = DateTime(2026, 4, 28);

    expect(
      isActiveThroughLocalEndDate(endDate, now: DateTime(2026, 4, 29, 0, 0, 1)),
      isFalse,
    );
    expect(
      isExpiredAfterLocalEndDate(endDate, now: DateTime(2026, 4, 29, 0, 0, 1)),
      isTrue,
    );
  });

  test('formats local date as yyyy-mm-dd', () {
    expect(localDateIso(DateTime(2026, 4, 28, 19, 47, 19)), '2026-04-28');
  });
}
