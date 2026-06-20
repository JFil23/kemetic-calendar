part of 'calendar_page.dart';

enum _FlowStudioMode { build, compose }

class _FlowStudioTone {
  const _FlowStudioTone({
    required this.exactColor,
    required this.softenedAccent,
    required this.pageGlow,
    required this.fieldBorder,
    required this.selectedPill,
    required this.selectedPillBorder,
    required this.ctaBg,
    required this.ctaBorder,
    required this.ctaText,
  });

  final Color exactColor;
  final Color softenedAccent;
  final Color pageGlow;
  final Color fieldBorder;
  final Color selectedPill;
  final Color selectedPillBorder;
  final Color ctaBg;
  final Color ctaBorder;
  final Color ctaText;

  factory _FlowStudioTone.resolve(Color activeColor) {
    final hsl = HSLColor.fromColor(activeColor);
    final softenedAccent = hsl
        .withSaturation(math.min(hsl.saturation * 0.62, 0.56))
        .withLightness(0.54)
        .toColor();
    const base = Color(0xFF050403);
    return _FlowStudioTone(
      exactColor: activeColor,
      softenedAccent: softenedAccent,
      pageGlow: softenedAccent.withValues(alpha: 0.16),
      fieldBorder: softenedAccent.withValues(alpha: 0.16),
      selectedPill: Color.alphaBlend(
        softenedAccent.withValues(alpha: 0.12),
        base,
      ),
      selectedPillBorder: softenedAccent.withValues(alpha: 0.24),
      ctaBg: Color.alphaBlend(softenedAccent.withValues(alpha: 0.13), base),
      ctaBorder: softenedAccent.withValues(alpha: 0.34),
      ctaText: Color.lerp(softenedAccent, const Color(0xFFE8D6A8), 0.18)!,
    );
  }
}

class _FlowStudioSpectrumPicker extends StatelessWidget {
  const _FlowStudioSpectrumPicker({
    required this.hue,
    required this.selectedColor,
    required this.onHueChanged,
  });

  final double hue;
  final Color selectedColor;
  final ValueChanged<double> onHueChanged;

  static Color _colorFromHue(double hueDegrees) {
    return HSLColor.fromAHSL(1.0, hueDegrees % 360.0, 0.72, 0.48).toColor();
  }

  void _updateHue(Offset localPosition, double width) {
    final t = (localPosition.dx / width).clamp(0.0, 1.0);
    onHueChanged(t * 360.0);
  }

