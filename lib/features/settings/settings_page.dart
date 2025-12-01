import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _realTimeAlerts = false;
  bool _catchUpReminders = true;
  bool _endOfDaySummary = true;
  bool _missedOnOpen = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _realTimeAlerts = prefs.getBool('settings:realTimeAlerts') ?? false;
      _catchUpReminders = prefs.getBool('settings:catchUpReminders') ?? true;
      _endOfDaySummary = prefs.getBool('settings:endOfDaySummary') ?? true;
      _missedOnOpen = prefs.getBool('settings:missedOnOpen') ?? true;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('settings:realTimeAlerts', _realTimeAlerts);
    await prefs.setBool('settings:catchUpReminders', _catchUpReminders);
    await prefs.setBool('settings:endOfDaySummary', _endOfDaySummary);
    await prefs.setBool('settings:missedOnOpen', _missedOnOpen);
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Settings',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFD4AF37)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Notifications'),
            SwitchListTile(
              activeColor: const Color(0xFFD4AF37),
              title: const Text('Real-time alerts (PWA push where supported)'),
              subtitle: const Text(
                'Requires installed PWA + notification permission on iOS/Android browsers.',
                style: TextStyle(color: Colors.white60),
              ),
              value: _realTimeAlerts,
              onChanged: (v) {
                setState(() => _realTimeAlerts = v);
                _save();
              },
            ),
            const SizedBox(height: 8),
            _sectionTitle('Catch-up reminders'),
            SwitchListTile(
              activeColor: const Color(0xFFD4AF37),
              title: const Text('Show missed reminders on open'),
              subtitle: const Text(
                'Always available, even if push is disabled.',
                style: TextStyle(color: Colors.white60),
              ),
              value: _missedOnOpen,
              onChanged: (v) {
                setState(() => _missedOnOpen = v);
                _save();
              },
            ),
            SwitchListTile(
              activeColor: const Color(0xFFD4AF37),
              title: const Text('End-of-day summary'),
              subtitle: const Text(
                'Show a daily review modal for incomplete items.',
                style: TextStyle(color: Colors.white60),
              ),
              value: _endOfDaySummary,
              onChanged: (v) {
                setState(() => _endOfDaySummary = v);
                _save();
              },
            ),
            SwitchListTile(
              activeColor: const Color(0xFFD4AF37),
              title: const Text('Catch-up banners during the day'),
              value: _catchUpReminders,
              onChanged: (v) {
                setState(() => _catchUpReminders = v);
                _save();
              },
            ),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFF222222)),
            const SizedBox(height: 16),
            const Text(
              'These settings are stored locally for now. Push alerts will prompt for notification permission only when supported (installed PWA).',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
