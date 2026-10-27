import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/data/flow_post_model.dart';
import 'package:mobile/data/flow_share_snapshot.dart';
import 'package:mobile/data/profile_repo.dart';
import 'package:mobile/data/share_models.dart';
import 'package:mobile/data/share_repo.dart';
import 'package:mobile/data/warm_state/warm_snapshot_store.dart';
import 'package:mobile/features/ask_haw/ask_haw_flow_contract.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/pages/pages_resource_test.dart' show session, uid;

const _futureContract = <String, dynamic>{
  'version': 99,
  'guidance': 'Future authored guidance.',
  'adaptations': ['future-adaptation'],
  'authorExtension': {
    'purpose': 'Preserve the author\'s exact optional contract.',
    'values': [1, true, null, 'unchanged'],
  },
  'steps': [
    {
      'id': 'prepare',
      'unknownFutureField': {'keep': true},
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'typed share and Inbox retain future optional metadata without enabling it',
    () {
      final snapshot = <String, dynamic>{
        'name': 'Authored practice',
        'rules': [],
        'assistance': _futureContract,
        'events': [
          {'offset_days': 0, 'title': 'Prepare', 'all_day': true},
        ],
      };
      final payload = FlowSharePayload.fromJson(snapshot);
      expect(payload.assistance, _futureContract);
      expect(payload.toJson()['assistance'], _futureContract);
      expect(AskHawFlowContract.tryFromJson(payload.assistance), isNull);
      expect(payload.events.single.title, 'Prepare');
      final inbox = InboxShareItem.fromJson({
        'share_id': 'assistance-share',
        'kind': 'flow',
        'recipient_id': uid,
        'sender_id': 'sender',
        'payload_id': 'payload',
        'title': 'Authored practice',
        'created_at': '2026-10-27T00:00:00Z',
        'payload_json': snapshot,
      });
      expect(inbox.flowPayload!.assistance, _futureContract);
    },
  );

  test(
    'old or malformed optional metadata leaves the underlying Flow readable',
    () {
      for (final raw in [
        null,
        'not a contract',
        5,
        [1, 2],
      ]) {
        final payload = FlowSharePayload.fromJson({
          'name': 'Old practice',
          'rules': [],
          'events': [],
          'assistance': raw,
        });
        expect(payload.name, 'Old practice');
        expect(payload.assistance, isNull);
        expect(payload.toJson().containsKey('assistance'), isFalse);
      }
      final original = <String, dynamic>{
        'version': 99,
        'nested': {'value': 'original'},
      };
      final copy = copyFlowAssistance(original)!;
      (original['nested'] as Map)['value'] = 'changed after snapshot';
      expect(copy['nested'], {'value': 'original'});
    },
  );

  test(
    'posted snapshot cache and appearance edits retain authored contract',
    () {
      final post = FlowPost.fromJson({
        'id': 'authored-post',
        'user_id': uid,
        'flow_id': 718639,
        'name': 'Authored practice',
        'rules': [],
        'created_at': '2026-10-27T00:00:00Z',
        'ai_metadata': {
          'payload': {'assistance': _futureContract, 'events': []},
        },
      });
      final restored = FlowPost.fromJson(
        jsonDecode(jsonEncode(post.toJson())) as Map<String, dynamic>,
      );
      expect(restored.payloadJson!['assistance'], _futureContract);
      expect(
        restored.withAppearance({
          'version': 1,
          'accent_argb': 123,
        }).payloadJson!['assistance'],
        _futureContract,
      );
    },
  );

  test(
    'direct share, publish and saved import carry the exact authored map',
    () async {
      SharedPreferences.setMockInitialValues({});
      await WarmSnapshotStore.instance.forgetAccount(uid);
      final writes = <String, List<Map<String, dynamic>>>{};
      final source = <String, dynamic>{
        'id': 718639,
        'user_id': uid,
        'name': 'Authored practice',
        'color': 0x6f93a8,
        'active': true,
        'is_saved': false,
        'rules': [],
        'assistance': _futureContract,
        'start_date': '2026-10-27',
        'end_date': '2026-11-05',
      };
      final client = SupabaseClient(
        'https://example.supabase.co',
        'fixture-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          Object? data;
          var status = 200;
          final table = request.url.path.split('/').last;
          if (table == 'create_flow_share') {
            status = 404;
            data = {'error': 'Function unavailable'};
          } else if (table == 'send_push') {
            data = {'ok': true};
          } else if (table == 'flows' && request.method == 'GET') {
            data = request.url.queryParameters['id'] == 'eq.718639'
                ? source
                : [];
          } else if (table == 'profiles') {
            data = {'id': 'recipient', 'display_name': 'Recipient'};
          } else if (table == 'user_event_filing_items_client' ||
              (table == 'flow_saves' && request.method == 'GET')) {
            data = [];
          } else if (request.method == 'POST' || request.method == 'PATCH') {
            final payload = Map<String, dynamic>.from(
              jsonDecode(request.body) as Map,
            );
            writes.putIfAbsent(table, () => []).add(payload);
            data = switch (table) {
              'flow_shares' => {
                'id': 'share-authored',
                'status': 'sent',
                'recipient_id': 'recipient',
              },
              'flow_posts' => {
                ...payload,
                'id': 'post-authored',
                'created_at': '2026-10-27T00:00:00Z',
              },
              'flows' => {'id': 718640},
              'flow_saves' => [payload],
              _ => [],
            };
          } else {
            throw StateError(
              'Unexpected request ${request.method} ${request.url}',
            );
          }
          return http.Response(
            jsonEncode(data),
            status,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      await client.auth.recoverSession(session());
      final sent = await ShareRepo(client).shareFlow(
        flowId: 718639,
        recipients: [
          ShareRecipient(type: ShareRecipientType.user, value: 'recipient'),
        ],
      );
      expect(sent.single.error, isNull);
      expect(
        (writes['flow_shares']!.single['payload_json'] as Map)['assistance'],
        _futureContract,
      );
      final published = await ProfileRepo(client).postFlow(718639);
      expect(published, isNotNull);
      expect(published!.payloadJson!['assistance'], _futureContract);
      final metadata = writes['flow_posts']!.single['ai_metadata'] as Map;
      expect(metadata['payload']['assistance'], _futureContract);
      final imported = await ProfileRepo(
        client,
      ).saveFlowPostToMyFlows(published);
      expect(imported, 718640);
      final created = writes['flows']!.firstWhere(
        (row) => row.containsKey('name'),
      );
      expect(created['assistance'], _futureContract);
      expect(created['origin_type'], 'profile_import');
      expect(created['active'], isFalse);
      expect(created['is_saved'], isFalse);
      expect(AskHawFlowContract.tryFromJson(created['assistance']), isNull);
    },
  );
}
