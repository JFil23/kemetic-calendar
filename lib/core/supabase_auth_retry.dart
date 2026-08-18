import 'package:supabase_flutter/supabase_flutter.dart';

bool isExpiredSupabaseJwtError(Object error) {
  if (error is AuthException) {
    final message = error.message.toLowerCase();
    return message.contains('jwt expired') ||
        message.contains('expired jwt') ||
        message.contains('token is expired');
  }

  if (error is PostgrestException) {
    final text =
        '${error.code ?? ''} ${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
            .toLowerCase();
    return error.code == 'PGRST303' ||
        text.contains('jwt expired') ||
        text.contains('expired jwt');
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
    if (!isExpiredSupabaseJwtError(error)) rethrow;

    final refreshed = await client.auth.refreshSession();
    if (refreshed.session == null) rethrow;

    return await run();
  }
}
