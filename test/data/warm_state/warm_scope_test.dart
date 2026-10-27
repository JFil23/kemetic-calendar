import 'package:mobile/features/pages/pages_arrangement.dart';
import 'package:mobile/data/flow_appearance.dart';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/data/account_view_cache.dart';
import 'package:mobile/data/warm_state/app_warm_state.dart';
import 'package:mobile/data/warm_state/warm_snapshot_store.dart';
import 'package:mobile/features/calendar/calendar_invalidation.dart';
import 'package:mobile/features/pages/pages_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/pages/pages_resource_test.dart' show uid, session;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'warm scope keeps the displayed detail and avoids whole-account fan-out',
    () async {
      SharedPreferences.setMockInitialValues({});
      await WarmSnapshotStore.instance.forgetAccount(uid);
      final cache = AccountViewCache.instance..enterAccount(uid);
      cache.evictPrefix(uid, '');
      cache.publish(uid, 'pages.flows', [
        const PagesFlow(
          id: '42',
          name: 'Displayed flow',
          appearance: FlowAppearance.empty,
        ),
      ]);
      final at = DateTime.now().add(const Duration(hours: 2));
      cache.publish(
        uid,
        'pages.events',
        PagesEventWindow([
          PagesUpcomingEvent(
            flowId: '42',
            title: 'Displayed occurrence',
            at: at,
          ),
        ], at.add(const Duration(days: 1))),
      );
      final requests = <http.Request>[];
      Map<String, Object?> flow(int id) => {
        'id': id,
        'user_id': uid,
        'name': 'Flow $id',
        'active': true,
        'visible_in_active_list': true,
        'rules': [],
      };
      final client = SupabaseClient(
        'https://example.supabase.co',
        'fixture',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((r) async {
          requests.add(r);
          final path = r.url.path.split('/').last;
          Object data = [];
          if (path == 'get_my_filed_flows_v1') {
            data = [for (var i = 42; i < 74; i++) flow(i)];
          }
          if (path == 'flows') data = flow(42);
          if (path == 'get_commons_together_home_cards' ||
              path == 'get_together_inbox') {
            data = {};
          }
          return http.Response(
            jsonEncode(data),
            200,
            headers: {'content-type': 'application/json'},
            request: r,
          );
        }),
      );
      await client.auth.recoverSession(session());
      final warm = AppWarmState(client)..start();
      addTearDown(() async {
        warm.dispose();
        await client.dispose();
        await WarmSnapshotStore.instance.forgetAccount(uid);
      });
      Future<void> settle() async {
        var stable = 0, last = -1;
        for (var i = 0; i < 200 && stable < 10; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          if (last == requests.length) {
            stable++;
          } else {
            stable = 0;
            last = requests.length;
          }
        }
      }

      await settle();
      final details = requests.where(
        (r) =>
            r.url.path.endsWith('/flows') &&
            r.url.queryParameters.containsKey('id'),
      );
      expect(details, hasLength(1));
      expect(details.single.url.queryParameters['id'], 'eq.42');
      expect(WarmSnapshotStore.instance.peek(uid, 'flow.events.42'), isNotNull);
      expect(
        requests.where((r) => r.url.path.endsWith('/get_my_filed_flows_v1')),
        hasLength(1),
      );
      expect(
        requests.where(
          (r) => r.url.path.endsWith('/get_commons_together_home_cards'),
        ),
        hasLength(1),
      );
      final feedReads = requests
          .where((r) => r.url.path.endsWith('/get_profile_feed_together_cards'))
          .length;
      final guidanceReads = requests
          .where((r) => r.url.path.endsWith('/maat_guidance_deliveries'))
          .length;
      CalendarInvalidationBus.instance.publish(
        const CalendarInvalidated(
          reason: CalendarInvalidationReason.flowStudioPersisted,
          flowId: 42,
        ),
      );
      await settle();
      expect(
        requests.where(
          (r) => r.url.path.endsWith('/get_profile_feed_together_cards'),
        ),
        hasLength(feedReads),
      );
      expect(
        requests.where((r) => r.url.path.endsWith('/maat_guidance_deliveries')),
        hasLength(guidanceReads),
      );
      expect(WarmSnapshotStore.instance.peek(uid, 'flow.events.42'), isNotNull);
    },
  );
}
