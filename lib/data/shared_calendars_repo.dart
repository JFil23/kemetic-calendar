import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'event_filing_engine.dart';
import 'event_filing_repo.dart';
import 'shared_calendar_models.dart';
import 'user_events_repo.dart';

class SharedCalendarsRepo {
  SharedCalendarsRepo(this._client);

  final SupabaseClient _client;

  static const String _hiddenCalendarsPrefKey = 'shared_calendars:hidden:v1';
  static const String _calendarFilingView =
      'shared_calendar_filing_items_client';
  static const String _calendarInviteFilingView =
      'shared_calendar_invite_filing_items_client';
  static const String _legacyCalendarSummaryView = 'shared_calendar_summaries';
  static const String _legacyPendingInviteView =
      'shared_calendar_pending_invites';
  static const String _legacySentPendingInviteView =
      'shared_calendar_sent_pending_invites';
  static const String _acceptedCalendarsCacheKeyPrefix =
      'shared_calendars:accepted:v1';
  static const String _pendingInvitesCacheKeyPrefix =
      'shared_calendars:pending_invites:v1';
  static const String _sentInvitesCacheKeyPrefix =
      'shared_calendars:sent_invites:v1';
  static final Map<String, List<SharedCalendarSummary>>
  _acceptedCalendarsMemoryCache = {};
  static final Map<String, List<SharedCalendarInvite>>
  _pendingInvitesMemoryCache = {};
  static final Map<String, List<SharedCalendarSentInvite>>
  _sentInvitesMemoryCache = {};

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[SharedCalendarsRepo] $message');
    }
  }

  String? get _currentUserId => _client.auth.currentUser?.id;

  String _acceptedCalendarsCacheKey(String userId) =>
      '$_acceptedCalendarsCacheKeyPrefix:$userId';

  String _pendingInvitesCacheKey(String userId) =>
      '$_pendingInvitesCacheKeyPrefix:$userId';

  String _sentInvitesCacheKey(String userId) =>
      '$_sentInvitesCacheKeyPrefix:$userId';

  List<SharedCalendarSummary>? cachedAcceptedCalendarsSync() {
    final uid = _currentUserId;
    if (uid == null || uid.isEmpty) return null;
    final items = _acceptedCalendarsMemoryCache[uid];
    if (items == null) return null;
    return List<SharedCalendarSummary>.unmodifiable(items);
  }

  Future<List<SharedCalendarSummary>?> restoreCachedAcceptedCalendars() async {
    final uid = _currentUserId;
    if (uid == null || uid.isEmpty) return null;
    final memoryItems = _acceptedCalendarsMemoryCache[uid];
    if (memoryItems != null) {
      return List<SharedCalendarSummary>.unmodifiable(memoryItems);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_acceptedCalendarsCacheKey(uid));
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      final items = decoded
          .whereType<Map>()
          .map(
            (row) =>
                SharedCalendarSummary.fromRow(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);
      _acceptedCalendarsMemoryCache[uid] =
          List<SharedCalendarSummary>.unmodifiable(items);
      return items;
    } catch (e) {
      _log('restore accepted calendar cache failed: $e');
      return null;
    }
  }

  Future<void> _cacheAcceptedCalendars(
    List<SharedCalendarSummary> calendars,
  ) async {
    final uid = _currentUserId;
    if (uid == null || uid.isEmpty) return;
    final frozen = List<SharedCalendarSummary>.unmodifiable(calendars);
    _acceptedCalendarsMemoryCache[uid] = frozen;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _acceptedCalendarsCacheKey(uid),
        jsonEncode(frozen.map((item) => item.toCacheJson()).toList()),
      );
    } catch (e) {
      _log('persist accepted calendar cache failed: $e');
    }
  }

  List<SharedCalendarInvite>? cachedPendingInvitesSync() {
    final uid = _currentUserId;
    if (uid == null || uid.isEmpty) return null;
    final items = _pendingInvitesMemoryCache[uid];
    if (items == null) return null;
    return List<SharedCalendarInvite>.unmodifiable(items);
  }

  Future<List<SharedCalendarInvite>?> restoreCachedPendingInvites() async {
    final uid = _currentUserId;
    if (uid == null || uid.isEmpty) return null;
    final memoryItems = _pendingInvitesMemoryCache[uid];
    if (memoryItems != null) {
      return List<SharedCalendarInvite>.unmodifiable(memoryItems);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pendingInvitesCacheKey(uid));
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      final items = decoded
          .whereType<Map>()
          .map(
            (row) =>
                SharedCalendarInvite.fromRow(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);
      _pendingInvitesMemoryCache[uid] = List<SharedCalendarInvite>.unmodifiable(
        items,
      );
      return items;
    } catch (e) {
      _log('restore pending invite cache failed: $e');
      return null;
    }
  }

  Future<void> _cachePendingInvites(List<SharedCalendarInvite> items) async {
    final uid = _currentUserId;
    if (uid == null || uid.isEmpty) return;
    final frozen = List<SharedCalendarInvite>.unmodifiable(items);
    _pendingInvitesMemoryCache[uid] = frozen;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _pendingInvitesCacheKey(uid),
        jsonEncode(frozen.map((item) => item.toCacheJson()).toList()),
      );
    } catch (e) {
      _log('persist pending invite cache failed: $e');
    }
  }

  Future<void> _removePendingInviteFromCache(String calendarId) async {
    final uid = _currentUserId;
    if (uid == null || uid.isEmpty) return;
    final current =
        _pendingInvitesMemoryCache[uid] ?? await restoreCachedPendingInvites();
    if (current == null || current.isEmpty) return;
    final next = current
        .where((invite) => invite.calendarId != calendarId)
        .toList(growable: false);
    if (next.length == current.length) return;
    await _cachePendingInvites(next);
  }

  List<SharedCalendarSentInvite>? cachedSentPendingInvitesSync() {
    final uid = _currentUserId;
    if (uid == null || uid.isEmpty) return null;
    final items = _sentInvitesMemoryCache[uid];
    if (items == null) return null;
    return List<SharedCalendarSentInvite>.unmodifiable(items);
  }

  Future<List<SharedCalendarSentInvite>?>
  restoreCachedSentPendingInvites() async {
    final uid = _currentUserId;
    if (uid == null || uid.isEmpty) return null;
    final memoryItems = _sentInvitesMemoryCache[uid];
    if (memoryItems != null) {
      return List<SharedCalendarSentInvite>.unmodifiable(memoryItems);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_sentInvitesCacheKey(uid));
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      final items = decoded
          .whereType<Map>()
          .map(
            (row) => SharedCalendarSentInvite.fromRow(
              Map<String, dynamic>.from(row),
            ),
          )
          .toList(growable: false);
      _sentInvitesMemoryCache[uid] =
          List<SharedCalendarSentInvite>.unmodifiable(items);
      return items;
    } catch (e) {
      _log('restore sent invite cache failed: $e');
      return null;
    }
  }

  Future<void> _cacheSentPendingInvites(
    List<SharedCalendarSentInvite> items,
  ) async {
    final uid = _currentUserId;
    if (uid == null || uid.isEmpty) return;
    final frozen = List<SharedCalendarSentInvite>.unmodifiable(items);
    _sentInvitesMemoryCache[uid] = frozen;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _sentInvitesCacheKey(uid),
        jsonEncode(frozen.map((item) => item.toCacheJson()).toList()),
      );
    } catch (e) {
      _log('persist sent invite cache failed: $e');
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
          .from(_calendarFilingView)
          .select()
          .order('is_personal', ascending: false)
          .order('name', ascending: true);
      final calendars = (rows as List)
          .whereType<Map>()
          .map(
            (row) => SharedCalendarSummary.fromRow(row.cast<String, dynamic>()),
          )
          .toList(growable: false);
      unawaited(_cacheAcceptedCalendars(calendars));
      return calendars;
    } catch (e) {
      _log('getAcceptedCalendars filing view failed: $e');
    }

    try {
      final rows = await _client
          .from(_legacyCalendarSummaryView)
          .select()
          .order('is_personal', ascending: false)
          .order('name', ascending: true);
      final calendars = (rows as List)
          .whereType<Map>()
          .map(
            (row) => SharedCalendarSummary.fromRow(row.cast<String, dynamic>()),
          )
          .toList(growable: false);
      unawaited(_cacheAcceptedCalendars(calendars));
      return calendars;
    } catch (e) {
      _log('getAcceptedCalendars legacy fallback failed: $e');
      return await restoreCachedAcceptedCalendars() ?? const [];
    }
  }

  Future<List<SharedCalendarInvite>> getPendingInvites() async {
    try {
      final rows = await _client
          .from(_calendarInviteFilingView)
          .select()
          .eq('invite_direction', 'incoming')
          .order('invited_at', ascending: false);
      final invites = (rows as List)
          .whereType<Map>()
          .map(
            (row) => SharedCalendarInvite.fromRow(row.cast<String, dynamic>()),
          )
          .toList(growable: false);
      unawaited(_cachePendingInvites(invites));
      return invites;
    } catch (e) {
      _log('getPendingInvites filing view failed: $e');
    }

    try {
      final rows = await _client
          .from(_legacyPendingInviteView)
          .select()
          .order('invited_at', ascending: false);
      final invites = (rows as List)
          .whereType<Map>()
          .map(
            (row) => SharedCalendarInvite.fromRow(row.cast<String, dynamic>()),
          )
          .toList(growable: false);
      unawaited(_cachePendingInvites(invites));
      return invites;
    } catch (e) {
      _log('getPendingInvites legacy fallback failed: $e');
      return await restoreCachedPendingInvites() ?? const [];
    }
  }

  Future<List<SharedCalendarSentInvite>> getSentPendingInvites() async {
    try {
      final rows = await _client
          .from(_calendarInviteFilingView)
          .select()
          .eq('invite_direction', 'sent')
          .order('invited_at', ascending: false);
      final invites = (rows as List)
          .whereType<Map>()
          .map(
            (row) =>
                SharedCalendarSentInvite.fromRow(row.cast<String, dynamic>()),
          )
          .toList(growable: false);
      unawaited(_cacheSentPendingInvites(invites));
      return invites;
    } catch (e) {
      _log('getSentPendingInvites filing view failed: $e');
    }

    try {
      final rows = await _client
          .from(_legacySentPendingInviteView)
          .select()
          .order('invited_at', ascending: false);
      final invites = (rows as List)
          .whereType<Map>()
          .map(
            (row) =>
                SharedCalendarSentInvite.fromRow(row.cast<String, dynamic>()),
          )
          .toList(growable: false);
      unawaited(_cacheSentPendingInvites(invites));
      return invites;
    } catch (e) {
      _log('getSentPendingInvites legacy fallback failed: $e');
      return await restoreCachedSentPendingInvites() ?? const [];
    }
  }

  Future<List<UserEvent>> getCalendarEvents(
    String calendarId, {
    int pageSize = 1000,
  }) async {
    final filedEvents = await getCalendarFiledEvents(
      calendarId,
      pageSize: pageSize,
    );
    return filedEvents.map((entry) => entry.event).toList(growable: false);
  }

  Future<List<FiledEvent>> getCalendarFiledEvents(
    String calendarId, {
    int pageSize = 1000,
  }) async {
    final trimmed = calendarId.trim();
    if (trimmed.isEmpty) return const [];

    try {
      return await EventFilingRepo(
        _client,
      ).getLiveFiledCalendarEvents(trimmed, pageSize: pageSize);
    } catch (e) {
      _log('getCalendarFiledEvents failed: $e');
      rethrow;
    }
  }

  Future<SharedCalendarInvite?> getPendingInviteForCalendar(
    String calendarId,
  ) async {
    final trimmed = calendarId.trim();
    if (trimmed.isEmpty) return null;

    try {
      final row = await _client
          .from(_calendarInviteFilingView)
          .select()
          .eq('calendar_id', trimmed)
          .eq('invite_direction', 'incoming')
          .maybeSingle();
      if (row == null) return null;
      return SharedCalendarInvite.fromRow(Map<String, dynamic>.from(row));
    } catch (e) {
      _log('getPendingInviteForCalendar filing view failed: $e');
    }

    try {
      final row = await _client
          .from(_legacyPendingInviteView)
          .select()
          .eq('calendar_id', trimmed)
          .maybeSingle();
      if (row == null) return null;
      return SharedCalendarInvite.fromRow(Map<String, dynamic>.from(row));
    } catch (e) {
      _log('getPendingInviteForCalendar legacy fallback failed: $e');
      return null;
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

  Future<SharedCalendarsSnapshot?> restoreCachedSnapshot() async {
    final results = await Future.wait<dynamic>([
      restoreCachedAcceptedCalendars(),
      restoreCachedPendingInvites(),
      getHiddenCalendarIds(),
    ]);
    final calendars = results[0] as List<SharedCalendarSummary>?;
    final pendingInvites = results[1] as List<SharedCalendarInvite>?;
    if (calendars == null && pendingInvites == null) return null;
    return SharedCalendarsSnapshot(
      calendars: calendars ?? const <SharedCalendarSummary>[],
      pendingInvites: pendingInvites ?? const <SharedCalendarInvite>[],
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

    unawaited(() async {
      final cached =
          cachedSentPendingInvitesSync() ??
          await restoreCachedSentPendingInvites();
      if (cached != null && !controller.isClosed) {
        lastItems = cached;
        controller.add(cached);
      }
      await emitLatest();
    }());

    controller.onCancel = () async {
      refreshDebounce?.cancel();
      await channel.unsubscribe();
      await controller.close();
    };

    return controller.stream;
  }

  Stream<List<SharedCalendarInvite>> watchPendingInvites() {
    final uid = _client.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) {
      return Stream.value(const <SharedCalendarInvite>[]);
    }

    final controller = StreamController<List<SharedCalendarInvite>>();
    final channelName =
        'shared_calendar_pending_invites_${uid}_${DateTime.now().microsecondsSinceEpoch}';
    List<SharedCalendarInvite> lastItems = const [];
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
        final items = await getPendingInvites();
        lastItems = items;
        if (!controller.isClosed) {
          controller.add(items);
        }
      } catch (e, st) {
        _log('watchPendingInvites refresh failed: $e');
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
          column: 'user_id',
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

    unawaited(() async {
      final cached =
          cachedPendingInvitesSync() ?? await restoreCachedPendingInvites();
      if (cached != null && !controller.isClosed) {
        lastItems = cached;
        controller.add(cached);
      }
      await emitLatest();
    }());

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
    String? calendarName,
    int? calendarColorValue,
  }) async {
    final trimmedCalendarId = calendarId.trim();
    final trimmedUserId = userId.trim();
    await _client.rpc(
      'invite_user_to_shared_calendar',
      params: <String, dynamic>{
        'p_calendar_id': trimmedCalendarId,
        'p_user_id': trimmedUserId,
        'p_role': role.name,
      },
    );

    final metadata = await _calendarPushMetadata(
      calendarId: trimmedCalendarId,
      fallbackName: calendarName,
      fallbackColorValue: calendarColorValue,
    );
    final title = metadata.name.isNotEmpty ? metadata.name : 'Calendar invite';
    await sendCalendarPush(
      userIds: <String>[trimmedUserId],
      title: title,
      body: 'You were invited to join $title.',
      data: <String, dynamic>{
        'type': 'calendar_invite',
        'kind': 'calendar_invite',
        'calendar_id': trimmedCalendarId,
        'calendar_name': title,
        if (metadata.colorValue != null) 'calendar_color': metadata.colorValue,
        'role': role.name,
      },
    );
  }

  Future<void> respondToInvite({
    required String calendarId,
    required bool accept,
    SharedCalendarInvite? invite,
  }) async {
    final trimmedCalendarId = calendarId.trim();
    final pendingInvite =
        invite ?? await getPendingInviteForCalendar(trimmedCalendarId);
    await _client.rpc(
      'respond_to_shared_calendar_invite',
      params: <String, dynamic>{
        'p_calendar_id': trimmedCalendarId,
        'p_accept': accept,
      },
    );
    unawaited(_removePendingInviteFromCache(trimmedCalendarId));

    final inviterId = pendingInvite?.invitedBy?.trim();
    if (inviterId == null || inviterId.isEmpty) return;

    final title = pendingInvite!.calendarName.trim().isNotEmpty
        ? pendingInvite.calendarName.trim()
        : 'Calendar invite';
    final status = accept ? 'accepted' : 'declined';
    await sendCalendarPush(
      userIds: <String>[inviterId],
      title: title,
      body: 'Your calendar invitation was $status.',
      data: <String, dynamic>{
        'type': 'calendar_invite_response',
        'kind': 'calendar_invite_response',
        'calendar_id': trimmedCalendarId,
        'calendar_name': title,
        'calendar_color': pendingInvite.calendarColorValue,
        'invite_status': status,
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

    final currentUserId = _client.auth.currentUser?.id.trim();
    final pushData = <String, dynamic>{if (data != null) ...data};
    final kind = pushData['kind']?.toString().trim();
    if ((pushData['type']?.toString().trim().isEmpty ?? true) &&
        kind != null &&
        kind.isNotEmpty) {
      pushData['type'] = kind;
    }
    if ((pushData['sender_id']?.toString().trim().isEmpty ?? true) &&
        currentUserId != null &&
        currentUserId.isNotEmpty) {
      pushData['sender_id'] = currentUserId;
    }

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
            if (pushData.isNotEmpty) 'data': pushData,
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

  Future<({String name, int? colorValue})> _calendarPushMetadata({
    required String calendarId,
    String? fallbackName,
    int? fallbackColorValue,
  }) async {
    final fallback = (
      name: fallbackName?.trim() ?? '',
      colorValue: fallbackColorValue,
    );
    if (fallback.name.isNotEmpty && fallback.colorValue != null) {
      return fallback;
    }

    try {
      final row = await _client
          .from(_calendarFilingView)
          .select('name, color')
          .eq('id', calendarId)
          .maybeSingle();
      if (row != null) {
        final name = ((row['name'] as String?) ?? '').trim();
        final colorValue = (row['color'] as num?)?.toInt();
        return (
          name: name.isNotEmpty ? name : fallback.name,
          colorValue: colorValue ?? fallback.colorValue,
        );
      }
    } catch (e) {
      _log('calendar push metadata filing lookup failed: $e');
    }

    try {
      final row = await _client
          .from(_legacyCalendarSummaryView)
          .select('name, color')
          .eq('id', calendarId)
          .maybeSingle();
      if (row != null) {
        final name = ((row['name'] as String?) ?? '').trim();
        final colorValue = (row['color'] as num?)?.toInt();
        return (
          name: name.isNotEmpty ? name : fallback.name,
          colorValue: colorValue ?? fallback.colorValue,
        );
      }
    } catch (e) {
      _log('calendar push metadata legacy lookup failed: $e');
    }

    return fallback;
  }
}
