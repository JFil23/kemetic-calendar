import 'package:shared_preferences/shared_preferences.dart';

class FlowOnboardingStateRepo {
  static const String _activationPromptSeenKeyPrefix =
      'flow_activation_prompt_seen_v2';

  String _activationPromptSeenKey(String userId) =>
      '$_activationPromptSeenKeyPrefix:$userId';

  Future<bool> hasSeenActivationPrompt(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_activationPromptSeenKey(userId)) ?? false;
  }

  Future<void> markActivationPromptSeen(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_activationPromptSeenKey(userId), true);
  }
}
