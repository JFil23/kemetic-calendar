import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// Request model for AI flow generation
class AIFlowGenerationRequest {
  final String description;
  final String startDate;  // YYYY-MM-DD format
  final String endDate;    // YYYY-MM-DD format
  final String? flowName;
  final String? flowColor;
  final String? timezone;
  final bool forceRefresh;

  AIFlowGenerationRequest({
    required this.description,
    required this.startDate,
    required this.endDate,
    this.flowName,
    this.flowColor,
    this.timezone,
    this.forceRefresh = false,
  });

  Map<String, dynamic> toJson() => {
        'description': description,
        'startDate': startDate,
        'endDate': endDate,
        if (flowName != null) 'flowName': flowName,
        if (flowColor != null) 'flowColor': flowColor,
        if (timezone != null) 'timezone': timezone,
        if (forceRefresh) 'force_refresh': true,
      };
}

/// Response model from AI flow generation
class AIFlowGenerationResponse {
  final String? flowName;
  final String? flowColor;
  final List<dynamic>? notes;
  final int? notesCount;
  final bool success;
  final bool? cached;
  final String? modelUsed;

  AIFlowGenerationResponse({
    required this.success,
    this.flowName,
    this.flowColor,
    this.notes,
    this.notesCount,
    this.cached,
    this.modelUsed,
  });

  factory AIFlowGenerationResponse.fromJson(Map<String, dynamic> json) {
    final notesRaw = json['notes'];
    return AIFlowGenerationResponse(
      success: (json['success'] as bool?) ?? false,
      flowName: json['flowName'] as String? ?? json['flow_name'] as String?,
      flowColor: json['flowColor'] as String? ?? json['flow_color'] as String?,
      notes: notesRaw is List ? notesRaw : null,
      notesCount: json['notesCount'] as int? ??
          json['notes_count'] as int? ??
          (notesRaw is List ? notesRaw.length : null),
      cached: json['cached'] as bool?,
      modelUsed: json['modelUsed'] as String? ?? json['model_used'] as String?,
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
    final buffer = StringBuffer('AIFlowGenerationError: $message');
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
      _log('🚀 Starting AI flow generation...');
      _log('📝 Request: ${request.toJson()}');

      // Step 1: Check authentication
      final session = _supabase.auth.currentSession;
      if (session == null) {
        _logError('❌ No active session');
        throw AIFlowGenerationError(
          message: 'Not authenticated. Please sign in and try again.',
          statusCode: 401,
        );
      }

      final accessToken = session.accessToken;
      _log('✅ Auth token exists: ${accessToken.substring(0, 20)}...');

      // Step 2: Validate request
      if (request.description.trim().isEmpty) {
        throw AIFlowGenerationError(
          message: 'Description cannot be empty',
          statusCode: 400,
        );
      }

      // Step 3: Call Edge Function
      // NOTE: Supabase SDK automatically adds Authorization header from session
      _log('📡 Calling Edge Function: ai_generate_flow');
      
      final response = await _supabase.functions.invoke(
        'ai_generate_flow',
        body: request.toJson(),
        method: HttpMethod.post,
      );

      _log('📬 Response status: ${response.status}');
      _log('📦 Response data type: ${response.data?.runtimeType}');

      // Step 4: Handle response
      if (response.status != 200) {
        _logError('❌ HTTP ${response.status}: ${response.data}');
        throw AIFlowGenerationError(
          message: _extractErrorMessage(response.data),
          statusCode: response.status,
          details: response.data is Map ? Map<String, dynamic>.from(response.data) : null,
        );
      }

      if (response.data == null) {
        _logError('❌ Empty response data');
        throw AIFlowGenerationError(
          message: 'Edge Function returned empty response',
          statusCode: 500,
        );
      }

      // Step 5: Parse response (defensive)
      try {
        final data = response.data is String
            ? Map<String, dynamic>.from(
                jsonDecode(response.data as String) as Map,
              )
            : Map<String, dynamic>.from(response.data as Map);

        _log('✅ Response data: $data');

        // Check for error in response body
        if (data.containsKey('error')) {
          _logError('❌ Error in response: ${data['error']}');
          throw AIFlowGenerationError(
            message: data['error'].toString(),
            statusCode: response.status,
            details: data,
          );
        }

        // Step 6: Create response object
        final aiResponse = AIFlowGenerationResponse.fromJson(data);
        _log('🎉 AI generation successful!');
        _log('   - Flow name: ${aiResponse.flowName}');
        _log('   - Notes count: ${aiResponse.notesCount ?? aiResponse.notes?.length ?? 0}');

        return aiResponse;
      } catch (e, stackTrace) {
        _logError('❌ Parse error: $e');
        _logError('📚 Stack trace:\n$stackTrace');
        throw AIFlowGenerationError(
          message: 'Failed to parse response',
          statusCode: response.status,
        );
      }
      
    } on AIFlowGenerationError {
      // Re-throw our custom errors
      rethrow;
    } catch (e, stackTrace) {
      // Catch and wrap all other errors
      _logError('💥 Unexpected error: $e');
      _logError('📚 Stack trace:\n$stackTrace');
      
      throw AIFlowGenerationError(
        message: 'Unexpected error during AI generation: ${e.toString()}',
        statusCode: 500,
        details: {'originalError': e.toString()},
      );
    }
  }

  /// Extract error message from response data
  String _extractErrorMessage(dynamic data) {
    if (data == null) return 'Unknown error occurred';
    
    if (data is String) return data;
    
    if (data is Map) {
      // Try common error field names
      final error = data['error'] ?? data['message'] ?? data['detail'];
      if (error != null) return error.toString();
      
      // Return full map as string
      return data.toString();
    }
    
    return data.toString();
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
    if (kDebugMode) {
      final timestamp = DateTime.now().toIso8601String();
      print('[$timestamp] [AIFlowService] 🚨 $message');
    }
  }
}

/// Extension to check if Edge Function exists
extension AIFlowGenerationServiceCheck on AIFlowGenerationService {
  /// Test if the Edge Function is deployed and accessible
  Future<bool> isEdgeFunctionAvailable() async {
    try {
      final response = await _supabase.functions.invoke(
        'ai_generate_flow',
        body: {'test': true},
        method: HttpMethod.post,
      );
      return response.status == 200 || response.status == 400; // 400 is ok for test
    } catch (e) {
      return false;
    }
  }
}