  @override
  Widget build(BuildContext context) {
    const barHeight = 28.0;
    const thumbSize = 34.0;
    const hitHeight = 44.0;
    final gradientColors = <Color>[
      for (final hue in const [
        0.0,
        28.0,
        56.0,
        105.0,
        165.0,
        210.0,
        245.0,
        280.0,
        320.0,
        360.0,
      ])
        _colorFromHue(hue),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(1.0, constraints.maxWidth);
        final left = ((hue % 360.0) / 360.0) * width;
        final minThumbLeft = -thumbSize * 0.16;
        final maxThumbLeft = math.max(minThumbLeft, width - thumbSize * 0.84);
        return Semantics(
          label: 'flow-studio-spectrum',
          slider: true,
          value: hue.round().toString(),
          child: GestureDetector(
            key: const ValueKey('flow-studio-spectrum'),
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => _updateHue(details.localPosition, width),
            onHorizontalDragStart: (details) =>
                _updateHue(details.localPosition, width),
            onHorizontalDragUpdate: (details) =>
                _updateHue(details.localPosition, width),
            child: SizedBox(
              height: hitHeight,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.centerLeft,
                children: [
                  Positioned.fill(
                    top: (hitHeight - barHeight) / 2,
                    bottom: (hitHeight - barHeight) / 2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(25),
                        gradient: LinearGradient(colors: gradientColors),
                        border: Border.all(
                          color: const Color(
                            0xFF4A3312,
                          ).withValues(alpha: 0.45),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x99000000),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(25),
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x22FFFFFF),
                              Color(0x00000000),
                              Color(0x33000000),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: (left - thumbSize / 2).clamp(
                      minThumbLeft,
                      maxThumbLeft,
                    ),
                    child: Container(
                      key: const ValueKey('flow-studio-spectrum-thumb'),
                      width: thumbSize,
                      height: thumbSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFF4EBDD),
                        boxShadow: [
                          BoxShadow(
                            color: selectedColor.withValues(alpha: 0.32),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                          const BoxShadow(
                            color: Color(0xAA000000),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(4),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selectedColor,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FlowStudioPage extends StatefulWidget {
  const _FlowStudioPage({
    required this.existingFlows,
    this.editFlowId,
    this.initialCalendarId,
    this.importData,
    this.onContinuityChanged,
    this.onRouteResult,
    this.onRouteClose,
    this.debugInitialDraftJson,
    this.debugDisableDraftPersistence = false,
    this.debugTimePicker,
  });

  final List<_Flow> existingFlows;
  final int? editFlowId;
  final String? initialCalendarId;
  final ImportFlowData? importData;
  final ValueChanged<Map<String, dynamic>>? onContinuityChanged;
  final Future<void> Function(_FlowStudioResult result)? onRouteResult;
  final FutureOr<void> Function()? onRouteClose;
  final Map<String, dynamic>? debugInitialDraftJson;
  final bool debugDisableDraftPersistence;
  final Future<TimeOfDay?> Function(
    BuildContext context,
    TimeOfDay initialTime,
  )?
  debugTimePicker;

  @override
  State<_FlowStudioPage> createState() => _FlowStudioPageState();
}

@visibleForTesting
Widget debugBuildFlowStudioPageForTest({
  ImportFlowData? importData,
  int? editFlowId,
  Map<String, dynamic>? initialDraftJson,
  bool debugHasExistingFlows = false,
  Future<void> Function(dynamic result)? onRouteResult,
  Future<TimeOfDay?> Function(BuildContext context, TimeOfDay initialTime)?
  debugTimePicker,
}) {
  return _FlowStudioPage(
    existingFlows: debugHasExistingFlows
        ? <_Flow>[
            _Flow(
              id: 1,
              name: 'Existing flow',
              color: _gold,
              active: true,
              rules: const <FlowRule>[],
            ),
          ]
        : const <_Flow>[],
    editFlowId: editFlowId,
    importData: importData,
    onRouteResult: onRouteResult == null
        ? null
        : (result) => onRouteResult(result),
    debugInitialDraftJson: initialDraftJson,
    debugDisableDraftPersistence: true,
    debugTimePicker: debugTimePicker,
  );
}

class _FlowStudioPageState extends State<_FlowStudioPage>
    with WidgetsBindingObserver {
  static _FlowStudioDraft? _sessionDraft;
  bool _suppressDraftSave = false;
  bool _nameControllerReady = false;
  bool _draftListenersInstalled = false;
  Timer? _draftPersistDebounce;
  _Flow? _editing;

  // basic
  late final TextEditingController _nameCtrl;
  bool _active = true;

  // color + mode
  int _selectedColorIndex = 0;
  _FlowStudioMode _studioMode = _FlowStudioMode.build;
  double _buildHue = HSLColor.fromColor(_flowPalette[0]).hue;
  Color? _buildExactColorBeforeDrag = _flowPalette[0];
  bool _buildColorWasDragged = false;
  double? _composeHue;
  Color? _composeExactColorBeforeDrag;
  bool _composeColorWasDragged = false;
  bool _useKemetic = false; // false = Gregorian, true = Kemetic

  final TextEditingController _composePromptCtrl = TextEditingController();
  bool _composeUseKemetic = false;
  DateTime? _composeStartDate, _composeEndDate;
  bool _composeManualDateRangeEdited = false;
  bool _composeInitialized = false;
  bool _composeGenerating = false;
  String? _composeError;
  AIFlowGenerationService? _composeAiService;

  // date range (Gregorian local, date-only)
  DateTime? _startDate, _endDate;
  bool _dateRangeEditedInCurrentEditor = false;
  bool get _hasFullRange => _startDate != null && _endDate != null;

  // Readiness gate: only allow sync when the editor's state is fully initialized.
  bool _syncReady = false;

  // Stable key for draft storage; active editor groups remain the source of truth.
  static String dayKey(int ky, int km, int kd) => '$ky-$km-$kd';

  // "same for all" selections
  final Set<int> _selectedDecanDays = <int>{}; // 1..10
  final Set<int> _selectedWeekdays = <int>{}; // 1..7 (Mon..Sun)

  // per-period mode
  bool _splitByPeriod = false; // toggle to show rows per decan/week

  // AI mode flag
  bool _isAIGeneratedFlow = false;

  // Loading flag for async flow loading
  bool _isLoadingFlow = false;
  bool _closeInFlight = false;

  // cached spans + per-period selections
  List<_KemeticDecanSpan> _kemeticSpans = const [];
  List<_WeekSpan> _weekSpans = const [];
  final Map<String, Set<int>> _perDecanSel =
      {}; // key: "ky-km-di", values: {1..10}
  final Map<String, Set<int>> _perWeekSel =
      {}; // key: monday ISO "yyyy-mm-dd", values: {1..7}

  // editors
  final Map<String, List<_NoteDraft>> _draftsByDay =
      {}; // key: "ky-km-kd" (customize mode) - supports multiple notes per day
  final Map<String, _NoteDraft> _draftsByPattern =
      {}; // key: "DD-n" or "WD-wd" (repeat mode)
  final GlobalKey _editorsAnchorKey = GlobalKey();
  int _flowAlertMinutesBefore = _alertNoneMinutes;
  bool _flowAlertMixed = false;
  String? _selectedCalendarId;

  // analytics
  int _originalEventCount = 0; // Store count of AI-generated events

  CalendarPageState? get _calendarPageState =>
      CalendarPage.globalKey.currentState;

  bool get _isItineraryImport =>
      widget.importData?.aiMetadata?['prompt_type'] == 'itinerarySchedule';

  Future<void> _ensureCalendarChoicesLoaded() async {
    final pageState = _calendarPageState;
    if (pageState == null || pageState._calendarStateLoaded) return;
    try {
      await pageState._loadCalendarState();
    } catch (e) {
      if (kDebugMode) {
        _calendarDebugPrint('[FlowStudio] calendar choices load failed: $e');
      }
    }
  }

  List<SharedCalendarSummary> get _editableCalendars {
    final pageState = _calendarPageState;
    if (pageState == null) return const <SharedCalendarSummary>[];
    final currentCalendarId = _selectedCalendarId ?? _editing?.calendarId;
    final calendars = pageState._calendarSummariesById.values
        .where(
          (calendar) => calendar.canEdit || currentCalendarId == calendar.id,
        )
        .toList(growable: false);
    calendars.sort((a, b) {
      if (a.isPersonal && !b.isPersonal) return -1;
      if (!a.isPersonal && b.isPersonal) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return calendars;
  }

  String? _defaultCalendarId() {
    final routeCalendarId = _routeInitialCalendarId();
    if (routeCalendarId != null) return routeCalendarId;
    final pageState = _calendarPageState;
    final personalCalendarId = pageState?._personalCalendarId;
    if (personalCalendarId != null && personalCalendarId.isNotEmpty) {
      return personalCalendarId;
    }
    final calendars = _editableCalendars;
    if (calendars.isNotEmpty) {
      return calendars.first.id;
    }
    return null;
  }

  String? _routeInitialCalendarId() {
    final trimmed = widget.initialCalendarId?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    if (!_canEditCalendar(trimmed)) return null;
    return trimmed;
  }

  String _calendarLabelFor(String? calendarId) {
    final trimmed = calendarId?.trim();
    if (trimmed == null || trimmed.isEmpty) return 'My Calendar';
    final summary = _calendarPageState?._calendarSummariesById[trimmed];
    final name = summary?.name.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'My Calendar';
  }

  bool _canEditCalendar(String? calendarId) {
    final trimmed = calendarId?.trim();
    if (trimmed == null || trimmed.isEmpty) return true;
    final summary = _calendarPageState?._calendarSummariesById[trimmed];
    return summary?.canEdit ?? true;
  }

  // ---------- tiny utilities (local to this page) ----------

  static DateTime _dateOnly(DateTime d) => DateUtils.dateOnly(d);

  static Color _flowStudioColorFromHue(double hueDegrees) {
    return HSLColor.fromAHSL(1.0, hueDegrees % 360.0, 0.72, 0.48).toColor();
  }

  static String _flowStudioHex(Color color) {
    final rgb = color.toARGB32() & 0x00FFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0')}';
  }

  static String _flowStudioColorNameForHue(double hue) {
    final normalized = hue % 360.0;
    if (normalized < 12 || normalized >= 345) return 'CRIMSON';
    if (normalized < 28) return 'VERMILION';
    if (normalized < 45) return 'EMBER';
    if (normalized < 62) return 'AMBER';
    if (normalized < 82) return 'GOLD';
    if (normalized < 115) return 'GREEN';
    if (normalized < 150) return 'JADE';
    if (normalized < 180) return 'TEAL';
    if (normalized < 205) return 'CYAN';
    if (normalized < 230) return 'SKY';
    if (normalized < 255) return 'INDIGO';
    if (normalized < 285) return 'VIOLET';
    if (normalized < 320) return 'MAGENTA';
    return 'ROSE';
  }

  static double _hueForColor(Color color) => HSLColor.fromColor(color).hue;

  static int _nearestFlowPaletteIndex(Color color) {
    final target = color.toARGB32() & 0x00FFFFFF;
    var bestIndex = 0;
    var bestDistance = double.infinity;
    for (var i = 0; i < _flowPalette.length; i++) {
      final current = _flowPalette[i].toARGB32() & 0x00FFFFFF;
      final tr = (target >> 16) & 0xFF;
      final tg = (target >> 8) & 0xFF;
      final tb = target & 0xFF;
      final cr = (current >> 16) & 0xFF;
      final cg = (current >> 8) & 0xFF;
      final cb = current & 0xFF;
      final distance =
          math.pow(tr - cr, 2) + math.pow(tg - cg, 2) + math.pow(tb - cb, 2);
      if (distance < bestDistance) {
        bestDistance = distance.toDouble();
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  Color get _buildColor {
    if (!_buildColorWasDragged && _buildExactColorBeforeDrag != null) {
      return _buildExactColorBeforeDrag!;
    }
    return _flowStudioColorFromHue(_buildHue);
  }

  Color get _composeColor {
    if (!_composeColorWasDragged && _composeExactColorBeforeDrag != null) {
      return _composeExactColorBeforeDrag!;
    }
    return _flowStudioColorFromHue(_composeHue ?? _buildHue);
  }

  Color get _activeStudioColor =>
      _studioMode == _FlowStudioMode.build ? _buildColor : _composeColor;

  double get _activeStudioHue => _studioMode == _FlowStudioMode.build
      ? _buildHue
      : (_composeHue ?? _buildHue);

  void _setBuildExactColor(Color color) {
    _buildHue = _hueForColor(color);
    _buildExactColorBeforeDrag = color;
    _buildColorWasDragged = false;
    _selectedColorIndex = _nearestFlowPaletteIndex(color);
  }

  void _setComposeExactColor(Color color) {
    _composeHue = _hueForColor(color);
    _composeExactColorBeforeDrag = color;
    _composeColorWasDragged = false;
  }

  void _setActiveStudioHue(double hue) {
    setState(() {
      if (_studioMode == _FlowStudioMode.build) {
        _buildHue = hue;
        _buildColorWasDragged = true;
        _buildExactColorBeforeDrag = null;
        _selectedColorIndex = _nearestFlowPaletteIndex(_buildColor);
      } else {
        _composeHue = hue;
        _composeColorWasDragged = true;
        _composeExactColorBeforeDrag = null;
      }
    });
    _schedulePersistentDraftSave();
  }

  void _ensureComposeInitialized() {
    if (_composeInitialized) return;
    _composeInitialized = true;
    _composeUseKemetic = _useKemetic;
    _composeStartDate = _startDate;
    _composeEndDate = _endDate;
    _composeManualDateRangeEdited = _hasFullRange;
    _setComposeExactColor(_buildColor);
  }

  void _setStudioMode(_FlowStudioMode mode) {
    setState(() {
      if (mode == _FlowStudioMode.compose) {
        _ensureComposeInitialized();
      }
      _studioMode = mode;
    });
    _markFlowEditorVisible();
    _schedulePersistentDraftSave();
  }

  String _composePromptTitleFallback() {
    final words = _composePromptCtrl.text
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(6)
        .toList(growable: false);
    if (words.isEmpty) return '';
    final title = words
        .map((word) {
          if (word.length == 1) return word.toUpperCase();
          return '${word[0].toUpperCase()}${word.substring(1)}';
        })
        .join(' ');
    return title.length <= 48 ? title : title.substring(0, 48).trimRight();
  }

  void _switchComposeToManualBuild() {
    final range = _composeEffectiveDateRange();
    setState(() {
      _studioMode = _FlowStudioMode.build;
      _composeGenerating = false;
      _composeError = null;
      _setBuildExactColor(_composeColor);
      _useKemetic = _composeUseKemetic;
      _startDate = range.startDate;
      _endDate = range.endDate;
      _dateRangeEditedInCurrentEditor = true;
      final fallbackTitle = _composePromptTitleFallback();
      if (_nameCtrl.text.trim().isEmpty && fallbackTitle.isNotEmpty) {
        _nameCtrl.text = fallbackTitle;
      }
    });
    _applySelectionToDrafts();
    _markFlowEditorVisible();
    _schedulePersistentDraftSave();
  }

  int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;
  TimeOfDay _addMinutes(TimeOfDay t, int delta) {
    final m = (_toMinutes(t) + delta) % (24 * 60);
    return TimeOfDay(hour: m ~/ 60, minute: m % 60);
  }

  String _fmtGregorian(DateTime? d) => d == null
      ? '--'
      : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _gregYearLabelFor(int kYear, int kMonth) {
    final lastDay = (kMonth == 13)
        ? (KemeticMath.isLeapKemeticYear(kYear) ? 6 : 5)
        : 30;
    final yStart = KemeticMath.toGregorian(kYear, kMonth, 1).year;
    final yEnd = KemeticMath.toGregorian(kYear, kMonth, lastDay).year;
    return (yStart == yEnd) ? '$yStart' : '$yStart/$yEnd';
  }

  String _fmtKemetic(DateTime? g) {
    if (g == null) return '--';
    final k = KemeticMath.fromGregorian(g);
    final month = getMonthById(k.kMonth).displayFull;
    final y = _gregYearLabelFor(k.kYear, k.kMonth);
    return '$month ${k.kDay} • $y';
  }

  Iterable<_NoteDraft> _allDrafts() sync* {
    for (final dayList in _draftsByDay.values) {
      for (final draft in dayList) {
        yield draft;
      }
    }
    yield* _draftsByPattern.values;
  }

  _NoteDraft _newDraftUsingFlowAlertDefault() {
    final draft = _NoteDraft(onChanged: _schedulePersistentDraftSave);
    draft.alertMinutesBefore = _flowAlertMinutesBefore;
    draft.usesFlowAlertDefault = true;
    return draft;
  }

  int _effectiveDraftAlertMinutes(_NoteDraft draft) {
    return draft.usesFlowAlertDefault
        ? _flowAlertMinutesBefore
        : draft.alertMinutesBefore;
  }

  void _refreshFlowAlertMixedState() {
    final drafts = _allDrafts().toList();
    if (drafts.isEmpty) {
      _flowAlertMixed = false;
      return;
    }
    _flowAlertMixed = drafts.any(
      (draft) => _effectiveDraftAlertMinutes(draft) != _flowAlertMinutesBefore,
    );
  }

  void _initializeFlowAlertStateFromDrafts() {
    final drafts = _allDrafts().toList();
    if (drafts.isEmpty) {
      _flowAlertMinutesBefore = _alertNoneMinutes;
      _flowAlertMixed = false;
      return;
    }

    final alertValues = drafts.map((draft) => draft.alertMinutesBefore).toSet();
    if (alertValues.length == 1) {
      _flowAlertMinutesBefore = alertValues.first;
      _flowAlertMixed = false;
      for (final draft in drafts) {
        draft.usesFlowAlertDefault = true;
        draft.alertMinutesBefore = _flowAlertMinutesBefore;
      }
      return;
    }

    _flowAlertMinutesBefore = drafts.first.alertMinutesBefore;
    _flowAlertMixed = true;
    for (final draft in drafts) {
      draft.usesFlowAlertDefault = false;
    }
  }

  int _daysInGregorianMonth(int year, int month) {
    final leap = (year % 4 == 0) && ((year % 100 != 0) || (year % 400 == 0));
    switch (month) {
      case 1:
        return 31;
      case 2:
        return leap ? 29 : 28;
      case 3:
        return 31;
      case 4:
        return 30;
      case 5:
        return 31;
      case 6:
        return 30;
      case 7:
        return 31;
      case 8:
        return 31;
      case 9:
        return 30;
      case 10:
        return 31;
      case 11:
        return 30;
      case 12:
        return 31;
      default:
        return 30;
    }
  }

  static DateTime _mondayOf(DateTime d) {
    final back = d.weekday - 1; // Mon=1..Sun=7
    return DateUtils.dateOnly(d.subtract(Duration(days: back)));
  }

  static String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  _FlowStudioDraft? _captureDraft() {
    final hasContent =
        _nameCtrl.text.trim().isNotEmpty ||
        _overviewCtrl.text.trim().isNotEmpty ||
        _composePromptCtrl.text.trim().isNotEmpty ||
        _studioMode != _FlowStudioMode.build ||
        _buildColorWasDragged ||
        _composeInitialized ||
        _draftsByDay.isNotEmpty ||
        _draftsByPattern.isNotEmpty ||
        _startDate != null ||
        _endDate != null;

    if (!hasContent) return null;

    Map<String, List<_DraftNoteData>> cloneDraftsByDay = {};
    _draftsByDay.forEach((k, list) {
      cloneDraftsByDay[k] = list.map(_DraftNoteData.fromDraft).toList();
    });

    final cloneDraftsByPattern = _draftsByPattern.map(
      (k, v) => MapEntry(k, _DraftNoteData.fromDraft(v)),
    );

    return _FlowStudioDraft(
      editingFlowId: _editing?.id,
      editingIsHidden: _editing?.isHidden ?? false,
      calendarId: _selectedCalendarId ?? _editing?.calendarId,
      name: _nameCtrl.text,
      active: _active,
      selectedColorIndex: _selectedColorIndex,
      studioMode: _studioMode.name,
      buildHue: _buildHue,
      buildColorArgb: _buildColor.toARGB32(),
      buildColorWasDragged: _buildColorWasDragged,
      composeHue: _composeHue,
      composeColorArgb: _composeInitialized ? _composeColor.toARGB32() : null,
      composeColorWasDragged: _composeColorWasDragged,
      composePrompt: _composePromptCtrl.text,
      composeUseKemetic: _composeUseKemetic,
      composeStartDate: _composeStartDate,
      composeEndDate: _composeEndDate,
      composeManualDateRangeEdited: _composeManualDateRangeEdited,
      useKemetic: _useKemetic,
      startDate: _startDate,
      endDate: _endDate,
      splitByPeriod: _splitByPeriod,
      selectedDecanDays: Set<int>.from(_selectedDecanDays),
      selectedWeekdays: Set<int>.from(_selectedWeekdays),
      perDecanSel: _perDecanSel.map((k, v) => MapEntry(k, Set<int>.from(v))),
      perWeekSel: _perWeekSel.map((k, v) => MapEntry(k, Set<int>.from(v))),
      draftsByDay: cloneDraftsByDay,
      draftsByPattern: cloneDraftsByPattern,
      overview: _overviewCtrl.text,
      isAIGeneratedFlow: _isAIGeneratedFlow,
      flowAlertMinutesBefore: _flowAlertMinutesBefore,
      flowAlertMixed: _flowAlertMixed,
    );
  }

  void _restoreDraft(_FlowStudioDraft draft) {
    setState(() {
      // Recreate minimal editing stub if we need to preserve the ID/hidden status
      if (draft.editingFlowId != null) {
        final colorIdx = draft.selectedColorIndex.clamp(
          0,
          _flowPalette.length - 1,
        );
        _editing = _Flow(
          id: draft.editingFlowId!,
          calendarId: draft.calendarId,
          name: draft.name.isEmpty ? '' : draft.name,
          color: _flowPalette[colorIdx],
          active: draft.active,
          rules: const [],
          start: draft.startDate,
          end: draft.endDate,
          notes: '',
          isHidden: draft.editingIsHidden,
          shareId: null,
        );
      } else {
        _editing = null;
      }

      _selectedCalendarId = draft.calendarId;

      _nameCtrl.text = draft.name;
      _active = draft.active;
      _selectedColorIndex = draft.selectedColorIndex.clamp(
        0,
        _flowPalette.length - 1,
      );
      final legacyColor = _flowPalette[_selectedColorIndex];
      if (draft.buildColorArgb != null) {
        final color = Color(draft.buildColorArgb!);
        _buildHue = draft.buildHue ?? _hueForColor(color);
        _buildColorWasDragged = draft.buildColorWasDragged;
        _buildExactColorBeforeDrag = draft.buildColorWasDragged ? null : color;
      } else if (draft.buildHue != null) {
        _buildHue = draft.buildHue!;
        _buildColorWasDragged = true;
        _buildExactColorBeforeDrag = null;
      } else {
        _setBuildExactColor(legacyColor);
      }
      _composePromptCtrl.text = draft.composePrompt;
      _composeUseKemetic = draft.composeUseKemetic;
      _composeStartDate = draft.composeStartDate;
      _composeEndDate = draft.composeEndDate;
      _composeManualDateRangeEdited = draft.composeManualDateRangeEdited;
      _composeInitialized =
          draft.composeHue != null ||
          draft.composeColorArgb != null ||
          draft.composePrompt.trim().isNotEmpty ||
          draft.studioMode == _FlowStudioMode.compose.name;
      if (draft.composeColorArgb != null) {
        final color = Color(draft.composeColorArgb!);
        _composeHue = draft.composeHue ?? _hueForColor(color);
        _composeColorWasDragged = draft.composeColorWasDragged;
        _composeExactColorBeforeDrag = draft.composeColorWasDragged
            ? null
            : color;
      } else {
        _composeHue = draft.composeHue;
        _composeColorWasDragged = draft.composeHue != null;
        _composeExactColorBeforeDrag = null;
      }
      _studioMode = draft.studioMode == _FlowStudioMode.compose.name
          ? _FlowStudioMode.compose
          : _FlowStudioMode.build;
      _useKemetic = draft.useKemetic;
      _startDate = draft.startDate;
      _endDate = draft.endDate;
      _dateRangeEditedInCurrentEditor = draft.editingFlowId != null;
      _splitByPeriod = draft.splitByPeriod;
      _selectedDecanDays
        ..clear()
        ..addAll(draft.selectedDecanDays);
      _selectedWeekdays
        ..clear()
        ..addAll(draft.selectedWeekdays);
      _perDecanSel
        ..clear()
        ..addAll(
          draft.perDecanSel.map((k, v) => MapEntry(k, Set<int>.from(v))),
        );
      _perWeekSel
        ..clear()
        ..addAll(draft.perWeekSel.map((k, v) => MapEntry(k, Set<int>.from(v))));

      // Rebuild drafts
      for (final list in _draftsByDay.values) {
        for (final d in list) {
          d.dispose();
        }
      }
      for (final d in _draftsByPattern.values) {
        d.dispose();
      }
      _draftsByDay
        ..clear()
        ..addAll(
          draft.draftsByDay.map(
            (k, list) => MapEntry(
              k,
              list
                  .map(
                    (n) => n.toDraft(onChanged: _schedulePersistentDraftSave),
                  )
                  .toList(),
            ),
          ),
        );
      _draftsByPattern
        ..clear()
        ..addAll(
          draft.draftsByPattern.map(
            (k, n) =>
                MapEntry(k, n.toDraft(onChanged: _schedulePersistentDraftSave)),
          ),
        );

      _overviewCtrl.text = draft.overview;
      _isAIGeneratedFlow = draft.isAIGeneratedFlow;
      _flowAlertMinutesBefore = draft.flowAlertMinutesBefore;
      _flowAlertMixed = draft.flowAlertMixed;

      _syncReady = true;
      _rebuildSpans();
    });
  }

  void _clearSessionDraft({bool clearPersistent = true}) {
    _sessionDraft = null;
    if (clearPersistent) {
      unawaited(
        AppRestorationService.instance.saveEditorState(
          _kFlowStudioDraftEditorKey,
          null,
        ),
      );
    }
  }

  void _markNameControllerReady() {
    _nameControllerReady = true;
    _installDraftListeners();
  }

  void _setImportNameControllerText(String name) {
    if (_nameControllerReady) {
      _nameCtrl.text = name;
      return;
    }
    _nameCtrl = TextEditingController(text: name);
    _markNameControllerReady();
  }

  void _installDraftListeners() {
    if (!_nameControllerReady || _draftListenersInstalled) return;
    _draftListenersInstalled = true;
    _nameCtrl.addListener(_schedulePersistentDraftSave);
    _overviewCtrl.addListener(_schedulePersistentDraftSave);
    _composePromptCtrl.addListener(_schedulePersistentDraftSave);
  }

  void _markFlowEditorVisible() {
    final state = <String, dynamic>{
      'mode': _kFlowStudioModeEditor,
      if (widget.editFlowId != null) 'editFlowId': widget.editFlowId,
      'studioMode': _studioMode.name,
    };
    final onContinuityChanged = widget.onContinuityChanged;
    if (onContinuityChanged != null) {
      onContinuityChanged(state);
      return;
    }
    final pageState = CalendarPage.globalKey.currentState;
    if (pageState == null) return;
    unawaited(
      pageState._saveCalendarOverlayState(
        _kCalendarOverlayKindFlowStudio,
        state,
      ),
    );
  }

  void _schedulePersistentDraftSave() {
    if (widget.debugDisableDraftPersistence ||
        _suppressDraftSave ||
        !_nameControllerReady) {
      return;
    }
    _draftPersistDebounce?.cancel();
    _draftPersistDebounce = Timer(const Duration(milliseconds: 500), () {
      unawaited(_persistDraftNow(reason: 'debounced'));
    });
  }

  Future<void> _persistDraftNow({required String reason}) async {
    if (widget.debugDisableDraftPersistence ||
        _suppressDraftSave ||
        !_nameControllerReady) {
      return;
    }
    final draft = _captureDraft();
    if (draft == null) {
      await AppRestorationService.instance.saveEditorState(
        _kFlowStudioDraftEditorKey,
        null,
      );
      return;
    }
    await AppRestorationService.instance
        .saveEditorState(_kFlowStudioDraftEditorKey, <String, dynamic>{
          ...draft.toJson(),
          'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
          'reason': reason,
        });
  }

  Future<void> _restorePersistentDraftIfAny({int? expectedEditFlowId}) async {
    final raw = await AppRestorationService.instance.readEditorState(
      _kFlowStudioDraftEditorKey,
    );
    final draft = _FlowStudioDraft.fromJson(raw);
    if (!mounted || draft == null) return;
    if (expectedEditFlowId != null &&
        draft.editingFlowId != expectedEditFlowId) {
      return;
    }
    _restoreDraft(draft);
    _schedulePersistentDraftSave();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        unawaited(_persistDraftNow(reason: 'lifecycle:${state.name}'));
        break;
      case AppLifecycleState.resumed:
        break;
    }
  }

  static const _wdLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  /// Build editor groups:
  /// - per-day groups in customize mode
  /// - pattern groups (weekday/decan-day) in repeat mode
  List<_EditorGroup> _buildEditorGroups() {
    final selected = _computeSelectedDays();
    if (selected.isEmpty) return const [];

    if (_splitByPeriod) {
      // One editor per concrete day.
      return [
        for (final d in selected)
          _EditorGroup(
            key: d.key,
            isPattern: false,
            header:
                '${getMonthById(d.km).displayFull} ${d.kd}  •  ${_fmtGregorian(d.g)}',
            days: [d],
          ),
      ];
    }

    // Repeat mode: pattern editors.
    if (_useKemetic) {
      // group by decan-day number 1..10
      final by = <int, List<_SelectedDay>>{};
      for (final d in selected) {
        final n = ((d.kd - 1) % 10) + 1;
        (by[n] ??= <_SelectedDay>[]).add(d);
      }
      final nums = _selectedDecanDays.toList()..sort();
      return [
        for (final n in nums)
          if (by[n]?.isNotEmpty ?? false)
            _EditorGroup(
              key: 'DD-$n',
              isPattern: true,
              header: 'Decan day $n • ${by[n]!.length} matches',
              days: by[n]!,
            ),
      ];
    } else {
      // group by weekday 1..7
      final by = <int, List<_SelectedDay>>{};
      for (final d in selected) {
        (by[d.g.weekday] ??= <_SelectedDay>[]).add(d);
      }
      final wds = _selectedWeekdays.toList()..sort();
      return [
        for (final wd in wds)
          if (by[wd]?.isNotEmpty ?? false)
            _EditorGroup(
              key: 'WD-$wd',
              isPattern: true,
              header: '${_wdLabels[wd - 1]} • ${by[wd]!.length} matches',
              days: by[wd]!,
            ),
      ];
    }
  }

  List<_SelectedDay> _computeSelectedDays() {
    final out = <_SelectedDay>[];
    if (!_hasFullRange) return out;

    bool inside(DateTime d) =>
        !d.isBefore(_startDate!) && !d.isAfter(_endDate!);

    if (_splitByPeriod) {
      if (_useKemetic) {
        for (final s in _kemeticSpans) {
          final sel = _perDecanSel[s.key] ?? const <int>{};
          for (final n in sel) {
            final kd = s.di * 10 + n; // 1..30
            final g = KemeticMath.toGregorian(s.ky, s.km, kd);
            if (!inside(g)) continue;
            final key = dayKey(s.ky, s.km, kd);
            out.add(_SelectedDay(key, s.ky, s.km, kd, g));
          }
        }
      } else {
        for (final w in _weekSpans) {
          final sel = _perWeekSel[w.key] ?? const <int>{};
          for (final wd in sel) {
            final g = w.monday.add(Duration(days: wd - 1));
            if (!inside(g)) continue;
            final k = KemeticMath.fromGregorian(g);
            final key = dayKey(k.kYear, k.kMonth, k.kDay);
            out.add(_SelectedDay(key, k.kYear, k.kMonth, k.kDay, g));
          }
        }
      }
    } else {
      if (_useKemetic) {
        for (
          DateTime d = _startDate!;
          !d.isAfter(_endDate!);
          d = d.add(const Duration(days: 1))
        ) {
          final k = KemeticMath.fromGregorian(d);
          if (k.kMonth == 13) continue;
          final dayInDecan = ((k.kDay - 1) % 10) + 1;
          if (_selectedDecanDays.contains(dayInDecan)) {
            final key = dayKey(k.kYear, k.kMonth, k.kDay);
            out.add(_SelectedDay(key, k.kYear, k.kMonth, k.kDay, d));
          }
        }
      } else {
        for (
          DateTime d = _startDate!;
          !d.isAfter(_endDate!);
          d = d.add(const Duration(days: 1))
        ) {
          if (_selectedWeekdays.contains(d.weekday)) {
            final k = KemeticMath.fromGregorian(d);
            final key = dayKey(k.kYear, k.kMonth, k.kDay);
            out.add(_SelectedDay(key, k.kYear, k.kMonth, k.kDay, d));
          }
        }
      }
    }

    out.sort((a, b) => a.g.compareTo(b.g));
    return out;
  }

  bool _draftHasUserContent(_NoteDraft draft) {
    return draft.titleCtrl.text.trim().isNotEmpty ||
        draft.locationCtrl.text.trim().isNotEmpty ||
        draft.detailCtrl.text.trim().isNotEmpty ||
        draft.category != null ||
        draft.actionId != null ||
        draft.behaviorPayload != null;
  }

  bool _draftListHasUserContent(List<_NoteDraft>? drafts) {
    if (drafts == null) return false;
    return drafts.any(_draftHasUserContent);
  }

  void _disposeDraftList(List<_NoteDraft>? drafts) {
    if (drafts == null) return;
    for (final draft in drafts) {
      draft.dispose();
    }
  }

  // Keep drafts in sync with the active groups.
  void _syncDraftsWithSelection() {
    // Hard gate: never sync while not ready.
    if (!_syncReady) return;

    final groups = _buildEditorGroups();

    // Day-draft syncing (customize mode).
    final wantDayKeys = {
      for (final g in groups.where((g) => !g.isPattern)) g.key,
    };

    if (_hasFullRange) {
      // Active groups decide what renders and saves. Meaningful deselected
      // drafts may stay cached for accidental reselect/system toggles, but
      // empty shells are removed immediately.
      final removeDay = _draftsByDay.keys
          .where((k) => !wantDayKeys.contains(k))
          .toList();

      for (final k in removeDay) {
        final list = _draftsByDay[k];
        if (!_draftListHasUserContent(list)) {
          _disposeDraftList(list);
          _draftsByDay.remove(k);
        }
      }

      // Seed missing wanted keys (one empty draft per day in customize mode).
      for (final k in wantDayKeys) {
        final existing = _draftsByDay[k];
        if (existing == null || existing.isEmpty) {
          if (!_draftsByDay.containsKey(k) ||
              (_draftsByDay[k]?.isEmpty ?? true)) {
            _draftsByDay.putIfAbsent(
              k,
              () => _splitByPeriod
                  ? <_NoteDraft>[_newDraftUsingFlowAlertDefault()]
                  : <_NoteDraft>[],
            );
          }
        }
      }
    }
    // When !_hasFullRange: do not remove/seed; no active groups render.

    // Pattern-draft syncing (repeat mode).
    final wantPatKeys = {
      for (final g in groups.where((g) => g.isPattern)) g.key,
    };

    if (_hasFullRange) {
      final removePat = _draftsByPattern.keys
          .where((k) => !wantPatKeys.contains(k))
          .toList();
      for (final k in removePat) {
        final draft = _draftsByPattern[k];
        if (draft == null || !_draftHasUserContent(draft)) {
          draft?.dispose();
          _draftsByPattern.remove(k);
        }
      }
    }
    for (final k in wantPatKeys) {
      _draftsByPattern.putIfAbsent(k, _newDraftUsingFlowAlertDefault);
    }

    setState(() {}); // Trigger UI update
  }

  // ---------- span builders ----------

  void _rebuildSpans() {
    // normalize range order
    if (_hasFullRange && _endDate!.isBefore(_startDate!)) {
      final t = _startDate;
      _startDate = _endDate;
      _endDate = t;
    }

    if (!_hasFullRange) {
      setState(() {
        _kemeticSpans = const [];
        _weekSpans = const [];
      });
      // IMPORTANT: do NOT call _syncDraftsWithSelection() here
      return;
    }

    // Kemetic decans present in [start..end]
    final kem = <String, _KemeticDecanSpan>{};
    for (
      DateTime d = _startDate!;
      !d.isAfter(_endDate!);
      d = d.add(const Duration(days: 1))
    ) {
      final k = KemeticMath.fromGregorian(d);
      if (k.kMonth == 13) continue; // epagomenal -> no decan
      final di = ((k.kDay - 1) ~/ 10); // 0..2
      final inDec = ((k.kDay - 1) % 10) + 1; // 1..10
      final key = '${k.kYear}-${k.kMonth}-$di';
      kem.putIfAbsent(key, () {
        final monthName = getMonthById(k.kMonth).displayFull;
        final diName =
            (DecanMetadata.decanNames[k.kMonth] ?? const ['A', 'B', 'C'])[di];
        return _KemeticDecanSpan(
          key: key,
          ky: k.kYear,
          km: k.kMonth,
          di: di,
          label: '$monthName • $diName',
          minDay: inDec,
          maxDay: inDec,
          gStart: d,
          gEnd: d,
        );
      });
      final span = kem[key]!;
      if (inDec < span.minDay) span.minDay = inDec;
      if (inDec > span.maxDay) span.maxDay = inDec;
      if (d.isBefore(span.gStart)) span.gStart = d;
      if (d.isAfter(span.gEnd)) span.gEnd = d;
    }

    // Gregorian weeks in [start..end]
    final weeks = <String, _WeekSpan>{};
    for (
      DateTime d = _startDate!;
      !d.isAfter(_endDate!);
      d = d.add(const Duration(days: 1))
    ) {
      final monday = _mondayOf(d);
      final key = _iso(monday);
      weeks.putIfAbsent(
        key,
        () => _WeekSpan(
          key: key,
          monday: monday,
          minWd: d.weekday,
          maxWd: d.weekday,
        ),
      );
      final w = weeks[key]!;
      if (d.weekday < w.minWd) w.minWd = d.weekday;
      if (d.weekday > w.maxWd) w.maxWd = d.weekday;
    }

    // trim selections outside bounds
    for (final s in kem.values) {
      final sel = _perDecanSel[s.key] ?? <int>{};
      sel.removeWhere((n) => n < s.minDay || n > s.maxDay);
      _perDecanSel[s.key] = sel;
    }
    _perDecanSel.removeWhere((k, _) => !kem.containsKey(k));

    for (final w in weeks.values) {
      final sel = _perWeekSel[w.key] ?? <int>{};
      sel.removeWhere((n) => n < w.minWd || n > w.maxWd);
      _perWeekSel[w.key] = sel;
    }
    _perWeekSel.removeWhere((k, _) => !weeks.containsKey(k));

    setState(() {
      _kemeticSpans = kem.values.toList()
        ..sort((a, b) => a.gStart.compareTo(b.gStart));
      _weekSpans = weeks.values.toList()
        ..sort((a, b) => a.monday.compareTo(b.monday));
    });

    // Only sync if we are ready AND we have a full range.
    if (_syncReady && _hasFullRange) {
      _syncDraftsWithSelection();
    }
  }

  /// Centralizes: "rebuild spans then (if ready) sync".
  /// NOTE: _rebuildSpans() already calls _syncDraftsWithSelection()
  /// when _syncReady && _hasFullRange, so we do not call it again here.
  void _applySelectionToDrafts() {
    _rebuildSpans();
  }

  // ---------- pickers ----------

  Future<DateTime?> _pickGregorianDate({DateTime? initial}) async {
    final now = DateTime.now();
    DateTime seed = DateUtils.dateOnly(initial ?? now);

    int y = seed.year;
    int m = seed.month;
    int d = seed.day;

    final int yearStart = now.year - 200;
    final yearCtrl = FixedExtentScrollController(
      initialItem: (y - yearStart).clamp(0, 400),
    );
    final monthCtrl = FixedExtentScrollController(
      initialItem: (m - 1).clamp(0, 11),
    );
    final dayCtrl = FixedExtentScrollController(
      initialItem: (d - 1).clamp(0, 30),
    );

    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        int localY = y, localM = m, localD = d;

        int dayMax() => _daysInGregorianMonth(localY, localM);

        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            final max = dayMax();
            if (localD > max) localD = max;

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // drag handle
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  const GlossyText(
                    text: 'Pick Gregorian date',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    gradient: blueGloss,
                  ),
                  const SizedBox(height: 8),

                  SizedBox(
                    height: 160,
                    child: Row(
                      children: [
                        // Month
                        Expanded(
                          flex: 4,
                          child: CupertinoPicker(
                            scrollController: monthCtrl,
                            itemExtent: 32,
                            looping: true,
                            backgroundColor: const Color(0x00121214),
                            onSelectedItemChanged: (i) {
                              setSheetState(() {
                                localM = (i % 12) + 1;
                                final mx = dayMax();
                                if (localD > mx && dayCtrl.hasClients) {
                                  localD = mx;
                                  WidgetsBinding.instance.addPostFrameCallback(
                                    (_) => dayCtrl.jumpToItem(localD - 1),
                                  );
                                }
                              });
                            },
                            children: List<Widget>.generate(12, (i) {
                              final label = _gregMonthNames[i + 1];
                              return Center(
                                child: GlossyText(
                                  text: label,
                                  style: const TextStyle(fontSize: 14),
                                  gradient: silverGloss,
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Day
                        Expanded(
                          flex: 3,
                          child: CupertinoPicker(
                            scrollController: dayCtrl,
                            itemExtent: 32,
                            looping: true,
                            backgroundColor: const Color(0x00121214),
                            onSelectedItemChanged: (i) {
                              setSheetState(() {
                                final mx = dayMax();
                                localD = (i % mx) + 1;
                              });
                            },
                            children: List<Widget>.generate(dayMax(), (i) {
                              final dd = i + 1;
                              return Center(
                                child: GlossyText(
                                  text: '$dd',
                                  style: const TextStyle(fontSize: 14),
                                  gradient: silverGloss,
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Year
                        Expanded(
                          flex: 4,
                          child: CupertinoPicker(
                            scrollController: yearCtrl,
                            itemExtent: 32,
                            looping: false,
                            backgroundColor: const Color(0x00121214),
                            onSelectedItemChanged: (i) {
                              setSheetState(() {
                                localY = yearStart + i;
                                final mx = dayMax();
                                if (localD > mx && dayCtrl.hasClients) {
                                  localD = mx;
                                  WidgetsBinding.instance.addPostFrameCallback(
                                    (_) => dayCtrl.jumpToItem(localD - 1),
                                  );
                                }
                              });
                            },
                            children: List<Widget>.generate(401, (i) {
                              final yy = yearStart + i;
                              return Center(
                                child: GlossyText(
                                  text: '$yy',
                                  style: const TextStyle(fontSize: 14),
                                  gradient: silverGloss,
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: silver, width: 1.25),
                          ),
                          onPressed: () => Navigator.pop(sheetCtx, null),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _blue,
                            foregroundColor: Colors.black,
                          ),
                          onPressed: () {
                            final out = DateUtils.dateOnly(
                              DateTime(localY, localM, localD),
                            );
                            Navigator.pop(sheetCtx, out);
                          },
                          child: const Text('Done'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<DateTime?> _pickKemeticDate({DateTime? initial}) async {
    final initK = KemeticMath.fromGregorian(initial ?? DateTime.now());
    int ky = initK.kYear, km = initK.kMonth, kd = initK.kDay;

    int maxDayFor(int year, int month) =>
        (month == 13) ? (KemeticMath.isLeapKemeticYear(year) ? 6 : 5) : 30;

    final yearStart = initK.kYear - 200;
    final yearCtrl = FixedExtentScrollController(
      initialItem: (ky - yearStart).clamp(0, 400),
    );
    final monthCtrl = FixedExtentScrollController(
      initialItem: (km - 1).clamp(0, 12),
    );
    final dayCtrl = FixedExtentScrollController(initialItem: (kd - 1));

    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        int localKy = ky, localKm = km, localKd = kd;

        int dayMax() => maxDayFor(localKy, localKm);

        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            if (localKd > dayMax()) localKd = dayMax();

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const GlossyText(
                    text: 'Pick Kemetic date',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    gradient: goldGloss, // <- gold gleam
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 160,
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: CupertinoPicker(
                            scrollController: monthCtrl,
                            itemExtent: 32,
                            looping: true,
                            backgroundColor: const Color(0x00121214),
                            onSelectedItemChanged: (i) {
                              setSheetState(() {
                                localKm = (i % 13) + 1;
                                final max = maxDayFor(localKy, localKm);
                                if (localKd > max) {
                                  localKd = max;
                                  if (dayCtrl.hasClients) {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback(
                                          (_) =>
                                              dayCtrl.jumpToItem(localKd - 1),
                                        );
                                  }
                                }
                              });
                            },
                            children: List<Widget>.generate(13, (i) {
                              final m = i + 1;
                              final label = getMonthById(m).displayFull;
                              return Center(
                                child: GlossyText(
                                  text: label,
                                  style: const TextStyle(fontSize: 14),
                                  gradient: silverGloss,
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 3,
                          child: CupertinoPicker(
                            scrollController: dayCtrl,
                            itemExtent: 32,
                            looping: true,
                            backgroundColor: const Color(0x00121214),
                            onSelectedItemChanged: (i) {
                              setSheetState(() {
                                final max = maxDayFor(localKy, localKm);
                                localKd = (i % max) + 1;
                              });
                            },
                            children: List<Widget>.generate(dayMax(), (i) {
                              final d = i + 1;
                              return Center(
                                child: GlossyText(
                                  text: '$d',
                                  style: const TextStyle(fontSize: 14),
                                  gradient: silverGloss,
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 4,
                          child: CupertinoPicker(
                            scrollController: yearCtrl,
                            itemExtent: 32,
                            looping: false,
                            backgroundColor: const Color(0x00121214),
                            onSelectedItemChanged: (i) {
                              setSheetState(() {
                                localKy = yearStart + i;
                                final max = maxDayFor(localKy, localKm);
                                if (localKd > max) {
                                  localKd = max;
                                  if (dayCtrl.hasClients) {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback(
                                          (_) =>
                                              dayCtrl.jumpToItem(localKd - 1),
                                        );
                                  }
                                }
                              });
                            },
                            children: List<Widget>.generate(401, (i) {
                              final ky = yearStart + i;
                              final label = _gregYearLabelFor(ky, localKm);
                              return Center(
                                child: GlossyText(
                                  text: label,
                                  style: const TextStyle(fontSize: 14),
                                  gradient: silverGloss,
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: silver, width: 1.25),
                          ),
                          onPressed: () => Navigator.pop(sheetCtx, null),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _gold,
                            foregroundColor: Colors
                                .white, // text color pairs with glossy white label
                          ),
                          onPressed: () {
                            final g = KemeticMath.toGregorian(
                              localKy,
                              localKm,
                              localKd,
                            );
                            Navigator.pop(sheetCtx, _dateOnly(g));
                          },
                          child: const GlossyText(
                            text: 'Done',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            gradient: whiteGloss, // subtle sheen on the label
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickRangeStart() async {
    final picked = _useKemetic
        ? await _pickKemeticDate(initial: _startDate)
        : await _pickGregorianDate(initial: _startDate);
    if (picked != null) {
      setState(() {
        _startDate = _dateOnly(picked);
        _dateRangeEditedInCurrentEditor = true;
      });
      _applySelectionToDrafts();
    }
  }

  Future<void> _pickRangeEnd() async {
    final picked = _useKemetic
        ? await _pickKemeticDate(initial: _endDate ?? _startDate)
        : await _pickGregorianDate(initial: _endDate ?? _startDate);
    if (picked != null) {
      setState(() {
        _endDate = _dateOnly(picked);
        _dateRangeEditedInCurrentEditor = true;
      });
      _applySelectionToDrafts();
    }
  }

  bool get _isEditingFlowContext =>
      _editing != null ||
      widget.editFlowId != null ||
      widget.importData != null;

  bool get _shouldSeedAiGenerationModalWithManualRange =>
      _hasFullRange &&
      (_isEditingFlowContext || _dateRangeEditedInCurrentEditor);

  // ---------- Overview support ----------

  final TextEditingController _overviewCtrl = TextEditingController();

  Future<void> _openOverviewEditor() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        final media = MediaQuery.of(sheetCtx);
        final keyboardInset = keyboardInsetOf(sheetCtx);
        final sheetMaxHeight = math.max(
          280.0,
          math.min(
            media.size.height * 0.72,
            media.size.height - keyboardInset - media.padding.top - 12,
          ),
        );
        return AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: keyboardInset),
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: sheetMaxHeight),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // drag handle
                    Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const GlossyText(
                      text: 'Flow overview',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      gradient: silverGloss,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _overviewCtrl,
                      scrollPadding: keyboardManagedTextFieldScrollPadding,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 10,
                      decoration: _darkInput(
                        'Describe this flow',
                        hint:
                            'What is this flow about? Any tips, links, or context?',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(
                                color: silver,
                                width: 1.25,
                              ),
                            ),
                            onPressed: () => Navigator.pop(sheetCtx),
                            child: const Text('Close'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    setState(
      () {},
    ); // refresh anything that reflects overview (none inline yet)
  }

  // ---------- per-day/pattern note editors ----------

  Future<void> _pickStartFor(_NoteDraft draft) async {
    final t = await _showFlowTimePicker(
      draft.start ?? const TimeOfDay(hour: 12, minute: 0),
    );
    if (t == null || !mounted) return;
    setState(() {
      draft.start = t;
      if (draft.end != null) {
        if (_toMinutes(draft.end!) <= _toMinutes(t)) {
          draft.end = _addMinutes(t, 60);
        }
      }
    });
    _schedulePersistentDraftSave();
  }

  Future<void> _pickEndFor(_NoteDraft draft) async {
    final t = await _showFlowTimePicker(
      draft.end ??
          (draft.start != null
              ? _addMinutes(draft.start!, 60)
              : const TimeOfDay(hour: 13, minute: 0)),
    );
    if (t == null || !mounted) return;
    setState(() {
      draft.end = t;
      if (draft.start != null) {
        if (_toMinutes(t) <= _toMinutes(draft.start!)) {
          draft.start = _addMinutes(t, -60);
        }
      }
    });
    _schedulePersistentDraftSave();
  }

  Future<TimeOfDay?> _showFlowTimePicker(TimeOfDay initialTime) {
    final debugPicker = widget.debugTimePicker;
    if (debugPicker != null) {
      return debugPicker(context, initialTime);
    }
    return showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (c, w) => Theme(
        data: Theme.of(c).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _gold,
            surface: _bg,
            onSurface: Colors.white,
          ),
        ),
        child: w!,
      ),
    );
  }

  Widget _timeButton(
    String label,
    TimeOfDay? value,
    VoidCallback onTap,
    bool enabled, {
    Key? key,
  }) {
    final h = value?.hourOfPeriod == 0 ? 12 : (value?.hourOfPeriod ?? 12);
    final m = (value?.minute ?? 0).toString().padLeft(2, '0');
    final ap = (value == null)
        ? ''
        : (value.period == DayPeriod.am ? 'AM' : 'PM');
    final text = value == null ? '--:--' : '$h:$m $ap';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('', style: TextStyle(fontSize: 0)),
        SizedBox(
          height: 40,
          child: OutlinedButton(
            key: key,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: _silver, width: 1),
            ),
            onPressed: enabled ? onTap : null,
            child: Text('$label: $text'),
          ),
        ),
      ],
    );
  }

  Widget _alertPicker(_NoteDraft draft) {
    return InkWell(
      onTap: () async {
        final picked = await _pickAlertMinutes(
          context,
          _effectiveDraftAlertMinutes(draft),
        );
        if (picked != null) {
          setState(() {
            if (picked == _flowAlertMinutesBefore) {
              draft.usesFlowAlertDefault = true;
              draft.alertMinutesBefore = picked;
            } else {
              draft.usesFlowAlertDefault = false;
              draft.alertMinutesBefore = picked;
            }
            _refreshFlowAlertMixedState();
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const GlossyText(
              text: 'Alert',
              style: TextStyle(fontSize: 14),
              gradient: silverGloss,
            ),
            Row(
              children: [
                GlossyText(
                  text: _alertLabelFor(_effectiveDraftAlertMinutes(draft)),
                  gradient: goldGloss,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: Colors.white54,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _flowAlertPicker() {
    return InkWell(
      onTap: () async {
        final picked = await _pickAlertMinutes(
          context,
          _flowAlertMixed ? null : _flowAlertMinutesBefore,
        );
        if (picked == null) return;
        setState(() {
          _flowAlertMinutesBefore = picked;
          _flowAlertMixed = false;
          for (final draft in _allDrafts()) {
            draft.usesFlowAlertDefault = true;
            draft.alertMinutesBefore = picked;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const GlossyText(
              text: 'Alert for all events',
              style: TextStyle(fontSize: 14),
              gradient: silverGloss,
            ),
            Row(
              children: [
                GlossyText(
                  text: _flowAlertMixed
                      ? 'Mixed'
                      : _alertLabelFor(_flowAlertMinutesBefore),
                  gradient: goldGloss,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: Colors.white54,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _notesEditorsPanel() {
    final groups = _buildEditorGroups();
    const fieldScrollPadding = keyboardManagedTextFieldScrollPadding;
    if (groups.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        _flowAlertPicker(),
        const SizedBox(height: 8),
        const GlossyText(
          text: 'Notes for selection',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          gradient: silverGloss,
        ),
        const SizedBox(height: 8),
        ...groups.expand((g) {
          // For customize mode: return multiple cards (one per draft in the list)
          if (!g.isPattern && _draftsByDay[g.key] != null) {
            final drafts = _draftsByDay[g.key]!;
            return drafts.asMap().entries.map((entry) {
              final index = entry.key;
              final draft = entry.value;
              return Padding(
                key: ValueKey('${g.key}-$index'),
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  color: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(color: _cardBorderGold, width: 1.0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GlossyText(
                          text: g.header,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          gradient: silverGloss,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: draft.titleCtrl,
                          scrollPadding: fieldScrollPadding,
                          style: const TextStyle(color: Colors.white),
                          decoration: _darkInput('Title'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: draft.locationCtrl,
                          scrollPadding: fieldScrollPadding,
                          style: const TextStyle(color: Colors.white),
                          decoration: _darkInput(
                            'Location or Video Call',
                            hint: 'e.g., Home • Zoom • https://…',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: draft.detailCtrl,
                          scrollPadding: fieldScrollPadding,
                          style: const TextStyle(color: Colors.white),
                          maxLines: 3,
                          decoration: _darkInput('Details (optional)'),
                        ),
                        const SizedBox(height: 10),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: draft.allDay,
                          onChanged: (v) {
                            setState(() => draft.allDay = v);
                            _schedulePersistentDraftSave();
                          },
                          title: const GlossyText(
                            text: 'All-day',
                            style: TextStyle(fontSize: 14),
                            gradient: silverGloss,
                          ),
                          activeThumbColor: _gold,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: _timeButton(
                                'Starts',
                                draft.start,
                                () => _pickStartFor(draft),
                                !draft.allDay,
                                key: ValueKey<String>(
                                  'flow-studio-note-start-${g.key}-$index',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _timeButton(
                                'Ends',
                                draft.end,
                                () => _pickEndFor(draft),
                                !draft.allDay,
                                key: ValueKey<String>(
                                  'flow-studio-note-end-${g.key}-$index',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _alertPicker(draft),
                      ],
                    ),
                  ),
                ),
              );
            });
          }
          // For pattern mode or empty list: skip
          return [];
        }),
      ],
    );
  }

  // ---------- save/delete ----------

  /// Show AI Flow Generation Modal
  Future<void> _showAIGenerationModal() async {
    final seedManualRange = _shouldSeedAiGenerationModalWithManualRange;
    final seedCurrentStart = seedManualRange || _dateRangeEditedInCurrentEditor;
    final result = await showModalBottomSheet<AIFlowGenerationResponse>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AIFlowGenerationModal(
        initialStartDate: seedCurrentStart ? _startDate : null,
        initialEndDate: seedManualRange ? _endDate : null,
        initialDateRangeIsManual: seedManualRange,
      ),
    );

    if (!mounted || result == null) return;

    _FlowStudioResult? edited;

    // Prefer DB-loaded flow if flowId is present
    if (result.flowId != null) {
      edited = await Navigator.of(context).push<_FlowStudioResult>(
        MaterialPageRoute(
          builder: (_) => _FlowStudioPage(
            existingFlows: widget.existingFlows,
            editFlowId: result.flowId,
          ),
        ),
      );
    } else {
      // Fallback: seed Flow Studio directly from AI response (no DB flowId)
      final baseStart =
          result.requestedStartDate ?? _startDate ?? DateTime.now();
      final importData = _aiImportDataFromResponse(result, baseStart);
      if (importData == null) return;

      edited = await Navigator.of(context).push<_FlowStudioResult>(
        MaterialPageRoute(
          builder: (_) => _FlowStudioPage(
            existingFlows: widget.existingFlows,
            editFlowId: null,
            importData: importData,
          ),
        ),
      );
    }

    if (!mounted || edited == null) return;

    await _finishWithResult(edited);
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Give your flow a name.')));
      return;
    }
    final selectedCalendarId =
        _selectedCalendarId ?? _editing?.calendarId ?? _defaultCalendarId();
    if (!_canEditCalendar(selectedCalendarId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can view this calendar, but you cannot edit it.'),
        ),
      );
      return;
    }

    // require rule choices only if a range is set
    if (_hasFullRange) {
      if (_useKemetic) {
        final ok = _splitByPeriod
            ? _perDecanSel.values.any((s) => s.isNotEmpty)
            : _selectedDecanDays.isNotEmpty;
        if (!ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pick at least one decan day.')),
          );
          return;
        }
      } else {
        final ok = _splitByPeriod
            ? _perWeekSel.values.any((s) => s.isNotEmpty)
            : _selectedWeekdays.isNotEmpty;
        if (!ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pick at least one weekday.')),
          );
          return;
        }
      }
    }

    // normalize
    if (_hasFullRange && _endDate!.isBefore(_startDate!)) {
      final t = _startDate;
      _startDate = _endDate;
      _endDate = t;
    }

    final rules = <FlowRule>[];

    if (_hasFullRange) {
      if (_splitByPeriod) {
        // explicit dates rule
        final out = <DateTime>{};
        if (_useKemetic) {
          for (final s in _kemeticSpans) {
            final set = _perDecanSel[s.key] ?? const <int>{};
            for (final n in set) {
              final kd = s.di * 10 + n;
              final g = KemeticMath.toGregorian(s.ky, s.km, kd);
              final go = _dateOnly(g);
              if (!go.isBefore(_startDate!) && !go.isAfter(_endDate!)) {
                out.add(go);
              }
            }
          }
        } else {
          for (final w in _weekSpans) {
            final set = _perWeekSel[w.key] ?? const <int>{};
            for (final wd in set) {
              final g = _dateOnly(w.monday.add(Duration(days: wd - 1)));
              if (!g.isBefore(_startDate!) && !g.isAfter(_endDate!)) out.add(g);
            }
          }
        }
        if (out.isNotEmpty) rules.add(_RuleDates(dates: out));
      } else {
        // single-row rule
        if (_useKemetic) {
          rules.add(
            _RuleDecan(
              months: _fullRange(1, 12),
              decans: _fullRange(1, 3),
              daysInDecan: _selectedDecanDays,
              allDay: true,
            ),
          );
        } else {
          rules.add(_RuleWeek(weekdays: _selectedWeekdays, allDay: true));
        }
      }
    }

    // collect planned notes
    final groups = _buildEditorGroups();
    final planned = <_PlannedNote>[];

    // attach current flow id to notes created by this save
    final int? flowId = _editing?.id ?? widget.editFlowId;

    final notes = notesEncode(
      kemetic: _useKemetic,
      split: _splitByPeriod,
      overview: _overviewCtrl.text,
    );

    if (_splitByPeriod) {
      // per-day drafts (handle multiple drafts per day)
      for (final g in groups) {
        final d = g.days.first;
        final drafts = _draftsByDay[d.key];
        if (drafts == null || drafts.isEmpty) continue;

        // Loop through all drafts for this day
        for (final draft in drafts) {
          if (draft.titleCtrl.text.trim().isEmpty) continue;

          final noteWithFlowId = draft.toNote(
            flowAlertMinutesBefore: _flowAlertMinutesBefore,
          );
          final linkedNote = _Note(
            title: noteWithFlowId.title,
            detail: noteWithFlowId.detail,
            location: noteWithFlowId.location,
            allDay: noteWithFlowId.allDay,
            start: noteWithFlowId.start,
            end: noteWithFlowId.end,
            flowId: flowId,
            alertOffsetMinutes: noteWithFlowId.alertOffsetMinutes,
            actionId: noteWithFlowId.actionId,
            behaviorPayload: noteWithFlowId.behaviorPayload,
          );

          planned.add(
            _PlannedNote(ky: d.ky, km: d.km, kd: d.kd, note: linkedNote),
          );
        }
      }
    } else {
      // pattern drafts: apply to all concrete matches in the group
      for (final g in groups) {
        final draft = _draftsByPattern[g.key];
        if (draft == null) continue;
        if (draft.titleCtrl.text.trim().isEmpty) continue;

        final noteWithFlowId = draft.toNote(
          flowAlertMinutesBefore: _flowAlertMinutesBefore,
        );
        final linkedNote = _Note(
          title: noteWithFlowId.title,
          detail: noteWithFlowId.detail,
          location: noteWithFlowId.location,
          allDay: noteWithFlowId.allDay,
          start: noteWithFlowId.start,
          end: noteWithFlowId.end,
          flowId: flowId,
          alertOffsetMinutes: noteWithFlowId.alertOffsetMinutes,
          actionId: noteWithFlowId.actionId,
          behaviorPayload: noteWithFlowId.behaviorPayload,
        );

        for (final d in g.days) {
          planned.add(
            _PlannedNote(ky: d.ky, km: d.km, kd: d.kd, note: linkedNote),
          );
        }
      }
    }

    // AFTER building `planned`

    final seen = <String>{};
    planned.retainWhere((p) {
      final key = '${p.ky}-${p.km}-${p.kd}|${p.note.title.trim()}';
      if (seen.contains(key)) return false;
      seen.add(key);
      return true;
    });

    // ✅ For imported flows, clear rules to prevent rule-based rescheduling
    // But keep rules for AI imports (payloadId == 'ai-local') so schedule displays
    final bool isAiImport = widget.importData?.share.payloadId == 'ai-local';
    final bool isImportedFlow = widget.importData != null && !isAiImport;
    final List<FlowRule> rulesToSave = isImportedFlow ? <FlowRule>[] : rules;
    final hasMaterializedSchedule =
        rulesToSave.isNotEmpty || planned.isNotEmpty;
    final hasScheduledOutput =
        _startDate != null ||
        _endDate != null ||
        rulesToSave.isNotEmpty ||
        planned.isNotEmpty;
    final importedWithoutMaterializedSchedule =
        isImportedFlow && !hasMaterializedSchedule;
    final saveAsUnscheduledTemplate =
        importedWithoutMaterializedSchedule ||
        (widget.importData == null &&
            !_isAIGeneratedFlow &&
            !hasScheduledOutput &&
            !(_editing?.isReminder ?? false) &&
            !(_editing?.isHidden ?? false));
    final flowIsSaved =
        (_editing?.isSaved ?? false) || saveAsUnscheduledTemplate;

    final flow = _Flow(
      id: _editing?.id ?? -1,
      calendarId: selectedCalendarId,
      name: name,
      color: _buildColor,
      active: _active,
      isSaved: flowIsSaved,
      savedAt: flowIsSaved ? (_editing?.savedAt ?? DateTime.now()) : null,
      rules: rulesToSave, // ✅ Empty rules for non-AI imports
      start: _startDate,
      end: _endDate,
      notes: notes,
      shareId: widget.importData?.share.shareId,
      isHidden:
          _editing?.isHidden ?? false, // Preserve hidden status if editing
    );

    final originFlowId =
        widget.importData?.originFlowId ??
        int.tryParse(widget.importData?.share.payloadId ?? '');
    final originShareId = widget.importData?.share.shareId;
    final originGenerationId = widget.importData?.generationId;
    final originType =
        widget.importData?.originType ??
        (isAiImport
            ? 'ai'
            : (widget.importData != null ? 'share_import' : null));
    final rootFlowId = widget.importData?.rootFlowId ?? originFlowId;

    // Reset AI mode flag after save - flow is now a normal editable flow
    if (_isAIGeneratedFlow) {
      _isAIGeneratedFlow = false;
    }

    await _finishWithResult(
      _FlowStudioResult(
        savedFlow: flow,
        plannedNotes: planned,
        originType: originType,
        originFlowId: originFlowId,
        originShareId: originShareId,
        originGenerationId: originGenerationId,
        rootFlowId: rootFlowId,
        aiMetadata: widget.importData?.aiMetadata,
      ),
    );
  }

  Future<void> _finishWithResult(_FlowStudioResult result) async {
    final routeResultHandler = widget.onRouteResult;
    if (routeResultHandler != null) {
      try {
        await routeResultHandler(result);
        _clearSessionDraft();
        _suppressDraftSave = true;
      } catch (error, stackTrace) {
        if (kDebugMode) {
          _calendarDebugPrint('[FlowStudio] save failed: $error');
          _calendarDebugPrint('$stackTrace');
        }
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to save flow: $error')));
      }
      return;
    }
    _clearSessionDraft();
    _suppressDraftSave = true;
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(result);
  }

  void _delete() {
    if (_editing == null) return;
    unawaited(_finishWithResult(_FlowStudioResult(deleteFlowId: _editing!.id)));
  }

  // ---------- Flow picker / preview ----------

  Future<void> _openFlowPicker() async {
    if (widget.existingFlows.isEmpty) return;

    final searchCtrl = TextEditingController();
    List<_Flow> filtered = List.of(widget.existingFlows)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        void applyFilter() {
          final q = searchCtrl.text.trim().toLowerCase();
          filtered =
              widget.existingFlows
                  .where((f) => f.name.toLowerCase().contains(q))
                  .toList()
                ..sort(
                  (a, b) =>
                      a.name.toLowerCase().compareTo(b.name.toLowerCase()),
                );
        }

        applyFilter();

        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            final media = MediaQuery.of(sheetCtx);
            final keyboardInset = keyboardInsetOf(sheetCtx);
            final sheetMaxHeight = math.max(
              280.0,
              math.min(
                media.size.height * 0.72,
                media.size.height - keyboardInset - media.padding.top - 12,
              ),
            );
            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: keyboardInset),
              child: SafeArea(
                top: false,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: sheetMaxHeight),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 36,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const GlossyText(
                          text: 'Find / Edit a flow',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          gradient: silverGloss,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: searchCtrl,
                          scrollPadding: keyboardManagedTextFieldScrollPadding,
                          style: const TextStyle(color: Colors.white),
                          decoration: _darkInput(
                            'Search flows',
                            hint: 'Type a name…',
                          ),
                          onChanged: (_) => setSheetState(applyFilter),
                        ),
                        const SizedBox(height: 10),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 360),
                          child: filtered.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24.0),
                                  child: Text(
                                    'No flows match',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, _) => const Divider(
                                    height: 12,
                                    color: Colors.white10,
                                  ),
                                  itemBuilder: (_, i) {
                                    final f = filtered[i];
                                    return ListTile(
                                      dense: true,
                                      onTap: () {
                                        Navigator.pop(sheetCtx);
                                        _showFlowPreview(f);
                                      },
                                      leading: Container(
                                        width: 18,
                                        height: 18,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: _glossFromColor(f.color),
                                        ),
                                      ),
                                      title: Text(
                                        f.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                      subtitle: Text(
                                        [
                                          f.active ? 'Active' : 'Inactive',
                                          if (f.start != null || f.end != null)
                                            '${_fmtGregorian(f.start)} → ${_fmtGregorian(f.end)}',
                                          notesDecode(f.notes).kemetic
                                              ? 'Kemetic'
                                              : 'Gregorian',
                                        ].join(' • '),
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                      trailing: const Icon(
                                        Icons.chevron_right,
                                        color: _silver,
                                      ),
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(
                                    color: silver,
                                    width: 1.25,
                                  ),
                                ),
                                onPressed: () => Navigator.pop(sheetCtx),
                                child: const Text('Close'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    searchCtrl.dispose();
  }

  void _showFlowPreview(_Flow f) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FlowPreviewPage(
          flow: f,
          getDecanLabel: (km, di) =>
              (DecanMetadata.decanNames[km] ?? const ['I', 'II', 'III'])[di],
          fmt: (d) => _fmtGregorian(d),
          onEdit: (flow) {
            _loadFlowForEdit(flow);
            Navigator.of(context).pop();
          },
          onAppendToJournal: null,
          onEndMaatFlow:
              null, // Flow Studio can't end flows (no access to _endFlow)
        ),
      ),
    );
  }

  void _clearEditorForNew() {
    setState(() {
      _editing = null;
      _selectedCalendarId = _defaultCalendarId();
      _nameCtrl.text = '';
      _active = true;
      _studioMode = _FlowStudioMode.build;
      _setBuildExactColor(_flowPalette[0]);
      _composePromptCtrl.clear();
      _composeUseKemetic = false;
      _composeStartDate = null;
      _composeEndDate = null;
      _composeManualDateRangeEdited = false;
      _composeInitialized = false;
      _composeHue = null;
      _composeExactColorBeforeDrag = null;
      _composeColorWasDragged = false;
      _composeGenerating = false;
      _composeError = null;
      _useKemetic = false;
      _startDate = null;
      _endDate = null;
      _dateRangeEditedInCurrentEditor = false;
      _splitByPeriod = false;

      _selectedDecanDays.clear();
      _selectedWeekdays.clear();
      _perDecanSel.clear();
      _perWeekSel.clear();
      _flowAlertMinutesBefore = _alertNoneMinutes;
      _flowAlertMixed = false;

      for (final dayList in _draftsByDay.values) {
        for (final d in dayList) {
          d.dispose();
        }
      }
      for (final d in _draftsByPattern.values) {
        d.dispose();
      }
      _draftsByDay.clear();
      _draftsByPattern.clear();

      _overviewCtrl.text = '';

      _syncReady = false; // prevent any sync during wipe/reset
      _rebuildSpans(); // clears spans; no sync happens
    });

    _clearSessionDraft();
  }

  // Load an existing flow into the editor (best-effort reconstruction of rules)
  void _loadFlowForEdit(_Flow f) {
    // Add debug logging
    if (kDebugMode) {
      _calendarDebugPrint(
        '[loadFlowForEdit] Loading flow ${f.id} "${f.name}" with color=${f.color.toARGB32().toRadixString(16)}',
      );
    }

    setState(() {
      _editing = f;
      _selectedCalendarId = f.calendarId ?? _defaultCalendarId();
      _nameCtrl.text = f.name;
      _active = f.active;
      _studioMode = _FlowStudioMode.build;
      _setBuildExactColor(f.color);

      _startDate = f.start == null ? null : _dateOnly(f.start!);
      _endDate = f.end == null ? null : _dateOnly(f.end!);
      _dateRangeEditedInCurrentEditor = _hasFullRange;

      final meta = notesDecode(f.notes);
      _useKemetic = meta.kemetic;
      _splitByPeriod = meta.split;
      _overviewCtrl.text = _effectiveOverview(f.notes, meta.overview);
      _flowAlertMinutesBefore = _alertNoneMinutes;
      _flowAlertMixed = false;

      // reset selections
      _selectedDecanDays.clear();
      _selectedWeekdays.clear();
      _perDecanSel.clear();
      _perWeekSel.clear();

      // try to reconstruct the selection state from rules
      if (f.rules.isNotEmpty) {
        final r = f.rules.first;
        if (r is _RuleDecan) {
          _useKemetic = true;
          _splitByPeriod = false;
          _selectedDecanDays.addAll(r.daysInDecan);
        } else if (r is _RuleWeek) {
          _useKemetic = false;
          _splitByPeriod = false;
          _selectedWeekdays.addAll(r.weekdays);
        } else if (r is _RuleDates) {
          _splitByPeriod = true;
          // build spans first
          _rebuildSpans();
          // seed per-period picks
          for (final g in r.dates) {
            if (_useKemetic) {
              final k = KemeticMath.fromGregorian(g);
              if (k.kMonth == 13) continue;
              final di = ((k.kDay - 1) ~/ 10);
              final inDec = ((k.kDay - 1) % 10) + 1;
              final key = '${k.kYear}-${k.kMonth}-$di';
              final set = _perDecanSel[key] ?? <int>{};
              set.add(inDec);
              _perDecanSel[key] = set;
            } else {
              final mon = _mondayOf(g);
              final key = _iso(mon);
              final set = _perWeekSel[key] ?? <int>{};
              set.add(g.weekday);
              _perWeekSel[key] = set;
            }
          }
        }
      }

      // refresh UI with new selections
      _syncReady = true;
      _applySelectionToDrafts();
    });
    _markFlowEditorVisible();
    _schedulePersistentDraftSave();
  }

  /// Load AI-generated flow by ID and populate Flow Studio
  Future<void> _loadAIGeneratedFlow(int flowId) async {
    try {
      // 1. Fetch the flow from database
      final repo = FlowsRepo(Supabase.instance.client);
      final flow = await repo.getFlowById(flowId);
      if (flow == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Flow not found')));
        }
        return;
      }

      // 2. Convert FlowRow to _Flow
      final flowObj = _Flow(
        id: flow.id,
        calendarId: flow.calendarId,
        name: flow.name,
        color: Color(rgbToArgb(flow.color)),
        active: flow.active,
        isSaved: flow.isSaved,
        savedAt: flow.savedAt,
        start: flow.startDate,
        end: flow.endDate,
        notes: flow.notes,
        rules: const [], // AI flows have no recurring rules
        shareId: null,
        isHidden: flow.isHidden, // Preserve hidden flag if present
        isReminder: flow.isReminder,
        reminderUuid: flow.reminderUuid,
      );

      // 3. Fetch events for this flow
      final eventsRepo = UserEventsRepo(Supabase.instance.client);
      final eventRecords = await eventsRepo.getEventsForFlow(flowId);

      // Convert record type to UserEvent objects
      final userEvents = eventRecords.map((record) {
        return UserEvent(
          id: record.id ?? '', // id is String? (UUID from database)
          clientEventId: record.clientEventId,
          title: record.title,
          detail: record.detail,
          location: record.location,
          allDay: record.allDay,
          startsAt: record.startsAtUtc,
          endsAt: record.endsAtUtc,
          flowLocalId: record.flowLocalId,
          category: record.category,
        );
      }).toList()..sort((a, b) => a.startsAt.compareTo(b.startsAt));

      // Dedupe by id/cid/composite to avoid duplicate drafts
      final seen = <String, UserEvent>{};
      for (final e in userEvents) {
        String key;
        if (e.id.isNotEmpty) {
          key = 'id:${e.id}';
        } else if (e.clientEventId != null) {
          key = 'cid:${e.clientEventId}';
        } else {
          final endKey = e.endsAt?.toIso8601String() ?? 'NO_END';
          key =
              'cmp|${e.title.trim().toLowerCase()}|${e.startsAt.toIso8601String()}|$endKey|${e.allDay}';
        }
        if (!seen.containsKey(key)) {
          seen[key] = e;
        }
      }
      final dedupedEvents = seen.values.toList()
        ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

      if (kDebugMode) {
        _calendarDebugPrint('🔍 [AI Flow Init] flowId: $flowId');
        _calendarDebugPrint(
          '🔍 [AI Flow Init] userEvents.length: ${userEvents.length}',
        );
        _calendarDebugPrint(
          '🔍 [AI Flow Init] titles: ${userEvents.map((e) => e.title).toList()}',
        );
      }

      // 4. 🚨 CRITICAL ORDERING: Set context BEFORE initializing selections
      // _populateGregorianSelections() needs _startDate to calculate week indices
      // _convertEventsToDrafts() needs _useKemetic to build correct date keys
      final meta = notesDecode(flowObj.notes);
      _startDate = flowObj.start == null ? null : _dateOnly(flowObj.start!);
      _endDate = flowObj.end == null ? null : _dateOnly(flowObj.end!);
      _dateRangeEditedInCurrentEditor = _hasFullRange;
      _useKemetic = meta.kemetic;
      _splitByPeriod = true; // Force customize mode for AI flows

      _syncReady = true;
      // 5. Build spans now that mode is known
      _rebuildSpans();

      // 6. Graceful fallback if no events loaded
      if (userEvents.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "We created your Flow but couldn't load scheduled blocks. You can add blocks below.",
              ),
              duration: Duration(seconds: 5),
              backgroundColor: Colors.orange,
            ),
          );
        }

        // Manual hydration of header fields (no _loadFlowForEdit call)
        setState(() {
          _editing = flowObj;
          _selectedCalendarId = flowObj.calendarId ?? _defaultCalendarId();
          _nameCtrl.text = flowObj.name;
          _active = flowObj.active;
          _studioMode = _FlowStudioMode.build;
          _setBuildExactColor(flowObj.color);

          _overviewCtrl.text = _effectiveOverview(flowObj.notes, meta.overview);

          // This is an already-persisted AI flow. Closing the editor must not
          // treat it like an unsaved generated draft.
          _isAIGeneratedFlow = false;
        });
        return;
      }

      // 7. NOW initialize AI flow selections (depends on _startDate, _endDate, _useKemetic set above)
      // Convert events to drafts and populate _draftsByDay
      _convertEventsToDrafts(
        dedupedEvents,
        renumberAiTitles: true,
        startDateForRenumbering: _startDate,
        forceTimedDrafts: true,
      );

      // 8. Clear and populate selection state
      _perWeekSel.clear();
      _perDecanSel.clear();

      if (_hasFullRange && _draftsByDay.isNotEmpty) {
        if (_useKemetic) {
          _populateKemeticSelections(dedupedEvents);
        } else {
          _populateGregorianSelections(dedupedEvents);
        }
      }

      _applySelectionToDrafts(); // one entry point

      // 9. Count ALL notes for analytics
      _originalEventCount = _draftsByDay.values.fold<int>(
        0,
        (sum, list) => sum + list.length,
      );

      if (kDebugMode) {
        _calendarDebugPrint(
          '🔍 [AI Flow Init] _originalEventCount: $_originalEventCount (days: ${_draftsByDay.keys.length})',
        );
      }

      // 10. 🔑 CRITICAL: Manually hydrate header fields WITHOUT calling _loadFlowForEdit()
      setState(() {
        _editing = flowObj;
        _selectedCalendarId = flowObj.calendarId ?? _defaultCalendarId();

        // Header fields only
        _nameCtrl.text = flowObj.name;
        _active = flowObj.active;
        _studioMode = _FlowStudioMode.build;
        _setBuildExactColor(flowObj.color);

        // Overview
        _overviewCtrl.text = _effectiveOverview(flowObj.notes, meta.overview);

        // This is an already-persisted AI flow. Closing the editor must not
        // treat it like an unsaved generated draft.
        _isAIGeneratedFlow = false;

        // Note: _startDate, _endDate, _useKemetic, _splitByPeriod already set above
      });

      // 11. Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                KemeticGold.icon(Icons.auto_awesome),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '✨ Generated "${flowObj.name}" with ${userEvents.length} events. Review and save!',
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1E3A5F),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading AI flow: $e')));
      }
    }
  }

  /// Load a flow by ID from database (for imported or AI flows not in existingFlows)
  Future<void> _loadFlowByIdFromDb(int flowId) async {
    if (kDebugMode) {
      _calendarDebugPrint('🔍 [LoadFlow] START: flowId=$flowId');
    }

    final flowsRepo = FlowsRepo(Supabase.instance.client);
    final eventsRepo = UserEventsRepo(Supabase.instance.client);

    // 1️⃣ Load the flow row
    final flowRow = await flowsRepo.getFlowById(flowId);
    if (flowRow == null) {
      if (kDebugMode) {
        _calendarDebugPrint('🔍 [LoadFlow] ERROR: Flow not found');
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Flow not found')));
      }
      return;
    }

    if (kDebugMode) {
      _calendarDebugPrint(
        '🔍 [LoadFlow] Flow found: name="${flowRow.name}", startDate=${flowRow.startDate}, endDate=${flowRow.endDate}',
      );
    }

    // If this is an AI-generated flow, keep the existing AI path
    final isAiGenerated = (flowRow.aiMetadata?['generated'] as bool?) == true;
    if (isAiGenerated) {
      if (kDebugMode) {
        _calendarDebugPrint(
          '🔍 [LoadFlow] Detected AI flow, delegating to _loadAIGeneratedFlow',
        );
      }
      await _loadAIGeneratedFlow(flowId);
      return;
    }

    // 2️⃣ Load all events for this flow (this is what the importer writes)
    final eventRecords = await eventsRepo.getEventsForFlow(flowId);

    if (kDebugMode) {
      _calendarDebugPrint(
        '🔍 [LoadFlow] Loaded ${eventRecords.length} event records',
      );
    }

    // ✅ CORRECTED: Map records → UserEvent using the same helper as AI path
    final userEvents = eventRecords.map((record) {
      return UserEvent(
        id: record.id ?? '',
        clientEventId: record.clientEventId,
        title: record.title,
        detail: record.detail,
        location: record.location,
        allDay: record.allDay,
        startsAt: record.startsAtUtc,
        endsAt: record.endsAtUtc,
        flowLocalId: record.flowLocalId,
        category: record.category,
      );
    }).toList();

    // If there are *no* events, fall back to the existing rule-based loader
    if (userEvents.isEmpty) {
      if (kDebugMode) {
        _calendarDebugPrint(
          '🔍 [LoadFlow] No events found, using rule-based loader fallback',
        );
      }
      final rules = flowRow.rules
          .map((r) => CalendarPage.ruleFromJson(r as Map<String, dynamic>))
          .toList();

      final f = _Flow(
        id: flowRow.id,
        calendarId: flowRow.calendarId,
        name: flowRow.name,
        color: Color(rgbToArgb(flowRow.color)),
        active: flowRow.active,
        isSaved: flowRow.isSaved,
        savedAt: flowRow.savedAt,
        start: flowRow.startDate,
        end: flowRow.endDate,
        notes: flowRow.notes,
        rules: rules,
        shareId: null,
        isHidden: false,
      );

      _editing = f;
      _nameCtrl.text = f.name;
      _active = f.active;
      _loadFlowForEdit(f);
      return;
    }

    // 3️⃣ Calculate start / end dates from the imported events
    userEvents.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final firstDate = userEvents.first.startsAt.toLocal();
    final lastDate = userEvents.last.startsAt.toLocal();
    final startDate = _dateOnly(flowRow.startDate ?? firstDate);
    final endDate = _dateOnly(flowRow.endDate ?? lastDate);

    if (kDebugMode) {
      _calendarDebugPrint('🔍 [LoadFlow] Calculated dates:');
      _calendarDebugPrint('  firstDate from events: $firstDate');
      _calendarDebugPrint('  lastDate from events: $lastDate');
      _calendarDebugPrint('  flowRow.startDate: ${flowRow.startDate}');
      _calendarDebugPrint('  flowRow.endDate: ${flowRow.endDate}');
      _calendarDebugPrint('  final startDate: $startDate');
      _calendarDebugPrint('  final endDate: $endDate');
    }

    // 4️⃣ Build _Flow model for the editor
    final rules = flowRow.rules
        .map((r) => CalendarPage.ruleFromJson(r as Map<String, dynamic>))
        .toList();

    final f = _Flow(
      id: flowRow.id,
      calendarId: flowRow.calendarId,
      name: flowRow.name,
      color: Color(rgbToArgb(flowRow.color)),
      active: flowRow.active,
      isSaved: flowRow.isSaved,
      savedAt: flowRow.savedAt,
      start: startDate,
      end: endDate,
      notes: flowRow.notes,
      rules: rules,
      shareId: null,
      isHidden: false,
    );

    // 5️⃣ Decode notes meta (overview, kemetic flag, split)
    final meta = notesDecode(f.notes);

    if (kDebugMode) {
      _calendarDebugPrint(
        '🔍 [LoadFlow] Decoded meta: kemetic=${meta.kemetic}, overview="${meta.overview}"',
      );
    }

    // Clear existing drafts before converting
    for (final dayList in _draftsByDay.values) {
      for (final draft in dayList) {
        draft.dispose();
      }
    }
    _draftsByDay.clear();

    // 6️⃣ 🚨 CRITICAL ORDERING: Set context BEFORE initializing selections
    // _populateGregorianSelections() needs _startDate to calculate week indices
    // _convertEventsToDrafts() needs _useKemetic to build correct date keys
    // Match AI flow path EXACTLY: set dates OUTSIDE setState
    _startDate = startDate;
    _endDate = endDate;
    _dateRangeEditedInCurrentEditor = _hasFullRange;
    _useKemetic = meta.kemetic;
    _splitByPeriod = true; // imported flows behave like customize mode
    _syncReady = true;

    if (kDebugMode) {
      _calendarDebugPrint(
        '🔍 [LoadFlow] Set state variables OUTSIDE setState:',
      );
      _calendarDebugPrint('  _startDate: $_startDate');
      _calendarDebugPrint('  _endDate: $_endDate');
      _calendarDebugPrint('  _useKemetic: $_useKemetic');
      _calendarDebugPrint('  _splitByPeriod: $_splitByPeriod');
      _calendarDebugPrint('  _syncReady: $_syncReady');
      _calendarDebugPrint('  _hasFullRange: $_hasFullRange');
    }

    // 7️⃣ Build spans now that mode is known (BEFORE converting events, like AI path)
    if (kDebugMode) {
      _calendarDebugPrint('🔍 [LoadFlow] Calling _rebuildSpans() (first call)');
    }
    _rebuildSpans();

    if (kDebugMode) {
      _calendarDebugPrint('🔍 [LoadFlow] After first _rebuildSpans():');
      _calendarDebugPrint('  _kemeticSpans.length: ${_kemeticSpans.length}');
      _calendarDebugPrint('  _weekSpans.length: ${_weekSpans.length}');
    }

    // 8️⃣ NOW convert events → drafts (same helper AI uses)
    if (kDebugMode) {
      _calendarDebugPrint(
        '🔍 [LoadFlow] Converting ${userEvents.length} events to drafts',
      );
    }
    _convertEventsToDrafts(userEvents);

    if (kDebugMode) {
      _calendarDebugPrint('🔍 [LoadFlow] After _convertEventsToDrafts():');
      _calendarDebugPrint('  _draftsByDay.length: ${_draftsByDay.length}');
      _calendarDebugPrint('  _draftsByDay.keys: ${_draftsByDay.keys.toList()}');
    }

    // 9️⃣ Clear and populate selection state
    _perWeekSel.clear();
    _perDecanSel.clear();

    if (kDebugMode) {
      _calendarDebugPrint(
        '🔍 [LoadFlow] Populating selections: _hasFullRange=$_hasFullRange, _draftsByDay.isNotEmpty=${_draftsByDay.isNotEmpty}',
      );
    }

    if (_hasFullRange && _draftsByDay.isNotEmpty) {
      if (_useKemetic) {
        _populateKemeticSelections(userEvents);
      } else {
        _populateGregorianSelections(userEvents);
      }

      if (kDebugMode) {
        _calendarDebugPrint('🔍 [LoadFlow] After populating selections:');
        _calendarDebugPrint('  _perDecanSel.length: ${_perDecanSel.length}');
        _calendarDebugPrint('  _perWeekSel.length: ${_perWeekSel.length}');
      }
    } else {
      if (kDebugMode) {
        _calendarDebugPrint(
          '🔍 [LoadFlow] SKIPPED selection population: _hasFullRange=$_hasFullRange, _draftsByDay.isNotEmpty=${_draftsByDay.isNotEmpty}',
        );
      }
    }

    // 🔟 Apply selections to drafts (calls _rebuildSpans() again, like AI path)
    if (kDebugMode) {
      _calendarDebugPrint(
        '🔍 [LoadFlow] Calling _applySelectionToDrafts() (will call _rebuildSpans() again)',
      );
    }
    _applySelectionToDrafts();

    if (kDebugMode) {
      _calendarDebugPrint('🔍 [LoadFlow] After _applySelectionToDrafts():');
      _calendarDebugPrint('  _kemeticSpans.length: ${_kemeticSpans.length}');
      _calendarDebugPrint('  _weekSpans.length: ${_weekSpans.length}');
    }

    // 1️⃣1️⃣ 🔑 CRITICAL: Manually hydrate header fields WITHOUT setting dates again
    // Match AI flow path: dates already set above, only set header fields here
    if (!mounted) {
      if (kDebugMode) {
        _calendarDebugPrint(
          '🔍 [LoadFlow] ERROR: Widget not mounted, aborting setState',
        );
      }
      return;
    }

    if (kDebugMode) {
      _calendarDebugPrint(
        '🔍 [LoadFlow] About to call setState with header fields:',
      );
      _calendarDebugPrint('  _editing will be: ${f.name}');
      _calendarDebugPrint('  _startDate (already set): $_startDate');
      _calendarDebugPrint('  _endDate (already set): $_endDate');
    }

    setState(() {
      _editing = f;
      _selectedCalendarId = f.calendarId ?? _defaultCalendarId();
      _nameCtrl.text = f.name;
      _active = f.active;
      _studioMode = _FlowStudioMode.build;
      _setBuildExactColor(f.color);

      _overviewCtrl.text = _effectiveOverview(f.notes, meta.overview);

      // ⛔️ Do NOT set dates here - they're already set above (like AI path)
      // ⛔️ Do NOT set _useKemetic, _splitByPeriod, _syncReady - already set above
      // ⛔️ Do NOT set _isAIGeneratedFlow - this is an imported flow
    });

    if (kDebugMode) {
      _calendarDebugPrint('🔍 [LoadFlow] After setState:');
      _calendarDebugPrint('  _editing: ${_editing?.name}');
      _calendarDebugPrint('  _startDate: $_startDate');
      _calendarDebugPrint('  _endDate: $_endDate');
      _calendarDebugPrint('  _hasFullRange: $_hasFullRange');
      _calendarDebugPrint('  _draftsByDay.length: ${_draftsByDay.length}');
      _calendarDebugPrint('  _kemeticSpans.length: ${_kemeticSpans.length}');
      _calendarDebugPrint('  _weekSpans.length: ${_weekSpans.length}');
      _calendarDebugPrint('🔍 [LoadFlow] END');
    }
  }

  ImportFlowData? _aiImportDataFromResponse(
    AIFlowGenerationResponse resp,
    DateTime baseStart,
  ) {
    try {
      final events = buildAiFlowImportEvents(resp);
      if (events.isEmpty) return null;

      // Build dummy share item (local-only)
      final share = InboxShareItem(
        shareId: 'ai-local-${DateTime.now().millisecondsSinceEpoch}',
        kind: InboxShareKind.flow,
        recipientId: '',
        senderId: '',
        payloadId: 'ai-local',
        title: resp.flowName ?? 'AI Flow',
        createdAt: DateTime.now(),
        payloadJson: {'events': events},
      );

      // Convert color hex -> ARGB int
      final hex = resp.flowColor ?? '#4dd0e1';
      final cleaned = hex.replaceFirst('#', '');
      final rgb = int.tryParse(cleaned, radix: 16) ?? 0x4dd0e1;
      final colorInt = 0xFF000000 | rgb;

      return ImportFlowData(
        share: share,
        name: resp.flowName ?? 'AI Flow',
        color: colorInt,
        notes: resp.notes is String
            ? resp.notes as String
            : jsonEncode(resp.notes),
        rules: const [],
        suggestedStartDate: baseStart,
        suggestedEndDate: resp.requestedEndDate,
        overview: resp.overviewSummary ?? resp.overviewTitle ?? '',
        generationId: resp.generationId,
        originType: 'ai',
        originFlowId: resp.flowId,
        rootFlowId: resp.flowId,
        aiMetadata: resp.aiMetadata,
      );
    } catch (_) {
      return null;
    }
  }

  /// Populate Kemetic selections based on events
  void _populateKemeticSelections(List<UserEvent> events) {
    for (final event in events) {
      final localStart = event.startsAt.toLocal();
      final (:kYear, :kMonth, :kDay) = KemeticMath.fromGregorian(localStart);

      // Calculate decan index and day within decan
      final di = ((kDay - 1) ~/ 10); // decan index (0-3)
      final inDec = ((kDay - 1) % 10) + 1; // day in decan (1-10)
      final key = '$kYear-$kMonth-$di';

      final set = _perDecanSel[key] ?? <int>{};
      set.add(inDec);
      _perDecanSel[key] = set;
    }
  }

  /// Populate Gregorian weekday selections based on events
  void _populateGregorianSelections(List<UserEvent> events) {
    for (final event in events) {
      final localStart = event.startsAt.toLocal();
      final mondayOfWeek = _mondayOf(localStart);
      final weekKey = _iso(mondayOfWeek);
      final weekday = localStart.weekday;

      final set = _perWeekSel[weekKey] ?? <int>{};
      set.add(weekday);
      _perWeekSel[weekKey] = set;
    }
  }

  /// Convert database events to _NoteDraft objects in _draftsByDay
  /// ✅ Handles multiple events per day correctly (Map of Lists)
  void _convertEventsToDrafts(
    List<UserEvent> events, {
    bool renumberAiTitles = false,
    DateTime? startDateForRenumbering,
    bool forceTimedDrafts = false,
  }) {
    // Step 1: Dispose all existing drafts properly (nested loop for lists)
    for (final dayList in _draftsByDay.values) {
      for (final draft in dayList) {
        draft.dispose();
      }
    }
    _draftsByDay.clear();

    final dayLabelRegex = RegExp(r'^day\s+(\d+)', caseSensitive: false);

    for (final event in events) {
      // Convert UTC to local
      final localStart = event.startsAt.toLocal();
      final localEnd = event.endsAt?.toLocal();
      final startDateOnly = _dateOnly(localStart);

      // Renumber common "Day X" prefixes so the first block is always Day 1
      String title = event.title;
      if (renumberAiTitles && startDateForRenumbering != null) {
        final dayOffset =
            startDateOnly
                .difference(_dateOnly(startDateForRenumbering))
                .inDays +
            1; // clamp below handled by regex guard
        if (dayOffset > 0) {
          final m = dayLabelRegex.firstMatch(title.trim());
          if (m != null) {
            title = title.replaceRange(m.start, m.end, 'Day $dayOffset');
          }
        }
      }

      // Get Kemetic date
      final (:kYear, :kMonth, :kDay) = KemeticMath.fromGregorian(localStart);
      final dateKey = dayKey(kYear, kMonth, kDay);

      // Create draft
      final draft = _NoteDraft(onChanged: _schedulePersistentDraftSave);

      // Populate controllers
      draft.titleCtrl.text = title;
      draft.locationCtrl.text = event.location ?? '';
      final decodedDetail = _decodeDetailMetadata(event.detail);
      draft.detailCtrl.text = _cleanDetail(decodedDetail.detail);
      draft.alertMinutesBefore =
          decodedDetail.alertMinutes ?? _alertNoneMinutes; // default to none
      draft.usesFlowAlertDefault = false;
      draft.category = event.category;
      draft.actionId = event.actionId;
      draft.behaviorPayload = event.behaviorPayload == null
          ? null
          : Map<String, dynamic>.from(event.behaviorPayload!);

      // Set times
      final hasExplicitTime =
          (localStart.hour != 0 || localStart.minute != 0) ||
          (localEnd != null && (localEnd.hour != 0 || localEnd.minute != 0));

      final treatAsTimed =
          forceTimedDrafts || (!event.allDay || hasExplicitTime);
      draft.allDay = treatAsTimed ? false : event.allDay;

      if (treatAsTimed) {
        final startTime =
            (localStart.hour == 0 && localStart.minute == 0 && forceTimedDrafts)
            ? const TimeOfDay(hour: 12, minute: 0)
            : TimeOfDay(hour: localStart.hour, minute: localStart.minute);

        draft.start = startTime;

        if (localEnd != null) {
          draft.end = TimeOfDay(hour: localEnd.hour, minute: localEnd.minute);
        } else {
          draft.end = _addMinutes(startTime, 60);
        }
      }

      // ✅ CRITICAL: Append to list, don't overwrite (multiple events per day)
      final listForDay = _draftsByDay[dateKey] ?? <_NoteDraft>[];
      listForDay.add(draft);
      _draftsByDay[dateKey] = listForDay;

      if (kDebugMode) {
        _calendarDebugPrint(
          '🔍 [Draft] $dateKey → title: "${draft.titleCtrl.text}" (${listForDay.length} total)',
        );
      }
    }

    _initializeFlowAlertStateFromDrafts();
  }

  // ---------- scaffold ----------

  /// Initialize Flow Studio from inbox import data
  Future<void> _initializeFromImport(ImportFlowData data) async {
    _setImportNameControllerText(data.name);
    _active = true;
    _isLoadingFlow = true;
    setState(() {});

    try {
      await _ensureCalendarChoicesLoaded();
      _selectedCalendarId = data.calendarId ?? _defaultCalendarId();
      _studioMode = _FlowStudioMode.build;
      _setBuildExactColor(Color(data.color));

      _startDate = data.suggestedStartDate != null
          ? _dateOnly(data.suggestedStartDate!)
          : _dateOnly(DateTime.now());
      final requestedEndDate = data.suggestedEndDate != null
          ? _dateOnly(data.suggestedEndDate!)
          : null;
      _dateRangeEditedInCurrentEditor = data.suggestedStartDate != null;

      // For AI imports (payloadId == 'ai-local'), force Gregorian/simple mode
      final isAiImport = data.share.payloadId == 'ai-local';
      if (isAiImport) {
        _useKemetic = false;
        _splitByPeriod = true;
        if ((data.overview ?? '').isNotEmpty) {
          _overviewCtrl.text = data.overview!;
        } else {
          _overviewCtrl.clear();
        }
      } else if (data.notes != null) {
        try {
          final meta = notesDecode(data.notes!);
          _useKemetic = meta.kemetic;
          _splitByPeriod = meta.split;
          _overviewCtrl.text = _effectiveOverview(data.notes, meta.overview);
        } catch (_) {}
      } else {
        _useKemetic = false;
        _splitByPeriod = true;
        _overviewCtrl.text = data.overview ?? '';
      }

      final payload = data.share.payloadJson;
      final eventsJson = payload?['events'] as List<dynamic>?;

      if (eventsJson != null && eventsJson.isNotEmpty) {
        if (!isAiImport) {
          // Shared-flow payload snapshots are already concrete event instances.
          // Keep them in per-day mode so Save persists the individual rows
          // instead of requiring a repeating weekday template selection.
          _useKemetic = false;
          _splitByPeriod = true;
        }
        final baseDate = _startDate ?? DateTime.now();
        final userEvents = <UserEvent>[];
        for (final e in eventsJson) {
          try {
            final offset = (e['offset_days'] as num?)?.toInt() ?? 0;
            final date = baseDate.add(Duration(days: offset));

            int sh = 9, sm = 0;
            final st = e['start_time'] as String?;
            if (st != null && st.length >= 5) {
              sh = int.parse(st.substring(0, 2));
              sm = int.parse(st.substring(3, 5));
            }

            int? eh, em;
            final et = e['end_time'] as String?;
            if (et != null && et.length >= 5) {
              eh = int.parse(et.substring(0, 2));
              em = int.parse(et.substring(3, 5));
            }

            final allDay = e['all_day'] as bool? ?? false;
            final startsAt = DateTime(date.year, date.month, date.day, sh, sm);
            DateTime? endsAt;
            if (!allDay) {
              if (eh != null && em != null) {
                endsAt = DateTime(date.year, date.month, date.day, eh, em);
              } else {
                endsAt = startsAt.add(const Duration(hours: 1));
              }
            }

            userEvents.add(
              UserEvent(
                id: '',
                clientEventId: null,
                title: (e['title'] as String?) ?? data.name,
                detail: (e['detail'] as String?) ?? '',
                location: (e['location'] as String?) ?? '',
                allDay: allDay,
                startsAt: startsAt,
                endsAt: endsAt,
                flowLocalId: null,
                category: null,
                actionId: e['action_id'] as String?,
                behaviorPayload: e['behavior_payload'] is Map
                    ? Map<String, dynamic>.from(e['behavior_payload'] as Map)
                    : null,
              ),
            );
          } catch (_) {
            // skip malformed event
          }
        }

        if (userEvents.isNotEmpty) {
          final allDates =
              userEvents.map((ev) => _dateOnly(ev.startsAt.toLocal())).toList()
                ..sort();
          _endDate = requestedEndDate ?? allDates.last;
        } else {
          _endDate = requestedEndDate ?? _startDate;
        }

        _syncReady = false;
        // Sort events by start time to maintain Day 1..N ordering
        userEvents.sort((a, b) => a.startsAt.compareTo(b.startsAt));

        _convertEventsToDrafts(
          userEvents,
          renumberAiTitles: true,
          startDateForRenumbering: _startDate,
          forceTimedDrafts: true, // allow time editing even if all_day true
        );
        _rebuildSpans(); // safe while _syncReady is false
        if (_hasFullRange && _draftsByDay.isNotEmpty) {
          if (_useKemetic) {
            _populateKemeticSelections(userEvents);
          } else {
            _populateGregorianSelections(userEvents);
            // For AI imports, ensure per-week selections are set from events
            if (isAiImport) {
              _perWeekSel.clear();
              for (final ev in userEvents) {
                final monday = _mondayOf(ev.startsAt.toLocal());
                final key = _iso(monday);
                final wd = ev.startsAt.toLocal().weekday;
                final set = _perWeekSel[key] ?? <int>{};
                set.add(wd);
                _perWeekSel[key] = set;
              }
              _applySelectionToDrafts();
            }
          }
          // Apply selection once after population (non-AI imports)
          if (!isAiImport) _applySelectionToDrafts();
        }
        if (mounted) {
          setState(() {
            _syncReady = true;
          });
          if (_hasFullRange) {
            _syncDraftsWithSelection();
          }
        } else {
          _syncReady = true;
        }
      } else {
        final suggestedWeekdays =
            data.share.suggestedSchedule?.weekdays ?? const <int>[];
        final hasImportSchedule =
            isAiImport ||
            data.rules.isNotEmpty ||
            suggestedWeekdays.isNotEmpty ||
            requestedEndDate != null;
        if (!hasImportSchedule) {
          _startDate = null;
          _endDate = null;
          _dateRangeEditedInCurrentEditor = false;
        } else {
          _endDate = requestedEndDate ?? _startDate;
        }
        _syncReady = true;
        _rebuildSpans();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading import: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFlow = false;
        });
      }
    }
  }

  /// Helper to load a flow from DB with loading spinner
  void _loadFromDbWithSpinner(int flowId) {
    if (kDebugMode) {
      _calendarDebugPrint(
        '🔧 [FlowStudio] _loadFromDbWithSpinner: flowId=$flowId',
      );
    }

    _nameCtrl = TextEditingController();
    _markNameControllerReady();
    _active = true;
    _isLoadingFlow = true;

    _loadFlowByIdFromDb(flowId)
        .then((_) async {
          if (!mounted) return;
          await _restorePersistentDraftIfAny(expectedEditFlowId: flowId);
          if (!mounted) return;
          setState(() {
            _isLoadingFlow = false;
          });
        })
        .catchError((e) {
          if (!mounted) return;
          setState(() {
            _isLoadingFlow = false;
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error loading flow: $e')));
        });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (kDebugMode) {
      _calendarDebugPrint(
        '🔧 [FlowStudio] initState: editFlowId=${widget.editFlowId}, '
        'existingFlows=${widget.existingFlows.length}',
      );
    }

    if (widget.importData != null) {
      _initializeFromImport(widget.importData!);
      _markFlowEditorVisible();
      return;
    }

    // Load flow if provided (always from DB to ensure full hydration)
    if (widget.editFlowId != null) {
      final id = widget.editFlowId!;
      if (kDebugMode) {
        _calendarDebugPrint(
          '🔎 [FlowStudio] editFlowId=$id → loading directly from DB',
        );
      }
      _loadFromDbWithSpinner(id);
    } else {
      if (kDebugMode) {
        _calendarDebugPrint('✨ [FlowStudio] New flow creation mode');
      }
      // Initialize for new flow creation
      _editing = null;
      _nameCtrl = TextEditingController();
      _markNameControllerReady();
      _selectedCalendarId = _defaultCalendarId();
      _active = true;
      _setBuildExactColor(_flowPalette[0]);
      _useKemetic = false;
      _splitByPeriod = true;
      _flowAlertMinutesBefore = _alertNoneMinutes;
      _flowAlertMixed = false;
      _syncReady = true; // new editor can sync once range exists
      _rebuildSpans(); // harmless if range empty; no sync without range

      if (_sessionDraft != null) {
        _restoreDraft(_sessionDraft!);
        _sessionDraft = null;
      } else if (widget.debugInitialDraftJson != null) {
        final draft = _FlowStudioDraft.fromJson(widget.debugInitialDraftJson);
        if (draft != null) {
          _restoreDraft(draft);
        }
      } else if (widget.debugDisableDraftPersistence) {
        // Test-only direct mounts avoid long-lived restoration futures.
      } else {
        unawaited(_restorePersistentDraftIfAny());
      }
    }
    _markFlowEditorVisible();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _draftPersistDebounce?.cancel();
    if (widget.debugDisableDraftPersistence) {
      _sessionDraft = null;
    } else if (!_suppressDraftSave) {
      _sessionDraft = _captureDraft();
      unawaited(_persistDraftNow(reason: 'dispose'));
    } else {
      _sessionDraft = null;
      unawaited(
        AppRestorationService.instance.saveEditorState(
          _kFlowStudioDraftEditorKey,
          null,
        ),
      );
    }

    if (_draftListenersInstalled) {
      _nameCtrl.removeListener(_schedulePersistentDraftSave);
      _overviewCtrl.removeListener(_schedulePersistentDraftSave);
      _composePromptCtrl.removeListener(_schedulePersistentDraftSave);
    }
    _nameCtrl.dispose();
    _overviewCtrl.dispose();
    _composePromptCtrl.dispose();
    for (final dayList in _draftsByDay.values) {
      for (final d in dayList) {
        d.dispose();
      }
    }
    for (final d in _draftsByPattern.values) {
      d.dispose();
    }
    super.dispose();
  }

  // ---------- UI bits ----------

  Widget _studioSectionLabel(String text, {String? trailing}) {
    return Row(
      children: [
        Text(
          text.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF6F604A),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 4,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          Text(
            trailing,
            style: const TextStyle(
              color: Color(0xFF6F604A),
              fontSize: 14,
              fontStyle: FontStyle.italic,
              fontFamily: 'GentiumPlus',
            ),
          ),
        ],
      ],
    );
  }

  InputDecoration _studioInputDecoration({
    required _FlowStudioTone tone,
    String? hint,
    double radius = 18,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF6F604A)),
      filled: true,
      fillColor: Color.alphaBlend(
        tone.softenedAccent.withValues(alpha: 0.035),
        const Color(0xFF050403),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: tone.fieldBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: tone.fieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(
          color: tone.softenedAccent.withValues(alpha: 0.44),
          width: 1.25,
        ),
      ),
    );
  }

  Widget _studioModeToggle(_FlowStudioTone tone) {
    Widget segment({
      required _FlowStudioMode mode,
      required IconData icon,
      required String label,
    }) {
      final selected = _studioMode == mode;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: InkWell(
            key: ValueKey(
              mode == _FlowStudioMode.build
                  ? 'flow-studio-mode-build'
                  : 'flow-studio-mode-compose',
            ),
            borderRadius: BorderRadius.circular(20),
            onTap: () => _setStudioMode(mode),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: selected ? tone.selectedPill : Colors.transparent,
                border: Border.all(
                  color: selected
                      ? tone.selectedPillBorder
                      : Colors.transparent,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: tone.softenedAccent.withValues(alpha: 0.07),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: selected ? _gold : const Color(0xFF756A59),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    label,
                    style: TextStyle(
                      color: selected ? _gold : const Color(0xFF756A59),
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'GentiumPlus',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xFF070703),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: const Color(0xFF33260E)),
      ),
      child: Row(
        children: [
          segment(
            mode: _FlowStudioMode.build,
            icon: Icons.edit_outlined,
            label: 'Build',
          ),
          segment(
            mode: _FlowStudioMode.compose,
            icon: Icons.auto_awesome,
            label: 'Compose',
          ),
        ],
      ),
    );
  }

  Widget _colorStudioSection(_FlowStudioTone tone) {
    final color = _activeStudioColor;
    final hue = _activeStudioHue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _studioSectionLabel('Color'),
        const SizedBox(height: 12),
        _FlowStudioSpectrumPicker(
          hue: hue,
          selectedColor: color,
          onHueChanged: _setActiveStudioHue,
        ),
        const SizedBox(height: 14),
        _colorReadoutCard(tone, color, hue),
      ],
    );
  }

  Widget _colorReadoutCard(_FlowStudioTone tone, Color color, double hue) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF050403),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tone.fieldBorder),
      ),
      child: Row(
        children: [
          Container(
            key: const ValueKey('flow-studio-color-preview-dot'),
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.18),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Text(
            _flowStudioHex(color),
            key: const ValueKey('flow-studio-color-hex'),
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontStyle: FontStyle.italic,
              fontFamily: 'GentiumPlus',
            ),
          ),
          const Spacer(),
          Text(
            _flowStudioColorNameForHue(hue),
            key: const ValueKey('flow-studio-color-name'),
            style: TextStyle(
              color: color.withValues(alpha: 0.82),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _studioCta({
    required _FlowStudioTone tone,
    required String text,
    required VoidCallback? onPressed,
    required Key key,
    bool busy = false,
  }) {
    return SizedBox(
      key: key,
      height: 58,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: busy ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: tone.ctaBg,
          foregroundColor: tone.ctaText,
          side: BorderSide(color: tone.ctaBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.auto_awesome, size: 20),
                  const SizedBox(width: 14),
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'GentiumPlus',
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _studioTopTintFade(_FlowStudioTone tone) {
    return SizedBox(
      height: 0,
      child: OverflowBox(
        alignment: Alignment.topCenter,
        minHeight: 0,
        maxHeight: 360,
        child: IgnorePointer(
          child: Container(
            height: 360,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  tone.softenedAccent.withValues(alpha: 0.18),
                  tone.softenedAccent.withValues(alpha: 0.10),
                  tone.softenedAccent.withValues(alpha: 0.04),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.34, 0.64, 1.0],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _systemPillToggle({
    required _FlowStudioTone tone,
    required bool useKemetic,
    required ValueChanged<bool> onChanged,
  }) {
    Widget item(bool itemUsesKemetic, String label) {
      final selected = useKemetic == itemUsesKemetic;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(17),
          onTap: () => onChanged(itemUsesKemetic),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              color: selected ? tone.selectedPill : Colors.transparent,
              border: Border.all(
                color: selected ? tone.selectedPillBorder : Colors.transparent,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? _gold : const Color(0xFF776B5B),
                fontSize: 16,
                fontFamily: 'GentiumPlus',
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 40,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0xFF080703),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: tone.fieldBorder),
        ),
        child: Row(children: [item(true, 'Kemetic'), item(false, 'Gregorian')]),
      ),
    );
  }

  Widget _composeSystemToggle(_FlowStudioTone tone) {
    return _systemPillToggle(
      tone: tone,
      useKemetic: _composeUseKemetic,
      onChanged: (value) => setState(() => _composeUseKemetic = value),
    );
  }

  Future<void> _pickComposeRangeStart() async {
    final picked = _composeUseKemetic
        ? await _pickKemeticDate(initial: _composeStartDate)
        : await _pickGregorianDate(initial: _composeStartDate);
    if (!mounted || picked == null) return;
    final pickedDate = dateOnlyForAiFlow(picked);
    final fallbackDays = _composeEndDate == null
        ? _composeDisplayedDurationDays()
        : math.max(
            1,
            _composeEndDate!
                    .difference(_composeStartDate ?? pickedDate)
                    .inDays +
                1,
          );
    setState(() {
      _composeManualDateRangeEdited = true;
      _composeStartDate = pickedDate;
      if (_composeEndDate == null || _composeEndDate!.isBefore(pickedDate)) {
        _composeEndDate = pickedDate.add(Duration(days: fallbackDays - 1));
      }
    });
  }

  Future<void> _pickComposeRangeEnd() async {
    final picked = _composeUseKemetic
        ? await _pickKemeticDate(initial: _composeEndDate ?? _composeStartDate)
        : await _pickGregorianDate(
            initial: _composeEndDate ?? _composeStartDate,
          );
    if (!mounted || picked == null) return;
    setState(() {
      _composeManualDateRangeEdited = true;
      _composeEndDate = dateOnlyForAiFlow(picked);
    });
  }

  int _composeDisplayedDurationDays() {
    final start = _composeStartDate;
    final end = _composeEndDate;
    if (start != null && end != null) {
      final days = end.difference(start).inDays + 1;
      if (days > 0) return days;
    }
    return extractFlowDurationDays(_composePromptCtrl.text) ??
        defaultAiFlowDurationDays;
  }

  FlowDateRange _composeEffectiveDateRange() {
    final defaultStart = dateOnlyForAiFlow(DateTime.now());
    return resolveAiFlowDateRange(
      prompt: _composePromptCtrl.text,
      defaultStartDate: defaultStart,
      manualStartDate: _composeStartDate,
      manualEndDate: _composeEndDate,
      useManualRange: _composeManualDateRangeEdited,
    );
  }

  Widget _composeDateRangeSection(_FlowStudioTone tone) {
    final startLabel = _composeUseKemetic
        ? _fmtKemetic(_composeStartDate)
        : _fmtGregorian(_composeStartDate);
    final endLabel = _composeUseKemetic
        ? _fmtKemetic(_composeEndDate)
        : _fmtGregorian(_composeEndDate);
    Widget dateButton(String label, VoidCallback onPressed) {
      return Expanded(
        child: SizedBox(
          height: 38,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: tone.ctaText,
              side: BorderSide(color: tone.fieldBorder, width: 1.2),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(19),
              ),
            ),
            onPressed: _composeGenerating ? null : onPressed,
            child: Text(label, style: const TextStyle(fontSize: 14)),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _studioSectionLabel('Date range'),
            const Spacer(),
            const Text(
              'optional',
              style: TextStyle(
                color: Color(0xFF6F604A),
                fontSize: 15,
                fontStyle: FontStyle.italic,
                fontFamily: 'GentiumPlus',
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            dateButton(startLabel, () => unawaited(_pickComposeRangeStart())),
            const SizedBox(width: 20),
            dateButton(endLabel, () => unawaited(_pickComposeRangeEnd())),
          ],
        ),
        if (_composeManualDateRangeEdited) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _composeGenerating
                ? null
                : () {
                    setState(() {
                      _composeManualDateRangeEdited = false;
                      final range = _composeEffectiveDateRange();
                      _composeStartDate = range.startDate;
                      _composeEndDate = range.endDate;
                    });
                  },
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: const Text('Use prompt duration'),
            style: TextButton.styleFrom(foregroundColor: _gold),
          ),
        ],
      ],
    );
  }

  Future<void> _shapeComposeFlow() async {
    final rawPrompt = _composePromptCtrl.text.trim();
    if (rawPrompt.length < 5) {
      setState(() {
        _composeError = rawPrompt.isEmpty
            ? 'Describe the flow you want to shape.'
            : 'Add a little more detail before shaping this flow.';
      });
      return;
    }

    final split = splitAiFlowPromptForApi(rawPrompt);
    final canonicalPrompt = buildCanonicalAiFlowPromptText(
      description: _composePromptCtrl.text,
      sourceText: split.sourceText,
    );
    final promptType = classifyFlowPrompt(canonicalPrompt);
    final selectedDateForParsing =
        _composeStartDate ?? dateOnlyForAiFlow(DateTime.now());
    final parsedItinerary = promptType == FlowPromptType.itinerarySchedule
        ? parseItineraryPrompt(
            canonicalPrompt,
            selectedStartDate: selectedDateForParsing,
            now: dateOnlyForAiFlow(DateTime.now()),
          )
        : null;

    if (promptType == FlowPromptType.itinerarySchedule &&
        (parsedItinerary == null || parsedItinerary.events.isEmpty)) {
      setState(() {
        _composeError =
            'Some dates or times could not be resolved. Review the pasted itinerary and try again.';
      });
      return;
    }

    final dateRange = parsedItinerary == null
        ? _composeEffectiveDateRange()
        : FlowDateRange(
            startDate: parsedItinerary.startDate,
            endDate: parsedItinerary.endDate,
            durationDays:
                parsedItinerary.endDate
                    .difference(parsedItinerary.startDate)
                    .inDays +
                1,
            source: FlowDateRangeSource.itinerarySchedule,
          );
    final startDate = dateRange.startDate;
    final endDate = dateRange.endDate;

    setState(() {
      _composeGenerating = true;
      _composeError = null;
      _composeStartDate = startDate;
      _composeEndDate = endDate;
    });

    try {
      final colorHex = aiFlowColorHexFromColor(_composeColor);
      final AIFlowGenerationResponse response;
      if (parsedItinerary != null) {
        response = parsedItinerary.toAIFlowGenerationResponse(
          flowColor: colorHex,
        );
      } else {
        AIFlowGenerationService? debugService;
        assert(() {
          // ignore: invalid_use_of_visible_for_testing_member
          debugService = AIFlowGenerationService.debugFlowStudioOverride;
          return true;
        }());
        final service =
            debugService ??
            (_composeAiService ??= AIFlowGenerationService(
              Supabase.instance.client,
            ));
        response = await service.generate(
          description: split.description,
          startDate: startDate,
          endDate: endDate,
          flowColor: colorHex,
          timezone: aiFlowIanaTimezoneForLocal(DateTime.now()),
          sourceText: split.sourceText,
        );
      }

      if (!mounted) return;
      if (response.success != true) {
        setState(() {
          _composeError =
              response.errorMessage ??
              'Generation failed. Please check your connection or try again.';
          _composeGenerating = false;
        });
        return;
      }

      final result = response.copyWith(
        requestedStartDate: startDate,
        requestedEndDate: endDate,
      );
      if (result.flowId != null) {
        await _loadFlowByIdFromDb(result.flowId!);
        if (!mounted) return;
        setState(() {
          _studioMode = _FlowStudioMode.build;
          _composeGenerating = false;
        });
        return;
      }

      final importData = _aiImportDataFromResponse(result, startDate);
      if (importData == null) {
        setState(() {
          _composeError = 'The generated flow had no events to import.';
          _composeGenerating = false;
        });
        return;
      }
      await _initializeFromImport(importData);
      if (!mounted) return;
      setState(() {
        _studioMode = _FlowStudioMode.build;
        _composeGenerating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _composeError = e.toString().replaceFirst('Exception: ', '');
        _composeGenerating = false;
      });
    }
  }

  Widget _itineraryImportBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _gold.withValues(alpha: 0.36)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.event_note, color: _gold, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Detected: Itinerary / Schedule',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Review the extracted dates, times, locations, and links before saving.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeToggle(_FlowStudioTone tone) {
    return _systemPillToggle(
      tone: tone,
      useKemetic: _useKemetic,
      onChanged: (value) {
        setState(() {
          _useKemetic = value;
        });
        _applySelectionToDrafts();
      },
    );
  }

  Widget _dateRangeSection() {
    final startLabel = _useKemetic
        ? _fmtKemetic(_startDate)
        : _fmtGregorian(_startDate);
    final endLabel = _useKemetic
        ? _fmtKemetic(_endDate)
        : _fmtGregorian(_endDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const GlossyText(
          text: 'Date range (optional)',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          gradient: silverGloss,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: silver, width: 1.25),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                  ),
                ),
                onPressed: _pickRangeStart,
                child: Text(startLabel, style: const TextStyle(fontSize: 14)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: silver, width: 1.25),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                  ),
                ),
                onPressed: _pickRangeEnd,
                child: Text(endLabel, style: const TextStyle(fontSize: 14)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _preRulesHint() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        SizedBox(height: 16),
        GlossyText(
          text: 'Set a start and end date to define rules',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          gradient: silverGloss,
        ),
        SizedBox(height: 6),
        Text(
          'After you pick both dates above, the rule chips will appear here.',
          style: TextStyle(color: Colors.white70),
        ),
      ],
    );
  }

  // Single-row chips (same for all decans / all weeks)
  Widget _kemeticSingleRow() {
    FilterChip chip(int n) => FilterChip(
      label: Text('$n'),
      selected: _selectedDecanDays.contains(n),
      onSelected: (v) {
        setState(() {
          v ? _selectedDecanDays.add(n) : _selectedDecanDays.remove(n);
        });
        _applySelectionToDrafts();
      },
      selectedColor: _gold.withValues(alpha: 0.22),
      checkmarkColor: Colors.white,
      side: const BorderSide(color: silver, width: 1.25),
      labelStyle: const TextStyle(color: Colors.white),
      backgroundColor: const Color(0xFF1A1B1F),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const GlossyText(
          text: 'Kemetic rules',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          gradient: silverGloss,
        ),
        const SizedBox(height: 6),
        _toggleCustomizeButton(),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (var n = 1; n <= 10; n++) chip(n)],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedDecanDays
                    ..clear()
                    ..addAll({for (var i = 1; i <= 10; i++) i});
                });
                _applySelectionToDrafts();
              },
              child: const Text('Select all'),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                setState(() => _selectedDecanDays.clear());
                _applySelectionToDrafts();
              },
              child: const Text('Clear'),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _openOverviewEditor,
              icon: const Icon(Icons.subject, color: _silver),
              label: const Text('Overview'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _gregorianSingleRow() {
    FilterChip chip(int n, String label) => FilterChip(
      label: Text(label),
      selected: _selectedWeekdays.contains(n),
      onSelected: (v) {
        setState(() {
          v ? _selectedWeekdays.add(n) : _selectedWeekdays.remove(n);
        });
        _applySelectionToDrafts();
      },
      selectedColor: _gold.withValues(alpha: 0.22),
      checkmarkColor: Colors.white,
      side: const BorderSide(color: silver, width: 1.25),
      labelStyle: const TextStyle(color: Colors.white),
      backgroundColor: const Color(0xFF1A1B1F),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const GlossyText(
          text: 'Gregorian rules',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          gradient: silverGloss,
        ),
        const SizedBox(height: 6),
        _toggleCustomizeButton(),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (var i = 0; i < 7; i++) chip(i + 1, _wdLabels[i])],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedWeekdays
                    ..clear()
                    ..addAll({1, 2, 3, 4, 5, 6, 7});
                });
                _applySelectionToDrafts();
              },
              child: const Text('Select all'),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                setState(() => _selectedWeekdays.clear());
                _applySelectionToDrafts();
              },
              child: const Text('Clear'),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _openOverviewEditor,
              icon: const Icon(Icons.subject, color: _silver),
              label: const Text('Overview'),
            ),
          ],
        ),
      ],
    );
  }

  // Per-period rows (decans or weeks)
  Widget _kemeticPerDecan() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const GlossyText(
          text: 'Kemetic rules • per decan',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          gradient: silverGloss,
        ),
        const SizedBox(height: 6),
        _toggleCustomizeButton(),
        const SizedBox(height: 8),
        Row(
          children: const [
            Spacer(),
            // keep spacing aligned with other sections
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _openOverviewEditor,
            icon: const Icon(Icons.subject, color: _silver),
            label: const Text('Overview'),
          ),
        ),
        const SizedBox(height: 8),
        if (_kemeticSpans.isEmpty)
          const Text(
            'No decans in this range.',
            style: TextStyle(color: Colors.white70),
          )
        else
          ..._kemeticSpans.map((s) {
            final sel = _perDecanSel[s.key] ?? <int>{};
            Widget chip(int n) {
              final enabled = n >= s.minDay && n <= s.maxDay;
              final selected = enabled && sel.contains(n);
              return FilterChip(
                label: Text('$n'),
                selected: selected,
                onSelected: !enabled
                    ? null
                    : (v) {
                        setState(() {
                          final set = _perDecanSel[s.key] ?? <int>{};
                          v ? set.add(n) : set.remove(n);
                          _perDecanSel[s.key] = set;
                        });
                        _applySelectionToDrafts();
                      },
                selectedColor: _gold.withValues(alpha: 0.22),
                checkmarkColor: Colors.white,
                side: BorderSide(color: enabled ? _silver : Colors.white12),
                labelStyle: TextStyle(
                  color: enabled ? Colors.white : Colors.white30,
                ),
                backgroundColor: const Color(0xFF1A1B1F),
              );
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.label, style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [for (var n = 1; n <= 10; n++) chip(n)],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _gregorianPerWeek() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const GlossyText(
          text: 'Gregorian rules • per week',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          gradient: silverGloss,
        ),
        const SizedBox(height: 6),
        _toggleCustomizeButton(),
        const SizedBox(height: 8),
        if (_weekSpans.isEmpty)
          const Text(
            'No weeks in this range.',
            style: TextStyle(color: Colors.white70),
          )
        else
          ..._weekSpans.map((w) {
            final label = 'Week of ${_fmtGregorian(w.monday)}';
            final sel = _perWeekSel[w.key] ?? <int>{};

            Widget chip(int wd, String lab) {
              final enabled = wd >= w.minWd && wd <= w.maxWd;
              final selected = enabled && sel.contains(wd);
              return FilterChip(
                label: Text(lab),
                selected: selected,
                onSelected: !enabled
                    ? null
                    : (v) {
                        setState(() {
                          final set = _perWeekSel[w.key] ?? <int>{};
                          v ? set.add(wd) : set.remove(wd);
                          _perWeekSel[w.key] = set;
                        });
                        _applySelectionToDrafts();
                      },
                selectedColor: _gold.withValues(alpha: 0.22),
                checkmarkColor: Colors.white,
                side: BorderSide(color: enabled ? _silver : Colors.white12),
                labelStyle: TextStyle(
                  color: enabled ? Colors.white : Colors.white30,
                ),
                backgroundColor: const Color(0xFF1A1B1F),
              );
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < 7; i++) chip(i + 1, _wdLabels[i]),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // Toggle between single row vs per-period rows
  Widget _toggleCustomizeButton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: !_hasFullRange
            ? null
            : () {
                setState(() {
                  // when turning on, seed per-period selections from single-row choice
                  if (!_splitByPeriod) {
                    if (_useKemetic) {
                      for (final s in _kemeticSpans) {
                        final base = _selectedDecanDays.where(
                          (n) => n >= s.minDay && n <= s.maxDay,
                        );
                        _perDecanSel[s.key] = {...base};
                      }
                    } else {
                      for (final w in _weekSpans) {
                        final base = _selectedWeekdays.where(
                          (n) => n >= w.minWd && n <= w.maxWd,
                        );
                        _perWeekSel[w.key] = {...base};
                      }
                    }
                  }
                  _splitByPeriod = !_splitByPeriod;
                });
                _applySelectionToDrafts();
              },
        icon: const Icon(Icons.tune, color: _silver),
        label: Text(
          _splitByPeriod
              ? (_useKemetic
                    ? 'Same days for all decans'
                    : 'Same days for every week')
              : (_useKemetic ? 'Customize per decan' : 'Customize per week'),
        ),
      ),
    );
  }

  // ---------- close handler ----------

  Future<void> _handleClose() async {
    // Close/cancel never deletes a flow. Deletion is only allowed through the
    // explicit Flow Studio delete action returned as _FlowStudioResult.
    if (!mounted || _closeInFlight) return;
    _closeInFlight = true;
    try {
      _suppressDraftSave = true;
      _draftPersistDebounce?.cancel();
      _sessionDraft = null;
      await CalendarPage._clearFlowStudioTransientState();
      if (!mounted) return;
      final routeCloseHandler = widget.onRouteClose;
      if (routeCloseHandler != null) {
        await routeCloseHandler();
        return;
      }
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
        return;
      }
      final rootNavigator = Navigator.of(context, rootNavigator: true);
      if (rootNavigator.canPop()) {
        rootNavigator.pop();
      }
    } finally {
      if (mounted) {
        _closeInFlight = false;
      }
    }
  }

  // ---------- build ----------

  @override
  Widget build(BuildContext context) {
    // ✅ Show loading indicator while loading flow from DB
    if (_isLoadingFlow) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0.5,
          leading: IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: _handleClose,
          ),
          title: const Text(
            'Flow Studio',
            style: TextStyle(color: Colors.white),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final selectedCalendarId =
        _selectedCalendarId ?? _editing?.calendarId ?? _defaultCalendarId();
    final selectedCalendar = selectedCalendarId == null
        ? null
        : _calendarPageState?._calendarSummariesById[selectedCalendarId];
    final canEditSelectedCalendar = _canEditCalendar(selectedCalendarId);
    final bodyPadding = EdgeInsets.fromLTRB(
      22,
      20,
      22,
      AppBottomInsets.contentBottomPadding(context),
    );
    const fieldScrollPadding = keyboardManagedTextFieldScrollPadding;
    final tone = _FlowStudioTone.resolve(_activeStudioColor);
    final studioChrome = Color.alphaBlend(
      tone.softenedAccent.withValues(alpha: 0.16),
      _bg,
    );

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: _bg,
      appBar: AppBar(
        toolbarHeight: 48,
        backgroundColor: studioChrome,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: IconButton(
            tooltip: 'Close',
            iconSize: 24,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            icon: const Icon(Icons.close, color: _gold),
            onPressed: _handleClose,
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            const Flexible(
              child: Text(
                'Flow Studio',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: TextStyle(
                  color: _gold,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'GentiumPlus',
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 32,
              height: 32,
              child: OutlinedButton(
                onPressed: _showAIGenerationModal,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _gold,
                  side: BorderSide(color: tone.ctaBorder),
                  backgroundColor: tone.ctaBg,
                  minimumSize: const Size(32, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Icon(Icons.auto_awesome, size: 16),
              ),
            ),
          ],
        ),
        actions: [
          if (_editing != null)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline, color: _silver, size: 22),
              onPressed: _delete,
            ),
          if (_studioMode == _FlowStudioMode.build)
            Padding(
              padding: const EdgeInsets.only(right: 22),
              child: SizedBox(
                width: 66,
                height: 36,
                child: TextButton(
                  onPressed: _save,
                  style: TextButton.styleFrom(
                    foregroundColor: _gold,
                    side: BorderSide(color: tone.ctaBorder),
                    backgroundColor: tone.ctaBg,
                    minimumSize: const Size(66, 36),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'GentiumPlus',
                    ),
                  ),
                ),
              ),
            ),
          if (widget.existingFlows.isNotEmpty)
            PopupMenuButton<int>(
              tooltip: 'Flows menu',
              icon: const Icon(Icons.more_vert, color: _silver, size: 22),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 220,
                maxWidth: 280,
              ),
              onSelected: (v) {
                if (v == 1) _openFlowPicker();
                if (v == 2) _clearEditorForNew();
                if (v == 3) _clearEditorForNew();
              },
              itemBuilder: (ctx) => const [
                PopupMenuItem(
                  value: 1,
                  child: ListTile(
                    leading: Icon(Icons.search),
                    title: Text('Find / Edit flows...'),
                  ),
                ),
                PopupMenuItem(
                  value: 2,
                  child: ListTile(
                    leading: Icon(Icons.add),
                    title: Text('New flow'),
                  ),
                ),
                PopupMenuItem(
                  value: 3,
                  child: ListTile(
                    leading: Icon(Icons.refresh),
                    title: Text('Reset fields'),
                  ),
                ),
              ],
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 22),
            height: 1,
            color: const Color(0xFF3A210F).withValues(alpha: 0.45),
          ),
        ),
      ),
      body: ListView(
        padding: bodyPadding,
        children: [
          _studioTopTintFade(tone),
          _studioModeToggle(tone),
          const SizedBox(height: 30),
          if (_studioMode == _FlowStudioMode.build) ...[
            _studioSectionLabel('Name'),
            const SizedBox(height: 18),
            TextField(
              controller: _nameCtrl,
              scrollPadding: fieldScrollPadding,
              style: const TextStyle(
                color: Color(0xFFF2E4C5),
                fontSize: 38,
                fontWeight: FontWeight.w700,
                fontFamily: 'GentiumPlus',
              ),
              decoration:
                  _studioInputDecoration(
                    tone: tone,
                    hint: 'FLOW TITLE',
                    radius: 4,
                  ).copyWith(
                    filled: false,
                    contentPadding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: tone.fieldBorder),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: tone.ctaBorder, width: 1.2),
                    ),
                  ),
            ),
            const SizedBox(height: 32),
            if (_isItineraryImport) ...[
              _itineraryImportBadge(),
              const SizedBox(height: 24),
            ],
            _colorStudioSection(tone),
            const SizedBox(height: 34),
            _studioSectionLabel('Overview'),
            const SizedBox(height: 12),
            SizedBox(
              height: 86,
              child: TextField(
                controller: _overviewCtrl,
                scrollPadding: fieldScrollPadding,
                style: const TextStyle(
                  color: Color(0xFFE8E1D5),
                  fontSize: 16,
                  height: 1.3,
                  fontStyle: FontStyle.italic,
                  fontFamily: 'GentiumPlus',
                ),
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                expands: true,
                maxLines: null,
                minLines: null,
                decoration:
                    _studioInputDecoration(
                      tone: tone,
                      hint:
                          'Describe the purpose, outcomes, links, or context.',
                    ).copyWith(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
              ),
            ),
            const SizedBox(height: 20),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _active,
              onChanged: (v) => setState(() => _active = v),
              title: _studioSectionLabel('Active'),
              activeThumbColor: tone.ctaText,
              activeTrackColor: tone.softenedAccent.withValues(alpha: 0.55),
            ),
            const Divider(color: Color(0x1FFFFFFF), height: 28),
            InkWell(
              onTap: !canEditSelectedCalendar
                  ? null
                  : () async {
                      await _ensureCalendarChoicesLoaded();
                      if (!context.mounted) return;
                      if (_selectedCalendarId == null) {
                        final defaultCalendarId = _defaultCalendarId();
                        if (defaultCalendarId != null) {
                          setState(() {
                            _selectedCalendarId = defaultCalendarId;
                          });
                        }
                      }
                      final calendars = _editableCalendars;
                      if (calendars.isEmpty) return;
                      final sheetContext = context;
                      final chosenId = await showCupertinoModalPopup<String>(
                        context: sheetContext,
                        builder: (popupCtx) {
                          return CupertinoActionSheet(
                            title: const GlossyText(
                              text: 'Calendar',
                              gradient: silverGloss,
                              style: TextStyle(fontSize: 18),
                            ),
                            actions: [
                              for (final calendar in calendars)
                                CupertinoActionSheetAction(
                                  onPressed: () {
                                    Navigator.of(popupCtx).pop(calendar.id);
                                  },
                                  child: Text(
                                    calendar.name,
                                    style: TextStyle(
                                      color: calendar.color,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                            cancelButton: CupertinoActionSheetAction(
                              isDestructiveAction: true,
                              onPressed: () => Navigator.of(popupCtx).pop(),
                              child: const Text('Cancel'),
                            ),
                          );
                        },
                      );
                      if (chosenId == null) return;
                      setState(() {
                        _selectedCalendarId = chosenId;
                      });
                    },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _studioSectionLabel('Calendar'),
                    Row(
                      children: [
                        Text(
                          _calendarLabelFor(selectedCalendarId),
                          style: TextStyle(
                            color: selectedCalendar?.color ?? _gold,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'GentiumPlus',
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: Color(0xFF6F604A),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (!canEditSelectedCalendar) ...[
              const SizedBox(height: 4),
              const Text(
                'You can view this calendar, but you cannot edit it.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
            const Divider(color: Color(0x1FFFFFFF), height: 28),
            Row(
              children: [
                _studioSectionLabel('System'),
                const Spacer(),
                Flexible(
                  fit: FlexFit.loose,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 200),
                    child: _modeToggle(tone),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 34),
            _dateRangeSection(),
            const SizedBox(height: 12),
            if (!_hasFullRange)
              _preRulesHint()
            else if (_useKemetic)
              (_splitByPeriod ? _kemeticPerDecan() : _kemeticSingleRow())
            else
              (_splitByPeriod ? _gregorianPerWeek() : _gregorianSingleRow()),
            SizedBox(key: _editorsAnchorKey, height: 0),
            _notesEditorsPanel(),
            const SizedBox(height: 24),
            _studioCta(
              key: const ValueKey('flow-studio-save-cta'),
              tone: tone,
              text: 'Save Flow',
              onPressed: _save,
            ),
          ] else ...[
            _colorStudioSection(tone),
            const SizedBox(height: 34),
            _studioSectionLabel('Describe your flow'),
            const SizedBox(height: 12),
            SizedBox(
              height: 176,
              child: TextField(
                controller: _composePromptCtrl,
                scrollPadding: fieldScrollPadding,
                expands: true,
                maxLines: null,
                minLines: null,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(
                  color: Color(0xFFE8E1D5),
                  fontSize: 18,
                  height: 1.36,
                  fontStyle: FontStyle.italic,
                  fontFamily: 'GentiumPlus',
                ),
                decoration:
                    _studioInputDecoration(
                      tone: tone,
                      hint: 'Describe what you want this flow to become.',
                    ).copyWith(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                    ),
              ),
            ),
            const SizedBox(height: 34),
            Row(
              children: [
                _studioSectionLabel('System'),
                const Spacer(),
                Flexible(
                  fit: FlexFit.loose,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 200),
                    child: _composeSystemToggle(tone),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 34),
            _composeDateRangeSection(tone),
            if (_composeError != null) ...[
              const SizedBox(height: 18),
              Text(
                _composeError!,
                style: const TextStyle(
                  color: Color(0xFFFFA99A),
                  fontSize: 13,
                  height: 1.25,
                ),
              ),
            ],
            const SizedBox(height: 34),
            _studioCta(
              key: const ValueKey('flow-studio-shape-cta'),
              tone: tone,
              text: 'Shape this flow',
              onPressed: () => unawaited(_shapeComposeFlow()),
              busy: _composeGenerating,
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              key: const ValueKey('flow-studio-build-manually'),
              onPressed: _composeGenerating
                  ? null
                  : _switchComposeToManualBuild,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Build manually'),
              style: TextButton.styleFrom(foregroundColor: tone.ctaText),
            ),
            const SizedBox(height: 4),
            const Text(
              'Save becomes available in Build mode.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF8F8270),
                fontSize: 12,
                height: 1.2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/* ---------------- Flow Preview Page (read-only) ---------------- */
