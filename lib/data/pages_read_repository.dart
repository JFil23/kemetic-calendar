import 'dart:convert';
import '../core/completion_status.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/rhythm/models/rhythm_models.dart';
import '../features/rhythm/planner/planner_overview.dart';
import '../features/rhythm/data/planner_badge_repo.dart';

import '../features/journal/journal_badge_utils.dart';
import '../features/journal/journal_v2_document_model.dart';
import '../features/pages/pages_models.dart';
import '../features/calendar/calendar_page.dart' show notesDecode;
import 'account_view_cache.dart';
import '../features/pages/pages_arrangement.dart';
import 'nutrition_repo.dart';
import 'flow_post_model.dart';
import 'flows_repo.dart';
import 'profile_avatar_glyphs.dart';
import 'profile_repo.dart';
import 'commons_models.dart';
import 'shared_practice_models.dart';

/// Only bounded, authenticated reads. No ensure, sync, insert, update or RPC
/// that mutates state belongs on this passive overview boundary.
class PagesReadRepository {
  PagesReadRepository(this.client, {required this.mayFetch});
  final bool Function() mayFetch;
  void checkActive() {
    if (!mayFetch()) throw const ViewReadCancelled();
  }

  final SupabaseClient client;
  String get uid => client.auth.currentUser!.id;
  static String dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  Future<PlannerOverview> planner(DateTime now) async {
    final owner = uid;
    final rows = await client
        .from('todos')
        .select(
          'id,title,due_date,due_time,status,show_on_checklist,show_on_calendar',
        )
        .eq('user_id', owner)
        .or(
          'due_date.gte.${dayKey(now)},due_date.is.null,status.is.null,status.not.in.(done,skipped,archived)',
        )
        .order('created_at')
        .limit(200);
    if (rows.length == 200) {
      throw StateError('Planner preview coverage unavailable');
    }
    RhythmItemState state(Object? s) => switch (s) {
      'done' => RhythmItemState.done,
      'partial' || 'in_progress' => RhythmItemState.partial,
      'skipped' || 'archived' => RhythmItemState.skipped,
      _ => RhythmItemState.pending,
    };
    TimeOfDay? time(Object? s) {
      final p = s?.toString().split(':');
      return p == null || p.length < 2
          ? null
          : TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
    }

    final todos = rows
        .map(
          (t) => RhythmTodo(
            id: t['id'] as String,
            title: t['title'] as String? ?? '',
            dueDate: DateTime.tryParse(t['due_date']?.toString() ?? ''),
            dueTime: time(t['due_time']),
            state: state(t['status']),
            isChecklist: t['show_on_checklist'] as bool? ?? true,
            isCalendar: t['show_on_calendar'] as bool? ?? true,
          ),
        )
        .toList();
    checkActive();
    final nutrients = await client
        .from('nutrition_items')
        .select(
          'id,nutrient,source,mode,days_of_week,decan_days,repeat,time_h,time_m,enabled',
        )
        .eq('user_id', owner)
        .or('enabled.eq.true,enabled.is.null')
        .order('created_at')
        .limit(100);
    if (nutrients.length == 100) {
      throw StateError('Nutrition preview coverage unavailable');
    }
    final nutrition = nutrients.map(NutritionItem.fromRow).toList();
    checkActive();
    final notes = await client
        .from('alignment_notes')
        .select('body')
        .eq('user_id', owner)
        .order('position')
        .order('created_at')
        .limit(1);
    checkActive();
    final badgeRows = await client
        .from('journal_badges')
        .select('event_id,tags')
        .eq('user_id', owner)
        .gte('occurred_on', dayKey(now))
        .lte('occurred_on', dayKey(DateTime(now.year, now.month, now.day + 9)))
        .like('event_id', 'planner-nutrition:%')
        .limit(201);
    if (badgeRows.length == 201) {
      throw StateError('Nutrition status coverage unavailable');
    }
    final states = <String, RhythmItemState>{
      for (final row in badgeRows)
        if (PlannerBadgeRepo.nutritionStateKeyFromEventId(
              row['event_id'] as String,
            ) !=
            null)
          PlannerBadgeRepo.nutritionStateKeyFromEventId(
            row['event_id'] as String,
          )!: PlannerBadgeRepo.stateFromTags(
            (row['tags'] as List? ?? []).cast<String>(),
          ),
    };
    var alignment = const <RhythmItem>[];
    final preview = PlannerOverview(
      todos: todos,
      nutrition: nutrition,
      nutritionStates: states,
      alignment: alignment,
      note: '',
    );
    if (!preview.hasTrackedItems(now)) {
      checkActive();
      final fields = await client
          .from('cycle_fields')
          .select('id,title')
          .eq('user_id', owner)
          .eq('checklist_enabled', true)
          .limit(201);
      if (fields.length == 201) {
        throw StateError('Alignment coverage unavailable');
      }
      checkActive();
      final checks = await client
          .from('checklist_items')
          .select('field_id,status')
          .eq('user_id', owner)
          .eq('local_date', dayKey(now))
          .limit(201);
      if (checks.length == 201) {
        throw StateError('Alignment status coverage unavailable');
      }
      final statuses = {
        for (final c in checks) c['field_id']: state(c['status']),
      };
      alignment = fields
          .map(
            (f) => RhythmItem(
              title: f['title'] as String? ?? '',
              summary: '',
              state: statuses[f['id']] ?? RhythmItemState.pending,
            ),
          )
          .toList();
    }

    return PlannerOverview(
      todos: todos,
      nutrition: nutrition,
      nutritionStates: states,
      alignment: alignment,
      note: notes.isEmpty ? '' : notes.first['body'] as String? ?? '',
    );
  }

