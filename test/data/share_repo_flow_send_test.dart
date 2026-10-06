import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/data/share_models.dart';
import 'package:mobile/data/share_repo.dart';
import 'package:mobile/data/warm_state/warm_snapshot_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/pages/pages_resource_test.dart' show session, uid;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final failLaterPage in [false, true]) {
    test(
      'fallback flow send preserves complete civil snapshot; page failure=$failLaterPage',
      () async {
        SharedPreferences.setMockInitialValues({});
        await WarmSnapshotStore.instance.forgetAccount(uid);
        final pages = <int>[];
        final shares = <Map<String, dynamic>>[];
        final client = SupabaseClient(
          'https://example.supabase.co',
          'key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((request) async {
            Object? body;
            var status = 200;
            switch (request.url.path) {
              case '/functions/v1/create_flow_share':
                status = 404;
                body = {'error': 'Function unavailable'};
              case '/functions/v1/send_push':
                body = {'ok': true};
              case '/rest/v1/flows':
                body = {
                  'id': 987,
                  'user_id': uid,
                  'name': 'My practice',
                  'start_date': '2026-03-06',
                  'end_date': '2026-03-10',
                  'rules': [],
                  'appearance': {'version': 1, 'accent_argb': 0xff6f93a8},
                };
              case '/rest/v1/user_event_filing_items_client':
                final offset = int.parse(
                  request.url.queryParameters['offset'] ?? '0',
                );
                pages.add(offset);
                if (failLaterPage && offset > 0) {
                  status = 503;
                  body = {'message': 'page unavailable'};
                } else {
                  body = List.generate(
                    offset == 0 ? 500 : 1,
                    (i) => {
                      'id': 'event-${offset + i}',
                      'user_id': uid,
                      'filed_flow_id': 987,
                      'title': 'Practice',
                      'starts_at': offset == 0
                          ? '2026-03-07T17:00:00Z'
                          : '2026-03-08T16:00:00Z',
                      'ends_at': offset == 0
                          ? '2026-03-07T18:00:00Z'
                          : '2026-03-09T08:00:00Z',
                      'all_day': false,
                      'item_kind': 'flow',
                      'lifecycle': 'active',
                      'action_id': 'reflect',
                      'behavior_payload': {'prompt': 'Begin'},
                    },
                  );
                }
              case '/rest/v1/profiles':
                body = {'id': 'recipient', 'display_name': 'Sender'};
              case '/rest/v1/flow_shares':
                shares.add(Map<String, dynamic>.from(jsonDecode(request.body)));
                body = {
                  'id': 'share-1',
                  'status': 'sent',
                  'recipient_id': 'recipient',
                };
              default:
                throw StateError('Unexpected request ${request.url}');
            }
            return http.Response(
              jsonEncode(body),
              status,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }),
        );
        addTearDown(client.dispose);
        await client.auth.recoverSession(session());
        final result = await ShareRepo(client).shareFlow(
          flowId: 987,
          recipients: [
            ShareRecipient(type: ShareRecipientType.user, value: 'recipient'),
          ],
        );
        expect(pages, [0, 500]);
        if (failLaterPage) {
          expect(shares, isEmpty);
          expect(result.single.error, isNotNull);
        } else {
          expect(result.single.error, isNull);
          expect(shares, hasLength(1));
          final payload = shares.single['payload_json'] as Map;
          expect(payload['start_date'], '2026-03-06');
          expect(payload['appearance'], {
            'version': 1,
            'accent_argb': 0xff6f93a8,
          });
          final events = payload['events'] as List;
          expect(events, hasLength(501));
          expect(events.first['offset_days'], 1);
          expect(events.last['offset_days'], 2);
          expect(events.first['start_time'], '09:00');
          expect(events.last['start_time'], '09:00');
          expect(events.last['end_time'], '01:00');
          expect(events.last['end_offset_days'], 1);
          expect(events.last['behavior_payload'], {'prompt': 'Begin'});
        }
      },
    );
  }
}
