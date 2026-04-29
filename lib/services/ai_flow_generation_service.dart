// lib/services/ai_flow_generation_service.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ai_flow_generation_response.dart';

class AIFlowGenerationService {
  final SupabaseClient _sb;

  AIFlowGenerationService(this._sb);

  static const int _maxSourceTextChars = 48 * 1024;
  static const int _maxSourceBlocks = 24;

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
    String? timezone, // IANA string (e.g., "America/Los_Angeles")
    String? sourceText,
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

    final sanitizedDescription = description.trim();
    final sanitizedSourceText = aiFlowSanitizeSourceTextForInvoke(
      sourceText,
      maxChars: _maxSourceTextChars,
      maxBlocks: _maxSourceBlocks,
    );

    // 2) Build payload (use passed dates)
    final payload = <String, dynamic>{
      'description': sanitizedDescription,
      'startDate': _fmt(startDate),
      'endDate': _fmt(endDate),
      if (flowColor != null) 'flowColor': flowColor,
      if (timezone != null) 'timezone': timezone,
      if (sanitizedSourceText != null && sanitizedSourceText.isNotEmpty)
        'source_text': sanitizedSourceText,
      if (forceRefresh) 'force_refresh': true,
      // ⚠️ Do NOT send useKemetic; function doesn't accept it
    };

    debugPrint(
      '[AIFlowService] invoke ai_generate_flow descChars=${sanitizedDescription.length} '
      'sourceChars=${sanitizedSourceText?.length ?? 0} '
      'range=${payload['startDate']}..${payload['endDate']}',
    );

    // 3) Auth-retry wrapped invoke (SDK auto-attaches JWT)
    final FunctionResponse res =
        await _withAuthRetry(() async {
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
                'message': msg,
                'error_code': 'FunctionException',
              },
              status: e.status,
            );
          } catch (e) {
            final msg = aiFlowBestErrorMessage(
              e,
              fallback: 'Unable to reach flow generation.',
            );
            return FunctionResponse(
              data: {
                'success': false,
                'message': msg,
                'error_code': 'client_error',
              },
              status: 500,
            );
          }
        }).timeout(
          const Duration(minutes: 4),
          onTimeout: () => FunctionResponse(
            data: <String, dynamic>{
              'success': false,
              'error': 'timeout',
              'message':
                  'Generation timed out. If this was a very long 90-day run, try again—'
                  'the server may need a second pass when traffic is high.',
            },
            status: 504,
          ),
        );

    // Fail fast on HTTP error status
    if (res.status != 200) {
      final msg = aiFlowBestErrorMessage(
        res.data,
        fallback: 'Generation failed (HTTP ${res.status}).',
      );
      return AIFlowGenerationResponse(
        success: false,
        errorMessage: msg,
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
      if (d is String) {
        final parsed = _tryDecodeJsonObject(d);
        if (parsed != null) {
          final msg = aiFlowBestErrorMessage(parsed);
          if (msg != null && msg.isNotEmpty) return msg;
        }
        if (d.trim().isNotEmpty) return d.trim();
      }
      if (d is Map) {
        final msg = aiFlowBestErrorMessage(d);
        if (msg != null && msg.isNotEmpty) return msg;
      }
    } catch (_) {
      // ignore parsing errors
    }
    return aiFlowBestErrorMessage(e, fallback: e.toString());
  }
}

@visibleForTesting
String? aiFlowSanitizeSourceTextForInvoke(
  String? raw, {
  int maxChars = 48 * 1024,
  int maxBlocks = 24,
}) {
  if (raw == null) return null;
  final normalized = raw.replaceAll('\r', '').trim();
  if (normalized.isEmpty) return null;

  final blocks = normalized
      .split(RegExp(r'\n\s*\n+'))
      .map((block) => block.trim())
      .where((block) => block.isNotEmpty)
      .where((block) => !_looksLikeFlowTelemetryBlock(block))
      .toList();

  final cleaned = blocks.isEmpty ? normalized : blocks.join('\n\n');
  if (cleaned.length <= maxChars) return cleaned;

  final total = blocks.length;
  if (total == 0) {
    return '${cleaned.substring(0, maxChars - 1).trimRight()}…';
  }

  final ranked = <({String block, int score, int index})>[];
  for (var i = 0; i < total; i++) {
    ranked.add((
      block: blocks[i],
      score: _scoreFlowSourceBlock(blocks[i], i, total),
      index: i,
    ));
  }
  ranked.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    return a.index.compareTo(b.index);
  });

  final selected = <int>{0, total - 1};
  for (final item in ranked) {
    if (selected.length >= maxBlocks) break;
    selected.add(item.index);
  }

  final ordered = selected.toList()..sort();
  final chosen = <String>[];
  var used = 0;

  for (final index in ordered) {
    final block = blocks[index];
    final nextUsed = used + (chosen.isEmpty ? 0 : 2) + block.length;
    if (nextUsed > maxChars) break;
    chosen.add(block);
    used = nextUsed;
  }

  if (chosen.isEmpty) {
    return '${cleaned.substring(0, maxChars - 1).trimRight()}…';
  }

  return chosen.join('\n\n');
}

