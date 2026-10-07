import 'account_operation_fence.dart';
import 'warm_state/warm_json_reads.dart';
import 'warm_state/warm_snapshot_store.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'birthday_calendar.dart';
import 'event_filing_engine.dart';
import 'user_events_repo.dart';

class EventFilingRepo {
  EventFilingRepo(this._client);

  final SupabaseClient _client;

  static const String viewName = 'user_event_filing_items_client';
  static const String selectColumns =
      'id,user_id,client_event_id,calendar_id,calendar_name,calendar_color,'
      'calendar_is_personal,title,detail,location,all_day,starts_at,ends_at,'
      'flow_local_id,category,action_id,behavior_payload,updated_at,created_at,'
      'filed_flow_id,flow_active,flow_is_hidden,flow_is_reminder,flow_is_saved,'
      'flow_notes,item_kind,lifecycle,live_on_calendar,is_saved,is_shared,'
      'is_posted,active_until,date_lifecycle,reason_item_kind,reason_deleted,'
      'reason_active_until,user_timezone,is_shared_calendar_source,'
      'is_event_share_source,is_flow_share_source,is_flow_post_source,'
      'is_flow_saved_source,is_active_reminder_source,'
      'is_scheduled_notification_source,filing_reasons';

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[EventFilingRepo] $message');
    }
  }

  /// A bounded page from the existing filing authority; no hydration or writes.
  Future<List<FiledEvent>> getOwnedItemsPage({
    required FiledItemKind kind,
    required int offset,
    int pageSize = 50,
    DateTime? startsOnOrAfterUtc,
    bool cachedOnly = false,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const [];
    final rows = await WarmJsonReads(_client, cachedOnly: cachedOnly).rows(
      'filing.${kind.name}.$offset.$pageSize.${startsOnOrAfterUtc?.toIso8601String()}',
      () => _client.rpc(
        'get_owned_filing_page_v1',
        params: {
          'p_kind': kind.name,
          'p_offset': offset,
          'p_limit': pageSize,
          'p_starts_on_or_after': startsOnOrAfterUtc?.toUtc().toIso8601String(),
        },
      ),
    );
    return rows.map((row) => FiledEvent.fromBackendRow(row)).toList();
  }

  Future<FiledEventCabinet> getEventCabinet({
    String? calendarId,
    bool liveOnly = false,
    int pageSize = 1000,
    int? maxRows,
    DateTime? startsOnOrAfterUtc,
    bool cachedOnly = false,
    bool warm = false,
  }) async {
    Future<List<Map<String, dynamic>>> read() => _readCabinetRows(
      calendarId: calendarId,
      liveOnly: liveOnly,
      pageSize: pageSize,
      maxRows: maxRows,
      startsOnOrAfterUtc: startsOnOrAfterUtc,
      strict: warm,
    );
    final rows = warm || cachedOnly
        ? await WarmJsonReads(_client, cachedOnly: cachedOnly).rows(
            'filing.calendar.$calendarId.$liveOnly.$pageSize.$maxRows.${startsOnOrAfterUtc?.toIso8601String()}',
            read,
          )
        : await read();
    return FiledEventCabinet.fromBackendRows(rows);
  }

  Future<List<Map<String, dynamic>>> _readCabinetRows({
    String? calendarId,
    bool liveOnly = false,
    int pageSize = 1000,
    int? maxRows,
    DateTime? startsOnOrAfterUtc,
    bool strict = false,
  }) async {
    final account = AccountOperationFence(_client);
    try {
      final trimmedCalendarId = calendarId?.trim();
      final boundedPageSize = pageSize <= 0 ? 1000 : pageSize;
      final boundedMaxRows = maxRows != null && maxRows > 0 ? maxRows : null;
      final rows = <Map<String, dynamic>>[];
      var offset = 0;

      try {
        while (true) {
          if (!account.isCurrent) throw const WarmReadCancelled();
          var query = _client.from(viewName).select(selectColumns);
          if (trimmedCalendarId != null && trimmedCalendarId.isNotEmpty) {
            query = query.eq('calendar_id', trimmedCalendarId);
          }
          if (liveOnly) {
            query = query.eq('live_on_calendar', true);
          }
          final windowStart = startsOnOrAfterUtc?.toUtc();
          if (windowStart != null) {
            query = query.gte('starts_at', windowStart.toIso8601String());
          }

          final remaining = boundedMaxRows == null
              ? boundedPageSize
              : boundedMaxRows - rows.length;
          if (remaining <= 0) break;
          final requestSize = remaining < boundedPageSize
              ? remaining
              : boundedPageSize;

          final page = await query
              .order('starts_at', ascending: true)
              .order('id', ascending: true)
              .range(offset, offset + requestSize - 1);

          if (!account.isCurrent) throw const WarmReadCancelled();
          final typedPage = (page as List)
              .whereType<Map>()
              .map((row) => row.cast<String, dynamic>())
              .toList(growable: false);
          rows.addAll(typedPage);
          if (boundedMaxRows != null && rows.length >= boundedMaxRows) break;
          if (typedPage.length < requestSize) break;
          offset += requestSize;
        }
      } catch (e) {
        _log('getEventCabinet failed: $e');
        rethrow;
      }

      try {
        final birthdayOccurrences =
            await BirthdayCalendarRepo(
              _client,
              strict: strict,
            ).getUpcomingOccurrences(
              calendarId: trimmedCalendarId,
              startsOnOrAfterUtc: startsOnOrAfterUtc,
            );
        rows.addAll(
          birthdayOccurrences.map(
            (occurrence) => occurrence.toFilingBackendRow(),
          ),
        );
      } catch (e) {
        if (strict) rethrow;
        _log('birthday occurrence merge failed: $e');
      }

      if (boundedMaxRows != null && rows.length > boundedMaxRows) {
        rows.sort((a, b) {
          final aStart = DateTime.tryParse(a['starts_at']?.toString() ?? '');
          final bStart = DateTime.tryParse(b['starts_at']?.toString() ?? '');
          final byStart = (aStart ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(bStart ?? DateTime.fromMillisecondsSinceEpoch(0));
          if (byStart != 0) return byStart;
          return (a['id']?.toString() ?? '').compareTo(
            b['id']?.toString() ?? '',
          );
        });
        rows.removeRange(boundedMaxRows, rows.length);
      }

      if (!account.isCurrent) throw const WarmReadCancelled();
      return rows;
    } finally {
      account.dispose();
    }
  }

  Future<List<UserEvent>> getLiveCalendarEvents(
    String calendarId, {
    int pageSize = 1000,
    int? maxRows,
    DateTime? startsOnOrAfterUtc,
  }) async {
    final filedEvents = await getLiveFiledCalendarEvents(
      calendarId,
      pageSize: pageSize,
      maxRows: maxRows,
      startsOnOrAfterUtc: startsOnOrAfterUtc,
    );
    return filedEvents.map((entry) => entry.event).toList(growable: false);
  }

  Future<List<FiledEvent>> getLiveFiledCalendarEvents(
    String calendarId, {
    int pageSize = 1000,
    bool cachedOnly = false,
    bool warm = false,
    int? maxRows,
    DateTime? startsOnOrAfterUtc,
  }) async {
    final trimmed = calendarId.trim();
    if (trimmed.isEmpty) return const [];
    final cabinet = await getEventCabinet(
      calendarId: trimmed,
      cachedOnly: cachedOnly,
      warm: warm,
      liveOnly: true,
      pageSize: pageSize,
      maxRows: maxRows,
      startsOnOrAfterUtc: startsOnOrAfterUtc,
    );
    return cabinet.activeForCalendar(trimmed);
  }
}
