import 'warm_state/warm_json_reads.dart';
import 'warm_state/warm_mutation.dart';
import 'dart:async';
import 'account_view_cache.dart';
import 'account_operation_fence.dart';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'event_filing_engine.dart';
import 'event_filing_repo.dart';
import 'birthday_calendar.dart';
import 'shared_calendar_models.dart';
import 'user_events_repo.dart';
import '../telemetry/telemetry.dart';

class SharedCalendarsRepo {
  SharedCalendarsRepo(this._client);

  final SupabaseClient _client;
  SupabaseClient get client => _client;

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
  static final Map<String, int> _acceptedCalendarVersions = {};
  static Future<void>? _acceptedCalendarWrites;
  static final Map<String, List<SharedCalendarInvite>>
  _pendingInvitesMemoryCache = {};
  static final Map<String, List<SharedCalendarSentInvite>>
  _sentInvitesMemoryCache = {};

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[SharedCalendarsRepo] ${redactLogText(message)}');
    }
  }

  String? get _currentUserId => _client.auth.currentUser?.id;
  String? get currentUserId => _currentUserId;

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

  int _acceptedCalendarVersion(String userId) =>
      _acceptedCalendarVersions[userId] ?? 0;

  int _invalidateAcceptedCalendarReads(String userId) =>
      _acceptedCalendarVersions[userId] = _acceptedCalendarVersion(userId) + 1;

  List<SharedCalendarSummary>? _acceptedCalendarsForAccount(String userId) {
    if (_currentUserId != userId) return null;
    final items = _acceptedCalendarsMemoryCache[userId];
    return items == null
        ? null
        : List<SharedCalendarSummary>.unmodifiable(items);
  }

  Future<List<SharedCalendarSummary>?> restoreCachedAcceptedCalendars() async {
    final accountFence = AccountOperationFence(_client);
    try {
      final uid = accountFence.userId;
      if (uid == null || uid.isEmpty) return null;
      final version = _acceptedCalendarVersion(uid);
      final memoryItems = _acceptedCalendarsForAccount(uid);
      if (memoryItems != null) return memoryItems;

      try {
        final prefs = await SharedPreferences.getInstance();
        if (!accountFence.isCurrent ||
            version != _acceptedCalendarVersion(uid)) {
          return _acceptedCalendarsForAccount(uid);
        }
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
    } finally {
      accountFence.dispose();
    }
  }

  Future<void> _cacheAcceptedCalendars(
    String userId,
    List<SharedCalendarSummary> calendars, {
    required int version,
    bool acknowledgedMutation = false,
  }) async {
    bool isCurrent() =>
        version == _acceptedCalendarVersion(userId) &&
        (acknowledgedMutation || _currentUserId == userId);
    if (!isCurrent()) return;
    final frozen = List<SharedCalendarSummary>.unmodifiable(calendars);
    _acceptedCalendarsMemoryCache[userId] = frozen;
    if (_currentUserId == userId) {
      AccountViewCache.instance.publish(userId, 'calendars.list', frozen);
    }

    // Keep disk publication in the same order as memory publication. A read
    // that began before a confirmed removal cannot later restore the old row.
    bool mayPersist() =>
        identical(_acceptedCalendarsMemoryCache[userId], frozen) &&
        (acknowledgedMutation || _currentUserId == userId);
    final write = (_acceptedCalendarWrites ?? Future<void>.value()).then((
      _,
    ) async {
      if (!mayPersist()) return;
      try {
        final prefs = await SharedPreferences.getInstance();
        if (!mayPersist()) return;
        await prefs.setString(
          _acceptedCalendarsCacheKey(userId),
          jsonEncode(frozen.map((item) => item.toCacheJson()).toList()),
        );
      } catch (e) {
        _log('persist accepted calendar cache failed: $e');
      }
    });
    _acceptedCalendarWrites = write;
    try {
      await write;
    } finally {
      if (identical(_acceptedCalendarWrites, write)) {
        _acceptedCalendarWrites = null;
      }
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

  Future<String?> ensureBirthdaysCalendar() {
    return BirthdayCalendarRepo(_client).ensureBirthdaysCalendar();
  }

  Future<String> createBirthday({
    required String name,
    required DateTime birthday,
    required int alertOffsetMinutes,
  }) {
    return BirthdayCalendarRepo(_client).createBirthday(
      name: name,
      birthday: birthday,
      alertOffsetMinutes: alertOffsetMinutes,
    );
  }

  Future<List<SharedCalendarSummary>> readAcceptedCalendarsOnly() async {
    final accountFence = AccountOperationFence(_client);
    try {
      final uid = accountFence.userId;
      if (uid == null || uid.isEmpty) return const [];
      final version = _acceptedCalendarVersion(uid);
      final cached = _acceptedCalendarsForAccount(uid);
      if (cached != null) return cached;
      final rows = await _client
          .from(_calendarFilingView)
          .select()
          .order('is_personal', ascending: false)
          .order('name')
          .limit(100);
      if (!accountFence.isCurrent || version != _acceptedCalendarVersion(uid)) {
        return _acceptedCalendarsForAccount(uid) ?? const [];
      }
      if (rows.length == 100) {
        throw StateError('Calendar preview coverage unavailable');
      }
      return rows
          .map((r) => SharedCalendarSummary.fromRow(r))
          .toList(growable: false);
    } finally {
      accountFence.dispose();
    }
  }

  Future<List<SharedCalendarSummary>> getAcceptedCalendars() async {
    final accountFence = AccountOperationFence(_client);
    try {
      final uid = accountFence.userId;
      if (uid == null || uid.isEmpty) return const [];
      final version = _acceptedCalendarVersion(uid);
      bool isCurrent() =>
          accountFence.isCurrent && version == _acceptedCalendarVersion(uid);
      await ensurePersonalCalendar();
      if (!isCurrent()) return _acceptedCalendarsForAccount(uid) ?? const [];
      await ensureBirthdaysCalendar();
      if (!isCurrent()) return _acceptedCalendarsForAccount(uid) ?? const [];
      try {
        final rows = await _client
            .from(_calendarFilingView)
            .select()
            .order('is_personal', ascending: false)
            .order('name', ascending: true);
        if (!isCurrent()) return _acceptedCalendarsForAccount(uid) ?? const [];
        final calendars = (rows as List)
            .whereType<Map>()
            .map(
              (row) =>
                  SharedCalendarSummary.fromRow(row.cast<String, dynamic>()),
            )
            .toList(growable: false);
        await _cacheAcceptedCalendars(uid, calendars, version: version);
        return _acceptedCalendarsForAccount(uid) ?? const [];
      } catch (e) {
        _log('getAcceptedCalendars filing view failed: $e');
        if (!isCurrent()) return _acceptedCalendarsForAccount(uid) ?? const [];
        final cached = await restoreCachedAcceptedCalendars();
        if (cached != null) return cached;
      }

      if (!isCurrent()) return _acceptedCalendarsForAccount(uid) ?? const [];
      try {
        final rows = await _client
            .from(_legacyCalendarSummaryView)
            .select()
            .order('is_personal', ascending: false)
            .order('name', ascending: true);
        if (!isCurrent()) return _acceptedCalendarsForAccount(uid) ?? const [];
        final calendars = (rows as List)
            .whereType<Map>()
            .map(
              (row) =>
                  SharedCalendarSummary.fromRow(row.cast<String, dynamic>()),
            )
            .toList(growable: false);
        await _cacheAcceptedCalendars(uid, calendars, version: version);
        return _acceptedCalendarsForAccount(uid) ?? const [];
      } catch (e) {
        _log('getAcceptedCalendars legacy fallback failed: $e');
        if (!isCurrent()) return _acceptedCalendarsForAccount(uid) ?? const [];
        return await restoreCachedAcceptedCalendars() ?? const [];
      }
    } finally {
      accountFence.dispose();
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
    int? maxRows,
    DateTime? startsOnOrAfterUtc,
  }) async {
    final filedEvents = await getCalendarFiledEvents(
      calendarId,
      pageSize: pageSize,
      maxRows: maxRows,
      startsOnOrAfterUtc: startsOnOrAfterUtc,
    );
    return filedEvents.map((entry) => entry.event).toList(growable: false);
  }

  Future<List<FiledEvent>> getCalendarFiledEvents(
    String calendarId, {
    int pageSize = 1000,
    bool cachedOnly = false,
    int? maxRows,
    DateTime? startsOnOrAfterUtc,
  }) async {
    final trimmed = calendarId.trim();
    if (trimmed.isEmpty) return const [];

    try {
      return await EventFilingRepo(_client).getLiveFiledCalendarEvents(
        trimmed,
        pageSize: pageSize,
        cachedOnly: cachedOnly,
        warm: true,
        maxRows: maxRows,
        startsOnOrAfterUtc: startsOnOrAfterUtc,
      );
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
      AccountViewCache.instance.publish(
        uid,
        'pages.hiddenCalendars',
        Set<String>.unmodifiable(hidden),
      );
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

  /// Keeps a repository-owned realtime stream bound to the authenticated
  /// account, including when Supabase restores that account after the caller
  /// has already subscribed.
  ///
  /// Inbox can mount before `currentUser` is restored on a web cold start.
  /// Returning a one-shot empty stream in that state permanently loses the
  /// later authenticated subscription, so auth changes must replace the
  /// account-scoped realtime stream rather than end it.
  Stream<T> _watchAuthenticated<T>({
    required T signedOutValue,
    required Stream<T> Function(String userId) watchForUser,
  }) {
    late final StreamController<T> controller;
    StreamSubscription<AuthState>? authSubscription;
    StreamSubscription<T>? accountSubscription;
    String? targetUserId;
    var hasTarget = false;
    var bindGeneration = 0;

    Future<void> bind(String? rawUserId) async {
      final trimmedUserId = rawUserId?.trim();
      final nextUserId = trimmedUserId == null || trimmedUserId.isEmpty
          ? null
          : trimmedUserId;
      if (hasTarget && targetUserId == nextUserId) return;

      hasTarget = true;
      targetUserId = nextUserId;
      final generation = ++bindGeneration;
      final previous = accountSubscription;
      accountSubscription = null;
      if (previous != null) {
        await previous.cancel();
      }
      if (controller.isClosed || generation != bindGeneration) return;

      if (nextUserId == null) {
        controller.add(signedOutValue);
        return;
      }

      accountSubscription = watchForUser(nextUserId).listen(
        (value) {
          if (!controller.isClosed && generation == bindGeneration) {
            controller.add(value);
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!controller.isClosed && generation == bindGeneration) {
            controller.addError(error, stackTrace);
          }
        },
      );
    }

    controller = StreamController<T>(
      onListen: () {
        authSubscription = _client.auth.onAuthStateChange.listen(
          (state) => unawaited(bind(state.session?.user.id)),
          onError: (Object error, StackTrace stackTrace) {
            if (!controller.isClosed) {
              controller.addError(error, stackTrace);
            }
          },
        );
        unawaited(bind(_client.auth.currentUser?.id));
      },
      onCancel: () async {
        bindGeneration += 1;
        await authSubscription?.cancel();
        await accountSubscription?.cancel();
        await controller.close();
      },
    );
    return controller.stream;
  }

  Stream<List<SharedCalendarSentInvite>> watchSentPendingInvites() {
    return _watchAuthenticated<List<SharedCalendarSentInvite>>(
      signedOutValue: const <SharedCalendarSentInvite>[],
      watchForUser: _watchSentPendingInvitesForUser,
    );
  }

  Stream<List<SharedCalendarSentInvite>> _watchSentPendingInvitesForUser(
    String uid,
  ) {
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
          final safeError = redactLogText(error?.toString() ?? 'null');
          debugPrint(
            '[SharedCalendarsRepo] channel=shared_calendar_sent_invites '
            'user=${safeLogIdentifier(uid)} status=$status error=$safeError',
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
    return _watchAuthenticated<List<SharedCalendarInvite>>(
      signedOutValue: const <SharedCalendarInvite>[],
      watchForUser: _watchPendingInvitesForUser,
    );
  }

  Stream<List<SharedCalendarInvite>> _watchPendingInvitesForUser(String uid) {
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
          final safeError = redactLogText(error?.toString() ?? 'null');
          debugPrint(
            '[SharedCalendarsRepo] channel=shared_calendar_pending_invites '
            'user=${safeLogIdentifier(uid)} status=$status error=$safeError',
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
    final warmAccount = _client.auth.currentUser?.id;
    invalidateWarmDomains(warmAccount, [
      'filing.calendar.',
      'pages.calendar',
      'calendars.',
      'pages.member',
    ]);
    try {
      final response = await _client.rpc(
        'create_shared_calendar',
        params: <String, dynamic>{'p_name': name.trim(), 'p_color': colorValue},
      );
      if (response is String && response.trim().isNotEmpty) {
        return response.trim();
      }
      throw StateError('Calendar was created but no id was returned.');
    } finally {
      invalidateWarmDomains(warmAccount, [
        'filing.calendar.',
        'pages.calendar',
        'calendars.',
        'pages.member',
      ]);
    }
  }

  Future<void> updateCalendar({
    required String calendarId,
    required String name,
    int? colorValue,
  }) async {
    final warmAccount = _client.auth.currentUser?.id;
    invalidateWarmDomains(warmAccount, [
      'filing.calendar.',
      'pages.calendar',
      'calendars.',
      'pages.member',
    ]);
    try {
      await _client.rpc(
        'update_shared_calendar',
        params: <String, dynamic>{
          'p_calendar_id': calendarId,
          'p_name': name.trim(),
          if (colorValue != null) 'p_color': colorValue,
        },
      );
    } finally {
      invalidateWarmDomains(warmAccount, [
        'filing.calendar.',
        'pages.calendar',
        'calendars.',
        'pages.member',
      ]);
    }
  }

  Future<void> inviteUser({
    required String calendarId,
    required String userId,
    SharedCalendarRole role = SharedCalendarRole.editor,
    int? sourceFlowId,
    String? calendarName,
    int? calendarColorValue,
  }) async {
    final warmAccount = _client.auth.currentUser?.id;
    invalidateWarmDomains(warmAccount, [
      'filing.calendar.',
      'pages.calendar',
      'calendars.',
      'pages.member',
    ]);
    try {
      final trimmedCalendarId = calendarId.trim();
      final trimmedUserId = userId.trim();
      await _client.rpc(
        'invite_user_to_shared_calendar',
        params: <String, dynamic>{
          'p_calendar_id': trimmedCalendarId,
          'p_user_id': trimmedUserId,
          'p_role': role.name,
          if (sourceFlowId != null && sourceFlowId > 0)
            'p_source_flow_id': sourceFlowId,
        },
      );

      final metadata = await _calendarPushMetadata(
        calendarId: trimmedCalendarId,
        fallbackName: calendarName,
        fallbackColorValue: calendarColorValue,
      );
      final title = metadata.name.isNotEmpty
          ? metadata.name
          : 'Calendar invite';
      await sendCalendarPush(
        userIds: <String>[trimmedUserId],
        title: title,
        body: 'You were invited to join $title.',
        data: <String, dynamic>{
          'type': 'calendar_invite',
          'kind': 'calendar_invite',
          'calendar_id': trimmedCalendarId,
          'calendar_name': title,
          if (metadata.colorValue != null)
            'calendar_color': metadata.colorValue,
          'role': role.name,
        },
      );
    } finally {
      invalidateWarmDomains(warmAccount, [
        'filing.calendar.',
        'pages.calendar',
        'calendars.',
        'pages.member',
      ]);
    }
  }

  Future<List<SharedCalendarMember>> restoreCachedMembers(
    String calendarId, {
    bool includePending = false,
  }) async {
    final rows = await WarmJsonReads(
      _client,
      cachedOnly: true,
    ).rows('calendars.members.$calendarId.$includePending', () async => []);
    return rows.map(SharedCalendarMember.fromRow).toList();
  }

  Future<List<SharedCalendarMember>> listMembers(
    String calendarId, {
    bool includePending = false,
    int? expectedMemberCount,
    int? expectedPendingCount,
  }) async {
    final rows = await WarmJsonReads(_client).rows(
      'calendars.members.$calendarId.$includePending',
      () async {
        final members = await _fetchMembers(
          calendarId,
          includePending: includePending,
          expectedMemberCount: expectedMemberCount,
          expectedPendingCount: expectedPendingCount,
        );
        return members.map((m) => m.toCacheJson()).toList();
      },
    );
    return rows.map(SharedCalendarMember.fromRow).toList();
  }

  Future<List<SharedCalendarMember>> _fetchMembers(
    String calendarId, {
    bool includePending = false,
    int? expectedMemberCount,
    int? expectedPendingCount,
  }) async {
    final trimmed = calendarId.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Calendar id is missing.');
    }
    final expectedTotal =
        (expectedMemberCount ?? 0) +
        (includePending ? (expectedPendingCount ?? 0) : 0);

    try {
      final response = await _client.rpc(
        'list_shared_calendar_members',
        params: <String, dynamic>{'p_calendar_id': trimmed},
      );
      final members = _decodeMemberRows(response);
      if (members.isNotEmpty || expectedTotal <= 0) return members;
      _log('listMembers RPC returned ${response.runtimeType}; using fallback');
    } catch (e) {
      _log('listMembers RPC failed: $e; using fallback');
    }

    return _listMembersFromTables(trimmed, includePending: includePending);
  }

  List<SharedCalendarMember> _decodeMemberRows(Object? response) {
    if (response == null) return const <SharedCalendarMember>[];
    if (response is! List) {
      throw StateError(
        'Unexpected member roster response: ${response.runtimeType}',
      );
    }

    return response
        .whereType<Map>()
        .map(
          (row) => SharedCalendarMember.fromRow(Map<String, dynamic>.from(row)),
        )
        .where((member) => member.userId.trim().isNotEmpty)
        .toList(growable: false);
  }

  Future<List<SharedCalendarMember>> _listMembersFromTables(
    String calendarId, {
    required bool includePending,
  }) async {
    final statuses = includePending
        ? const <String>['accepted', 'pending']
        : const <String>['accepted'];
    final rows = await _client
        .from('shared_calendar_members')
        .select(
          'user_id, role, status, invited_by, created_at, responded_at, updated_at',
        )
        .eq('calendar_id', calendarId)
        .inFilter('status', statuses);
    final rawRows = (rows as List)
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
    if (rawRows.isEmpty) return const <SharedCalendarMember>[];

    final userIds = rawRows
        .map((row) => row['user_id']?.toString().trim())
        .whereType<String>()
        .where((userId) => userId.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final profilesById = <String, Map<String, dynamic>>{};
    if (userIds.isNotEmpty) {
      final profileRows = await _client
          .from('profiles')
          .select('id, handle, display_name, avatar_url')
          .inFilter('id', userIds);
      for (final row in (profileRows as List).whereType<Map>()) {
        final profile = Map<String, dynamic>.from(row);
        final id = profile['id']?.toString().trim();
        if (id != null && id.isNotEmpty) {
          profilesById[id] = profile;
        }
      }
    }

    return rawRows
        .map((row) {
          final userId = row['user_id']?.toString().trim();
          final profile = userId == null ? null : profilesById[userId];
          return SharedCalendarMember.fromRow(<String, dynamic>{
            ...row,
            'invited_at': row['created_at'],
            if (profile != null) ...profile,
          });
        })
        .where((member) => member.userId.trim().isNotEmpty)
        .toList(growable: false);
  }

  Future<void> updateMemberRole({
    required String calendarId,
    required String userId,
    required SharedCalendarRole role,
  }) async {
    final warmAccount = _client.auth.currentUser?.id;
    invalidateWarmDomains(warmAccount, [
      'filing.calendar.',
      'pages.calendar',
      'calendars.',
      'pages.member',
    ]);
    try {
      await _client.rpc(
        'update_shared_calendar_member_role',
        params: <String, dynamic>{
          'p_calendar_id': calendarId.trim(),
          'p_user_id': userId.trim(),
          'p_role': role.name,
        },
      );
    } finally {
      invalidateWarmDomains(warmAccount, [
        'filing.calendar.',
        'pages.calendar',
        'calendars.',
        'pages.member',
      ]);
    }
  }

  Future<void> removeMember({
    required String calendarId,
    required String userId,
  }) async {
    final warmAccount = _client.auth.currentUser?.id;
    invalidateWarmDomains(warmAccount, [
      'filing.calendar.',
      'pages.calendar',
      'calendars.',
      'pages.member',
    ]);
    try {
      await _client.rpc(
        'remove_shared_calendar_member',
        params: <String, dynamic>{
          'p_calendar_id': calendarId.trim(),
          'p_user_id': userId.trim(),
        },
      );
    } finally {
      invalidateWarmDomains(warmAccount, [
        'filing.calendar.',
        'pages.calendar',
        'calendars.',
        'pages.member',
      ]);
    }
  }

  Future<void> revokeInvite({
    required String calendarId,
    required String userId,
  }) async {
    final warmAccount = _client.auth.currentUser?.id;
    invalidateWarmDomains(warmAccount, [
      'filing.calendar.',
      'pages.calendar',
      'calendars.',
      'pages.member',
    ]);
    try {
      await _client.rpc(
        'revoke_shared_calendar_invite',
        params: <String, dynamic>{
          'p_calendar_id': calendarId.trim(),
          'p_user_id': userId.trim(),
        },
      );
    } finally {
      invalidateWarmDomains(warmAccount, [
        'filing.calendar.',
        'pages.calendar',
        'calendars.',
        'pages.member',
      ]);
    }
  }

  Future<void> respondToInvite({
    required String calendarId,
    required bool accept,
    SharedCalendarInvite? invite,
  }) async {
    final warmAccount = _client.auth.currentUser?.id;
    invalidateWarmDomains(warmAccount, [
      'filing.calendar.',
      'pages.calendar',
      'calendars.',
      'pages.member',
    ]);
    try {
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
    } finally {
      invalidateWarmDomains(warmAccount, [
        'filing.calendar.',
        'pages.calendar',
        'calendars.',
        'pages.member',
      ]);
    }
  }

  Future<void> leaveCalendar(String calendarId) async {
    final accountFence = AccountOperationFence(_client);
    try {
      final account = accountFence.userId;
      if (account == null || account.isEmpty) {
        throw StateError('Sign in before removing a calendar.');
      }
      final trimmedId = calendarId.trim();
      if (trimmedId.isEmpty) {
        throw ArgumentError.value(calendarId, 'calendarId');
      }
      // Restore the established snapshot before changing it, including when this
      // write is the repository's first operation after an app restart.
      await restoreCachedAcceptedCalendars();
      if (!accountFence.isCurrent) {
        throw StateError('Account changed before removing the calendar.');
      }
      _invalidateAcceptedCalendarReads(account);
      invalidateWarmDomains(account, [
        'filing.calendar.',
        'pages.calendar',
        'calendars.',
        'pages.member',
      ]);
      try {
        await _client.rpc(
          'leave_shared_calendar',
          params: <String, dynamic>{'p_calendar_id': trimmedId},
        );
        final version = _invalidateAcceptedCalendarReads(account);
        final current = _acceptedCalendarsMemoryCache[account];
        if (current != null) {
          await _cacheAcceptedCalendars(
            account,
            current.where((calendar) => calendar.id != trimmedId).toList(),
            version: version,
            acknowledgedMutation: true,
          );
        }
      } finally {
        _invalidateAcceptedCalendarReads(account);
        invalidateWarmDomains(account, [
          'filing.calendar.',
          'pages.calendar',
          'calendars.',
          'pages.member',
        ]);
      }
    } finally {
      accountFence.dispose();
    }
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

  Future<void> notifySharedCalendarItemAdded({
    required String? calendarId,
    required String itemType,
    required String itemId,
    String? itemTitle,
    String? clientEventId,
    int? flowId,
    String? eventId,
    String? noteId,
    String? reminderId,
    String? taskId,
    DateTime? startDate,
    DateTime? endDate,
    int? kYear,
    int? kMonth,
    int? kDay,
  }) async {
    String dateOnlyIso(DateTime value) {
      final local = DateTime(value.year, value.month, value.day);
      return local.toIso8601String();
    }

    final trimmedCalendarId = calendarId?.trim();
    final trimmedItemType = itemType.trim();
    final trimmedItemId = itemId.trim();
    if (trimmedCalendarId == null ||
        trimmedCalendarId.isEmpty ||
        trimmedItemType.isEmpty ||
        trimmedItemId.isEmpty) {
      return;
    }

    try {
      await _client.functions.invoke(
        'notify_shared_calendar_item_added',
        body: <String, dynamic>{
          'calendar_id': trimmedCalendarId,
          'item_type': trimmedItemType,
          'item_id': trimmedItemId,
          if (itemTitle != null && itemTitle.trim().isNotEmpty)
            'item_title': itemTitle.trim(),
          if (clientEventId != null && clientEventId.trim().isNotEmpty)
            'client_event_id': clientEventId.trim(),
          if (flowId != null && flowId > 0) 'flow_id': flowId,
          if (eventId != null && eventId.trim().isNotEmpty)
            'event_id': eventId.trim(),
          if (noteId != null && noteId.trim().isNotEmpty)
            'note_id': noteId.trim(),
          if (reminderId != null && reminderId.trim().isNotEmpty)
            'reminder_id': reminderId.trim(),
          if (taskId != null && taskId.trim().isNotEmpty)
            'task_id': taskId.trim(),
          if (startDate != null) 'start_date': dateOnlyIso(startDate),
          if (endDate != null) 'end_date': dateOnlyIso(endDate),
          if (kYear != null) 'k_year': kYear,
          if (kMonth != null) 'k_month': kMonth,
          if (kDay != null) 'k_day': kDay,
        },
      );
    } catch (e) {
      _log('notifySharedCalendarItemAdded failed: $e');
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
