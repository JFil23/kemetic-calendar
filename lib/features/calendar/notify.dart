// lib/features/calendar/notify.dart
import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../settings/settings_prefs.dart';

// Timezone DB (we schedule in LOCAL timezone)
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Notification types (prepare for Phase 1.1)
enum NotificationType {
  eventStart('event_start'),
  reminder10min('reminder_10min'),
  dailyReview('daily_review'),
  flowStep('flow_step'),

  /// Flow-adjacent nudges (shared DB constraint with `flow_reminder`).
  flowReminder('flow_reminder');

  final String value;
  const NotificationType(this.value);
}

class _PersistedNotification {
  const _PersistedNotification({required this.notificationId});

  final int notificationId;
}

enum NotificationScheduleOutcome {
  scheduledLocally,
  persistedForLocalReconcile,
  persistedForPush,
  permissionMissing,
  skippedAlreadyDue,
  duplicateInProgress,
  failed,
}

class NotificationScheduleResult {
  const NotificationScheduleResult._(
    this.outcome, {
    this.scheduledAt,
    this.message,
  });

  const NotificationScheduleResult.scheduledLocally(DateTime scheduledAt)
    : this._(
        NotificationScheduleOutcome.scheduledLocally,
        scheduledAt: scheduledAt,
      );

  const NotificationScheduleResult.persistedForLocalReconcile(
    DateTime scheduledAt,
  ) : this._(
        NotificationScheduleOutcome.persistedForLocalReconcile,
        scheduledAt: scheduledAt,
      );

  const NotificationScheduleResult.persistedForPush(DateTime scheduledAt)
    : this._(
        NotificationScheduleOutcome.persistedForPush,
        scheduledAt: scheduledAt,
      );

  const NotificationScheduleResult.permissionMissing(String message)
    : this._(NotificationScheduleOutcome.permissionMissing, message: message);

  const NotificationScheduleResult.skippedAlreadyDue()
    : this._(NotificationScheduleOutcome.skippedAlreadyDue);

  const NotificationScheduleResult.duplicateInProgress()
    : this._(NotificationScheduleOutcome.duplicateInProgress);

  const NotificationScheduleResult.failed(String message)
    : this._(NotificationScheduleOutcome.failed, message: message);

  final NotificationScheduleOutcome outcome;
  final DateTime? scheduledAt;
  final String? message;

  bool get isPermissionMissing =>
      outcome == NotificationScheduleOutcome.permissionMissing;
}

class Notify {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _androidChannelId = 'maat.reminders';
  static const _androidChannelName = 'Ma\'at Reminders';
  static const _androidChannelDesc = 'Event notes and flow reminders';
  static const _minimumScheduleLead = Duration(seconds: 3);
  static const _maxConcurrentLocalNotifications = 450;
  static const _localReconcileDebounce = Duration(milliseconds: 350);
  static const localPermissionMissingMessage =
      'Notification permission is off for this device. Turn it on before event alerts can fire.';

  static bool _inited = false;
  static final Set<String> _schedulingInProgress = {};
  static Timer? _localReconcileTimer;
  static bool _localReconcileInProgress = false;
  static bool _localReconcileQueued = false;
  static bool _localReconcileNeedsRefresh = false;
  static bool? _canScheduleExactAlarms;
  static bool _loggedInexactAlarmFallback = false;

  static String _notificationIdentity(
    String clientEventId,
    NotificationType type,
  ) {
    return '${type.value}::$clientEventId';
  }

  static NotificationType _notificationTypeFromValue(String? raw) {
    for (final type in NotificationType.values) {
      if (type.value == raw) return type;
    }
    return NotificationType.eventStart;
  }

  static bool _notificationRequiresEventExistence(NotificationType type) {
    switch (type) {
      case NotificationType.eventStart:
      case NotificationType.reminder10min:
        return true;
      case NotificationType.dailyReview:
      case NotificationType.flowStep:
      case NotificationType.flowReminder:
        return false;
    }
  }

  /// Fallback-only platform id for local scheduling when database persistence is
  /// unavailable. Normal scheduling must use the DB-stored notification_id.
  static int _generateFallbackNotificationId(
    String clientEventId, {
    NotificationType type = NotificationType.eventStart,
  }) {
    final identity = _notificationIdentity(clientEventId, type);
    // Use hashCode for deterministic ID generation
    // Modulo 1M to keep in safe range for iOS/Android
    final hash = identity.hashCode.abs() % 1000000;

    // Ensure ID is never 0 (some platforms don't like it)
    return hash == 0 ? 1 : hash;
  }

