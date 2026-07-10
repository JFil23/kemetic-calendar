part of 'calendar_page.dart';

enum _FlowPreviewMode { legacy, active, saved }

enum _MyFlowDayCardVariant { liveHero, savedLead, expandedInline }

enum FlowDetailSource {
  flowStudio,
  myFlows,
  reflection,
  inboxShare,
  directShare,
  profilePost,
  profileActivity,
  other,
  communityFeed,
}

enum FlowDetailActionKind {
  join,
  manage,
  importFlow,
  openImported,
  addToMyFlows,
  openSaved,
  viewOnly,
}

@immutable
class FlowDetailActionPolicy {
  const FlowDetailActionPolicy({
    required this.source,
    required this.kind,
    required this.label,
    required this.icon,
    this.busyLabel,
    this.busy = false,
    this.enabled = true,
    this.onPressed,
    this.startDateLabel,
    this.onStartDatePressed,
  });

  final FlowDetailSource source;
  final FlowDetailActionKind kind;
  final String label;
  final String? busyLabel;
  final IconData icon;
  final bool busy;
  final bool enabled;
  final FutureOr<void> Function()? onPressed;
  final String? startDateLabel;
  final FutureOr<void> Function()? onStartDatePressed;

  String get effectiveLabel => busy ? (busyLabel ?? label) : label;
  bool get canRun => enabled && !busy && onPressed != null;
}

class _FlowPreviewMetrics {
  const _FlowPreviewMetrics({
    required this.totalEventCount,
    required this.remainingEventCount,
    required this.completedEventCount,
  });

  final int totalEventCount;
  final int remainingEventCount;
  final int completedEventCount;

  factory _FlowPreviewMetrics.fromSnapshot({
    required _Flow flow,
    required _MyFlowsFilingSnapshot snapshot,
  }) {
    final total = snapshot.totalEventCounts[flow.id] ?? 0;
    final remaining = snapshot.remainingEventCounts[flow.id] ?? 0;
    final completed = math.max(0, math.min(total, total - remaining));
    return _FlowPreviewMetrics(
      totalEventCount: total,
      remainingEventCount: remaining,
      completedEventCount: completed,
    );
  }
}

class _FlowDashboardDay {
  const _FlowDashboardDay({
    required this.key,
    required this.dayNumber,
    required this.event,
  });

  final String key;
  final int dayNumber;
  final FlowEventRow event;

  DateTime get localStart => event.startsAtUtc.toLocal();
  DateTime? get localEnd => event.endsAtUtc?.toLocal();
}

class _FlowDashboardPartition {
  const _FlowDashboardPartition({
    required this.completed,
    required this.hero,
    required this.upcoming,
    required this.currentDayNumber,
  });

  final List<_FlowDashboardDay> completed;
  final _FlowDashboardDay? hero;
  final List<_FlowDashboardDay> upcoming;
  final int currentDayNumber;
}

class _FlowDayContent {
  const _FlowDayContent({
    required this.title,
    required this.timeRange,
    required this.body,
    required this.location,
    required this.externalButtonLabel,
  });

  final String title;
  final String timeRange;
  final String? body;
  final String? location;
  final String? externalButtonLabel;
}

class _FlowPreviewPage extends StatefulWidget {
  const _FlowPreviewPage({
    required this.flow,
    required this.getDecanLabel,
    required this.fmt,
    required this.onEdit,
    this.onAppendToJournal,
    this.onEndMaatFlow,
    this.flowSequence,
    this.initialIndex = 0,
    this.mode = _FlowPreviewMode.legacy,
    this.metricsByFlow = const <int, _FlowPreviewMetrics>{},
    this.initialEventsByFlow,
    this.actionPolicy,
    this.showFlowOptions = true,
    this.onCalendarChanged,
  });

  final _Flow flow;
  final List<_Flow>? flowSequence;
  final int initialIndex;
  final _FlowPreviewMode mode;
  final Map<int, _FlowPreviewMetrics> metricsByFlow;
  final Map<int, List<FlowEventRow>>? initialEventsByFlow;
  final FlowDetailActionPolicy? actionPolicy;
  final bool showFlowOptions;
  final Future<_Flow> Function(_Flow flow, SharedCalendarSummary calendar)?
  onCalendarChanged;
  final String Function(int km, int di) getDecanLabel;
  final String Function(DateTime? g) fmt;
  final void Function(_Flow flow) onEdit;
  final Future<void> Function(String text)? onAppendToJournal;

  /// if provided & flow is a Ma'at instance, show a gold-outline "End Flow" button.
  final void Function(_Flow flow)? onEndMaatFlow;

  @override
  State<_FlowPreviewPage> createState() => _FlowPreviewPageState();
}

class _FlowPreviewPageState extends State<_FlowPreviewPage> {
  UserEventsRepo? _userEventsRepo;

  late final List<_Flow> _flowSequence;
  late int _currentIndex;
  late final PageController _pageController;

  // Cache events per flow id so we don't re-query when swiping back.
  final Map<int, List<FlowEventRow>> _eventsByFlow = {};
  final Map<int, Object?> _eventsErrorByFlow = {};
  final Set<int> _loadingFlowIds = {};
  String? _expandedDayKey;
  DateTime? _selectedStartForSaved;
  bool _isImportingSaved = false;
  bool _calendarChangeInFlight = false;
  Map<String, SharedCalendarSummary> _detachedCalendarSummariesById =
      const <String, SharedCalendarSummary>{};
  String? _detachedPersonalCalendarId;

