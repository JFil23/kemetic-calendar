import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/fixtures/follow_sky_observation_presentation_fixture.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/follow_sky_observation_presentation_model.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/follow_sky_view_time_policy.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  late tz.Location losAngeles;

  setUpAll(() {
    tzdata.initializeTimeZones();
    losAngeles = tz.getLocation('America/Los_Angeles');
  });

  DateTime instantAt(int day, int hour, [int minute = 0]) {
    return tz.TZDateTime(losAngeles, 2026, 8, day, hour, minute).toUtc();
  }

  DateTime viewTimeAt(int day, int hour, [int minute = 0]) {
    return followSkyWallTime(
      instantAt(day, hour, minute),
      losAngelesFullMoonPresentationFixture.ianaTimeZone,
    );
  }

  test('Los Angeles fixture locks its temporary observing authority', () {
    final fixture = losAngelesFullMoonPresentationFixture;

    expect(FollowSkyPresentationContext.losAngeles.place.latitude, 34.0522);
    expect(FollowSkyPresentationContext.losAngeles.place.longitude, -118.2437);
    expect(fixture.ianaTimeZone, 'America/Los_Angeles');
    expect(viewTimeAt(28, 1, 55), DateTime(2026, 8, 28, 1, 55));
  });

  test('initial view time uses live time only inside the resolved track', () {
    final fixture = losAngelesFullMoonPresentationFixture;
    final track = fixture.track;

    FollowSkyViewTimeController controller(DateTime now) =>
        FollowSkyViewTimeController(track: track, now: now);

    final before = controller(viewTimeAt(27, 18));
    expect(before.value, fixture.initialSelection);
    before.dispose();

    for (final live in <DateTime>[
      viewTimeAt(27, 20, 30),
      viewTimeAt(28, 1, 55),
      viewTimeAt(28, 6, 30),
    ]) {
      final active = controller(live);
      expect(active.value, live);
      active.dispose();
    }

    final after = controller(viewTimeAt(28, 7));
    expect(after.value, fixture.initialSelection);
    after.dispose();
  });

  test('track start and end are inclusive live boundaries', () {
    final fixture = losAngelesFullMoonPresentationFixture;
    final track = fixture.track;

    expect(
      isFollowSkyTrackLiveTime(now: track.trackStart, track: track),
      isTrue,
    );
    expect(isFollowSkyTrackLiveTime(now: track.trackEnd, track: track), isTrue);
  });
}
