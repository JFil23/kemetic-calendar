import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/external_calendar_repository.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
    );
  });

  test('build lane is explicit and has no production fallback', () {
    const environment = String.fromEnvironment('APP_ENV');
    expect(externalCalendarBuildLane, switch (environment) {
      'staging' => 'staging',
      'prod' => 'production',
      _ => null,
    });
  });

  for (final lane in <String?>['staging', 'production', null, 'unknown']) {
    test(
      'calendar and search restore only the current external lane: $lane',
      () {
        final payload = <String, dynamic>{
          'id': 'projection-id',
          'clientEventId': 'external:projection-id',
          'title': 'Train 8:00 PM',
          'allDay': true,
          'flowId': -1,
          if (lane != null) 'externalCalendarLane': lane,
        };
        final currentLane = externalCalendarBuildLane;
        final permitted = currentLane != null && currentLane == lane;
        final state = CalendarPageState();
        final calendar = state.debugWarmStartNoteRoundTripForTesting(payload);
        final search = CalendarPage.debugWarmStartSearchNoteForTesting(payload);
        if (permitted) {
          expect(calendar?['clientEventId'], 'external:projection-id');
          expect(calendar?['title'], 'Train 8:00 PM');
          expect(calendar?['externalCalendarLane'], currentLane);
          expect(search?.clientEventId, 'external:projection-id');
          expect(search?.title, 'Train 8:00 PM');
        } else {
          expect(calendar, isNull);
          expect(search, isNull);
        }
      },
    );
  }

  test(
    'old authored and legacy native rows retain their unchanged payloads',
    () {
      final state = CalendarPageState();
      for (final clientEventId in ['authored-note', 'native:legacy-copy']) {
        final payload = <String, dynamic>{
          'id': 'old-row-id',
          'clientEventId': clientEventId,
          'title': 'Existing calendar row',
          'detail': 'Original description',
          'allDay': true,
          'flowId': -1,
        };
        final calendar = state.debugWarmStartNoteRoundTripForTesting(payload);
        final search = CalendarPage.debugWarmStartSearchNoteForTesting(payload);
        expect(calendar?['clientEventId'], clientEventId);
        expect(calendar?['detail'], 'Original description');
        expect(calendar!.containsKey('externalCalendarLane'), isFalse);
        expect(search?.clientEventId, clientEventId);
        expect(search?.title, 'Existing calendar row');
      }
    },
  );
}
