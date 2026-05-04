import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  Future<FiledEventCabinet> getEventCabinet({
    String? calendarId,
    bool liveOnly = false,
    int pageSize = 1000,
  }) async {
    final trimmedCalendarId = calendarId?.trim();
    final boundedPageSize = pageSize <= 0 ? 1000 : pageSize;
    final rows = <Map<String, dynamic>>[];
    var offset = 0;

    try {
      while (true) {
        var query = _client.from(viewName).select(selectColumns);
        if (trimmedCalendarId != null && trimmedCalendarId.isNotEmpty) {
          query = query.eq('calendar_id', trimmedCalendarId);
        }
        if (liveOnly) {
          query = query.eq('live_on_calendar', true);
        }

        final page = await query
            .order('starts_at', ascending: true)
            .order('id', ascending: true)
            .range(offset, offset + boundedPageSize - 1);

        final typedPage = (page as List)
            .whereType<Map>()
            .map((row) => row.cast<String, dynamic>())
            .toList(growable: false);
        rows.addAll(typedPage);
        if (typedPage.length < boundedPageSize) break;
        offset += boundedPageSize;
      }
    } catch (e) {
      _log('getEventCabinet failed: $e');
      rethrow;
    }

    return FiledEventCabinet.fromBackendRows(rows);
  }

  Future<List<UserEvent>> getLiveCalendarEvents(
    String calendarId, {
    int pageSize = 1000,
  }) async {
    final filedEvents = await getLiveFiledCalendarEvents(
      calendarId,
      pageSize: pageSize,
    );
    return filedEvents.map((entry) => entry.event).toList(growable: false);
  }

  Future<List<FiledEvent>> getLiveFiledCalendarEvents(
    String calendarId, {
    int pageSize = 1000,
  }) async {
    final trimmed = calendarId.trim();
    if (trimmed.isEmpty) return const [];
    final cabinet = await getEventCabinet(
      calendarId: trimmed,
      liveOnly: true,
      pageSize: pageSize,
    );
    return cabinet.activeForCalendar(trimmed);
  }
}
