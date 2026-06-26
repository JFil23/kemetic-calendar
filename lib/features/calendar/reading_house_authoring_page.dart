part of 'calendar_page.dart';

class _ReadingHouseAuthoringPage extends StatefulWidget {
  const _ReadingHouseAuthoringPage({
    required this.flow,
    this.onSave,
    this.calendar,
    this.personalCalendarId,
    this.sharedCalendarsRepo,
    this.onCalendarChanged,
  });

  final _Flow flow;
  final Future<void> Function(_FlowStudioResult result)? onSave;
  final SharedCalendarSummary? calendar;
  final String? personalCalendarId;
  final SharedCalendarsRepo? sharedCalendarsRepo;
  final Future<_Flow> Function(_Flow flow, SharedCalendarSummary calendar)?
  onCalendarChanged;

  @override
  State<_ReadingHouseAuthoringPage> createState() =>
      _ReadingHouseAuthoringPageState();
}

class _ReadingHouseAuthoringPageState
    extends State<_ReadingHouseAuthoringPage> {
  final UserEventsRepo _eventsRepo = UserEventsRepo(Supabase.instance.client);
  late _Flow _flow;
  SharedCalendarSummary? _calendar;
  List<ReadingHouseSitting> _sittings =
      readingHouseStarterSittingsForAuthoring();
  List<SharedCalendarMember> _members = const <SharedCalendarMember>[];
  ReadingHousePlan _plan = const ReadingHousePlan();
  TrackSkyTimeZone _timezone = detectTrackSkyTimeZone();
  DateTime? _firstStart;
  bool _loading = true;
  bool _saving = false;
  bool _membersLoading = false;
  bool _presenceSaving = false;
  Object? _error;
  Object? _membersError;

  @override
  void initState() {
    super.initState();
    _flow = widget.flow;
    _calendar = widget.calendar;
    _plan = readingHousePlanFromFlowNotes(_flow.notes);
    _timezone =
        _readingHouseTimeZoneFromKey(
          _readingHouseFlowNoteToken(_flow.notes, 'reading_house_tz='),
        ) ??
        detectTrackSkyTimeZone();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await _eventsRepo.getEventsForFlow(
        _flow.id,
        flowEventsOnly: true,
      );
      final sittings = <ReadingHouseSitting>[];
      for (final row in rows) {
        if (!isReadingHouseFlowReference(
          flowName: _flow.name,
          flowNotes: _flow.notes,
          actionId: row.actionId,
          behaviorPayload: row.behaviorPayload,
        )) {
          continue;
        }
        final sitting = readingHouseSittingForEvent(
          title: row.title,
          actionId: row.actionId,
          behaviorPayload: row.behaviorPayload,
        );
        if (sitting == null) continue;
        final localStart = readingHouseLocalDateTimeForUtc(
          row.startsAtUtc,
          _timezone,
        );
        sittings.add(
          sitting.copyWith(
            scheduledDate: DateTime(
              localStart.year,
              localStart.month,
              localStart.day,
            ),
            hour: localStart.hour,
            minute: localStart.minute,
          ),
        );
        _plan = readingHousePlanFromPayload(
          row.behaviorPayload,
          fallback: _plan,
        );
      }
      sittings.sort((a, b) => a.eventNumber.compareTo(b.eventNumber));
      if (!mounted) return;
      setState(() {
        _sittings = sittings.isEmpty
            ? readingHouseStarterSittingsForAuthoring()
            : normalizeReadingHouseSittingOrder(sittings);
        _firstStart =
            _sittings.first.scheduledDate ??
            _flow.start ??
            defaultReadingHouseStartDate(_timezone);
        _loading = false;
      });
      unawaited(_loadHousePresence());
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _loadHousePresence() async {
    final calendarId = _flow.calendarId?.trim();
    if (calendarId != null &&
        calendarId.isNotEmpty &&
        (_calendar == null || _calendar?.id.trim() != calendarId)) {
      await _refreshHouseCalendar(calendarId);
    }
    await _loadHouseMembers();
  }

  DateTime get _effectiveFirstStart {
    final first = _firstStart ?? _flow.start ?? DateTime.now();
    return DateTime(first.year, first.month, first.day);
  }

  int _flowDayForDate(DateTime sittingDate) {
    final first = _effectiveFirstStart;
    final selected = DateTime(
      sittingDate.year,
      sittingDate.month,
      sittingDate.day,
    );
    return math.max(1, selected.difference(first).inDays + 1);
  }

  String _dateLabel(DateTime date) {
    final k = KemeticMath.fromGregorian(date);
    final month = getMonthById(k.kMonth).displayFull;
    final g =
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.year}';
    return '$month ${k.kDay} · $g';
  }

  String _timeLabel(TimeOfDay time) {
    return MaterialLocalizations.of(context).formatTimeOfDay(time);
  }

  DateTime _dateForSitting(ReadingHouseSitting sitting) {
    final schedule = readingHouseScheduleForSitting(
      sitting,
      _effectiveFirstStart,
      _timezone,
    );
    return DateTime(
      schedule.startLocal.year,
      schedule.startLocal.month,
      schedule.startLocal.day,
    );
  }

  bool get _isSharedHouseCalendar {
    final calendar = _calendar;
    if (calendar == null || calendar.isPersonal || calendar.isSystem) {
      return false;
    }
    final personalId = widget.personalCalendarId?.trim();
    if (personalId != null &&
        personalId.isNotEmpty &&
        calendar.id.trim() == personalId) {
      return false;
    }
    return calendar.status == SharedCalendarInviteStatus.accepted;
  }

  int get _activeJoinedMemberCount {
    if (_plan.isSolo) return 1;
    final accepted = _members
        .where((member) => member.status == SharedCalendarInviteStatus.accepted)
        .length;
    if (accepted > 0) return accepted;
    final summaryCount = _calendar?.memberCount ?? 1;
    return summaryCount < 1 ? 1 : summaryCount;
  }

  String get _houseState => readingHouseHouseStateFor(
    soloStudy: _plan.isSolo,
    activeJoinedMemberCount: _activeJoinedMemberCount,
  );

  bool get _canAuthorSittings {
    final calendar = _calendar;
    if (calendar == null || !_isSharedHouseCalendar) return true;
    return calendar.canEdit;
  }

  void _showAuthoringLockedMessage() {
    _showPresenceMessage(
      'View-only members can read the plan but cannot edit sittings.',
    );
  }

  String? get _nextSittingLabel {
    if (_sittings.isEmpty) return null;
    final today = DateUtils.dateOnly(DateTime.now());
    ReadingHouseSitting? next;
    ReadingHouseOccurrenceSchedule? nextSchedule;
    for (final sitting in normalizeReadingHouseSittingOrder(_sittings)) {
      final schedule = readingHouseScheduleForSitting(
        sitting,
        _effectiveFirstStart,
        _timezone,
      );
      final date = DateUtils.dateOnly(schedule.startLocal);
      if (date.isBefore(today)) continue;
      next = sitting;
      nextSchedule = schedule;
      break;
    }
    next ??= _sittings.first;
    nextSchedule ??= readingHouseScheduleForSitting(
      next,
      _effectiveFirstStart,
      _timezone,
    );
    return '${readingHouseSittingTitle(next)} · ${_dateLabel(nextSchedule.startLocal)}';
  }

  void _showPresenceMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadHouseMembers() async {
    final repo = widget.sharedCalendarsRepo;
    final calendar = _calendar;
    if (_plan.isSolo ||
        repo == null ||
        calendar == null ||
        !_isSharedHouseCalendar ||
        !calendar.canSeeMemberRoster) {
      if (!mounted) return;
      setState(() {
        _members = const <SharedCalendarMember>[];
        _membersLoading = false;
        _membersError = null;
      });
      return;
    }

    setState(() {
      _membersLoading = true;
      _membersError = null;
    });
    try {
      final members = await repo.listMembers(
        calendar.id,
        includePending: calendar.canSeePendingInvites,
        expectedMemberCount: calendar.memberCount,
        expectedPendingCount: calendar.pendingInviteCount,
      );
      if (!mounted) return;
      setState(() {
        _members = members;
        _membersLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _membersError = error;
        _membersLoading = false;
      });
    }
  }

  Future<void> _refreshHouseCalendar(String calendarId) async {
    final repo = widget.sharedCalendarsRepo;
    if (repo == null) return;
    final snapshot = await repo.loadSnapshot();
    SharedCalendarSummary? updated;
    for (final calendar in snapshot.calendars) {
      if (calendar.id == calendarId) {
        updated = calendar;
        break;
      }
    }
    if (!mounted || updated == null) return;
    setState(() => _calendar = updated);
  }

  Future<void> _inviteReader() async {
    final repo = widget.sharedCalendarsRepo;
    final calendar = _calendar;
    if (repo == null ||
        calendar == null ||
        !_isSharedHouseCalendar ||
        !calendar.canManageMembership ||
        _presenceSaving) {
      return;
    }
    final userId = await context.push<String>(
      '/profile-search'
      '?title=${Uri.encodeComponent('Invite to Reading House')}'
      '&hint=${Uri.encodeComponent('Search by @handle or display name')}'
      '&select=picker',
    );
    if (!mounted || userId == null || userId.trim().isEmpty) return;

    setState(() => _presenceSaving = true);
    try {
      await repo.inviteUser(
        calendarId: calendar.id,
        userId: userId.trim(),
        role: SharedCalendarRole.viewer,
        calendarName: calendar.name,
        calendarColorValue: calendar.colorValue,
      );
      await _refreshHouseCalendar(calendar.id);
      await _loadHouseMembers();
      _showPresenceMessage('Reading House invite sent.');
    } catch (error) {
      _showPresenceMessage('Could not invite reader: $error');
    } finally {
      if (mounted) {
        setState(() => _presenceSaving = false);
      }
    }
  }

  Future<void> _showMembers() async {
    final repo = widget.sharedCalendarsRepo;
    final calendar = _calendar;
    if (repo == null ||
        calendar == null ||
        !_isSharedHouseCalendar ||
        !calendar.canSeeMemberRoster) {
      return;
    }
    final changed = await CalendarMembersSheet.show(
      context,
      repo: repo,
      calendar: calendar,
      pendingFirst: false,
    );
    if (!mounted) return;
    if (changed == true) {
      await _refreshHouseCalendar(calendar.id);
    }
    await _loadHouseMembers();
  }

  Future<void> _openSharedCalendarChooser() async {
    final repo = widget.sharedCalendarsRepo;
    final onCalendarChanged = widget.onCalendarChanged;
    if (repo == null || onCalendarChanged == null) {
      await CalendarPage.openSharedCalendarsFromAnyContext(
        context,
        restorationState: const <String, dynamic>{
          'source': 'reading_house_phase_3a',
        },
      );
      return;
    }

    final snapshot = await repo.loadSnapshot();
    if (!mounted) return;
    final options = snapshot.calendars
        .where(
          (calendar) =>
              !calendar.isPersonal && !calendar.isSystem && calendar.canEdit,
        )
        .toList(growable: false);
    if (options.isEmpty) {
      await CalendarPage.openSharedCalendarsFromAnyContext(
        context,
        restorationState: const <String, dynamic>{
          'source': 'reading_house_phase_3a',
        },
      );
      return;
    }

    final selected = await _chooseSharedCalendar(options);
    if (!mounted || selected == null || _presenceSaving) return;

    setState(() => _presenceSaving = true);
    try {
      final updated = await onCalendarChanged(_flow, selected);
      if (!mounted) return;
      setState(() {
        _flow = updated;
        _calendar = selected;
      });
      await _refreshHouseCalendar(selected.id);
      await _loadHouseMembers();
      _showPresenceMessage('Reading House opened on ${selected.name}.');
    } catch (error) {
      _showPresenceMessage(
        'Could not open this house on a shared calendar: $error',
      );
    } finally {
      if (mounted) {
        setState(() => _presenceSaving = false);
      }
    }
  }

  Future<SharedCalendarSummary?> _chooseSharedCalendar(
    List<SharedCalendarSummary> options,
  ) {
    return showModalBottomSheet<SharedCalendarSummary>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0C120F),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0x664FA58D)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Open House calendar',
                  style: TextStyle(
                    color: Color(0xFFF0D46E),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Choose a shared calendar. Joined members will see this house schedule; private reader text stays private.',
                  style: TextStyle(color: Color(0xFFB7AAA0), height: 1.3),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: Color(0x334FA58D)),
                    itemBuilder: (itemContext, index) {
                      final calendar = options[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          calendar.name,
                          style: const TextStyle(color: Color(0xFFE8D9C3)),
                        ),
                        subtitle: Text(
                          readingHouseMemberCountSummary(calendar.memberCount),
                          style: const TextStyle(color: Color(0xFFB7AAA0)),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: Color(0xFF76CBB2),
                        ),
                        onTap: () => Navigator.of(sheetContext).pop(calendar),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _editSitting(ReadingHouseSitting sitting) async {
    if (!_canAuthorSittings) {
      _showAuthoringLockedMessage();
      return;
    }
    final scheduledDate = _dateForSitting(sitting);
    final edited = await showModalBottomSheet<ReadingHouseSitting>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReadingHouseSittingDraftSheet(
        sitting: sitting,
        initialDate: scheduledDate,
        initialTime: TimeOfDay(hour: sitting.hour, minute: sitting.minute),
        flowDayForDate: _flowDayForDate,
        accentColor: const Color(0xFF76CBB2),
        borderColor: const Color(0x664FA58D),
      ),
    );
    if (edited == null || !mounted) return;
    setState(() {
      _sittings = editReadingHouseSitting(
        _sittings,
        sitting.eventNumber,
        edited,
      );
    });
  }

  void _addSitting() {
    if (!_canAuthorSittings) {
      _showAuthoringLockedMessage();
      return;
    }
    setState(() {
      _sittings = addReadingHouseSitting(_sittings);
    });
  }

  void _deleteSitting(ReadingHouseSitting sitting) {
    if (!_canAuthorSittings) {
      _showAuthoringLockedMessage();
      return;
    }
    if (_sittings.length <= 1) return;
    setState(() {
      _sittings = deleteReadingHouseSitting(_sittings, sitting.eventNumber);
    });
  }

  void _moveSitting(int oldIndex, int newIndex) {
    if (!_canAuthorSittings) {
      _showAuthoringLockedMessage();
      return;
    }
    setState(() {
      _sittings = reorderReadingHouseSitting(_sittings, oldIndex, newIndex);
    });
  }

  Future<void> _save() async {
    if (_saving || _sittings.isEmpty) return;
    if (!_canAuthorSittings) {
      _showAuthoringLockedMessage();
      return;
    }
    setState(() => _saving = true);

    final normalized = normalizeReadingHouseSittingOrder(_sittings);
    final schedules = <ReadingHouseOccurrenceSchedule>[
      for (final sitting in normalized)
        readingHouseScheduleForSitting(
          sitting,
          _effectiveFirstStart,
          _timezone,
        ),
    ];
    final dates = <DateTime>{
      for (final schedule in schedules)
        DateTime(
          schedule.startLocal.year,
          schedule.startLocal.month,
          schedule.startLocal.day,
        ),
    };
    final orderedDates = dates.toList()..sort();

    final notes = <String>[
      'mode=gregorian',
      'split=1',
      if (kReadingHouseOverview.trim().isNotEmpty)
        'ov=${Uri.encodeComponent(kReadingHouseOverview.trim())}',
      'maat=$kReadingHouseFlowKey',
      'reading_house_tz=${_timezone.key}',
      ...readingHouseFlowNoteTokens(_plan),
      'reading_house_authoring_phase=$kReadingHouseHostAuthoringPhaseEnabled',
      'reading_house_hour=$kReadingHouseDefaultHour',
      'reading_house_minute=$kReadingHouseDefaultMinute',
    ].join(';');

    final planned = <_PlannedNote>[];
    for (var i = 0; i < normalized.length; i++) {
      final sitting = normalized[i];
      final schedule = schedules[i];
      final k = KemeticMath.fromGregorian(
        DateTime(
          schedule.startLocal.year,
          schedule.startLocal.month,
          schedule.startLocal.day,
        ),
      );
      final title = readingHouseSittingTitle(sitting);
      final detail = readingHouseDetailText(sitting, plan: _plan);
      planned.add(
        _PlannedNote(
          ky: k.kYear,
          km: k.kMonth,
          kd: k.kDay,
          note: _Note(
            title: title,
            detail: detail,
            allDay: false,
            start: TimeOfDay(
              hour: schedule.startLocal.hour,
              minute: schedule.startLocal.minute,
            ),
            end: TimeOfDay(
              hour: schedule.endLocal.hour,
              minute: schedule.endLocal.minute,
            ),
            flowId: _flow.id,
            category: 'Study',
            alertOffsetMinutes: _alertNoneMinutes,
            actionId: readingHouseActionId(sitting),
            behaviorPayload: readingHouseBehaviorPayload(
              sitting: sitting,
              schedule: schedule,
              plan: _plan,
            ),
          ),
        ),
      );
    }

    final result = _FlowStudioResult(
      savedFlow: _Flow(
        id: _flow.id,
        calendarId: _flow.calendarId,
        name: _flow.name,
        color: _flow.color,
        active: _flow.active,
        isSaved: _flow.isSaved,
        savedAt: _flow.savedAt,
        rules: <FlowRule>[if (dates.isNotEmpty) _RuleDates(dates: dates)],
        start: orderedDates.isEmpty ? _flow.start : orderedDates.first,
        end: orderedDates.isEmpty ? _flow.end : orderedDates.last,
        notes: notes,
        shareId: _flow.shareId,
        isHidden: _flow.isHidden,
        isReminder: _flow.isReminder,
        reminderUuid: _flow.reminderUuid,
      ),
      plannedNotes: planned,
    );

    final onSave = widget.onSave;
    if (onSave != null) {
      await onSave(result);
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  Widget _sittingTile(ReadingHouseSitting sitting, int index) {
    final schedule = readingHouseScheduleForSitting(
      sitting,
      _effectiveFirstStart,
      _timezone,
    );
    final sourceLabel =
        sitting.sittingSource == kReadingHouseSittingSourceHostAuthored
        ? 'Host authored'
        : 'Starter default';
    final time = TimeOfDay(
      hour: schedule.startLocal.hour,
      minute: schedule.startLocal.minute,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0C120F),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x554FA58D)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        collapsedIconColor: const Color(0xFF76CBB2),
        iconColor: const Color(0xFF76CBB2),
        title: Text(
          readingHouseSittingTitle(sitting),
          style: const TextStyle(
            color: Color(0xFFF0D46E),
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          '$sourceLabel · ${_dateLabel(schedule.startLocal)} · ${_timeLabel(time)}',
          style: const TextStyle(color: Color(0xFFB7AAA0)),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: [
          Text(
            readingHouseDetailText(sitting, plan: _plan),
            style: const TextStyle(color: Color(0xFFE8D9C3), height: 1.35),
          ),
          const SizedBox(height: 12),
          if (_canAuthorSittings)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Move up',
                  onPressed: index == 0
                      ? null
                      : () => _moveSitting(index, index - 1),
                  icon: const Icon(Icons.keyboard_arrow_up),
                  color: const Color(0xFF76CBB2),
                ),
                IconButton(
                  tooltip: 'Move down',
                  onPressed: index >= _sittings.length - 1
                      ? null
                      : () => _moveSitting(index, index + 1),
                  icon: const Icon(Icons.keyboard_arrow_down),
                  color: const Color(0xFF76CBB2),
                ),
                IconButton(
                  tooltip: 'Edit sitting',
                  onPressed: () => _editSitting(sitting),
                  icon: const Icon(Icons.edit_outlined),
                  color: const Color(0xFF76CBB2),
                ),
                IconButton(
                  tooltip: 'Delete sitting',
                  onPressed: _sittings.length <= 1
                      ? null
                      : () => _deleteSitting(sitting),
                  icon: const Icon(Icons.delete_outline),
                  color: const Color(0xFFD98E73),
                ),
              ],
            ),
          if (!_canAuthorSittings)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'View only · hosts and calendar editors author sittings.',
                style: TextStyle(color: Color(0xFFB7AAA0), height: 1.3),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMemberPreview() {
    if (_plan.isSolo) return const SizedBox.shrink();
    if (!_isSharedHouseCalendar) {
      return const Text(
        'No joined readers yet.',
        style: TextStyle(color: Color(0xFFB7AAA0), height: 1.3),
      );
    }
    if (_membersLoading) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text('Loading members', style: TextStyle(color: Color(0xFFB7AAA0))),
        ],
      );
    }
    if (_membersError != null) {
      return Text(
        readingHouseMemberCountSummary(_activeJoinedMemberCount),
        style: const TextStyle(color: Color(0xFFB7AAA0), height: 1.3),
      );
    }

    final accepted = _members
        .where((member) => member.status == SharedCalendarInviteStatus.accepted)
        .toList(growable: false);
    final pending = _members
        .where((member) => member.status == SharedCalendarInviteStatus.pending)
        .toList(growable: false);
    if (accepted.isEmpty) {
      return Text(
        readingHouseMemberCountSummary(_activeJoinedMemberCount),
        style: const TextStyle(color: Color(0xFFB7AAA0), height: 1.3),
      );
    }

    final visibleMembers = accepted.take(4).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final member in visibleMembers)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                const Icon(
                  Icons.person_outline,
                  size: 16,
                  color: Color(0xFF76CBB2),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${member.displayLabel} · ${member.roleLabel}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFFE8D9C3)),
                  ),
                ),
              ],
            ),
          ),
        if (accepted.length > visibleMembers.length)
          Text(
            '+${accepted.length - visibleMembers.length} more joined',
            style: const TextStyle(color: Color(0xFFB7AAA0), height: 1.3),
          ),
        if (pending.isNotEmpty)
          Text(
            pending.length == 1
                ? '1 invite pending'
                : '${pending.length} invites pending',
            style: const TextStyle(color: Color(0xFFB7AAA0), height: 1.3),
          ),
      ],
    );
  }

  Widget _buildHousePresencePanel() {
    final houseState = _houseState;
    final stateLabel = readingHouseHouseStateLabel(houseState);
    final calendar = _calendar;
    final calendarName = calendar?.name.trim();
    final summaryLines = readingHouseFactualSummaryLines(
      houseState: houseState,
      activeJoinedMemberCount: _activeJoinedMemberCount,
      nextSittingLabel: _nextSittingLabel,
    );
    final canInvite =
        !_plan.isSolo &&
        _isSharedHouseCalendar &&
        calendar != null &&
        calendar.canManageMembership;
    final canShowMembers =
        !_plan.isSolo &&
        _isSharedHouseCalendar &&
        calendar != null &&
        calendar.canSeeMemberRoster;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0C120F),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x664FA58D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.groups_2_outlined,
                color: Color(0xFF76CBB2),
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stateLabel,
                      style: const TextStyle(
                        color: Color(0xFFF0D46E),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (calendarName != null && calendarName.isNotEmpty)
                      Text(
                        calendarName,
                        style: const TextStyle(color: Color(0xFFB7AAA0)),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final line in summaryLines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                line,
                style: const TextStyle(color: Color(0xFFE8D9C3), height: 1.3),
              ),
            ),
          const SizedBox(height: 12),
          _buildMemberPreview(),
          if (!_plan.isSolo) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                if (!_isSharedHouseCalendar)
                  OutlinedButton.icon(
                    onPressed: _presenceSaving
                        ? null
                        : _openSharedCalendarChooser,
                    icon: const Icon(Icons.group_add_outlined),
                    label: const Text('Open on shared calendar'),
                  ),
                if (canInvite)
                  OutlinedButton.icon(
                    onPressed: _presenceSaving ? null : _inviteReader,
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: const Text('Invite reader'),
                  ),
                if (canShowMembers)
                  TextButton.icon(
                    onPressed: _showMembers,
                    icon: const Icon(Icons.people_outline),
                    label: const Text('Members'),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            'Membership uses shared-calendar access. The schedule, roster, chosen sitting fragments, one-level replies, house margin, and host announcements are visible to joined members; private reflections, notes, and local margin text stay private. Discussion rooms and chat remain future-facing.',
            style: TextStyle(color: Color(0xFFB7AAA0), height: 1.35),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MaatFlowListTokens.pageBg,
      appBar: AppBar(
        backgroundColor: MaatFlowListTokens.pageBg,
        foregroundColor: MaatFlowListTokens.gold,
        surfaceTintColor: Colors.transparent,
        title: const Text('Reading House'),
        actions: [
          if (_canAuthorSittings)
            TextButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(_saving ? 'Saving' : 'Save'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _gold))
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Text(
                  'Could not load Reading House sittings.',
                  style: const TextStyle(color: Color(0xFFE8D9C3)),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(
                24,
                18,
                24,
                AppBottomInsets.contentBottomPadding(context) + 28,
              ),
              children: [
                const Text(
                  'Host sittings',
                  style: TextStyle(
                    color: Color(0xFFF0D46E),
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _canAuthorSittings
                      ? 'Shape the private reading plan. Readers can bring chosen fragments after Carrying; responses stay fragment-scoped.'
                      : 'Read the shared sitting plan. Hosts and calendar editors author sittings.',
                  style: const TextStyle(
                    color: Color(0xFFB7AAA0),
                    fontSize: 16,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 22),
                _buildHousePresencePanel(),
                for (var i = 0; i < _sittings.length; i++)
                  _sittingTile(_sittings[i], i),
                const SizedBox(height: 8),
                if (_canAuthorSittings)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _addSitting,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Sitting'),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ReadingHouseSittingDraftSheet extends StatefulWidget {
  const _ReadingHouseSittingDraftSheet({
    required this.sitting,
    required this.initialDate,
    required this.initialTime,
    required this.flowDayForDate,
    required this.accentColor,
    required this.borderColor,
  });

  final ReadingHouseSitting sitting;
  final DateTime initialDate;
  final TimeOfDay initialTime;
  final int Function(DateTime date) flowDayForDate;
  final Color accentColor;
  final Color borderColor;

  @override
  State<_ReadingHouseSittingDraftSheet> createState() =>
      _ReadingHouseSittingDraftSheetState();
}

class _ReadingHouseSittingDraftSheetState
    extends State<_ReadingHouseSittingDraftSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _sectionCtrl;
  late final TextEditingController _themeCtrl;
  late final TextEditingController _promptCtrl;
  late final TextEditingController _noteCtrl;
  late DateTime _scheduledDate;
  late TimeOfDay _scheduledTime;

  @override
  void initState() {
    super.initState();
    final sitting = widget.sitting;
    _titleCtrl = TextEditingController(text: sitting.title);
    _sectionCtrl = TextEditingController(text: sitting.section);
    _themeCtrl = TextEditingController(text: sitting.theme);
    _promptCtrl = TextEditingController(text: sitting.privatePrompt);
    _noteCtrl = TextEditingController(text: sitting.hostNote);
    _scheduledDate = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
    _scheduledTime = widget.initialTime;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _sectionCtrl.dispose();
    _themeCtrl.dispose();
    _promptCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  String _dateLabel(DateTime date) {
    final k = KemeticMath.fromGregorian(date);
    final month = getMonthById(k.kMonth).displayFull;
    final gregorian =
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.year}';
    return '$month ${k.kDay} · $gregorian';
  }

  String _timeLabel(TimeOfDay time) {
    return MaterialLocalizations.of(context).formatTimeOfDay(time);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _scheduledDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _scheduledTime,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _scheduledTime = picked;
    });
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF9C9086)),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(
          color: widget.accentColor.withValues(alpha: 0.28),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: widget.accentColor),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    Key? key,
  }) {
    return TextField(
      key: key,
      controller: controller,
      maxLines: maxLines,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: maxLines == 1
          ? TextInputAction.next
          : TextInputAction.newline,
      scrollPadding: keyboardManagedTextFieldScrollPadding,
      style: const TextStyle(color: Color(0xFFE8D9C3)),
      decoration: _fieldDecoration(label),
    );
  }

  String _trimmedOrFallback(TextEditingController controller, String fallback) {
    final trimmed = controller.text.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }

  ReadingHouseSitting _draftSitting() {
    final sitting = widget.sitting;
    return sitting
        .copyWith(
          title: _trimmedOrFallback(_titleCtrl, sitting.title),
          section: _trimmedOrFallback(_sectionCtrl, sitting.section),
          theme: _trimmedOrFallback(_themeCtrl, sitting.theme),
          privatePrompt: _trimmedOrFallback(_promptCtrl, sitting.privatePrompt),
          hostNote: _noteCtrl.text.trim(),
          scheduledDate: _scheduledDate,
          flowDay: widget.flowDayForDate(_scheduledDate),
          hour: _scheduledTime.hour,
          minute: _scheduledTime.minute,
        )
        .asHostAuthored();
  }

  void _saveDraft() {
    Navigator.of(context).pop(_draftSitting());
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(left: 18, right: 18, bottom: bottomInset + 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF090907),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: widget.borderColor),
          ),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Edit sitting',
                  style: TextStyle(
                    color: widget.accentColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                _field(
                  'Sitting title',
                  _titleCtrl,
                  key: const ValueKey<String>(
                    'reading_house_sitting_title_field',
                  ),
                ),
                const SizedBox(height: 12),
                _field(
                  'Section',
                  _sectionCtrl,
                  key: const ValueKey<String>(
                    'reading_house_sitting_section_field',
                  ),
                ),
                const SizedBox(height: 12),
                _field(
                  'Theme',
                  _themeCtrl,
                  maxLines: 2,
                  key: const ValueKey<String>(
                    'reading_house_sitting_theme_field',
                  ),
                ),
                const SizedBox(height: 12),
                _field(
                  'Private prompt',
                  _promptCtrl,
                  maxLines: 3,
                  key: const ValueKey<String>(
                    'reading_house_sitting_private_prompt_field',
                  ),
                ),
                const SizedBox(height: 12),
                _field(
                  'Host note',
                  _noteCtrl,
                  maxLines: 2,
                  key: const ValueKey<String>(
                    'reading_house_sitting_host_note_field',
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today),
                      label: Text(_dateLabel(_scheduledDate)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: widget.accentColor,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.schedule),
                      label: Text(_timeLabel(_scheduledTime)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: widget.accentColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saveDraft,
                    icon: const Icon(Icons.check),
                    label: const Text('Save Sitting'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String? _readingHouseFlowNoteToken(String? notes, String prefix) {
  if (notes == null || notes.isEmpty) return null;
  for (final token in notes.split(';')) {
    final trimmed = token.trim();
    if (trimmed.startsWith(prefix)) {
      return trimmed.substring(prefix.length);
    }
  }
  return null;
}

TrackSkyTimeZone? _readingHouseTimeZoneFromKey(String? key) {
  switch (key?.trim().toLowerCase()) {
    case 'pacific':
      return TrackSkyTimeZone.pacific;
    case 'mountain':
      return TrackSkyTimeZone.mountain;
    case 'central':
      return TrackSkyTimeZone.central;
    case 'eastern':
      return TrackSkyTimeZone.eastern;
  }
  return null;
}
