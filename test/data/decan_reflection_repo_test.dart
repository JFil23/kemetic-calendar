import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/decan_reflection_model.dart';
import 'package:mobile/data/decan_reflection_repo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const userId = '00000000-0000-4000-8000-00000000c011';

  for (final fixture in <({String label, Map<String, dynamic> row})>[
    (label: 'v1', row: _v1Row),
    (label: 'pure v2', row: _v2Row),
  ]) {
    test(
      'reflection-id lookup loads ${fixture.label} render metadata',
      () async {
        final receipt = await _withReflectionServer(
          (request) async => _sendJson(request, <Object?>[fixture.row]),
          (client, requests) async {
            await client.auth.recoverSession(_sessionJson(userId));
            final result = await DecanReflectionRepo(
              client,
            ).getRenderMetadataForReflection(_reflection);
            return (result: result, requests: List<Uri>.from(requests));
          },
        );

        expect(receipt.result?.badgeBody, 'The record was weighed.');
        expect(receipt.requests, hasLength(1));
        expect(
          receipt
              .requests
              .single
              .queryParameters['source_snapshot->>decan_reflection_id'],
          'eq.${_reflection.id}',
        );
      },
    );
  }

  test('reflection-id lookup loads pure v2 graph hints', () async {
    final result = await _withReflectionServer(
      (request) async => _sendJson(request, <Object?>[_v2Row]),
      (client, _) async {
        await client.auth.recoverSession(_sessionJson(userId));
        return DecanReflectionRepo(
          client,
        ).getGraphHintsForReflection(_reflection);
      },
    );

    expect(result?.leadAxis, 'truth');
    expect(result?.anchorNodes, <String>['maat']);
    expect(result?.cta?.ref, 'the-tending');
  });

  test('window fallback still loads a supported manifest row', () async {
    final receipt = await _withReflectionServer(
      (request) async {
        if (request.uri.queryParameters.containsKey(
          'source_snapshot->>decan_reflection_id',
        )) {
          await _sendJson(request, <Object?>[]);
          return;
        }
        await _sendJson(request, <Object?>[_v2Row]);
      },
      (client, requests) async {
        await client.auth.recoverSession(_sessionJson(userId));
        final result = await DecanReflectionRepo(
          client,
        ).getRenderMetadataForReflection(_reflection);
        return (result: result, requests: List<Uri>.from(requests));
      },
    );

    expect(receipt.result?.renderer, 'deterministic_spectrum');
    expect(receipt.requests, hasLength(2));
    expect(
      receipt.requests.last.queryParameters['period_key'],
      'like.2026-09-16:2026-09-25:%',
    );
  });
}

final DecanReflection _reflection = DecanReflection(
  id: 'reflection-cut-11',
  decanName: 'Cut 11',
  decanTheme: 'Reader compatibility',
  decanStart: _start,
  decanEnd: _end,
  badgeCount: 2,
  reflectionText: 'The record was weighed.',
  createdAt: _start,
);

final DateTime _start = DateTime.fromMillisecondsSinceEpoch(
  1789516800000,
  isUtc: true,
);
final DateTime _end = DateTime.fromMillisecondsSinceEpoch(
  1790294400000,
  isUtc: true,
);

const Map<String, dynamic> _v1Row = <String, dynamic>{
  'created_at': '2026-09-16T00:00:00Z',
  'anchor_nodes': <String>['maat'],
  'source_snapshot': <String, dynamic>{
    'decan_reflection_id': 'reflection-cut-11',
  },
  'metadata': <String, dynamic>{
    'renderer': 'deterministic_spectrum',
    'used_llm': false,
    'llm_cost': 0,
    'spectrum_flow_key': 'the-weighing',
    'lead_axis': 'truth',
    'output_control': <String, dynamic>{
      'renderer': <String, dynamic>{
        'deterministic_response': <String, dynamic>{
          'badgeBody': 'The record was weighed.',
        },
      },
      'reflection_destination': <String, dynamic>{
        'type': 'flow_template',
        'ref': 'the-tending',
        'label': 'Open suggested flow',
      },
    },
  },
};

const Map<String, dynamic> _v2Row = <String, dynamic>{
  'created_at': '2026-09-16T00:00:00Z',
  'anchor_nodes': <String>['maat'],
  'source_snapshot': <String, dynamic>{
    'decan_reflection_id': 'reflection-cut-11',
  },
  'metadata': <String, dynamic>{
    'manifest': <String, dynamic>{
      'version': kReflectionGenerationManifestV2,
      'render': <String, dynamic>{
        'renderer': 'deterministic_spectrum',
        'used_llm': false,
        'llm_cost': 0,
        'spectrum_flow_key': 'the-weighing',
        'badge_body': 'The record was weighed.',
      },
      'graph': <String, dynamic>{
        'lead_axis': 'truth',
        'destination': <String, dynamic>{
          'type': 'flow_template',
          'ref': 'the-tending',
          'label': 'Open suggested flow',
        },
      },
    },
  },
};

Future<T> _withReflectionServer<T>(
  Future<void> Function(HttpRequest request) handle,
  Future<T> Function(SupabaseClient client, List<Uri> requests) run,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final requests = <Uri>[];
  final subscription = server.listen((request) async {
    requests.add(request.uri);
    await handle(request);
  });
  final client = SupabaseClient(
    'http://${server.address.host}:${server.port}',
    'test-anon-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );

  try {
    return await run(client, requests);
  } finally {
    await subscription.cancel();
    await server.close(force: true);
  }
}

Future<void> _sendJson(
  HttpRequest request,
  Object? body, {
  int statusCode = HttpStatus.ok,
}) async {
  request.response.statusCode = statusCode;
  request.response.headers.contentType = ContentType.json;
  request.response.write(jsonEncode(body));
  await request.response.close();
}

String _sessionJson(String userId) {
  final expiresAt =
      DateTime.now().add(const Duration(days: 365)).millisecondsSinceEpoch ~/
      1000;
  return jsonEncode(<String, Object?>{
    'access_token': 'test-access-token-$expiresAt',
    'expires_in': 31536000,
    'refresh_token': 'test-refresh-token',
    'token_type': 'bearer',
    'user': <String, Object?>{
      'id': userId,
      'app_metadata': <String, Object?>{
        'provider': 'email',
        'providers': <String>['email'],
      },
      'user_metadata': <String, Object?>{},
      'aud': 'authenticated',
      'email': 'cut11@example.com',
      'phone': '',
      'created_at': '2026-01-01T00:00:00.000000Z',
      'email_confirmed_at': '2026-01-01T00:00:00.000000Z',
      'role': 'authenticated',
      'updated_at': '2026-01-01T00:00:00.000000Z',
    },
    'expiresAt': expiresAt,
  });
}
