import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile/data/profile_repo.dart';
import 'package:mobile/data/shared_calendar_models.dart';
import 'package:mobile/features/calendar/calendar_page.dart' show KemeticMath;
import 'package:mobile/features/calendar/end_flow_diagnostics.dart';
import 'package:mobile/features/calendar/kemetic_month_metadata.dart';
import 'package:mobile/features/calendar/maat_flow_identity.dart';
import 'package:mobile/features/calendar/maat_flow_temporal_controller.dart';
import 'package:mobile/features/calendar/maat_flow_temporal_policy.dart';
import 'package:mobile/features/calendar/maat_flow_temporal_resolver.dart';
import 'package:mobile/features/calendar/maat_flow_visual_tokens.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_detail_shell.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_thirty_day_calendar.dart';
import 'package:mobile/features/calendar/the_reading_house_flow.dart';
import 'package:mobile/features/calendar/track_sky_flow.dart';
import 'package:mobile/widgets/keyboard_aware.dart';

import '../reading_house_authority.dart';
import 'reading_house_sitting_editor.dart';

abstract final class ReadingHouseDetailTokens {
  static const Color pageBackground = Color(0xFF050504);
  static const Color sheetBackground = Color(0xFF080907);
  static const Color bone = Color(0xFFE8E2D6);
  static const Color gold = Color(0xFFD4AE43);
  static const Color goldDim = Color(0xFF8A7030);
  static const Color silver = Color(0xFF9E9A94);
  static const Color silverLow = Color(0xFF6A6660);
  static const Color house = Color(0xFF3FA98A);
  static const Color houseHighlight = Color(0xFF7FD9BC);
  static const Color houseDeep = Color(0xFF17362E);
  static const Color separator = Color(0xFF1E2A24);
  static const String heroAsset = 'assets/the_reading_house/hero.png';
  static const Alignment heroImageAlignment = Alignment(-0.18, 0);

  static const MaatFlowDetailTheme theme = MaatFlowDetailTheme(
    pageBackground: pageBackground,
    sheetBackground: sheetBackground,
    sheetBorder: Color(0x5C3FA98A),
    accent: house,
    primaryText: bone,
    secondaryText: silver,
    mutedText: silverLow,
    separator: separator,
    glow: houseHighlight,
  );

  static const MaatFlowThirtyDayCalendarTheme calendarTheme =
      MaatFlowThirtyDayCalendarTheme(
        introText: bone,
        introEmphasis: silver,
        border: Color(0x3D3FA98A),
        month: house,
        monthTransliteration: Color(0xFF507565),
        decan: Color(0xFF557566),
        day: Color(0xFF788079),
        today: houseHighlight,
        highlight: houseHighlight,
      );
}

class ReadingHouseDetailPage extends StatefulWidget {
  const ReadingHouseDetailPage({
    super.key,
    required this.timezone,
    this.initialStartDate,
    this.initialPlan = const ReadingHousePlan(),
    this.initialSittings = kReadingHouseSittings,
    this.initiallyHeld = false,
    this.initialFlowId,
    this.initialCalendarId,
    this.initialOpenDoors = false,
    this.initialSnapshot,
    this.authority,
    this.resolvePersonalCalendarId,
    this.onHeld,
    this.onPersisted,
    this.onEndFlow,
    this.showBackButton = true,
    this.backFallbackLocation = kMaatFlowsListRoute,
    this.resizeToAvoidBottomInset = true,
    this.clock,
    this.presentDayIanaTimeZone,
    this.ianaTimeZoneProvider,
    this.temporalScheduler,
  });

  final TrackSkyTimeZone timezone;
  final DateTime? initialStartDate;
  final ReadingHousePlan initialPlan;
  final List<ReadingHouseSitting> initialSittings;
  final bool initiallyHeld;
  final int? initialFlowId;
  final String? initialCalendarId;
  final bool initialOpenDoors;
  final ReadingHouseSnapshot? initialSnapshot;
  final ReadingHouseAuthority? authority;
  final Future<String?> Function()? resolvePersonalCalendarId;
  final ValueChanged<int>? onHeld;
  final Future<void> Function(ReadingHouseSnapshot snapshot)? onPersisted;
  final Future<EndFlowOutcome> Function(int flowId)? onEndFlow;
  final bool showBackButton;
  final String backFallbackLocation;
  final bool resizeToAvoidBottomInset;
  final MaatFlowClock? clock;
  final String? presentDayIanaTimeZone;
  final MaatFlowIanaTimeZoneProvider? ianaTimeZoneProvider;
  final MaatFlowTemporalScheduler? temporalScheduler;

  @override
  State<ReadingHouseDetailPage> createState() => _ReadingHouseDetailPageState();
}