@visibleForTesting
String? aiFlowBestErrorMessage(Object? raw, {String? fallback}) {
  final message = _extractAiFlowErrorMessage(raw);
  if (message != null && message.isNotEmpty) return message;
  return fallback;
}

String? _extractAiFlowErrorMessage(Object? raw) {
  if (raw == null) return null;

  if (raw is String) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final parsed = _tryDecodeJsonObject(trimmed);
    if (parsed != null) {
      final nested = _extractAiFlowErrorMessage(parsed);
      if (nested != null && nested.isNotEmpty) return nested;
    }
    return _isGenericAiFlowErrorLabel(trimmed) ? null : trimmed;
  }

  if (raw is Map) {
    final map = Map<String, dynamic>.from(raw);
    for (final key in ['message', 'detail', 'errorMessage', 'msg']) {
      final nested = _extractAiFlowErrorMessage(map[key]);
      if (nested != null && nested.isNotEmpty) return nested;
    }

    final errorValue = map['error'];
    if (errorValue is Map || errorValue is String) {
      final nested = _extractAiFlowErrorMessage(errorValue);
      if (nested != null && nested.isNotEmpty) return nested;
    }

    for (final key in ['error_code', 'code', 'statusText']) {
      final nested = _extractAiFlowErrorMessage(map[key]);
      if (nested != null && nested.isNotEmpty) return nested;
    }

    final compact = map.toString().trim();
    return compact.isEmpty ? null : compact;
  }

  if (raw is FunctionException) {
    final nested = _extractAiFlowErrorMessage(raw.details);
    if (nested != null && nested.isNotEmpty) return nested;
    final text = raw.toString().trim();
    return _isGenericAiFlowErrorLabel(text) ? null : text;
  }

  final text = raw.toString().trim();
  if (text.isEmpty || _isGenericAiFlowErrorLabel(text)) return null;
  if (text.startsWith('Exception: ')) {
    return text.substring('Exception: '.length);
  }
  return text;
}

Map<String, dynamic>? _tryDecodeJsonObject(String raw) {
  try {
    final decoded = json.decode(raw);
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
  } catch (_) {
    // ignore
  }
  return null;
}

bool _isGenericAiFlowErrorLabel(String value) {
  final lower = value.trim().toLowerCase();
  return lower == 'client_error' ||
      lower == 'functionexception' ||
      lower == 'function exception' ||
      lower == 'error' ||
      lower == 'exception';
}

bool _looksLikeFlowTelemetryBlock(String block) {
  final compact = block.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (compact.isEmpty) return false;
  final jsonKeys = RegExp(r'"[\w.-]+":').allMatches(compact).length;
  final telemetryHits = RegExp(
    r'(event_message|deployment_id|execution_id|function_id|project_ref|served_by|booted|shutdown|wallclocktime|cpu_time_used|memory_used|timestamp|version|region)',
    caseSensitive: false,
  ).allMatches(compact).length;
  return telemetryHits >= 2 ||
      (compact.startsWith('{') && compact.endsWith('}') && jsonKeys >= 4);
}

int _scoreFlowSourceBlock(String block, int index, int total) {
  var score = 0;
  if (index == 0 || index == total - 1) score += 3;
  if (RegExp(r'^(?:#{1,6}\s|[A-Z][^.!?\n]{3,80}:)').hasMatch(block)) {
    score += 8;
  }
  if (RegExp(r'^(?:[-*•]|\d+\.)\s', multiLine: true).hasMatch(block)) {
    score += 8;
  }
  if (RegExp(
    r'\b(day|week|phase|milestone|constraint|goal|deliverable|checkpoint|decision|priority|theme|meal|breakfast|lunch|dinner|snack|protein|vegetable|fruit|fat|carb|gut|hydration)\b',
    caseSensitive: false,
  ).hasMatch(block)) {
    score += 10;
  }
  if (RegExp(r'https?:\/\/|www\.', caseSensitive: false).hasMatch(block)) {
    score += 4;
  }
  if (RegExp(r'\d').hasMatch(block)) score += 3;
  if (block.length >= 120 && block.length <= 1800) score += 4;
  return score;
}
