import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_banner_resolver.dart';
import 'package:mobile/features/calendar/calendar_geometry_snapshot.dart';
import 'package:mobile/features/calendar/calendar_section_index.dart';

void main() {
  final resolver = CalendarBannerResolver(deadband: 8);
  final month12 = MonthRef(year: 4, month: 12);
  final heriu = MonthRef(year: 4, month: 13);
  final thoth = MonthRef(year: 5, month: 1);
  final snapshot = CalendarGeometrySnapshot(
    generation: 1,
    sections: [
      _geometry(month12, 0, 100, finalDayBlockLeading: 70),
      _geometry(heriu, 100, 130, finalDayBlockLeading: 115),
      _geometry(thoth, 130, 230, finalDayBlockLeading: 200),
    ],
  );

  test('initial selection hands off at the outgoing final day block', () {
    expect(
      resolver.resolve(
        snapshot: snapshot,
        activationCoordinate: 70,
        mode: CalendarBannerResolutionMode.initial,
      ),
      heriu,
    );
  });

  test('following-month extent owns its leading divider and season header', () {
    expect(snapshot.ownerAt(100), heriu);
    expect(snapshot.ownerAt(130), thoth);
  });

  test('forward deadband holds the incumbent near one boundary', () {
    expect(
      resolver.resolve(
        snapshot: snapshot,
        activationCoordinate: 77.999,
        incumbent: month12,
        mode: CalendarBannerResolutionMode.scrollingTowardFuture,
      ),
      month12,
    );
    expect(
      resolver.resolve(
        snapshot: snapshot,
        activationCoordinate: 78,
        incumbent: month12,
        mode: CalendarBannerResolutionMode.scrollingTowardFuture,
      ),
      heriu,
    );
  });

  test('reverse deadband holds the incumbent near the opposite boundary', () {
    expect(
      resolver.resolve(
        snapshot: snapshot,
        activationCoordinate: 62.001,
        incumbent: heriu,
        mode: CalendarBannerResolutionMode.scrollingTowardPast,
      ),
      heriu,
    );
    expect(
      resolver.resolve(
        snapshot: snapshot,
        activationCoordinate: 62,
        incumbent: heriu,
        mode: CalendarBannerResolutionMode.scrollingTowardPast,
      ),
      month12,
    );
  });

  test('multi-section jumps do not retain a stale incumbent', () {
    expect(
      resolver.resolve(
        snapshot: snapshot,
        activationCoordinate: 180,
        incumbent: month12,
        mode: CalendarBannerResolutionMode.scrollingTowardFuture,
      ),
      thoth,
    );
  });

  test('geometry-only generation keeps a mounted stationary incumbent', () {
    final resized = CalendarGeometrySnapshot(
      generation: 2,
      sections: [
        _geometry(month12, 0, 95, finalDayBlockLeading: 65),
        _geometry(heriu, 95, 125, finalDayBlockLeading: 110),
        _geometry(thoth, 125, 225, finalDayBlockLeading: 195),
      ],
    );

    expect(resized.ownerAt(100), heriu);
    expect(
      resolver.resolve(
        snapshot: resized,
        activationCoordinate: 100,
        incumbent: month12,
        mode: CalendarBannerResolutionMode.geometryOnlyAtUnchangedOffset,
      ),
      month12,
    );
  });

  test('geometry-only generation falls back when incumbent is unmounted', () {
    final partial = CalendarGeometrySnapshot(
      generation: 2,
      sections: [_geometry(heriu, 95, 125)],
    );

    expect(
      resolver.resolve(
        snapshot: partial,
        activationCoordinate: 100,
        incumbent: month12,
        mode: CalendarBannerResolutionMode.geometryOnlyAtUnchangedOffset,
      ),
      heriu,
    );
  });

  test('one resolver handles live and settled samples identically', () {
    final live = resolver.resolve(
      snapshot: snapshot,
      activationCoordinate: 112,
      incumbent: month12,
      mode: CalendarBannerResolutionMode.scrollingTowardFuture,
    );
    final settled = resolver.resolve(
      snapshot: snapshot,
      activationCoordinate: 112,
      incumbent: month12,
      mode: CalendarBannerResolutionMode.scrollingTowardFuture,
    );

    expect(live, heriu);
    expect(settled, live);
  });

  test('rejects invalid deadband values', () {
    expect(() => CalendarBannerResolver(deadband: -1), throwsRangeError);
    expect(
      () => CalendarBannerResolver(deadband: double.nan),
      throwsRangeError,
    );
  });
}

CalendarSectionGeometry _geometry(
  MonthRef month,
  num leading,
  num trailing, {
  num? finalDayBlockLeading,
}) {
  return CalendarSectionGeometry(
    month: month,
    extent: CalendarCanonicalExtent(
      leading: leading.toDouble(),
      trailing: trailing.toDouble(),
    ),
    finalDayBlockLeading: finalDayBlockLeading?.toDouble(),
  );
}
