// lib/services/ai_flow_generation_service.dart

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:functions_client/functions_client.dart';

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
        errorMessage: 'You need to sign in before generating a flow.',
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
    final FunctionResponse res = await _withAuthRetry(() async {
      try {
        return await _sb.functions.invoke(
          'ai_generate_flow',
          body: payload,
        );
      } on FunctionException catch (e) {
        final msg = _fnErrorMessage(e);
        return FunctionResponse(
          data: {
            'success': false,
            'error': 'FunctionException',
            'message': msg,
          },
          status: e.status,
        );
      } catch (e) {
        return FunctionResponse(
          data: {
            'success': false,
            'error': 'client_error',
            'message': e.toString(),
          },
          status: 500,
        );
      }
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

    // Fail fast on HTTP error status
    if (res.status != 200) {
      String? msg;
      try {
        if (res.data is Map) {
          final m = res.data as Map;
          msg = (m['error'] ?? m['message'] ?? m['detail'])?.toString();
        } else if (res.data is String) {
          msg = res.data as String;
        }
      } catch (_) {
        msg = null;
      }
      return AIFlowGenerationResponse(
        success: false,
        errorMessage:
            msg?.isNotEmpty == true ? msg : 'Generation failed (HTTP ${res.status}).',
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

    // 4) Parse response (defensive)
    try {
      final data = res.data;
      final map = data is String
          ? json.decode(data) as Map<String, dynamic>
          : Map<String, dynamic>.from(data as Map);

      final parsed = AIFlowGenerationResponse.fromJson(map);
      // If backend returned success=false but no message, add a friendly one
      if (parsed.success != true && parsed.errorMessage == null) {
        return AIFlowGenerationResponse(
          success: parsed.success,
          flowId: parsed.flowId,
          flowName: parsed.flowName,
          flowColor: parsed.flowColor,
          overviewTitle: parsed.overviewTitle,
          overviewSummary: parsed.overviewSummary,
          notes: parsed.notes,
          notesCount: parsed.notesCount,
          events: parsed.events,
          modelUsed: parsed.modelUsed,
          cached: parsed.cached,
          generationId: parsed.generationId,
          schemaVersion: parsed.schemaVersion,
          policyVersion: parsed.policyVersion,
          snapshotVersion: parsed.snapshotVersion,
          errorMessage: 'Generation failed. Please try again in a moment.',
        );
      }
      return parsed;
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
        errorMessage: 'Unable to read AI response. Please try again.',
      );
    }
  }

  String? _fnErrorMessage(FunctionException e) {
    try {
      final d = e.details;
      if (d is Map) {
        // Common locations for the OpenAI error payload
        final msg = d['message'] ??
            (d['error'] is Map ? (d['error'] as Map)['message'] : null) ??
            d['detail'];
        if (msg is String && msg.trim().isNotEmpty) return msg.trim();
      }
    } catch (_) {
      // ignore parsing errors
    }
    return e.toString();
  }
}