  Future<List<PagesFlow>> flows() async {
    final rows = await client
        .rpc('get_my_filed_flows_v1', params: {'p_limit': 100})
        .select(
          'id,user_id,name,color,appearance,notes,start_date,end_date,active,is_hidden,is_reminder,visible_in_active_list,total_event_count,remaining_event_count',
        );
    if (rows.length == 100) {
      throw StateError('Flow preview coverage unavailable');
    }
    return (rows as List)
        .map((r) => FlowRow.fromRow(Map<String, dynamic>.from(r)))
        .where((f) => f.visibleInActiveList && !f.isHidden && !f.isReminder)
        .map(
          (f) => PagesFlow(
            id: '${f.id}',
            name: f.name,
            appearance: f.appearance,
            maatKey: notesDecode(f.notes).maatKey,
            color: 0xff000000 | f.color,
            total: f.totalEventCount,
            completed: (f.totalEventCount - f.remainingEventCount).clamp(
              0,
              f.totalEventCount,
            ),
            start: f.startDate,
            end: f.endDate,
          ),
        )
        .toList();
  }

  Future<List<FlowPost>> activityPost({String? postId, int? flowId}) async {
    var query = client
        .from('flow_posts')
        .select(
          'id,user_id,flow_id,name,color,start_date,end_date,is_hidden,created_at,appearance:ai_metadata->payload->appearance',
        )
        .eq('user_id', uid)
        .eq('is_hidden', false);
    if (postId != null) query = query.eq('id', postId);
    if (flowId != null) query = query.eq('flow_id', flowId);
    final rows = await query.order('created_at', ascending: false).limit(1);
    return rows
        .map(
          (r) => FlowPost.fromJson({
            ...r,
            'payload': {'appearance': r['appearance']},
          }),
        )
        .toList();
  }

  /// Selected people only; no profile bootstrap or progress writes.
  Future<List<String>> personGlyphs(String personId) async {
    checkActive();
    final rows = await client
        .from('profiles')
        .select('avatar_glyphs')
        .eq('id', personId)
        .limit(1);
    return parseProfileAvatarGlyphIds(rows.firstOrNull?['avatar_glyphs']);
  }

  Future<List<PagesPerson>> calendarMembers(String calendarId) async {
    final rows = await client
        .rpc(
          'list_shared_calendar_members',
          params: {'p_calendar_id': calendarId},
        )
        .eq('status', 'accepted')
        .select('user_id,handle,display_name')
        .limit(3);
    final members = (rows as List)
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
    final ids = members.map((r) => r['user_id'] as String).toList();
    if (ids.isEmpty) return const [];
    final known = {
      for (final id in ids) id: ProfileRepo(client).getCachedProfileSync(id),
    };
    final missing = ids.where((id) => known[id] == null).toList();
    checkActive();
    final profiles = missing.isEmpty
        ? <Map<String, dynamic>>[]
        : await client
              .from('profiles')
              .select('id,display_name,handle,avatar_glyphs')
              .inFilter('id', missing)
              .limit(3);
    final byId = {for (final p in profiles) p['id']: p};
    return members.map((m) {
      final id = m['user_id'] as String;
      final profile = known[id];
      return PagesPerson(
        profile?.effectiveName ??
            m['display_name'] as String? ??
            m['handle'] as String? ??
            'Member',
        glyphIds:
            profile?.avatarGlyphIds ??
            parseProfileAvatarGlyphIds(byId[id]?['avatar_glyphs']),
      );
    }).toList();
  }

  Future<List<FlowPost>> ownPosts() async {
    final rows = await client
        .from('flow_posts')
        .select(
          'id,user_id,flow_id,name,color,start_date,end_date,is_hidden,created_at,appearance:ai_metadata->payload->appearance',
        )
        .eq('user_id', uid)
        .eq('is_hidden', false)
        .order('created_at', ascending: false)
        .limit(20);
    return rows
        .map(
          (r) => FlowPost.fromJson({
            ...r,
            'payload': {'appearance': r['appearance']},
          }),
        )
        .toList();
  }

  Future<List<FlowRow>> publicAppearance(int flowId) async {
    final rows = await client
        .from('flows')
        .select(
          'id,user_id,name,color,appearance,start_date,end_date,active,is_hidden,is_reminder',
        )
        .eq('id', flowId)
        .eq('is_hidden', false)
        .limit(1);
    return rows.map(FlowRow.fromRow).toList();
  }

