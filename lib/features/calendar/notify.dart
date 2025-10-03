// lib/features/calendar/notify.dart
import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Timezone DB (we schedule in UTC)
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class Notify {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _androidChannelId = 'maat.reminders';
  static const _androidChannelName = 'Ma\'at Reminders';
  static const _androidChannelDesc = 'Event notes and flow reminders';

  static bool _inited = false;

  static void _log(String msg) {
    if (kDebugMode) {
      // Prefix so it's easy to grep in logs
      // Example: I/flutter  ( xxxx): [Notify] init() done
      // (Uses print so it shows in flutter run console)
      print('[Notify] $msg');
    }
  }

  /// Call once at app startup (e.g., from main()).
  static Future<void> init() async {
    if (_inited) {
      _log('init() skipped (already)');
      return;
    }

    // 1) Timezone DB; we’ll schedule in UTC
    tzdata.initializeTimeZones();
    _log('Timezones initialized (using UTC for scheduling)');

    // 2) Android init
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    // 3) iOS/macOS init
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    await _plugin.initialize(initSettings);
    _log('initialize() complete');

    // 4) Android 13+ notifications runtime permission
    final androidSpecific =
    _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    final notifGranted = await androidSpecific?.requestNotificationsPermission();
    _log('requestNotificationsPermission() => $notifGranted');

    // 5) Android 12+ exact alarms permission (best effort)
    try {
      final exactGranted = await androidSpecific?.requestExactAlarmsPermission();
      _log('requestExactAlarmsPermission() => $exactGranted');
    } catch (e) {
      _log('requestExactAlarmsPermission() threw: $e (safe to ignore)');
    }

    _inited = true;
    _log('init() done');
  }

  /// Immediate test alert (use your "Test alert" button).
  static Future<void> debugTestNow() async {
    if (!_inited) {
      await init();
    }

    const androidDetails = AndroidNotificationDetails(
      _androidChannelId,
      _androidChannelName,
      channelDescription: _androidChannelDesc,
      importance: Importance.max,
      priority: Priority.max,
      enableVibration: true,
      playSound: true,
      // Use the default launcher icon shipped with Flutter templates:
      icon: '@mipmap/ic_launcher', // <-- change from @drawable/ic_launcher_foreground
      channelShowBadge: true,
      ticker: 'ticker',
    );


    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    _log('show() now => id=999000 title="Test alert"');
    await _plugin.show(
      999000,
      'Test alert',
      'If you see this, notifications are working.',
      details,
      payload: '{}',
    );
    await pending(); // dump queue after show
  }

  /// Helper: schedule something a few seconds out (for your debug button).
  static Future<void> debugScheduleIn({int seconds = 10}) async {
    final when = DateTime.now().add(Duration(seconds: seconds));
    await scheduleAlert(
      id: 999111,
      scheduledAt: when,
      title: 'Debug scheduled alert',
      body: 'Fires ~${seconds}s after tapping.',
      payload: '{}',
    );
  }

  /// Schedule a notification at *local* wall time [scheduledAt].
  /// We convert to UTC and schedule in the UTC zone to avoid plugin TZ deps.
  static Future<void> scheduleAlert({
    required int id,
    required DateTime scheduledAt,
    required String title,
    String? body,
    String? payload,
  }) async {
    if (!_inited) {
      await init();
    }

    final now = DateTime.now();
    final safeWhen = scheduledAt.isAfter(now.add(const Duration(seconds: 3)))
        ? scheduledAt
        : now.add(const Duration(seconds: 5));

    // Schedule by absolute instant: convert to UTC and use the UTC zone
    final utcInstant = safeWhen.toUtc();
    final tzTime = tz.TZDateTime.from(utcInstant, tz.getLocation('UTC'));

    const androidDetails = AndroidNotificationDetails(
      _androidChannelId,
      _androidChannelName,
      channelDescription: _androidChannelDesc,
      importance: Importance.max,
      priority: Priority.max,
      enableVibration: true,
      playSound: true,
      // Use the default launcher icon shipped with Flutter templates:
      icon: '@mipmap/ic_launcher', // <-- change from @drawable/ic_launcher_foreground
      channelShowBadge: true,
      ticker: 'ticker',
    );

    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    _log('zonedSchedule() => id=$id when=${utcInstant.toIso8601String()} title="$title" body="$body"');
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,


      payload: payload,
      matchDateTimeComponents: null,
    );

    await pending(); // dump queue after scheduling
  }

  /// Print pending notifications so you can confirm the queue.
  static Future<void> pending() async {
    final pending = await _plugin.pendingNotificationRequests();
    _log('pending (${pending.length}): '
        '${pending.map((e) => '{id:${e.id},title:${e.title}}').toList()}');
  }
}
