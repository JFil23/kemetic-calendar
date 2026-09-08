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
import 'reading_house_event_block_visual.dart';
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
  static const String heroAsset = 'assets/the_reading_house/reference_hero.jpg';
  static const Alignment heroImageAlignment = Alignment(0, 0.10);

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
      referenceHeroHeight: 258,
      referenceSheetOverlap: 26,
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
              actionNote: 'Creates the house in My Flows.',
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
                top: MediaQuery.paddingOf(context).top + 6,
                left: 18,
                child: MaatFlowDetailBackButton(
                  key: const ValueKey<String>('reading-house-back'),
                  color: ReadingHouseDetailTokens.gold,
                  backgroundColor: const Color(0xA60A0806),
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
        const ReadingHouseDetailFeaturedSection(),
        _buildHouseSetup(),
        _buildCalendar(),
        _buildSittings(context),
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
        ? 'no invites yet'
        : pendingCount == 1
        ? '1 invite pending'
        : '$pendingCount invites pending';
    // Everyone who accepts sees this same house, even before it has dates.
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
          _BookObject(
            bookController: _bookController,
            editionController: _editionController,
            questionController: _questionController,
            canEdit: _canEdit,
            bookReadOnly: _plan.displayBookTitle,
            editionReadOnly: _plan.editionNote,
            questionReadOnly: _plan.displayQuestion,
          ),
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF070A08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x243FA98A)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    key: const ValueKey<String>('reading-house-mode'),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Reading with',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: ReadingHouseDetailTokens.bone,
                              fontFamily: MaatFlowListTokens.fontFamily,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              height: 1,
                            ),
                          ),
                        ),
                        if (_savingMode)
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: SizedBox(
                              key: ValueKey<String>(
                                'reading-house-choice-busy',
                              ),
                              width: 13,
                              height: 13,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: ReadingHouseDetailTokens.houseHighlight,
                              ),
                            ),
                          ),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // onFirst: !_canEdit
                                _HouseChip(
                                  label: 'Solo',
                                  selected: !_withReaders,
                                  onTap: !_canEdit || _savingMode
                                      ? null
                                      : () => unawaited(_changeMode(false)),
                                  readOnly: !_canEdit,
                                ),
                                const SizedBox(width: 6),
                                // onSecond: !_canEdit
                                _HouseChip(
                                  label: 'Readers',
                                  selected: _withReaders,
                                  onTap: !_canEdit || _savingMode
                                      ? null
                                      : () => unawaited(_changeMode(true)),
                                  readOnly: !_canEdit,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ClipRect(
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 250),
                      alignment: Alignment.topCenter,
                      heightFactor: _withReaders ? 1 : 0,
                      child: IgnorePointer(
                        ignoring: !_withReaders,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 15),
                          child: DecoratedBox(
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Color(0x1A3FA98A)),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Container(
                                    key: const ValueKey<String>(
                                      'reading-house-doors',
                                    ),
                                    child: Row(
                                      children: [
                                        const Expanded(
                                          child: Text(
                                            'Who enters?',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Color(0xFFAFA89D),
                                              fontFamily:
                                                  MaatFlowListTokens.fontFamily,
                                              fontSize: 14,
                                              height: 1,
                                            ),
                                          ),
                                        ),
                                        if (_savingDoors)
                                          const Padding(
                                            padding: EdgeInsets.only(right: 8),
                                            child: SizedBox(
                                              key: ValueKey<String>(
                                                'reading-house-choice-busy',
                                              ),
                                              width: 13,
                                              height: 13,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 1.5,
                                                color: ReadingHouseDetailTokens
                                                    .houseHighlight,
                                              ),
                                            ),
                                          ),
                                        Flexible(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerRight,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                _HouseChip(
                                                  label: 'Invited only',
                                                  selected: !_openDoors,
                                                  compact: true,
                                                  onTap:
                                                      !_canEdit || _savingDoors
                                                      ? null
                                                      : () => unawaited(
                                                          _changeDoors(false),
                                                        ),
                                                  readOnly: !_canEdit,
                                                ),
                                                const SizedBox(width: 6),
                                                _HouseChip(
                                                  label: 'Commons',
                                                  selected: _openDoors,
                                                  compact: true,
                                                  onTap:
                                                      !_canEdit || _savingDoors
                                                      ? null
                                                      : () => unawaited(
                                                          _changeDoors(true),
                                                        ),
                                                  readOnly: !_canEdit,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_openDoors)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 8),
                                      child: Text(
                                        'Community members can discover this house in the Commons.',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          color: Color(0xFF688177),
                                          fontFamily: 'GentiumPlus',
                                          fontSize: 11,
                                          fontStyle: FontStyle.italic,
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                  if (_withReaders)
                                    Padding(
                                      key: const ValueKey<String>(
                                        'reading-house-readers',
                                      ),
                                      padding: const EdgeInsets.only(top: 14),
                                      child: Column(
                                        children: [
                                          _PeopleLine(
                                            initials: hostInitials,
                                            name: hostName,
                                            state: 'Host · $inviteSummary',
                                            inviteLabel: _canManageMembership
                                                ? '+ Invite'
                                                : null,
                                            onInvite: _canManageMembership
                                                ? () =>
                                                      unawaited(_inviteReader())
                                                : null,
                                          ),
                                          for (final reader in invitedReaders)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 12,
                                              ),
                                              child: _PeopleLine(
                                                initials: _memberInitials(
                                                  reader,
                                                ),
                                                name: reader.displayLabel,
                                                state: reader.isPending
                                                    ? 'Invited'
                                                    : 'Accepted',
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
            introFirstLine: 'The reading',
            introSecondLine: '',
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
                    : 'Place the reading',
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
            padding: EdgeInsets.fromLTRB(24, 0, 24, 0),
            child: Text(
              'The sittings',
              style: TextStyle(
                color: ReadingHouseDetailTokens.bone,
                fontFamily: MaatFlowListTokens.fontFamily,
                fontSize: 29,
                fontWeight: FontWeight.w500,
                height: 1,
              ),
            ),
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
                label: _addingSitting ? 'Adding sitting…' : '+ Add sitting',
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
    if (date == null) return '${sitting.section} · NOT PLACED';
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay(hour: sitting.hour, minute: sitting.minute));
    return '${sitting.section} · ${_kemeticDate(date)} · $time';
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
      glyphBorder: const Color(0xB87FD9BC),
      glyphGlow: ReadingHouseDetailTokens.houseHighlight,
      title: 'The Reading\nHouse',
      subtitle: '',
      contentBottom: 26,
      contentLeft: 23,
      contentRight: 23,
      glyphToTitleSpacing: 10,
      titleFontSize: 42,
      titleHeight: 0.94,
      titleLetterSpacing: -0.42,
    );
  }
}

class _ReadingHouseHeroBackdrop extends StatelessWidget {
  const _ReadingHouseHeroBackdrop();

  static const ColorFilter _mockupImageTreatment = ColorFilter.matrix(<double>[
    0.60118134,
    0.09014148,
    0.00907718,
    0,
    -3.825,
    0.02685334,
    0.66446948,
    0.00907718,
    0,
    -3.825,
    0.02685334,
    0.09014148,
    0.58340518,
    0,
    -3.825,
    0,
    0,
    0,
    1,
    0,
  ]);

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Transform.scale(
          key: const ValueKey<String>('reading-house-hero-image-scale'),
          scale: 1.01,
          child: ColorFiltered(
            key: const ValueKey<String>('reading-house-hero-image-treatment'),
            colorFilter: _mockupImageTreatment,
            child: Image.asset(
              ReadingHouseDetailTokens.heroAsset,
              key: const ValueKey<String>('reading-house-hero-image'),
              fit: BoxFit.cover,
              alignment: ReadingHouseDetailTokens.heroImageAlignment,
              errorBuilder: (context, error, stackTrace) => const ColoredBox(
                color: ReadingHouseDetailTokens.pageBackground,
              ),
            ),
          ),
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
          height: 135,
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

class _BookObject extends StatefulWidget {
  const _BookObject({
    required this.bookController,
    required this.editionController,
    required this.questionController,
    required this.canEdit,
    required this.bookReadOnly,
    required this.editionReadOnly,
    required this.questionReadOnly,
  });

  final TextEditingController bookController;
  final TextEditingController editionController;
  final TextEditingController questionController;
  final bool canEdit;
  final String bookReadOnly;
  final String editionReadOnly;
  final String questionReadOnly;

  @override
  State<_BookObject> createState() => _BookObjectState();
}

class _BookObjectState extends State<_BookObject> {
  bool _editingQuestion = false;
  String _questionSnapshot = '';

  @override
  void didUpdateWidget(covariant _BookObject oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.canEdit && _editingQuestion) {
      widget.questionController.text = _questionSnapshot;
      _editingQuestion = false;
    }
  }

  String get _questionDisplay {
    final typed = widget.questionController.text.trim();
    if (typed.isNotEmpty) return typed;
    final fallback = widget.questionReadOnly.trim();
    if (fallback.isNotEmpty) return fallback;
    return 'What is this book asking the reader to hold?';
  }

  void _beginQuestionEdit() {
    if (!widget.canEdit) return;
    setState(() {
      _questionSnapshot = widget.questionController.text;
      _editingQuestion = true;
    });
  }

  void _cancelQuestionEdit() {
    widget.questionController.text = _questionSnapshot;
    setState(() => _editingQuestion = false);
  }

  void _saveQuestionEdit() {
    setState(() => _editingQuestion = false);
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF070A08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x2B3FA98A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'The book',
                  style: TextStyle(
                    color: Color(0xFF7F867F),
                    fontFamily: 'GentiumPlus',
                    fontSize: 12,
                    height: 1,
                  ),
                ),
                _SetupBareField(
                  fieldKey: const ValueKey<String>('reading-house-book'),
                  controller: widget.bookController,
                  enabled: widget.canEdit, // enabled: _canEdit
                  readOnlyValue: widget.bookReadOnly,
                  hintText: 'Name the book',
                  style: _displayStyle(
                    color: ReadingHouseDetailTokens.houseHighlight,
                    fontSize: 25,
                    fontWeight: FontWeight.w500,
                    height: 1.08,
                  ),
                  hintStyle: _displayStyle(
                    color: const Color(0xFF3D4943),
                    fontSize: 25,
                    fontWeight: FontWeight.w500,
                    height: 1.08,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    const Text(
                      'Edition',
                      style: TextStyle(
                        color: Color(0xFF58625D),
                        fontFamily: 'GentiumPlus',
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        height: 1.2,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 7),
                      child: SizedBox(
                        width: 3,
                        height: 3,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xFF3D4A44),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _SetupBareField(
                        fieldKey: const ValueKey<String>(
                          'reading-house-edition',
                        ),
                        controller: widget.editionController,
                        enabled: widget.canEdit,
                        readOnlyValue: widget.editionReadOnly,
                        hintText: 'Translator, edition, or link',
                        style: const TextStyle(
                          color: Color(0xFF8D9993),
                          fontFamily: 'GentiumPlus',
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          height: 1.2,
                        ),
                        hintStyle: const TextStyle(
                          color: Color(0xFF4C5751),
                          fontFamily: 'GentiumPlus',
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0x1A3FA98A))),
              color: Color(0x053FA98A),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 13, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'House question',
                          style: TextStyle(
                            color: Color(0xFF7F867F),
                            fontFamily: 'GentiumPlus',
                            fontSize: 12,
                            height: 1,
                          ),
                        ),
                      ),
                      if (widget.canEdit && !_editingQuestion)
                        GestureDetector(
                          key: const ValueKey<String>(
                            'reading-house-question-edit',
                          ),
                          onTap: _beginQuestionEdit,
                          child: const Text(
                            'Edit',
                            style: TextStyle(
                              color: Color(0xFF527A6C),
                              fontFamily: 'GentiumPlus',
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (_editingQuestion) ...[
                    const SizedBox(height: 8),
                    TextField(
                      key: const ValueKey<String>('reading-house-question'),
                      controller: widget.questionController,
                      enabled: widget.canEdit,
                      autofocus: true,
                      minLines: 3,
                      maxLines: null,
                      cursorColor: ReadingHouseDetailTokens.houseHighlight,
                      style: _displayStyle(
                        color: ReadingHouseDetailTokens.bone,
                        fontSize: 16,
                        height: 1.35,
                      ),
                      decoration: InputDecoration(
                        hintText:
                            'What is this book asking the reader to hold?',
                        hintStyle: _displayStyle(
                          color: const Color(0xFF3D4943),
                          fontSize: 16,
                          height: 1.35,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF07100D),
                        contentPadding: const EdgeInsets.all(10),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: ReadingHouseDetailTokens.houseHighlight
                                .withValues(alpha: 0.26),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: ReadingHouseDetailTokens.houseHighlight
                                .withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        GestureDetector(
                          key: const ValueKey<String>(
                            'reading-house-question-cancel',
                          ),
                          onTap: _cancelQuestionEdit,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 3,
                              vertical: 3,
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                color: Color(0xFF6F756F),
                                fontFamily: 'GentiumPlus',
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          key: const ValueKey<String>(
                            'reading-house-question-save',
                          ),
                          onTap: _saveQuestionEdit,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 3,
                              vertical: 3,
                            ),
                            child: Text(
                              'Save question',
                              style: TextStyle(
                                color: ReadingHouseDetailTokens.houseHighlight,
                                fontFamily: 'GentiumPlus',
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _questionDisplay,
                        key: const ValueKey<String>(
                          'reading-house-question-display',
                        ),
                        style: _displayStyle(
                          color: ReadingHouseDetailTokens.bone,
                          fontSize: 18.5,
                          height: 1.3,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupBareField extends StatelessWidget {
  const _SetupBareField({
    required this.fieldKey,
    required this.controller,
    required this.enabled,
    required this.readOnlyValue,
    required this.hintText,
    required this.style,
    required this.hintStyle,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final bool enabled;
  final String readOnlyValue;
  final String hintText;
  final TextStyle style;
  final TextStyle hintStyle;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Text(
          readOnlyValue.trim().isNotEmpty ? readOnlyValue.trim() : hintText,
          key: fieldKey,
          style: style,
        ),
      );
    }
    return TextField(
      key: fieldKey,
      controller: controller,
      enabled: enabled,
      cursorColor: ReadingHouseDetailTokens.houseHighlight,
      style: style,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.only(top: 5, bottom: 1),
        border: InputBorder.none,
        hintText: hintText,
        hintStyle: hintStyle,
      ),
    );
  }
}

class _HouseChip extends StatelessWidget {
  const _HouseChip({
    required this.label,
    required this.selected,
    required this.readOnly,
    this.onTap,
    this.compact = false,
  });

  final String label;
  final bool selected;
  final bool readOnly;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      constraints: BoxConstraints(minHeight: compact ? 31 : 34),
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected ? const Color(0xAD7FD9BC) : const Color(0x24E8E2D6),
        ),
        color: selected ? const Color(0x173FA98A) : Colors.transparent,
      ),
      child: Text(
        label,
        style: _displayStyle(
          color: selected
              ? ReadingHouseDetailTokens.houseHighlight
              : const Color(0xFF7D857F),
          fontSize: compact ? 11.5 : 12.5,
        ),
      ),
    );
    return Semantics(
      selected: selected,
      button: !readOnly,
      child: readOnly
          ? content
          : InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onTap,
              child: content,
            ),
    );
  }
}

class _PeopleLine extends StatelessWidget {
  const _PeopleLine({
    required this.initials,
    required this.name,
    required this.state,
    this.inviteLabel,
    this.onInvite,
  });

  final String initials;
  final String name;
  final String state;
  final String? inviteLabel;
  final VoidCallback? onInvite;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0x143FA98A))),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 13),
        child: Row(
          children: [
            Container(
              width: 29,
              height: 29,
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
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: _displayStyle(
                      color: ReadingHouseDetailTokens.bone,
                      fontSize: 15.5,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    state,
                    style: _uiStyle(
                      color: const Color(0xFF59635E),
                      fontSize: 10.5,
                      fontStyle: FontStyle.italic,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
            if (inviteLabel != null)
              TextButton(
                key: const ValueKey<String>('reading-house-invite-reader'),
                onPressed: onInvite,
                style: TextButton.styleFrom(
                  foregroundColor: ReadingHouseDetailTokens.houseHighlight,
                  padding: const EdgeInsets.fromLTRB(8, 5, 0, 5),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontFamily: 'GentiumPlus',
                    fontSize: 12,
                  ),
                ),
                child: Text(inviteLabel!),
              ),
          ],
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey<String>('reading-house-sitting-${sitting.eventNumber}'),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0x173FA98A))),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 29,
                child: Text(
                  number,
                  style: _uiStyle(
                    color: ReadingHouseDetailTokens.goldDim,
                    fontSize: 10,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sitting.title,
                      style: _displayStyle(
                        color: ReadingHouseDetailTokens.houseHighlight,
                        fontSize: 20,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      status,
                      style: _uiStyle(
                        color: const Color(0xFF67716B),
                        fontSize: 11,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: ReadingHouseDetailTokens.house,
                ),
            ],
          ),
        ),
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
              color: const Color(0xFFAAA197),
              fontSize: 18,
              fontStyle: FontStyle.italic,
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                kReadingHouseHistoricalBadgeText,
                style: _displayStyle(
                  color: const Color(0xFF858B86),
                  fontSize: 15.5,
                  height: 1.52,
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
