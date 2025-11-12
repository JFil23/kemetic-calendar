import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

/// Request model for AI flow generation
class AIFlowGenerationRequest {
  final String description;
  final String startDate;  // YYYY-MM-DD format
  final String endDate;    // YYYY-MM-DD format
  final String? flowName;
  final String? flowColor;
  final String? timezone;

  AIFlowGenerationRequest({
    required this.description,
    required this.startDate,
    required this.endDate,
    this.flowName,
    this.flowColor,
    this.timezone,
  });

  Map<String, dynamic> toJson() => {
        'description': description,
        'startDate': startDate,
        'endDate': endDate,
        if (flowName != null) 'flowName': flowName,
        // ✅ Always include flowColor with default fallback
        'flowColor': (flowColor != null && flowColor!.isNotEmpty) ? flowColor : '#4dd0e1',
        if (timezone != null) 'timezone': timezone,
      };
}

/// Response model from AI flow generation
class AIFlowGenerationResponse {
  final int? flowId;
  final String flowName;
  final String flowColor;
  final List<FlowRule> rules;
  final String? notes;

  AIFlowGenerationResponse({
    this.flowId,
    required this.flowName,
    required this.flowColor,
    required this.rules,
    this.notes,
  });

  factory AIFlowGenerationResponse.fromJson(Map<String, dynamic> json) {
    return AIFlowGenerationResponse(
      flowId: json['flowId'] as int?,
      flowName: json['flowName'] as String,
      flowColor: json['flowColor'] as String,
      rules: ((json['rules'] as List?) ?? [])
          .map((r) => FlowRule.fromJson(r as Map<String, dynamic>))
          .toList(),
      notes: json['notes'] as String?,
    );
  }
}

/// Flow rule model
class FlowRule {
  final String type; // 'week', 'decan', 'dates'
  final Map<String, dynamic> data;

  FlowRule({
    required this.type,
    required this.data,
  });

  factory FlowRule.fromJson(Map<String, dynamic> json) {
    return FlowRule(
      type: json['type'] as String,
      data: Map<String, dynamic>.from(json)..remove('type'),
    );
  }

  Map<String, dynamic> toJson() => {'type': type, ...data};
}

/// Custom exception for AI generation errors
class AIFlowGenerationError implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? details;

  AIFlowGenerationError({
    required this.message,
    this.statusCode,
    this.details,
  });

  @override
  String toString() {
    final buffer = StringBuffer('AI Generation Error: $message');
    if (statusCode != null) {
      buffer.write(' (HTTP $statusCode)');
    }
    if (details != null) {
      buffer.write('\nDetails: $details');
    }
    return buffer.toString();
  }
}

/// Service for AI-powered flow generation
class AIFlowGenerationService {
  final SupabaseClient _supabase;

  AIFlowGenerationService(this._supabase);

