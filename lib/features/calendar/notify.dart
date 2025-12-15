// lib/features/calendar/notify.dart
import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Timezone DB (we schedule in LOCAL timezone)
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Notification types (prepare for Phase 1.1)
enum NotificationType {
  eventStart('event_start'),
  reminder10min('reminder_10min'),
  dailyReview('daily_review'),
  flowStep('flow_step');
  
  final String value;
  const NotificationType(this.value);
}

class Notify {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _androidChannelId = 'maat.reminders';
  static const _androidChannelName = 'Ma\'at Reminders';
  static const _androidChannelDesc = 'Event notes and flow reminders';

  static bool _inited = false;
  static final Set<String> _schedulingInProgress = {};

  /// Generate stable notification ID from clientEventId
  /// Hash-based approach prevents ID conflicts across app restarts
  static int _generateStableNotificationId(String clientEventId) {
    // Use hashCode for deterministic ID generation
    // Modulo 1M to keep in safe range for iOS/Android
    final hash = clientEventId.hashCode.abs() % 1000000;
    
    // Ensure ID is never 0 (some platforms don't like it)
    return hash == 0 ? 1 : hash;
  }

  static void _log(String msg) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toIso8601String();
      print('[Notify $timestamp] $msg');
    }
  }

  /// Call once at app startup (e.g., from main()).
  static Future<void> init() async {
    if (_inited) {
      _log('init() skipped (already)');
      return;
    }

    // 1) Timezone DB; we'll schedule in LOCAL timezone
    tzdata.initializeTimeZones();
    
    // Auto-detect timezone using DateTime offset
    final nowLocal = DateTime.now();
    final offset = nowLocal.timeZoneOffset;
    
    String detectedTimezone = 'America/Los_Angeles'; // Default fallback
    
    try {
      final offsetHours = offset.inHours;
      final offsetMinutes = offset.inMinutes.remainder(60);
      
      _log('🌍 Device timezone offset: ${offsetHours}h ${offsetMinutes}m');
      
      // Map common timezones by UTC offset
      final timezoneMap = {
        // US Timezones - Fixed DST handling
        -8: 'America/Los_Angeles',  // PST (winter)
        -7: 'America/Los_Angeles',  // PDT (summer) ← FIXED!
        -6: 'America/Denver',        // MDT (summer) or CST (winter)
        -5: 'America/Chicago',       // CDT (summer) or EST (winter)
        -4: 'America/New_York',      // EDT (summer)
        -10: 'Pacific/Honolulu',     // HST (no DST)
        -9: 'America/Anchorage',     // AKST/AKDT
        
        // International
        0: 'Europe/London',          // GMT/BST
        1: 'Europe/Paris',           // CET/CEST
        8: 'Asia/Singapore',         // SGT
        9: 'Asia/Tokyo',             // JST
        10: 'Australia/Sydney',      // AEST/AEDT
      };
      
      detectedTimezone = timezoneMap[offsetHours] ?? 'America/Los_Angeles';
      
      _log('📍 Detected timezone: $detectedTimezone (offset: ${offsetHours}h)');
      
    } catch (e) {
      _log('⚠️ Timezone detection failed: $e');
      _log('   Using fallback: America/Los_Angeles');
    }
    
    tz.setLocalLocation(tz.getLocation(detectedTimezone));
    _log('Timezones initialized (will use LOCAL timezone: $detectedTimezone)');

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
    // Show final state
    final finalPending = await _plugin.pendingNotificationRequests();
    _log('Final pending notifications: ${finalPending.length}');
  }

  /// Show an immediate notification without persistence (used for FCM foreground).
  static Future<void> showInstant({
    required String title,
    String? body,
  }) async {
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

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(1000000),
      title,
      body,
      details,
    );
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
    NotificationType type = NotificationType.eventStart,
  }) async {
    if (!_inited) {
      await init();
    }

    // FIX #2: Prevent duplicate scheduling
    if (_schedulingInProgress.contains(clientEventId)) {
      _log('⚠️ Already scheduling notification for $clientEventId, skipping duplicate');
      return;
    }

    try {
      _schedulingInProgress.add(clientEventId);

      final now = DateTime.now();
      final safeWhen = scheduledAt.isAfter(now.add(const Duration(seconds: 3)))
          ? scheduledAt
          : now.add(const Duration(seconds: 5));

      // Generate stable notification ID from clientEventId
      final notificationId = _generateStableNotificationId(clientEventId);

      // Check if existing notification needs update
      final existing = await _getNotificationByEventId(clientEventId);
      if (existing != null) {
        _log('Updating existing notification $notificationId for event $clientEventId');
        // Cancel old notification
        await _plugin.cancel(notificationId);
      } else {
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
        type: type,
      );

      // Detailed logging happens in _scheduleLocalNotification()
    } finally {
      // Always remove from set, even if error occurs
      _schedulingInProgress.remove(clientEventId);
    }
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

  /// Cancel notification when event is deleted (simplified version)
  static Future<void> cancelNotification(String clientEventId) async {
    if (!_inited) {
      await init();
    }

    try {
      // Generate the notification ID that would have been used
      final notificationId = _generateStableNotificationId(clientEventId);
      
      _log('Canceling notification $notificationId for event $clientEventId');
      
      // Cancel from device
      await _plugin.cancel(notificationId);
      
      // Mark as inactive in database
      await _markNotificationInactive(clientEventId);
      
      _log('✅ Canceled notification for $clientEventId');
    } catch (e) {
      _log('⚠️ Error canceling notification: $e');
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
  /// FIXED: Removed fullScreenIntent and showWhen for Android 15 compatibility
  static Future<void> _scheduleLocalNotification({
    required int id,
    required DateTime scheduledAt,
    required String title,
    String? body,
    String? payload,
  }) async {
    // Convert to timezone-aware datetime
    final tzScheduled = tz.TZDateTime.from(scheduledAt, tz.local);

    _log('Scheduling notification in LOCAL timezone: ${tz.local.name}');
    _log('  UTC time: ${scheduledAt.toUtc()}');
    _log('  Local time: $tzScheduled');
    _log('  Will fire at: ${tzScheduled.toString()}');

    // Android 15 compatible configuration - removed fullScreenIntent and showWhen
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

    // iOS compatible configuration - removed presentAlert for consistency
    const iosDetails = DarwinNotificationDetails();
    
    const details = NotificationDetails(
      android: androidDetails, 
      iOS: iosDetails
    );

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzScheduled,
        details,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      
      _log('✅ Notification $id scheduled successfully');
    } catch (e) {
      _log('❌ Error scheduling notification $id: $e');
      rethrow;
    }
  }

  /// **PRIVATE**: Persist notification to Supabase
  static Future<void> _persistNotificationToDatabase({
    required String clientEventId,
    required int notificationId,
    required DateTime scheduledAt,
    required String title,
    String? body,
    required String payload,
    NotificationType type = NotificationType.eventStart,
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
        'notification_type': type.value,
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

  /// **DEBUG**: Cancel all pending notifications (for debugging)
  static Future<void> debugCancelAll() async {
    if (!_inited) await init();
    
    final pending = await _plugin.pendingNotificationRequests();
    for (final notif in pending) {
      await _plugin.cancel(notif.id);
    }
    
    _log('🗑️ Cancelled ${pending.length} pending notifications');
    
    // Also mark all as inactive in database
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      
      if (userId != null) {
        await client
            .from('scheduled_notifications')
            .update({'is_active': false})
            .eq('user_id', userId)
            .eq('is_active', true);
        
        _log('✅ Marked all notifications inactive in database');
      }
    } catch (e) {
      _log('⚠️ Error updating database: $e');
    }
    
    // Show final state
    final finalPending = await _plugin.pendingNotificationRequests();
    _log('Final pending notifications: ${finalPending.length}');
  }

  /// **DEBUG**: Reschedule all from database (for debugging)
  static Future<void> debugRescheduleAll() async {
    if (!_inited) await init();
    
    _log('🔄 Force rescheduling all notifications...');
    await rescheduleAllFromDatabase();
    // Show final state
    final finalPending = await _plugin.pendingNotificationRequests();
    _log('Final pending notifications: ${finalPending.length}');
  }

  /// **DEBUG**: Dump database state (for debugging)
  static Future<void> debugDumpDatabase() async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      
      if (userId == null) {
        _log('❌ No user logged in');
        return;
      }
      
      final response = await client
          .from('scheduled_notifications')
          .select()
          .eq('user_id', userId)
          .order('scheduled_at', ascending: true);
      
      final notifications = response as List<dynamic>;
      
      _log('========================================');
      _log('DATABASE NOTIFICATIONS: ${notifications.length}');
      _log('========================================');
      
      if (notifications.isEmpty) {
        _log('  (No notifications in database)');
      } else {
        for (final notif in notifications) {
          _log('  ID: ${notif['notification_id']}');
          _log('  Event: ${notif['client_event_id']}');
          _log('  Type: ${notif['notification_type']}');
          _log('  When: ${notif['scheduled_at']}');
          _log('  Title: ${notif['title']}');
          _log('  Active: ${notif['is_active']}');
          _log('  ----------------------------------------');
        }
      }
      _log('========================================');
    } catch (e) {
      _log('❌ Error dumping database: $e');
    }
  }

  /// **DEBUG**: Compare device vs database (for debugging sync issues)
  static Future<void> debugCompareDeviceAndDatabase() async {
    _log('🔍 Starting device vs database comparison...');
    _log('');
    
    // First show permissions
    await debugCheckPermissions();
    _log('');
    
    // Show database contents
    await debugDumpDatabase();
    _log('');
    
    // Get device notifications
    final devicePending = await _plugin.pendingNotificationRequests();
    final deviceIds = devicePending.map((n) => n.id).toSet();
    
    _log('========================================');
    _log('DEVICE NOTIFICATIONS: ${devicePending.length}');
    _log('========================================');
    if (devicePending.isEmpty) {
      _log('  (No notifications on device)');
    } else {
      for (final notif in devicePending) {
        _log('  ID: ${notif.id}');
        _log('  Title: ${notif.title}');
        _log('  Body: ${notif.body}');
        _log('  ----------------------------------------');
      }
    }
    _log('========================================');
    _log('');
    
    // Compare IDs
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        _log('⚠️ Cannot compare - no user logged in');
        return;
      }
      
      final dbNotifs = await client
          .from('scheduled_notifications')
          .select()
          .eq('user_id', userId)
          .eq('is_active', true);
      
      final dbIds = (dbNotifs as List).map((n) => n['notification_id'] as int).toSet();
      
      final onlyDevice = deviceIds.difference(dbIds);
      final onlyDb = dbIds.difference(deviceIds);
      final inBoth = deviceIds.intersection(dbIds);
      
      _log('========================================');
      _log('SYNC COMPARISON RESULTS');
      _log('========================================');
      _log('✅ In both device & DB: ${inBoth.length}');
      if (inBoth.isNotEmpty) {
        _log('   IDs: $inBoth');
      }
      _log('');
      _log('⚠️ Only on device: ${onlyDevice.length}');
      if (onlyDevice.isNotEmpty) {
        _log('   IDs: $onlyDevice');
        _log('   → These notifications exist on device but not in database');
        _log('   → May be old notifications or from deprecated scheduleAlert()');
      }
      _log('');
      _log('⚠️ Only in database: ${onlyDb.length}');
      if (onlyDb.isNotEmpty) {
        _log('   IDs: $onlyDb');
        _log('   → These notifications are in database but not scheduled on device');
        _log('   → This is a sync problem - should reschedule');
      }
      _log('========================================');
      
      // Provide recommendation
      if (onlyDevice.isEmpty && onlyDb.isEmpty) {
        _log('✅ SYNC STATUS: PERFECT - All notifications synced correctly!');
      } else if (onlyDb.isNotEmpty) {
        _log('⚠️ SYNC STATUS: NEEDS RESCHEDULE - Run "Reschedule All" to fix');
      } else if (onlyDevice.isNotEmpty) {
        _log('⚠️ SYNC STATUS: ORPHANED NOTIFICATIONS - Run "Cancel All" then "Reschedule All"');
      }
      _log('========================================');
      
    } catch (e) {
      _log('❌ Error comparing: $e');
    }
  }
}
