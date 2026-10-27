part of 'user_events_repo.dart';

class AskHawActionConflict implements Exception {
  const AskHawActionConflict(this.result);
  final Map<String, dynamic> result;
  @override
  String toString() =>
      'This calendar changed since the proposal. Your request is kept. Review the current calendar before trying again.';
}

final _askHawActionQueues = <String, Future<void>>{};

/// Additive acknowledged actions on the existing event/Flow owner. The durable
/// document contains requests and receipts, never a second calendar projection.
extension AskHawEventActions on UserEventsRepo {
  static String actionStorageKey(String account) =>
      'ask_haw_actions:v1:$account';

  Future<Map<String, dynamic>> readAskHawContext({
    required DateTime fromUtc,
    required DateTime untilUtc,
  }) async {
    final fence = AccountOperationFence(_client);
    try {
      if (fence.userId == null || !fence.isCurrent) {
        throw StateError('Sign in to use your calendar.');
      }
      final raw = await _client
          .rpc(
            'read_ask_haw_context_v1',
            params: {
              'p_account': fence.userId,
              'p_from': fromUtc.toUtc().toIso8601String(),
              'p_until': untilUtc.toUtc().toIso8601String(),
            },
          )
          .timeout(const Duration(seconds: 30));
      if (!fence.isCurrent) {
        throw StateError('Account changed while reading your calendar.');
      }
      final value = Map<String, dynamic>.from(raw as Map);
      if (value['status'] != 'ready' ||
          (value['coverage'] as Map?)?['complete'] != true) {
        throw StateError(
          'Your complete calendar could not be confirmed. Try a shorter date range.',
        );
      }
      return value;
    } finally {
      fence.dispose();
    }
  }

  Future<List<Map<String, dynamic>>> pendingAskHawActions() async {
    final fence = AccountOperationFence(_client);
    try {
      final uid = fence.userId;
      if (uid == null) return [];
      final prefs = await SharedPreferences.getInstance();
      if (!fence.isCurrent) return [];
      final raw = prefs.getString(actionStorageKey(uid));
      if (raw == null) return [];
      final doc = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      if (doc['schema'] != 1 || doc['account'] != uid) {
        throw StateError(
          'Saved calendar requests need a compatible app version.',
        );
      }
      return [
        for (final value in doc['pending'] as List)
          Map<String, dynamic>.from(value as Map),
      ];
    } finally {
      fence.dispose();
    }
  }

  Future<Map<String, dynamic>> applyAskHawActions({
    required String mutationId,
    required List<Map<String, dynamic>> actions,
  }) {
    final fence = AccountOperationFence(_client);
    final uid = fence.userId;
    if (uid == null || !fence.isCurrent) {
      fence.dispose();
      return Future.error(StateError('Sign in to change your calendar.'));
    }
    final result = (_askHawActionQueues[uid] ?? Future.value()).then((_) async {
      void check() {
        if (!fence.isCurrent) {
          throw StateError(
            'Account changed. Your request remains with its original account.',
          );
        }
      }

      check();
      final prefs = await SharedPreferences.getInstance();
      check();
      final key = actionStorageKey(uid);
      final saved = prefs.getString(key);
      final doc = saved == null
          ? <String, dynamic>{
              'schema': 1,
              'account': uid,
              'pending': [],
              'conflicts': [],
            }
          : Map<String, dynamic>.from(jsonDecode(saved) as Map);
      if (doc['schema'] != 1 || doc['account'] != uid) {
        throw StateError(
          'Saved calendar requests need a compatible app version.',
        );
      }
      final request = <String, dynamic>{
        'p_account': uid,
        'p_mutation': mutationId,
        'p_actions': actions,
      };
      final pending = List<dynamic>.from(doc['pending'] as List);
      final existing = pending
          .where((r) => (r as Map)['p_mutation'] == mutationId)
          .firstOrNull;
      if (existing != null && jsonEncode(existing) != jsonEncode(request)) {
        throw StateError(
          'A saved request cannot be reused for a different change.',
        );
      }
      Future<void> persist() async {
        check();
        if (!await prefs.setString(key, jsonEncode(doc))) {
          await prefs.reload();
          throw StateError(
            'Could not preserve this calendar change. Keep it open and retry.',
          );
        }
        check();
      }

      if (existing == null) {
        pending.add(request);
        doc['pending'] = pending;
        await persist();
      }
      invalidateWarmDomains(uid, [
        'flow.',
        'filing.',
        'pages.flows',
        'pages.events',
        'pages.calendar',
      ]);
      try {
        final raw = await _client
            .rpc('apply_ask_haw_actions_v1', params: request)
            .timeout(const Duration(seconds: 30));
        check();
        final receipt = Map<String, dynamic>.from(raw as Map);
        if (receipt['mutation_id'] != mutationId) {
          throw StateError(
            'The calendar acknowledgement did not match. Your request is kept.',
          );
        }
        if (receipt['status'] != 'applied' && receipt['status'] != 'conflict') {
          throw StateError(
            'This change was not acknowledged. Your request is kept.',
          );
        }
        pending.removeWhere((r) => (r as Map)['p_mutation'] == mutationId);
        doc['pending'] = pending;
        if (receipt['status'] == 'conflict') {
          (doc['conflicts'] as List).add({
            'request': request,
            'result': receipt,
          });
        }
        await persist();
        if (receipt['status'] == 'conflict') {
          throw AskHawActionConflict(receipt);
        }
        return receipt;
      } finally {
        invalidateWarmDomains(uid, [
          'flow.',
          'filing.',
          'pages.flows',
          'pages.events',
          'pages.calendar',
        ]);
      }
    });
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _askHawActionQueues[uid] = tail;
    unawaited(
      tail.whenComplete(() {
        fence.dispose();
        if (identical(_askHawActionQueues[uid], tail)) {
          _askHawActionQueues.remove(uid);
        }
      }),
    );
    return result;
  }
}
