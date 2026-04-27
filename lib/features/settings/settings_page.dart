import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/shared/glossy_text.dart';

import '../calendar/calendar_page.dart';
import '../calendar/notify.dart';
import 'settings_prefs.dart';
import 'us_holiday_seeder.dart';
import '../../services/calendar_sync_service.dart';
import '../../services/push_notifications.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _realTimeAlerts = false;
  bool _autoCalendarSync = true;
  bool _usHolidaysEnabled = false;
  bool _seedingHolidays = false;
  bool _syncingCalendar = false;
  bool _unlinkingCalendar = false;
  bool _loading = true;
  bool _requestingPush = false;
  bool _loadingPushDiagnostics = false;
  bool _sendingPushTest = false;
  String? _pushStatus;
  CalendarSyncStatus? _calendarSyncStatus;
  PushRegistrationDiagnostics? _pushDiagnostics;

  bool get _hasSession => Supabase.instance.client.auth.currentSession != null;
  bool get _nativeCalendarSyncAvailable => !kIsWeb;
  bool get _calendarBusy => _syncingCalendar || _unlinkingCalendar;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    await SettingsPrefs.clearLegacyReminderPrefs(prefs);

    CalendarSyncStatus? calendarStatus;
    if (_nativeCalendarSyncAvailable) {
      final sync = sharedCalendarSyncService(Supabase.instance.client);
      calendarStatus = await sync.getStatus();
    }

    if (!mounted) return;
    setState(() {
      _realTimeAlerts = SettingsPrefs.realTimeAlertsEnabledFrom(prefs);
      _autoCalendarSync =
          _nativeCalendarSyncAvailable &&
          SettingsPrefs.autoCalendarSyncEnabledFrom(prefs);
      _usHolidaysEnabled = SettingsPrefs.usHolidaysEnabledFrom(prefs);
      _calendarSyncStatus = calendarStatus;
      _loading = false;
    });
    unawaited(_refreshPushDiagnostics());
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SettingsPrefs.realTimeAlertsKey, _realTimeAlerts);
    await prefs.setBool(SettingsPrefs.autoCalendarSyncKey, _autoCalendarSync);
    await prefs.setBool(SettingsPrefs.usHolidaysEnabledKey, _usHolidaysEnabled);
  }

  Future<void> _refreshCalendarStatus() async {
    if (!_nativeCalendarSyncAvailable) return;
    final status = await sharedCalendarSyncService(
      Supabase.instance.client,
    ).getStatus();
    if (!mounted) return;
    setState(() {
      _calendarSyncStatus = status;
    });
  }

  Future<void> _setRealTimeAlerts(bool enabled) async {
    final client = Supabase.instance.client;
    final push = PushNotifications.instance(client);
    final messenger = ScaffoldMessenger.of(context);

    if (enabled && !_hasSession) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text(
            'Sign in before enabling push alerts on this device.',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    setState(() {
      _realTimeAlerts = enabled;
      _requestingPush = enabled;
      _pushStatus = enabled
          ? 'Requesting permission and linking this device for push alerts...'
          : 'Push alerts are off on this device.';
    });

    if (!enabled) {
      await _save();
      await push.unregister();
      await Notify.syncLocalDeliveryMode();
      if (!mounted) return;
      setState(() {
        _requestingPush = false;
      });
      await _refreshPushDiagnostics();
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Push alerts disabled on this device.'),
          backgroundColor: Colors.green.shade700,
        ),
      );
      return;
    }

    final token = await push.requestAndRegisterToken();
    if (!mounted) return;

    final success = token != null;
    final failureMessage =
        push.lastRegistrationError ??
        'Push permission was denied, Firebase is not configured, or the device token could not be created.';
    setState(() {
      _requestingPush = false;
      _realTimeAlerts = success;
      _pushStatus = success
          ? 'Push alerts are enabled for this device.'
          : failureMessage;
    });
    await _save();
    await Notify.syncLocalDeliveryMode();
    await _refreshPushDiagnostics();

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Push alerts enabled on this device.' : failureMessage,
        ),
        backgroundColor: success ? Colors.green.shade700 : Colors.red.shade700,
      ),
    );
  }

  Future<void> _refreshPushDiagnostics() async {
    if (!mounted) return;
    setState(() {
      _loadingPushDiagnostics = true;
    });

    final diagnostics = await PushNotifications.instance(
      Supabase.instance.client,
    ).getDiagnostics();

    if (!mounted) return;
    setState(() {
      _pushDiagnostics = diagnostics;
      _loadingPushDiagnostics = false;
    });
  }

  Future<void> _sendPushTest() async {
    if (!_hasSession) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _sendingPushTest = true;
      _pushStatus = 'Dispatching a test push through send_push...';
    });

    final result = await PushNotifications.instance(
      Supabase.instance.client,
    ).sendSelfTestPush();

    if (!mounted) return;
    setState(() {
      _sendingPushTest = false;
      _pushStatus = result.message;
    });
    await _refreshPushDiagnostics();

    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.ok
            ? Colors.green.shade700
            : Colors.red.shade700,
      ),
    );
  }

  Future<void> _setAutoCalendarSync(bool enabled) async {
    if (!_nativeCalendarSyncAvailable) return;

    final messenger = ScaffoldMessenger.of(context);
    final sync = sharedCalendarSyncService(Supabase.instance.client);

    setState(() {
      _autoCalendarSync = enabled;
      _syncingCalendar = enabled;
    });
    await _save();

    if (!enabled) {
      sync.stop();
      if (!mounted) return;
      setState(() {
        _syncingCalendar = false;
      });
      messenger.showSnackBar(
        SnackBar(
          content: const Text(
            'Automatic calendar sync turned off. You can still sync manually.',
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );
      return;
    }

    if (!_hasSession) {
      if (!mounted) return;
      setState(() {
        _syncingCalendar = false;
      });
      messenger.showSnackBar(
        SnackBar(
          content: const Text(
            'Automatic calendar sync will start after you sign in.',
          ),
          backgroundColor: Colors.orange.shade700,
        ),
      );
      return;
    }

    try {
      await sync.start();
      await _refreshCalendarStatus();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Automatic calendar sync turned on.'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not start automatic calendar sync: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _syncingCalendar = false;
        });
      }
    }
  }

  Future<void> _toggleUsHolidays(bool enabled) async {
    final previous = _usHolidaysEnabled;
    final messenger = ScaffoldMessenger.of(context);

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
          messenger.showSnackBar(
            SnackBar(
              content: Text('Loaded $added U.S. holiday notes.'),
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
          messenger.showSnackBar(
            SnackBar(
              content: const Text('Removed U.S. holiday notes.'),
              backgroundColor: Colors.green.shade700,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _usHolidaysEnabled = previous;
      });
      await _save();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e is StateError ? e.message : 'Could not update holiday notes: $e',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
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
    final messenger = ScaffoldMessenger.of(context);

    if (!_nativeCalendarSyncAvailable) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text(
            'Native calendar sync is only available in the iOS/Android app.',
          ),
          backgroundColor: Colors.orange.shade700,
        ),
      );
      return;
    }

    if (!_hasSession) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Sign in to sync your device calendar.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    setState(() {
      _syncingCalendar = true;
    });

    try {
      final sync = sharedCalendarSyncService(client);
      final result = await sync.sync(interactive: true);

      if (result.didSync) {
        final calendarState = CalendarPage.globalKey.currentState;
        if (calendarState != null) {
          await calendarState.reloadFromOutside();
        }
      }

      await _refreshCalendarStatus();
      if (mounted) {
        _showCalendarSyncResult(result);
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Calendar sync failed: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _syncingCalendar = false;
        });
      }
    }
  }

  Future<void> _unlinkCalendarAccounts() async {
    final client = Supabase.instance.client;
    final messenger = ScaffoldMessenger.of(context);

    if (!_nativeCalendarSyncAvailable) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text(
            'Native calendar unlink cleanup is only available in the iOS/Android app.',
          ),
          backgroundColor: Colors.orange.shade700,
        ),
      );
      return;
    }

    if (!_hasSession) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Sign in before unlinking synced calendar data.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0C0C0C),
          title: const Text(
            'Unlink Calendar Sync',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'This removes imported Apple/Google calendar events from Kemetic, clears sync state, and turns automatic calendar sync off until you re-enable it. If older hAw exports still exist on the device calendar, the cleanup also removes those legacy copies.',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Unlink and clear'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _unlinkingCalendar = true;
    });

    try {
      final sync = sharedCalendarSyncService(client);
      final result = await sync.unlinkAndPurge(
        interactive: true,
        markResetCompleted: true,
      );

      final calendarState = CalendarPage.globalKey.currentState;
      if (calendarState != null) {
        await calendarState.reloadFromOutside();
      }

      await _refreshCalendarStatus();
      final autoSync = await SettingsPrefs.autoCalendarSyncEnabled();
      if (!mounted) return;

      setState(() {
        _autoCalendarSync = autoSync;
      });

      final parts = <String>[
        if (result.removedImportedEvents > 0)
          'removed ${result.removedImportedEvents} imported device-calendar events from Kemetic',
        if (result.removedNativeEvents > 0)
          'removed ${result.removedNativeEvents} legacy hAw exports from the device calendar',
      ];
      final summary = parts.isEmpty
          ? 'Calendar import state was cleared and automatic sync was turned off.'
          : '${parts.join('; ')}. Automatic sync is now off.';
      final suffix = result.permissionGranted
          ? ''
          : ' Grant calendar access and run this again if older exported hAw copies still remain on the device calendar.';

      messenger.showSnackBar(
        SnackBar(
          content: Text('$summary$suffix'),
          backgroundColor: result.permissionGranted
              ? Colors.green.shade700
              : Colors.orange.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not unlink synced calendar data: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _unlinkingCalendar = false;
        });
      }
    }
  }

  void _showCalendarSyncResult(CalendarSyncRunResult result) {
    final messenger = ScaffoldMessenger.of(context);
    switch (result.state) {
      case CalendarSyncRunState.synced:
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Calendar import completed on this device.'),
            backgroundColor: Colors.green.shade700,
          ),
        );
        return;
      case CalendarSyncRunState.unlinked:
        messenger.showSnackBar(
          SnackBar(
            content: const Text(
              'Imported device-calendar data was cleared. Re-enable sync when you want Kemetic to import again.',
            ),
            backgroundColor: Colors.orange.shade700,
          ),
        );
        return;
      case CalendarSyncRunState.permissionDenied:
        messenger.showSnackBar(
          SnackBar(
            content: const Text(
              'Calendar access is not granted on this device.',
            ),
            backgroundColor: Colors.red.shade700,
          ),
        );
        return;
      case CalendarSyncRunState.skippedInProgress:
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Calendar sync is already running.'),
            backgroundColor: Colors.orange.shade700,
          ),
        );
        return;
      case CalendarSyncRunState.skippedWeb:
        messenger.showSnackBar(
          SnackBar(
            content: const Text(
              'Native calendar sync is unavailable in this web context.',
            ),
            backgroundColor: Colors.orange.shade700,
          ),
        );
        return;
      case CalendarSyncRunState.skippedNoSession:
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Sign in to sync your calendar.'),
            backgroundColor: Colors.red.shade700,
          ),
        );
        return;
      case CalendarSyncRunState.skippedPermissionBackoff:
        messenger.showSnackBar(
          SnackBar(
            content: const Text(
              'Calendar permission was denied recently. Re-enable access in the OS and try again.',
            ),
            backgroundColor: Colors.orange.shade700,
          ),
        );
        return;
      case CalendarSyncRunState.failed:
        messenger.showSnackBar(
          SnackBar(
            content: Text('Calendar sync failed: ${result.error}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
        return;
    }
  }

  String _formatTimestamp(DateTime dt) {
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$mm/$dd $hh:$min';
  }

  String _pushToggleSubtitle() {
    if (!_hasSession) {
      return 'Sign in first, then allow notifications for this device.';
    }
    if (_realTimeAlerts) {
      return 'This device is linked for account-level push alerts.';
    }
    return 'Off by default. Turn this on only for devices that should receive push alerts.';
  }

  String _pushStatusText() {
    if (_pushStatus != null) return _pushStatus!;
    if (_requestingPush) {
      return 'Requesting notification permission...';
    }
    if (_loadingPushDiagnostics) {
      return 'Checking Firebase, permission, and device registration...';
    }
    if (_realTimeAlerts) {
      return 'Push alerts are enabled for this device.';
    }
    return _hasSession
        ? 'Push alerts are currently off on this device.'
        : 'Push alerts stay unavailable until you sign in.';
  }

  String _pushButtonLabel() {
    if (_requestingPush) return 'Requesting...';
    if (!_hasSession) return 'Sign in to enable push';
    return _realTimeAlerts
        ? 'Refresh push on this device'
        : 'Enable push on this device';
  }

  List<String> _pushDiagnosticLines() {
    final diagnostics = _pushDiagnostics;
    if (diagnostics == null) {
      return const <String>[];
    }

    final lines = <String>[
      diagnostics.firebaseReady
          ? 'Firebase is ready on ${diagnostics.platform}.'
          : 'Firebase is not ready for this build. Check the bundled Firebase config.',
      'Permission: ${diagnostics.permissionStatus}.',
    ];

    if (kIsWeb) {
      lines.add(
        'For the most reliable web delivery, install the PWA and allow notifications for this site.',
      );
      lines.add(
        diagnostics.browserSubscriptionPresent
            ? 'Browser subscription: present (${diagnostics.browserSubscriptionSummary}).'
            : 'Browser subscription: missing on this device.',
      );
    }

    if (!diagnostics.hasSession) {
      lines.add('Sign in to link this device to your account for remote push.');
      return lines;
    }

    if (diagnostics.databaseRegistered) {
      final lastSeen = diagnostics.lastSeenAt?.toLocal();
      lines.add(
        lastSeen == null
            ? 'Server registration: active for this device.'
            : 'Server registration: active, last seen ${_formatTimestamp(lastSeen)}.',
      );
      if (diagnostics.tokenSummary != 'not available') {
        lines.add('Registered token: ${diagnostics.tokenSummary}.');
      }
    } else {
      lines.add(
        'Server registration: this device is not currently linked in push_tokens.',
      );
    }

    if (diagnostics.error != null && diagnostics.error!.isNotEmpty) {
      lines.add('Diagnostics warning: ${diagnostics.error!}');
    }

    return lines;
  }

  String _syncButtonLabel() {
    if (!_nativeCalendarSyncAvailable) return 'Native sync unavailable on web';
    if (_syncingCalendar) return 'Syncing...';
    if (!_hasSession) return 'Sign in to sync';
    return 'Sync now';
  }

  List<String> _calendarStatusLines() {
    final lines = <String>[];

    if (!_nativeCalendarSyncAvailable) {
      lines.add('Web builds cannot access the native device calendar.');
      return lines;
    }

    lines.add(
      _autoCalendarSync
          ? 'Automatic sync is on. The app keeps importing device-calendar changes after sign-in.'
          : 'Automatic sync is off. Use Sync now whenever you want to import again.',
    );

    final lastSync = _calendarSyncStatus?.lastSyncAt?.toLocal();
    lines.add(
      lastSync == null
          ? 'Last sync: not yet completed on this device.'
          : 'Last sync: ${_formatTimestamp(lastSync)}',
    );

    final lastDenied = _calendarSyncStatus?.lastPermissionDeniedAt?.toLocal();
    if (lastDenied != null) {
      lines.add('Calendar access last denied: ${_formatTimestamp(lastDenied)}');
    }

    final lastReset = _calendarSyncStatus?.lastResetAt?.toLocal();
    if (lastReset != null) {
      lines.add('Last unlink cleanup: ${_formatTimestamp(lastReset)}');
    }

    if (!_hasSession) {
      lines.add('Sign in is required before any device calendar sync can run.');
    }

    return lines;
  }

  Widget _sectionCard({
    required String title,
    required String description,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C0C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF242424)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _settingSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
    Widget? trailing,
  }) {
    return Column(
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: KemeticGold.base,
          title: Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(color: Colors.white60, height: 1.35),
          ),
          value: value,
          onChanged: onChanged,
          secondary: trailing,
        ),
        const Divider(color: Color(0xFF1D1D1D), height: 1),
      ],
    );
  }

  Widget _statusLine(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 6, color: Colors.white38),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryButton({
    required VoidCallback? onPressed,
    required Widget child,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: KemeticGold.base,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: onPressed,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: KemeticGold.base)),
      );
    }

    final calendarStatusLines = _calendarStatusLines();
    final pushDiagnosticLines = _pushDiagnosticLines();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: KemeticGold.icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: KemeticGold.base),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Only live device-level controls are surfaced here.',
              style: TextStyle(color: Colors.white60, height: 1.4),
            ),
            const SizedBox(height: 16),
            _sectionCard(
              title: 'Notifications',
              description:
                  'Push alerts are opt-in per device. Scheduled reminder notifications continue to be driven by the events and reminders you create.',
              children: [
                _settingSwitch(
                  title: 'Push alerts on this device',
                  subtitle: _pushToggleSubtitle(),
                  value: _realTimeAlerts,
                  onChanged: _requestingPush ? null : _setRealTimeAlerts,
                ),
                const SizedBox(height: 16),
                _primaryButton(
                  onPressed: _requestingPush || !_hasSession
                      ? null
                      : () => _setRealTimeAlerts(true),
                  child: Text(_pushButtonLabel()),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF3A3A3A)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed:
                        _sendingPushTest ||
                            _requestingPush ||
                            !_hasSession ||
                            !_realTimeAlerts
                        ? null
                        : _sendPushTest,
                    child: Text(
                      _sendingPushTest
                          ? 'Sending test push...'
                          : 'Send test push to this device',
                    ),
                  ),
                ),
                _statusLine(_pushStatusText()),
                for (final line in pushDiagnosticLines) _statusLine(line),
              ],
            ),
            const SizedBox(height: 16),
            _sectionCard(
              title: 'Calendar Sync',
              description:
                  'Device calendar sync only imports external events into Kemetic. Events you create in Kemetic stay in Kemetic.',
              children: [
                _settingSwitch(
                  title: 'Keep device calendar synced automatically',
                  subtitle: _nativeCalendarSyncAvailable
                      ? 'Runs after sign-in and keeps importing device-calendar changes in the background.'
                      : 'Native calendar sync is not available in web builds.',
                  value: _autoCalendarSync,
                  onChanged: !_nativeCalendarSyncAvailable || _calendarBusy
                      ? null
                      : _setAutoCalendarSync,
                ),
                const SizedBox(height: 16),
                _primaryButton(
                  onPressed:
                      !_nativeCalendarSyncAvailable ||
                          _calendarBusy ||
                          !_hasSession
                      ? null
                      : _syncCalendarNow,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_syncingCalendar) ...[
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ] else ...[
                        const Icon(Icons.sync),
                        const SizedBox(width: 10),
                      ],
                      Text(_syncButtonLabel()),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade200,
                      side: BorderSide(color: Colors.red.shade300),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed:
                        !_nativeCalendarSyncAvailable ||
                            _calendarBusy ||
                            !_hasSession
                        ? null
                        : _unlinkCalendarAccounts,
                    child: Text(
                      _unlinkingCalendar
                          ? 'Unlinking calendars...'
                          : 'Unlink and clear synced calendar data',
                    ),
                  ),
                ),
                for (final line in calendarStatusLines) _statusLine(line),
              ],
            ),
            const SizedBox(height: 16),
            _sectionCard(
              title: 'Calendar Content',
              description:
                  'Optional data sources that add entries inside the app without changing your core sync behavior.',
              children: [
                _settingSwitch(
                  title: 'Add U.S. holidays as notes',
                  subtitle: _seedingHolidays
                      ? 'Applying holiday notes...'
                      : 'Adds standard U.S. holidays as editable app notes.',
                  value: _usHolidaysEnabled,
                  onChanged: _seedingHolidays ? null : _toggleUsHolidays,
                  trailing: _seedingHolidays
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: KemeticGold.base,
                          ),
                        )
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Preferences stay local to this device. Push registration and calendar permission are also device-specific.',
              style: TextStyle(color: Colors.white60, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