class _ReadingHouseDetailPageState extends State<ReadingHouseDetailPage> {
  late final TextEditingController _bookController;
  late final TextEditingController _editionController;
  late final TextEditingController _questionController;
  final ScrollController _scrollController = ScrollController();
  late DateTime _windowStart;
  late MaatFlowTemporalController _temporalController;
  late List<ReadingHouseSitting> _sittings;
  late bool _withReaders;
  late bool _held;
  late bool _openDoors;
  int? _flowId;
  String? _calendarId;
  List<SharedCalendarMember> _members = const <SharedCalendarMember>[];
  bool _canEdit = true;
  bool _canManageMembership = true;
  bool _loadingHouse = false;
  bool _holding = false;
  bool _savingMode = false;
  bool _savingDoors = false;
  bool _placingReading = false;
  bool _addingSitting = false;
  bool _endingHouse = false;
  bool _applyingSnapshot = false;
  int _detailsSaveSerial = 0;
  int _memberRefreshSerial = 0;
  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();
    final initialSnapshot = widget.initialSnapshot;
    final initialPlan = initialSnapshot?.plan ?? widget.initialPlan;
    final initialBook = initialPlan.bookTitle.trim();
    _bookController = TextEditingController(
      text: initialBook == kReadingHouseDefaultBookTitle ? '' : initialBook,
    );
    _editionController = TextEditingController(text: initialPlan.editionNote);
    _questionController = TextEditingController(
      text: initialPlan.houseQuestion == kReadingHouseDefaultQuestion
          ? ''
          : initialPlan.houseQuestion,
    );
    _sittings = List<ReadingHouseSitting>.of(
      initialSnapshot?.sittings ?? widget.initialSittings,
    );
    _withReaders = !(initialSnapshot?.plan ?? widget.initialPlan).isSolo;
    _held = initialSnapshot?.held ?? widget.initiallyHeld;
    _openDoors = initialSnapshot?.openDoors ?? widget.initialOpenDoors;
    _flowId = initialSnapshot?.flowId ?? widget.initialFlowId;
    _calendarId = initialSnapshot?.calendarId ?? widget.initialCalendarId;
    _temporalController = _createTemporalController()..start();
    _temporalController.addListener(_handleTemporalChange);
    _windowStart = _temporalController.renderedStartDate;
    _members = initialSnapshot?.members ?? const <SharedCalendarMember>[];
    _canEdit = initialSnapshot?.canEdit ?? true;
    _canManageMembership = initialSnapshot?.canManageMembership ?? true;
    _bookController.addListener(_scheduleProgressiveSave);
    _editionController.addListener(_scheduleProgressiveSave);
    _questionController.addListener(_scheduleProgressiveSave);
    if (initialSnapshot == null &&
        _flowId != null &&
        widget.authority != null) {
      unawaited(_loadHouse());
    }
  }

  @override
  void didUpdateWidget(covariant ReadingHouseDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.clock != oldWidget.clock ||
        widget.presentDayIanaTimeZone != oldWidget.presentDayIanaTimeZone ||
        widget.ianaTimeZoneProvider != oldWidget.ianaTimeZoneProvider ||
        widget.temporalScheduler != oldWidget.temporalScheduler) {
      _replaceTemporalController();
    }
    if (widget.initialStartDate != oldWidget.initialStartDate &&
        widget.initialStartDate != null &&
        !_held) {
      _temporalController.lockExplicitDate(widget.initialStartDate!);
    }
  }

  @override
  void dispose() {
    _temporalController.removeListener(_handleTemporalChange);
    _temporalController.dispose();
    _saveDebounce?.cancel();
    _scrollController.dispose();
    _bookController.dispose();
    _editionController.dispose();
    _questionController.dispose();
    super.dispose();
  }

  MaatFlowTemporalContext get _temporalContext => _temporalController.context;

  MaatFlowTemporalController _createTemporalController() {
    final persistedDates =
        _sittings
            .map((sitting) => sitting.scheduledDate)
            .whereType<DateTime>()
            .map(DateUtils.dateOnly)
            .toList()
          ..sort();
    final carried = _held || _flowId != null || persistedDates.isNotEmpty;
    return MaatFlowTemporalController(
      ianaTimeZone:
          widget.presentDayIanaTimeZone ??
          MaatFlowDeviceTimeZone.currentIanaTimeZone,
      ianaTimeZoneProvider:
          widget.ianaTimeZoneProvider ??
          (widget.presentDayIanaTimeZone == null
              ? MaatFlowDeviceTimeZone.refresh
              : () async => widget.presentDayIanaTimeZone!),
      clock: widget.clock ?? maatFlowSystemClock,
      scheduler: widget.temporalScheduler ?? scheduleMaatFlowTemporalCallback,
      resolve: (context) => const MaatFlowTemporalResolver().resolve(
        kind: MaatFlowKind.readingHouse,
        context: context,
      ),
      explicitStartDate: carried
          ? (persistedDates.isNotEmpty
                ? persistedDates.first
                : widget.initialStartDate)
          : widget.initialStartDate,
      carried: carried,
    );
  }

  void _replaceTemporalController() {
    final old = _temporalController;
    final explicitDate = old.isExplicitlyLocked ? old.renderedStartDate : null;
    old.removeListener(_handleTemporalChange);
    old.dispose();
    _temporalController = _createTemporalController();
    if (explicitDate != null && !_held) {
      _temporalController.lockExplicitDate(explicitDate);
    }
    _temporalController.addListener(_handleTemporalChange);
    _temporalController.start();
    _windowStart = _temporalController.renderedStartDate;
  }

  void _handleTemporalChange() {
    if (!mounted) return;
    setState(() {
      _windowStart = _temporalController.renderedStartDate;
    });
  }

  int get _placedCount =>
      _sittings.where((sitting) => sitting.scheduledDate != null).length;

  List<MaatFlowThirtyDayMarker> _calendarMarkers() {
    final markers = <DateTime, MaatFlowThirtyDayMarker>{};
    final today = _temporalContext.presentLocalDate;
    final end = _windowStart.add(const Duration(days: 29));
    if (!today.isBefore(_windowStart) && !today.isAfter(end)) {
      markers[today] = MaatFlowThirtyDayMarker(date: today, isToday: true);
    }
    for (final sitting in _sittings) {
      final scheduledDate = sitting.scheduledDate;
      if (scheduledDate == null) continue;
      final date = DateUtils.dateOnly(scheduledDate);
      if (date.isBefore(_windowStart) || date.isAfter(end)) continue;
      markers[date] = MaatFlowThirtyDayMarker(
        date: date,
        isToday: DateUtils.isSameDay(date, today),
        highlighted: true,
        filled: true,
        accent: ReadingHouseDetailTokens.houseHighlight,
        topLabel: 'SITTING ${sitting.eventNumber.toString().padLeft(2, '0')}',
      );
    }
    return markers.values.toList(growable: false);
  }

  ReadingHousePlan get _plan =>
      (widget.initialSnapshot?.plan ?? widget.initialPlan).copyWith(
        bookTitle: _bookController.text.trim(),
        editionNote: _editionController.text.trim(),
        houseQuestion: _questionController.text.trim(),
        mode: _withReaders ? kReadingHouseDefaultMode : kReadingHouseSoloMode,
      );

  void _applySnapshot(ReadingHouseSnapshot snapshot) {
    _applyingSnapshot = true;
    try {
      _flowId = snapshot.flowId;
      _calendarId = snapshot.calendarId;
      _held = snapshot.held;
      _withReaders = !snapshot.plan.isSolo;
      _openDoors = snapshot.openDoors;
      _sittings = List<ReadingHouseSitting>.of(snapshot.sittings);
      final persistedDates =
          _sittings
              .map((sitting) => sitting.scheduledDate)
              .whereType<DateTime>()
              .map(DateUtils.dateOnly)
              .toList()
            ..sort();
      if (persistedDates.isNotEmpty) _windowStart = persistedDates.first;
      if (snapshot.held) {
        _temporalController.lockCarried(
          persistedStartDate: persistedDates.isEmpty
              ? _windowStart
              : persistedDates.first,
          notify: false,
        );
      }
      _members = snapshot.members;
      _canEdit = snapshot.canEdit;
      _canManageMembership = snapshot.canManageMembership;
      final book = snapshot.plan.bookTitle.trim();
      _replaceControllerText(
        _bookController,
        book == kReadingHouseDefaultBookTitle ? '' : book,
      );
      _replaceControllerText(_editionController, snapshot.plan.editionNote);
      final question = snapshot.plan.houseQuestion.trim();
      _replaceControllerText(
        _questionController,
        question == kReadingHouseDefaultQuestion ? '' : question,
      );
    } finally {
      _applyingSnapshot = false;
    }
  }

  void _replaceControllerText(
    TextEditingController controller,
    String nextText,
  ) {
    if (controller.text == nextText) return;
    controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
    );
  }

  Future<void> _loadHouse() async {
    final authority = widget.authority;
    final flowId = _flowId;
    if (authority == null || flowId == null || flowId <= 0) return;
    setState(() => _loadingHouse = true);
    try {
      final snapshot = await authority.load(
        flowId: flowId,
        fallbackPlan: _plan,
        fallbackSittings: _sittings,
      );
      if (!mounted) return;
      setState(() => _applySnapshot(snapshot));
    } catch (error) {
      _showError('Could not load this Reading House: $error');
    } finally {
      if (mounted) setState(() => _loadingHouse = false);
    }
  }

  void _scheduleProgressiveSave() {
    if (_applyingSnapshot || !_held || !_canEdit) return;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(
      const Duration(milliseconds: 450),
      () => unawaited(_persistDetails()),
    );
  }

  ReadingHouseSnapshot get _currentSnapshot => ReadingHouseSnapshot(
    flowId: _flowId,
    calendarId: _calendarId,
    plan: _plan,
    sittings: _sittings,
    openDoors: _openDoors,
    members: _members,
    held: _held,
    canEdit: _canEdit,
    canManageMembership: _canManageMembership,
    isSharedHouse: _withReaders,
  );

  Future<String> _personalCalendarId() async {
    final resolved = await widget.resolvePersonalCalendarId?.call();
    final calendarId = resolved?.trim();
    if (calendarId == null || calendarId.isEmpty) {
      throw StateError('Your personal calendar is unavailable.');
    }
    return calendarId;
  }

  Future<void> _persistDetails() async {
    final authority = widget.authority;
    if (authority == null || !_held || !_canEdit) return;
    final serial = ++_detailsSaveSerial;
    final house = _currentSnapshot;
    try {
      await authority.updateHeldHouse(
        house: house,
        plan: house.plan,
        sittings: house.sittings,
        openDoors: house.openDoors,
        timezone: widget.timezone,
      );
      if (!mounted || serial != _detailsSaveSerial) return;
    } catch (error) {
      if (!mounted || serial != _detailsSaveSerial) return;
      _showError('Could not save this Reading House: $error');
    }
  }

  Future<ReadingHouseSnapshot?> _holdHouse() async {
    if (_held) return _currentSnapshot;
    final authority = widget.authority;
    if (authority == null || !_canEdit || _holding || _loadingHouse) {
      return null;
    }
    _saveDebounce?.cancel();
    setState(() => _holding = true);
    try {
      final snapshot = await authority.ensureHouse(
        flowId: _flowId,
        calendarId: _calendarId,
        personalCalendarId: await _personalCalendarId(),
        plan: _plan,
        sittings: _sittings,
        openDoors: _openDoors,
        timezone: widget.timezone,
      );
      if (!mounted) return snapshot;
      setState(() => _applySnapshot(snapshot));
      if (snapshot.flowId != null) widget.onHeld?.call(snapshot.flowId!);
      _notifyPersistedInBackground(snapshot);
      return snapshot;
    } catch (error) {
      _showError('Could not hold this Reading House: $error');
      return null;
    } finally {
      if (mounted) setState(() => _holding = false);
    }
  }

  Future<void> _changeMode(bool withReaders) async {
    if (!_canEdit || _savingMode || _withReaders == withReaders) return;
    if (!withReaders && _members.any((member) => !member.isOwner)) {
      _showError(
        'Remove invited readers before changing this house to Solo study.',
      );
      return;
    }
    if (!_held) {
      setState(() {
        _withReaders = withReaders;
        if (!withReaders) _openDoors = false;
      });
      return;
    }

    final authority = widget.authority;
    if (authority == null) return;
    _saveDebounce?.cancel();
    setState(() => _savingMode = true);
    try {
      final nextPlan = _plan.copyWith(
        mode: withReaders ? kReadingHouseDefaultMode : kReadingHouseSoloMode,
      );
      final snapshot = await authority.ensureHouse(
        flowId: _flowId,
        calendarId: _calendarId,
        personalCalendarId: await _personalCalendarId(),
        plan: nextPlan,
        sittings: _sittings,
        openDoors: withReaders && _openDoors,
        timezone: widget.timezone,
      );
      if (!mounted) return;
      setState(() => _applySnapshot(snapshot));
      _notifyPersistedInBackground(snapshot);
    } catch (error) {
      _showError('Could not change how this house is read: $error');
    } finally {
      if (mounted) setState(() => _savingMode = false);
    }
  }

  Future<void> _changeDoors(bool openDoors) async {
    if (!_canEdit || _savingDoors || _openDoors == openDoors) return;
    if (!_held) {
      setState(() => _openDoors = openDoors);
      return;
    }

    final authority = widget.authority;
    if (authority == null) return;
    _saveDebounce?.cancel();
    setState(() => _savingDoors = true);
    try {
      final house = _currentSnapshot;
      final snapshot = await authority.updateHeldHouse(
        house: house,
        plan: house.plan,
        sittings: house.sittings,
        openDoors: openDoors,
        timezone: widget.timezone,
      );
      if (!mounted) return;
      setState(() => _openDoors = snapshot.openDoors);
    } catch (error) {
      _showError('Could not change the doors: $error');
    } finally {
      if (mounted) setState(() => _savingDoors = false);
    }
  }

  Future<void> _placeReading() async {
    if (!_canEdit || _placingReading) return;
    final resolvedDates = readingHouseResolvedStarterDates(
      _windowStart,
      _sittings,
    );
    final next = <ReadingHouseSitting>[
      for (var index = 0; index < _sittings.length; index++)
        if (_sittings[index].scheduledDate != null)
          _sittings[index]
        else
          _sittings[index].copyWith(scheduledDate: resolvedDates[index]),
    ];
    if (!_held) {
      setState(() => _sittings = next);
      return;
    }

    final authority = widget.authority;
    if (authority == null) return;
    _saveDebounce?.cancel();
    setState(() => _placingReading = true);
    try {
      final snapshot = await authority.ensureHouse(
        flowId: _flowId,
        calendarId: _calendarId,
        personalCalendarId: await _personalCalendarId(),
        plan: _plan,
        sittings: next,
        openDoors: _openDoors,
        timezone: widget.timezone,
      );
      if (!mounted) return;
      setState(() => _applySnapshot(snapshot));
      _notifyPersistedInBackground(snapshot);
    } catch (error) {
      _showError('Could not place this reading: $error');
    } finally {
      if (mounted) setState(() => _placingReading = false);
    }
  }

  Future<void> _inviteReader() async {
    if (!_held) {
      final held = await _holdHouse();
      if (held == null || !mounted) return;
    }
    final authority = widget.authority;
    if (authority == null || !_canManageMembership) return;
    final excluded = <String>{for (final member in _members) member.userId};
    FocusManager.instance.primaryFocus?.unfocus();
    final invited = await showEditableModalBottomSheet<SharedCalendarMember>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReaderInviteSheet(
        authority: authority,
        excludedUserIds: excluded,
        onInvite: (reader) =>
            authority.inviteReader(house: _currentSnapshot, reader: reader),
      ),
    );
    FocusManager.instance.primaryFocus?.unfocus();
    if (invited == null || !mounted) return;
    setState(() => _members = _upsertMember(_members, invited));
    unawaited(_refreshMembersInBackground());
  }

  List<SharedCalendarMember> _upsertMember(
    List<SharedCalendarMember> current,
    SharedCalendarMember member,
  ) {
    return List<SharedCalendarMember>.unmodifiable(<SharedCalendarMember>[
      for (final existing in current)
        if (existing.userId != member.userId) existing,
      member,
    ]);
  }

  Future<void> _refreshMembersInBackground() async {
    final authority = widget.authority;
    if (authority == null || !_held || !_withReaders) return;
    final serial = ++_memberRefreshSerial;
    try {
      final members = await authority.refreshMembers(house: _currentSnapshot);
      if (!mounted || serial != _memberRefreshSerial) return;
      setState(() => _members = members);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[ReadingHouse] member reconciliation failed: $error');
        debugPrint('$stackTrace');
      }
    }
  }

  void _notifyPersistedInBackground(ReadingHouseSnapshot snapshot) {
    unawaited(_notifyPersisted(snapshot));
  }

  Future<void> _endHouse() async {
    final endFlow = widget.onEndFlow;
    final flowId = _flowId;
    if (!_held ||
        !_canEdit ||
        _endingHouse ||
        endFlow == null ||
        flowId == null ||
        flowId <= 0) {
      return;
    }

    _saveDebounce?.cancel();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _endingHouse = true);
    final navigator = Navigator.of(context);
    try {
      final outcome = await endFlow(flowId);
      if (!mounted) return;
      if (outcome.result != EndFlowActionResult.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(endFlowFailureDisplayMessage(outcome)),
            action: SnackBarAction(
              label: 'Copy diagnostics',
              onPressed: () => unawaited(
                EndFlowDiagnostics.instance.copyTerminalDiagnostics(
                  outcome.operationId,
                ),
              ),
            ),
          ),
        );
        return;
      }
      navigator.pop();
    } finally {
      if (mounted) setState(() => _endingHouse = false);
    }
  }

  Future<void> _notifyPersisted(ReadingHouseSnapshot snapshot) async {
    final callback = widget.onPersisted;
    if (callback == null) return;
    try {
      await callback(snapshot);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[ReadingHouse] post-save refresh failed: $error');
        debugPrint('$stackTrace');
      }
    }
  }

  Future<void> _openSitting(ReadingHouseSitting sitting) async {
    if (!_canEdit) return;
    final returnOffset = _scrollController.hasClients
        ? _scrollController.offset
        : null;
    await ReadingHouseSittingEditorSheet.show(
      context,
      sitting: sitting,
      initialDate: sitting.scheduledDate ?? _windowStart,
      initialTime: TimeOfDay(hour: sitting.hour, minute: sitting.minute),
      flowDayForDate: (date) =>
          date.difference(DateUtils.dateOnly(_windowStart)).inDays + 1,
      accentColor: ReadingHouseDetailTokens.houseHighlight,
      borderColor: const Color(0x664FA58D),
      onSave: (edited) => _saveSitting(sitting, edited),
    );
    await Future<void>.delayed(kThemeAnimationDuration);
    if (!mounted || returnOffset == null || !_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    position.jumpTo(
      returnOffset.clamp(position.minScrollExtent, position.maxScrollExtent),
    );
  }

  Future<bool> _saveSitting(
    ReadingHouseSitting original,
    ReadingHouseSitting edited,
  ) async {
    final next = editReadingHouseSitting(
      _sittings,
      original.eventNumber,
      edited,
    );
    if (!_held) {
      if (mounted) setState(() => _sittings = next);
      return true;
    }
    final authority = widget.authority;
    if (authority == null) return false;
    _saveDebounce?.cancel();
    try {
      final snapshot = await authority.saveSitting(
        house: _currentSnapshot,
        sitting: edited,
        sittings: next,
        timezone: widget.timezone,
      );
      if (!mounted) return true;
      setState(() {
        _sittings = editReadingHouseSitting(
          _sittings,
          edited.eventNumber,
          snapshot.sittings.firstWhere(
            (candidate) => candidate.eventNumber == edited.eventNumber,
          ),
        );
      });
      _notifyPersistedInBackground(snapshot);
      return true;
    } catch (error) {
      _showError('Could not save this sitting: $error');
      return false;
    }
  }

  Future<void> _addSitting() async {
    if (!_canEdit || _addingSitting) return;
    final next = addReadingHouseSitting(_sittings);
    final added = next.last;
    if (_held) {
      final authority = widget.authority;
      if (authority == null) return;
      setState(() => _addingSitting = true);
      try {
        final snapshot = await authority.saveSitting(
          house: _currentSnapshot,
          sitting: added,
          sittings: next,
          timezone: widget.timezone,
        );
        if (!mounted) return;
        setState(() => _sittings = List.of(snapshot.sittings));
      } catch (error) {
        _showError('Could not add this sitting: $error');
        return;
      } finally {
        if (mounted) setState(() => _addingSitting = false);
      }
    } else {
      setState(() => _sittings = next);
    }
    if (!mounted) return;
    await _openSitting(added);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final body = MaatFlowDetailShell(
      theme: ReadingHouseDetailTokens.theme,
      scrollController: _scrollController,
      scrollKey: const ValueKey<String>('reading-house-scroll'),
      heroLayerKey: const ValueKey<String>('reading-house-hero-layer'),
      sheetKey: const ValueKey<String>('reading-house-sheet'),
      hero: const _ReadingHouseHero(),
      bottomDock: !_canEdit
          ? null
          : MaatFlowDetailDock(
              theme: ReadingHouseDetailTokens.theme,
              joined: _held,
              busy: _holding || _endingHouse,
              onPressed: !_loadingHouse ? _holdHouse : null,
              onJoinedPressed:
                  !_loadingHouse && widget.onEndFlow != null && _flowId != null
                  ? () => unawaited(_endHouse())
                  : null,
              actionLabel: 'Hold this house',
              actionNote:
                  'This creates the house in My Flows. You do not need to schedule it yet.',
              joinedLabel: widget.onEndFlow == null
                  ? 'Held in your flows'
                  : 'End this house',
              joinedNote: widget.onEndFlow == null
                  ? 'This house can stay partial while readers respond. Nothing needs to be scheduled yet.'
                  : 'Removes this house and its scheduled sittings so you can begin again.',
              actionKey: const ValueKey<String>('reading-house-hold'),
              joinedKey: const ValueKey<String>('reading-house-held'),
            ),
      sheet: _buildSheet(context),
    );

    return Scaffold(
      resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
      backgroundColor: ReadingHouseDetailTokens.pageBackground,
      body: KeyboardAwareEditableSurface(
        child: Stack(
          children: [
            body,
            if (widget.showBackButton)
              Positioned(
                top: MediaQuery.paddingOf(context).top + 4,
                left: 4,
                child: BackButton(
                  key: const ValueKey<String>('reading-house-back'),
                  color: ReadingHouseDetailTokens.gold,
                  onPressed: () => popMaatFlowDetailOrGo(
                    context,
                    fallbackLocation: widget.backFallbackLocation,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSheet(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SheetHandle(),
        const _BeforeCalendarIntro(),
        _buildHouseSetup(),
        _buildCalendar(),
        _buildSittings(context),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _questionController,
          builder: (context, _, child) =>
              _ReadingFrame(question: _plan.displayQuestion),
        ),
        const _HistoricalContext(),
      ],
    );
  }

  Widget _buildHouseSetup() {
    SharedCalendarMember? host;
    for (final member in _members) {
      if (member.isOwner) {
        host = member;
        break;
      }
    }
    final currentUserId = widget.authority?.currentUserId;
    final hostName = host == null
        ? (_canManageMembership ? 'You' : 'House host')
        : host.userId == currentUserId
        ? 'You'
        : host.displayLabel;
    final hostInitials = host == null ? 'H' : _memberInitials(host);
    final invitedReaders = _members
        .where(
          (member) =>
              member.userId != widget.authority?.currentUserId &&
              !member.isOwner,
        )
        .toList(growable: false);
    final pendingCount = invitedReaders
        .where((member) => member.isPending)
        .length;
    final inviteSummary = pendingCount == 0
        ? 'No invites yet'
        : pendingCount == 1
        ? '1 invite pending'
        : '$pendingCount invites pending';
    return Container(
      key: const ValueKey<String>('reading-house-setup'),
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 30),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: ReadingHouseDetailTokens.separator),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SetupTextField(
            label: 'YOU’RE READING',
            hintText: 'Name the book',
            controller: _bookController,
            enabled: _canEdit,
            readOnlyValue: _plan.displayBookTitle,
            topPadding: 0,
            fieldKey: const ValueKey<String>('reading-house-book'),
          ),
          _SetupTextField(
            label: 'EDITION / TRANSLATION',
            trailing: 'can skip',
            hintText: 'Translator, edition, or link',
            controller: _editionController,
            enabled: _canEdit,
            readOnlyValue: _plan.editionNote,
            fieldKey: const ValueKey<String>('reading-house-edition'),
          ),
          _SetupTextField(
            label: 'THE QUESTION THIS HOUSE WILL HOLD',
            trailing: 'can skip',
            hintText: 'What would you do if you could live forever?',
            controller: _questionController,
            enabled: _canEdit,
            readOnlyValue: _plan.displayQuestion,
            fieldKey: const ValueKey<String>('reading-house-question'),
          ),
          _SetupChoiceField(
            label: 'HOW WILL YOU READ?',
            firstLabel: 'Solo study',
            secondLabel: 'With readers · recommended',
            secondSelected: _withReaders,
            onFirst: !_canEdit || _savingMode
                ? null
                : () => unawaited(_changeMode(false)),
            onSecond: !_canEdit || _savingMode
                ? null
                : () => unawaited(_changeMode(true)),
            note: _withReaders
                ? 'Everyone who accepts sees this same house, even before it has dates.'
                : 'A solo house stays with you and your private calendar.',
            fieldKey: const ValueKey<String>('reading-house-mode'),
            busy: _savingMode,
            readOnly: !_canEdit,
          ),
          IgnorePointer(
            ignoring: !_withReaders,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: _withReaders ? 1 : 0.32,
              child: _SetupChoiceField(
                label: 'WHO CAN SEE THIS HOUSE?',
                firstLabel: 'Closed · invite only',
                secondLabel: 'Open · appears in the Commons',
                secondSelected: _openDoors,
                onFirst: !_canEdit || _savingDoors
                    ? null
                    : () => unawaited(_changeDoors(false)),
                onSecond: !_canEdit || _savingDoors
                    ? null
                    : () => unawaited(_changeDoors(true)),
                note: _openDoors
                    ? 'Community members can discover this house in the Commons.'
                    : 'Closed houses only appear to people you invite.',
                highlightedNote: _openDoors,
                fieldKey: const ValueKey<String>('reading-house-doors'),
                busy: _savingDoors,
                readOnly: !_canEdit,
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: !_withReaders
                ? const SizedBox.shrink()
                : Padding(
                    key: const ValueKey<String>('reading-house-readers'),
                    padding: const EdgeInsets.only(top: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const _UpperLabel('READERS'),
                            Text(
                              inviteSummary,
                              style: _uiStyle(
                                color: ReadingHouseDetailTokens.house,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _ReaderRow(
                          initials: hostInitials,
                          name: hostName,
                          status: 'HOST',
                          host: true,
                        ),
                        for (final reader in invitedReaders) ...[
                          const SizedBox(height: 12),
                          _ReaderRow(
                            initials: _memberInitials(reader),
                            name: reader.displayLabel,
                            status: reader.isPending ? 'INVITED' : 'ACCEPTED',
                          ),
                        ],
                        if (invitedReaders.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 43, top: 12),
                            child: Text(
                              'No one else is here yet.',
                              style: _uiStyle(
                                color: const Color(0xFF59635E),
                                fontSize: 12.5,
                                fontStyle: FontStyle.italic,
                                height: 1.35,
                              ),
                            ),
                          ),
                        if (_canManageMembership) ...[
                          const SizedBox(height: 16),
                          _DashedPillButton(
                            key: const ValueKey<String>(
                              'reading-house-invite-reader',
                            ),
                            label: '+ Invite someone',
                            onTap: () => unawaited(_inviteReader()),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 22),
          _HouseStateLine(
            held: _held,
            openDoors: _openDoors && _withReaders,
            invitedCount: _withReaders ? pendingCount : 0,
            placedCount: _placedCount,
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    final waiting = _sittings.length - _placedCount;
    final waitingCopy = waiting <= 0
        ? 'Every sitting has a date. You can still move each one later.'
        : '${_countWord(waiting)} ${waiting == 1 ? 'sitting is' : 'sittings are'} waiting for dates. Nothing about the house is lost while you wait.';
    return Container(
      key: const ValueKey<String>('reading-house-calendar-section'),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: ReadingHouseDetailTokens.separator),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MaatFlowThirtyDayCalendar(
            key: const ValueKey<String>('reading-house-thirty-day-calendar'),
            windowStart: _windowStart,
            markers: _calendarMarkers(),
            theme: ReadingHouseDetailTokens.calendarTheme,
            introFirstLine: 'Ready?',
            introSecondLine: 'Place the reading now.',
            keyPrefix: 'reading-house-calendar',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 11, 24, 0),
            child: Text(
              waitingCopy,
              style: _uiStyle(
                color: ReadingHouseDetailTokens.silverLow,
                fontSize: 13,
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            ),
          ),
          if (_canEdit)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 30),
              child: _OutlinePillButton(
                key: const ValueKey<String>('reading-house-place-reading'),
                label: _placingReading
                    ? 'Placing reading…'
                    : waiting <= 0
                    ? 'Reading placed'
                    : 'Place the sittings',
                color: ReadingHouseDetailTokens.gold,
                onTap: waiting <= 0 || _placingReading ? null : _placeReading,
                busy: _placingReading,
              ),
            )
          else
            const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSittings(BuildContext context) {
    return Container(
      key: const ValueKey<String>('reading-house-sittings'),
      padding: const EdgeInsets.only(top: 30),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: ReadingHouseDetailTokens.separator),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: _SectionEyebrow('THE SITTINGS'),
          ),
          for (final sitting in _sittings)
            _SittingRow(
              sitting: sitting,
              status: _sittingStatus(context, sitting),
              onTap: _canEdit ? () => _openSitting(sitting) : null,
            ),
          if (_canEdit)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 22),
              child: _DashedPillButton(
                key: const ValueKey<String>('reading-house-add-sitting'),
                label: _addingSitting
                    ? 'Adding sitting…'
                    : '+ Add another sitting',
                onTap: !_addingSitting ? () => unawaited(_addSitting()) : null,
              ),
            )
          else
            const SizedBox(height: 22),
        ],
      ),
    );
  }

  String _sittingStatus(BuildContext context, ReadingHouseSitting sitting) {
    final date = sitting.scheduledDate;
    if (date == null) return 'NOT PLACED';
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay(hour: sitting.hour, minute: sitting.minute));
    return '${_kemeticDate(date)} · $time';
  }

  String _memberInitials(SharedCalendarMember member) {
    final label = member.displayLabel.trim();
    final words = label
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList(growable: false);
    if (words.isEmpty) return 'R';
    if (words.length == 1) {
      return words.first
          .substring(0, words.first.length.clamp(1, 2))
          .toUpperCase();
    }
    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }
}

class _ReadingHouseHero extends StatelessWidget {
  const _ReadingHouseHero();

  @override
  Widget build(BuildContext context) {
    return MaatFlowDetailHero(
      key: const ValueKey<String>('reading-house-hero'),
      theme: ReadingHouseDetailTokens.theme,
      background: const _ReadingHouseHeroBackdrop(),
      glyph: kReadingHouseGlyph,
      glyphKey: const ValueKey<String>('reading-house-hero-glyph'),
      glyphGradient: const RadialGradient(
        center: Alignment(-0.24, -0.44),
        radius: 0.9,
        colors: [Color(0xFF3C9277), Color(0xFF1A4638), Color(0xFF08140F)],
      ),
      glyphBorder: ReadingHouseDetailTokens.houseHighlight,
      glyphGlow: ReadingHouseDetailTokens.houseHighlight,
      title: 'The Reading\nHouse',
      subtitle: 'One book. A few people. Shared attention.',
    );
  }
}

class _ReadingHouseHeroBackdrop extends StatelessWidget {
  const _ReadingHouseHeroBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          ReadingHouseDetailTokens.heroAsset,
          key: const ValueKey<String>('reading-house-hero-image'),
          fit: BoxFit.cover,
          alignment: ReadingHouseDetailTokens.heroImageAlignment,
          errorBuilder: (context, error, stackTrace) =>
              const ColoredBox(color: ReadingHouseDetailTokens.pageBackground),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x10050504),
                Color(0x18050504),
                Color(0x66050504),
                Color(0xB3050504),
              ],
              stops: [0.0, 0.46, 0.70, 1.0],
            ),
          ),
        ),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 200,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Color(0x24050504),
                  ReadingHouseDetailTokens.pageBackground,
                  ReadingHouseDetailTokens.pageBackground,
                ],
                stops: [0.0, 0.38, 0.92, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 34,
      child: Align(
        alignment: Alignment(0, -0.35),
        child: SizedBox(
          width: 44,
          height: 4,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xFF31453D),
              borderRadius: BorderRadius.all(Radius.circular(99)),
            ),
          ),
        ),
      ),
    );
  }
}

