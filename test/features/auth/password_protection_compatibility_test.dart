import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/features/auth/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const account = '00000000-0000-4000-8000-000000000001';
  Map<String, dynamic> session() {
    final payload = base64Url
        .encode(
          utf8.encode(
            jsonEncode({
              'sub': account,
              'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
              'role': 'authenticated',
            }),
          ),
        )
        .replaceAll('=', '');
    return {
      'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.fixture',
      'refresh_token': 'fixture-refresh-token',
      'token_type': 'bearer',
      'expires_in': 3600,
      'user': {
        'id': account,
        'aud': 'authenticated',
        'role': 'authenticated',
        'email': 'fixture@example.test',
        'app_metadata': {'provider': 'email'},
        'user_metadata': <String, dynamic>{},
        'created_at': '2026-01-01T00:00:00Z',
      },
      'weak_password': {
        'reasons': ['pwned'],
        'message': 'This password has appeared in a data breach.',
      },
    };
  }

  http.Response leakedPassword() => http.Response(
    jsonEncode({
      'code': 'weak_password',
      'msg': 'This password has appeared in a data breach.',
      'weak_password': {
        'reasons': ['pwned'],
      },
    }),
    422,
    headers: {'content-type': 'application/json'},
  );

  test(
    'existing password sign-in accepts a successful session with a warning',
    () async {
      final client = GoTrueClient(
        url: 'https://auth.example.test',
        autoRefreshToken: false,
        asyncStorage: _MemoryAuthStorage(),
        httpClient: MockClient((request) async {
          expect(request.url.path, '/token');
          expect(request.url.queryParameters['grant_type'], 'password');
          return http.Response(jsonEncode(session()), 200);
        }),
      );
      addTearDown(client.dispose);
      final result = await client.signInWithPassword(
        email: 'fixture@example.test',
        password: 'existing-fixture-password',
      );
      expect(result.session?.user.id, account);
      expect(client.currentSession, isNotNull);
    },
  );

  test(
    'leaked signup password uses the existing readable retry message',
    () async {
      final client = GoTrueClient(
        url: 'https://auth.example.test',
        autoRefreshToken: false,
        asyncStorage: _MemoryAuthStorage(),
        httpClient: MockClient((request) async {
          expect(request.url.path, '/signup');
          return leakedPassword();
        }),
      );
      addTearDown(client.dispose);
      try {
        await client.signUp(
          email: 'fixture@example.test',
          password: 'leaked-fixture-password',
        );
        fail('A leaked signup password must be rejected');
      } on AuthException catch (error) {
        expect(error.code, 'weak_password');
        expect(
          emailAuthMessageForAuthException(error, creatingAccount: true),
          'Use a stronger password.',
        );
        expect(client.currentSession, isNull);
      }
    },
  );

  test('rejected password change preserves the signed-in account', () async {
    final client = GoTrueClient(
      url: 'https://auth.example.test',
      autoRefreshToken: false,
      asyncStorage: _MemoryAuthStorage(),
      httpClient: MockClient((request) async {
        if (request.url.path == '/token')
          return http.Response(jsonEncode(session()), 200);
        expect(request.url.path, '/user');
        expect(request.method, 'PUT');
        return leakedPassword();
      }),
    );
    addTearDown(client.dispose);
    await client.signInWithPassword(
      email: 'fixture@example.test',
      password: 'existing-fixture-password',
    );
    await expectLater(
      client.updateUser(UserAttributes(password: 'leaked-fixture-password')),
      throwsA(
        isA<AuthException>().having(
          (error) => error.code,
          'code',
          'weak_password',
        ),
      ),
    );
    expect(client.currentUser?.id, account);
    expect(client.currentSession, isNotNull);
  });
}

class _MemoryAuthStorage extends GotrueAsyncStorage {
  final Map<String, String> _values = {};
  @override
  Future<String?> getItem({required String key}) async => _values[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    _values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    _values.remove(key);
  }
}
