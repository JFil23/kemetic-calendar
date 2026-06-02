part of 'calendar_page.dart';

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
  });

  final _Flow flow;
  final List<_Flow>? flowSequence;
  final int initialIndex;
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
  late final UserEventsRepo _userEventsRepo;

  late final List<_Flow> _flowSequence;
  late int _currentIndex;
  late final PageController _pageController;

  // Cache events per flow id so we don't re-query when swiping back.
  final Map<int, List<FlowEventRow>> _eventsByFlow = {};
  final Map<int, Object?> _eventsErrorByFlow = {};
  final Set<int> _loadingFlowIds = {};
  DateTime? _selectedStartForSaved;
  bool _isImportingSaved = false;

  @override
  void initState() {
    super.initState();
    _userEventsRepo = UserEventsRepo(Supabase.instance.client);
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
    _loadEventsFor(_flowSequence[_currentIndex]);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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

    setState(() {
      _loadingFlowIds.add(flowId);
      _eventsErrorByFlow.remove(flowId);
    });

    try {
      final events = await _userEventsRepo.getEventsForFlow(flowId);
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
    final events = await _userEventsRepo.getEventsForFlow(template.id);

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

    final newId = await _userEventsRepo.upsertFlow(
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

      await _userEventsRepo.upsertByClientId(
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

        await _userEventsRepo.upsertByClientId(
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
        final events = await _userEventsRepo.getEventsForFlow(newId);
        if (events.isNotEmpty) {
          firstClientEventId = events.first.clientEventId;
        }
      } catch (_) {}
      final pageState = CalendarPage.globalKey.currentState;
      if (pageState != null) {
        await pageState._notifySharedCalendarMembers(
          calendarId: flow.calendarId,
          title: pageState._calendarDisplayName(flow.calendarId),
          body: 'Flow updated: ${flow.name}',
          clientEventId: firstClientEventId,
          data: <String, dynamic>{'flow_id': newId},
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

    return ListView(
      key: PageStorageKey('flow-${flow.id}'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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

  @override
  Widget build(BuildContext context) {
    final currentFlow = _flowSequence[_currentIndex];
    final currentMeta = _metaFor(currentFlow);
    final currentEvents = _eventsByFlow[currentFlow.id] ?? const [];
    final isMaatInstance = currentMeta.maatKey != null;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0.5,
        title: const Text('Flow', style: TextStyle(color: Colors.white)),
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
      bottomNavigationBar: currentFlow.isSaved
          ? _buildSavedImportFooter(currentFlow)
          : null,
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
}) {
  if (detail == null &&
      location == null &&
      category == null &&
      alertMinutes == null) {
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
    this.initialFilingSnapshot,
  });

  final Future<_MyFlowsFilingSnapshot> Function() loadFilingSnapshot;
  final _MyFlowsFilingSnapshot? initialFilingSnapshot;
  final String Function(DateTime? d) fmtGregorian;
  final FutureOr<void> Function() onCreateNew;
  final FutureOr<void> Function(int flowId) onEditFlow;
  final FutureOr<void> Function(int flowId) onEndFlow;
  final Future<void> Function(int? importedFlowId)? onImportFlow;
  final Future<void> Function(String text)? onAppendToJournal;

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

    Widget list = ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 12, color: Colors.white10),
      itemBuilder: (ctx, i) {
        final f = items[i];
        final meta = notesDecode(f.notes);
        final modeLabel = meta.kemetic ? 'Kemetic' : 'Gregorian';
        final statusLabel = _tab == FlowListTab.saved ? 'Saved' : 'Active';
        final rangeLabel =
            '${widget.fmtGregorian(f.start)} → ${widget.fmtGregorian(f.end)}';

        return ListTile(
          onTap: () async {
            final importedFlowId = await Navigator.of(context).push<int?>(
              MaterialPageRoute(
                builder: (_) => _FlowPreviewPage(
                  flow: f,
                  flowSequence: items,
                  initialIndex: i,
                  getDecanLabel: (km, di) =>
                      (DecanMetadata.decanNames[km] ??
                      const ['I', 'II', 'III'])[di],
                  fmt: widget.fmtGregorian,
                  onEdit: (flow) => unawaited(
                    _runAndReload(() => widget.onEditFlow(flow.id)),
                  ),
                  onAppendToJournal: widget.onAppendToJournal,
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
          },

          leading: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _glossFromColor(f.color),
            ),
          ),
          title: Text(f.name, style: const TextStyle(color: Colors.white)),
          subtitle: Text(
            [
              statusLabel,
              modeLabel,
              if (f.start != null || f.end != null) rangeLabel,
            ].join(' • '),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          trailing: const Icon(Icons.chevron_right, color: _silver),
        );
      },
    );

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0.5,
        title: const Text('My Flows', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            tooltip: 'New flow',
            icon: const Icon(Icons.add, color: _silver),
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<FlowListTab>(
                    segments: const [
                      ButtonSegment(
                        value: FlowListTab.active,
                        label: Text('Active Flows'),
                      ),
                      ButtonSegment(
                        value: FlowListTab.saved,
                        label: Text('Saved Flows'),
                      ),
                    ],
                    selected: <FlowListTab>{_tab},
                    onSelectionChanged: (v) {
                      if (v.isNotEmpty) {
                        setState(() => _tab = v.first);
                      }
                    },
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all(
                        const Color(0xFF111111),
                      ),
                      foregroundColor: WidgetStateProperty.all(Colors.white),
                      side: WidgetStateProperty.all(
                        const BorderSide(color: Colors.white24),
                      ),
                      padding: WidgetStateProperty.all(
                        const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading && _snapshot == null
                ? loadingState
                : (_loadError != null && _currentSnapshot.flows.isEmpty)
                ? errorState
                : items.isEmpty
                ? emptyState
                : list,
          ),
        ],
      ),
    );
  }
}

enum FlowListTab { active, saved }

/* ───────────────────────── Flow Hub (entry page) ───────────────────────── */

class _FlowHubPage extends StatefulWidget {
  const _FlowHubPage({
    required this.openMyFlows,
    required this.openMaatFlows,
    required this.onCreateNew,
  });

  final VoidCallback openMyFlows;
  final VoidCallback openMaatFlows;
  final VoidCallback onCreateNew;

  @override
  State<_FlowHubPage> createState() => _FlowHubPageState();
}

class _FlowHubPageState extends State<_FlowHubPage> {
  final GlobalKey _flowBuilderHelperKey = GlobalKey(
    debugLabel: 'flow_hub_builder_helper',
  );
  bool _helperPrompted = false;

  @override
  void initState() {
    super.initState();
    unawaited(_maybeShowFlowBuilderHelper());
  }

  Future<void> _maybeShowFlowBuilderHelper() async {
    if (_helperPrompted) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return;
    final storage = OnboardingProgressStorage();
    if (!await storage.shouldShowHelper(
      userId,
      OnboardingHelperIds.flowBuilder,
    )) {
      return;
    }
    _helperPrompted = true;
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    if (!await storage.shouldShowHelper(
      userId,
      OnboardingHelperIds.flowBuilder,
    )) {
      return;
    }
    GuidedOnboardingController.instance.show(
      CoachmarkTarget(
        key: _flowBuilderHelperKey,
        title: 'Build your own rhythm',
        body:
            'Create personal flows for study, health, family, writing, business, or spiritual practice.',
        placement: CoachmarkPlacement.below,
        variant: CoachmarkVariant.helperBubble,
        showDismissButton: true,
        dismissLabel: 'Got it',
        onDismiss: () async {
          GuidedOnboardingController.instance.clear();
          await storage.markHelperCompleted(
            userId,
            OnboardingHelperIds.flowBuilder,
          );
          await Events.trackIfAuthed(
            'helper_seen_flow_builder',
            const <String, dynamic>{},
          );
        },
      ),
    );
  }

  Future<void> _markFlowBuilderHelperCompleted() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return;
    if (GuidedOnboardingController.instance.target?.variant ==
        CoachmarkVariant.helperBubble) {
      GuidedOnboardingController.instance.clear();
    }
    await OnboardingProgressStorage().markHelperCompleted(
      userId,
      OnboardingHelperIds.flowBuilder,
    );
  }

  void _handleCreateNew() {
    unawaited(_markFlowBuilderHelperCompleted());
    widget.onCreateNew();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0.5,
        title: const Text('Flow Studio', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 32, 16, 0),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FlowHubCell(
                      key: _flowBuilderHelperKey,
                      title: 'Add Flow',
                      subtitle: 'Create a new flow',
                      onTap: _handleCreateNew,
                    ),
                    _FlowHubCell(
                      title: 'My Flows',
                      subtitle: 'Your saved and active flows',
                      onTap: widget.openMyFlows,
                    ),
                    _FlowHubCell(
                      title: _kMaatFlowsDisplayTitle,
                      subtitle: "Ma'at template flows",
                      onTap: widget.openMaatFlows,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowHubCell extends StatelessWidget {
  const _FlowHubCell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF101114),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: KemeticGold.base.withValues(alpha: 0.72),
          width: 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                KemeticGold.text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.fade,
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* ───────────────────────── Ma’at Flows list ───────────────────────── */