class _BeforeCalendarIntro extends StatelessWidget {
  const _BeforeCalendarIntro();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('reading-house-before-calendar'),
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 26),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: ReadingHouseDetailTokens.separator),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionEyebrow('BEFORE THE CALENDAR'),
          const SizedBox(height: 13),
          Text.rich(
            TextSpan(
              text: 'Pick the book first.\n',
              children: [
                TextSpan(
                  text: 'Nothing has to be scheduled yet.',
                  style: TextStyle(
                    color: ReadingHouseDetailTokens.silver,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
            style: _displayStyle(
              color: ReadingHouseDetailTokens.bone,
              fontSize: 25,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Invite the readers, then set the sittings whenever you’re ready.',
            style: _uiStyle(
              color: ReadingHouseDetailTokens.silverLow,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionEyebrow extends StatelessWidget {
  const _SectionEyebrow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text,
          style: _uiStyle(
            color: ReadingHouseDetailTokens.goldDim,
            fontSize: 10,
            letterSpacing: 2.3,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Divider(color: ReadingHouseDetailTokens.separator, height: 1),
        ),
      ],
    );
  }
}

class _UpperLabel extends StatelessWidget {
  const _UpperLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: _uiStyle(
        color: ReadingHouseDetailTokens.goldDim,
        fontSize: 10,
        letterSpacing: 2.1,
        height: 1.1,
      ),
    );
  }
}

class _SetupTextField extends StatelessWidget {
  const _SetupTextField({
    required this.label,
    required this.hintText,
    required this.controller,
    required this.fieldKey,
    this.enabled = true,
    this.readOnlyValue,
    this.trailing,
    this.topPadding = 17,
  });

  final String label;
  final String hintText;
  final TextEditingController controller;
  final Key fieldKey;
  final bool enabled;
  final String? readOnlyValue;
  final String? trailing;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(0, topPadding, 0, 15),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x1F3FA98A))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _UpperLabel(label)),
              if (trailing != null)
                Flexible(
                  child: Text(
                    trailing!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: _uiStyle(
                      color: const Color(0xFF4F5B55),
                      fontSize: 10,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
            ],
          ),
          if (enabled)
            TextField(
              key: fieldKey,
              controller: controller,
              cursorColor: ReadingHouseDetailTokens.houseHighlight,
              style: _displayStyle(
                color: ReadingHouseDetailTokens.houseHighlight,
                fontSize: 22,
                fontStyle: FontStyle.italic,
                height: 1.25,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.only(top: 9, bottom: 6),
                border: InputBorder.none,
                hintText: hintText,
                hintStyle: _displayStyle(
                  color: const Color(0xFF3F4A44),
                  fontSize: 22,
                  fontStyle: FontStyle.italic,
                  height: 1.25,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 9, bottom: 6),
              child: Text(
                readOnlyValue?.trim().isNotEmpty == true
                    ? readOnlyValue!.trim()
                    : 'Not specified',
                key: fieldKey,
                style: _displayStyle(
                  color: ReadingHouseDetailTokens.houseHighlight,
                  fontSize: 22,
                  fontStyle: FontStyle.italic,
                  height: 1.25,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SetupChoiceField extends StatelessWidget {
  const _SetupChoiceField({
    required this.label,
    required this.firstLabel,
    required this.secondLabel,
    required this.secondSelected,
    required this.onFirst,
    required this.onSecond,
    required this.note,
    required this.fieldKey,
    this.highlightedNote = false,
    this.busy = false,
    this.readOnly = false,
  });

  final String label;
  final String firstLabel;
  final String secondLabel;
  final bool secondSelected;
  final VoidCallback? onFirst;
  final VoidCallback? onSecond;
  final String note;
  final Key fieldKey;
  final bool highlightedNote;
  final bool busy;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: fieldKey,
      padding: const EdgeInsets.fromLTRB(0, 17, 0, 15),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x1F3FA98A))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _UpperLabel(label)),
              if (busy)
                const SizedBox(
                  key: ValueKey<String>('reading-house-choice-busy'),
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: ReadingHouseDetailTokens.houseHighlight,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: _ChoiceButton(
                  label: firstLabel,
                  selected: !secondSelected,
                  onTap: onFirst,
                  readOnly: readOnly,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _ChoiceButton(
                  label: secondLabel,
                  selected: secondSelected,
                  onTap: onSecond,
                  readOnly: readOnly,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: highlightedNote
                ? const EdgeInsets.symmetric(horizontal: 12, vertical: 11)
                : EdgeInsets.zero,
            decoration: highlightedNote
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: const Color(0x293FA98A)),
                    color: const Color(0x0E3FA98A),
                  )
                : null,
            child: Text(
              note,
              style: _uiStyle(
                color: highlightedNote
                    ? const Color(0xFF8BB5A6)
                    : const Color(0xFF68766F),
                fontSize: highlightedNote ? 12.5 : 12,
                fontStyle: FontStyle.italic,
                height: 1.38,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.readOnly = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      constraints: const BoxConstraints(minHeight: 44),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? const Color(0xC27FD9BC) : const Color(0x24E8E2D6),
        ),
        color: selected ? const Color(0x1A3FA98A) : Colors.transparent,
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: _displayStyle(
          color: selected
              ? ReadingHouseDetailTokens.houseHighlight
              : ReadingHouseDetailTokens.silver,
          fontSize: 15.5,
        ),
      ),
    );
    return Semantics(
      selected: selected,
      button: !readOnly,
      child: readOnly
          ? content
          : InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: content,
            ),
    );
  }
}

