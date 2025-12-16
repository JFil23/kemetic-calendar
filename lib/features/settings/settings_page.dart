import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../calendar/calendar_page.dart';
import 'us_holiday_seeder.dart';
import '../../services/push_notifications.dart';
import '../../services/calendar_sync_service.dart';

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
  bool _usHolidaysEnabled = false;
  bool _seedingHolidays = false;
  bool _syncingCalendar = false;
  bool _loading = true;
  bool _requestingPush = false;
  String? _pushStatus;
  String? _calendarSyncStatus;

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
      _usHolidaysEnabled = prefs.getBool('settings:usHolidaysEnabled') ?? false;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('settings:realTimeAlerts', _realTimeAlerts);
    await prefs.setBool('settings:catchUpReminders', _catchUpReminders);
    await prefs.setBool('settings:endOfDaySummary', _endOfDaySummary);
    await prefs.setBool('settings:missedOnOpen', _missedOnOpen);
    await prefs.setBool('settings:usHolidaysEnabled', _usHolidaysEnabled);
  }

  Future<void> _toggleUsHolidays(bool enabled) async {
    final previous = _usHolidaysEnabled;

    setState(() {
      _usHolidaysEnabled = enabled;
      _seedingHolidays = true;
    });
    await _save();

    try {
      final calendarState = CalendarPage.globalKey.currentState;
      if (enabled) {
        final added = await UsHolidaySeeder.seed(years: 2);
        if (calendarState != null) {
          await calendarState.reloadFromOutside();
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Loaded $added US holidays'),
              backgroundColor: Colors.green.shade700,
            ),
          );
        }
      } else {
        await UsHolidaySeeder.clear();
        if (calendarState != null) {
          await calendarState.reloadFromOutside();
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Removed US holiday notes'),
              backgroundColor: Colors.green.shade700,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _usHolidaysEnabled = previous;
        });
        await _save();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is StateError ? e.message : 'Could not update holidays: $e',
            ),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _seedingHolidays = false;
        });
      }
    }
  }

  Future<void> _syncCalendarNow() async {
    final client = Supabase.instance.client;
    if (client.auth.currentSession == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Sign in to sync your calendar.'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      return;
    }

    setState(() {
      _syncingCalendar = true;
    });

    try {
      final sync = sharedCalendarSyncService(client);
      await sync.sync();

      final calendarState = CalendarPage.globalKey.currentState;
      if (calendarState != null) {
        await calendarState.reloadFromOutside();
      }

      if (mounted) {
        final ts = _formatTimestamp(DateTime.now());
        setState(() {
          _calendarSyncStatus = 'Last sync requested: $ts'
              '${kIsWeb ? ' (PWA native calendar access may be limited)' : ''}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              kIsWeb
                  ? 'Requested calendar sync. PWAs on iOS may not expose the native calendar.'
                  : 'Requested calendar sync on this device.',
            ),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _calendarSyncStatus = 'Sync failed: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Calendar sync failed: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _syncingCalendar = false;
        });
      }
    }
  }

  String _formatTimestamp(DateTime dt) {
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$mm/$dd $hh:$min';
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
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.black,
              ),
              onPressed: _requestingPush
                  ? null
                  : () async {
                      setState(() {
                        _requestingPush = true;
                        _pushStatus = null;
                      });
                      final client = Supabase.instance.client;
                      final push = PushNotifications.instance(client);
                      final token = await push.requestAndRegisterToken();
                      if (!mounted) return;
                      setState(() {
                        _requestingPush = false;
                        _pushStatus = token == null ? 'Permission denied or no token' : 'Token saved';
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(token == null
                              ? 'Notifications not enabled (grant permission to receive push).'
                              : 'Notifications enabled on this device.'),
                          backgroundColor: token == null ? Colors.red.shade700 : Colors.green.shade700,
                        ),
                      );
                    },
              child: Text(_requestingPush ? 'Requesting…' : 'Enable notifications on this device'),
            ),
            if (_pushStatus != null) ...[
              const SizedBox(height: 6),
              Text(
                _pushStatus!,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
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
            const SizedBox(height: 12),
            _sectionTitle('Calendar'),
            SwitchListTile(
              activeColor: const Color(0xFFD4AF37),
              title: const Text('US holidays'),
              subtitle: Text(
                _seedingHolidays
                    ? 'Applying holiday notes...'
                    : 'Auto-add standard US holidays as notes.',
                style: const TextStyle(color: Colors.white60),
              ),
              value: _usHolidaysEnabled,
              onChanged: _seedingHolidays ? null : (v) => _toggleUsHolidays(v),
              secondary: _seedingHolidays
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFD4AF37),
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.black,
              ),
              icon: _syncingCalendar
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                    )
                  : const Icon(Icons.sync),
              label: Text(_syncingCalendar ? 'Syncing…' : 'Sync calendar now'),
              onPressed: _syncingCalendar ? null : _syncCalendarNow,
            ),
            const SizedBox(height: 6),
            const Text(
              'Push/pull with your device calendar. On PWAs (iOS Safari), native calendar access may be limited.',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
            if (_calendarSyncStatus != null) ...[
              const SizedBox(height: 6),
              Text(
                _calendarSyncStatus!,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
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
