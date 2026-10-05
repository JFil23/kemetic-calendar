import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Fences one operation across account departure, including A → B → A.
/// Same-account token refresh keeps the operation valid. The caller owns the
/// subscription lifetime and disposes this fence when its operation completes.
class AccountOperationFence {
  AccountOperationFence(this._client) : userId = _client.auth.currentUser?.id {
    _subscription = _client.auth.onAuthStateChange.listen(
      (state) {
        if (state.event == AuthChangeEvent.signedOut ||
            state.session?.user.id != userId) {
          _departed = true;
        }
      },
      onError: (Object error, StackTrace stack) {
        // Refresh transport errors are not evidence of account departure.
        // Auth owns recovery; this passive observer only fences identity.
      },
    );
  }

  final SupabaseClient _client;
  final String? userId;
  late final StreamSubscription<AuthState> _subscription;
  bool _departed = false;

  bool get isCurrent => !_departed && _client.auth.currentUser?.id == userId;

  void dispose() => unawaited(_subscription.cancel());
}