  /// Generate a flow using AI
  /// 
  /// Throws [AIFlowGenerationError] if generation fails.
  Future<AIFlowGenerationResponse> generateFlow(
    AIFlowGenerationRequest request,
  ) async {
    try {
      _log('🚀 AI Generation Starting...');
      _log('📝 Description: "${request.description}"');
      _log('📅 Date range: ${request.startDate} to ${request.endDate}');
      _log('🎨 Color: ${request.flowColor}');
      
      // Log the full request JSON
      final requestJson = request.toJson();
      _log('📦 Request JSON: $requestJson');
      _log('📏 Request size: ${requestJson.toString().length} bytes');

      // Step 1: FORCE session refresh to get fresh token
      _log('🔄 Refreshing session to get fresh token...');
      try {
        final refreshResult = await _supabase.auth.refreshSession();
        if (refreshResult.session == null) {
          _logError('❌ Session refresh failed - no session returned');
          throw AIFlowGenerationError(
            message: 'Please sign out and sign back in',
            statusCode: 401,
          );
        }
        _log('✅ Session refreshed successfully');
      } catch (e) {
        _logError('❌ Session refresh error: $e');
        throw AIFlowGenerationError(
          message: 'Session refresh failed. Please sign out and back in.',
          statusCode: 401,
        );
      }

      // Step 2: Check authentication with fresh session
      final session = _supabase.auth.currentSession;
      if (session == null) {
        _logError('❌ No active session after refresh');
        throw AIFlowGenerationError(
          message: 'Please sign in to use AI generation',
          statusCode: 401,
        );
      }

      _log('✅ Authenticated as ${session.user.email}');
      _log('🔑 Token expires: ${DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000)}');

      // Step 3: Call Edge Function with fresh token
      _log('📡 Calling ai_generate_flow Edge Function...');
      
      final response = await _supabase.functions.invoke(
        'ai_generate_flow',
        body: requestJson,
        method: HttpMethod.post,
      );

      _log('📬 Response received: HTTP ${response.status}');
      _log('📦 Response data: ${response.data}');

      // Step 4: Handle non-200 responses
      if (response.status != 200) {
        final errorMessage = _extractDetailedError(response);
        _logError('❌ Edge Function error: $errorMessage');
        
        throw AIFlowGenerationError(
          message: errorMessage,
          statusCode: response.status,
          details: response.data is Map ? Map<String, dynamic>.from(response.data) : null,
        );
      }

      // Step 5: Parse successful response
      if (response.data == null) {
        throw AIFlowGenerationError(
          message: 'Edge Function returned empty response',
          statusCode: 500,
        );
      }

      // ✅ FIX 1: Parse JSON string responses properly
      Map<String, dynamic> data;
      if (response.data is String) {
        // Parse JSON string
        try {
          data = jsonDecode(response.data as String) as Map<String, dynamic>;
          _log('✅ Parsed JSON string response');
        } catch (e) {
          _logError('❌ Failed to parse JSON string: $e');
          data = <String, dynamic>{};
        }
      } else if (response.data is Map) {
        data = Map<String, dynamic>.from(response.data as Map);
        _log('✅ Using Map response directly');
      } else {
        // Fallback for any other type
        _logError('⚠️ Unexpected response.data type: ${response.data.runtimeType}');
        data = Map<String, dynamic>.from(response.data ?? {});
      }

      // Check for timeout fallback
      if (data['success'] == false && data['fallback'] == true) {
        _logError('⚠️ Timeout fallback received');
        throw AIFlowGenerationError(
          message: data['message'] ?? 'AI generation timed out. Try a shorter date range (3-10 days).',
          statusCode: response.status,
          details: data,
        );
      }

      // Check for error in response body
      if (data.containsKey('error')) {
        throw AIFlowGenerationError(
          message: data['error'].toString(),
          statusCode: response.status,
          details: data,
        );
      }

      _log('✅ AI generation successful!');
      final aiResponse = AIFlowGenerationResponse.fromJson(data);
      _log('   Flow: ${aiResponse.flowName}');
      _log('   Rules: ${aiResponse.rules.length}');

      return aiResponse;
      
    } on AIFlowGenerationError {
      rethrow;
    } catch (e, stackTrace) {
      _logError('💥 Unexpected error: $e');
      if (kDebugMode) {
        print('Stack trace:\n$stackTrace');
      }
      
      throw AIFlowGenerationError(
        message: 'Unexpected error: ${e.toString()}',
        statusCode: 500,
        details: {'originalError': e.toString()},
      );
    }
  }

  /// Extract detailed error message from Edge Function response
  String _extractDetailedError(dynamic response) {
    final data = response.data;
    
    // Try to extract error message from various formats
    if (data == null) {
      return 'Edge Function returned no data (HTTP ${response.status})';
    }
    
    if (data is String) {
      return data;
    }
    
    if (data is Map) {
      // Common error formats
      if (data.containsKey('error')) {
        final error = data['error'];
        
        // Handle nested error objects
        if (error is Map) {
          final message = error['message'] ?? error['error'] ?? error.toString();
          final code = error['code'] ?? '';
          return code.isNotEmpty ? '[$code] $message' : message.toString();
        }
        
        return error.toString();
      }
      
      if (data.containsKey('message')) {
        return data['message'].toString();
      }
      
      if (data.containsKey('detail')) {
        return data['detail'].toString();
      }
      
      // Return full map as JSON string
      return data.toString();
    }
    
    return 'Unknown error (HTTP ${response.status}): ${data.toString()}';
  }

  /// Log helper for debug mode
  void _log(String message) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toIso8601String();
      print('[$timestamp] [AIFlowService] $message');
    }
  }

  /// Log error helper
  void _logError(String message) {
    final timestamp = DateTime.now().toIso8601String();
    print('[$timestamp] [AIFlowService] 🚨 $message');
  }
}



