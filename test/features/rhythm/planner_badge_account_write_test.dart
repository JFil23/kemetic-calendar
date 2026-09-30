import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/data/nutrition_repo.dart';
import 'package:mobile/features/rhythm/data/planner_badge_repo.dart';
import 'package:mobile/features/rhythm/models/rhythm_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../pages/pages_resource_test.dart' show session, uid;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'nutrition checkmarks use one account-fenced transaction and propagate failure',
    () async {
      final requests = <http.Request>[];
      var fail = false;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((r) async {
          requests.add(r);
          return http.Response(
            fail ? '{"code":"42501","message":"denied"}' : 'null',
            fail ? 403 : 200,
            headers: {'content-type': 'application/json'},
            request: r,
          );
        }),
      );
      await client.auth.recoverSession(session());
      final repo = PlannerBadgeRepo(client);
      final item = NutritionItem(
        id: '10000000-0000-4000-8000-000000000001',
        nutrient: 'Fixture',
        source: 'Source',
        purpose: 'Purpose',
        schedule: const IntakeSchedule(
          mode: IntakeMode.decan,
          decanDays: {1},
          repeat: true,
          time: TimeOfDay(hour: 9, minute: 0),
        ),
      );
      await repo.syncNutritionState(
        item: item,
        date: DateTime(2026, 9, 29),
        state: RhythmItemState.done,
      );
      expect(requests.length, 1);
      expect(
        requests.single.url.path,
        endsWith('/rpc/sync_planner_nutrition_state_v1'),
      );
      expect(jsonDecode(requests.single.body)['p_account_id'], uid);
      fail = true;
      await expectLater(
        repo.syncNutritionState(
          item: item,
          date: DateTime(2026, 9, 29),
          state: RhythmItemState.pending,
        ),
        throwsA(isA<PostgrestException>()),
      );
      await client.dispose();
    },
  );
}
