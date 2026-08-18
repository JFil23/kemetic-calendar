import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

bool isRetryableSupabaseAuthError(Object error) {
  if (error is AuthException) {
    return _containsRetryableJwtPhrase(error.message);
  }

  if (error is PostgrestException) {
    final text =
        '${error.code ?? ''} ${error.message} ${error.details ?? ''} ${error.hint ?? ''}';
    return error.code == 'PGRST303' || _containsRetryableJwtPhrase(text);
  }

  if (error is FunctionException) {
    if (error.status != 401) return false;
    return _containsRetryableJwtPhrase(_functionExceptionText(error));
  }

  return false;
}

Future<T> withSupabaseAuthRetry<T>(
  SupabaseClient client,
  Future<T> Function() run,
) async {
  try {
    return await run();
  } catch (error) {
    if (!isRetryableSupabaseAuthError(error)) rethrow;

    final refreshed = await client.auth.refreshSession();
    if (refreshed.session == null) rethrow;

    return await run();
  }
}

bool _containsRetryableJwtPhrase(String raw) {
  final lower = raw.toLowerCase();
  return lower.contains('invalid jwt') ||
      lower.contains('jwt expired') ||
      lower.contains('expired jwt') ||
      lower.contains('token is expired');
}

String _functionExceptionText(FunctionException error) {
  final fromDetails = _extractAuthErrorText(error.details);
  if (fromDetails.isNotEmpty) return fromDetails;
  final reason = error.reasonPhrase?.trim() ?? '';
  if (reason.isNotEmpty) return reason;
  return error.toString();
}

String _extractAuthErrorText(Object? raw) {
  if (raw == null) return '';

  if (raw is String) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final parsed = _tryDecodeJsonObject(trimmed);
    if (parsed != null) {
      final nested = _extractAuthErrorText(parsed);
      if (nested.isNotEmpty) return nested;
    }
    return trimmed;
  }

  if (raw is Map) {
    final map = Map<String, dynamic>.from(raw);
    for (final key in ['message', 'detail', 'errorMessage', 'msg', 'error']) {
      final nested = _extractAuthErrorText(map[key]);
      if (nested.isNotEmpty) return nested;
    }
  }

  return raw.toString().trim();
}

Map<String, dynamic>? _tryDecodeJsonObject(String raw) {
  try {
    final decoded = json.decode(raw);
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
  } catch (_) {}
  return null;
}
