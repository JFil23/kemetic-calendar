import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/birthday_calendar.dart';
import '../../data/event_filing_engine.dart';
import '../../data/shared_calendar_models.dart';
import '../../data/shared_calendars_repo.dart';
import '../../shared/glossy_text.dart';
import '../../widgets/kemetic_keyboard.dart';
import '../../widgets/keyboard_aware.dart';
import '../calendar/notify.dart';
import '../reminders/reminder_rule.dart';

typedef SharedCalendarAddEventCallback =
    Future<bool> Function(SharedCalendarSummary calendar);

typedef SharedCalendarEventTapCallback =
    Future<void> Function(
      SharedCalendarSummary calendar,
      FiledEvent filedEvent, {
      List<FiledEvent> calendarEvents,
    });

class H3wCalendarSheetTokens {
  const H3wCalendarSheetTokens._();

  static const pageBase = Color(0xFF0D0B07);
  static const cardBase = Color(0xFF120F08);

  static const gold = Color(0xFFD4AE43);
  static const glyphGlow = Color(0xFFF5E8CB);

  static const silverHi = Color(0xFFC8C4BC);
  static const silverMid = Color(0xFF9E9A94);
  static const silverLo = Color(0xFF6A6660);

  static const sharedAccent = Color(0xFF7F77DD);
  static const sharedAccentLight = Color(0xFFAFA9EC);
  static const sharedAccentGlow = Color(0xFFC6C2F2);

  static const repeatPink = Color(0xFFD4537E);
  static const repeatPinkLight = Color(0xFFE59AB4);

  static const goldChipText = Color(0xFFC8B26A);

  static const eventGreen = Color(0xFF7BB661);
  static const eventBlue = Color(0xFF5D9BE8);

  static const serif = 'CormorantGaramond';
  static const serifFallback = <String>['Georgia', 'Times New Roman', 'serif'];
}

class SharedCalendarsSheet extends StatefulWidget {
  const SharedCalendarsSheet({
    super.key,
    required this.repo,
    this.onAddEventRequested,
    this.onEventTapRequested,
    this.initialExpandedCalendarIds = const <String>[],
    this.onContinuityChanged,
    this.routeMode = false,
    this.dismissOnEventTap = true,
    this.onClose,
    this.showCloseButton = true,
    this.routeModeSafeAreaTop = true,
  });

  final SharedCalendarsRepo repo;
  final SharedCalendarAddEventCallback? onAddEventRequested;
  final SharedCalendarEventTapCallback? onEventTapRequested;
  final List<String> initialExpandedCalendarIds;
  final ValueChanged<Map<String, dynamic>>? onContinuityChanged;
  final bool routeMode;
  final bool dismissOnEventTap;
  final VoidCallback? onClose;
  final bool showCloseButton;
  final bool routeModeSafeAreaTop;

  static Future<bool?> show(
    BuildContext context, {
    required SharedCalendarsRepo repo,
    SharedCalendarAddEventCallback? onAddEventRequested,
    SharedCalendarEventTapCallback? onEventTapRequested,
    List<String> initialExpandedCalendarIds = const <String>[],
    ValueChanged<Map<String, dynamic>>? onContinuityChanged,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SharedCalendarsSheet(
        repo: repo,
        onAddEventRequested: onAddEventRequested,
        onEventTapRequested: onEventTapRequested,
        initialExpandedCalendarIds: initialExpandedCalendarIds,
        onContinuityChanged: onContinuityChanged,
      ),
    );
  }

  @override
  State<SharedCalendarsSheet> createState() => _SharedCalendarsSheetState();
}

class _SharedCalendarsSheetState extends State<SharedCalendarsSheet> {
  static const int _calendarEventPreviewLimit = 80;
  static const int _calendarEventFullPageSize = 250;

  static const List<int> _palette = <int>[
    0xFFD4AE43,
    0xFF5D9BE8,
    0xFF5DCAA5,
    0xFFE8943C,
    0xFFE25577,
    0xFF7F77DD,
  ];

