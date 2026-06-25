part of 'calendar_page.dart';

class _ReadingHouseAuthoringPage extends StatefulWidget {
  const _ReadingHouseAuthoringPage({required this.flow, this.onSave});

  final _Flow flow;
  final Future<void> Function(_FlowStudioResult result)? onSave;

  @override
  State<_ReadingHouseAuthoringPage> createState() =>
      _ReadingHouseAuthoringPageState();
}

class _ReadingHouseAuthoringPageState
    extends State<_ReadingHouseAuthoringPage> {
  final UserEventsRepo _eventsRepo = UserEventsRepo(Supabase.instance.client);
  List<ReadingHouseSitting> _sittings =
      readingHouseStarterSittingsForAuthoring();
  ReadingHousePlan _plan = const ReadingHousePlan();
  TrackSkyTimeZone _timezone = detectTrackSkyTimeZone();
  DateTime? _firstStart;
  bool _loading = true;
  bool _saving = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _plan = readingHousePlanFromFlowNotes(widget.flow.notes);
    _timezone =
        _readingHouseTimeZoneFromKey(
          _readingHouseFlowNoteToken(widget.flow.notes, 'reading_house_tz='),
        ) ??
        detectTrackSkyTimeZone();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await _eventsRepo.getEventsForFlow(
        widget.flow.id,
        flowEventsOnly: true,
      );
      final sittings = <ReadingHouseSitting>[];
      for (final row in rows) {
        if (!isReadingHouseFlowReference(
          flowName: widget.flow.name,
          flowNotes: widget.flow.notes,
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
            widget.flow.start ??
            defaultReadingHouseStartDate(_timezone);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  DateTime get _effectiveFirstStart {
    final first = _firstStart ?? widget.flow.start ?? DateTime.now();
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

  Future<void> _editSitting(ReadingHouseSitting sitting) async {
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
    setState(() {
      _sittings = addReadingHouseSitting(_sittings);
    });
  }

  void _deleteSitting(ReadingHouseSitting sitting) {
    if (_sittings.length <= 1) return;
    setState(() {
      _sittings = deleteReadingHouseSitting(_sittings, sitting.eventNumber);
    });
  }

  void _moveSitting(int oldIndex, int newIndex) {
    setState(() {
      _sittings = reorderReadingHouseSitting(_sittings, oldIndex, newIndex);
    });
  }

  Future<void> _save() async {
    if (_saving || _sittings.isEmpty) return;
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
            flowId: widget.flow.id,
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
        id: widget.flow.id,
        calendarId: widget.flow.calendarId,
        name: widget.flow.name,
        color: widget.flow.color,
        active: widget.flow.active,
        isSaved: widget.flow.isSaved,
        savedAt: widget.flow.savedAt,
        rules: <FlowRule>[if (dates.isNotEmpty) _RuleDates(dates: dates)],
        start: orderedDates.isEmpty ? widget.flow.start : orderedDates.first,
        end: orderedDates.isEmpty ? widget.flow.end : orderedDates.last,
        notes: notes,
        shareId: widget.flow.shareId,
        isHidden: widget.flow.isHidden,
        isReminder: widget.flow.isReminder,
        reminderUuid: widget.flow.reminderUuid,
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
                const Text(
                  'Shape the private reading plan. Company surfaces remain future-facing only.',
                  style: TextStyle(
                    color: Color(0xFFB7AAA0),
                    fontSize: 16,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 22),
                for (var i = 0; i < _sittings.length; i++)
                  _sittingTile(_sittings[i], i),
                const SizedBox(height: 8),
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
