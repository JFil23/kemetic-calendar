import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/hydration/calendar_viewport_geometry.dart';

void main() {
  test('contains every month occupying visible pixels', () {
    final range = visibleKemeticMonthRange(
      viewportTop: 100,
      viewportBottom: 500,
      mountedMonths: const <CalendarMonthViewportBounds>[
        CalendarMonthViewportBounds(
          kYear: 2,
          kMonth: 4,
          top: -100,
          bottom: 100,
        ),
        CalendarMonthViewportBounds(kYear: 2, kMonth: 5, top: 80, bottom: 260),
        CalendarMonthViewportBounds(kYear: 2, kMonth: 6, top: 260, bottom: 440),
        CalendarMonthViewportBounds(kYear: 2, kMonth: 7, top: 440, bottom: 620),
      ],
    );

    expect(range?.firstKMonth, 5);
    expect(range?.lastKMonth, 7);
  });

  test('sorts correctly across a Kemetic year boundary', () {
    final range = visibleKemeticMonthRange(
      viewportTop: 0,
      viewportBottom: 400,
      mountedMonths: const <CalendarMonthViewportBounds>[
        CalendarMonthViewportBounds(kYear: 3, kMonth: 1, top: 200, bottom: 400),
        CalendarMonthViewportBounds(kYear: 2, kMonth: 13, top: 0, bottom: 200),
      ],
    );

    expect(range?.firstKYear, 2);
    expect(range?.firstKMonth, 13);
    expect(range?.lastKYear, 3);
    expect(range?.lastKMonth, 1);
  });

  test('edge-only contact does not expand the requested range', () {
    final range = visibleKemeticMonthRange(
      viewportTop: 100,
      viewportBottom: 300,
      mountedMonths: const <CalendarMonthViewportBounds>[
        CalendarMonthViewportBounds(kYear: 2, kMonth: 4, top: 0, bottom: 100),
        CalendarMonthViewportBounds(kYear: 2, kMonth: 5, top: 100, bottom: 300),
        CalendarMonthViewportBounds(kYear: 2, kMonth: 6, top: 300, bottom: 500),
      ],
    );

    expect(range?.firstKMonth, 5);
    expect(range?.lastKMonth, 5);
  });
}
