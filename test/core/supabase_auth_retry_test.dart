import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/supabase_auth_retry.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('isExpiredSupabaseJwtError', () {
    test('detects PostgREST expired JWT responses', () {
      expect(
        isExpiredSupabaseJwtError(
          const PostgrestException(message: 'JWT expired', code: 'PGRST303'),
        ),
        isTrue,
      );
    });

    test('detects auth expired token responses', () {
      expect(
        isExpiredSupabaseJwtError(
          const AuthException('Token is expired', statusCode: '401'),
        ),
        isTrue,
      );
    });

    test('ignores unrelated PostgREST errors', () {
      expect(
        isExpiredSupabaseJwtError(
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