class _ReaderRow extends StatelessWidget {
  const _ReaderRow({
    required this.initials,
    required this.name,
    required this.status,
    this.host = false,
  });

  final String initials;
  final String name;
  final String status;
  final bool host;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0x427FD9BC)),
            color: const Color(0x143FA98A),
          ),
          child: Text(
            initials,
            style: _uiStyle(
              color: ReadingHouseDetailTokens.houseHighlight,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            name,
            style: _displayStyle(
              color: ReadingHouseDetailTokens.bone,
              fontSize: 17,
              height: 1,
            ),
          ),
        ),
        Text(
          status,
          style: _uiStyle(
            color: host
                ? ReadingHouseDetailTokens.gold
                : ReadingHouseDetailTokens.houseHighlight,
            fontSize: 10,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

class _HouseStateLine extends StatelessWidget {
  const _HouseStateLine({
    required this.held,
    required this.openDoors,
    required this.invitedCount,
    required this.placedCount,
  });

  final bool held;
  final bool openDoors;
  final int invitedCount;
  final int placedCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('reading-house-state-line'),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x243FA98A)),
        color: const Color(0x0A3FA98A),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 7,
        children: [
          _StateText(held ? 'House is open' : 'Not yet held', emphasized: true),
          const _StateDot(),
          _StateText(openDoors ? 'Open in Commons' : 'Closed house'),
          const _StateDot(),
          _StateText(
            invitedCount == 0
                ? 'No readers invited'
                : 'Waiting on $invitedCount ${invitedCount == 1 ? 'reader' : 'readers'}',
          ),
          const _StateDot(),
          _StateText(
            placedCount == 0
                ? 'Not scheduled'
                : '$placedCount ${placedCount == 1 ? 'sitting' : 'sittings'} ready',
            muted: placedCount == 0,
          ),
        ],
      ),
    );
  }
}

