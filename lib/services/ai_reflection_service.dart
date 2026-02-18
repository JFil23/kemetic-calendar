// Lightweight LLM client for decan reflections, reusing Supabase Edge Functions.

import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

class AIReflectionResponse {
  final bool success;
  final String? reflection;
  final String? modelUsed;
  final String? error;
  final int? badgeCount;
  final int? evidenceCount;
  final List<String>? topTags;
  final String? branch;
  final String? reflectionId;

  const AIReflectionResponse({
    required this.success,
    this.reflection,
    this.modelUsed,
    this.error,
    this.badgeCount,
    this.evidenceCount,
    this.topTags,
    this.branch,
    this.reflectionId,
  });

  factory AIReflectionResponse.fromJson(Map<String, dynamic> json) {
    return AIReflectionResponse(
      success: json['success'] == true,
      reflection: json['reflection'] as String?,
      modelUsed: json['modelUsed'] as String?,
      error: json['error'] as String?,
      badgeCount: json['badgeCount'] as int?,
      evidenceCount: json['evidenceCount'] as int?,
      topTags: (json['topTags'] as List?)?.map((e) => e.toString()).toList(),
      branch: json['branch'] as String?,
      reflectionId: json['reflection_id'] as String?,
    );
  }
}

class AIReflectionService {
  final SupabaseClient _sb;

  AIReflectionService(this._sb);

  Future<AIReflectionResponse> generateReflection({
    required String decanName,
    String? decanTheme,
    required DateTime decanStart,
    required DateTime decanEnd,
    bool includeHistory = true,
    bool persist = false,
    List<Map<String, dynamic>>? badges,
  }) async {
    final sess = _sb.auth.currentSession;
    if (sess == null) {
      return const AIReflectionResponse(
        success: false,
        reflection: null,
        modelUsed: 'no-session',
        error: 'Not signed in (no currentSession).',
      );
    }

    final userId = sess.user.id;
    String toDateOnlyLocal(DateTime dt) {
      final l = dt.toLocal();
      final yyyy = l.year.toString().padLeft(4, '0');
      final mm = l.month.toString().padLeft(2, '0');
      final dd = l.day.toString().padLeft(2, '0');
      return '$yyyy-$mm-$dd';
    }

    final payload = <String, dynamic>{
      'user_id': userId,
      'decan_name': decanName,
      'decan_theme': decanTheme,
      'decan_start': toDateOnlyLocal(decanStart),
      'decan_end': toDateOnlyLocal(decanEnd),
      'include_history': includeHistory,
      'v2': true,
      'persist': persist,
      if (badges != null) 'badges': badges,
    };

    final res = await _sb.functions.invoke(
      'ai_generate_reflection',
      body: payload,
    );

    // SDK returns a FunctionResponse without an .error getter; use status/data.
    if (res.status != 200) {
      final errBody = res.data;
      final errMsg = errBody is Map && errBody['error'] != null
          ? errBody['error'].toString()
          : 'Function returned status ${res.status}';
      return AIReflectionResponse(
        success: false,
        reflection: null,
        modelUsed: 'invoke-error',
        error: errMsg,
      );
    }

    final data = res.data;
    if (data == null) {
      return const AIReflectionResponse(
        success: false,
        reflection: null,
        modelUsed: 'null-data',
        error: 'Function returned null data.',
      );
    }

    final Map<String, dynamic> raw = data is String
        ? json.decode(data) as Map<String, dynamic>
        : data as Map<String, dynamic>;

    // Normalize wrapped responses like { data: { success, reflection, ... } }
    final Map<String, dynamic> normalized =
        (raw['success'] == null && raw['data'] is Map<String, dynamic>)
            ? raw['data'] as Map<String, dynamic>
            : raw;

    return AIReflectionResponse.fromJson(normalized);
  }
}
