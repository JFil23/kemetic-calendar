import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/data/flows_repo.dart';
import 'package:mobile/features/calendar/calendar_hydration_diagnostics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _userId = '27d63169-a28a-4550-a0a0-8fee0e8e7b95';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('FlowRow.fromRow', () {
    test('parses filing view fields for My Flows hydration', () {
      final row = FlowRow.fromRow({
        'id': 42,
        'user_id': 'user-1',
        'calendar_id': 'calendar-1',
        'name': 'Follow the sky',
        'color': 0x12F0A1,
        'active': true,
        'is_saved': true,
        'start_date': '2026-05-01T00:00:00Z',
        'end_date': '2027-03-20T00:00:00Z',
        'notes': 'source=filing',
        'rules': [
          {
            'type': 'gregorian',
            'months': [5],
            'days': [1],
            'allDay': true,
          },
        ],
        'is_hidden': false,
        'is_reminder': false,
        'reminder_uuid': null,
        'share_id': '2bfaf9f3-c605-4a3e-8d47-fb6ce7b1703f',
        'saved_at': '2026-05-04T12:00:00Z',
        'lifecycle': 'active',
        'visible_in_active_list': true,
        'visible_in_saved_list': true,
        'total_event_count': 12,
        'remaining_event_count': 8,
        'remaining_live_event_count': 7,
        'ai_metadata': {'source': 'test'},
      });

      expect(row.id, 42);
      expect(row.shareId, '2bfaf9f3-c605-4a3e-8d47-fb6ce7b1703f');
      expect(row.filingLifecycle, 'active');
      expect(row.visibleInActiveList, isTrue);
      expect(row.visibleInSavedList, isTrue);
      expect(row.totalEventCount, 12);
      expect(row.remainingEventCount, 8);
      expect(row.remainingLiveEventCount, 7);
      expect(row.rules, hasLength(1));
      expect(row.aiMetadata, {'source': 'test'});
    });

    test(
      'uses lifecycle fallback for older rows without filing visibility',
      () {
        final row = FlowRow.fromRow({
          'id': 9,
          'user_id': 'user-1',
          'name': 'Legacy flow',
          'color': null,
          'active': true,
          'is_saved': false,
          'start_date': null,
          'end_date': null,
          'notes': null,
          'rules': null,
          'lifecycle': 'active',
        });

        expect(row.visibleInActiveList, isTrue);
        expect(row.visibleInSavedList, isFalse);
        expect(row.totalEventCount, 0);
        expect(row.remainingLiveEventCount, 0);
      },
    );
  });

  group('FlowFilingCounts', () {
    test('counts visible active flows and their live remaining events', () {
      FlowRow row({
        required int id,
        required bool active,
        required int remaining,
      }) {
        return FlowRow.fromRow({
          'id': id,
          'user_id': 'user-1',
          'name': 'Flow $id',
          'active': true,
          'is_saved': false,
          'start_date': null,
          'end_date': null,
          'notes': null,
          'rules': const [],
          'visible_in_active_list': active,
          'remaining_live_event_count': remaining,
        });
      }

      final counts = FlowFilingCounts.fromRows([
        row(id: 1, active: true, remaining: 7),
        row(id: 2, active: false, remaining: 20),
        row(id: 3, active: true, remaining: 4),
      ]);

      expect(counts.activeFlows, 2);
      expect(counts.flowEvents, 11);
    });
  });

  group('flow ledger hydration', () {
    test('uses filing view counts without the activity RPC', () {
      final source = File('lib/data/flows_repo.dart').readAsStringSync();
      final match = RegExp(
        r'Future<FlowLedger<FlowRow>> loadMyFlowLedger\(\) async \{([\s\S]*?)\n  \}',
      ).firstMatch(source);

      expect(match, isNotNull);
      final body = match!.group(1)!;
      expect(body, contains('_eventCountsFromFlowRows(flows)'));
      expect(body, isNot(contains('_loadMyEventCounts')));
      expect(body, isNot(contains("rpc('get_my_flow_activity')")));
    });
  });

  group('activity hydration outcomes', () {
    test('reports successful empty activity distinctly', () async {
      final client = SupabaseClient(
        'https://example.supabase.test',
        'test-anon-key',
        httpClient: _ActivityClient(fail: false),
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      try {
        await client.auth.recoverSession(_sessionJson());
        final result = await FlowsRepo(
          client,
        ).loadMyFlowEventCounts(flowIds: const <int>[1]);

        expect(result.status, HydrationFetchStatus.successfulEmpty);
        expect(result.value.total, isEmpty);
        expect(result.value.remaining, isEmpty);
      } finally {
        client.dispose();
      }
    });

    test('reports failed activity instead of successful empty', () async {
      final httpClient = _ActivityClient(fail: true);
      final client = SupabaseClient(
        'https://example.supabase.test',
        'test-anon-key',
        httpClient: httpClient,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      try {
        await client.auth.recoverSession(_sessionJson());
        final result = await FlowsRepo(
          client,
        ).loadMyFlowEventCounts(flowIds: const <int>[1]);

        expect(result.status, HydrationFetchStatus.failed);
        expect(result.value.total, isEmpty);
        expect(result.value.remaining, isEmpty);
        expect(
          httpClient.requestCount,
          1,
          reason: 'an activity timeout must not expand the event filing view',
        );
      } finally {
        client.dispose();
      }
    });

    test('reports unauthenticated activity without a request', () async {
      final httpClient = _ActivityClient(fail: false);
      final client = SupabaseClient(
        'https://example.supabase.test',
        'test-anon-key',
        httpClient: httpClient,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      try {
        final result = await FlowsRepo(
          client,
        ).loadMyFlowEventCounts(flowIds: const <int>[1]);

        expect(result.status, HydrationFetchStatus.unauthenticated);
        expect(httpClient.requestCount, 0);
      } finally {
        client.dispose();
      }
    });

    test('activity failure has no event-view query fallback', () {
      final source = File('lib/data/flows_repo.dart').readAsStringSync();
      final start = source.indexOf(
        'Future<HydrationFetchResult<FlowEventCounts>> _loadMyEventCounts(',
      );
      final end = source.indexOf(
        'Future<HydrationFetchResult<FlowEventCounts>> loadMyFlowEventCounts(',
        start,
      );
      final body = source.substring(start, end);

      expect(body, isNot(contains("from('user_event_filing_items_client')")));
      expect(body, isNot(contains('user_event_completions')));
    });
  });
}

class _ActivityClient extends http.BaseClient {
  _ActivityClient({required this.fail});

  final bool fail;
  int requestCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestCount++;
    if (fail) {
      return _response(request, const <String, Object?>{
        'message': 'fixture failure',
        'code': '57014',
        'details': null,
        'hint': null,
      }, statusCode: 500);
    }
    return _response(request, const <Object?>[]);
  }

  http.StreamedResponse _response(
    http.BaseRequest request,
    Object? body, {
    int statusCode = 200,
  }) {
    final bytes = utf8.encode(jsonEncode(body));
    return http.StreamedResponse(
      Stream<List<int>>.value(bytes),
      statusCode,
      request: request,
      headers: const <String, String>{'content-type': 'application/json'},
    );
  }
}

String _sessionJson() => jsonEncode(<String, Object?>{
  'access_token': _jwtForUser(_userId),
  'token_type': 'bearer',
  'expires_in': 3600,
  'expires_at': DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000 + 3600,
  'refresh_token': 'fixture-refresh-token',
  'user': <String, Object?>{
    'id': _userId,
    'aud': 'authenticated',
    'role': 'authenticated',
    'email': 'fixture@example.com',
    'app_metadata': const <String, Object?>{},
    'user_metadata': const <String, Object?>{},
    'created_at': '2026-01-01T00:00:00.000Z',
  },
});

String _jwtForUser(String userId) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final expiresAt =
      DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000 + 3600;
  return '${encode(<String, Object?>{'alg': 'HS256', 'typ': 'JWT'})}.'
      '${encode(<String, Object?>{'sub': userId, 'exp': expiresAt})}.signature';
}
