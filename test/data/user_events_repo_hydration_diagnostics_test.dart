import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/data/user_events_repo.dart';
import 'package:mobile/features/calendar/calendar_hydration_diagnostics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _userId = '27d63169-a28a-4550-a0a0-8fee0e8e7b95';
final _hydrationStart = DateTime.utc(2026, 1, 1);
final _hydrationEnd = DateTime.utc(2026, 1, 2);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    CalendarHydrationDiagnostics.instance.debugReset();
  });

  tearDown(() {
    CalendarHydrationDiagnostics.instance.debugReset();
  });

  test(
    'four hydration sources report truthful successful-empty outcomes',
    () async {
      final client = SupabaseClient(
        'https://example.supabase.test',
        'test-anon-key',
        httpClient: _HydrationClient(fail: false),
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      try {
        await client.auth.recoverSession(_sessionJson());
        final context = _startPass();
        final repo = UserEventsRepo(client);

        expect(await repo.getAllFlows(diagnosticContext: context), isEmpty);
        expect(
          (await repo.getEventsForFlowIds(
            <int>{1},
            startUtc: _hydrationStart,
            endUtc: _hydrationEnd,
            diagnosticContext: context,
          )).status,
          HydrationFetchStatus.successfulEmpty,
        );
        expect(
          await repo.getEventsForFlow(
            1,
            diagnosticContext: context.child('flow_fallback_0'),
          ),
          isEmpty,
        );
        expect(
          (await repo.getStandaloneEventsForDateRangeAll(
            startUtc: DateTime.utc(2026, 1, 1),
            endUtc: DateTime.utc(2026, 1, 2),
            diagnosticContext: context,
          )).status,
          HydrationFetchStatus.successfulEmpty,
        );

        final requests = await _closeAndRequests(context);
        expect(_status(requests, 'flow_catalog'), 'successful_empty');
        expect(_status(requests, 'flow_batch'), 'successful_empty');
        expect(_status(requests, 'flow_fallback_0'), 'successful_empty');
        expect(_status(requests, 'standalone'), 'successful_empty');
      } finally {
        client.dispose();
      }
    },
  );

  test(
    'swallowed failures stay empty but report failed; catalog still throws',
    () async {
      final client = SupabaseClient(
        'https://example.supabase.test',
        'test-anon-key',
        httpClient: _HydrationClient(fail: true),
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      try {
        await client.auth.recoverSession(_sessionJson());
        final context = _startPass();
        final repo = UserEventsRepo(client);

        await expectLater(
          repo.getAllFlows(diagnosticContext: context),
          throwsA(isA<PostgrestException>()),
        );
        expect(
          (await repo.getEventsForFlowIds(
            <int>{1},
            startUtc: _hydrationStart,
            endUtc: _hydrationEnd,
            diagnosticContext: context,
          )).status,
          HydrationFetchStatus.failed,
        );
        expect(
          await repo.getEventsForFlow(
            1,
            diagnosticContext: context.child('flow_fallback_0'),
          ),
          isEmpty,
        );
        expect(
          (await repo.getStandaloneEventsForDateRangeAll(
            startUtc: DateTime.utc(2026, 1, 1),
            endUtc: DateTime.utc(2026, 1, 2),
            diagnosticContext: context,
          )).status,
          HydrationFetchStatus.failed,
        );

        final requests = await _closeAndRequests(context);
        expect(_status(requests, 'flow_catalog'), 'failed');
        expect(_status(requests, 'flow_batch'), 'failed');
        expect(_status(requests, 'flow_fallback_0'), 'failed');
        expect(_status(requests, 'standalone'), 'failed');
      } finally {
        client.dispose();
      }
    },
  );

  test(
    'four sources report unauthenticated without inventing no-flows',
    () async {
      final client = SupabaseClient(
        'https://example.supabase.test',
        'test-anon-key',
        httpClient: _HydrationClient(fail: false),
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      try {
        final context = _startPass();
        final repo = UserEventsRepo(client);

        expect(await repo.getAllFlows(diagnosticContext: context), isEmpty);
        expect(
          (await repo.getEventsForFlowIds(
            <int>{1},
            startUtc: _hydrationStart,
            endUtc: _hydrationEnd,
            diagnosticContext: context,
          )).status,
          HydrationFetchStatus.unauthenticated,
        );
        expect(
          await repo.getEventsForFlow(
            1,
            diagnosticContext: context.child('flow_fallback_0'),
          ),
          isEmpty,
        );
        expect(
          (await repo.getStandaloneEventsForDateRangeAll(
            startUtc: DateTime.utc(2026, 1, 1),
            endUtc: DateTime.utc(2026, 1, 2),
            diagnosticContext: context,
          )).status,
          HydrationFetchStatus.unauthenticated,
        );

        final requests = await _closeAndRequests(context);
        for (final operation in <String>[
          'flow_catalog',
          'flow_batch',
          'flow_fallback_0',
          'standalone',
        ]) {
          expect(_status(requests, operation), 'unauthenticated');
        }
      } finally {
        client.dispose();
      }
    },
  );

  test('critical hydration lanes use the versioned RPC contract', () async {
    final transport = _HydrationClient(fail: false);
    final client = SupabaseClient(
      'https://example.supabase.test',
      'test-anon-key',
      httpClient: transport,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    try {
      await client.auth.recoverSession(_sessionJson());
      final repo = UserEventsRepo(client);
      final start = DateTime.utc(2026, 1, 1);
      final end = DateTime.utc(2026, 1, 3);

      await repo.getEventsForFlowIds(
        <int>{7, 3},
        pageSize: 25,
        startUtc: start,
        endUtc: end,
      );
      await repo.getStandaloneEventsForDateRangeAll(
        startUtc: start,
        endUtc: end,
        pageSize: 25,
      );

      final rpcRequests = transport.requests
          .where(
            (request) =>
                request.url.path ==
                '/rest/v1/rpc/get_calendar_hydration_events_v1',
          )
          .toList(growable: false);
      expect(rpcRequests, hasLength(2));
      expect(
        rpcRequests.map((request) => request.url.path),
        everyElement('/rest/v1/rpc/get_calendar_hydration_events_v1'),
      );
      expect(
        transport.requests.map((request) => request.url.path),
        isNot(contains('/rest/v1/user_event_filing_items_client')),
      );

      final flowBody = transport.bodyAt(0);
      expect(flowBody['p_lane'], 'flow');
      expect(flowBody['p_flow_ids'], <int>[3, 7]);
      expect(flowBody['p_page_limit'], 25);
      expect(flowBody['p_page_offset'], 0);
      expect(flowBody['p_start_utc'], start.toIso8601String());
      expect(flowBody['p_end_utc'], end.toIso8601String());

      final standaloneBody = transport.bodyAt(1);
      expect(standaloneBody['p_lane'], 'standalone');
      expect(standaloneBody['p_flow_ids'], isNull);
      expect(standaloneBody['p_page_limit'], 25);
      expect(standaloneBody['p_page_offset'], 0);
    } finally {
      client.dispose();
    }
  });

  test('a later-page failure discards the accumulated batch', () async {
    final transport = _SecondPageFailureClient();
    final client = SupabaseClient(
      'https://example.supabase.test',
      'test-anon-key',
      httpClient: transport,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    try {
      await client.auth.recoverSession(_sessionJson());
      final result = await UserEventsRepo(client).getEventsForFlowIds(
        <int>{1},
        pageSize: 1,
        startUtc: _hydrationStart,
        endUtc: _hydrationEnd,
      );

      expect(result.status, HydrationFetchStatus.failed);
      expect(result.value, isEmpty);
      expect(transport.requests, hasLength(2));
      expect(
        transport.requests.map((request) => request.url.path),
        everyElement('/rest/v1/rpc/get_calendar_hydration_events_v1'),
      );
      expect(transport.bodyAt(0)['p_page_offset'], 0);
      expect(transport.bodyAt(1)['p_page_offset'], 1);
    } finally {
      client.dispose();
    }
  });
}

HydrationDiagnosticContext _startPass() {
  final diagnostics = CalendarHydrationDiagnostics.instance;
  diagnostics.startColdProcess(userId: _userId);
  return diagnostics.beginPass(
    epoch: 1,
    requestedSource: 'test',
    executedSource: 'test',
  )!;
}

Future<List<Map<String, Object?>>> _closeAndRequests(
  HydrationDiagnosticContext context,
) async {
  final diagnostics = CalendarHydrationDiagnostics.instance;
  diagnostics.endPass(context, succeeded: true);
  diagnostics.recordCoordinatorIdle();
  await diagnostics.debugClose(HydrationTraceCloseReason.navigation);
  return (diagnostics.lastCompletedTrace!['requests']! as List)
      .map((item) => Map<String, Object?>.from(item as Map))
      .toList(growable: false);
}

String? _status(List<Map<String, Object?>> requests, String operation) {
  return requests.lastWhere(
        (request) => request['operation'] == operation,
      )['status']
      as String?;
}

class _HydrationClient extends http.BaseClient {
  _HydrationClient({required this.fail});

  final bool fail;
  final List<http.BaseRequest> requests = <http.BaseRequest>[];

  Map<String, Object?> bodyAt(int index) {
    final request = requests[index] as http.Request;
    return Map<String, Object?>.from(jsonDecode(request.body) as Map);
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    if (fail) {
      return _jsonResponse(request, const <String, Object?>{
        'message': 'fixture failure',
        'code': 'PGRST500',
        'details': null,
        'hint': null,
      }, statusCode: 500);
    }
    return _jsonResponse(request, const <Object?>[]);
  }

  http.StreamedResponse _jsonResponse(
    http.BaseRequest request,
    Object? body, {
    int statusCode = 200,
  }) {
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(jsonEncode(body))),
      statusCode,
      request: request,
      headers: const <String, String>{'content-type': 'application/json'},
    );
  }
}

class _SecondPageFailureClient extends http.BaseClient {
  int _requestCount = 0;
  final List<http.BaseRequest> requests = <http.BaseRequest>[];

  Map<String, Object?> bodyAt(int index) {
    final request = requests[index] as http.Request;
    return Map<String, Object?>.from(jsonDecode(request.body) as Map);
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    _requestCount++;
    if (_requestCount == 1) {
      return _jsonResponse(request, <Object?>[
        <String, Object?>{
          'id': '11111111-1111-4111-8111-111111111111',
          'client_event_id': 'fixture-page-one',
          'title': 'Page one',
          'all_day': false,
          'starts_at': '2026-01-01T12:00:00.000Z',
          'ends_at': '2026-01-01T13:00:00.000Z',
          'filed_flow_id': 1,
          'item_kind': 'flow',
        },
      ]);
    }
    return _jsonResponse(request, const <String, Object?>{
      'message': 'second page timeout',
      'code': '57014',
      'details': null,
      'hint': null,
    }, statusCode: 500);
  }

  http.StreamedResponse _jsonResponse(
    http.BaseRequest request,
    Object? body, {
    int statusCode = 200,
  }) {
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(jsonEncode(body))),
      statusCode,
      request: request,
      headers: const <String, String>{'content-type': 'application/json'},
    );
  }
}

String _sessionJson() {
  final expiresAt =
      DateTime.now().add(const Duration(days: 365)).millisecondsSinceEpoch ~/
      1000;
  return jsonEncode(<String, Object?>{
    'access_token': 'test-access-token-$expiresAt',
    'expires_in': 31536000,
    'refresh_token': 'test-refresh-token',
    'token_type': 'bearer',
    'user': <String, Object?>{
      'id': _userId,
      'app_metadata': <String, Object?>{
        'provider': 'email',
        'providers': <String>['email'],
      },
      'user_metadata': <String, Object?>{},
      'aud': 'authenticated',
      'email': 'hydration@example.com',
      'phone': '',
      'created_at': '2026-01-01T00:00:00.000000Z',
      'email_confirmed_at': '2026-01-01T00:00:00.000000Z',
      'role': 'authenticated',
      'updated_at': '2026-01-01T00:00:00.000000Z',
    },
    'expiresAt': expiresAt,
  });
}