  SharedCalendarsSnapshot? _snapshot;
  final Set<String> _expandedCalendarIds = <String>{};
  final Set<String> _showAllCalendarEventIds = <String>{};
  final Set<String> _fullyLoadedCalendarEventIds = <String>{};
  final Set<String> _loadingCalendarEventIds = <String>{};
  final Map<String, List<FiledEvent>> _calendarEventsById =
      <String, List<FiledEvent>>{};
  final Map<String, String> _calendarEventErrorsById = <String, String>{};
  bool _loading = true;
  bool _saving = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _expandedCalendarIds.addAll(
      widget.initialExpandedCalendarIds
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty),
    );
    unawaited(_restoreCachedSnapshot());
    _reload(showLoading: false);
  }

  void _notifyContinuityChanged() {
    widget.onContinuityChanged?.call(<String, dynamic>{
      'expandedCalendarIds': _expandedCalendarIds.toList(growable: false),
    });
  }

  Future<void> _restoreCachedSnapshot() async {
    final snapshot = await widget.repo.restoreCachedSnapshot();
    if (!mounted || snapshot == null) return;
    setState(() {
      _snapshot = snapshot;
      _loading = false;
    });
    unawaited(_hydrateExpandedCalendarEvents());
  }

  Future<void> _reload({bool showLoading = true}) async {
    if (showLoading || _snapshot == null) {
      setState(() => _loading = true);
    }
    final snapshot = await widget.repo.loadSnapshot();
    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      _loading = false;
    });
    unawaited(_hydrateExpandedCalendarEvents());
  }

  Future<void> _runAction(Future<void> Function() action) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await action();
      _changed = true;
      await _reload();
    } catch (e) {
      if (!mounted) return;
      _showSheetMessage(e.toString());
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _createCalendar() async {
    final result = await _showCalendarEditor();
    if (result == null) return;
    await _runAction(() async {
      await widget.repo.createCalendar(
        name: result.name,
        colorValue: result.colorValue,
      );
    });
  }

  Future<void> _createBirthday(SharedCalendarSummary calendar) async {
    if (!calendar.isBirthdays) return;
    final result = await _showBirthdayEditor();
    if (result == null) return;

    await _runAction(() async {
      final birthdayId = await widget.repo.createBirthday(
        name: result.name,
        birthday: result.birthday,
        alertOffsetMinutes: result.alertOffsetMinutes,
      );
      await _scheduleNextBirthdayAlert(
        BirthdayItem(
          id: birthdayId,
          userId: widget.repo.currentUserId ?? '',
          calendarId: calendar.id,
          name: result.name,
          month: result.birthday.month,
          day: result.birthday.day,
          birthYear: result.birthday.year,
          alertOffsetMinutes: result.alertOffsetMinutes,
        ),
      );
    });
  }

  Future<void> _scheduleNextBirthdayAlert(BirthdayItem item) async {
    if (item.alertOffsetMinutes == kBirthdayNoAlertMinutes) return;
    final occurrence = nextBirthdayOccurrence(item: item);
    if (occurrence == null) return;
    final scheduledAt = occurrence.localStart.subtract(
      Duration(minutes: item.alertOffsetMinutes),
    );
    try {
      final result = await Notify.scheduleAlertWithPersistenceResult(
        clientEventId: occurrence.clientEventId,
        scheduledAt: scheduledAt,
        title: occurrence.title,
        payload: birthdayNotificationPayloadJson(occurrence),
      );
      if (result.needsUserVisibleWarning) {
        _showSheetMessage(
          result.message ?? 'Birthday alert was not scheduled.',
        );
      }
    } catch (e) {
      _showSheetMessage('Birthday saved, but the alert was not scheduled.');
    }
  }

  Future<void> _editCalendar(SharedCalendarSummary calendar) async {
    final result = await _showCalendarEditor(
      initialName: calendar.name,
      initialColorValue: calendar.colorValue,
    );
    if (result == null) return;
    await _runAction(() {
      return widget.repo.updateCalendar(
        calendarId: calendar.id,
        name: result.name,
        colorValue: result.colorValue,
      );
    });
  }

  Future<void> _inviteToCalendar(SharedCalendarSummary calendar) async {
    if (!calendar.canManageMembership) return;
    final userId = await context.push<String>(
      '/profile-search'
      '?title=${Uri.encodeComponent('Invite to Calendar')}'
      '&hint=${Uri.encodeComponent('Search by @handle or display name')}'
      '&select=picker',
    );
    if (userId == null || userId.trim().isEmpty) return;

    final trimmedUserId = userId.trim();
    await _runAction(() async {
      await widget.repo.inviteUser(
        calendarId: calendar.id,
        userId: trimmedUserId,
        calendarName: calendar.name,
        calendarColorValue: calendar.colorValue,
      );
    });
  }

  Future<void> _showMembersSheet(
    SharedCalendarSummary calendar, {
    bool pendingFirst = false,
  }) async {
    if (!calendar.canSeeMemberRoster) return;
    final changed = await CalendarMembersSheet.show(
      context,
      repo: widget.repo,
      calendar: calendar,
      pendingFirst: pendingFirst,
    );
    if (!mounted) return;
    await _reload(showLoading: false);
    if (changed != true) return;
    _changed = true;
  }

  Future<void> _addEventToCalendar(SharedCalendarSummary calendar) async {
    final handler = widget.onAddEventRequested;
    if (_saving || handler == null) return;
    setState(() => _saving = true);
    try {
      final didSave = await handler(calendar);
      if (!mounted) return;
      if (didSave) {
        _changed = true;
        await _reload(showLoading: false);
      }
    } catch (e) {
      if (!mounted) return;
      _showSheetMessage(e.toString());
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _openCalendarEvent(
    SharedCalendarSummary calendar,
    FiledEvent filedEvent,
  ) {
    final handler = widget.onEventTapRequested;
    if (handler == null) return;

    if (kDebugMode) {
      final event = filedEvent.event;
      debugPrint(
        '[SharedCalendarEventTap] event tap '
        'calendarId=${calendar.id} eventId=${event.id} '
        'clientEventId=${event.clientEventId} '
        'title="${event.title}" start=${event.startsAt.toIso8601String()}',
      );
    }

    final calendarEvents = List<FiledEvent>.unmodifiable(
      _calendarEventsById[calendar.id] ?? const <FiledEvent>[],
    );

    void dispatch() {
      unawaited(handler(calendar, filedEvent, calendarEvents: calendarEvents));
    }

    if (widget.dismissOnEventTap) {
      Navigator.of(context, rootNavigator: true).pop(_changed);
      WidgetsBinding.instance.addPostFrameCallback((_) => dispatch());
      return;
    }

    dispatch();
  }

  Future<void> _leaveCalendar(SharedCalendarSummary calendar) async {
    final isOwner = calendar.role == SharedCalendarRole.owner;
    final label = isOwner ? 'Delete calendar?' : 'Leave calendar?';
    final detail = isOwner
        ? 'This removes the shared calendar and its events for everyone.'
        : 'You will stop seeing events from this calendar.';
    final shouldContinue = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111214),
        title: Text(label, style: const TextStyle(color: Colors.white)),
        content: Text(
          detail,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(isOwner ? 'Delete' : 'Leave'),
          ),
        ],
      ),
    );
    if (shouldContinue != true) return;

    await _runAction(() => widget.repo.leaveCalendar(calendar.id));
  }

  Future<void> _setCalendarVisible(
    SharedCalendarSummary calendar,
    bool visible,
  ) async {
    await widget.repo.setCalendarVisible(calendar.id, visible);
    final snapshot = _snapshot;
    if (snapshot == null || !mounted) return;
    final hidden = Set<String>.from(snapshot.hiddenCalendarIds);
    if (visible) {
      hidden.remove(calendar.id);
    } else {
      hidden.add(calendar.id);
    }
    setState(() {
      _snapshot = SharedCalendarsSnapshot(
        calendars: snapshot.calendars,
        pendingInvites: snapshot.pendingInvites,
        hiddenCalendarIds: hidden,
      );
    });
    _changed = true;
  }

  DateTime get _calendarEventWindowStartUtc {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).toUtc();
  }

  Future<List<FiledEvent>> _fetchCalendarEvents(
    String calendarId, {
    required bool fullLoad,
  }) {
    return widget.repo.getCalendarFiledEvents(
      calendarId,
      pageSize: fullLoad
          ? _calendarEventFullPageSize
          : _calendarEventPreviewLimit,
      maxRows: fullLoad ? null : _calendarEventPreviewLimit,
      startsOnOrAfterUtc: fullLoad ? null : _calendarEventWindowStartUtc,
    );
  }

  Future<List<FiledEvent>> _fetchCalendarEventsWithRetry(
    String calendarId, {
    required bool fullLoad,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        return await _fetchCalendarEvents(calendarId, fullLoad: fullLoad);
      } catch (e) {
        lastError = e;
        if (attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
      }
    }
    Error.throwWithStackTrace(
      lastError ?? StateError('Calendar event load failed'),
      StackTrace.current,
    );
  }

  Future<void> _loadCalendarEventsById(
    String calendarId, {
    bool fullLoad = false,
  }) async {
    final trimmed = calendarId.trim();
    if (trimmed.isEmpty || _loadingCalendarEventIds.contains(trimmed)) return;

    setState(() {
      _calendarEventErrorsById.remove(trimmed);
      _loadingCalendarEventIds.add(trimmed);
    });

    try {
      final events = await _fetchCalendarEventsWithRetry(
        trimmed,
        fullLoad: fullLoad,
      );
      if (!mounted) return;
      setState(() {
        _calendarEventsById[trimmed] = events;
        if (fullLoad) {
          _fullyLoadedCalendarEventIds.add(trimmed);
        } else {
          _fullyLoadedCalendarEventIds.remove(trimmed);
        }
        _loadingCalendarEventIds.remove(trimmed);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingCalendarEventIds.remove(trimmed);
        if ((_calendarEventsById[trimmed] ?? const <FiledEvent>[]).isEmpty) {
          _calendarEventErrorsById[trimmed] =
              'Could not load events for this calendar.';
        }
      });
    }
  }

  Future<void> _toggleCalendarEvents(SharedCalendarSummary calendar) async {
    final calendarId = calendar.id.trim();
    if (calendarId.isEmpty) return;

    if (_expandedCalendarIds.contains(calendarId)) {
      setState(() {
        _expandedCalendarIds.remove(calendarId);
        _showAllCalendarEventIds.remove(calendarId);
      });
      _notifyContinuityChanged();
      return;
    }

    setState(() {
      _expandedCalendarIds.add(calendarId);
      _calendarEventErrorsById.remove(calendarId);
    });
    _notifyContinuityChanged();

    if (!_calendarEventsById.containsKey(calendarId)) {
      await _loadCalendarEventsById(calendarId);
    }
  }

  Future<void> _hydrateExpandedCalendarEvents() async {
    final snapshot = _snapshot;
    if (snapshot == null) return;
    final allowedCalendarIds = snapshot.calendars
        .map((calendar) => calendar.id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (allowedCalendarIds.isEmpty) return;

    final ids = _expandedCalendarIds
        .where(
          (id) =>
              allowedCalendarIds.contains(id) &&
              !_calendarEventsById.containsKey(id) &&
              !_loadingCalendarEventIds.contains(id),
        )
        .toList(growable: false);
    if (ids.isEmpty) return;

    await Future.wait(ids.map(_loadCalendarEventsById));
  }

  Future<_CalendarEditorResult?> _showCalendarEditor({
    String initialName = '',
    int? initialColorValue,
  }) async {
    return showDialog<_CalendarEditorResult>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => _CalendarEditorDialog(
        initialName: initialName,
        initialColorValue: initialColorValue ?? _palette.first,
        palette: _palette,
      ),
    );
  }

  Future<_BirthdayEditorResult?> _showBirthdayEditor() {
    return showDialog<_BirthdayEditorResult>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => const _BirthdayEditorDialog(),
    );
  }

  void _showSheetMessage(String message) {
    final overlayContext = Navigator.of(
      context,
      rootNavigator: true,
    ).overlay?.context;
    final messenger =
        (overlayContext == null
            ? null
            : ScaffoldMessenger.maybeOf(overlayContext)) ??
        ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final content = Stack(
      children: [
        Column(
          children: [
            if (!widget.routeMode)
              const Padding(
                padding: EdgeInsets.only(top: 11),
                child: _H3wSheetGrabber(),
              ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          H3wCalendarSheetTokens.gold,
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _reload,
                      color: H3wCalendarSheetTokens.gold,
                      backgroundColor: H3wCalendarSheetTokens.cardBase,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
                        children: [
                          _sheetHeader(),
                          const _H3wHeaderDivider(),
                          if (snapshot != null &&
                              snapshot.pendingInvites.isNotEmpty) ...[
                            _sectionTitle('Invites'),
                            for (final invite in snapshot.pendingInvites)
                              _inviteCard(invite),
                          ],
                          _sectionTitle('Your calendars'),
                          if (snapshot == null || snapshot.calendars.isEmpty)
                            _emptyState()
                          else
                            for (final calendar in snapshot.calendars)
                              _calendarTile(calendar, snapshot),
                        ],
                      ),
                    ),
            ),
          ],
        ),
        if (widget.showCloseButton)
          Positioned(
            top: 20,
            right: 22,
            child: IconButton(
              tooltip: 'Close',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 34, height: 34),
              visualDensity: VisualDensity.compact,
              onPressed:
                  widget.onClose ?? () => Navigator.of(context).pop(_changed),
              icon: const Icon(
                Icons.close,
                color: H3wCalendarSheetTokens.gold,
                size: 24,
              ),
            ),
          ),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: H3wCalendarSheetTokens.pageBase,
        borderRadius: widget.routeMode
            ? BorderRadius.zero
            : const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: widget.routeMode
            ? null
            : const [
                BoxShadow(
                  color: Color(0x8C000000),
                  blurRadius: 40,
                  offset: Offset(0, -10),
                ),
              ],
      ),
      child: SafeArea(
        top: widget.routeMode && widget.routeModeSafeAreaTop,
        child: widget.routeMode
            ? SizedBox.expand(child: content)
            : SizedBox(
                height: MediaQuery.of(context).size.height * 0.9,
                child: content,
              ),
      ),
    );
  }

  Widget _sheetHeader() {
    return Padding(
      padding: EdgeInsets.only(
        top: widget.routeMode ? 14 : 14,
        right: widget.showCloseButton ? 44 : 0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Calendars',
                  style: TextStyle(
                    color: H3wCalendarSheetTokens.gold,
                    fontSize: 33,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                    letterSpacing: 0.3,
                    fontFamily: H3wCalendarSheetTokens.serif,
                    fontFamilyFallback: H3wCalendarSheetTokens.serifFallback,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Manage shared calendars and in-app invites',
                  style: TextStyle(
                    color: H3wCalendarSheetTokens.silverMid,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    fontFamily: H3wCalendarSheetTokens.serif,
                    fontFamilyFallback: H3wCalendarSheetTokens.serifFallback,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          _H3wAddCircleButton(
            tooltip: 'New calendar',
            onPressed: _saving ? null : _createCalendar,
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 20, 2, 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: H3wCalendarSheetTokens.silverLo,
          fontSize: 13,
          fontWeight: FontWeight.w400,
          letterSpacing: 1.6,
          fontFamily: H3wCalendarSheetTokens.serif,
          fontFamilyFallback: H3wCalendarSheetTokens.serifFallback,
        ),
      ),
    );
  }

  Widget _emptyState() {
    return H3wCalendarCardSurface(
      accent: H3wCalendarSheetTokens.gold,
      isPersonal: true,
      padding: const EdgeInsets.all(18),
      child: Text(
        'Create a family calendar, a friends calendar, or another shared space.',
        style: const TextStyle(
          color: H3wCalendarSheetTokens.silverMid,
          fontSize: 15,
          fontWeight: FontWeight.w400,
          fontFamily: H3wCalendarSheetTokens.serif,
          fontFamilyFallback: H3wCalendarSheetTokens.serifFallback,
        ),
      ),
    );
  }

  Widget _calendarTile(
    SharedCalendarSummary calendar,
    SharedCalendarsSnapshot snapshot,
  ) {
    final isVisible = !snapshot.hiddenCalendarIds.contains(calendar.id);
    final isOwner = calendar.role == SharedCalendarRole.owner;
    final isExpanded = _expandedCalendarIds.contains(calendar.id);
    final accent = _cardAccent(calendar);
    final accentLight = _cardAccentLight(calendar);

    return H3wCalendarCardSurface(
      accent: accent,
      isPersonal: calendar.isPersonal,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _toggleCalendarEvents(calendar),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _calendarDot(accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              calendar.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: calendar.isPersonal
                                    ? H3wCalendarSheetTokens.gold
                                    : accentLight,
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                height: 1.1,
                                fontFamily: H3wCalendarSheetTokens.serif,
                                fontFamilyFallback:
                                    H3wCalendarSheetTokens.serifFallback,
                              ),
                            ),
                            const SizedBox(height: 2),
                            _calendarSubtitle(calendar),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.ease,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: H3wCalendarSheetTokens.silverMid,
                          size: 19,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              if (calendar.isBirthdays) ...[
                _H3wRowIconButton(
                  key: const ValueKey<String>('birthdays-calendar-add-button'),
                  tooltip: 'Add birthday',
                  icon: Icons.add,
                  color: accentLight,
                  onPressed: _saving ? null : () => _createBirthday(calendar),
                ),
                const SizedBox(width: 10),
              ],
              _H3wVisibilityToggle(
                value: isVisible,
                accent: accent,
                knobColor: accentLight,
                isPersonal: calendar.isPersonal,
                onChanged: (value) => _setCalendarVisible(calendar, value),
              ),
            ],
          ),
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 320),
              curve: Curves.ease,
              alignment: Alignment.topCenter,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: isExpanded ? 1 : 0,
                child: isExpanded
                    ? Column(
                        children: [
                          const SizedBox(height: 15),
                          _calendarEventsDropdown(calendar),
                          if (!calendar.isPersonal && !calendar.isSystem)
                            _calendarFooterActions(calendar, isOwner),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _calendarDot(Color accent) {
    return Container(
      width: 13,
      height: 13,
      margin: const EdgeInsets.only(top: 5),
      decoration: BoxDecoration(
        color: accent,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.50), blurRadius: 8),
        ],
      ),
    );
  }

  Widget _calendarSubtitle(SharedCalendarSummary calendar) {
    if (calendar.isPersonal) {
      return const Text(
        'Personal calendar',
        style: TextStyle(
          color: H3wCalendarSheetTokens.silverMid,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          fontFamily: H3wCalendarSheetTokens.serif,
          fontFamilyFallback: H3wCalendarSheetTokens.serifFallback,
        ),
      );
    }

    final memberLabel =
        '${calendar.memberCount} ${calendar.memberCount == 1 ? 'member' : 'members'}';
    final memberText = Text(
      memberLabel,
      style: const TextStyle(
        color: H3wCalendarSheetTokens.silverHi,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        fontFamily: H3wCalendarSheetTokens.serif,
        fontFamilyFallback: H3wCalendarSheetTokens.serifFallback,
      ),
    );

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (calendar.canSeeMemberRoster)
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => _showMembersSheet(calendar),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: memberText,
            ),
          )
        else
          memberText,
        const Text(
          ' · ',
          style: TextStyle(
            color: H3wCalendarSheetTokens.silverLo,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            fontFamily: H3wCalendarSheetTokens.serif,
            fontFamilyFallback: H3wCalendarSheetTokens.serifFallback,
          ),
        ),
        Text(
          calendar.roleLabel,
          style: const TextStyle(
            color: H3wCalendarSheetTokens.silverMid,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            fontFamily: H3wCalendarSheetTokens.serif,
            fontFamilyFallback: H3wCalendarSheetTokens.serifFallback,
          ),
        ),
      ],
    );
  }

  Widget _pendingInviteLink(SharedCalendarSummary calendar) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => _showMembersSheet(calendar, pendingFirst: true),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
          decoration: BoxDecoration(
            color: H3wCalendarSheetTokens.gold.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            '${calendar.pendingInviteCount} pending',
            style: const TextStyle(
              color: H3wCalendarSheetTokens.goldChipText,
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
              height: 1.7,
              fontFamily: H3wCalendarSheetTokens.serif,
              fontFamilyFallback: H3wCalendarSheetTokens.serifFallback,
            ),
          ),
        ),
      ),
    );
  }

  Widget _calendarFooterActions(SharedCalendarSummary calendar, bool isOwner) {
    final accentLight = _cardAccentLight(calendar);
    final hasLeftActions =
        calendar.canManageMembership ||
        calendar.role == SharedCalendarRole.owner ||
        (calendar.canEditEvents && widget.onAddEventRequested != null) ||
        (calendar.canSeePendingInvites && calendar.pendingInviteCount > 0);

    return Container(
      margin: const EdgeInsets.only(top: 15),
      padding: const EdgeInsets.only(top: 13),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          if (hasLeftActions)
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 18,
                runSpacing: 8,
                children: [
                  if (calendar.canManageMembership)
                    _H3wFooterIconButton(
                      tooltip: 'Invite',
                      icon: Icons.person_add_alt_1_outlined,
                      color: accentLight,
                      onPressed: _saving
                          ? null
                          : () => _inviteToCalendar(calendar),
                    ),
                  if (calendar.role == SharedCalendarRole.owner)
                    _H3wFooterIconButton(
                      tooltip: 'Edit',
                      icon: Icons.edit_outlined,
                      color: accentLight,
                      onPressed: _saving ? null : () => _editCalendar(calendar),
                    ),
                  if (calendar.canEditEvents &&
                      widget.onAddEventRequested != null)
                    _H3wFooterIconButton(
                      tooltip: 'Add event',
                      icon: Icons.add_circle_outline,
                      color: accentLight,
                      onPressed: _saving
                          ? null
                          : () => _addEventToCalendar(calendar),
                    ),
                  if (calendar.canSeePendingInvites &&
                      calendar.pendingInviteCount > 0)
                    _pendingInviteLink(calendar),
                ],
              ),
            )
          else
            const Spacer(),
          TextButton(
            onPressed: _saving ? null : () => _leaveCalendar(calendar),
            style: TextButton.styleFrom(
              foregroundColor: H3wCalendarSheetTokens.silverMid,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                fontFamily: H3wCalendarSheetTokens.serif,
                fontFamilyFallback: H3wCalendarSheetTokens.serifFallback,
              ),
            ),
            child: Text(isOwner ? 'Delete' : 'Leave'),
          ),
        ],
      ),
    );
  }

  Widget _calendarEventsDropdown(SharedCalendarSummary calendar) {
    final calendarId = calendar.id;
    final isLoading = _loadingCalendarEventIds.contains(calendarId);
    final error = _calendarEventErrorsById[calendarId];
    final events = _calendarEventsById[calendarId] ?? const <FiledEvent>[];
    final accent = _cardAccent(calendar);
    final accentLight = _cardAccentLight(calendar);
    final panelAccent = calendar.isPersonal
        ? H3wCalendarSheetTokens.gold
        : accent;
    final panelTitleColor = calendar.isPersonal
        ? H3wCalendarSheetTokens.goldChipText
        : accentLight;
    final showAll = _showAllCalendarEventIds.contains(calendarId);
    final fullyLoaded = _fullyLoadedCalendarEventIds.contains(calendarId);
    final totalCount = calendar.liveEventCount > events.length
        ? calendar.liveEventCount
        : events.length;
    final hasMoreEvents = !fullyLoaded && totalCount > events.length;
    final visibleEvents = events;

    Widget body;
    if (isLoading && events.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(panelTitleColor),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Loading events...',
              style: TextStyle(
                color: H3wCalendarSheetTokens.silverMid,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                fontFamily: H3wCalendarSheetTokens.serif,
                fontFamilyFallback: H3wCalendarSheetTokens.serifFallback,
              ),
            ),
          ],
        ),
      );
    } else if (error != null && events.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Text(
          error,
          style: const TextStyle(
            color: H3wCalendarSheetTokens.repeatPinkLight,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            fontFamily: H3wCalendarSheetTokens.serif,
            fontFamilyFallback: H3wCalendarSheetTokens.serifFallback,
          ),
        ),
      );
    } else if (events.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: const Text(
          'No events on this calendar.',
          style: TextStyle(
            color: H3wCalendarSheetTokens.silverMid,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            fontFamily: H3wCalendarSheetTokens.serif,
            fontFamilyFallback: H3wCalendarSheetTokens.serifFallback,
          ),
        ),
      );
    } else {
      body = Column(
        children: [
          for (var i = 0; i < visibleEvents.length; i++)
            _calendarEventRow(
              visibleEvents[i],
              calendar,
              showTopBorder: i != 0,
            ),
          if (events.length > visibleEvents.length)
            _showAllEventsButton(calendar, totalCount, panelTitleColor),
          if (!showAll &&
              events.length <= visibleEvents.length &&
              totalCount > visibleEvents.length)
            _showAllEventsButton(calendar, totalCount, panelTitleColor),
          if (showAll && isLoading && hasMoreEvents)
            _loadingMoreEventsRow(panelTitleColor),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 6),
      decoration: BoxDecoration(
        color: panelAccent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: panelAccent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: panelTitleColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Upcoming events',
                style: TextStyle(
                  color: panelTitleColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  fontFamily: H3wCalendarSheetTokens.serif,
                  fontFamilyFallback: H3wCalendarSheetTokens.serifFallback,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '· $totalCount',
                style: const TextStyle(
                  color: H3wCalendarSheetTokens.silverLo,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  fontFamily: H3wCalendarSheetTokens.serif,
                  fontFamilyFallback: H3wCalendarSheetTokens.serifFallback,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          body,
        ],
      ),
    );
  }

  Widget _calendarEventRow(
    FiledEvent filedEvent,
    SharedCalendarSummary calendar, {
    bool showTopBorder = false,
  }) {
    final event = filedEvent.event;
    final title = event.title.trim().isEmpty ? 'Untitled event' : event.title;
    final meta = _eventMetaText(filedEvent);
    final repeatLabel = _eventRepeatLabel(event.detail);
    final eventColor = _eventDotColor(filedEvent, calendar);

    final canOpenEvent = widget.onEventTapRequested != null;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: canOpenEvent
          ? () => _openCalendarEvent(calendar, filedEvent)
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          border: showTopBorder
              ? Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                )
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: eventColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: H3wCalendarSheetTokens.silverHi,
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      fontFamily: H3wCalendarSheetTokens.serif,
                      fontFamilyFallback: H3wCalendarSheetTokens.serifFallback,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 7,
              runSpacing: 6,
              children: [
                _eventChip(
                  icon: Icons.access_time,
                  text: meta,
                  fill: H3wCalendarSheetTokens.gold.withValues(alpha: 0.10),
                  color: H3wCalendarSheetTokens.goldChipText,
                ),
                if (repeatLabel != null)
                  _eventChip(
                    icon: Icons.repeat,
                    text: repeatLabel,
                    fill: eventColor == H3wCalendarSheetTokens.eventGreen
                        ? H3wCalendarSheetTokens.eventGreen.withValues(
                            alpha: 0.14,
                          )
                        : H3wCalendarSheetTokens.repeatPink.withValues(
                            alpha: 0.13,
                          ),
                    color: eventColor == H3wCalendarSheetTokens.eventGreen
                        ? const Color(0xFFA9D391)
                        : H3wCalendarSheetTokens.repeatPinkLight,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _showAllEventsButton(
    SharedCalendarSummary calendar,
    int count,
    Color color,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        setState(() => _showAllCalendarEventIds.add(calendar.id));
        if (!_fullyLoadedCalendarEventIds.contains(calendar.id)) {
          unawaited(_loadCalendarEventsById(calendar.id, fullLoad: true));
        }
      },
      child: Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 5),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Show all $count',
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  fontFamily: H3wCalendarSheetTokens.serif,
                  fontFamilyFallback: H3wCalendarSheetTokens.serifFallback,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down_rounded, color: color, size: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _loadingMoreEventsRow(Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 5),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.6,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(width: 7),
            Text(
              'Loading more',
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                fontFamily: H3wCalendarSheetTokens.serif,
                fontFamilyFallback: H3wCalendarSheetTokens.serifFallback,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _eventChip({
    required IconData icon,
    required String text,
    required Color fill,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 5),
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w400,
              height: 1.7,
              fontFamily: H3wCalendarSheetTokens.serif,
              fontFamilyFallback: H3wCalendarSheetTokens.serifFallback,
            ),
          ),
        ],
      ),
    );
  }

  String _eventMetaText(FiledEvent filedEvent) {
    final event = filedEvent.event;
    final localStart = event.startsAt.toLocal();
    final datePattern = localStart.year == DateTime.now().year
        ? 'EEE, MMM d'
        : 'EEE, MMM d, y';
    final day = DateFormat(datePattern).format(localStart);
    if (event.allDay) return '$day • All day';

    final startPeriod = DateFormat('a').format(localStart);
    final start = DateFormat('h:mm').format(localStart);
    final end = event.endsAt == null
        ? null
        : () {
            final localEnd = event.endsAt!.toLocal();
            final endPeriod = DateFormat('a').format(localEnd);
            if (endPeriod == startPeriod) {
              return '${DateFormat('h:mm').format(localEnd)} $endPeriod';
            }
            return DateFormat('h:mm a').format(localEnd);
          }();
    return end == null ? '$day • $start $startPeriod' : '$day • $start–$end';
  }

  Color _cardAccent(SharedCalendarSummary calendar) {
    return calendar.isPersonal ? H3wCalendarSheetTokens.gold : calendar.color;
  }

  Color _cardAccentLight(SharedCalendarSummary calendar) {
    if (calendar.isPersonal) return H3wCalendarSheetTokens.gold;
    final accent = calendar.color;
    if (accent.toARGB32() == H3wCalendarSheetTokens.sharedAccent.toARGB32()) {
      return H3wCalendarSheetTokens.sharedAccentLight;
    }
    return Color.lerp(accent, Colors.white, 0.34) ?? accent;
  }

  Color _eventDotColor(FiledEvent filedEvent, SharedCalendarSummary calendar) {
    final explicit = _detailColor(filedEvent.event.detail);
    if (explicit != null) return explicit;
    final eventColor = filedEvent.event.calendarColor;
    if (eventColor != null) return Color(0xFF000000 | (eventColor & 0xFFFFFF));
    return calendar.color;
  }

  Color? _detailColor(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final match = RegExp(r'(?:^|;)color=([0-9a-fA-FxX]+);').firstMatch(raw);
    final hex = match?.group(1);
    if (hex == null) return null;
    try {
      final rgb = hex.toLowerCase().startsWith('0x')
          ? int.parse(hex)
          : int.parse('0x$hex');
      return Color(0xFF000000 | (rgb & 0x00FFFFFF));
    } catch (_) {
      return null;
    }
  }

  String? _eventRepeatLabel(String? detail) {
    if (detail == null || detail.isEmpty) return null;
    const marker = 'repeat=';
    final idx = detail.indexOf(marker);
    if (idx < 0) return null;
    final start = idx + marker.length;
    final end = detail.indexOf(';', start);
    final jsonStr = (end >= 0)
        ? detail.substring(start, end)
        : detail.substring(start);
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map<String, dynamic>) return null;
      final repeat = ReminderRepeat.fromJson(decoded);
      return _repeatLabel(repeat);
    } catch (_) {
      return null;
    }
  }

  String? _repeatLabel(ReminderRepeat repeat) {
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

    switch (repeat.kind) {
      case ReminderRepeatKind.none:
        return null;
      case ReminderRepeatKind.everyNDays:
        final interval = repeat.interval <= 0 ? 1 : repeat.interval;
        return interval == 1 ? 'Every day' : 'Every $interval days';
      case ReminderRepeatKind.weekly:
        if (repeat.weekdays.isEmpty) return 'Weekly';
        const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final weekdays = repeat.weekdays.toList()..sort();
        return 'Weekly ${weekdays.map((d) => labels[(d - 1).clamp(0, 6)]).join('/')}';
      case ReminderRepeatKind.monthlyDay:
        final days = repeat.monthDays.isEmpty
            ? <int>[if (repeat.monthDay != null) repeat.monthDay!]
            : (repeat.monthDays.toList()..sort());
        if (days.isEmpty) return 'Monthly';
        return 'Monthly ${days.map(ordinal).join(', ')}';
      case ReminderRepeatKind.kemeticEveryNDecans:
        final interval = repeat.interval <= 0 ? 1 : repeat.interval;
        return interval == 1 ? 'Every decan' : 'Every $interval decans';
      case ReminderRepeatKind.kemeticDecanDay:
        final days = repeat.decanDays.toList()..sort();
        return days.isEmpty
            ? 'Each decan'
            : 'Each decan · day ${days.join(', ')}';
      case ReminderRepeatKind.kemeticMonthDay:
        final days = repeat.kemeticMonthDays.toList()..sort();
        return days.isEmpty
            ? 'Monthly · K'
            : 'Monthly ${days.map(ordinal).join(', ')} · K';
    }
  }

  Widget _inviteCard(SharedCalendarInvite invite) {
    return H3wCalendarCardSurface(
      accent: invite.color,
      isPersonal: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _calendarDot(invite.color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  invite.calendarName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color.lerp(invite.color, Colors.white, 0.34),
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                    fontFamily: H3wCalendarSheetTokens.serif,
                    fontFamilyFallback: H3wCalendarSheetTokens.serifFallback,
                  ),
                ),
              ),
              Text(
                invite.role == SharedCalendarRole.viewer
                    ? 'View only'
                    : 'Can edit',
                style: const TextStyle(
                  color: H3wCalendarSheetTokens.silverMid,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  fontFamily: H3wCalendarSheetTokens.serif,
                  fontFamilyFallback: H3wCalendarSheetTokens.serifFallback,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${invite.inviterLabel} invited you to join this calendar.',
            style: const TextStyle(
              color: H3wCalendarSheetTokens.silverMid,
              fontSize: 14,
              fontWeight: FontWeight.w400,
              fontFamily: H3wCalendarSheetTokens.serif,
              fontFamilyFallback: H3wCalendarSheetTokens.serifFallback,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving
                      ? null
                      : () => _runAction(() async {
                          await widget.repo.respondToInvite(
                            calendarId: invite.calendarId,
                            accept: false,
                            invite: invite,
                          );
                        }),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: H3wCalendarSheetTokens.sharedAccentLight,
                    side: BorderSide(
                      color: H3wCalendarSheetTokens.sharedAccentLight
                          .withValues(alpha: 0.42),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w400,
                      fontFamily: H3wCalendarSheetTokens.serif,
                      fontFamilyFallback: H3wCalendarSheetTokens.serifFallback,
                    ),
                  ),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: invite.color.withValues(alpha: 0.24),
                    foregroundColor: H3wCalendarSheetTokens.silverHi,
                    textStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      fontFamily: H3wCalendarSheetTokens.serif,
                      fontFamilyFallback: H3wCalendarSheetTokens.serifFallback,
                    ),
                  ),
                  onPressed: _saving
                      ? null
                      : () => _runAction(() async {
                          await widget.repo.respondToInvite(
                            calendarId: invite.calendarId,
                            accept: true,
                            invite: invite,
                          );
                        }),
                  child: const Text('Accept'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _H3wSheetGrabber extends StatelessWidget {
  const _H3wSheetGrabber();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 5,
        decoration: BoxDecoration(
          color: const Color(0xFF3A352C),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}

class _H3wHeaderDivider extends StatelessWidget {
  const _H3wHeaderDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.only(top: 18),
      color: Colors.white.withValues(alpha: 0.07),
    );
  }
}

