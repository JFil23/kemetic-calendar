import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'shared_calendar_models.dart';

class SharedCalendarsRepo {
  SharedCalendarsRepo(this._client);

  final SupabaseClient _client;

  static const String _hiddenCalendarsPrefKey = 'shared_calendars:hidden:v1';

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[SharedCalendarsRepo] $message');
    }
  }

  Future<String?> ensurePersonalCalendar() async {
    try {
      final response = await _client.rpc('ensure_personal_calendar_for_user');
      if (response is String && response.trim().isNotEmpty) {
        return response.trim();
      }
      return null;
    } catch (e) {
      _log('ensurePersonalCalendar failed: $e');
      return null;
    }
  }

  Future<List<SharedCalendarSummary>> getAcceptedCalendars() async {
    await ensurePersonalCalendar();
    try {
      final rows = await _client
          .from('shared_calendar_summaries')
          .select()
          .order('is_personal', ascending: false)
          .order('name', ascending: true);
      return (rows as List)
          .whereType<Map>()
          .map(
            (row) => SharedCalendarSummary.fromRow(row.cast<String, dynamic>()),
          )
          .toList(growable: false);
    } catch (e) {
      _log('getAcceptedCalendars failed: $e');
      return const [];
    }
  }

  Future<List<SharedCalendarInvite>> getPendingInvites() async {
    try {
      final rows = await _client
          .from('shared_calendar_pending_invites')
          .select()
          .order('invited_at', ascending: false);
      return (rows as List)
          .whereType<Map>()
          .map(
            (row) => SharedCalendarInvite.fromRow(row.cast<String, dynamic>()),
          )
          .toList(growable: false);
    } catch (e) {
      _log('getPendingInvites failed: $e');
      return const [];
    }
  }

  Future<List<SharedCalendarSentInvite>> getSentPendingInvites() async {
    try {
      final rows = await _client
          .from('shared_calendar_sent_pending_invites')
          .select()
          .order('invited_at', ascending: false);
      return (rows as List)
          .whereType<Map>()
          .map(
            (row) =>
                SharedCalendarSentInvite.fromRow(row.cast<String, dynamic>()),
          )
          .toList(growable: false);
    } catch (e) {
      _log('getSentPendingInvites failed: $e');
      return const [];
    }
  }

  Future<Set<String>> getHiddenCalendarIds() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) return <String>{};
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList('$_hiddenCalendarsPrefKey:$uid');
      return (stored ?? const <String>[])
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toSet();
    } catch (e) {
      _log('getHiddenCalendarIds failed: $e');
      return <String>{};
    }
  }

  Future<void> setCalendarVisible(String calendarId, bool visible) async {
    final uid = _client.auth.currentUser?.id;
    final trimmed = calendarId.trim();
    if (uid == null || uid.isEmpty || trimmed.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_hiddenCalendarsPrefKey:$uid';
      final hidden = (prefs.getStringList(key) ?? const <String>[])
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toSet();
      if (visible) {
        hidden.remove(trimmed);
      } else {
        hidden.add(trimmed);
      }
      await prefs.setStringList(key, hidden.toList()..sort());
    } catch (e) {
      _log('setCalendarVisible failed: $e');
    }
  }

  Future<SharedCalendarsSnapshot> loadSnapshot() async {
    final results = await Future.wait<dynamic>([
      getAcceptedCalendars(),
      getPendingInvites(),
      getHiddenCalendarIds(),
    ]);
    return SharedCalendarsSnapshot(
      calendars: results[0] as List<SharedCalendarSummary>,
      pendingInvites: results[1] as List<SharedCalendarInvite>,
      hiddenCalendarIds: results[2] as Set<String>,
    );
  }

  Stream<List<SharedCalendarSentInvite>> watchSentPendingInvites() {
    final uid = _client.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) {
      return Stream.value(const <SharedCalendarSentInvite>[]);
    }

    final controller = StreamController<List<SharedCalendarSentInvite>>();
    final channelName =
        'shared_calendar_sent_invites_${uid}_${DateTime.now().microsecondsSinceEpoch}';
    List<SharedCalendarSentInvite> lastItems = const [];
    Timer? refreshDebounce;
    bool refreshInFlight = false;
    bool refreshQueued = false;

    Future<void> emitLatest() async {
      if (refreshInFlight) {
        refreshQueued = true;
        return;
      }
      refreshInFlight = true;
      try {
        final items = await getSentPendingInvites();
        lastItems = items;
        if (!controller.isClosed) {
          controller.add(items);
        }
      } catch (e, st) {
        _log('watchSentPendingInvites refresh failed: $e');
        if (kDebugMode) {
          debugPrint('$st');
        }
        if (!controller.isClosed) {
          controller.add(lastItems);
        }
      } finally {
        refreshInFlight = false;
        if (refreshQueued) {
          refreshQueued = false;
          unawaited(emitLatest());
        }
      }
    }

    void scheduleRefresh() {
      refreshDebounce?.cancel();
      refreshDebounce = Timer(const Duration(milliseconds: 120), () {
        unawaited(emitLatest());
      });
    }

    final channel = _client.channel(channelName)
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'shared_calendar_members',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'invited_by',
          value: uid,
        ),
        callback: (_) => scheduleRefresh(),
      )
      ..subscribe((status, [error]) {
        if (kDebugMode) {
          debugPrint(
            '[SharedCalendarsRepo] channel=$channelName status=$status error=$error',
          );
        }
        switch (status) {
          case RealtimeSubscribeStatus.subscribed:
            scheduleRefresh();
            break;
          case RealtimeSubscribeStatus.channelError:
          case RealtimeSubscribeStatus.timedOut:
            scheduleRefresh();
            break;
          case RealtimeSubscribeStatus.closed:
            break;
        }
      });

    unawaited(emitLatest());

    controller.onCancel = () async {
      refreshDebounce?.cancel();
      await channel.unsubscribe();
      await controller.close();
    };

    return controller.stream;
  }

  Future<String> createCalendar({
    required String name,
    required int colorValue,
  }) async {
    final response = await _client.rpc(
      'create_shared_calendar',
      params: <String, dynamic>{'p_name': name.trim(), 'p_color': colorValue},
    );
    if (response is String && response.trim().isNotEmpty) {
      return response.trim();
    }
    throw StateError('Calendar was created but no id was returned.');
  }

  Future<void> updateCalendar({
    required String calendarId,
    required String name,
    int? colorValue,
  }) async {
    await _client.rpc(
      'update_shared_calendar',
      params: <String, dynamic>{
        'p_calendar_id': calendarId,
        'p_name': name.trim(),
        if (colorValue != null) 'p_color': colorValue,
      },
    );
  }

  Future<void> inviteUser({
    required String calendarId,
    required String userId,
    SharedCalendarRole role = SharedCalendarRole.editor,
  }) async {
    await _client.rpc(
      'invite_user_to_shared_calendar',
      params: <String, dynamic>{
        'p_calendar_id': calendarId,
        'p_user_id': userId,
        'p_role': role.name,
      },
    );
  }

  Future<void> respondToInvite({
    required String calendarId,
    required bool accept,
  }) async {
    await _client.rpc(
      'respond_to_shared_calendar_invite',
      params: <String, dynamic>{
        'p_calendar_id': calendarId,
        'p_accept': accept,
      },
    );
  }

  Future<void> leaveCalendar(String calendarId) async {
    await _client.rpc(
      'leave_shared_calendar',
      params: <String, dynamic>{'p_calendar_id': calendarId},
    );
  }

  Future<List<String>> getAcceptedMemberIds(
    String calendarId, {
    bool excludeCurrentUser = true,
  }) async {
    final trimmed = calendarId.trim();
    if (trimmed.isEmpty) return const [];

    final currentUserId = _client.auth.currentUser?.id.trim();
    try {
      final rows = await _client
          .from('shared_calendar_members')
          .select('user_id')
          .eq('calendar_id', trimmed)
          .eq('status', 'accepted');
      return (rows as List)
          .whereType<Map>()
          .map((row) => (row['user_id'] as String?)?.trim())
          .whereType<String>()
          .where(
            (userId) =>
                userId.isNotEmpty &&
                (!excludeCurrentUser || userId != currentUserId),
          )
          .toSet()
          .toList(growable: false);
    } catch (e) {
      _log('getAcceptedMemberIds failed: $e');
      return const [];
    }
  }

  Future<void> sendCalendarPush({
    required List<String> userIds,
    required String title,
    String? body,
    Map<String, dynamic>? data,
  }) async {
    final recipients = userIds
        .map((userId) => userId.trim())
        .where((userId) => userId.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (recipients.isEmpty) return;

    for (var i = 0; i < recipients.length; i += 5) {
      final batch = recipients.sublist(
        i,
        i + 5 > recipients.length ? recipients.length : i + 5,
      );
      try {
        await _client.functions.invoke(
          'send_push',
          body: <String, dynamic>{
            'userIds': batch,
            'notification': <String, dynamic>{
              'title': title,
              if (body != null && body.trim().isNotEmpty) 'body': body.trim(),
            },
            if (data != null && data.isNotEmpty) 'data': data,
          },
        );
      } catch (e) {
        _log('sendCalendarPush batch failed: $e');
      }
    }
  }

  Future<int> createCalendarNotifications({
    required String calendarId,
    required List<String> userIds,
    String kind = 'calendar_event',
    required String title,
    String? body,
    Map<String, dynamic>? data,
  }) async {
    final trimmedCalendarId = calendarId.trim();
    final recipients = userIds
        .map((userId) => userId.trim())
        .where((userId) => userId.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (trimmedCalendarId.isEmpty || recipients.isEmpty) return 0;

    try {
      final response = await _client.rpc(
        'notify_shared_calendar_members',
        params: <String, dynamic>{
          'p_calendar_id': trimmedCalendarId,
          'p_recipient_ids': recipients,
          'p_kind': kind,
          'p_title': title.trim(),
          'p_body': body?.trim(),
          'p_payload': data ?? const <String, dynamic>{},
        },
      );
      if (response is int) return response;
      if (response is num) return response.toInt();
      return 0;
    } catch (e) {
      _log('createCalendarNotifications failed: $e');
      return 0;
    }
  }
}
