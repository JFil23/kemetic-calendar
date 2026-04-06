import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/push_notifications.dart';
import '../shared/glossy_text.dart';
import '../main.dart' show supabase;

class PushDiagnosticsPage extends StatefulWidget {
  const PushDiagnosticsPage({super.key});

  @override
  State<PushDiagnosticsPage> createState() => _PushDiagnosticsPageState();
}

class _PushDiagnosticsPageState extends State<PushDiagnosticsPage> {
  String _status = 'Idle';
  String _userId = '<none>';
  String _permission = '<unknown>';
  String _tokenMasked = '<none>';
  String _lastError = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final client = supabase;
    final pn = PushNotifications.instance(client);
    final u = client.auth.currentUser;
    setState(() {
      _userId = u?.id ?? '<none>';
      _status = 'Checking...';
      _permission = '<unknown>';
      _tokenMasked = '<none>';
      _lastError = '';
    });

    try {
      final ok = await pn.initAndRequestPermission();
      _permission = ok ? 'granted' : 'denied';
      final token = await pn.requestAndRegisterToken();
      if (token == null) {
        _tokenMasked = '<null>';
        _status = 'No token';
      } else {
        _tokenMasked = token.length > 10
            ? '${token.substring(0, 6)}...${token.substring(token.length - 6)} (len=${token.length})'
            : token;
        _status = 'Token registered (see logs for result)';
      }
    } catch (e) {
      _lastError = e.toString();
      _status = 'Error';
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const Scaffold(
        body: Center(child: Text('Push diagnostics available in debug only')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Push Diagnostics (debug)'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row('User ID', _userId),
            _row('Permission', _permission),
            _row('Token', _tokenMasked),
            _row('Status', _status),
            if (_lastError.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Last error:', style: TextStyle(color: Colors.redAccent)),
              Text(_lastError, style: const TextStyle(color: Colors.redAccent)),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _refresh,
                style: ElevatedButton.styleFrom(
                  backgroundColor: KemeticGold.base,
                  foregroundColor: Colors.black,
                ),
                child: KemeticGold.text(
                  'Retry push registration',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