class _H3wAddCircleButton extends StatelessWidget {
  const _H3wAddCircleButton({required this.tooltip, required this.onPressed});

  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: H3wCalendarSheetTokens.gold.withValues(alpha: 0.50),
              width: 1.4,
            ),
          ),
          child: const Icon(
            Icons.add,
            color: H3wCalendarSheetTokens.gold,
            size: 17,
          ),
        ),
      ),
    );
  }
}

class _H3wRowIconButton extends StatelessWidget {
  const _H3wRowIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.56)),
            color: color.withValues(alpha: 0.08),
          ),
          child: Icon(icon, color: color, size: 17),
        ),
      ),
    );
  }
}

class H3wCalendarCardSurface extends StatelessWidget {
  const H3wCalendarCardSurface({
    super.key,
    required this.accent,
    required this.isPersonal,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final Color accent;
  final bool isPersonal;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final borderColor = isPersonal
        ? H3wCalendarSheetTokens.gold.withValues(alpha: 0.30)
        : accent.withValues(alpha: 0.32);
    final washColor = isPersonal
        ? H3wCalendarSheetTokens.gold.withValues(alpha: 0.10)
        : accent.withValues(alpha: 0.14);
    final crownColor = isPersonal
        ? H3wCalendarSheetTokens.glyphGlow.withValues(alpha: 0.10)
        : H3wCalendarSheetTokens.sharedAccentLight.withValues(alpha: 0.12);
    final hairColor = isPersonal
        ? H3wCalendarSheetTokens.glyphGlow.withValues(alpha: 0.35)
        : H3wCalendarSheetTokens.sharedAccentLight.withValues(alpha: 0.40);

    return Container(
      margin: const EdgeInsets.only(top: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: H3wCalendarSheetTokens.cardBase,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -1.18),
                      radius: isPersonal ? 1.20 : 1.24,
                      colors: [washColor, Colors.transparent],
                      stops: [0.0, isPersonal ? 0.60 : 0.62],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: -110,
                height: 220,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topCenter,
                      radius: 0.72,
                      colors: [crownColor, Colors.transparent],
                      stops: const [0.0, 0.70],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        hairColor,
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: const SizedBox(height: 1),
                ),
              ),
              Padding(padding: padding, child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _H3wVisibilityToggle extends StatelessWidget {
  const _H3wVisibilityToggle({
    required this.value,
    required this.accent,
    required this.knobColor,
    required this.isPersonal,
    required this.onChanged,
  });

  final bool value;
  final Color accent;
  final Color knobColor;
  final bool isPersonal;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final trackAlpha = value ? (isPersonal ? 0.25 : 0.30) : 0.08;
    final borderAlpha = value ? (isPersonal ? 0.40 : 0.45) : 0.16;

    return Tooltip(
      message: value ? 'Hide calendar' : 'Show calendar',
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 54,
          height: 30,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: trackAlpha),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: borderAlpha)),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            curve: Curves.ease,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: value ? knobColor : H3wCalendarSheetTokens.silverLo,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _H3wFooterIconButton extends StatelessWidget {
  const _H3wFooterIconButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Icon(icon, color: color, size: 19),
        ),
      ),
    );
  }
}

