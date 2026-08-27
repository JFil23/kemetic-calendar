import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/follow_the_sky/presentation/fixtures/follow_sky_observation_presentation_fixture.dart';
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

    expect(fixture.latitudeDegrees, 34.0522);
    expect(fixture.longitudeDegrees, -118.2437);
    expect(fixture.ianaTimeZone, 'America/Los_Angeles');
    expect(viewTimeAt(28, 1, 55), DateTime(2026, 8, 28, 1, 55));
  });

  test('initial view time uses live time only from rise through set', () {
    final fixture = losAngelesFullMoonPresentationFixture;
    final rise = fixture.instrument.rise!;
    final set = fixture.instrument.set!;
    final peak = fixture.initialSelection;

    expect(
      initialFollowSkyViewTime(
        now: viewTimeAt(27, 18),
        rise: rise,
        set: set,
        peak: peak,
      ),
      peak,
    );
    expect(
      initialFollowSkyViewTime(
        now: viewTimeAt(27, 20, 30),
        rise: rise,
        set: set,
        peak: peak,
      ),
      DateTime(2026, 8, 27, 20, 30),
    );
    expect(
      initialFollowSkyViewTime(
        now: viewTimeAt(28, 1, 55),
        rise: rise,
        set: set,
        peak: peak,
      ),
      DateTime(2026, 8, 28, 1, 55),
    );
    expect(
      initialFollowSkyViewTime(
        now: viewTimeAt(28, 6, 30),
        rise: rise,
        set: set,
        peak: peak,
      ),
      DateTime(2026, 8, 28, 6, 30),
    );
    expect(
      initialFollowSkyViewTime(
        now: viewTimeAt(28, 7),
        rise: rise,
        set: set,
        peak: peak,
      ),
      peak,
    );
  });

  test('rise and set are inclusive live boundaries', () {
    final fixture = losAngelesFullMoonPresentationFixture;
    final rise = fixture.instrument.rise!;
    final set = fixture.instrument.set!;

    expect(isFollowSkyLiveTime(now: rise, rise: rise, set: set), isTrue);
    expect(isFollowSkyLiveTime(now: set, rise: rise, set: set), isTrue);
  });
}
