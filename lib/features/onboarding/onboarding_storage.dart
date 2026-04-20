import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OnboardingStorage {
  OnboardingStorage(this._client);

  static const String _localKeyPrefix = 'onboarding_v1_completed';

  final SupabaseClient _client;

  String _localKeyForUser(String userId) => '$_localKeyPrefix:$userId';

  Future<bool> isCompletedLocally(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_localKeyForUser(userId)) ?? false;
    } catch (e) {
      debugPrint('[OnboardingStorage] Failed to read local flag: $e');
      return false;
    }
  }

  Future<void> setCompletedLocally(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_localKeyForUser(userId), true);
    } catch (e) {
      debugPrint('[OnboardingStorage] Failed to set local flag: $e');
    }
  }

  Future<bool> fetchRemoteCompletion(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select('onboarding_completed_at')
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return false;
      final completedAt = response['onboarding_completed_at'];
      return completedAt != null;
    } catch (e) {
      debugPrint('[OnboardingStorage] Failed to fetch remote flag: $e');
      return false;
    }
  }

  Future<bool> hasCompleted(String userId) async {
    if (await isCompletedLocally(userId)) return true;

    final remoteCompleted = await fetchRemoteCompletion(userId);
    if (remoteCompleted) {
      await setCompletedLocally(userId);
      return true;
    }
    return false;
  }

  Future<void> markCompleted(String userId) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    try {
      await _client.from('profiles').upsert({
        'id': userId,
        'onboarding_completed_at': nowIso,
      });
    } catch (e) {
      debugPrint('[OnboardingStorage] Failed to persist remote flag: $e');
    }

    await setCompletedLocally(userId);
  }
}
