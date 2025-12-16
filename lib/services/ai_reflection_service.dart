// Lightweight LLM client for decan reflections, reusing Supabase Edge Functions.

import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

class AIReflectionResponse {
  final bool success;
  final String? reflection;
  final String? modelUsed;

  const AIReflectionResponse({
    required this.success,
    this.reflection,
    this.modelUsed,
  });

  factory AIReflectionResponse.fromJson(Map<String, dynamic> json) {
    return AIReflectionResponse(
      success: json['success'] == true,
      reflection: json['reflection'] as String?,
      modelUsed: json['modelUsed'] as String?,
    );
  }
}

class AIReflectionService {
  final SupabaseClient _sb;

  AIReflectionService(this._sb);

  Future<AIReflectionResponse> generateReflection({
    required String decanName,
    required List<String> badgeTitles,
    required int badgeCount,
    required String kemeticDayLabel,
  }) async {
    final sess = _sb.auth.currentSession;
    if (sess == null) {
      return const AIReflectionResponse(success: false, reflection: null);
    }

    final payload = <String, dynamic>{
      'decan_name': decanName,
      'badge_titles': badgeTitles,
      'badge_count': badgeCount,
      'kemetic_day': kemeticDayLabel,
    };

    final res = await _sb.functions.invoke(
      'ai_generate_reflection',
      body: payload,
    );

    final data = res.data;
    final map = data is String
        ? json.decode(data) as Map<String, dynamic>
        : data as Map<String, dynamic>;

    return AIReflectionResponse.fromJson(map);
  }
}