class CalendarMembersSheet extends StatefulWidget {
  const CalendarMembersSheet({
    super.key,
    required this.repo,
    required this.calendar,
    this.pendingFirst = false,
  });

  final SharedCalendarsRepo repo;
  final SharedCalendarSummary calendar;
  final bool pendingFirst;

  static Future<bool?> show(
    BuildContext context, {
    required SharedCalendarsRepo repo,
    required SharedCalendarSummary calendar,
    bool pendingFirst = false,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CalendarMembersSheet(
        repo: repo,
        calendar: calendar,
        pendingFirst: pendingFirst,
      ),
    );
  }

  @override
  State<CalendarMembersSheet> createState() => _CalendarMembersSheetState();
}

class _CalendarMembersSheetState extends State<CalendarMembersSheet> {
  List<SharedCalendarMember> _members = const <SharedCalendarMember>[];
  String? _loadError;
  String? _actionError;
  bool _loading = true;
  bool _saving = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final members = await widget.repo.listMembers(
        widget.calendar.id,
        includePending: widget.calendar.canSeePendingInvites,
        expectedMemberCount: widget.calendar.memberCount,
        expectedPendingCount: widget.calendar.pendingInviteCount,
      );
      if (!mounted) return;
      setState(() {
        _members = members;
        _loadError = null;
        _actionError = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loading = false;
      });
      _showSheetMessage(e.toString());
    }
  }

  Future<void> _runAction(Future<void> Function() action) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _actionError = null;
    });
    try {
      await action();
      _changed = true;
      await _reload();
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionError = e.toString());
      _showSheetMessage(e.toString());
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<bool> _confirm({
    required String title,
    required String detail,
    required String actionLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111214),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(
          detail,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    return result == true;
  }

  void _showSheetMessage(String message) {
    final overlayContext = Navigator.of(
      context,
      rootNavigator: true,
    ).overlay?.context;
    final messenger =
        (overlayContext == null
            ? null
            : ScaffoldMessenger.maybeOf(overlayContext)) ??
        ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _changeRole(
    SharedCalendarMember member,
    SharedCalendarRole role,
  ) async {
    if (member.isOwner) return;
    if (role == member.role) {
      _showSheetMessage(
        '${member.displayLabel} is already ${member.roleLabel.toLowerCase()}.',
      );
      return;
    }
    await _runAction(() {
      return widget.repo.updateMemberRole(
        calendarId: widget.calendar.id,
        userId: member.userId,
        role: role,
      );
    });
  }

  Future<void> _pickRole(
    SharedCalendarMember member,
    BuildContext anchorContext,
  ) async {
    if (_saving || member.isOwner) return;

    final anchorObject = anchorContext.findRenderObject();
    final overlay = Navigator.of(context, rootNavigator: true).overlay;
    final overlayObject = overlay?.context.findRenderObject();
    if (anchorObject is! RenderBox || overlayObject is! RenderBox) {
      _showSheetMessage('Role menu is unavailable right now.');
      return;
    }

    final topLeft = anchorObject.localToGlobal(
      Offset.zero,
      ancestor: overlayObject,
    );
    final bottomRight = anchorObject.localToGlobal(
      Offset(anchorObject.size.width, anchorObject.size.height),
      ancestor: overlayObject,
    );
    final selected = await showMenu<SharedCalendarRole>(
      context: context,
      useRootNavigator: true,
      color: const Color(0xFF1A1B1E),
      initialValue: member.role,
      position: RelativeRect.fromRect(
        Rect.fromPoints(topLeft, bottomRight),
        Offset.zero & overlayObject.size,
      ),
      items: [
        _roleMenuItem(
          role: SharedCalendarRole.editor,
          currentRole: member.role,
          label: 'Can edit',
        ),
        _roleMenuItem(
          role: SharedCalendarRole.viewer,
          currentRole: member.role,
          label: 'View only',
        ),
      ],
    );
    if (!mounted || selected == null) return;
    await _changeRole(member, selected);
  }

  PopupMenuItem<SharedCalendarRole> _roleMenuItem({
    required SharedCalendarRole role,
    required SharedCalendarRole currentRole,
    required String label,
  }) {
    final selected = role == currentRole;
    return PopupMenuItem<SharedCalendarRole>(
      value: role,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 18,
            child: selected
                ? Icon(Icons.check, color: widget.calendar.color, size: 16)
                : null,
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Future<void> _removeMember(SharedCalendarMember member) async {
    if (member.isOwner) return;
    final confirmed = await _confirm(
      title: 'Remove member?',
      detail: '${member.displayLabel} will lose access to this calendar.',
      actionLabel: 'Remove',
    );
    if (!confirmed) return;
    await _runAction(() {
      return widget.repo.removeMember(
        calendarId: widget.calendar.id,
        userId: member.userId,
      );
    });
  }

  Future<void> _revokeInvite(SharedCalendarMember member) async {
    final confirmed = await _confirm(
      title: 'Revoke invite?',
      detail: '${member.displayLabel} will no longer be able to accept it.',
      actionLabel: 'Revoke',
    );
    if (!confirmed) return;
    await _runAction(() {
      return widget.repo.revokeInvite(
        calendarId: widget.calendar.id,
        userId: member.userId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final accepted = _members
        .where((member) => member.status == SharedCalendarInviteStatus.accepted)
        .toList(growable: false);
    final pending = _members
        .where((member) => member.status == SharedCalendarInviteStatus.pending)
        .toList(growable: false);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.82,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GlossyText(
                            text: widget.pendingFirst
                                ? 'Pending invites'
                                : 'Members',
                            gradient: goldGloss,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.calendar.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFBFC3C7),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: _saving ? null : _reload,
                      icon: KemeticGold.icon(Icons.refresh),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(_changed),
                      icon: KemeticGold.icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            KemeticGold.base,
                          ),
                        ),
                      )
                    : _loadError != null
                    ? _loadErrorView()
                    : RefreshIndicator(
                        onRefresh: _reload,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                          children: _sectionWidgets(accepted, pending),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _sectionWidgets(
    List<SharedCalendarMember> accepted,
    List<SharedCalendarMember> pending,
  ) {
    final sections = <Widget>[];
    if (_actionError != null) {
      sections.add(_actionErrorBanner(_actionError!));
      sections.add(const SizedBox(height: 12));
    }

    void addAccepted() {
      sections.add(_sectionTitle('Members'));
      sections.add(const SizedBox(height: 10));
      if (accepted.isEmpty) {
        sections.add(_emptyText('No accepted members yet.'));
      } else {
        for (final member in accepted) {
          sections.add(_memberRow(member));
        }
      }
    }

    void addPending() {
      if (pending.isEmpty && !widget.pendingFirst) return;
      sections.add(const SizedBox(height: 18));
      sections.add(_sectionTitle('Pending'));
      sections.add(const SizedBox(height: 10));
      if (pending.isEmpty) {
        sections.add(_emptyText('No pending invites.'));
      } else {
        for (final member in pending) {
          sections.add(_memberRow(member));
        }
      }
    }

    if (widget.pendingFirst) {
      sections.add(_sectionTitle('Pending'));
      sections.add(const SizedBox(height: 10));
      if (pending.isEmpty) {
        sections.add(_emptyText('No pending invites.'));
      } else {
        for (final member in pending) {
          sections.add(_memberRow(member));
        }
      }
      sections.add(const SizedBox(height: 18));
      addAccepted();
    } else {
      addAccepted();
      addPending();
    }

    return sections;
  }

  Widget _actionErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF101114),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE85D75)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFE85D75), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 12,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Dismiss',
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => _actionError = null),
            icon: const Icon(Icons.close, color: Colors.white54, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _loadErrorView() {
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF101114),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE85D75)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Could not load members',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _loadError ?? 'Unknown error',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.66),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.8),
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _emptyText(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        text,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.62)),
      ),
    );
  }

  Widget _memberRow(SharedCalendarMember member) {
    final canManage =
        widget.calendar.canManageMembership && !member.isOwner && !_saving;
    final subtitle = member.handleLabel;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF101114),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          _avatar(member),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.displayLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.52),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _roleControl(member, canManage: canManage),
          if (canManage) ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip: member.isPending ? 'Revoke invite' : 'Remove member',
              onPressed: member.isPending
                  ? () => _revokeInvite(member)
                  : () => _removeMember(member),
              icon: Icon(
                member.isPending
                    ? Icons.cancel_outlined
                    : Icons.person_remove_alt_1_outlined,
                color: const Color(0xFFE85D75),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _avatar(SharedCalendarMember member) {
    final avatarUrl = member.avatarUrl?.trim();
    final label = member.displayLabel.trim();
    final initial = label.isEmpty ? '?' : label.substring(0, 1).toUpperCase();
    return CircleAvatar(
      radius: 20,
      backgroundColor: widget.calendar.color.withValues(alpha: 0.18),
      backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
          ? NetworkImage(avatarUrl)
          : null,
      child: avatarUrl == null || avatarUrl.isEmpty
          ? Text(
              initial,
              style: TextStyle(
                color: widget.calendar.color,
                fontWeight: FontWeight.w800,
              ),
            )
          : null,
    );
  }

  Widget _roleControl(SharedCalendarMember member, {required bool canManage}) {
    if (!canManage) {
      return _roleChip(member.roleLabel, editable: false);
    }

    return Builder(
      builder: (chipContext) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _saving ? null : () => _pickRole(member, chipContext),
        child: _roleChip(member.roleLabel, editable: true),
      ),
    );
  }

  Widget _roleChip(String label, {required bool editable}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: widget.calendar.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: widget.calendar.color.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: widget.calendar.color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (editable) ...[
            const SizedBox(width: 3),
            Icon(Icons.arrow_drop_down, color: widget.calendar.color, size: 18),
          ],
        ],
      ),
    );
  }
}

