// lib/features/calendar/notify.dart
import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Timezone DB (we schedule in UTC)
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class Notify {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _androidChannelId = 'maat.reminders';
  static const _androidChannelName = 'Ma\'at Reminders';
  static const _androidChannelDesc = 'Event notes and flow reminders';

  static bool _inited = false;
  static int _nextNotificationId = 1000; // Start from 1000 to avoid conflicts

  static void _log(String msg) {
    if (kDebugMode) {
      print('[Notify] $msg');
    }
  }

  /// Call once at app startup (e.g., from main()).
  static Future<void> init() async {
    if (_inited) {
      _log('init() skipped (already)');
      return;
    }

    // 1) Timezone DB; we'll schedule in UTC
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

    // 6) Reschedule all active notifications from database
    await rescheduleAllFromDatabase();
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
      icon: '@mipmap/ic_launcher',
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
    await pending();
  }

  /// Helper: schedule something a few seconds out (for your debug button).
  static Future<void> debugScheduleIn({int seconds = 10}) async {
    final when = DateTime.now().add(Duration(seconds: seconds));
    await scheduleAlertWithPersistence(
      clientEventId: 'debug-test-${DateTime.now().millisecondsSinceEpoch}',
      scheduledAt: when,
      title: 'Debug scheduled alert',
      body: 'Fires ~${seconds}s after tapping.',
      payload: '{}',
    );
  }

  /// **NEW**: Schedule a notification WITH PERSISTENCE to Supabase
  /// This is the primary method to use for all event notifications
  static Future<void> scheduleAlertWithPersistence({
    required String clientEventId,
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

    // Check if we already have a notification for this event
    final existing = await _getNotificationByEventId(clientEventId);

    int notificationId;
    if (existing != null) {
      // Update existing notification
      notificationId = existing['notification_id'] as int;
      _log('Updating existing notification $notificationId for event $clientEventId');

      // Cancel old notification
      await _plugin.cancel(notificationId);
    } else {
      // Generate new notification ID
      notificationId = _nextNotificationId++;
      _log('Creating new notification $notificationId for event $clientEventId');
    }

    // Schedule the local notification
    await _scheduleLocalNotification(
      id: notificationId,
      scheduledAt: safeWhen,
      title: title,
      body: body,
      payload: payload ?? '{}',
    );

    // Persist to Supabase
    await _persistNotificationToDatabase(
      clientEventId: clientEventId,
      notificationId: notificationId,
      scheduledAt: safeWhen,
      title: title,
      body: body,
      payload: payload ?? '{}',
    );

    _log('✅ Notification scheduled and persisted: $title at $safeWhen');
  }

  /// **NEW**: Cancel notification for a specific event
  static Future<void> cancelNotificationForEvent(String clientEventId) async {
    if (!_inited) {
      await init();
    }

    try {
      final notification = await _getNotificationByEventId(clientEventId);

      if (notification != null) {
        final notificationId = notification['notification_id'] as int;

        // Cancel the local notification
        await _plugin.cancel(notificationId);
        _log('Cancelled notification $notificationId');

        // Mark as inactive in database (don't delete for audit trail)
        await _markNotificationInactive(clientEventId);
        _log('✅ Notification cancelled for event: $clientEventId');
      } else {
        _log('No notification found for event: $clientEventId');
      }
    } catch (e) {
      _log('⚠️ Error cancelling notification: $e');
    }
  }

  /// **NEW**: Reschedule all active notifications from database
  /// Call this on app startup to restore all scheduled notifications
  static Future<void> rescheduleAllFromDatabase() async {
    if (!_inited) {
      _log('Cannot reschedule - not initialized');
      return;
    }

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      if (userId == null) {
        _log('No user logged in, skipping reschedule');
        return;
      }

      final now = DateTime.now();

      // Fetch all active notifications that haven't fired yet
      final response = await client
          .from('scheduled_notifications')
          .select()
          .eq('user_id', userId)
          .eq('is_active', true)
          .gte('scheduled_at', now.toIso8601String())
          .order('scheduled_at', ascending: true);

      final notifications = response as List<dynamic>;

      _log('Rescheduling ${notifications.length} active notifications');

      int rescheduled = 0;
      for (final notif in notifications) {
        try {
          final scheduledAt = DateTime.parse(notif['scheduled_at'] as String);

          // Only reschedule future notifications
          if (scheduledAt.isAfter(now)) {
            await _scheduleLocalNotification(
              id: notif['notification_id'] as int,
              scheduledAt: scheduledAt,
              title: notif['title'] as String,
              body: notif['body'] as String?,
              payload: notif['payload'] as String? ?? '{}',
            );
            rescheduled++;
          } else {
            // Mark past notifications as inactive
            await _markNotificationInactive(notif['client_event_id'] as String);
          }
        } catch (e) {
          _log('⚠️ Error rescheduling notification ${notif['id']}: $e');
        }
      }

      _log('✅ Rescheduled $rescheduled notifications');
    } catch (e) {
      _log('⚠️ Error loading notifications from database: $e');
    }
  }

  /// **PRIVATE**: Internal method to schedule local notification only
  static Future<void> _scheduleLocalNotification({
    required int id,
    required DateTime scheduledAt,
    required String title,
    String? body,
    String? payload,
  }) async {
    final tzScheduled = tz.TZDateTime.from(scheduledAt, tz.UTC);

    const androidDetails = AndroidNotificationDetails(
      _androidChannelId,
      _androidChannelName,
      channelDescription: _androidChannelDesc,
      importance: Importance.max,
      priority: Priority.max,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
      channelShowBadge: true,
      ticker: 'ticker',
    );

    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzScheduled,
      details,
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  /// **PRIVATE**: Persist notification to Supabase
  static Future<void> _persistNotificationToDatabase({
    required String clientEventId,
    required int notificationId,
    required DateTime scheduledAt,
    required String title,
    String? body,
    required String payload,
  }) async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      if (userId == null) {
        _log('⚠️ Cannot persist notification - no user logged in');
        return;
      }

      await client.from('scheduled_notifications').upsert({
        'user_id': userId,
        'client_event_id': clientEventId,
        'notification_id': notificationId,
        'scheduled_at': scheduledAt.toUtc().toIso8601String(),
        'title': title,
        'body': body,
        'payload': payload,
        'is_active': true,
      }, onConflict: 'user_id,client_event_id');

      _log('Persisted notification to database: $clientEventId');
    } catch (e) {
      _log('⚠️ Error persisting notification to database: $e');
      // Don't throw - notification is still scheduled locally
    }
  }

  /// **PRIVATE**: Get notification by event ID
  static Future<Map<String, dynamic>?> _getNotificationByEventId(
      String clientEventId) async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      if (userId == null) return null;

      final response = await client
          .from('scheduled_notifications')
          .select()
          .eq('user_id', userId)
          .eq('client_event_id', clientEventId)
          .eq('is_active', true)
          .maybeSingle();

      return response;
    } catch (e) {
      _log('⚠️ Error fetching notification: $e');
      return null;
    }
  }

  /// **PRIVATE**: Mark notification as inactive
  static Future<void> _markNotificationInactive(String clientEventId) async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      if (userId == null) return;

      await client
          .from('scheduled_notifications')
          .update({'is_active': false})
          .eq('user_id', userId)
          .eq('client_event_id', clientEventId);

      _log('Marked notification inactive: $clientEventId');
    } catch (e) {
      _log('⚠️ Error marking notification inactive: $e');
    }
  }

  /// **DEPRECATED**: Old method - use scheduleAlertWithPersistence instead
  /// Kept for backward compatibility with test buttons
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

    await _scheduleLocalNotification(
      id: id,
      scheduledAt: safeWhen,
      title: title,
      body: body,
      payload: payload ?? '{}',
    );

    _log('⚠️ Using deprecated scheduleAlert - consider using scheduleAlertWithPersistence');
  }

  /// Dump pending notifications for debugging
  static Future<void> pending() async {
    final pend = await _plugin.pendingNotificationRequests();
    _log('========================================');
    _log('PENDING NOTIFICATIONS: ${pend.length}');
    _log('========================================');
    for (final p in pend) {
      _log('  ID: ${p.id}');
      _log('  Title: ${p.title}');
      _log('  Body: ${p.body}');
      _log('  Payload: ${p.payload}');
      _log('  ----------------------------------------');
    }
    if (pend.isEmpty) {
      _log('⚠️ NO PENDING NOTIFICATIONS!');
      _log('This means notifications are not being scheduled on the device.');
      _log('Check: Battery optimization, Exact alarm permission, Notification permission');
    }
    _log('========================================');
  }

  /// **NEW**: Debug method to check notification permissions and status
  static Future<void> debugCheckPermissions() async {
    _log('========================================');
    _log('NOTIFICATION PERMISSIONS CHECK');
    _log('========================================');

    try {
      final androidSpecific = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (androidSpecific != null) {
        final canScheduleExact = await androidSpecific.canScheduleExactNotifications();
        _log('✓ Can schedule exact alarms: $canScheduleExact');

        if (canScheduleExact == false) {
          _log('⚠️ WARNING: Exact alarms permission NOT granted!');
          _log('   Go to: Settings → Apps → Your App → Alarms & reminders → Allow');
        }
      }

      // Check pending notifications
      final pend = await _plugin.pendingNotificationRequests();
      _log('✓ Pending notifications count: ${pend.length}');

      // Check database
      try {
        final client = Supabase.instance.client;
        final userId = client.auth.currentUser?.id;

        if (userId != null) {
          final dbNotifs = await client
              .from('scheduled_notifications')
              .select()
              .eq('user_id', userId)
              .eq('is_active', true);

          _log('✓ Database active notifications: ${(dbNotifs as List).length}');

          if (pend.length != (dbNotifs as List).length) {
            _log('⚠️ WARNING: Mismatch between device (${pend.length}) and database (${(dbNotifs as List).length})!');
          }
        } else {
          _log('⚠️ No user logged in - cannot check database');
        }
      } catch (e) {
        _log('⚠️ Error checking database: $e');
      }

    } catch (e) {
      _log('⚠️ Error checking permissions: $e');
    }

    _log('========================================');
  }

  /// **NEW**: Clean up old notifications from database
  /// Call periodically to remove inactive notifications older than 30 days
  static Future<void> cleanupOldNotifications() async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      if (userId == null) return;

      final cutoff = DateTime.now().subtract(const Duration(days: 30));

      await client
          .from('scheduled_notifications')
          .delete()
          .eq('user_id', userId)
          .eq('is_active', false)
          .lt('updated_at', cutoff.toIso8601String());

      _log('✅ Cleaned up old notifications');
    } catch (e) {
      _log('⚠️ Error cleaning up notifications: $e');
    }
  }
}