  Future<TogetherInboxSnapshot> together() async {
    // Pages only needs the inbox card payload, not quote approvals or decisions.
    final json = await client.rpc(
      'get_together_inbox',
      params: {'p_limit': 20},
    );
    if (json is! Map) throw StateError('Together preview unavailable');
    return TogetherInboxSnapshot.fromJson(Map<String, dynamic>.from(json));
  }

  Future<CommonsHomeSnapshot> commons() async {
    final json = await client.rpc(
      'get_commons_together_home_cards',
      params: {
        'p_local_date': dayKey(DateTime.now()),
        'p_question_id': '',
        'p_question_text': '',
        'p_limit': 6,
      },
    );
    if (json is! Map) throw StateError('Commons preview unavailable');
    return CommonsHomeSnapshot.fromJson(Map<String, dynamic>.from(json));
  }

  Future<PagesEventWindow> events(DateTime now) async {
    final end = DateTime(now.year, now.month, now.day + 31);
    final rows = await client
        .from('user_event_filing_items_client')
        .select('title,starts_at,flow_local_id,filed_flow_id')
        .gte('starts_at', now.toUtc().toIso8601String())
        .lt('starts_at', end.toUtc().toIso8601String())
        .order('starts_at')
        .limit(201);
    final events = rows
        .map(
          (r) => PagesUpcomingEvent(
            flowId: (r['filed_flow_id'] ?? r['flow_local_id'] ?? '').toString(),
            title: r['title'] as String? ?? '',
            at: DateTime.parse(r['starts_at'] as String).toLocal(),
          ),
        )
        .toList();
    return PagesEventWindow(events, rows.length == 201 ? events.last.at : end);
  }

  Future<JournalOverview> journal(DateTime now) async {
    final owner = uid;
    // Inspect a bounded recent document window; never scan body text across
    // journal history. Older badge coverage remains explicitly unknown.
    final rows = await client
        .from('journal_entries')
        .select('greg_date,body,meta')
        .eq('user_id', owner)
        .lte('greg_date', dayKey(now))
        .order('greg_date', ascending: false)
        .limit(14);
    final written = <String>{};
    final badgesByDay = <String, List<PagesSignal>>{};
    for (final row in rows) {
      final date = row['greg_date'].toString();
      if (((row['meta'] as Map?)?['chars'] as num? ?? 0) > 0) written.add(date);
      badgesByDay[date] = journalBadgeSignals(row['body'] as String? ?? '');
    }
    return JournalOverview(
      written: written,
      badgesByDay: badgesByDay,
      historyComplete: rows.length < 14,
    );
  }
}

class JournalOverview {
  const JournalOverview({
    required this.written,
    required this.badgesByDay,
    this.historyComplete = false,
  });
  final Set<String> written;
  final Map<String, List<PagesSignal>> badgesByDay;
  final bool historyComplete;
  List<PagesSignal> get badges {
    final dates = badgesByDay.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final d in dates) {
      if (badgesByDay[d]!.isNotEmpty) return badgesByDay[d]!;
    }
    return const [];
  }
}

JournalDocument _journalDocument(String body) {
  try {
    final json = jsonDecode(body);
    return json is Map
        ? JournalDocument.fromJson(Map<String, dynamic>.from(json))
        : JournalDocument.fromPlainText(body);
  } catch (_) {
    return JournalDocument.fromPlainText(body);
  }
}

List<PagesSignal> journalBadgeSignals(
  String body,
) => JournalBadgeUtils.tokensFromDocument(_journalDocument(body)).reversed
    .map((b) {
      final at = b.start?.toLocal();
      return PagesSignal(
        b.title,
        color: b.color.toARGB32(),
        status: b.isCompletionBadge
            ? switch (b.completionStatus) {
                CompletionStatus.observed => '✓',
                CompletionStatus.partial => '◐',
                CompletionStatus.skipped => '—',
                CompletionStatus.none => '',
              }
            : '',
        detail: at == null
            ? ''
            : '${at.hour % 12 == 0 ? 12 : at.hour % 12}${at.minute == 0 ? '' : ':${at.minute.toString().padLeft(2, '0')}'} ${at.hour < 12 ? 'AM' : 'PM'}',
      );
    })
    .toList(growable: false);
void publishJournalOverview(String uid, DateTime date, String body) {
  final cache = AccountViewCache.instance;
  final previous = cache.peek<JournalOverview>(uid, 'journal.overview');
  if (previous == null) return;
  final key = PagesReadRepository.dayKey(date);
  final written = {...previous.written};
  // Save confirms this day was touched; the document parser handles empty docs.
  if (_journalDocument(body).toPlainText().trim().isNotEmpty) {
    written.add(key);
  } else {
    written.remove(key);
  }
  final byDay = {...previous.badgesByDay, key: journalBadgeSignals(body)};
  final ordered = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
  for (final old in ordered.skip(14)) {
    byDay.remove(old);
    written.remove(old);
  }
  cache.publish(
    uid,
    'journal.overview',
    JournalOverview(
      written: written,
      badgesByDay: byDay,
      historyComplete: previous.historyComplete,
    ),
  );
}
