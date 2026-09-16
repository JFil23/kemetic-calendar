import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/follow_sky_calendar_preview.dart';

void main() {
  test('omitted preview is unavailable, not a loaded empty day', () {
    expect(
      FollowSkyCalendarPreview.unavailable.dateState(DateTime(2026, 8, 1)),
      MaatFlowDateCalendarState.unavailable,
    );
    expect(
      FollowSkyCalendarPreview.empty.dateState(DateTime(2026, 8, 1)),
      MaatFlowDateCalendarState.loadedEmpty,
    );
  });

  test('coverage complete does not apply to dates outside the window', () {
    final preview = FollowSkyCalendarPreview(
      windowStart: DateTime(2026, 9, 13),
      windowEnd: DateTime(2026, 10, 10),
      coverageComplete: true,
      supply: CalendarPreviewSupply.loaded,
    );
    expect(
      preview.dateState(DateTime(2026, 8, 20)),
      MaatFlowDateCalendarState.outOfWindow,
    );
    expect(
      preview.dateState(DateTime(2026, 9, 13)),
      MaatFlowDateCalendarState.loadedEmpty,
    );
    expect(
      maatFlowDateCalendarLabel(MaatFlowDateCalendarState.outOfWindow),
      isNot(maatFlowDateCalendarLabel(MaatFlowDateCalendarState.loadedEmpty)),
    );
  });

  test('incomplete coverage inside the window stays loading', () {
    const preview = FollowSkyCalendarPreview(
      windowStart: null,
      coverageComplete: false,
      supply: CalendarPreviewSupply.loading,
    );
    expect(
      preview.dateState(DateTime(2026, 9, 13)),
      MaatFlowDateCalendarState.loading,
    );
  });
}
