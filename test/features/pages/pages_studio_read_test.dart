import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/data/account_view_cache.dart';
import 'package:mobile/data/flow_appearance.dart';
import 'package:mobile/data/pages_studio_read_repository.dart';
import 'package:mobile/features/pages/pages_arrangement.dart';
import 'package:mobile/features/pages/pages_models.dart';
import 'pages_resource_test.dart' show session;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'selected instrument reads are bounded and never ensure, mark read, or write',
    () async {
      SharedPreferences.setMockInitialValues({
        'offering_table_1_day_12_day_view_v1': jsonEncode({
          'words': {'offering': 'Actual saved intention'},
        }),
      });
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'fixture',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((r) async {
          requests.add(r);
          return http.Response(
            r.url.path.endsWith('reading_house_room_summaries')
                ? jsonEncode({
                    'calendar_id': 'calendar',
                    'flow_id': 1,
                    'members': [],
                    'member_count': 1,
                    'active': true,
                  })
                : r.url.path.endsWith('kar_shrines')
                ? 'null'
                : '[]',
            200,
            headers: {'content-type': 'application/json'},
            request: r,
          );
        }),
      );
      await client.auth.recoverSession(session());
      final event = PagesUpcomingEvent(
        id: 'filing',
        clientEventId: 'occurrence',
        calendarId: 'calendar',
        flowId: '1',
        title: 'Day 12: scheduled',
        at: DateTime(2026, 9, 28),
        behavior: const {'day': 12},
      );
      final before = (await SharedPreferences.getInstance()).getKeys();
      for (final key in [
        null,
        'the-offering-table',
        'the-kar',
        'the-reading-house',
      ]) {
        final flow = PagesFlow(
          id: '1',
          name: 'Scheduled flow',
          appearance: FlowAppearance.empty,
          maatKey: key,
        );
        final result = await readPagesStudioSnapshot(
          client,
          flow,
          event,
          () => true,
        );
        expect(result.identity, pagesStudioIdentity(flow, event));
        if (key == 'the-offering-table') {
          expect(
            result.offeringStates[12]!.words['offering'],
            'Actual saved intention',
          );
        }
      }
      expect(requests.map((r) => r.method), everyElement('GET'));
      expect(requests.map((r) => r.url.pathSegments.last), [
        'kar_shrines',
        'reading_house_room_summaries',
        'reading_house_chat_messages',
      ]);
      expect(requests.last.url.queryParameters['limit'], '50');
      expect((await SharedPreferences.getInstance()).getKeys(), before);
      final count = requests.length;
      await expectLater(
        readPagesStudioSnapshot(
          client,
          const PagesFlow(
            id: '1',
            name: 'Hidden',
            appearance: FlowAppearance.empty,
          ),
          event,
          () => false,
        ),
        throwsA(isA<ViewReadCancelled>()),
      );
      expect(requests.length, count);
      await client.dispose();
    },
  );
}
