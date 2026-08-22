import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/track_sky_flow.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    clearTrackSkyFlowDataCacheForTest();
  });

  test('V2-backed load returns materializable catalog events', () async {
    // Ensure asset path resolves from package root during tests.
    final catalogFile = File('assets/follow_the_sky/sky_catalog_v2.json');
    expect(catalogFile.existsSync(), isTrue);

    final data = await loadTrackSkyFlowData(TrackSkyTimeZone.pacific);
    expect(data.events, isNotEmpty);
    expect(data.events.first.skyEventId, isNotNull);
    expect(
      data.events.any((e) => e.title == 'Full Moon' || e.title.contains('Equinox')),
      isTrue,
    );
  });

  test('upcoming filter excludes past events', () async {
    final data = await loadTrackSkyFlowData(TrackSkyTimeZone.eastern);
    final upcoming = upcomingTrackSkyEvents(
      data,
      now: DateTime.utc(2026, 9, 1),
    );
    expect(upcoming, isNotEmpty);
    for (final e in upcoming) {
      expect(
        trackSkyEventEndLocal(e, TrackSkyTimeZone.eastern)
            .isBefore(DateTime.utc(2026, 9, 1)),
        isFalse,
      );
    }
  });

  test('no markdown assets remain for track sky', () {
    expect(File('assets/ma_at_flows/track_sky_pacific.md').existsSync(), isFalse);
    expect(
      File('lib/features/calendar/track_sky_flow_data.g.dart').existsSync(),
      isFalse,
    );
  });
}