  static void _log(String msg) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toIso8601String();
      debugPrint('[Notify $timestamp] $msg');
    }
  }

  static String _stripMetadataPrefixes(String raw) {
    var text = raw.trim();
    final colorOrAlertPrefix = RegExp(
      r'^(?:color=[0-9a-fA-FxX]+;|alert=[-+]?\d+;)',
    );
    while (text.isNotEmpty) {
      if (text.startsWith('flowLocalId=')) {
        final semi = text.indexOf(';');
        text = (semi >= 0 && semi < text.length - 1)
            ? text.substring(semi + 1).trimLeft()
            : '';
        continue;
      }
      if (text.startsWith('repeat=')) {
        final semi = text.indexOf(';');
        text = (semi >= 0 && semi < text.length - 1)
            ? text.substring(semi + 1).trimLeft()
            : '';
        continue;
      }
      final match = colorOrAlertPrefix.firstMatch(text);
      if (match == null) break;
      text = text.substring(match.end).trimLeft();
    }
    return text.trim();
  }

  static String? _sanitizeNotificationBody(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;

    final cidRegex = RegExp(
      r'^(kemet_cid:)?ky=\d+-km=\d+-kd=\d+\|s=\d+\|t=[^|]+\|f=[^|]+$',
      caseSensitive: false,
    );
    final kept = <String>[];

    for (final line in raw.split(RegExp(r'\r?\n'))) {
      final cleaned = _stripMetadataPrefixes(line);
      if (cleaned.isEmpty) continue;

      final lowered = cleaned.toLowerCase();
      final collapsed = cleaned.replaceAll(RegExp(r'\s+'), '');
      if (lowered.startsWith('kemet_cid:') ||
          lowered.startsWith('kemetic_cid:') ||
          lowered.startsWith('reminder:') ||
          cidRegex.hasMatch(collapsed.toLowerCase())) {
        continue;
      }

      kept.add(cleaned);
    }

    if (kept.isEmpty) return null;
    final result = kept.join('\n').trim();
    return result.isEmpty ? null : result;
  }

  static String _sanitizeNotificationTitle(String raw) {
    final sanitized = _sanitizeNotificationBody(raw);
    if (sanitized == null || sanitized.isEmpty) {
      return raw.trim();
    }
    return sanitized.replaceAll(RegExp(r'\s*\n\s*'), ' ').trim();
  }

  static String _fallbackNotificationBody() => 'Tap to open in Kemetic.';

  static Future<String?> _lookupEventTitle(String clientEventId) async {
    if (clientEventId.isEmpty) return null;
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return null;

      final row = await client
          .from('user_event_filing_items_client')
          .select('title')
          .eq('client_event_id', clientEventId)
          .maybeSingle();
      final title = (row?['title'] as String?)?.trim();
      if (title == null || title.isEmpty) return null;
      final sanitized = _sanitizeNotificationTitle(title);
      return sanitized.isEmpty ? title : sanitized;
    } catch (_) {
      return null;
    }
  }

  static Future<String> _resolveNotificationTitle({
    required String clientEventId,
    String? preferredTitle,
    String? fallbackTitle,
  }) async {
    final preferred = _sanitizeNotificationTitle(preferredTitle ?? '');
    if (preferred.isNotEmpty) return preferred;

    final fallback = _sanitizeNotificationTitle(fallbackTitle ?? '');
    if (fallback.isNotEmpty) return fallback;

    final lookedUp = await _lookupEventTitle(clientEventId);
    if (lookedUp != null && lookedUp.isNotEmpty) return lookedUp;

    return 'Reminder';
  }

  static String _resolveNotificationBody({String? preferredBody}) {
    final sanitized = _sanitizeNotificationBody(preferredBody);
    if (sanitized != null && sanitized.isNotEmpty) {
      return sanitized;
    }
    return _fallbackNotificationBody();
  }

  static Future<bool> _shouldScheduleLocallyOnThisDevice() async {
    final pushEnabled = await SettingsPrefs.realTimeAlertsEnabled();
    return !pushEnabled;
  }

  static Future<bool> _localNotificationsEnabled({
    bool requestIfMissing = false,
  }) async {
    final androidSpecific = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidSpecific != null) {
      final enabled = await androidSpecific.areNotificationsEnabled();
      if (enabled == true || enabled == null) return true;
      if (!requestIfMissing) return false;

      final requested = await androidSpecific.requestNotificationsPermission();
      if (requested == true) return true;
      final afterRequest = await androidSpecific.areNotificationsEnabled();
      return afterRequest == true;
    }

    if (!requestIfMissing) {
      return true;
    }

    final iosSpecific = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (iosSpecific != null) {
      final granted = await iosSpecific.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted != false;
    }

    final macSpecific = _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
    if (macSpecific != null) {
      final granted = await macSpecific.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted != false;
    }

    return true;
  }

  static Future<String?> localDeliveryPermissionWarning() async {
    if (!_inited) {
      await init();
    }

    final shouldScheduleLocally = await _shouldScheduleLocallyOnThisDevice();
    if (!shouldScheduleLocally) return null;

    final enabled = await _localNotificationsEnabled();
    return enabled ? null : localPermissionMissingMessage;
  }

  static Future<void> _cancelPendingLocalNotificationsOnly() async {
    if (!_inited) return;
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final notification in pending) {
        await _plugin.cancel(notification.id);
      }
      _log(
        'Cancelled ${pending.length} pending local notifications on this device',
      );
    } catch (e) {
      _log('⚠️ Error cancelling pending local notifications: $e');
    }
  }

  static void _requestLocalWindowReconcile({
    Duration delay = _localReconcileDebounce,
    bool refreshExisting = false,
  }) {
    if (!_inited) return;

    _localReconcileQueued = true;
    _localReconcileNeedsRefresh =
        _localReconcileNeedsRefresh || refreshExisting;

    _localReconcileTimer?.cancel();
    _localReconcileTimer = Timer(delay, () {
      _localReconcileTimer = null;
      unawaited(_reconcileLocalScheduleWindow());
    });
  }

  static Future<void> _reconcileLocalScheduleWindow() async {
    if (!_inited) return;
    if (_localReconcileInProgress) {
      _localReconcileQueued = true;
      return;
    }

    _localReconcileTimer?.cancel();
    _localReconcileTimer = null;

    final shouldRefreshExisting = _localReconcileNeedsRefresh;
    _localReconcileQueued = false;
    _localReconcileNeedsRefresh = false;
    _localReconcileInProgress = true;

    try {
      final shouldScheduleLocally = await _shouldScheduleLocallyOnThisDevice();
      if (!shouldScheduleLocally) {
        _log(
          'Push alerts are enabled on this device; clearing local scheduled notifications',
        );
        await _cancelPendingLocalNotificationsOnly();
        return;
      }

      final localNotificationsEnabled = await _localNotificationsEnabled();
      if (!localNotificationsEnabled) {
        _log(
          '$localPermissionMissingMessage Skipping local schedule reconciliation.',
        );
        return;
      }

      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      if (userId == null) {
        _log('No user logged in, skipping local schedule reconciliation');
        return;
      }

      final now = DateTime.now();
      final response = await client
          .from('scheduled_notifications')
          .select()
          .eq('user_id', userId)
          .eq('is_active', true)
          .order('scheduled_at', ascending: true);

      final rows = (response as List)
          .cast<Map<dynamic, dynamic>>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);

      final eventBackedCandidateIds = <String>{};
      for (final row in rows) {
        final clientEventId = (row['client_event_id'] as String?)?.trim();
        if (clientEventId == null || clientEventId.isEmpty) continue;

        final type = _notificationTypeFromValue(
          row['notification_type'] as String?,
        );
        if (_notificationRequiresEventExistence(type)) {
          eventBackedCandidateIds.add(clientEventId);
        }
      }

      final existingEventIds = await _existingEventIdsForNotifications(
        eventBackedCandidateIds,
      );

      final eligibleRows = <Map<String, dynamic>>[];
      int retired = 0;
      for (final row in rows) {
        final clientEventId = (row['client_event_id'] as String?)?.trim();
        if (clientEventId == null || clientEventId.isEmpty) continue;

        final type = _notificationTypeFromValue(
          row['notification_type'] as String?,
        );
        final notificationId =
            row['notification_id'] as int? ??
            _generateFallbackNotificationId(clientEventId, type: type);
        final scheduledAtRaw = row['scheduled_at'] as String?;
        if (scheduledAtRaw == null || scheduledAtRaw.isEmpty) {
          await _plugin.cancel(notificationId);
          await _markNotificationInactive(clientEventId, type: type);
          retired++;
          continue;
        }

        DateTime scheduledAt;
        try {
          scheduledAt = DateTime.parse(scheduledAtRaw);
        } catch (e) {
          _log(
            '⚠️ Invalid scheduled_at for $clientEventId (${type.value}): $e',
          );
          await _plugin.cancel(notificationId);
          await _markNotificationInactive(clientEventId, type: type);
          retired++;
          continue;
        }

        if (!scheduledAt.isAfter(now.add(_minimumScheduleLead))) {
          await _plugin.cancel(notificationId);
          await _markNotificationInactive(clientEventId, type: type);
          retired++;
          continue;
        }

        if (_notificationRequiresEventExistence(type) &&
            !existingEventIds.contains(clientEventId)) {
          await _plugin.cancel(notificationId);
          await _markNotificationInactive(clientEventId, type: type);
          _log(
            'Skipping local schedule; event missing for $clientEventId (${type.value})',
          );
          retired++;
          continue;
        }

        row['notification_id'] = notificationId;
        eligibleRows.add(row);
      }

      final desiredRows = eligibleRows
          .take(_maxConcurrentLocalNotifications)
          .toList(growable: false);
      final deferredCount = eligibleRows.length - desiredRows.length;
      final desiredIds = desiredRows
          .map((row) => row['notification_id'] as int)
          .toSet();

      final pending = await _plugin.pendingNotificationRequests();
      final pendingIds = pending.map((notif) => notif.id).toSet();

      int canceled = 0;
      for (final notif in pending) {
        if (desiredIds.contains(notif.id)) continue;
        await _plugin.cancel(notif.id);
        canceled++;
      }

      int scheduled = 0;
      int refreshed = 0;
      for (final row in desiredRows) {
        final notificationId = row['notification_id'] as int;
        final alreadyPending = pendingIds.contains(notificationId);
        if (alreadyPending && !shouldRefreshExisting) continue;

        try {
          if (alreadyPending) {
            await _plugin.cancel(notificationId);
            refreshed++;
          }

          final clientEventId = row['client_event_id'] as String;
          final scheduledAt = DateTime.parse(row['scheduled_at'] as String);
          final resolvedTitle = await _resolveNotificationTitle(
            clientEventId: clientEventId,
            preferredTitle: row['title'] as String?,
          );
          await _scheduleLocalNotification(
            id: notificationId,
            scheduledAt: scheduledAt,
            title: resolvedTitle,
            body: _resolveNotificationBody(
              preferredBody: row['body'] as String?,
            ),
            payload: row['payload'] as String? ?? '{}',
          );
          scheduled++;
        } catch (e) {
          _log(
            '⚠️ Error reconciling notification $notificationId (${row['client_event_id']}): $e',
          );
        }
      }

      _log(
        '✅ Local schedule window synced '
        '(eligible=${eligibleRows.length}, armed=${desiredRows.length}, '
        'scheduled=$scheduled, refreshed=$refreshed, canceled=$canceled, '
        'retired=$retired, deferred=$deferredCount, '
        'max=$_maxConcurrentLocalNotifications)',
      );
    } catch (e) {
      _log('⚠️ Error reconciling local scheduled notifications: $e');
    } finally {
      _localReconcileInProgress = false;
      if (_localReconcileQueued || _localReconcileNeedsRefresh) {
        final refreshExisting = _localReconcileNeedsRefresh;
        _localReconcileQueued = false;
        _localReconcileNeedsRefresh = false;
        _requestLocalWindowReconcile(
          delay: Duration.zero,
          refreshExisting: refreshExisting,
        );
      }
    }
  }

  static Future<void> syncLocalDeliveryMode() async {
    if (!_inited) {
      await init();
      return;
    }

    final shouldScheduleLocally = await _shouldScheduleLocallyOnThisDevice();
    if (!shouldScheduleLocally) {
      _log(
        'Push alerts are enabled on this device; skipping local scheduled notifications',
      );
      await _cancelPendingLocalNotificationsOnly();
      return;
    }

    await rescheduleAllFromDatabase();
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
        -8: 'America/Los_Angeles', // PST (winter)
        -7: 'America/Los_Angeles', // PDT (summer) ← FIXED!
        -6: 'America/Denver', // MDT (summer) or CST (winter)
        -5: 'America/Chicago', // CDT (summer) or EST (winter)
        -4: 'America/New_York', // EDT (summer)
        -10: 'Pacific/Honolulu', // HST (no DST)
        -9: 'America/Anchorage', // AKST/AKDT
        // International
        0: 'Europe/London', // GMT/BST
        1: 'Europe/Paris', // CET/CEST
        8: 'Asia/Singapore', // SGT
        9: 'Asia/Tokyo', // JST
        10: 'Australia/Sydney', // AEST/AEDT
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

    // 4) Android permissions status only. Startup initialization must not open
    // runtime permission dialogs or the Android exact-alarm settings screen,
    // because those activities sit above Flutter and intercept every tap.
    final androidSpecific = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidSpecific?.createNotificationChannel(
      const AndroidNotificationChannel(
        _androidChannelId,
        _androidChannelName,
        description: _androidChannelDesc,
        importance: Importance.max,
      ),
    );

    final notificationsEnabled = await androidSpecific
        ?.areNotificationsEnabled();
    _log('areNotificationsEnabled() => $notificationsEnabled');

    // 5) Android 12+ exact alarms status. If unavailable, scheduling will use
    // AndroidScheduleMode.inexactAllowWhileIdle instead of launching Settings.
    try {
      final exactGranted = await androidSpecific
          ?.canScheduleExactNotifications();
      if (exactGranted != null) {
        _canScheduleExactAlarms = exactGranted;
      }
      _log('canScheduleExactNotifications() => $exactGranted');
    } catch (e) {
      _canScheduleExactAlarms = false;
      _log('canScheduleExactNotifications() threw: $e (safe to ignore)');
    }

    _inited = true;
    _log('init() done');

    // 6) Apply this device's delivery mode to scheduled notifications.
    await syncLocalDeliveryMode();
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
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

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
  static Future<void> showInstant({required String title, String? body}) async {
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
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

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
    await scheduleAlertWithPersistenceResult(
      clientEventId: clientEventId,
      scheduledAt: scheduledAt,
      title: title,
      body: body,
      payload: payload,
      type: type,
    );
  }

  static Future<NotificationScheduleResult> scheduleAlertWithPersistenceResult({
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

    final notificationIdentity = _notificationIdentity(clientEventId, type);

    // FIX #2: Prevent duplicate scheduling
    if (_schedulingInProgress.contains(notificationIdentity)) {
      _log(
        '⚠️ Already scheduling notification for $notificationIdentity, skipping duplicate',
      );
      return const NotificationScheduleResult.duplicateInProgress();
    }

    try {
      _schedulingInProgress.add(notificationIdentity);

      final now = DateTime.now();

      if (!scheduledAt.isAfter(now.add(_minimumScheduleLead))) {
        final existing = await _getNotificationByEventId(
          clientEventId,
          type: type,
        );
        final notificationId =
            existing?['notification_id'] as int? ??
            _generateFallbackNotificationId(clientEventId, type: type);
        await _plugin.cancel(notificationId);
        await _markNotificationInactive(clientEventId, type: type);
        _log(
          'Skipping already-due notification for $notificationIdentity '
          '(requested=$scheduledAt now=$now); retired any active row instead of re-arming it',
        );
        return const NotificationScheduleResult.skippedAlreadyDue();
      }

      // Check if existing notification needs update
      final existing = await _getNotificationByEventId(
        clientEventId,
        type: type,
      );
      final fallbackNotificationId =
          existing?['notification_id'] as int? ??
          _generateFallbackNotificationId(clientEventId, type: type);
      final shouldScheduleLocally = await _shouldScheduleLocallyOnThisDevice();
      final sanitizedTitle = await _resolveNotificationTitle(
        clientEventId: clientEventId,
        preferredTitle: title,
        fallbackTitle: existing?['title'] as String?,
      );
      final sanitizedBody = _resolveNotificationBody(preferredBody: body);
      if (existing != null) {
        _log(
          'Updating existing notification $fallbackNotificationId for event $clientEventId',
        );
      } else {
        _log(
          'Creating notification row for event $clientEventId (${type.value})',
        );
      }

      // Persist to Supabase
      final persistedNotification = await _persistNotificationToDatabase(
        clientEventId: clientEventId,
        scheduledAt: scheduledAt,
        title: sanitizedTitle,
        body: sanitizedBody,
        payload: payload ?? '{}',
        type: type,
      );
      final notificationId =
          persistedNotification?.notificationId ?? fallbackNotificationId;

      if (shouldScheduleLocally) {
        if (existing != null) {
          await _plugin.cancel(notificationId);
        }

        final localNotificationsEnabled = await _localNotificationsEnabled();
        if (!localNotificationsEnabled) {
          _log(
            '$localPermissionMissingMessage Persisted row for $notificationIdentity but did not arm a local notification.',
          );
          return const NotificationScheduleResult.permissionMissing(
            localPermissionMissingMessage,
          );
        }

        if (persistedNotification != null) {
          _requestLocalWindowReconcile();
          _log(
            'Queued local schedule reconciliation for $notificationIdentity',
          );
          return NotificationScheduleResult.persistedForLocalReconcile(
            scheduledAt,
          );
        } else {
          try {
            await _scheduleLocalNotification(
              id: notificationId,
              scheduledAt: scheduledAt,
              title: sanitizedTitle,
              body: sanitizedBody,
              payload: payload ?? '{}',
            );
            _log(
              '⚠️ Scheduled local fallback without database persistence for $notificationIdentity',
            );
            return NotificationScheduleResult.scheduledLocally(scheduledAt);
          } catch (e) {
            _log(
              '⚠️ Local fallback scheduling failed for $notificationIdentity: $e',
            );
            return NotificationScheduleResult.failed(e.toString());
          }
        }
      } else {
        await _plugin.cancel(notificationId);
        _log(
          'Push alerts enabled on this device; persisted without local schedule for $notificationIdentity',
        );
        return NotificationScheduleResult.persistedForPush(scheduledAt);
      }
    } finally {
      // Always remove from set, even if error occurs
      _schedulingInProgress.remove(notificationIdentity);
    }
  }

  /// Best-effort bulk cancellation used by delete/reconcile paths.
  ///
  /// This always retires matching `scheduled_notifications` rows in Supabase,
  /// and cancels local pending notifications when the plugin is already
  /// initialized in the current process. It intentionally avoids calling
  /// `init()` so cleanup does not trigger a restore pass while rows are being
  /// deleted.
  static Future<void> cancelNotificationsForClientEventIds(
    Iterable<String> clientEventIds,
  ) async {
    final ids = clientEventIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (ids.isEmpty) return;

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;

      const batchSize = 100;
      bool rowsRetired = false;
      for (int i = 0; i < ids.length; i += batchSize) {
        final end = (i + batchSize < ids.length) ? i + batchSize : ids.length;
        final batch = ids.sublist(i, end);

        final response = await client
            .from('scheduled_notifications')
            .select('client_event_id, notification_id')
            .eq('user_id', userId)
            .eq('is_active', true)
            .inFilter('client_event_id', batch);

        final rows = (response as List)
            .cast<Map<dynamic, dynamic>>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList(growable: false);
        if (rows.isEmpty) continue;

        final matchedIds = <String>{};
        for (final row in rows) {
          final cid = (row['client_event_id'] as String?)?.trim();
          if (cid == null || cid.isEmpty) continue;
          matchedIds.add(cid);

          final notificationId = row['notification_id'] as int?;
          if (_inited && notificationId != null) {
            try {
              await _plugin.cancel(notificationId);
            } catch (e) {
              _log(
                '⚠️ Error cancelling local notification $notificationId for $cid: $e',
              );
            }
          }
        }

        if (matchedIds.isEmpty) continue;

        await client
            .from('scheduled_notifications')
            .update({'is_active': false})
            .eq('user_id', userId)
            .inFilter('client_event_id', matchedIds.toList());
        rowsRetired = true;
      }

      if (_inited && rowsRetired) {
        _requestLocalWindowReconcile();
      }
    } catch (e) {
      _log('⚠️ Error cancelling notifications for client_event_ids: $e');
    }
  }

  /// **NEW**: Cancel notification for a specific event
  static Future<void> cancelNotificationForEvent(String clientEventId) async {
    if (!_inited) {
      await init();
    }

    try {
      await cancelNotificationsForClientEventIds([clientEventId]);
      _log('✅ Notification cancelled for event: $clientEventId');
    } catch (e) {
      _log('⚠️ Error cancelling notification: $e');
    }
  }

  /// Cancel every active scheduled notification whose [client_event_id] starts with [prefix].
  /// Used for rhythm field reminders (`rhythm:field:<uuid>:…`).
  static Future<void> cancelByClientEventIdPrefix(String prefix) async {
    if (prefix.isEmpty) return;
    if (!_inited) {
      await init();
    }
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;

      final rows = await client
          .from('scheduled_notifications')
          .select('client_event_id')
          .eq('user_id', userId)
          .eq('is_active', true)
          .like('client_event_id', '$prefix%');

      final matchedIds = <String>{};
      for (final row in (rows as List).cast<Map<String, dynamic>>()) {
        final cid = row['client_event_id'] as String?;
        if (cid != null && cid.isNotEmpty) matchedIds.add(cid);
      }

      if (matchedIds.isNotEmpty) {
        await cancelNotificationsForClientEventIds(matchedIds);
      }
    } catch (e) {
      _log('⚠️ cancelByClientEventIdPrefix: $e');
    }
  }

  /// Cancel notification when event is deleted (simplified version)
  static Future<void> cancelNotification(String clientEventId) async {
    if (!_inited) {
      await init();
    }

    try {
      await cancelNotificationForEvent(clientEventId);
    } catch (e) {
      _log('⚠️ Error canceling notification: $e');
    }
  }

  static Future<Set<String>> _existingEventIdsForNotifications(
    Set<String> clientEventIds,
  ) async {
    final filtered = clientEventIds.where((id) => id.isNotEmpty).toSet();
    if (filtered.isEmpty) return const <String>{};

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return const <String>{};

      final existing = <String>{};
      const batchSize = 100;
      final ids = filtered.toList();

      for (int i = 0; i < ids.length; i += batchSize) {
        final batch = ids.skip(i).take(batchSize).toList();
        final rows = await client
            .from('user_event_filing_items_client')
            .select('client_event_id')
            .inFilter('client_event_id', batch);
        for (final row in (rows as List).cast<Map<String, dynamic>>()) {
          final cid = row['client_event_id'] as String?;
          if (cid != null && cid.isNotEmpty) {
            existing.add(cid);
          }
        }
      }

      return existing;
    } catch (e) {
      _log('⚠️ Error checking event existence for notifications: $e');
      return filtered;
    }
  }

  /// **NEW**: Reschedule all active notifications from database
  /// Call this on app startup to restore all scheduled notifications
  static Future<void> rescheduleAllFromDatabase() async {
    if (!_inited) {
      _log('Cannot reschedule - not initialized');
      return;
    }

    _localReconcileNeedsRefresh = true;
    await _reconcileLocalScheduleWindow();
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
      iOS: iosDetails,
    );

    var scheduleMode = await _androidScheduleMode();
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzScheduled,
        details,
        payload: payload,
        androidScheduleMode: scheduleMode,
      );

      _log('✅ Notification $id scheduled successfully');
    } catch (e) {
      if (scheduleMode != AndroidScheduleMode.inexactAllowWhileIdle &&
          _isExactAlarmDenied(e)) {
        _canScheduleExactAlarms = false;
        scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
        _logInexactAlarmFallback();
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          tzScheduled,
          details,
          payload: payload,
          androidScheduleMode: scheduleMode,
        );
        _log('✅ Notification $id scheduled with inexact fallback');
        return;
      }
      _log('❌ Error scheduling notification $id: $e');
      rethrow;
    }
  }

  static Future<AndroidScheduleMode> _androidScheduleMode() async {
    final androidSpecific = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidSpecific == null) return AndroidScheduleMode.exactAllowWhileIdle;

    var canScheduleExact = _canScheduleExactAlarms;
    if (canScheduleExact == null) {
      try {
        canScheduleExact = await androidSpecific
            .canScheduleExactNotifications();
      } catch (e) {
        canScheduleExact = false;
        _log('canScheduleExactNotifications() threw: $e');
      }
      _canScheduleExactAlarms = canScheduleExact;
    }

    if (canScheduleExact == false) {
      _logInexactAlarmFallback();
      return AndroidScheduleMode.inexactAllowWhileIdle;
    }

    return AndroidScheduleMode.exactAllowWhileIdle;
  }

  static bool _isExactAlarmDenied(Object error) {
    if (error is PlatformException) {
      return error.code == 'exact_alarms_not_permitted';
    }
    return error.toString().contains('exact_alarms_not_permitted');
  }

  static void _logInexactAlarmFallback() {
    if (_loggedInexactAlarmFallback) return;
    _loggedInexactAlarmFallback = true;
    _log(
      'Exact alarm permission is not granted; local notifications will use '
      'inexact Android scheduling on this device.',
    );
  }

  /// **PRIVATE**: Persist notification to Supabase and return its DB-owned
  /// platform notification id.
  static Future<_PersistedNotification?> _persistNotificationToDatabase({
    required String clientEventId,
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
        return null;
      }

      final response = await client.rpc(
        'upsert_scheduled_notification',
        params: <String, dynamic>{
          'p_client_event_id': clientEventId,
          'p_scheduled_at': scheduledAt.toUtc().toIso8601String(),
          'p_title': title,
          'p_body': body,
          'p_payload': payload,
          'p_notification_type': type.value,
        },
      );
      final persisted = _decodePersistedNotification(response);
      if (persisted == null) {
        _log(
          '⚠️ Persisted notification but no notification_id was returned: $clientEventId',
        );
        return null;
      }

      _log(
        'Persisted notification to database: $clientEventId '
        '(notification_id=${persisted.notificationId})',
      );
      return persisted;
    } catch (e) {
      _log('⚠️ Error persisting notification to database: $e');
      return null;
    }
  }

  static _PersistedNotification? _decodePersistedNotification(
    Object? response,
  ) {
    final row = switch (response) {
      List<dynamic> rows when rows.isNotEmpty => rows.first,
      Map<dynamic, dynamic> map => map,
      _ => null,
    };
    if (row is! Map) return null;

    final decoded = Map<String, dynamic>.from(row);
    final notificationId = (decoded['notification_id'] as num?)?.toInt();
    if (notificationId == null || notificationId <= 0) return null;

    return _PersistedNotification(notificationId: notificationId);
  }

  /// **PRIVATE**: Get notification by event ID
  static Future<List<Map<String, dynamic>>> _getNotificationsByEventId(
    String clientEventId,
  ) async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      if (userId == null) return const <Map<String, dynamic>>[];

      final response = await client
          .from('scheduled_notifications')
          .select()
          .eq('user_id', userId)
          .eq('client_event_id', clientEventId)
          .eq('is_active', true);

      return (response as List)
          .cast<Map<dynamic, dynamic>>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    } catch (e) {
      _log('⚠️ Error fetching notifications: $e');
      return const <Map<String, dynamic>>[];
    }
  }

  static Future<Map<String, dynamic>?> _getNotificationByEventId(
    String clientEventId, {
    NotificationType type = NotificationType.eventStart,
  }) async {
    final notifications = await _getNotificationsByEventId(clientEventId);
    for (final notification in notifications) {
      if ((notification['notification_type'] as String?) == type.value) {
        return notification;
      }
    }
    return null;
  }

  /// **PRIVATE**: Mark notification as inactive
  static Future<void> _markNotificationInactive(
    String clientEventId, {
    NotificationType? type,
  }) async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      if (userId == null) return;

      var query = client
          .from('scheduled_notifications')
          .update({'is_active': false})
          .eq('user_id', userId)
          .eq('client_event_id', clientEventId);
      if (type != null) {
        query = query.eq('notification_type', type.value);
      }
      await query;

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

    _log(
      '⚠️ Using deprecated scheduleAlert - consider using scheduleAlertWithPersistence',
    );
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
      _log(
        'Check: Battery optimization, Exact alarm permission, Notification permission',
      );
    }
    _log('========================================');
  }

  /// **NEW**: Debug method to check notification permissions and status
  static Future<void> debugCheckPermissions() async {
    _log('========================================');
    _log('NOTIFICATION PERMISSIONS CHECK');
    _log('========================================');

    try {
      final androidSpecific = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidSpecific != null) {
        final canScheduleExact = await androidSpecific
            .canScheduleExactNotifications();
        _log('✓ Can schedule exact alarms: $canScheduleExact');

        if (canScheduleExact == false) {
          _log('⚠️ WARNING: Exact alarms permission NOT granted!');
          _log(
            '   Go to: Settings → Apps → Your App → Alarms & reminders → Allow',
          );
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
            _log(
              '⚠️ WARNING: Mismatch between device (${pend.length}) and database (${(dbNotifs as List).length})!',
            );
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

      final dbIds = (dbNotifs as List)
          .map((n) => n['notification_id'] as int)
          .toSet();

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
        _log(
          '   → May be old notifications or from deprecated scheduleAlert()',
        );
      }
      _log('');
      _log('⚠️ Only in database: ${onlyDb.length}');
      if (onlyDb.isNotEmpty) {
        _log('   IDs: $onlyDb');
        _log(
          '   → These notifications are in database but not scheduled on device',
        );
        _log('   → This is a sync problem - should reschedule');
      }
      _log('========================================');

      // Provide recommendation
      if (onlyDevice.isEmpty && onlyDb.isEmpty) {
        _log('✅ SYNC STATUS: PERFECT - All notifications synced correctly!');
      } else if (onlyDb.isNotEmpty) {
        _log('⚠️ SYNC STATUS: NEEDS RESCHEDULE - Run "Reschedule All" to fix');
      } else if (onlyDevice.isNotEmpty) {
        _log(
          '⚠️ SYNC STATUS: ORPHANED NOTIFICATIONS - Run "Cancel All" then "Reschedule All"',
        );
      }
      _log('========================================');
    } catch (e) {
      _log('❌ Error comparing: $e');
    }
  }
}
