import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/supabase_auth_retry.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('isRetryableSupabaseAuthError', () {
    test('detects PostgREST expired JWT responses', () {
      expect(
        isRetryableSupabaseAuthError(
          const PostgrestException(message: 'JWT expired', code: 'PGRST303'),
        ),
        isTrue,
      );
    });

    test('detects auth expired token responses', () {
      expect(
        isRetryableSupabaseAuthError(
          const AuthException('Token is expired', statusCode: '401'),
        ),
        isTrue,
      );
    });

    test('detects FunctionException map details Invalid JWT', () {
      expect(
        isRetryableSupabaseAuthError(
          const FunctionException(
            status: 401,
            details: {'message': 'Invalid JWT'},
          ),
        ),
        isTrue,
      );
    });

    test('detects FunctionException JSON string details', () {
      expect(
        isRetryableSupabaseAuthError(
          const FunctionException(
            status: 401,
            details: '{"error":{"message":"JWT expired"}}',
          ),
        ),
        isTrue,
      );
    });

    test('detects FunctionException raw string details', () {
      expect(
        isRetryableSupabaseAuthError(
          const FunctionException(status: 401, details: 'expired jwt'),
        ),
        isTrue,
      );
    });

    test('ignores unrelated FunctionException 401s', () {
      expect(
        isRetryableSupabaseAuthError(
          const FunctionException(
            status: 401,
            details: {'message': 'Missing authorization header'},
          ),
        ),
        isFalse,
      );
    });

    test('ignores Invalid JWT when status is not 401', () {
      expect(
        isRetryableSupabaseAuthError(
          const FunctionException(
            status: 500,
            details: {'message': 'Invalid JWT'},
          ),
        ),
        isFalse,
      );
    });

    test('ignores unrelated PostgREST errors', () {
      expect(
        isRetryableSupabaseAuthError(
          const PostgrestException(
            message: 'relation does not exist',
            code: '42P01',
          ),
        ),
        isFalse,
      );
    });
  });
}