  UserEventsRepo get _eventsRepo =>
      _userEventsRepo ??= UserEventsRepo(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _flowSequence = (widget.flowSequence ?? [widget.flow]).toList();
    if (_flowSequence.isEmpty) {
      _flowSequence.add(widget.flow);
    } else if (!_flowSequence.any((f) => f.id == widget.flow.id)) {
      _flowSequence.insert(0, widget.flow);
    }

    int initial = widget.initialIndex;
    if (initial < 0 || initial >= _flowSequence.length) {
      initial = _flowSequence.indexWhere((f) => f.id == widget.flow.id);
      if (initial < 0) initial = 0;
    }
    _currentIndex = initial;
    _pageController = PageController(initialPage: _currentIndex);
    final initialEventsByFlow = widget.initialEventsByFlow;
    if (initialEventsByFlow != null) {
      _eventsByFlow.addAll(initialEventsByFlow);
    }
    _loadEventsFor(_flowSequence[_currentIndex]);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  CalendarPageState? get _calendarPageState =>
      CalendarPage.globalKey.currentState;

  SharedCalendarSummary? _calendarSummaryFor(_Flow flow) {
    final pageStateSummary = _calendarPageState?._calendarSummary(
      flow.calendarId,
    );
    if (pageStateSummary != null) return pageStateSummary;
    final trimmed = flow.calendarId?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return _detachedCalendarSummariesById[trimmed];
  }

  String _calendarLabelFor(_Flow flow) {
    final summary = _calendarSummaryFor(flow);
    final name = summary?.name.trim();
    if (summary?.isPersonal == true) return 'My Calendar';
    if (name != null && name.isNotEmpty) return name;
    return 'My Calendar';
  }

  Color _calendarColorFor(_Flow flow) {
    return _calendarSummaryFor(flow)?.color ?? _gold;
  }

  FlowEventRow _eventWithCalendar(
    FlowEventRow event,
    SharedCalendarSummary calendar,
  ) {
    return (
      id: event.id,
      clientEventId: event.clientEventId,
      calendarId: calendar.id,
      calendarName: calendar.name,
      calendarColor: calendar.colorValue,
      calendarIsPersonal: calendar.isPersonal,
      title: event.title,
      detail: event.detail,
      location: event.location,
      allDay: event.allDay,
      startsAtUtc: event.startsAtUtc,
      endsAtUtc: event.endsAtUtc,
      flowLocalId: event.flowLocalId,
      category: event.category,
      actionId: event.actionId,
      behaviorPayload: event.behaviorPayload,
    );
  }

  Future<void> _openFlowCalendarPicker(_Flow flow) async {
    if (_calendarChangeInFlight || widget.onCalendarChanged == null) return;
    final pageState = _calendarPageState;
    late final List<SharedCalendarSummary> calendars;
    String? selectedCalendarId;
    if (pageState != null) {
      await pageState._loadCalendarState();
      if (!mounted) return;
      calendars = pageState._editableCalendarsForFlow(flow.calendarId);
      selectedCalendarId = flow.calendarId ?? pageState._personalCalendarId;
    } else {
      final choices = await CalendarPage._loadHeadlessEditableCalendarsForFlow(
        flow.calendarId,
      );
      if (!mounted) return;
      calendars = choices.calendars;
      selectedCalendarId =
          flow.calendarId ??
          choices.personalCalendarId ??
          _detachedPersonalCalendarId;
      setState(() {
        _detachedPersonalCalendarId =
            choices.personalCalendarId ?? _detachedPersonalCalendarId;
        _detachedCalendarSummariesById = <String, SharedCalendarSummary>{
          for (final calendar in calendars) calendar.id: calendar,
        };
      });
    }

    if (calendars.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No editable calendars available.')),
      );
      return;
    }

    final chosenId = await _showCalendarChoiceSheet(
      context: context,
      calendars: calendars,
      selectedCalendarId: selectedCalendarId,
      title: 'Flow calendar',
    );
    if (!mounted || chosenId == null || chosenId.trim().isEmpty) return;
    if (chosenId == flow.calendarId) return;

    final chosenCalendar = calendars.firstWhere(
      (calendar) => calendar.id == chosenId,
      orElse: () => calendars.first,
    );
    final previousCalendarId = flow.calendarId;
    final events = _eventsByFlow[flow.id];

    setState(() {
      _calendarChangeInFlight = true;
      flow.calendarId = chosenCalendar.id;
      if (events != null) {
        _eventsByFlow[flow.id] = events
            .map((event) => _eventWithCalendar(event, chosenCalendar))
            .toList(growable: false);
      }
    });

    try {
      final updated = await widget.onCalendarChanged!(flow, chosenCalendar);
      if (!mounted) return;
      setState(() {
        final index = _flowSequence.indexWhere(
          (candidate) => candidate.id == updated.id,
        );
        if (index >= 0) {
          _flowSequence[index] = updated;
        } else {
          flow.calendarId = updated.calendarId;
        }
        _calendarChangeInFlight = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        flow.calendarId = previousCalendarId;
        if (events != null) {
          _eventsByFlow[flow.id] = events;
        }
        _calendarChangeInFlight = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to change flow calendar.')),
      );
    }
  }

  Widget _buildFlowCalendarSelector(
    _Flow flow, {
    required bool dashboard,
    _MyFlowCardPalette? palette,
  }) {
    final canChange = widget.onCalendarChanged != null && flow.id > 0;
    final color = dashboard
        ? palette?.accent ?? _calendarColorFor(flow)
        : _calendarColorFor(flow);
    final textColor = dashboard
        ? const Color(0xFFE8D9C3)
        : const Color(0xFFE8D6A8);
    final labelColor = dashboard ? const Color(0xFF4A3E22) : Colors.white70;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey<String>('flow-calendar-picker-${flow.id}'),
        onTap: canChange ? () => _openFlowCalendarPicker(flow) : null,
        borderRadius: BorderRadius.circular(dashboard ? 10 : 8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FLOW CALENDAR',
                      style: TextStyle(
                        color: labelColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _calendarLabelFor(flow),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontSize: dashboard ? 19 : 16,
                        fontFamily: dashboard
                            ? MaatFlowListTokens.fontFamily
                            : 'GentiumPlus',
                        fontFamilyFallback: dashboard
                            ? MaatFlowListTokens.fontFallback
                            : null,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (_calendarChangeInFlight)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              else if (canChange)
                Icon(Icons.chevron_right, color: color),
            ],
          ),
        ),
      ),
    );
  }

  ({bool kemetic, bool split, String overview, String? maatKey}) _metaFor(
    _Flow flow,
  ) {
    return notesDecode(flow.notes);
  }

  TrackSkyEventSchedule _trackSkyScheduleFromLocalWindow(
    DateTime startLocal,
    DateTime? endLocal,
    bool allDay,
  ) {
    String two(int value) => value.toString().padLeft(2, '0');
    return TrackSkyEventSchedule(
      dateIso:
          '${startLocal.year}-${two(startLocal.month)}-${two(startLocal.day)}',
      startTime24: allDay
          ? null
          : '${two(startLocal.hour)}:${two(startLocal.minute)}',
      endTime24: allDay || endLocal == null
          ? null
          : '${two(endLocal.hour)}:${two(endLocal.minute)}',
      allDay: allDay,
    );
  }

  ({DateTime startLocal, DateTime? endLocal, bool allDay})
  _normalizeTrackSkyLocalWindow({
    required String title,
    required String? category,
    required DateTime startLocal,
    required DateTime? endLocal,
    required bool allDay,
  }) {
    final schedule = _trackSkyScheduleFromLocalWindow(
      startLocal,
      endLocal,
      allDay,
    );
    final normalized = normalizeTrackSkyViewingSchedule(
      title: title,
      category: category ?? '',
      schedule: schedule,
    );
    if (normalized.allDay || normalized.startTime24 == null) {
      return (startLocal: startLocal, endLocal: endLocal, allDay: allDay);
    }

    final dateParts = normalized.dateIso.split('-').map(int.parse).toList();
    final startParts = normalized.startTime24!
        .split(':')
        .map(int.parse)
        .toList();
    final newStart = DateTime(
      dateParts[0],
      dateParts[1],
      dateParts[2],
      startParts[0],
      startParts[1],
    );
    DateTime? newEnd;
    if (normalized.endTime24 != null) {
      final endParts = normalized.endTime24!.split(':').map(int.parse).toList();
      newEnd = DateTime(
        dateParts[0],
        dateParts[1],
        dateParts[2],
        endParts[0],
        endParts[1],
      );
    }

    return (startLocal: newStart, endLocal: newEnd, allDay: false);
  }

  FlowEventRow _normalizeTrackSkyFlowEventRow(FlowEventRow event) {
    final normalized = _normalizeTrackSkyLocalWindow(
      title: event.title,
      category: event.category,
      startLocal: event.startsAtUtc.toLocal(),
      endLocal: event.endsAtUtc?.toLocal(),
      allDay: event.allDay,
    );
    return (
      id: event.id,
      clientEventId: event.clientEventId,
      calendarId: event.calendarId,
      calendarName: event.calendarName,
      calendarColor: event.calendarColor,
      calendarIsPersonal: event.calendarIsPersonal,
      title: event.title,
      detail: event.detail,
      location: event.location,
      allDay: normalized.allDay,
      startsAtUtc: normalized.startLocal.toUtc(),
      endsAtUtc: normalized.endLocal?.toUtc(),
      flowLocalId: event.flowLocalId,
      category: event.category,
      actionId: event.actionId,
      behaviorPayload: event.behaviorPayload == null
          ? null
          : Map<String, dynamic>.from(event.behaviorPayload!),
    );
  }

  List<FlowEventRow> _dedupeEvents(List<FlowEventRow> events) {
    String canonKey(FlowEventRow e) {
      final titleKey = e.title.trim().toLowerCase();
      final startKey = e.startsAtUtc.toIso8601String();
      final endKey = e.endsAtUtc?.toIso8601String() ?? 'NO_END';
      final locKey = (e.location ?? '').trim().toLowerCase();
      final detailKey = (e.detail ?? '').trim().toLowerCase();
      final flowKey = (e.flowLocalId ?? -1).toString();
      return [
        titleKey,
        startKey,
        endKey,
        e.allDay ? 'allDay' : 'timed',
        locKey,
        detailKey,
        flowKey,
        (e.category ?? '').toLowerCase(),
      ].join('|');
    }

    int quality(FlowEventRow e) {
      if (e.id != null) return 3;
      if (e.clientEventId != null) return 2;
      return 1;
    }

    final merged = <String, FlowEventRow>{};

    for (final e in events) {
      final key = canonKey(e);
      final existing = merged[key];
      if (existing == null || quality(e) > quality(existing)) {
        merged[key] = e;
      }
    }

    final deduped = merged.values.toList()
      ..sort((a, b) => a.startsAtUtc.compareTo(b.startsAtUtc));
    return deduped;
  }

  Future<void> _loadEventsFor(_Flow flow) async {
    final flowId = flow.id;
    if (_loadingFlowIds.contains(flowId) || _eventsByFlow.containsKey(flowId)) {
      return;
    }

    final repo = _eventsRepo;
    setState(() {
      _loadingFlowIds.add(flowId);
      _eventsErrorByFlow.remove(flowId);
    });

    try {
      final events = await repo.getEventsForFlow(flowId);
      final normalized = _isTrackSkyFlowName(flow.name)
          ? events.map(_normalizeTrackSkyFlowEventRow).toList()
          : events;
      final deduped = _dedupeEvents(normalized);

      if (!mounted) return;
      setState(() {
        _eventsByFlow[flowId] = deduped;
        _loadingFlowIds.remove(flowId);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _eventsErrorByFlow[flowId] = e;
        _loadingFlowIds.remove(flowId);
      });
    }
  }

  String _buildFlowBadgeToken(_Flow flow, List<FlowEventRow> events) {
    DateTime start = flow.start ?? DateTime.now();
    DateTime end = flow.end ?? start.add(const Duration(hours: 1));
    if (events.isNotEmpty) {
      start = events.first.startsAtUtc.toLocal();
      end = (events.first.endsAtUtc ?? start.add(const Duration(hours: 1)))
          .toLocal();
    }
    final meta = _metaFor(flow);
    final description = _effectiveOverview(flow.notes, meta.overview);
    final cleanedDesc = _stripCidLines(description);
    final descForToken = cleanedDesc.isEmpty ? null : cleanedDesc;
    final id = 'badge-${DateTime.now().microsecondsSinceEpoch}';
    return EventBadgeToken.buildToken(
      id: id,
      title: flow.name.isEmpty ? 'Flow block' : flow.name,
      start: start,
      end: end,
      color: flow.color,
      description: descForToken,
    );
  }

  Future<void> _handleAddFlowToJournal(
    _Flow flow,
    List<FlowEventRow> events,
  ) async {
    final cb = widget.onAppendToJournal;
    if (cb == null) return;
    final token = _buildFlowBadgeToken(flow, events);
    try {
      await cb('$token ');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Added to journal'),
            backgroundColor: Color(0xFFFFC145),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      // ignore
    }
  }

  DateTime _savedDefaultStart(_Flow flow) {
    final today = DateUtils.dateOnly(DateTime.now());
    final start = flow.start;
    if (start == null) return today;
    final normalized = DateUtils.dateOnly(start);
    return normalized.isBefore(today) ? today : normalized;
  }

  DateTime _savedDisplayStart(_Flow flow) =>
      DateUtils.dateOnly(_selectedStartForSaved ?? _savedDefaultStart(flow));

  Future<void> _pickSavedStart(_Flow flow) async {
    final picked = await FlowStartDatePicker.show(
      context,
      initialDate: _savedDisplayStart(flow),
    );
    if (picked != null && mounted) {
      setState(() => _selectedStartForSaved = DateUtils.dateOnly(picked));
    }
  }

  Future<int> _importSavedFlow(_Flow template, DateTime startDate) async {
    DateTime dateOnly(DateTime d) => DateUtils.dateOnly(d);
    final targetStart = dateOnly(startDate);
    final events = await _eventsRepo.getEventsForFlow(template.id);

    DateTime minDate(DateTime a, DateTime b) => a.isBefore(b) ? a : b;
    DateTime maxDate(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

    DateTime baseStart = targetStart;
    if (template.start != null) {
      baseStart = dateOnly(template.start!);
    } else if (events.isNotEmpty) {
      baseStart = dateOnly(
        events.map((e) => e.startsAtUtc.toLocal()).reduce(minDate),
      );
    }

    final deltaDays = targetStart.difference(baseStart).inDays;

    DateTime? templateEnd = template.end;
    if (templateEnd == null && events.isNotEmpty) {
      templateEnd = events
          .map((e) => dateOnly(e.startsAtUtc.toLocal()))
          .reduce(maxDate);
    }
    final DateTime? newEnd = templateEnd == null
        ? null
        : dateOnly(templateEnd.add(Duration(days: deltaDays)));

    final rulesJson = jsonEncode(
      template.rules.map(CalendarPageState.ruleToJson).toList(),
    );

    final newId = await _eventsRepo.upsertFlow(
      name: template.name,
      color: template.color.toARGB32(),
      active: true,
      calendarId: template.calendarId,
      startDate: targetStart,
      endDate: newEnd,
      notes: template.notes,
      rules: rulesJson,
      isHidden: false,
      isSaved: false,
      shareId: template.shareId,
      originType: 'saved_import',
      originFlowId: template.id,
      rootFlowId: template.id,
      isReminder: template.isReminder,
      reminderUuid: template.reminderUuid,
    );

    var importedEventCount = 0;
    for (final e in events) {
      final localStart = e.startsAtUtc.toLocal();
      final originDate = dateOnly(localStart);
      final offset = originDate.difference(baseStart).inDays;
      final newDate = targetStart.add(Duration(days: offset));

      final startDt = DateTime(
        newDate.year,
        newDate.month,
        newDate.day,
        localStart.hour,
        localStart.minute,
        localStart.second,
        localStart.millisecond,
        localStart.microsecond,
      );

      DateTime? endDt;
      final localEnd = e.endsAtUtc?.toLocal();
      if (localEnd != null) {
        final endOrigin = dateOnly(localEnd);
        final endOffset = endOrigin.difference(baseStart).inDays;
        final endDate = targetStart.add(Duration(days: endOffset));
        endDt = DateTime(
          endDate.year,
          endDate.month,
          endDate.day,
          localEnd.hour,
          localEnd.minute,
          localEnd.second,
          localEnd.millisecond,
          localEnd.microsecond,
        );
      }

      final (:kYear, :kMonth, :kDay) = KemeticMath.fromGregorian(startDt);
      final cid = EventCidUtil.buildClientEventId(
        ky: kYear,
        km: kMonth,
        kd: kDay,
        title: e.title.isEmpty ? template.name : e.title,
        startHour: startDt.hour,
        startMinute: startDt.minute,
        allDay: e.allDay,
        flowId: newId,
      );

      await _eventsRepo.upsertByClientId(
        clientEventId: cid,
        title: e.title,
        startsAtUtc: startDt.toUtc(),
        detail: (e.detail ?? '').trim().isEmpty ? null : e.detail,
        location: (e.location ?? '').trim().isEmpty ? null : e.location,
        allDay: e.allDay,
        endsAtUtc: endDt?.toUtc(),
        calendarId: template.calendarId,
        flowLocalId: newId,
        category: e.category,
        caller: 'saved_flow_import',
      );
      importedEventCount++;
    }

    if (importedEventCount == 0 && template.rules.isNotEmpty) {
      importedEventCount = await _materializeSavedFlowRules(
        flowId: newId,
        template: template,
        startDate: targetStart,
        endDate: newEnd,
      );
    }

    if (kDebugMode) {
      _calendarDebugPrint(
        '[saved_flow_import] Imported flow $newId with $importedEventCount events',
      );
    }

    return newId;
  }

  Future<int> _materializeSavedFlowRules({
    required int flowId,
    required _Flow template,
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    final scheduleStart = DateUtils.dateOnly(startDate);
    final scheduleEnd = DateUtils.dateOnly(
      endDate ?? scheduleStart.add(const Duration(days: 90)),
    );

    final noteMeta = _decodeSavedFlowImportNotes(template.notes);
    final noteTitle = template.name.isEmpty ? 'Flow Event' : template.name;
    final detailWithMeta = _encodeDetailWithMeta(
      noteMeta.detail,
      alertMinutes: noteMeta.alertMinutes,
    );

    var imported = 0;
    for (
      var date = scheduleStart;
      !date.isAfter(scheduleEnd);
      date = date.add(const Duration(days: 1))
    ) {
      final kDate = KemeticMath.fromGregorian(date);

      for (final rule in template.rules) {
        if (!rule.matches(
          ky: kDate.kYear,
          km: kDate.kMonth,
          kd: kDate.kDay,
          g: date,
        )) {
          continue;
        }

        final startHour = rule.allDay ? 9 : (rule.start?.hour ?? 9);
        final startMinute = rule.allDay ? 0 : (rule.start?.minute ?? 0);
        final startsAt = DateTime(
          date.year,
          date.month,
          date.day,
          startHour,
          startMinute,
        );

        DateTime? endsAt;
        if (!rule.allDay) {
          if (rule.end != null) {
            endsAt = DateTime(
              date.year,
              date.month,
              date.day,
              rule.end!.hour,
              rule.end!.minute,
            );
          } else {
            endsAt = startsAt.add(const Duration(hours: 1));
          }
        }

        final cid = EventCidUtil.buildClientEventId(
          ky: kDate.kYear,
          km: kDate.kMonth,
          kd: kDate.kDay,
          title: noteTitle,
          startHour: startHour,
          startMinute: startMinute,
          allDay: rule.allDay,
          flowId: flowId,
        );

        await _eventsRepo.upsertByClientId(
          clientEventId: cid,
          title: noteTitle,
          startsAtUtc: startsAt.toUtc(),
          detail: detailWithMeta ?? noteMeta.detail,
          location: noteMeta.location,
          allDay: rule.allDay,
          endsAtUtc: endsAt?.toUtc(),
          calendarId: template.calendarId,
          flowLocalId: flowId,
          category: noteMeta.category,
          caller: 'saved_flow_import_rules',
        );
        imported++;
      }
    }

    return imported;
  }

  ({String? detail, String? location, String? category, int? alertMinutes})
  _decodeSavedFlowImportNotes(String? rawNotes) {
    if (rawNotes == null || rawNotes.isEmpty) {
      return (detail: null, location: null, category: null, alertMinutes: null);
    }

    try {
      final meta = jsonDecode(rawNotes) as Map<String, dynamic>;
      if (meta['kind'] == 'repeating_note') {
        return (
          detail: (meta['detail'] as String?)?.trim(),
          location: (meta['location'] as String?)?.trim(),
          category: (meta['category'] as String?)?.trim(),
          alertMinutes: (meta['alertMinutes'] as num?)?.toInt(),
        );
      }
    } catch (_) {
      // Fall through to legacy note decoding.
    }

    try {
      final decoded = notesDecode(rawNotes);
      final overview = decoded.overview.trim();
      return (
        detail: overview.isEmpty ? null : overview,
        location: null,
        category: null,
        alertMinutes: null,
      );
    } catch (_) {
      return (detail: null, location: null, category: null, alertMinutes: null);
    }
  }

  Future<void> _handleImportSaved(_Flow flow) async {
    if (_isImportingSaved) return;
    setState(() => _isImportingSaved = true);
    final startDate = _savedDisplayStart(flow);
    try {
      final newId = await _importSavedFlow(flow, startDate);
      String? firstClientEventId;
      try {
        final events = await _eventsRepo.getEventsForFlow(newId);
        if (events.isNotEmpty) {
          firstClientEventId = events.first.clientEventId;
        }
      } catch (_) {}
      final pageState = CalendarPage.globalKey.currentState;
      if (pageState != null) {
        await pageState._notifySharedCalendarItemAdded(
          calendarId: flow.calendarId,
          itemType: 'flow',
          itemId: newId.toString(),
          itemTitle: flow.name,
          clientEventId: firstClientEventId,
          flowId: newId,
          startDate: startDate,
        );
      }
      if (!mounted) return;
      setState(() => _isImportingSaved = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Flow imported to your calendar'),
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.of(context).pop<int?>(newId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isImportingSaved = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }

  List<Widget> _buildSchedule({
    required _Flow flow,
    required bool kemetic,
    ReminderRule? reminderRule,
  }) {
    // Special-case reminder-backed flows: show their repeat pattern instead of
    // the empty rules table.
    if (reminderRule != null) {
      final repeatLabel = _reminderRepeatLabel(reminderRule);
      final startLabel = widget.fmt(reminderRule.startLocal);
      final timeLabel = reminderRule.allDay
          ? 'All day'
          : TimeOfDay.fromDateTime(reminderRule.startLocal).format(context);

      TextStyle head = const TextStyle(
        color: Colors.white70,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      );
      TextStyle cell = const TextStyle(color: Colors.white, fontSize: 13);

      return [
        Table(
          columnWidths: const {1: FlexColumnWidth(2)},
          children: [
            TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text('REPEAT', style: head),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    repeatLabel,
                    style: cell,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            const TableRow(
              children: [
                SizedBox(height: 1, child: ColoredBox(color: Colors.white10)),
                SizedBox(height: 1, child: ColoredBox(color: Colors.white10)),
              ],
            ),
            TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('STARTS', style: head),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    startLabel,
                    style: cell,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            const TableRow(
              children: [
                SizedBox(height: 1, child: ColoredBox(color: Colors.white10)),
                SizedBox(height: 1, child: ColoredBox(color: Colors.white10)),
              ],
            ),
            TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('TIME', style: head),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    timeLabel,
                    style: cell,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ],
        ),
      ];
    }

    final rows = <TableRow>[];

    TextStyle head = const TextStyle(
      color: Colors.white70,
      fontWeight: FontWeight.w600,
      fontSize: 12,
    );
    TextStyle cell = const TextStyle(color: Colors.white, fontSize: 13);

    // Header
    rows.add(
      TableRow(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(kemetic ? 'DECAN' : 'WEEKDAY', style: head),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text('DAYS', style: head, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
    rows.add(
      const TableRow(
        children: [
          SizedBox(height: 1, child: ColoredBox(color: Colors.white10)),
          SizedBox(height: 1, child: ColoredBox(color: Colors.white10)),
        ],
      ),
    );

    if (flow.rules.isEmpty) {
      rows.add(
        TableRow(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('—', style: TextStyle(color: Colors.white54)),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No schedule',
                style: TextStyle(color: Colors.white54),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      );
      return [
        Table(columnWidths: const {1: FlexColumnWidth(2)}, children: rows),
      ];
    }

    final r = flow.rules.first;
    if (kemetic) {
      if (r is _RuleDecan) {
        final days = r.daysInDecan.toList()..sort();
        for (final di in [1, 2, 3]) {
          final label = ['I', 'II', 'III'][di - 1];
          rows.add(
            TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('Decan $label', style: cell),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    days.isEmpty ? '—' : days.join(', '),
                    style: cell,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }
      } else if (r is _RuleDates) {
        // Group by Month • Decan
        final Map<String, List<int>> map = {};
        for (final g in r.dates) {
          final k = KemeticMath.fromGregorian(g);
          if (k.kMonth == 13) continue; // skip epagomenal
          final di = ((k.kDay - 1) ~/ 10); // 0..2
          final inDec = ((k.kDay - 1) % 10) + 1;
          final name =
              '${getMonthById(k.kMonth).displayFull} • ${widget.getDecanLabel(k.kMonth, di)}';
          (map[name] ??= <int>[]).add(inDec);
        }
        final keys = map.keys.toList()..sort();
        for (final key in keys) {
          final days = map[key]!..sort();
          rows.add(
            TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(key, style: cell),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    days.join(', '),
                    style: cell,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }
      } else {
        rows.add(
          TableRow(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('—', style: TextStyle(color: Colors.white54)),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Unsupported rule',
                  style: TextStyle(color: Colors.white54),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }
    } else {
      if (r is _RuleWeek) {
        final names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        for (int i = 1; i <= 7; i++) {
          rows.add(
            TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(names[i - 1], style: cell),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    r.weekdays.contains(i) ? 'Yes' : '—',
                    style: cell,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }
      } else if (r is _RuleDates) {
        // Group by week-of (Monday)
        final Map<DateTime, List<int>> byWeek = {};
        for (final g in r.dates) {
          final monday = _FlowStudioPageState._mondayOf(g);
          (byWeek[monday] ??= <int>[]).add(g.weekday);
        }
        final weeks = byWeek.keys.toList()..sort();
        final wdName = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        for (final m in weeks) {
          final days = byWeek[m]!..sort();
          rows.add(
            TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Week of ${_FlowStudioPageState._iso(m)}',
                    style: cell,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    days.map((wd) => wdName[wd - 1]).join(', '),
                    style: cell,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }
      } else {
        rows.add(
          TableRow(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('—', style: TextStyle(color: Colors.white54)),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Unsupported rule',
                  style: TextStyle(color: Colors.white54),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }
    }

    return [
      Table(
        columnWidths: const {1: FlexColumnWidth(2)},
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: rows,
      ),
    ];
  }

  Widget _buildFlowBody({
    required _Flow flow,
    required ({bool kemetic, bool split, String overview, String? maatKey})
    meta,
    required List<FlowEventRow> events,
    required bool loading,
    required Object? error,
    ReminderRule? reminderRule,
  }) {
    final displayOverview = _effectiveOverview(flow.notes, meta.overview);
    final isReminderFlow = reminderRule != null || flow.isReminder;
    final bottomPadding = AppBottomInsets.contentBottomPadding(context);

    return ListView(
      key: PageStorageKey('flow-${flow.id}'),
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
      children: [
        // Name
        GlossyText(
          text: flow.name,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          gradient: goldGloss,
        ),
        const SizedBox(height: 10),

        // Overview
        const GlossyText(
          text: 'Overview',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          gradient: silverGloss,
        ),
        const SizedBox(height: 6),
        Text(
          (displayOverview.isEmpty) ? '—' : displayOverview,
          style: const TextStyle(color: Colors.white, height: 1.35),
        ),
        const SizedBox(height: 16),

        // Date range + mode
        Row(
          children: [
            Expanded(
              child: Text(
                meta.kemetic ? 'Kemetic' : 'Gregorian',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            Text(
              '${widget.fmt(flow.start)} → ${widget.fmt(flow.end)}',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildFlowCalendarSelector(flow, dashboard: false),
        const SizedBox(height: 16),

        // Schedule
        const GlossyText(
          text: 'Schedule',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          gradient: silverGloss,
        ),
        const SizedBox(height: 6),
        ..._buildSchedule(
          flow: flow,
          kemetic: meta.kemetic,
          reminderRule: reminderRule,
        ),

        const SizedBox(height: 24),

        // Days & Notes (event-level note fields)
        const GlossyText(
          text: 'Days & Notes',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          gradient: silverGloss,
        ),
        const SizedBox(height: 6),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Could not load flow days/notes.',
              style: TextStyle(fontSize: 14, color: Colors.redAccent),
            ),
          )
        else if (events.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No days or notes for this flow yet.',
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
          )
        else if (isReminderFlow)
          _buildReminderSummaryCard(
            flow: flow,
            rule: reminderRule,
            events: events,
          )
        else
          ...events.map(
            (event) => _buildEventTile(
              event,
              isTrackSky:
                  meta.maatKey == 'track-the-sky' ||
                  _isTrackSkyFlowName(flow.name),
            ),
          ),
      ],
    );
  }

  bool _usesDashboardBody(_Flow flow, ReminderRule? reminderRule) {
    if (widget.mode == _FlowPreviewMode.legacy) return false;
    return reminderRule == null && !flow.isReminder;
  }

  List<_FlowDashboardDay> _dashboardDaysFor(
    _Flow flow,
    List<FlowEventRow> events,
  ) {
    final sorted = events.toList()
      ..sort((a, b) => a.startsAtUtc.compareTo(b.startsAtUtc));
    return [
      for (var i = 0; i < sorted.length; i++)
        _FlowDashboardDay(
          key:
              '${flow.id}:${sorted[i].id ?? sorted[i].clientEventId ?? '${i}_${sorted[i].startsAtUtc.toIso8601String()}'}',
          dayNumber: i + 1,
          event: sorted[i],
        ),
    ];
  }

  int _resolveCurrentDashboardIndex(List<_FlowDashboardDay> days) {
    if (days.isEmpty) return 0;
    final today = DateUtils.dateOnly(DateTime.now());
    for (var i = 0; i < days.length; i++) {
      if (DateUtils.isSameDay(DateUtils.dateOnly(days[i].localStart), today)) {
        return i;
      }
    }
    for (var i = 0; i < days.length; i++) {
      if (DateUtils.dateOnly(days[i].localStart).isAfter(today)) {
        return i;
      }
    }
    return days.length - 1;
  }

  _FlowDashboardPartition _partitionDashboardDays(
    _Flow flow,
    List<FlowEventRow> events,
  ) {
    final days = _dashboardDaysFor(flow, events);
    if (days.isEmpty) {
      return const _FlowDashboardPartition(
        completed: <_FlowDashboardDay>[],
        hero: null,
        upcoming: <_FlowDashboardDay>[],
        currentDayNumber: 1,
      );
    }

    if (widget.mode == _FlowPreviewMode.saved) {
      return _FlowDashboardPartition(
        completed: const <_FlowDashboardDay>[],
        hero: days.first,
        upcoming: days.skip(1).toList(),
        currentDayNumber: 1,
      );
    }

    final currentIndex = _resolveCurrentDashboardIndex(days);
    return _FlowDashboardPartition(
      completed: days.take(currentIndex).toList(),
      hero: days[currentIndex],
      upcoming: days.skip(currentIndex + 1).toList(),
      currentDayNumber: days[currentIndex].dayNumber,
    );
  }

  _FlowPreviewMetrics _metricsForFlow(_Flow flow, List<FlowEventRow> events) {
    final metrics = widget.metricsByFlow[flow.id];
    if (metrics != null) return metrics;
    return _FlowPreviewMetrics(
      totalEventCount: events.length,
      remainingEventCount: events.length,
      completedEventCount: 0,
    );
  }

  bool _isCidOnlyDetail(String text) {
    final trimmed = text.trim().replaceAll(RegExp(r'\s+'), '');
    final withPrefix = trimmed.startsWith('kemet_cid:')
        ? trimmed.substring('kemet_cid:'.length)
        : trimmed;
    final cidPattern = RegExp(
      r'^ky=\d+-km=\d+-kd=\d+\|s=\d+\|t=[^|]+\|f=[^|]+$',
    );
    return cidPattern.hasMatch(withPrefix);
  }

  _FlowDayContent _contentForDashboardDay(
    _FlowDashboardDay day, {
    required bool isTrackSky,
  }) {
    final event = day.event;
    final cleanedTitle = _cleanTitle(event.title);
    final title = cleanedTitle.isEmpty
        ? (event.title.trim().isEmpty ? '(Untitled day)' : event.title.trim())
        : cleanedTitle;
    final cleanedDetail = _stripCidLines(_cleanDetail(event.detail));
    final detailText = isTrackSky
        ? buildTrackSkyNarrativeSummary(
            title: event.title,
            category: event.category,
            fallbackGuidance: cleanedDetail,
          )
        : cleanedDetail;
    final body = detailText.isNotEmpty && !_isCidOnlyDetail(detailText)
        ? detailText
        : null;
    final location = (event.location ?? '').trim();
    final normalizedLocation = location.isEmpty
        ? ''
        : normalizeExternalLinkToken(location);
    final externalLabel = normalizedLocation.isEmpty
        ? (location.isEmpty ? null : 'Open Location')
        : normalizedLocation.toLowerCase().contains('youtu')
        ? 'Watch on YouTube'
        : 'Open Link';

    return _FlowDayContent(
      title: title,
      timeRange: _formatEventTime(day.localStart, day.localEnd, event.allDay),
      body: body,
      location: location.isEmpty ? null : location,
      externalButtonLabel: externalLabel,
    );
  }

  Widget _buildDashboardBody({
    required _Flow flow,
    required ({bool kemetic, bool split, String overview, String? maatKey})
    meta,
    required List<FlowEventRow> events,
    required bool loading,
    required Object? error,
  }) {
    final palette = _MyFlowCardPalette.fromColor(flow.color);
    final displayOverview = _effectiveOverview(flow.notes, meta.overview);
    final bottomPadding = AppBottomInsets.contentBottomPadding(context) + 196;
    final isTrackSky =
        meta.maatKey == 'track-the-sky' || _isTrackSkyFlowName(flow.name);

    if (loading && events.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: _gold));
    }

    final partition = _partitionDashboardDays(flow, events);
    final metrics = _metricsForFlow(flow, events);
    final total = metrics.totalEventCount > 0
        ? metrics.totalEventCount
        : events.length;
    final progressDay = widget.mode == _FlowPreviewMode.saved
        ? 1
        : partition.currentDayNumber;

    return ListView(
      key: PageStorageKey('flow-dashboard-${flow.id}-${widget.mode.name}'),
      padding: EdgeInsets.fromLTRB(30, 28, 30, bottomPadding),
      children: [
        _buildDashboardTitleArea(
          flow: flow,
          overview: displayOverview,
          palette: palette,
        ),
        const SizedBox(height: 34),
        _buildDashboardMetadataBar(
          flow: flow,
          meta: meta,
          palette: palette,
          progressLabel: 'Day $progressDay · $total',
        ),
        const SizedBox(height: 18),
        _buildFlowCalendarSelector(flow, dashboard: true, palette: palette),
        const SizedBox(height: 34),
        if (error != null)
          _buildDashboardMessage(
            'Could not load flow days/notes.',
            palette: palette,
            isError: true,
          )
        else if (events.isEmpty)
          _buildDashboardMessage(
            'No days or notes for this flow yet.',
            palette: palette,
          )
        else ...[
          if (widget.mode == _FlowPreviewMode.active &&
              partition.completed.isNotEmpty) ...[
            _buildDashboardSectionHeader(
              'COMPLETED · ${partition.completed.length} EVENTS',
              palette,
            ),
            const SizedBox(height: 14),
            ...partition.completed
                .take(3)
                .map(
                  (day) => _buildDashboardExpandableRow(
                    day: day,
                    palette: palette,
                    isCompleted: true,
                    isTrackSky: isTrackSky,
                  ),
                ),
            if (partition.completed.length > 3) ...[
              const SizedBox(height: 2),
              Center(
                child: Text(
                  '+ ${partition.completed.length - 3} more completed',
                  style: const TextStyle(
                    color: Color(0xFF4A3E22),
                    fontFamily: MaatFlowListTokens.fontFamily,
                    fontFamilyFallback: MaatFlowListTokens.fontFallback,
                    fontSize: 17,
                    fontStyle: FontStyle.italic,
                    height: 1.2,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 34),
          ],
          _buildDashboardSectionHeader(
            widget.mode == _FlowPreviewMode.saved
                ? 'DAY 1'
                : 'TODAY · DAY ${partition.hero?.dayNumber ?? progressDay}',
            palette,
          ),
          const SizedBox(height: 14),
          if (partition.hero != null)
            _MyFlowDayContentCard(
              key: ValueKey<String>('my_flow_day_card_${partition.hero!.key}'),
              day: partition.hero!,
              content: _contentForDashboardDay(
                partition.hero!,
                isTrackSky: isTrackSky,
              ),
              palette: palette,
              variant: widget.mode == _FlowPreviewMode.saved
                  ? _MyFlowDayCardVariant.savedLead
                  : _MyFlowDayCardVariant.liveHero,
              eyebrow: widget.mode == _FlowPreviewMode.saved
                  ? 'DAY 1'
                  : 'TODAY · DAY ${partition.hero!.dayNumber}',
            ),
          if (partition.upcoming.isNotEmpty) ...[
            const SizedBox(height: 46),
            _buildDashboardSectionHeader('UPCOMING', palette),
            const SizedBox(height: 14),
            ...partition.upcoming.map(
              (day) => _buildDashboardExpandableRow(
                day: day,
                palette: palette,
                isCompleted: false,
                isTrackSky: isTrackSky,
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildDashboardTitleArea({
    required _Flow flow,
    required String overview,
    required _MyFlowCardPalette palette,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 16,
              height: 16,
              margin: const EdgeInsets.only(top: 15, right: 18),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: palette.accent,
              ),
            ),
            Expanded(
              child: Text(
                flow.name,
                style: const TextStyle(
                  color: Color(0xFFF0D46E),
                  fontFamily: MaatFlowListTokens.fontFamily,
                  fontFamilyFallback: MaatFlowListTokens.fontFallback,
                  fontSize: 37,
                  fontWeight: FontWeight.w600,
                  height: 1.08,
                ),
              ),
            ),
          ],
        ),
        if (overview.trim().isNotEmpty) ...[
          const SizedBox(height: 28),
          Text(
            overview.trim(),
            style: const TextStyle(
              color: Color(0xFFB7AAA0),
              fontFamily: MaatFlowListTokens.fontFamily,
              fontFamilyFallback: MaatFlowListTokens.fontFallback,
              fontSize: 22,
              fontWeight: FontWeight.w500,
              height: 1.55,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDashboardMetadataBar({
    required _Flow flow,
    required ({bool kemetic, bool split, String overview, String? maatKey})
    meta,
    required _MyFlowCardPalette palette,
    required String progressLabel,
  }) {
    final values = <({String label, String value, bool accent})>[
      (
        label: 'SYSTEM',
        value: meta.kemetic ? 'Kemetic' : 'Gregorian',
        accent: false,
      ),
      (label: 'STARTED', value: widget.fmt(flow.start), accent: false),
      (label: 'ENDS', value: widget.fmt(flow.end), accent: false),
      (label: 'PROGRESS', value: progressLabel, accent: true),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 430;
        return Container(
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: Color(0x332A230D), width: 0.8),
              bottom: BorderSide(color: Color(0x332A230D), width: 0.8),
            ),
          ),
          child: narrow
              ? Column(
                  children: [
                    Row(children: _metadataCells(values.take(2), palette)),
                    const Divider(height: 1, color: Color(0x332A230D)),
                    Row(children: _metadataCells(values.skip(2), palette)),
                  ],
                )
              : Row(children: _metadataCells(values, palette)),
        );
      },
    );
  }

  List<Widget> _metadataCells(
    Iterable<({String label, String value, bool accent})> values,
    _MyFlowCardPalette palette,
  ) {
    final list = values.toList();
    return [
      for (var i = 0; i < list.length; i++) ...[
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  list[i].label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF4A3E22),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 3.0,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  list[i].value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: list[i].accent
                        ? palette.progressColor
                        : const Color(0xFFE8D9C3),
                    fontFamily: MaatFlowListTokens.fontFamily,
                    fontFamilyFallback: MaatFlowListTokens.fontFallback,
                    fontSize: 18,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (i < list.length - 1)
          const SizedBox(
            height: 58,
            child: VerticalDivider(
              width: 1,
              thickness: 0.8,
              color: Color(0x332A230D),
            ),
          ),
      ],
    ];
  }

  Widget _buildDashboardSectionHeader(
    String label,
    _MyFlowCardPalette palette,
  ) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Color.lerp(palette.accent, MaatFlowListTokens.gold, 0.28),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 4.0,
            height: 1,
          ),
        ),
        const SizedBox(width: 20),
        const Expanded(
          child: Divider(color: Color(0x332A230D), thickness: 0.8, height: 1),
        ),
      ],
    );
  }

  Widget _buildDashboardMessage(
    String message, {
    required _MyFlowCardPalette palette,
    bool isError = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.cardBase,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.cardBorder, width: 0.8),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: isError ? const Color(0xFFFF8A72) : const Color(0xFFB7AAA0),
          fontSize: 15,
          height: 1.35,
        ),
      ),
    );
  }

  Widget _buildDashboardExpandableRow({
    required _FlowDashboardDay day,
    required _MyFlowCardPalette palette,
    required bool isCompleted,
    required bool isTrackSky,
  }) {
    final expanded = _expandedDayKey == day.key;
    final content = _contentForDashboardDay(day, isTrackSky: isTrackSky);

    return Column(
      key: ValueKey<String>('my_flow_day_row_${day.key}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey<String>('my_flow_day_tap_${day.key}'),
            onTap: () {
              setState(() {
                _expandedDayKey = expanded ? null : day.key;
              });
            },
            splashColor: palette.accent.withValues(alpha: 0.05),
            highlightColor: palette.accent.withValues(alpha: 0.03),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 82,
                    child: Text(
                      'DAY\n${day.dayNumber}',
                      style: const TextStyle(
                        color: Color(0xFF4A3E22),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.2,
                        height: 1.18,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          content.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF7D6E50),
                            fontFamily: MaatFlowListTokens.fontFamily,
                            fontFamilyFallback: MaatFlowListTokens.fontFallback,
                            fontSize: 22,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w600,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.fmt(day.localStart),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF4E422B),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (isCompleted)
                    Icon(Icons.check, color: palette.accent, size: 26),
                  const SizedBox(width: 8),
                  Icon(
                    expanded ? Icons.expand_less : Icons.chevron_right,
                    color: palette.chevronColor,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topCenter,
          child: expanded
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: _MyFlowDayContentCard(
                    day: day,
                    content: content,
                    palette: palette,
                    variant: _MyFlowDayCardVariant.expandedInline,
                    eyebrow: isCompleted
                        ? 'COMPLETED · DAY ${day.dayNumber}'
                        : 'DAY ${day.dayNumber}',
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentFlow = _flowSequence[_currentIndex];
    final currentMeta = _metaFor(currentFlow);
    final currentEvents = _eventsByFlow[currentFlow.id] ?? const [];
    final currentReminderRule = _reminderRuleFromFlow(currentFlow);
    final usesDashboard = _usesDashboardBody(currentFlow, currentReminderRule);
    final isMaatInstance = currentMeta.maatKey != null;

    return Scaffold(
      backgroundColor: usesDashboard ? MaatFlowListTokens.pageBg : _bg,
      appBar: AppBar(
        backgroundColor: usesDashboard
            ? MaatFlowListTokens.pageBg
            : Colors.black,
        foregroundColor: usesDashboard ? MaatFlowListTokens.gold : Colors.white,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: usesDashboard ? 0 : 0.5,
        centerTitle: usesDashboard,
        toolbarHeight: usesDashboard ? 64 : null,
        iconTheme: IconThemeData(
          color: usesDashboard ? MaatFlowListTokens.gold : Colors.white,
        ),
        title: Text(
          usesDashboard ? 'My Flows' : 'Flow',
          style: TextStyle(
            color: usesDashboard ? MaatFlowListTokens.gold : Colors.white,
            fontFamily: usesDashboard ? MaatFlowListTokens.fontFamily : null,
            fontFamilyFallback: usesDashboard
                ? MaatFlowListTokens.fontFallback
                : null,
            fontSize: usesDashboard ? 25 : null,
            fontWeight: usesDashboard ? FontWeight.w500 : null,
            height: usesDashboard ? 1 : null,
          ),
        ),
        actions: [
          if (isMaatInstance && widget.onEndMaatFlow != null)
            OutlinedButton(
              style: withExpandedTouchTargets(
                context,
                OutlinedButton.styleFrom(
                  foregroundColor: _gold,
                  side: const BorderSide(color: _gold, width: 1.2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  minimumSize: const Size(0, 35),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: const VisualDensity(
                    horizontal: -1,
                    vertical: -1,
                  ),
                ),
              ),
              onPressed: () => widget.onEndMaatFlow?.call(currentFlow),
              child: const Text('End Flow'),
            ),
          if (widget.showFlowOptions)
            PopupMenuButton<String>(
              icon: KemeticGold.icon(Icons.more_vert), // ⋮ vertical dots
              tooltip: 'Flow options',
              onSelected: (value) async {
                if (value == 'journal') {
                  await _handleAddFlowToJournal(currentFlow, currentEvents);
                } else if (value == 'edit') {
                  widget.onEdit(currentFlow);
                } else if (value == 'share') {
                  _openShareSheet(context, currentFlow);
                } else if (value == 'save') {
                  await _toggleSaved(currentFlow);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'journal',
                  child: Row(
                    children: [
                      KemeticGold.icon(Icons.check_circle),
                      const SizedBox(width: 12),
                      const Text(
                        'Done / Add to journal',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      KemeticGold.icon(Icons.edit),
                      const SizedBox(width: 12),
                      const Text(
                        'Edit Flow',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'share',
                  child: Row(
                    children: [
                      KemeticGold.icon(Icons.share),
                      const SizedBox(width: 12),
                      const Text(
                        'Share Flow',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'save',
                  child: Row(
                    children: [
                      KemeticGold.icon(
                        currentFlow.isSaved
                            ? Icons.bookmark_remove
                            : Icons.bookmark_add,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        currentFlow.isSaved ? 'Remove from Saved' : 'Save Flow',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
              color: const Color(0xFF000000), // True black
            ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: _flowSequence.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
            _selectedStartForSaved = null;
            _isImportingSaved = false;
            _expandedDayKey = null;
          });
          _loadEventsFor(_flowSequence[index]);
        },
        itemBuilder: (context, index) {
          final flow = _flowSequence[index];
          final meta = _metaFor(flow);
          final events = _eventsByFlow[flow.id] ?? const [];
          final loading = _loadingFlowIds.contains(flow.id);
          final error = _eventsErrorByFlow[flow.id];
          final reminderRule = _reminderRuleFromFlow(flow);
          if (_usesDashboardBody(flow, reminderRule)) {
            return _buildDashboardBody(
              flow: flow,
              meta: meta,
              events: events,
              loading: loading,
              error: error,
            );
          }
          return _buildFlowBody(
            flow: flow,
            meta: meta,
            events: events,
            loading: loading,
            error: error,
            reminderRule: reminderRule,
          );
        },
      ),
      bottomNavigationBar: usesDashboard
          ? widget.actionPolicy != null
                ? _buildExternalDashboardFooter(
                    currentFlow,
                    widget.actionPolicy!,
                  )
                : _buildDashboardFooter(currentFlow)
          : currentFlow.isSaved
          ? _buildSavedImportFooter(currentFlow)
          : null,
    );
  }

  Widget _buildExternalDashboardFooter(
    _Flow flow,
    FlowDetailActionPolicy policy,
  ) {
    final palette = _MyFlowCardPalette.fromColor(flow.color);
    final startDateLabel = policy.startDateLabel;
    final onStartDatePressed = policy.onStartDatePressed;

    void runAction(FutureOr<void> Function()? action) {
      final result = action?.call();
      if (result is Future<void>) {
        unawaited(result);
      }
    }

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(30, 10, 30, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (startDateLabel != null && onStartDatePressed != null) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFE8D9C3),
                  side: BorderSide(color: palette.cardBorder, width: 1),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: policy.busy
                    ? null
                    : () => runAction(onStartDatePressed),
                child: Text(startDateLabel),
              ),
            ),
            const SizedBox(height: 12),
          ],
          _buildDashboardCtaButton(
            label: policy.effectiveLabel,
            palette: palette,
            onPressed: policy.canRun ? () => runAction(policy.onPressed) : null,
            icon: policy.icon,
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardFooter(_Flow flow) {
    final palette = _MyFlowCardPalette.fromColor(flow.color);
    if (widget.mode == _FlowPreviewMode.saved) {
      return SafeArea(
        minimum: const EdgeInsets.fromLTRB(30, 8, 30, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDashboardStartDateButton(flow, palette),
            const SizedBox(height: 12),
            _buildDashboardCtaButton(
              label: _isImportingSaved ? 'Importing…' : 'Import Flow',
              palette: palette,
              onPressed: _isImportingSaved
                  ? null
                  : () => _handleImportSaved(flow),
              icon: Icons.file_download_outlined,
            ),
          ],
        ),
      );
    }

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(30, 10, 30, 18),
      child: _buildDashboardCtaButton(
        label: 'Manage Flow',
        palette: palette,
        onPressed: () => widget.onEdit(flow),
        icon: Icons.tune,
      ),
    );
  }

  Widget _buildDashboardStartDateButton(
    _Flow flow,
    _MyFlowCardPalette palette,
  ) {
    final startDate = _savedDisplayStart(flow);
    final bool hasExplicitSelection =
        _selectedStartForSaved != null || flow.start != null;
    final label = hasExplicitSelection
        ? 'Start: ${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}'
        : 'Select a start date';

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFE8D9C3),
          side: BorderSide(color: palette.cardBorder, width: 1),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: _isImportingSaved ? null : () => _pickSavedStart(flow),
        child: Text(label),
      ),
    );
  }

  Widget _buildDashboardCtaButton({
    required String label,
    required _MyFlowCardPalette palette,
    required VoidCallback? onPressed,
    required IconData icon,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 76,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(
                palette.accent.withValues(alpha: 0.16),
                const Color(0xFF160805),
              ),
              const Color(0xFF070403),
            ],
          ),
          border: Border.all(color: palette.cardBorder, width: 0.9),
        ),
        child: TextButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, color: palette.progressColor, size: 22),
          label: Text(
            label,
            style: TextStyle(
              color: palette.progressColor,
              fontFamily: MaatFlowListTokens.fontFamily,
              fontFamilyFallback: MaatFlowListTokens.fontFallback,
              fontSize: 27,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSavedImportFooter(_Flow flow) {
    final startDate = _savedDisplayStart(flow);
    final bool hasExplicitSelection =
        _selectedStartForSaved != null || flow.start != null;
    final label = hasExplicitSelection
        ? 'Start: ${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}'
        : 'Select a start date';

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white54),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: _isImportingSaved ? null : () => _pickSavedStart(flow),
              child: Text(label),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF161616),
                foregroundColor: const Color(0xFF8A74FF),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _isImportingSaved
                  ? null
                  : () => _handleImportSaved(flow),
              child: Text(_isImportingSaved ? 'Importing…' : 'Import Flow'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleSaved(_Flow flow) async {
    try {
      await UserEventsRepo(
        Supabase.instance.client,
      ).setFlowSaved(flowId: flow.id, isSaved: !flow.isSaved);
      if (!mounted) return;
      setState(() {
        flow.isSaved = !flow.isSaved;
        flow.savedAt = flow.isSaved ? DateTime.now().toUtc() : null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            flow.isSaved ? 'Saved to Saved Flows' : 'Removed from Saved Flows',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update saved state: $e')),
      );
    }
  }

  Widget _buildEventTile(FlowEventRow e, {bool isTrackSky = false}) {
    final localStart = e.startsAtUtc.toLocal();
    final localEnd = e.endsAtUtc?.toLocal();
    bool isCidDetail(String text) {
      final trimmed = text.trim().replaceAll(RegExp(r'\s+'), '');
      final withPrefix = trimmed.startsWith('kemet_cid:')
          ? trimmed.substring('kemet_cid:'.length)
          : trimmed;
      final cidPattern = RegExp(
        r'^ky=\d+-km=\d+-kd=\d+\|s=\d+\|t=[^|]+\|f=[^|]+$',
      );
      return cidPattern.hasMatch(withPrefix);
    }

    final cleanedDetail = _stripCidLines(_cleanDetail(e.detail));
    final detailText = isTrackSky
        ? buildTrackSkyNarrativeSummary(
            title: e.title,
            category: e.category,
            fallbackGuidance: cleanedDetail,
          )
        : cleanedDetail;
    final hasDetail = detailText.isNotEmpty && !isCidDetail(detailText);
    final hasLocation = (e.location != null && e.location!.trim().isNotEmpty);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + date/time
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  e.title.isEmpty ? '(Untitled day)' : e.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatEventTime(localStart, localEnd, e.allDay),
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),

          if (hasDetail) ...[
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13, color: Colors.white),
                children: _buildExternalLinkSpans(detailText),
              ),
            ),
          ],

          if (hasLocation) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _launchExternalPreviewTarget(e.location!.trim()),
              child: Text(
                e.location!.trim(),
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReminderSummaryCard({
    required _Flow flow,
    required List<FlowEventRow> events,
    ReminderRule? rule,
  }) {
    final first = events.isNotEmpty ? events.first : null;
    final repeat = rule?.repeat ?? _decodeReminderRepeat(first?.detail);
    final startLocal =
        rule?.startLocal ?? first?.startsAtUtc.toLocal() ?? DateTime.now();
    final endLocal = rule?.endLocal ?? flow.end;
    final allDay = rule?.allDay ?? (first?.allDay ?? false);

    final effectiveRule = ReminderRule(
      id: rule?.id ?? flow.reminderUuid ?? 'reminder',
      title: flow.name,
      startLocal: startLocal,
      endLocal: endLocal,
      allDay: allDay,
      color: rule?.color ?? flow.color,
      category: rule?.category ?? first?.category,
      active: rule?.active ?? true,
      repeat: repeat,
    );

    final repeatLabel = _reminderRepeatLabel(effectiveRule);
    final timeLabel = allDay
        ? 'All day'
        : TimeOfDay.fromDateTime(startLocal).format(context);
    final dateLabel = widget.fmt(DateUtils.dateOnly(startLocal));
    final detail = _cleanDetail(first?.detail);
    final hasDetail = detail.isNotEmpty;
    final location = (first?.location ?? '').trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  flow.name.isEmpty ? '(Untitled reminder)' : flow.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$dateLabel · $timeLabel',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Repeats: $repeatLabel',
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (effectiveRule.endLocal != null) ...[
            const SizedBox(height: 4),
            Text(
              'Ends: ${widget.fmt(DateUtils.dateOnly(effectiveRule.endLocal!))}',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white60,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (hasDetail) ...[
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13, color: Colors.white),
                children: _buildExternalLinkSpans(detail),
              ),
            ),
          ],
          if (location.isNotEmpty) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _launchExternalPreviewTarget(location),
              child: Text(
                location,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatEventTime(DateTime start, DateTime? end, bool allDay) {
    if (allDay) {
      return widget.fmt(start);
    }

    final startTime = TimeOfDay.fromDateTime(start);
    final startTimeStr = startTime.format(context);

    if (end == null) {
      return '${widget.fmt(start)} · $startTimeStr';
    }

    final endTime = TimeOfDay.fromDateTime(end);
    final endTimeStr = endTime.format(context);

    final sameDay =
        start.year == end.year &&
        start.month == end.month &&
        start.day == end.day;

    if (sameDay) {
      return '${widget.fmt(start)} · $startTimeStr–$endTimeStr';
    }

    return '${widget.fmt(start)} $startTimeStr → ${widget.fmt(end)} $endTimeStr';
  }

  static Future<void> _openShareSheet(BuildContext context, _Flow flow) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          ShareFlowSheet(flowId: flow.id, flowTitle: flow.name),
    );

    if (result == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Flow shared successfully!'),
          backgroundColor: KemeticGold.base,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

class _MyFlowDayContentCard extends StatelessWidget {
  const _MyFlowDayContentCard({
    super.key,
    required this.day,
    required this.content,
    required this.palette,
    required this.variant,
    required this.eyebrow,
  });

  final _FlowDashboardDay day;
  final _FlowDayContent content;
  final _MyFlowCardPalette palette;
  final _MyFlowDayCardVariant variant;
  final String eyebrow;

  @override
  Widget build(BuildContext context) {
    final isInline = variant == _MyFlowDayCardVariant.expandedInline;
    final accentOpacity = isInline ? 0.58 : 0.82;
    final washOpacity = isInline ? 0.11 : 0.16;
    final borderOpacity = isInline ? 0.14 : 0.20;
    final titleSize = isInline ? 30.0 : 33.0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: palette.accent.withValues(alpha: borderOpacity),
          width: 0.9,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: palette.cardBase)),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      palette.accent.withValues(alpha: washOpacity),
                      palette.accent.withValues(alpha: washOpacity * 0.35),
                      Colors.transparent,
                    ],
                    stops: const [0, 0.38, 1],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.88, -0.92),
                    radius: 1.12,
                    colors: [
                      const Color(
                        0xFFF4D478,
                      ).withValues(alpha: isInline ? 0.045 : 0.065),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 4,
                color: palette.accent.withValues(alpha: accentOpacity),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                isInline ? 28 : 30,
                isInline ? 28 : 30,
                isInline ? 24 : 28,
                isInline ? 28 : 30,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eyebrow,
                    style: TextStyle(
                      color: palette.accent.withValues(alpha: 0.86),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3.1,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    content.title,
                    style: TextStyle(
                      color: const Color(0xFFF0D46E),
                      fontFamily: MaatFlowListTokens.fontFamily,
                      fontFamilyFallback: MaatFlowListTokens.fontFallback,
                      fontSize: titleSize,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    content.timeRange,
                    style: const TextStyle(
                      color: Color(0xFF8F817A),
                      fontFamily: MaatFlowListTokens.fontFamily,
                      fontFamilyFallback: MaatFlowListTokens.fontFallback,
                      fontSize: 17,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                  if (content.body != null) ...[
                    const SizedBox(height: 28),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          color: Color(0xFFB7AAA0),
                          fontFamily: MaatFlowListTokens.fontFamily,
                          fontFamilyFallback: MaatFlowListTokens.fontFallback,
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                          height: 1.45,
                        ),
                        children: _buildExternalLinkSpans(content.body!),
                      ),
                    ),
                  ],
                  if (content.location != null &&
                      content.externalButtonLabel != null) ...[
                    const SizedBox(height: 30),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: palette.accent,
                        side: BorderSide(
                          color: palette.accent.withValues(alpha: 0.42),
                          width: 1,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        minimumSize: const Size(0, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      onPressed: () =>
                          _launchExternalPreviewTarget(content.location!),
                      icon: Icon(
                        content.externalButtonLabel == 'Watch on YouTube'
                            ? Icons.play_arrow_rounded
                            : Icons.open_in_new,
                        size: 20,
                      ),
                      label: Text(
                        content.externalButtonLabel!,
                        style: const TextStyle(
                          fontFamily: MaatFlowListTokens.fontFamily,
                          fontFamilyFallback: MaatFlowListTokens.fontFallback,
                          fontSize: 21,
                          fontWeight: FontWeight.w600,
                          height: 1,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ---------------- Flows Viewer (list → preview) ---------------- */

String notesEncode({
  required bool kemetic,
  required bool split,
  required String overview,
  String? maatKey,
}) {
  final parts = <String>[
    kemetic ? 'mode=kemetic' : 'mode=gregorian',
    if (split) 'split=1',
    if (overview.trim().isNotEmpty)
      'ov=${Uri.encodeComponent(overview.trim())}',
    if (maatKey != null) 'maat=$maatKey',
  ];
  return parts.join(';');
}

({bool kemetic, bool split, String overview, String? maatKey}) notesDecode(
  String? notes,
) {
  bool kemetic = false;
  bool split = false;
  String overview = '';
  String? maatKey;
  if (notes != null && notes.isNotEmpty) {
    for (final token in notes.split(';')) {
      final t = token.trim();
      if (t == 'mode=kemetic') kemetic = true;
      if (t == 'split=1') split = true;
      if (t.startsWith('ov=')) overview = Uri.decodeComponent(t.substring(3));
      if (t.startsWith('maat=')) maatKey = t.substring(5);
    }
  }
  return (kemetic: kemetic, split: split, overview: overview, maatKey: maatKey);
}

// Derive a human-friendly overview string, falling back to stored notes content
// (including repeating-note metadata) when the encoded overview is empty.
ReminderRule? _tryParseReminderRuleFromNotes(String? notes) {
  if (notes == null || notes.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(notes.trim());
    if (decoded is Map<String, dynamic>) {
      return ReminderRule.fromJson(decoded);
    }
  } catch (_) {
    // Not a reminder json blob; ignore.
  }
  return null;
}

String _formatBasicTime(DateTime dt) {
  final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final m = dt.minute.toString().padLeft(2, '0');
  final mer = dt.hour >= 12 ? 'PM' : 'AM';
  return '$h:$m $mer';
}

ReminderRule? _reminderRuleFromFlow(_Flow f) {
  final rule = _tryParseReminderRuleFromNotes(f.notes);
  if (rule == null) return null;
  return rule.copyWith(
    calendarId: rule.calendarId ?? f.calendarId,
    endLocal: rule.endLocal ?? f.end,
  );
}

ReminderRepeat _decodeReminderRepeat(String? detail) {
  if (detail == null || detail.isEmpty) return const ReminderRepeat();
  final marker = 'repeat=';
  final idx = detail.indexOf(marker);
  if (idx < 0) return const ReminderRepeat();
  final start = idx + marker.length;
  final end = detail.indexOf(';', start);
  final jsonStr = (end >= 0)
      ? detail.substring(start, end)
      : detail.substring(start);
  try {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return ReminderRepeat.fromJson(map);
  } catch (_) {
    return const ReminderRepeat();
  }
}

String _reminderRepeatLabel(ReminderRule rule) {
  String ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
    }
  }

  switch (rule.repeat.kind) {
    case ReminderRepeatKind.none:
      return 'One-time';
    case ReminderRepeatKind.everyNDays:
      final iv = rule.repeat.interval <= 0 ? 1 : rule.repeat.interval;
      return iv == 1 ? 'Every day' : 'Every $iv days';
    case ReminderRepeatKind.weekly:
      if (rule.repeat.weekdays.isEmpty) return 'Weekly';
      const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final parts = rule.repeat.weekdays.toList()..sort();
      return parts.map((d) => labels[(d - 1).clamp(0, 6)]).join(', ');
    case ReminderRepeatKind.monthlyDay:
      final days = rule.repeat.monthDays.isNotEmpty
          ? rule.repeat.monthDays
          : {
              if (rule.repeat.monthDay != null)
                rule.repeat.monthDay!.clamp(1, 31),
            };
      final labels = days.toList()..sort();
      return 'Monthly ${labels.map(ordinal).join(", ")} (G)';
    case ReminderRepeatKind.kemeticEveryNDecans:
      final iv = rule.repeat.interval <= 0 ? 1 : rule.repeat.interval;
      return iv == 1 ? 'Every Decan' : 'Every $iv Decans';
    case ReminderRepeatKind.kemeticDecanDay:
      final ds = rule.repeat.decanDays.toList()..sort();
      return ds.isEmpty ? 'Each Decan' : 'Each Decan · Day ${ds.join(", ")}';
    case ReminderRepeatKind.kemeticMonthDay:
      final ds = rule.repeat.kemeticMonthDays.toList()..sort();
      if (ds.isEmpty) return 'Monthly (Kemetic)';
      return 'Monthly ${ds.map(ordinal).join(", ")} (K)';
  }
}

String _effectiveOverview(String? notes, String decodedOverview) {
  final trimmed = cleanFlowDetail(decodedOverview);
  if (trimmed.isNotEmpty) return trimmed;

  final reminderRule = _tryParseReminderRuleFromNotes(notes);
  if (reminderRule != null) {
    final repeatLabel = _reminderRepeatLabel(reminderRule);
    final timeLabel = reminderRule.allDay
        ? 'All day'
        : _formatBasicTime(reminderRule.startLocal);
    final endLabel = reminderRule.endLocal == null
        ? ''
        : ' · Ends ${DateUtils.dateOnly(reminderRule.endLocal!).month.toString().padLeft(2, '0')}/${DateUtils.dateOnly(reminderRule.endLocal!).day.toString().padLeft(2, '0')}/${DateUtils.dateOnly(reminderRule.endLocal!).year}';
    return 'Repeats $repeatLabel · $timeLabel$endLabel';
  }

  final raw = (notes ?? '').trim();
  if (raw.isEmpty) return '';

  final repMeta = _decodeRepeatingNoteMetadata(notes);
  if (repMeta.detail?.trim().isNotEmpty == true) {
    return repMeta.detail!.trim();
  }

  return cleanFlowOverview(raw);
}

// Helper: encode detail and location for repeating notes in flow.notes
String? _encodeRepeatingNoteMetadata({
  String? detail,
  String? location,
  String? category,
  int? alertMinutes,
  bool keepMarker = false,
}) {
  if (detail == null &&
      location == null &&
      category == null &&
      alertMinutes == null &&
      !keepMarker) {
    return null;
  }
  final parts = <String, dynamic>{'kind': 'repeating_note'};
  if (detail != null && detail.isNotEmpty) {
    parts['detail'] = detail;
  }
  if (location != null && location.isNotEmpty) {
    parts['location'] = location;
  }
  if (category != null && category.isNotEmpty) {
    parts['category'] = category;
  }
  if (alertMinutes != null) {
    parts['alertMinutes'] = alertMinutes;
  }
  return jsonEncode(parts);
}

// Helper: decode detail and location from flow.notes for repeating notes
({String? detail, String? location, String? category, int? alertMinutes})
_decodeRepeatingNoteMetadata(String? notes) {
  if (notes == null || notes.isEmpty) {
    return (detail: null, location: null, category: null, alertMinutes: null);
  }
  try {
    final meta = jsonDecode(notes) as Map<String, dynamic>;
    if (meta['kind'] == 'repeating_note') {
      return (
        detail: (meta['detail'] as String?)?.trim(),
        location: (meta['location'] as String?)?.trim(),
        category: (meta['category'] as String?)?.trim(),
        alertMinutes: (meta['alertMinutes'] as num?)?.toInt(),
      );
    }
  } catch (_) {
    // Not JSON or not our format
  }
  return (detail: null, location: null, category: null, alertMinutes: null);
}

// Helper: clean event title by stripping code-like patterns, metadata, and time patterns
String _cleanTitle(String? s) {
  if (s == null || s.isEmpty) return '';
  var t = s.trim();

  // Strip code fence patterns (```json, ```, etc.)
  t = t
      .replaceAll(
        RegExp(r'```[a-z]*\s*', multiLine: true, caseSensitive: false),
        '',
      )
      .trim();

  // Strip properly formatted time patterns (e.g., "8:00 PM", "8:00PM", "8:00")
  t = t
      .replaceAll(
        RegExp(
          r'\b\d{1,2}:\d{1,2}\s*(?:AM|PM|am|pm|A\.M\.|P\.M\.|a\.m\.|p\.m\.)\b',
          caseSensitive: false,
        ),
        '',
      )
      .trim();

  // Strip malformed time patterns with spaces in minutes (e.g., "7:0 0", "8: 0 0", "7:00 0")
  // Match: digit(s):digit(s) space digit(s) - with or without word boundaries
  t = t.replaceAll(RegExp(r'\d{1,2}:\s*\d\s+\d'), '').trim();
  t = t.replaceAll(RegExp(r'\d{1,2}:\d\s+\d'), '').trim();
  t = t.replaceAll(RegExp(r'\d{1,2}:\s*\d{1,2}\s+\d'), '').trim();

  // Strip simple time patterns without AM/PM (e.g., "7:00", "8:0", "7: 00")
  // But be careful - only if it's the entire string or at word boundaries
  t = t.replaceAll(RegExp(r'\b\d{1,2}:\s*\d{1,2}\b(?!\w)'), '').trim();

  // Strip time ranges (e.g., "8:00 AM - 9:00 AM", "8:00-9:00")
  t = t
      .replaceAll(
        RegExp(
          r'\b\d{1,2}:\d{1,2}\s*(?:AM|PM|am|pm)?\s*(?:-|–|to)\s*\d{1,2}:\d{1,2}\s*(?:AM|PM|am|pm)?\b',
          caseSensitive: false,
        ),
        '',
      )
      .trim();

  // If title is JSON-like with a title field, extract it
  if (t.startsWith('{') && t.contains('"title"')) {
    try {
      final decoded = jsonDecode(t);
      if (decoded is Map && decoded['title'] != null) {
        t = decoded['title'].toString().trim();
        // Re-strip time patterns after JSON extraction
        t = t
            .replaceAll(
              RegExp(
                r'\b\d{1,2}:\d{1,2}\s*(?:AM|PM|am|pm)\b',
                caseSensitive: false,
              ),
              '',
            )
            .trim();
      }
    } catch (_) {
      // ignore invalid JSON
    }
  }

  // Strip metadata prefixes
  if (t.startsWith('flowLocalId=')) {
    final i = t.indexOf(';');
    t = (i >= 0 && i < t.length - 1) ? t.substring(i + 1) : '';
  }

  // Strip CID-like patterns
  final cidPattern = RegExp(r'^ky=\d+-km=\d+-kd=\d+\|s=\d+\|t=[^|]+\|f=[^|]+');
  if (cidPattern.hasMatch(t.replaceAll(RegExp(r'\s+'), ''))) {
    return '';
  }

  // Remove stray code fences
  t = t.replaceAll(RegExp(r'^```|```$', multiLine: true), '').trim();

  // Collapse extra whitespace
  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();

  // Final check: if the cleaned title looks like just a time (including malformed), treat as empty
  final timeOnlyPattern = RegExp(
    r'^\s*\d{1,2}\s*[:]\s*\d{1,2}(?:\s+\d+)?\s*(?:AM|PM|am|pm)?\s*$',
    caseSensitive: false,
  );
  if (timeOnlyPattern.hasMatch(t)) {
    return '';
  }

  // Also check for malformed patterns like "7:0 0" (space between minute digits)
  final malformedTimePattern = RegExp(
    r'^\s*\d{1,2}\s*[:]\s*\d\s+\d\s*$',
    caseSensitive: false,
  );
  if (malformedTimePattern.hasMatch(t)) {
    return '';
  }

  if (t.isEmpty) return '';
  return t;
}

// Helper: clean event detail by stripping legacy flowLocalId= prefix
String _cleanDetail(String? s) {
  if (s == null || s.isEmpty) return '';
  final decoded = _decodeDetailMetadata(s);
  var t = decoded.detail ?? '';
  if (t.startsWith('flowLocalId=')) {
    final i = t.indexOf(';');
    t = (i >= 0 && i < t.length - 1) ? t.substring(i + 1) : '';
  }
  // Strip reminder metadata embedded in detail
  if (t.startsWith('repeat=')) {
    final i = t.indexOf(';');
    t = (i >= 0 && i < t.length - 1) ? t.substring(i + 1) : '';
  }
  // Strip kemet_cid / reminder metadata lines
  final lines = t.split(RegExp(r'\r?\n'));
  final kept = lines.where((line) {
    final trimmed = line.trim().toLowerCase();
    if (trimmed.startsWith('kemet_cid:')) return false;
    if (trimmed.startsWith('kemetic_cid:')) return false;
    if (trimmed.startsWith('reminder:')) return false;
    return trimmed.isNotEmpty;
  }).toList();
  t = kept.join('\n');
  return normalizeTrackSkyDetailText(t.trim());
}

// Helper: strip cid-only lines and legacy flowLocalId lines from detail text.
String _stripCidLines(String detail) {
  final lines = detail.split(RegExp(r'\r?\n'));
  final cidRegex = RegExp(
    r'^(kemet_cid:)?ky=\d+-km=\d+-kd=\d+\|s=\d+\|t=[^|]+\|f=[^|]+$',
  );
  final kept = lines.where((line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return false; // drop blanks
    if (trimmed.startsWith('flowLocalId=')) return false;
    final norm = trimmed.replaceAll(RegExp(r'\s+'), '');
    if (cidRegex.hasMatch(norm)) return false;
    return true;
  }).toList();
  return kept.join('\n').trim();
}

// Helper: collect cid/flowLocalId metadata lines so we can reattach later without showing them.
String _extractCidMetadata(String detail) {
  if (detail.isEmpty) return '';
  final lines = detail.split(RegExp(r'\r?\n'));
  final cidRegex = RegExp(
    r'^(kemet_cid:)?ky=\d+-km=\d+-kd=\d+\|s=\d+\|t=[^|]+\|f=[^|]+$',
  );
  final removed = lines.where((line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.startsWith('flowLocalId=')) return true;
    final norm = trimmed.replaceAll(RegExp(r'\s+'), '');
    return cidRegex.hasMatch(norm);
  }).toList();
  return removed.join('\n').trim();
}

// Helper: reattach hidden cid metadata without forcing the user to see it.
String _appendCidMetadata(String detail, String cidMeta) {
  if (cidMeta.isEmpty) return detail;
  if (detail.isEmpty) return cidMeta;
  final needsBlankLine = !detail.endsWith('\n');
  final separator = needsBlankLine ? '\n\n' : '\n';
  return '$detail$separator$cidMeta';
}

/// Extracts metadata prefixes (color + alert offset) from an event detail string.
/// Supports multiple prefixes in any order, e.g. `color=ffcc00;alert=-1;My note`.
({Color? color, int? alertMinutes, String? detail}) _decodeDetailMetadata(
  String? raw,
) {
  if (raw == null || raw.isEmpty) {
    return (color: null, alertMinutes: null, detail: null);
  }

  Color? color;
  int? alertMinutes;
  String remainder = raw;

  final metaPattern = RegExp(r'^(color=([0-9a-fA-FxX]+)|alert=([-+]?\d+));');
  while (true) {
    final match = metaPattern.firstMatch(remainder);
    if (match == null) break;

    final colorHex = match.group(2);
    final alertRaw = match.group(3);

    if (colorHex != null) {
      try {
        final int rgb = colorHex.toLowerCase().startsWith('0x')
            ? int.parse(colorHex)
            : int.parse('0x$colorHex');
        color = Color(0xFF000000 | (rgb & 0x00FFFFFF));
      } catch (_) {
        // Ignore invalid color metadata; continue parsing remainder.
      }
    } else if (alertRaw != null) {
      alertMinutes = int.tryParse(alertRaw);
    }

    remainder = remainder.substring(match.end);
  }

  return (
    color: color,
    alertMinutes: alertMinutes,
    detail: remainder.isEmpty ? null : remainder,
  );
}

String? _encodeDetailWithMeta(
  String? detail, {
  Color? color,
  int? alertMinutes,
}) {
  final buffer = StringBuffer();
  if (color != null) {
    final hex = (color.toARGB32() & 0x00FFFFFF)
        .toRadixString(16)
        .padLeft(6, '0');
    buffer.write('color=$hex;');
  }
  if (alertMinutes != null) {
    buffer.write('alert=$alertMinutes;');
  }
  if (detail != null && detail.isNotEmpty) {
    buffer.write(detail);
  }
  final out = buffer.toString();
  return out.isEmpty ? null : out;
}

// Helper: label for repeat option
String _repeatOptionLabel(
  NoteRepeatOption option,
  SimpleRecurrenceFrequency customFreq,
  int customInterval,
) {
  switch (option) {
    case NoteRepeatOption.never:
      return 'Never';
    case NoteRepeatOption.everyDay:
      return 'Every Day';
    case NoteRepeatOption.everyWeek:
      return 'Every Week';
    case NoteRepeatOption.every2Weeks:
      return 'Every 2 Weeks';
    case NoteRepeatOption.everyMonth:
      return 'Every Month';
    case NoteRepeatOption.everyYear:
      return 'Every Year';
    case NoteRepeatOption.custom:
      final unit = () {
        switch (customFreq) {
          case SimpleRecurrenceFrequency.daily:
            return 'day';
          case SimpleRecurrenceFrequency.weekly:
            return 'week';
          case SimpleRecurrenceFrequency.monthly:
            return 'month';
          case SimpleRecurrenceFrequency.yearly:
            return 'year';
        }
      }();
      if (customInterval == 1) {
        return 'Every $unit';
      } else {
        return 'Every $customInterval ${unit}s';
      }
  }
}

// Helper: label for end repeat
String _endRepeatLabel(
  NoteRepeatEndType endType,
  DateTime? endDate, [
  int? endCount,
]) {
  switch (endType) {
    case NoteRepeatEndType.never:
      return 'Never';
    case NoteRepeatEndType.onDate:
      if (endDate == null) return 'On Date…';
      return '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';
    case NoteRepeatEndType.afterCount:
      return 'After ${endCount ?? 10} times';
  }
}

/// Generate dates for a repeating note series, respecting Kemetic months/years
/// when frequency is monthly/yearly.
Set<DateTime> generateNoteRecurrenceDates({
  required DateTime startDate,
  required NoteRepeatOption repeatOption,
  required SimpleRecurrenceFrequency customFrequency,
  required int customInterval,
  required NoteRepeatEndType endType,
  required DateTime? endDate,
  required int endCount,
  required DateTime horizonEnd,
}) {
  final dates = <DateTime>{};

  // Determine effective frequency + interval from repeatOption/custom
  SimpleRecurrenceFrequency frequency;
  int interval;

  if (repeatOption == NoteRepeatOption.custom) {
    frequency = customFrequency;
    interval = (customInterval <= 0) ? 1 : customInterval;
  } else {
    switch (repeatOption) {
      case NoteRepeatOption.never:
        frequency = SimpleRecurrenceFrequency.daily;
        interval = 1;
        break;
      case NoteRepeatOption.everyDay:
        frequency = SimpleRecurrenceFrequency.daily;
        interval = 1;
        break;
      case NoteRepeatOption.everyWeek:
        frequency = SimpleRecurrenceFrequency.weekly;
        interval = 1;
        break;
      case NoteRepeatOption.every2Weeks:
        frequency = SimpleRecurrenceFrequency.weekly;
        interval = 2;
        break;
      case NoteRepeatOption.everyMonth:
        frequency = SimpleRecurrenceFrequency.monthly;
        interval = 1;
        break;
      case NoteRepeatOption.everyYear:
        frequency = SimpleRecurrenceFrequency.yearly;
        interval = 1;
        break;
      case NoteRepeatOption.custom:
        frequency = customFrequency;
        interval = (customInterval <= 0) ? 1 : customInterval;
        break;
    }
  }

  // Effective limit: min(horizonEnd, endDate) if "On Date"
  DateTime limit = DateUtils.dateOnly(horizonEnd);
  if (endType == NoteRepeatEndType.onDate && endDate != null) {
    final e = DateUtils.dateOnly(endDate);
    if (e.isBefore(limit)) {
      limit = e;
    }
  }

  int remainingCount = endType == NoteRepeatEndType.afterCount
      ? endCount
      : 1 << 30; // a big number

  DateTime current = DateUtils.dateOnly(startDate);

  // Special-case: starting in Month 13 with "Every Month" -> treat as yearly
  if (repeatOption == NoteRepeatOption.everyMonth) {
    final kStart = KemeticMath.fromGregorian(current);
    if (kStart.kMonth == 13) {
      frequency = SimpleRecurrenceFrequency.yearly;
      interval = 1;
    }
  }

  void addOccurrence(DateTime d) {
    final dayOnly = DateUtils.dateOnly(d);
    if (dayOnly.isAfter(limit)) return;
    if (remainingCount <= 0) return;
    dates.add(dayOnly);
    remainingCount--;
  }

  while (!current.isAfter(limit) && remainingCount > 0) {
    addOccurrence(current);

    switch (frequency) {
      case SimpleRecurrenceFrequency.daily:
        current = current.add(Duration(days: interval));
        break;

      case SimpleRecurrenceFrequency.weekly:
        current = current.add(Duration(days: 7 * interval));
        break;

      case SimpleRecurrenceFrequency.monthly:
        // Kemetic month arithmetic
        final k = KemeticMath.fromGregorian(current);
        final nextK = KemeticMath.addMonths(
          kYear: k.kYear,
          kMonth: k.kMonth,
          kDay: k.kDay,
          monthsToAdd: interval,
        );
        current = KemeticMath.toGregorian(
          nextK.kYear,
          nextK.kMonth,
          nextK.kDay,
        );
        break;

      case SimpleRecurrenceFrequency.yearly:
        // Kemetic year arithmetic (handles epagomenal/leap)
        final k = KemeticMath.fromGregorian(current);
        int newYear = k.kYear + interval;
        int newMonth = k.kMonth;
        int newDay = k.kDay;

        if (newMonth == 13) {
          final maxEpi = KemeticMath.isLeapKemeticYear(newYear) ? 6 : 5;
          if (newDay > maxEpi) newDay = maxEpi;
        }

        current = KemeticMath.toGregorian(newYear, newMonth, newDay);
        break;
    }
  }

  if (kDebugMode) {
    _calendarDebugPrint(
      '[RepeatNote] Generated ${dates.length} dates for $repeatOption '
      '(freq=$frequency, interval=$interval, limit=$limit)',
    );
  }

  return dates;
}

/// Build a note-specific rule using `_RuleDates` and the Kemetic-aware generator.
_RuleDates _buildNoteRuleDates({
  required DateTime firstOccurrenceDate,
  required NoteRepeatOption repeatOption,
  required SimpleRecurrenceFrequency customFrequency,
  required int customInterval,
  required NoteRepeatEndType endType,
  required DateTime? endDate,
  required int endCount,
  required bool allDay,
  required TimeOfDay? startTime,
  required TimeOfDay? endTime,
  required DateTime horizonEnd,
}) {
  final dates = generateNoteRecurrenceDates(
    startDate: firstOccurrenceDate,
    repeatOption: repeatOption,
    customFrequency: customFrequency,
    customInterval: customInterval,
    endType: endType,
    endDate: endDate,
    endCount: endCount,
    horizonEnd: horizonEnd,
  );

  return _RuleDates(
    dates: dates,
    allDay: allDay,
    start: startTime,
    end: endTime,
  );
}

class _FlowsViewerPage extends StatefulWidget {
  const _FlowsViewerPage({
    required this.loadFilingSnapshot,
    required this.fmtGregorian,
    required this.onCreateNew,
    required this.onEditFlow,
    required this.onEndFlow,
    this.onImportFlow,
    this.onAppendToJournal,
    this.onCalendarChanged,
    this.initialFilingSnapshot,
    this.onPreviewFlowForTesting,
  });

  final Future<_MyFlowsFilingSnapshot> Function() loadFilingSnapshot;
  final _MyFlowsFilingSnapshot? initialFilingSnapshot;
  final String Function(DateTime? d) fmtGregorian;
  final FutureOr<void> Function() onCreateNew;
  final FutureOr<void> Function(int flowId) onEditFlow;
  final FutureOr<void> Function(int flowId) onEndFlow;
  final Future<void> Function(int? importedFlowId)? onImportFlow;
  final Future<void> Function(String text)? onAppendToJournal;
  final Future<_Flow> Function(_Flow flow, SharedCalendarSummary calendar)?
  onCalendarChanged;
  final ValueChanged<int>? onPreviewFlowForTesting;

  @override
  State<_FlowsViewerPage> createState() => _FlowsViewerPageState();
}

class _FlowsViewerPageState extends State<_FlowsViewerPage> {
  FlowListTab _tab = FlowListTab.active;
  _MyFlowsFilingSnapshot? _snapshot;
  Object? _loadError;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.initialFilingSnapshot;
    _loading = _snapshot == null;
    unawaited(_reloadFiledFlows());
  }

  Future<void> _reloadFiledFlows() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }

    try {
      final snapshot = await widget.loadFilingSnapshot();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _snapshot ??= _MyFlowsFilingSnapshot.empty;
        _loading = false;
      });
    }
  }

  Future<void> _runAndReload(FutureOr<void> Function() action) async {
    try {
      await Future<void>.sync(action);
    } finally {
      await _reloadFiledFlows();
    }
  }

  Future<void> _openFlowPreview(List<_Flow> items, int index) async {
    final flow = items[index];
    final mode = _tab == FlowListTab.active
        ? _FlowPreviewMode.active
        : _FlowPreviewMode.saved;
    final metricsByFlow = <int, _FlowPreviewMetrics>{
      for (final item in items)
        item.id: _FlowPreviewMetrics.fromSnapshot(
          flow: item,
          snapshot: _currentSnapshot,
        ),
    };
    final previewForTesting = widget.onPreviewFlowForTesting;
    if (previewForTesting != null) {
      previewForTesting(flow.id);
      return;
    }

    final importedFlowId = await Navigator.of(context).push<int?>(
      MaterialPageRoute(
        builder: (_) => _FlowPreviewPage(
          flow: flow,
          flowSequence: items,
          initialIndex: index,
          mode: mode,
          metricsByFlow: metricsByFlow,
          getDecanLabel: (km, di) =>
              (DecanMetadata.decanNames[km] ?? const ['I', 'II', 'III'])[di],
          fmt: widget.fmtGregorian,
          onEdit: (flow) =>
              unawaited(_runAndReload(() => widget.onEditFlow(flow.id))),
          onAppendToJournal: widget.onAppendToJournal,
          onCalendarChanged: widget.onCalendarChanged,
          onEndMaatFlow: (flow) {
            unawaited(_runAndReload(() => widget.onEndFlow(flow.id)));
            Navigator.of(context).pop();
          },
        ),
      ),
    );
    if (!mounted) return;
    if (importedFlowId != null) {
      await widget.onImportFlow?.call(importedFlowId);
      await _reloadFiledFlows();
    }
  }

  int _compareSavedFlows(_Flow a, _Flow b) {
    final aSavedAt = a.savedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bSavedAt = b.savedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bySavedAt = bSavedAt.compareTo(aSavedAt);
    if (bySavedAt != 0) return bySavedAt;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  _MyFlowsFilingSnapshot get _currentSnapshot =>
      _snapshot ?? _MyFlowsFilingSnapshot.empty;

  List<_Flow> get _activeItems =>
      _currentSnapshot.flows
          .where((flow) => _currentSnapshot.activeFlowIds.contains(flow.id))
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  // Saved flows act as templates, so they stay visible even after the user
  // removes them from the active calendar.
  List<_Flow> get _savedItems =>
      _currentSnapshot.flows
          .where((flow) => _currentSnapshot.savedFlowIds.contains(flow.id))
          .toList()
        ..sort(_compareSavedFlows);

  @override
  Widget build(BuildContext context) {
    final items = _tab == FlowListTab.active ? _activeItems : _savedItems;

    Widget loadingState = const Center(
      child: CircularProgressIndicator(color: _gold),
    );

    Widget errorState = Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Unable to load flows',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 12),
            IconButton(
              tooltip: 'Retry',
              onPressed: _loading ? null : () => unawaited(_reloadFiledFlows()),
              icon: const Icon(Icons.refresh, color: _gold),
            ),
          ],
        ),
      ),
    );

    Widget emptyState = const Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'No flows yet',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            'Tap + to create a flow, or explore Ma’at templates.',
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );

    final listBottomPadding = AppBottomInsets.contentBottomPadding(context);
    Widget list = ListView.separated(
      padding: EdgeInsets.fromLTRB(16, 0, 16, listBottomPadding),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (ctx, i) {
        final f = items[i];
        final spec = _MyFlowCardDisplaySpec.fromFlow(
          flow: f,
          snapshot: _currentSnapshot,
        );

        return _MyFlowCard(
          spec: spec,
          isActive: _tab == FlowListTab.active,
          onTap: () {
            unawaited(_openFlowPreview(items, i));
          },
        );
      },
    );

    Widget content;
    if (_loading && _snapshot == null) {
      content = loadingState;
    } else if (_loadError != null && _currentSnapshot.flows.isEmpty) {
      content = errorState;
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MyFlowSectionLabel(
            label: _tab == FlowListTab.active ? 'ACTIVE' : 'SAVED',
          ),
          Expanded(child: items.isEmpty ? emptyState : list),
        ],
      );
    }

    return Scaffold(
      backgroundColor: MaatFlowListTokens.pageBg,
      appBar: AppBar(
        backgroundColor: MaatFlowListTokens.pageBg,
        foregroundColor: MaatFlowListTokens.gold,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 64,
        leadingWidth: 64,
        iconTheme: const IconThemeData(color: MaatFlowListTokens.gold),
        title: const Text(
          'My Flows',
          style: TextStyle(
            color: MaatFlowListTokens.gold,
            fontFamily: MaatFlowListTokens.fontFamily,
            fontFamilyFallback: MaatFlowListTokens.fontFallback,
            fontSize: 25,
            fontWeight: FontWeight.w500,
            height: 1,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'New flow',
            icon: const Icon(
              Icons.add,
              color: MaatFlowListTokens.gold,
              size: 22,
            ),
            onPressed: () {
              unawaited(_runAndReload(widget.onCreateNew));
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 38, 22, 0),
            child: _MyFlowsTabSelector(
              selected: _tab,
              onChanged: (tab) {
                if (tab != _tab) setState(() => _tab = tab);
              },
            ),
          ),
          const SizedBox(height: 38),
          Expanded(child: content),
        ],
      ),
    );
  }
}

class _MyFlowSectionLabel extends StatelessWidget {
  const _MyFlowSectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF4A3E22),
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 4.0,
          height: 1,
        ),
      ),
    );
  }
}

enum FlowListTab { active, saved }

class _MyFlowsTabSelector extends StatelessWidget {
  const _MyFlowsTabSelector({required this.selected, required this.onChanged});

  final FlowListTab selected;
  final ValueChanged<FlowListTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFF080704),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0x662A230D), width: 0.8),
      ),
      child: Row(
        children: [
          Expanded(
            child: _MyFlowsTabSegment(
              label: 'Active Flows',
              selected: selected == FlowListTab.active,
              onTap: () => onChanged(FlowListTab.active),
            ),
          ),
          Expanded(
            child: _MyFlowsTabSegment(
              label: 'Saved Flows',
              selected: selected == FlowListTab.saved,
              onTap: () => onChanged(FlowListTab.saved),
            ),
          ),
        ],
      ),
    );
  }
}

class _MyFlowsTabSegment extends StatelessWidget {
  const _MyFlowsTabSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = selected
        ? const Color(0xFFD0B34A)
        : const Color(0xFF5A4A2A);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        splashColor: MaatFlowListTokens.gold.withValues(alpha: 0.05),
        highlightColor: MaatFlowListTokens.gold.withValues(alpha: 0.03),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF211807) : Colors.transparent,
            borderRadius: BorderRadius.circular(28),
            border: selected
                ? Border.all(color: const Color(0x7744350F), width: 0.8)
                : null,
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected) ...[
                    const Icon(Icons.check, color: Color(0xFFD0B34A), size: 20),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      color: textColor,
                      fontFamily: MaatFlowListTokens.fontFamily,
                      fontFamilyFallback: MaatFlowListTokens.fontFallback,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

@visibleForTesting
Widget buildMyFlowsListPreviewForTesting({
  bool activeEmpty = false,
  bool savedEmpty = false,
  bool includeUnresolvedMaatFlow = false,
  bool includeMissingProgressFlow = false,
  bool includeNoScheduleSavedFlow = false,
  ValueChanged<int>? onPreviewFlow,
  VoidCallback? onCreateNew,
}) {
  final snapshot = _buildMyFlowsPreviewSnapshot(
    activeEmpty: activeEmpty,
    savedEmpty: savedEmpty,
    includeUnresolvedMaatFlow: includeUnresolvedMaatFlow,
    includeMissingProgressFlow: includeMissingProgressFlow,
    includeNoScheduleSavedFlow: includeNoScheduleSavedFlow,
  );

  return _FlowsViewerPage(
    loadFilingSnapshot: () async => snapshot,
    initialFilingSnapshot: snapshot,
    fmtGregorian: _formatMyFlowsPreviewGregorian,
    onCreateNew: onCreateNew ?? () {},
    onEditFlow: (_) {},
    onEndFlow: (_) {},
    onPreviewFlowForTesting: onPreviewFlow,
  );
}

@visibleForTesting
Widget buildMyFlowDetailPreviewForTesting({
  bool saved = false,
  bool reminderBacked = false,
  bool longTitle = false,
  Color flowColor = const Color(0xFFB95A38),
  VoidCallback? onManageFlow,
}) {
  final now = DateUtils.dateOnly(DateTime.now());
  final flow = _buildMyFlowsPreviewFlow(
    id: reminderBacked ? 70 : (saved ? 71 : 72),
    name: longTitle
        ? 'Daily Math Visuals: 90-Day Visual Math Ladder'
        : (saved ? 'Saved Personal Template' : 'Daily Math Visuals'),
    color: flowColor,
    active: !saved,
    isSaved: saved,
    start: now.subtract(const Duration(days: 2)),
    end: now.add(const Duration(days: 3)),
    notes: reminderBacked
        ? null
        : 'mode=gregorian;ov=${Uri.encodeComponent('A focused flow with one linked video each day and a short reflection.')}',
    isReminder: reminderBacked,
  );
  final events = reminderBacked
      ? <FlowEventRow>[
          _buildMyFlowPreviewEvent(
            flowId: flow.id,
            index: 0,
            title: 'Morning Review',
            detail: 'A short check-in for the day.',
            startsAt: now.add(const Duration(hours: 9)),
            endsAt: now.add(const Duration(hours: 10)),
          ),
        ]
      : <FlowEventRow>[
          for (var i = 0; i < 6; i++)
            _buildMyFlowPreviewEvent(
              flowId: flow.id,
              index: i,
              title: [
                'Area of Square',
                'How to Simplify Fractions',
                'Why Does Fermat’s Last Theorem Matter?',
                'The Birthday Problem and Probability',
                'What Is the Golden Ratio?',
                'How Euler’s Formula Connects Everything',
              ][i],
              detail: i == 2
                  ? 'Watch the linked video.\n\n"What does Fermat’s Last Theorem teach about patience in long problems?"'
                  : 'Watch the linked video and write one short reflection.',
              location: i == 2
                  ? 'https://www.youtube.com/watch?v=example'
                  : null,
              startsAt: now
                  .subtract(const Duration(days: 2))
                  .add(Duration(days: i, hours: 12)),
              endsAt: now
                  .subtract(const Duration(days: 2))
                  .add(Duration(days: i, hours: 13)),
            ),
        ];

  return _FlowPreviewPage(
    flow: flow,
    mode: reminderBacked
        ? _FlowPreviewMode.legacy
        : (saved ? _FlowPreviewMode.saved : _FlowPreviewMode.active),
    metricsByFlow: {
      flow.id: _FlowPreviewMetrics(
        totalEventCount: events.length,
        remainingEventCount: saved ? events.length : 3,
        completedEventCount: saved ? 0 : 3,
      ),
    },
    initialEventsByFlow: {flow.id: events},
    getDecanLabel: (km, di) =>
        (DecanMetadata.decanNames[km] ?? const ['I', 'II', 'III'])[di],
    fmt: _formatMyFlowsPreviewGregorian,
    onEdit: (_) => onManageFlow?.call(),
    onAppendToJournal: null,
    onEndMaatFlow: null,
  );
}

FlowEventRow _buildMyFlowPreviewEvent({
  required int flowId,
  required int index,
  required String title,
  required String detail,
  required DateTime startsAt,
  DateTime? endsAt,
  String? location,
}) {
  return (
    id: 'preview-$flowId-$index',
    clientEventId: 'preview-client-$flowId-$index',
    calendarId: null,
    calendarName: null,
    calendarColor: null,
    calendarIsPersonal: true,
    title: title,
    detail: detail,
    location: location,
    allDay: false,
    startsAtUtc: startsAt.toUtc(),
    endsAtUtc: endsAt?.toUtc(),
    flowLocalId: flowId,
    category: null,
    actionId: null,
    behaviorPayload: null,
  );
}

_MyFlowsFilingSnapshot _buildMyFlowsPreviewSnapshot({
  required bool activeEmpty,
  required bool savedEmpty,
  required bool includeUnresolvedMaatFlow,
  required bool includeMissingProgressFlow,
  required bool includeNoScheduleSavedFlow,
}) {
  final activeFlows = <_Flow>[
    _buildMyFlowsPreviewFlow(
      id: 1,
      name: 'Personal Practice',
      color: const Color(0xFF5C8FD8),
      start: DateTime(2026, 5, 25),
      end: DateTime(2026, 6, 23),
    ),
    _buildMyFlowsPreviewFlow(
      id: 2,
      name: 'Follow the sky',
      color: const Color(0xFF6876D8),
      start: DateTime(2026, 5),
      end: DateTime(2027, 3),
      notes: 'mode=kemetic;maat=track-the-sky',
    ),
  ];
  if (includeUnresolvedMaatFlow) {
    activeFlows.add(
      _buildMyFlowsPreviewFlow(
        id: 4,
        name: 'Mystery Maat',
        color: const Color(0xFFC8A84A),
        start: DateTime(2026, 7, 1),
        end: DateTime(2026, 7, 10),
        notes: 'mode=kemetic;maat=not-a-real-flow',
      ),
    );
  }
  if (includeMissingProgressFlow) {
    activeFlows.add(
      _buildMyFlowsPreviewFlow(
        id: 5,
        name: 'No Count Practice',
        color: const Color(0xFF8A7962),
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 9),
      ),
    );
  }

  final savedFlow = _buildMyFlowsPreviewFlow(
    id: 3,
    name: 'The Weighing',
    color: const Color(0xFFB8A88A),
    active: false,
    isSaved: true,
    savedAt: DateTime(2026, 6, 1),
    start: DateTime(2026, 5, 24),
    end: DateTime(2026, 6, 22),
    notes: 'mode=kemetic;maat=the-weighing',
  );
  final savedPersonalFlow = _buildMyFlowsPreviewFlow(
    id: 6,
    name: 'Saved Personal Template',
    color: const Color(0xFF8A4F3C),
    active: false,
    isSaved: true,
    savedAt: DateTime(2026, 5, 30),
    start: DateTime(2026, 5, 25),
    end: DateTime(2026, 8, 22),
  );
  final noScheduleSavedFlow = _buildMyFlowsPreviewFlow(
    id: 7,
    name: 'CODEX_NO_SCHEDULE_FLOW_VISIBILITY',
    color: const Color(0xFF6E8F5E),
    active: true,
    isSaved: true,
    savedAt: DateTime(2026, 6, 2),
  );
  final flows = <_Flow>[
    ...activeFlows,
    savedFlow,
    savedPersonalFlow,
    if (includeNoScheduleSavedFlow) noScheduleSavedFlow,
  ];
  final activeIds = activeEmpty
      ? <int>{}
      : activeFlows.map((flow) => flow.id).toSet();
  final savedIds = savedEmpty
      ? <int>{}
      : <int>{
          savedFlow.id,
          savedPersonalFlow.id,
          if (includeNoScheduleSavedFlow) noScheduleSavedFlow.id,
        };
  final totalCounts = <int, int>{
    1: 6,
    2: 27,
    3: 9,
    if (includeUnresolvedMaatFlow) 4: 10,
  };
  final remainingCounts = <int, int>{
    1: 2,
    2: 22,
    3: 2,
    if (includeUnresolvedMaatFlow) 4: 10,
  };

  return _MyFlowsFilingSnapshot(
    flows: List<_Flow>.unmodifiable(flows),
    activeFlowIds: Set<int>.unmodifiable(activeIds),
    savedFlowIds: Set<int>.unmodifiable(savedIds),
    totalEventCounts: Map<int, int>.unmodifiable(totalCounts),
    remainingEventCounts: Map<int, int>.unmodifiable(remainingCounts),
  );
}

_Flow _buildMyFlowsPreviewFlow({
  required int id,
  required String name,
  required Color color,
  DateTime? start,
  DateTime? end,
  String? notes,
  bool active = true,
  bool isSaved = false,
  bool isReminder = false,
  DateTime? savedAt,
}) {
  return _Flow(
    id: id,
    name: name,
    color: color,
    active: active,
    isSaved: isSaved,
    savedAt: savedAt,
    start: start,
    end: end,
    notes: notes,
    rules: const <FlowRule>[],
    isReminder: isReminder,
  );
}

String _formatMyFlowsPreviewGregorian(DateTime? date) {
  if (date == null) return '--';
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

/* ───────────────────────── Flow Hub (entry page) ───────────────────────── */

class _FlowHubPage extends StatefulWidget {
  const _FlowHubPage({
    required this.openMyFlows,
    required this.openMaatFlows,
    required this.onCreateNew,
    this.onClose,
  });

  final VoidCallback openMyFlows;
  final VoidCallback openMaatFlows;
  final VoidCallback onCreateNew;
  final VoidCallback? onClose;

  @override
  State<_FlowHubPage> createState() => _FlowHubPageState();
}

class _FlowHubPageState extends State<_FlowHubPage> {
  final GlobalKey _maatFlowsHelperKey = GlobalKey(
    debugLabel: 'flow_studio_maat_flows_helper',
  );
  bool _helperPrompted = false;
  bool _helperPromptScheduled = false;

  @override
  void initState() {
    super.initState();
    _scheduleFlowStudioMaatFlowsHelper();
  }

  void _scheduleFlowStudioMaatFlowsHelper() {
    if (_helperPromptScheduled) return;
    _helperPromptScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_maybeShowFlowStudioMaatFlowsHelper());
    });
  }

  Future<void> _maybeShowFlowStudioMaatFlowsHelper() async {
    if (_helperPrompted) return;
    final reviewMode = onboardingReviewSessionRequested;
    final userId =
        Supabase.instance.client.auth.currentUser?.id ??
        (reviewMode ? kOnboardingReviewHelperUserId : null);
    if (userId == null || userId.isEmpty) return;
    const helper = OnboardingHelperRegistry.flowStudioMaatFlows;
    final helperService = OnboardingHelperCompletionService.instance;
    if (!reviewMode &&
        !await helperService.shouldShowHelper(userId, helper.id)) {
      return;
    }
    _helperPrompted = true;
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    if (!reviewMode) {
      await helperService.hydrateUser(userId);
    }
    if (!mounted ||
        (!reviewMode &&
            !helperService.shouldShowHelperSync(userId, helper.id))) {
      return;
    }
    GuidedOnboardingController.instance.show(
      CoachmarkTarget(
        key: _maatFlowsHelperKey,
        title: helper.title,
        body: helper.body,
        placement: CoachmarkPlacement.below,
        variant: CoachmarkVariant.helperBubble,
        showDismissButton: true,
        dismissLabel: 'Got it',
        helperId: helper.id,
        helperUserId: userId,
        sourceWidget: OnboardingHelperRegistry.flowHubPageMaatFlowsSourceWidget,
        onDismiss: () async {
          if (reviewMode) {
            GuidedOnboardingController.instance.clear();
            return;
          }
          final completion = helperService.markHelperCompleted(
            userId,
            helper.id,
          );
          GuidedOnboardingController.instance.clear();
          await completion;
        },
      ),
    );
    unawaited(
      Events.trackIfAuthed(helper.analyticsEvent, const <String, dynamic>{}),
    );
  }

  Future<void> _markFlowStudioHelperCompleted(String helperId) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return;
    final completion = OnboardingHelperCompletionService.instance
        .markHelperCompleted(userId, helperId);
    if (GuidedOnboardingController.instance.target?.variant ==
        CoachmarkVariant.helperBubble) {
      GuidedOnboardingController.instance.clear();
    }
    await completion;
  }

  void _handleCreateNew() {
    unawaited(
      _markFlowStudioHelperCompleted(
        OnboardingHelperRegistry.flowStudioMaatFlows.id,
      ),
    );
    widget.onCreateNew();
  }

  void _handleOpenMyFlows() {
    unawaited(
      _markFlowStudioHelperCompleted(
        OnboardingHelperRegistry.flowStudioMaatFlows.id,
      ),
    );
    widget.openMyFlows();
  }

  void _handleOpenMaatFlows() {
    unawaited(
      _markFlowStudioHelperCompleted(
        OnboardingHelperRegistry.flowStudioMaatFlows.id,
      ),
    );
    widget.openMaatFlows();
  }

  void _handleClose() {
    final onClose = widget.onClose;
    if (onClose != null) {
      onClose();
      return;
    }
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    unawaited(Navigator.of(context, rootNavigator: true).maybePop());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.black,
        toolbarHeight: 58,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: IconButton(
            tooltip: 'Close',
            iconSize: 24,
            icon: const Icon(Icons.close, color: _gold),
            onPressed: _handleClose,
          ),
        ),
        centerTitle: true,
        title: const Text(
          'Flow Studio',
          style: TextStyle(
            color: _gold,
            fontSize: 24,
            fontWeight: FontWeight.w600,
            fontFamily: 'GentiumPlus',
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            height: 1,
            color: const Color(0xFF30200D).withValues(alpha: 0.48),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: AppBottomInsets.contentBottomPadding(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _FlowHubMaatCard(
                        key: _maatFlowsHelperKey,
                        title: _kMaatFlowsDisplayTitle,
                        subtitle:
                            'Practices offered by the tradition. Each one a\npath you can walk.',
                        joinedText: '3 of 31',
                        onTap: _handleOpenMaatFlows,
                      ),
                      const SizedBox(height: 14),
                      _FlowHubMyFlowsCard(
                        title: 'My Flows',
                        subtitle: 'Your active and saved flows.',
                        statsText: '5 active · 7 saved',
                        onTap: _handleOpenMyFlows,
                      ),
                      const SizedBox(height: 14),
                      _FlowHubAddCard(
                        title: 'Add Flow',
                        subtitle: 'Begin something new',
                        onTap: _handleCreateNew,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlowHubCardShell extends StatelessWidget {
  const _FlowHubCardShell({
    required this.onTap,
    required this.height,
    required this.child,
    this.featured = false,
  });

  final VoidCallback onTap;
  final double height;
  final Widget child;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final borderColor = featured
        ? _gold.withValues(alpha: 0.24)
        : _gold.withValues(alpha: 0.16);
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: featured ? const Color(0xFF17150B) : const Color(0xFF070604),
          borderRadius: BorderRadius.circular(featured ? 13 : 11),
          border: Border.all(color: borderColor),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(featured ? 13 : 11),
            onTap: onTap,
            child: Stack(
              children: [
                Positioned(
                  top: featured ? 21 : 0,
                  right: 15,
                  bottom: featured ? null : 0,
                  child: Center(
                    child: Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: _gold.withValues(alpha: 0.22),
                    ),
                  ),
                ),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FlowHubMaatCard extends StatelessWidget {
  const _FlowHubMaatCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.joinedText,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String joinedText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).shortestSide >= 600;
    return _FlowHubCardShell(
      onTap: onTap,
      height: isWide ? 300 : 281,
      featured: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 26, 18, 14),
        child: Column(
          children: [
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _gold.withValues(alpha: 0.24)),
                color: const Color(0xFF090806),
              ),
              alignment: Alignment.center,
              child: Container(
                width: 39,
                height: 39,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _gold.withValues(alpha: 0.17)),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.balance_outlined,
                  color: _gold.withValues(alpha: 0.78),
                  size: 18,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _gold,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                fontFamily: 'GentiumPlus',
              ),
            ),
            const SizedBox(height: 18),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF8A7848).withValues(alpha: 0.82),
                fontSize: 13,
                height: 1.55,
                fontStyle: FontStyle.italic,
                fontFamily: 'GentiumPlus',
              ),
            ),
            const Spacer(),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    'JOINED',
                    style: TextStyle(
                      color: _gold.withValues(alpha: 0.42),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.5,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Text(
                    joinedText,
                    style: TextStyle(
                      color: _gold.withValues(alpha: 0.72),
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      fontFamily: 'GentiumPlus',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlowHubMyFlowsCard extends StatelessWidget {
  const _FlowHubMyFlowsCard({
    required this.title,
    required this.subtitle,
    required this.statsText,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String statsText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _FlowHubCardShell(
      onTap: onTap,
      height: 163,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 17, 26, 16),
        child: Row(
          children: [
            const _FlowHubMiniPalette(),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _gold,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'GentiumPlus',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: const Color(0xFF7F704D).withValues(alpha: 0.68),
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      fontFamily: 'GentiumPlus',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    statsText,
                    style: TextStyle(
                      color: const Color(0xFF7F704D).withValues(alpha: 0.62),
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      fontFamily: 'GentiumPlus',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlowHubAddCard extends StatelessWidget {
  const _FlowHubAddCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _FlowHubCardShell(
      onTap: onTap,
      height: 117,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 15, 26, 15),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF151303),
                border: Border.all(color: _gold.withValues(alpha: 0.23)),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.add, color: _gold, size: 20),
            ),
            const SizedBox(width: 17),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: _gold.withValues(alpha: 0.82),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'GentiumPlus',
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: const Color(0xFF7F704D).withValues(alpha: 0.62),
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      fontFamily: 'GentiumPlus',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlowHubMiniPalette extends StatelessWidget {
  const _FlowHubMiniPalette();

  @override
  Widget build(BuildContext context) {
    const colors = [
      Color(0xFF5A8FC1),
      Color(0xFFB9603E),
      Color(0xFF5967B4),
      Color(0xFF958D7B),
      Color(0xFF524783),
      Color(0xFF7A3F25),
    ];
    return SizedBox(
      width: 19,
      height: 32,
      child: Wrap(
        spacing: 5,
        runSpacing: 5,
        children: [
          for (final color in colors)
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
        ],
      ),
    );
  }
}

// Legacy source marker retained for route guard slicing:
// class _FlowHubCell extends StatelessWidget

/* ───────────────────────── Ma’at Flows list ───────────────────────── */
