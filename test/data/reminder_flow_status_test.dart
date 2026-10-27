import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/data/flows_repo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const reminder = '33333333-3333-4333-8333-333333333333';
  test(
    'one confirmed UUID read retains paused Flow identity and lifecycle',
    () async {
      final requests = <Uri>[];
      final pausedAt = DateTime.utc(2026, 10, 27, 15);
      final client = SupabaseClient(
        'https://example.supabase.co',
        'fixture-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          requests.add(request.url);
          expect(request.url.path, '/rest/v1/flows');
          expect(request.url.queryParameters['reminder_uuid'], 'eq.$reminder');
          expect(request.url.queryParameters['select'], 'id,active,paused_at');
          return http.Response(
            jsonEncode([
              {
                'id': 8100,
                'active': true,
                'paused_at': pausedAt.toIso8601String(),
              },
            ]),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final repo = FlowsRepo(client);
      final status = await repo.getFlowStatusByReminderUuid(reminder);
      expect(status, (id: 8100, active: true, pausedAt: pausedAt));
      expect(requests, hasLength(1));
      expect(await repo.getFlowIdByReminderUuid(reminder), 8100);
      expect(requests, hasLength(2));
      expect(await repo.getFlowStatusByReminderUuid('not-a-uuid'), isNull);
      expect(requests, hasLength(2));
    },
  );

  test(
    'missing or malformed pause status fails closed instead of enabling scheduling',
    () async {
      for (final row in [
        {'id': 8100},
        {'id': 8100, 'active': true},
        {'id': 8100, 'active': true, 'paused_at': 'unresolved'},
      ]) {
        final client = SupabaseClient(
          'https://example.supabase.co',
          'fixture-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient(
            (request) async => http.Response(
              jsonEncode([row]),
              200,
              request: request,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );
        addTearDown(client.dispose);
        await expectLater(
          FlowsRepo(client).getFlowStatusByReminderUuid(reminder),
          throwsStateError,
        );
      }
    },
  );
}
