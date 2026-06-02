import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'maat_decan_flow.dart';

class LivingTextDayOneNodeStore {
  const LivingTextDayOneNodeStore();

  Future<String?> readSlug({
    required String userId,
    required String? flowInstanceId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(
      _key(userId: userId, flowInstanceId: flowInstanceId),
    );
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  Future<void> writeSlug({
    required String userId,
    required String? flowInstanceId,
    required String nodeSlug,
  }) async {
    final trimmed = nodeSlug.trim();
    if (trimmed.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(userId: userId, flowInstanceId: flowInstanceId),
      trimmed,
    );
  }

  @visibleForTesting
  String keyForTesting({
    required String userId,
    required String? flowInstanceId,
  }) {
    return _key(userId: userId, flowInstanceId: flowInstanceId);
  }

  // TODO: If Living Text ever stores the Day 1 entry during enrollment, move
  // capture there and keep this helper as the scoped persistence boundary.
  String _key({required String userId, required String? flowInstanceId}) {
    final trimmedUserId = userId.trim().isEmpty ? 'local' : userId.trim();
    final trimmedFlowInstanceId = flowInstanceId?.trim();
    if (trimmedFlowInstanceId == null || trimmedFlowInstanceId.isEmpty) {
      return 'maat_flow:$trimmedUserId:$kLivingTextFlowKey:day1_node_slug';
    }
    return 'maat_flow:$trimmedUserId:$kLivingTextFlowKey:$trimmedFlowInstanceId:day1_node_slug';
  }
}
