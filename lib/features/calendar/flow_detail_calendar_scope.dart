import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/account_operation_fence.dart';
import '../../data/event_filing_repo.dart';
import '../../data/event_filing_engine.dart';
import '../../data/external_calendar_repository.dart';
import '../../data/flows_repo.dart';
import '../../data/shared_calendars_repo.dart';
import '../../data/user_events_repo.dart';
import '../../data/warm_state/warm_snapshot_store.dart';
import '../../data/warm_state/warm_work_queue.dart';
import 'calendar_invalidation.dart';
import 'calendar_page.dart' show calendarPreviewEventColor;
import 'follow_the_sky/presentation/follow_sky_calendar_preview.dart';

/// Calendar context for every flow detail, independent of the navigation host.
/// This is a read projection of the existing account repositories, not another
/// calendar store. It never writes events or queues account mutations.
class FlowDetailCalendarScope extends StatefulWidget {
  const FlowDetailCalendarScope({
    super.key,
    required this.start,
    required this.end,
    required this.builder,
    this.initialPreview = FollowSkyCalendarPreview.unavailable,
  });

  final DateTime start, end;
  final FollowSkyCalendarPreview initialPreview;
  final Widget Function(BuildContext, FollowSkyCalendarPreview) builder;

  @override
  State<FlowDetailCalendarScope> createState() =>
      _FlowDetailCalendarScopeState();
}

