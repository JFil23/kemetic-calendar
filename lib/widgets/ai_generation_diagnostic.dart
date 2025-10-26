import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 🔧 DIAGNOSTIC WIDGET - Add this temporarily to test AI generation
/// 
/// This will help identify exactly what's failing:
/// 1. Authentication check
/// 2. Edge Function availability
/// 3. Actual AI generation call
class AIGenerationDiagnosticWidget extends StatefulWidget {
  const AIGenerationDiagnosticWidget({super.key});

  @override
  State<AIGenerationDiagnosticWidget> createState() =>
      _AIGenerationDiagnosticWidgetState();
}

class _AIGenerationDiagnosticWidgetState
    extends State<AIGenerationDiagnosticWidget> {
  final _logs = <String>[];
  bool _testing = false;

  void _log(String message) {
    setState(() {
      final timestamp = DateTime.now().toString().substring(11, 19);
      _logs.add('[$timestamp] $message');
    });
    print('[AIGenDiag] $message');
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      _logs.clear();
      _testing = true;
    });

    try {
      final supabase = Supabase.instance.client;

      // TEST 1: Check authentication
      _log('🔍 TEST 1: Checking authentication...');
      final session = supabase.auth.currentSession;
      
      if (session == null) {
        _log('❌ FAIL: No active session');
        _log('   → Please sign in first');
        return;
      }
      
      final userId = session.user.id;
      final email = session.user.email ?? 'unknown';
      _log('✅ PASS: Authenticated');
      _log('   → User ID: $userId');
      _log('   → Email: $email');
      _log('   → Token: ${session.accessToken.substring(0, 20)}...');

      // TEST 2: Check Edge Function availability
      _log('');
      _log('🔍 TEST 2: Checking Edge Function...');
      
      try {
        final testResponse = await supabase.functions.invoke(
          'ai_generate_flow',
          body: {'_test': true, '_diagnostic': true},
          method: HttpMethod.post,
        );
        
        _log('✅ PASS: Edge Function reachable');
        _log('   → HTTP Status: ${testResponse.status}');
        _log('   → Response type: ${testResponse.data?.runtimeType}');
        
        if (testResponse.status == 404) {
          _log('⚠️  WARNING: Function not found (404)');
          _log('   → Edge Function might not be deployed');
          _log('   → Check Supabase Dashboard > Edge Functions');
        }
        
      } catch (e) {
        _log('❌ FAIL: Cannot reach Edge Function');
        _log('   → Error: $e');
        _log('   → Edge Function might not be deployed');
        return;
      }

      // TEST 3: Try actual generation with minimal request
      _log('');
      _log('🔍 TEST 3: Testing AI generation...');
      
      final testRequest = {
        'description': 'Test flow for diagnostics',
        'startDate': '2025-10-25',
        'endDate': '2025-10-27',
      };
      
      _log('   → Sending request: $testRequest');
      
      try {
        final genResponse = await supabase.functions.invoke(
          'ai_generate_flow',
          body: testRequest,
          method: HttpMethod.post,
        );
        
        _log('   → HTTP Status: ${genResponse.status}');
        _log('   → Response: ${genResponse.data}');
        
        if (genResponse.status == 200) {
          _log('✅ PASS: AI generation working!');
          _log('   → Your issue is likely in the request format');
          _log('   → or date/calendar conversion');
        } else {
          _log('❌ FAIL: HTTP ${genResponse.status}');
          
          // Parse error details
          if (genResponse.data is Map) {
            final errorData = genResponse.data as Map;
            if (errorData.containsKey('error')) {
              _log('   → Error: ${errorData['error']}');
            }
            if (errorData.containsKey('details')) {
              _log('   → Details: ${errorData['details']}');
            }
          } else {
            _log('   → Raw response: ${genResponse.data}');
          }
        }
        
      } catch (e, stackTrace) {
        _log('❌ FAIL: Generation threw exception');
        _log('   → Error: $e');
        _log('   → This might be:');
        _log('      • Edge Function not deployed');
        _log('      • Missing API keys in Edge Function');
        _log('      • LLM provider error (OpenAI/Anthropic)');
        _log('      • Database/RLS issue');
      }

      _log('');
      _log('═══════════════════════════════════');
      _log('📋 DIAGNOSTIC SUMMARY');
      _log('═══════════════════════════════════');
      _log('If all tests passed: Check your request format');
      _log('If test 3 failed: Check Edge Function logs in Supabase');
      _log('If test 2 failed: Deploy the Edge Function first');
      _log('If test 1 failed: Sign in to the app first');
      
    } finally {
      setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Generation Diagnostics'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // Run button
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _testing ? null : _runDiagnostics,
              icon: _testing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(_testing ? 'Running Tests...' : 'Run Diagnostics'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37), // Gold
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),
          
          // Instructions
          if (_logs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'This diagnostic tool will:\n'
                '1. Check if you\'re signed in\n'
                '2. Check if the Edge Function exists\n'
                '3. Test AI generation\n\n'
                'Tap "Run Diagnostics" to start',
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ),
          
          // Log output
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1B1F),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
              child: ListView.builder(
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  final log = _logs[index];
                  Color textColor = Colors.white70;
                  
                  if (log.contains('✅')) textColor = Colors.greenAccent;
                  if (log.contains('❌')) textColor = Colors.redAccent;
                  if (log.contains('⚠️')) textColor = Colors.orangeAccent;
                  if (log.contains('TEST')) textColor = Colors.cyanAccent;
                  if (log.contains('═══')) textColor = const Color(0xFFD4AF37);
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      log,
                      style: TextStyle(
                        color: textColor,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          
          // Copy logs button
          if (_logs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton.icon(
                onPressed: () {
                  // Copy logs to clipboard (you'll need clipboard package)
                  final logsText = _logs.join('\n');
                  print('=== DIAGNOSTIC LOGS ===\n$logsText');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Logs printed to console'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                icon: const Icon(Icons.copy),
                label: const Text('Print Logs to Console'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFD4AF37)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
