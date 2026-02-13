// lib/services/ai_flow_generation_service.dart

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ai_flow_generation_response.dart';

class AIFlowGenerationService {
  final SupabaseClient _sb;

  AIFlowGenerationService(this._sb);

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}'; // YYYY-MM-DD

  Future<T> _withAuthRetry<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on AuthException {
      // Token likely expired — refresh then retry once
      final refreshed = await _sb.auth.refreshSession();
      if (refreshed.session == null) rethrow;
      return await run();
    }
  }

  Future<AIFlowGenerationResponse> generate({
    required String description,
    required DateTime startDate,
    required DateTime endDate,
    String? flowColor, // hex like "#4dd0e1"
    String? timezone,  // IANA string (e.g., "America/Los_Angeles")
    bool forceRefresh = false,
  }) async {
    // 1) Session precheck
    final sess = _sb.auth.currentSession;
    if (sess == null) {
      // Return error response instead of throwing
      return const AIFlowGenerationResponse(
        success: false,
        flowId: null,
        flowName: null,
        flowColor: null,
        notes: null,
        notesCount: null,
        events: null,
        modelUsed: null,
        cached: null,
      );
    }

    // 2) Build payload (use passed dates)
    final payload = <String, dynamic>{
      'description': description,
      'startDate': _fmt(startDate),
      'endDate': _fmt(endDate),
      if (flowColor != null) 'flowColor': flowColor,
      if (timezone != null) 'timezone': timezone,
      if (forceRefresh) 'force_refresh': true,
      // ⚠️ Do NOT send useKemetic; function doesn't accept it
    };

    // 3) Auth-retry wrapped invoke (SDK auto-attaches JWT)
    final res = await _withAuthRetry(() {
      return _sb.functions.invoke(
        'ai_generate_flow',
        body: payload,
      );
    });

    // TEMPORARY DEBUG: Log response details
    debugPrint('[AI invoke] status: ${res.status}');
    debugPrint('[AI invoke] data: ${res.data}');
    if (res.data is Map && (res.data as Map)['success'] == true) {
      final dataMap = res.data as Map;
      debugPrint('[AI invoke] OK ✅ flowId=${dataMap['flowId']} model=${dataMap['modelUsed']}');
    } else {
      debugPrint('[AI invoke] FAIL ❌ ${res.data}');
    }

    // 4) Parse response (defensive)
    try {
      final data = res.data;
      final map = data is String
          ? json.decode(data) as Map<String, dynamic>
          : Map<String, dynamic>.from(data as Map);

      return AIFlowGenerationResponse.fromJson(map);
    } catch (e, st) {
      debugPrint('[AI invoke] parse error: $e');
      debugPrint('$st');
      return const AIFlowGenerationResponse(
        success: false,
        flowId: null,
        flowName: null,
        flowColor: null,
        notes: null,
        notesCount: null,
        events: null,
        modelUsed: null,
        cached: null,
      );
    }
  }
}