class _FlowDetailCalendarScopeState extends State<FlowDetailCalendarScope>
    with WidgetsBindingObserver {
  SupabaseClient? _client;
  StreamSubscription<AuthState>? _auth;
  StreamSubscription<CalendarInvalidated>? _calendar;
  StreamSubscription<WarmSnapshotChange>? _external;
  late FollowSkyCalendarPreview _preview;
  String? _account;
  int _generation = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _preview = widget.initialPreview;
    // Static visual fixtures and unauthenticated discovery remain usable.
    try {
      _client = Supabase.instance.client;
    } catch (_) {
      return;
    }
    final client = _client!;
    _account = client.auth.currentUser?.id;
    WidgetsBinding.instance.addObserver(this);
    _auth = client.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.signedOut ||
          state.session?.user.id != _account) {
        _account = state.session?.user.id;
        _generation++;
        if (mounted) {
          setState(() => _preview = FollowSkyCalendarPreview.unavailable);
          unawaited(_load());
        }
      }
    });
    _calendar = CalendarInvalidationBus.instance.stream.listen(
      (_) => _refresh(),
    );
    // ExternalCalendarRepository publishes its acknowledged background reads
    // through the existing warm store. Recompose after that read arrives.
    _external = WarmSnapshotStore.instance.changes.listen((change) {
      if (change.userId == _account &&
          change.key.startsWith('externalCalendar.')) {
        _refresh();
      }
    });
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant FlowDetailCalendarScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.start != widget.start || oldWidget.end != widget.end) {
      _preview = widget.initialPreview;
      unawaited(_load());
    }
  }

  void _refresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer(
      const Duration(milliseconds: 30),
      () => unawaited(_load()),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _load() async {
    final client = _client;
    if (client == null || client.auth.currentUser == null) return;
    final generation = ++_generation;
    final account = AccountOperationFence(client);
    final start = DateUtils.dateOnly(widget.start);
    final end = DateUtils.dateOnly(widget.end);
    final until = DateTime(end.year, end.month, end.day + 1);
    bool current() => mounted && generation == _generation && account.isCurrent;
    void publish(FollowSkyCalendarPreview value) {
      if (current()) setState(() => _preview = value);
    }

    Future<FollowSkyCalendarPreview> read(bool cachedOnly) async {
      final cabinet = await EventFilingRepo(client).getEventCabinet(
        liveOnly: true,
        startsOnOrAfterUtc: start.toUtc(),
        cachedOnly: cachedOnly,
        warm: true,
      );
      if (!current()) throw const WarmReadCancelled();
      final flowsRepo = FlowsRepo(client);
      final flows = cachedOnly
          ? await flowsRepo.restoreCachedFiledFlows() ?? const <FlowRow>[]
          : await flowsRepo.listMyFiledFlows();
      if (!current()) throw const WarmReadCancelled();
      final byId = {for (final flow in flows) flow.id: flow};
      final external = await externalCalendarRepository(
        client,
      ).visibleEvents(start, until);
      if (!current()) throw const WarmReadCancelled();
      final hiddenCalendars = await SharedCalendarsRepo(
        client,
      ).getHiddenCalendarIds();
      if (!current()) throw const WarmReadCancelled();
      final rows = <FollowSkyCalendarPreviewRow>[];
      void add({
        required String title,
        required DateTime startsAt,
        DateTime? endsAt,
        required bool allDay,
        String? id,
        Color? color,
        String? flowName,
        int? flowId,
      }) {
        final local = startsAt.toLocal();
        final day = DateUtils.dateOnly(local);
        if (day.isBefore(start) || day.isAfter(end)) return;
        final from = allDay ? DateTime(day.year, day.month, day.day, 9) : local;
        var to = endsAt?.toLocal() ?? from.add(const Duration(hours: 1));
        if (!to.isAfter(from)) to = from.add(const Duration(hours: 1));
        rows.add(
          FollowSkyCalendarPreviewRow(
            localDay: day,
            start: from,
            end: to,
            title: title,
            eventId: id,
            flowName: flowName,
            flowId: flowId,
            allDay: allDay,
            eventColor:
                color ??
                calendarPreviewEventColor(
                  calendarIsPersonal: true,
                  isReminder: false,
                ),
          ),
        );
      }

      for (final entry in cabinet.entries) {
        if (!entry.visibleOnCalendar ||
            hiddenCalendars.contains(entry.calendar.id)) {
          continue;
        }
        final event = entry.event;
        final flow = byId[entry.flowId];
        add(
          title: event.title,
          startsAt: event.startsAt,
          endsAt: event.endsAt,
          allDay: event.allDay,
          id: event.clientEventId ?? event.id,
          color: calendarPreviewEventColor(
            detail: event.detail,
            calendarColor: event.calendarColor == null
                ? null
                : event.calendarColor! | 0xFF000000,
            calendarIsPersonal: event.calendarIsPersonal,
            flowName: flow?.name,
            flowColor: flow == null ? null : flow.color | 0xFF000000,
            isReminder: entry.kind == FiledItemKind.reminder,
          ),
          flowId: entry.flowId,
          flowName: flow?.name,
        );
      }
      for (final event in standaloneRowsFromExternalCalendarEvents(
        external,
        start,
        until,
      )) {
        add(
          title: event.title,
          startsAt: event.startsAtUtc,
          endsAt: event.endsAtUtc,
          allDay: event.allDay,
          id: event.clientEventId ?? event.id,
          color: calendarPreviewEventColor(
            detail: event.detail,
            calendarColor: event.calendarColor,
            calendarIsPersonal: event.calendarIsPersonal,
            isReminder: event.isReminder,
          ),
        );
      }
      rows.sort((a, b) => a.start.compareTo(b.start));
      return FollowSkyCalendarPreview(
        rows: rows,
        windowStart: start,
        windowEnd: end,
      );
    }

    try {
      if (_preview.supply != CalendarPreviewSupply.loaded) {
        publish(
          FollowSkyCalendarPreview(
            windowStart: start,
            windowEnd: end,
            supply: CalendarPreviewSupply.loading,
            coverageComplete: false,
          ),
        );
      }
      try {
        publish(
          await runZoned(
            () => read(true),
            zoneValues: {warmReadGuard: current},
          ),
        );
      } catch (_) {
        // A cold miss does not certify an empty calendar.
      }
      if (!current()) return;
      try {
        publish(
          await runZoned(
            () => read(false),
            zoneValues: {warmReadGuard: current},
          ),
        );
      } on WarmAccessDenied {
        publish(FollowSkyCalendarPreview.unavailable);
      } on WarmReadCancelled {
        // A just-closed route or departed account may own a coalesced read.
        // Once it is fenced, this still-current entry needs its own refresh.
        if (current()) _refresh();
      } catch (_) {
        if (_preview.supply != CalendarPreviewSupply.loaded) {
          publish(FollowSkyCalendarPreview.unavailable);
        }
      }
    } finally {
      account.dispose();
    }
  }

  @override
  void dispose() {
    _generation++;
    _refreshTimer?.cancel();
    _auth?.cancel();
    _calendar?.cancel();
    _external?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _preview);
}