class _BirthdayEditorResult {
  const _BirthdayEditorResult({
    required this.name,
    required this.birthday,
    required this.alertOffsetMinutes,
  });

  final String name;
  final DateTime birthday;
  final int alertOffsetMinutes;
}

class _BirthdayEditorDialog extends StatefulWidget {
  const _BirthdayEditorDialog();

  @override
  State<_BirthdayEditorDialog> createState() => _BirthdayEditorDialogState();
}

class _BirthdayEditorDialogState extends State<_BirthdayEditorDialog> {
  final TextEditingController _nameCtrl = TextEditingController();
  DateTime? _birthday;
  int _alertOffsetMinutes = kBirthdayNoAlertMinutes;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: H3wCalendarSheetTokens.silverMid),
      isDense: true,
      filled: true,
      fillColor: const Color(0xFF211C14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: H3wCalendarSheetTokens.gold),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: H3wCalendarSheetTokens.repeatPink),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: H3wCalendarSheetTokens.repeatPinkLight,
        ),
      ),
    );
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(now.year - 130),
      lastDate: DateTime(now.year + 1, 12, 31),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: H3wCalendarSheetTokens.gold,
              surface: Color(0xFF16130D),
              onSurface: Colors.white,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xFF16130D),
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() {
      _birthday = DateUtils.dateOnly(picked);
      _error = null;
    });
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required.');
      return;
    }
    final birthday = _birthday;
    if (birthday == null) {
      setState(() => _error = 'Birthday date is required.');
      return;
    }
    Navigator.of(context).pop(
      _BirthdayEditorResult(
        name: name,
        birthday: birthday,
        alertOffsetMinutes: _alertOffsetMinutes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final birthdayLabel = _birthday == null
        ? 'Choose date'
        : DateFormat.yMMMMd().format(_birthday!);

    return KemeticKeyboardRevealScope(
      enabled: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 26),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
          decoration: BoxDecoration(
            color: const Color(0xFF16130D),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Color(
                kBirthdaysCalendarColorValue,
              ).withValues(alpha: 0.35),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x99000000),
                blurRadius: 60,
                offset: Offset(0, 20),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add Birthday',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w600,
                    fontFamily: H3wCalendarSheetTokens.serif,
                    fontFamilyFallback: H3wCalendarSheetTokens.serifFallback,
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  key: const ValueKey<String>('birthday-name-field'),
                  controller: _nameCtrl,
                  autofocus: true,
                  cursorColor: H3wCalendarSheetTokens.gold,
                  scrollPadding: keyboardManagedTextFieldScrollPadding,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                    fontFamily: H3wCalendarSheetTokens.serif,
                    fontFamilyFallback: H3wCalendarSheetTokens.serifFallback,
                  ),
                  decoration: _inputDecoration('Name'),
                ),
                const SizedBox(height: 12),
                InkWell(
                  key: const ValueKey<String>('birthday-date-picker'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: _pickBirthday,
                  child: InputDecorator(
                    decoration: _inputDecoration('Birthday'),
                    child: Text(
                      birthdayLabel,
                      style: TextStyle(
                        color: _birthday == null
                            ? H3wCalendarSheetTokens.silverMid
                            : Colors.white,
                        fontSize: 17,
                        fontFamily: H3wCalendarSheetTokens.serif,
                        fontFamilyFallback:
                            H3wCalendarSheetTokens.serifFallback,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  key: const ValueKey<String>('birthday-alert-picker'),
                  initialValue: _alertOffsetMinutes,
                  dropdownColor: const Color(0xFF211C14),
                  iconEnabledColor: H3wCalendarSheetTokens.gold,
                  decoration: _inputDecoration('Alert'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontFamily: H3wCalendarSheetTokens.serif,
                    fontFamilyFallback: H3wCalendarSheetTokens.serifFallback,
                  ),
                  items: [
                    for (final option in kBirthdayAlertOptions)
                      DropdownMenuItem<int>(
                        value: option,
                        child: Text(birthdayAlertLabel(option)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _alertOffsetMinutes = value);
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: H3wCalendarSheetTokens.repeatPinkLight,
                      fontSize: 13,
                      fontFamily: H3wCalendarSheetTokens.serif,
                      fontFamilyFallback: H3wCalendarSheetTokens.serifFallback,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: H3wCalendarSheetTokens.silverMid,
                        textStyle: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w400,
                          fontFamily: H3wCalendarSheetTokens.serif,
                          fontFamilyFallback:
                              H3wCalendarSheetTokens.serifFallback,
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 22),
                    TextButton(
                      key: const ValueKey<String>('birthday-save-button'),
                      onPressed: _save,
                      style: TextButton.styleFrom(
                        foregroundColor: Color(kBirthdaysCalendarColorValue),
                        textStyle: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          fontFamily: H3wCalendarSheetTokens.serif,
                          fontFamilyFallback:
                              H3wCalendarSheetTokens.serifFallback,
                        ),
                      ),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarEditorResult {
  const _CalendarEditorResult({required this.name, required this.colorValue});

  final String name;
  final int colorValue;
}

class _CalendarEditorDialog extends StatefulWidget {
  const _CalendarEditorDialog({
    required this.initialName,
    required this.initialColorValue,
    required this.palette,
  });

  final String initialName;
  final int initialColorValue;
  final List<int> palette;

  @override
  State<_CalendarEditorDialog> createState() => _CalendarEditorDialogState();
}

class _CalendarEditorDialogState extends State<_CalendarEditorDialog> {
  late final TextEditingController _nameCtrl = TextEditingController(
    text: widget.initialName,
  );
  late int _selectedColor = widget.initialColorValue;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KemeticKeyboardRevealScope(
      enabled: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 26),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
          decoration: BoxDecoration(
            color: const Color(0xFF16130D),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: H3wCalendarSheetTokens.gold.withValues(alpha: 0.25),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x99000000),
                blurRadius: 60,
                offset: Offset(0, 20),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.initialName.isEmpty ? 'New Calendar' : 'Edit Calendar',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w600,
                    fontFamily: H3wCalendarSheetTokens.serif,
                    fontFamilyFallback: H3wCalendarSheetTokens.serifFallback,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Name',
                  style: TextStyle(
                    color: H3wCalendarSheetTokens.silverMid,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    fontFamily: H3wCalendarSheetTokens.serif,
                    fontFamilyFallback: H3wCalendarSheetTokens.serifFallback,
                  ),
                ),
                const SizedBox(height: 7),
                TextField(
                  controller: _nameCtrl,
                  autofocus: true,
                  cursorColor: H3wCalendarSheetTokens.sharedAccent,
                  scrollPadding: keyboardManagedTextFieldScrollPadding,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                    fontFamily: H3wCalendarSheetTokens.serif,
                    fontFamilyFallback: H3wCalendarSheetTokens.serifFallback,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFF211C14),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: H3wCalendarSheetTokens.sharedAccent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Color',
                  style: TextStyle(
                    color: H3wCalendarSheetTokens.silverMid,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    fontFamily: H3wCalendarSheetTokens.serif,
                    fontFamilyFallback: H3wCalendarSheetTokens.serifFallback,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: widget.palette
                      .map((colorValue) {
                        final selected = colorValue == _selectedColor;
                        return InkWell(
                          onTap: () {
                            setState(() => _selectedColor = colorValue);
                          },
                          borderRadius: BorderRadius.circular(23),
                          child: Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: Color(colorValue),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          ),
                        );
                      })
                      .toList(growable: false),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor:
                            H3wCalendarSheetTokens.sharedAccentLight,
                        textStyle: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w400,
                          fontFamily: H3wCalendarSheetTokens.serif,
                          fontFamilyFallback:
                              H3wCalendarSheetTokens.serifFallback,
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 26),
                    TextButton(
                      onPressed: () {
                        final name = _nameCtrl.text.trim();
                        if (name.isEmpty) return;
                        Navigator.of(context).pop(
                          _CalendarEditorResult(
                            name: name,
                            colorValue: _selectedColor,
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor:
                            H3wCalendarSheetTokens.sharedAccentLight,
                        textStyle: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                          fontFamily: H3wCalendarSheetTokens.serif,
                          fontFamilyFallback:
                              H3wCalendarSheetTokens.serifFallback,
                        ),
                      ),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