class _StateText extends StatelessWidget {
  const _StateText(this.text, {this.emphasized = false, this.muted = false});

  final String text;
  final bool emphasized;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: _uiStyle(
        color: emphasized
            ? ReadingHouseDetailTokens.houseHighlight
            : muted
            ? const Color(0xFF59615D)
            : const Color(0xFF718179),
        fontSize: 11.5,
        height: 1.35,
      ),
    );
  }
}

class _StateDot extends StatelessWidget {
  const _StateDot();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 3,
      height: 3,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF32423B),
        ),
      ),
    );
  }
}

class _SittingRow extends StatelessWidget {
  const _SittingRow({
    required this.sitting,
    required this.status,
    required this.onTap,
  });

  final ReadingHouseSitting sitting;
  final String status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final number = sitting.eventNumber.toString().padLeft(2, '0');
    return InkWell(
      key: ValueKey<String>('reading-house-sitting-${sitting.eventNumber}'),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0x173FA98A))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 32,
              child: Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  number,
                  style: _uiStyle(
                    color: ReadingHouseDetailTokens.goldDim,
                    fontSize: 10,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sitting.title,
                    style: _displayStyle(
                      color: ReadingHouseDetailTokens.gold,
                      fontSize: 21,
                      fontStyle: FontStyle.italic,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    status,
                    style: _uiStyle(
                      color: const Color(0xFF59635E),
                      fontSize: 10.5,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    sitting.privatePrompt,
                    style: _displayStyle(
                      color: ReadingHouseDetailTokens.silver,
                      fontSize: 15.5,
                      fontStyle: FontStyle.italic,
                      height: 1.38,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(top: 5),
                child: Icon(
                  Icons.chevron_right,
                  size: 17,
                  color: ReadingHouseDetailTokens.house,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReadingFrame extends StatelessWidget {
  const _ReadingFrame({required this.question});

  final String question;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey<String>('reading-house-reading-frame'),
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionEyebrow('THE READING FRAME'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0x293FA98A)),
              gradient: const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Color(0x0F3FA98A), Color(0x03FFFFFF)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _UpperLabel('HOUSE QUESTION · CAN WAIT'),
                const SizedBox(height: 9),
                Text(
                  question,
                  style: _displayStyle(
                    color: ReadingHouseDetailTokens.bone,
                    fontSize: 19,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This becomes the quiet center everyone returns to.',
                  style: _uiStyle(
                    color: ReadingHouseDetailTokens.silverLow,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoricalContext extends StatelessWidget {
  const _HistoricalContext();

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey<String>('reading-house-historical-context'),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          key: const ValueKey<String>('reading-house-context-toggle'),
          tilePadding: const EdgeInsets.symmetric(horizontal: 2),
          childrenPadding: const EdgeInsets.fromLTRB(2, 0, 2, 16),
          collapsedIconColor: const Color(0xFF386D5C),
          iconColor: const Color(0xFF386D5C),
          shape: const Border(
            top: BorderSide(color: ReadingHouseDetailTokens.separator),
            bottom: BorderSide(color: ReadingHouseDetailTokens.separator),
          ),
          collapsedShape: const Border(
            top: BorderSide(color: ReadingHouseDetailTokens.separator),
            bottom: BorderSide(color: ReadingHouseDetailTokens.separator),
          ),
          title: Text(
            'In Kemet',
            style: _displayStyle(
              color: ReadingHouseDetailTokens.silver,
              fontSize: 16.5,
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                kReadingHouseHistoricalBadgeText,
                style: _displayStyle(
                  color: const Color(0xFF858B86),
                  fontSize: 16,
                  height: 1.48,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutlinePillButton extends StatelessWidget {
  const _OutlinePillButton({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
    this.busy = false,
  });

  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          disabledForegroundColor: ReadingHouseDetailTokens.silverLow,
          side: BorderSide(color: color.withValues(alpha: 0.38)),
          shape: const StadiumBorder(),
          textStyle: _displayStyle(fontSize: 16),
        ),
        child: busy
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  color: color,
                ),
              )
            : Text(label),
      ),
    );
  }
}

class _DashedPillButton extends StatelessWidget {
  const _DashedPillButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: SizedBox(
        height: 42,
        child: CustomPaint(
          foregroundPainter: const _DashedRoundedRectPainter(),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onTap,
              child: Center(
                child: Text(
                  label,
                  style: _displayStyle(
                    color: ReadingHouseDetailTokens.houseHighlight,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedRoundedRectPainter extends CustomPainter {
  const _DashedRoundedRectPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(999)),
      );
    final paint = Paint()
      ..color = ReadingHouseDetailTokens.houseHighlight.withValues(alpha: 0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 6), paint);
        distance += 10;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SheetKicker extends StatelessWidget {
  const _SheetKicker(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: _uiStyle(
        color: ReadingHouseDetailTokens.house,
        fontSize: 10,
        letterSpacing: 2,
      ),
    );
  }
}

class _SheetHeading extends StatelessWidget {
  const _SheetHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: _displayStyle(
        color: ReadingHouseDetailTokens.gold,
        fontSize: 28,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _ReaderInviteSheet extends StatefulWidget {
  const _ReaderInviteSheet({
    required this.authority,
    required this.excludedUserIds,
    required this.onInvite,
  });

  final ReadingHouseAuthority authority;
  final Set<String> excludedUserIds;
  final Future<SharedCalendarMember> Function(UserSearchResult reader) onInvite;

  @override
  State<_ReaderInviteSheet> createState() => _ReaderInviteSheetState();
}

class _ReaderInviteSheetState extends State<_ReaderInviteSheet> {
  late final FocusNode _searchFocus = FocusNode(
    debugLabel: 'reading-house-reader-search',
  );
  String _query = '';
  List<UserSearchResult> _results = const <UserSearchResult>[];
  Timer? _debounce;
  int _searchSerial = 0;
  bool _searching = false;
  Object? _error;
  Object? _inviteError;
  String? _invitingUserId;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchFocus.dispose();
    super.dispose();
  }

  void _dismiss([SharedCalendarMember? member]) {
    _searchFocus.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop(member);
  }

  void _onQueryChanged(String raw) {
    final query = raw.trim();
    final serial = ++_searchSerial;
    _debounce?.cancel();
    setState(() {
      _query = query;
      _error = null;
      _inviteError = null;
      if (query.length < 2) {
        _results = const <UserSearchResult>[];
        _searching = false;
      }
    });
    if (query.length < 2) return;
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      if (mounted) setState(() => _searching = true);
      try {
        final results = await widget.authority.searchReaders(
          query,
          excludedUserIds: widget.excludedUserIds,
        );
        if (!mounted || serial != _searchSerial) return;
        setState(() {
          _results = results;
          _searching = false;
        });
      } catch (error) {
        if (!mounted || serial != _searchSerial) return;
        setState(() {
          _error = error;
          _results = const <UserSearchResult>[];
          _searching = false;
        });
      }
    });
  }

  Future<void> _invite(UserSearchResult reader) async {
    if (_invitingUserId != null) return;
    setState(() {
      _invitingUserId = reader.userId;
      _inviteError = null;
    });
    try {
      final member = await widget.onInvite(reader);
      if (!mounted) return;
      _dismiss(member);
    } catch (error) {
      if (!mounted) return;
      setState(() => _inviteError = error);
    } finally {
      if (mounted) setState(() => _invitingUserId = null);
    }
  }

  String _initials(UserSearchResult reader) {
    final label = reader.name.trim();
    final words = label
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList(growable: false);
    if (words.isEmpty) return 'R';
    if (words.length == 1) {
      return words.first
          .substring(0, words.first.length.clamp(1, 2))
          .toUpperCase();
    }
    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardAwareEditableSurface(
      child: Material(
        key: const ValueKey<String>('reading-house-invite-sheet'),
        color: const Color(0xFF0A0D0B),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          side: BorderSide(color: Color(0x427FD9BC)),
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 15, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Spacer(),
                  const SizedBox(
                    width: 42,
                    height: 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0xFF33463E),
                        borderRadius: BorderRadius.all(Radius.circular(99)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: _dismiss,
                        icon: const Icon(
                          Icons.close,
                          color: ReadingHouseDetailTokens.silver,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const _SheetKicker('READERS'),
              const SizedBox(height: 8),
              const _SheetHeading('Invite a reader'),
              const SizedBox(height: 18),
              TextField(
                key: const ValueKey<String>('reading-house-reader-search'),
                focusNode: _searchFocus,
                autofocus: true,
                onChanged: _onQueryChanged,
                cursorColor: ReadingHouseDetailTokens.houseHighlight,
                style: _uiStyle(
                  color: ReadingHouseDetailTokens.bone,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF65756D),
                  ),
                  hintText: 'Search by @handle or display name',
                  hintStyle: _uiStyle(
                    color: const Color(0xFF59635E),
                    fontSize: 15,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF080A08),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0x427FD9BC)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xB87FD9BC)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _inviteError != null
                    ? 'Invitation failed. Please try again.'
                    : _query.length < 2
                    ? 'Type at least two characters to search profiles.'
                    : _searching
                    ? 'Searching…'
                    : _error != null
                    ? 'Search is unavailable. Please try again.'
                    : _results.isEmpty
                    ? 'No eligible readers found.'
                    : 'Choose a reader to send a real invitation.',
                style: _uiStyle(
                  color: ReadingHouseDetailTokens.silverLow,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              for (final reader in _results)
                InkWell(
                  key: ValueKey<String>(
                    'reading-house-reader-result-${reader.userId}',
                  ),
                  onTap: _invitingUserId == null
                      ? () => unawaited(_invite(reader))
                      : null,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 54),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0x1A3FA98A)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0x143FA98A),
                          ),
                          child: Text(
                            _initials(reader),
                            style: _uiStyle(
                              color: ReadingHouseDetailTokens.houseHighlight,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reader.name,
                                style: _displayStyle(
                                  color: ReadingHouseDetailTokens.bone,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                reader.handle?.trim().isNotEmpty == true
                                    ? '@${reader.handle!.trim()}'
                                    : '',
                                style: _uiStyle(
                                  color: ReadingHouseDetailTokens.silverLow,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_invitingUserId == reader.userId)
                          const SizedBox(
                            key: ValueKey<String>(
                              'reading-house-invite-result-busy',
                            ),
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.8,
                              color: ReadingHouseDetailTokens.houseHighlight,
                            ),
                          )
                        else
                          Text(
                            'ADD',
                            style: _uiStyle(
                              color: ReadingHouseDetailTokens.houseHighlight,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _kemeticDate(DateTime date) {
  final kemetic = KemeticMath.fromGregorian(date);
  final month = getMonthById(kemetic.kMonth).displayFull;
  return '$month ${kemetic.kDay}';
}

String _countWord(int value) {
  return switch (value) {
    1 => 'One',
    2 => 'Two',
    3 => 'Three',
    _ => '$value',
  };
}

TextStyle _displayStyle({
  Color? color,
  double? fontSize,
  FontWeight? fontWeight,
  FontStyle? fontStyle,
  double? height,
  double? letterSpacing,
}) {
  return TextStyle(
    color: color,
    fontFamily: MaatFlowListTokens.fontFamily,
    fontFamilyFallback: MaatFlowListTokens.fontFallback,
    fontSize: fontSize,
    fontWeight: fontWeight,
    fontStyle: fontStyle,
    height: height,
    letterSpacing: letterSpacing,
  );
}

TextStyle _uiStyle({
  Color? color,
  double? fontSize,
  FontWeight? fontWeight,
  FontStyle? fontStyle,
  double? height,
  double? letterSpacing,
}) {
  return _displayStyle(
    color: color,
    fontSize: fontSize,
    fontWeight: fontWeight,
    fontStyle: fontStyle,
    height: height,
    letterSpacing: letterSpacing,
  );
}
