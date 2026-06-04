import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/event_filing_engine.dart';
import '../../data/shared_calendar_models.dart';
import '../../data/shared_calendars_repo.dart';
import '../../shared/glossy_text.dart';
import '../../widgets/kemetic_keyboard.dart';
import '../../widgets/keyboard_aware.dart';

typedef SharedCalendarAddEventCallback =
    Future<bool> Function(SharedCalendarSummary calendar);

typedef SharedCalendarEventTapCallback =
    Future<void> Function(
      SharedCalendarSummary calendar,
      FiledEvent filedEvent, {
      List<FiledEvent> calendarEvents,
    });

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
  });

  final SharedCalendarsRepo repo;
  final SharedCalendarAddEventCallback? onAddEventRequested;
  final SharedCalendarEventTapCallback? onEventTapRequested;
  final List<String> initialExpandedCalendarIds;
  final ValueChanged<Map<String, dynamic>>? onContinuityChanged;
  final bool routeMode;
  final bool dismissOnEventTap;
  final VoidCallback? onClose;

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
  static const List<int> _palette = <int>[
    0xFFD4AF37,
    0xFF6AA7FF,
    0xFF57C785,
    0xFFFF8C42,
    0xFFE85D75,
    0xFF8E7CFF,
  ];

  SharedCalendarsSnapshot? _snapshot;
  final Set<String> _expandedCalendarIds = <String>{};
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

  Future<void> _toggleCalendarEvents(SharedCalendarSummary calendar) async {
    final calendarId = calendar.id.trim();
    if (calendarId.isEmpty) return;

    if (_expandedCalendarIds.contains(calendarId)) {
      setState(() => _expandedCalendarIds.remove(calendarId));
      _notifyContinuityChanged();
      return;
    }

    setState(() {
      _expandedCalendarIds.add(calendarId);
      _calendarEventErrorsById.remove(calendarId);
      _calendarEventsById.remove(calendarId);
      _loadingCalendarEventIds.add(calendarId);
    });
    _notifyContinuityChanged();

    try {
      final events = await widget.repo.getCalendarFiledEvents(calendarId);
      if (!mounted) return;
      setState(() {
        _calendarEventsById[calendarId] = events;
        _loadingCalendarEventIds.remove(calendarId);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingCalendarEventIds.remove(calendarId);
        _calendarEventErrorsById[calendarId] =
            'Could not load events for this calendar.';
      });
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

    for (final calendarId in ids) {
      if (!mounted) return;
      setState(() {
        _calendarEventErrorsById.remove(calendarId);
        _loadingCalendarEventIds.add(calendarId);
      });
      try {
        final events = await widget.repo.getCalendarFiledEvents(calendarId);
        if (!mounted) return;
        setState(() {
          _calendarEventsById[calendarId] = events;
          _loadingCalendarEventIds.remove(calendarId);
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _loadingCalendarEventIds.remove(calendarId);
          _calendarEventErrorsById[calendarId] =
              'Could not load events for this calendar.';
        });
      }
    }
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
    final content = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    GlossyText(
                      text: 'Calendars',
                      gradient: goldGloss,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Manage shared calendars and in-app invites',
                      style: TextStyle(color: Color(0xFFBFC3C7), fontSize: 13),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'New calendar',
                onPressed: _saving ? null : _createCalendar,
                icon: KemeticGold.icon(Icons.add_circle_outline),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed:
                    widget.onClose ?? () => Navigator.of(context).pop(_changed),
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
                    valueColor: AlwaysStoppedAnimation<Color>(KemeticGold.base),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      if (snapshot != null &&
                          snapshot.pendingInvites.isNotEmpty) ...[
                        _sectionTitle('Invites'),
                        const SizedBox(height: 10),
                        for (final invite in snapshot.pendingInvites)
                          _inviteCard(invite),
                        const SizedBox(height: 18),
                      ],
                      _sectionTitle('Your calendars'),
                      const SizedBox(height: 10),
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
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: widget.routeMode
            ? BorderRadius.zero
            : const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: widget.routeMode,
        child: widget.routeMode
            ? SizedBox.expand(child: content)
            : SizedBox(
                height: MediaQuery.of(context).size.height * 0.9,
                child: content,
              ),
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

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF101114),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        'Create a family calendar, a friends calendar, or another shared space.',
        style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _toggleCalendarEvents(calendar),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: calendar.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          KemeticGold.text(
                            calendar.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.fade,
                          ),
                          const SizedBox(height: 4),
                          _calendarSubtitle(calendar),
                        ],
                      ),
                    ),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: calendar.color,
                    ),
                    const SizedBox(width: 6),
                    Switch(
                      value: isVisible,
                      activeThumbColor: calendar.color,
                      onChanged: (value) =>
                          _setCalendarVisible(calendar, value),
                    ),
                  ],
                ),
              ),
            ),
            if (isExpanded) ...[
              const SizedBox(height: 12),
              _calendarEventsDropdown(calendar),
            ],
            if (!calendar.isPersonal) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isOwner
                          ? 'Owned by you'
                          : 'Owned by ${calendar.ownerLabel}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.56),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (calendar.canSeePendingInvites &&
                      calendar.pendingInviteCount > 0)
                    _pendingInviteLink(calendar),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (calendar.canManageMembership)
                    IconButton(
                      tooltip: 'Invite',
                      onPressed: _saving
                          ? null
                          : () => _inviteToCalendar(calendar),
                      icon: Icon(Icons.person_add_alt_1, color: calendar.color),
                    ),
                  if (calendar.role == SharedCalendarRole.owner)
                    IconButton(
                      tooltip: 'Edit',
                      onPressed: _saving ? null : () => _editCalendar(calendar),
                      icon: Icon(Icons.edit_outlined, color: calendar.color),
                    ),
                  if (calendar.canEditEvents &&
                      widget.onAddEventRequested != null)
                    IconButton(
                      tooltip: 'Add event',
                      onPressed: _saving
                          ? null
                          : () => _addEventToCalendar(calendar),
                      icon: Icon(
                        Icons.add_circle_outline,
                        color: calendar.color,
                      ),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: _saving ? null : () => _leaveCalendar(calendar),
                    child: Text(isOwner ? 'Delete' : 'Leave'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _calendarSubtitle(SharedCalendarSummary calendar) {
    final style = TextStyle(
      color: Colors.white.withValues(alpha: 0.62),
      fontSize: 13,
    );
    if (calendar.isPersonal) {
      return Text('Personal calendar', style: style);
    }

    final memberLabel =
        '${calendar.memberCount} ${calendar.memberCount == 1 ? 'member' : 'members'}';
    final memberText = Text(
      memberLabel,
      style: calendar.canSeeMemberRoster
          ? style.copyWith(color: calendar.color, fontWeight: FontWeight.w700)
          : style,
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
        Text(' • ${calendar.roleLabel}', style: style),
      ],
    );
  }

  Widget _pendingInviteLink(SharedCalendarSummary calendar) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => _showMembersSheet(calendar, pendingFirst: true),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Text(
          '${calendar.pendingInviteCount} pending',
          style: TextStyle(
            color: calendar.color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _calendarEventsDropdown(SharedCalendarSummary calendar) {
    final calendarId = calendar.id;
    final isLoading = _loadingCalendarEventIds.contains(calendarId);
    final error = _calendarEventErrorsById[calendarId];
    final events = _calendarEventsById[calendarId] ?? const <FiledEvent>[];

    Widget body;
    if (isLoading) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(calendar.color),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Loading events...',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.68)),
            ),
          ],
        ),
      );
    } else if (error != null) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          error,
          style: const TextStyle(color: Color(0xFFE85D75), fontSize: 13),
        ),
      );
    } else if (events.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          'No events on this calendar.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.62)),
        ),
      );
    } else {
      body = Column(
        children: [
          for (var i = 0; i < events.length; i++) ...[
            _calendarEventRow(events[i], calendar),
            if (i != events.length - 1)
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
          ],
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: calendar.color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_note_rounded, size: 16, color: calendar.color),
              const SizedBox(width: 6),
              Text(
                events.isEmpty && !isLoading
                    ? 'Upcoming events'
                    : 'Upcoming events (${events.length})',
                style: TextStyle(
                  color: calendar.color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          body,
        ],
      ),
    );
  }

  Widget _calendarEventRow(
    FiledEvent filedEvent,
    SharedCalendarSummary calendar,
  ) {
    final event = filedEvent.event;
    final title = event.title.trim().isEmpty ? 'Untitled event' : event.title;
    final meta = _eventMetaText(filedEvent);
    final detail = event.location?.trim().isNotEmpty == true
        ? event.location!.trim()
        : event.detail?.trim();

    final canOpenEvent = widget.onEventTapRequested != null;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: canOpenEvent
          ? () => _openCalendarEvent(calendar, filedEvent)
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                color: calendar.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 12,
                    ),
                  ),
                  if (detail != null && detail.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.48),
                        fontSize: 12,
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

  String _eventMetaText(FiledEvent filedEvent) {
    final event = filedEvent.event;
    final localStart = event.startsAt.toLocal();
    final datePattern = localStart.year == DateTime.now().year
        ? 'EEE, MMM d'
        : 'EEE, MMM d, y';
    final day = DateFormat(datePattern).format(localStart);
    if (event.allDay) return '$day • All day';

    final start = DateFormat('h:mm a').format(localStart);
    final end = event.endsAt == null
        ? null
        : DateFormat('h:mm a').format(event.endsAt!.toLocal());
    return end == null ? '$day • $start' : '$day • $start-$end';
  }

  Widget _inviteCard(SharedCalendarInvite invite) {
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
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: invite.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: KemeticGold.text(
                    invite.calendarName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                  ),
                ),
                Text(
                  invite.role == SharedCalendarRole.viewer
                      ? 'View only'
                      : 'Can edit',
                  style: TextStyle(
                    color: invite.color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${invite.inviterLabel} invited you to join this calendar.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.68),
                fontSize: 13,
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
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: invite.color,
                      foregroundColor: Colors.black,
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
      child: AlertDialog(
        backgroundColor: const Color(0xFF111214),
        title: Text(
          widget.initialName.isEmpty ? 'New Calendar' : 'Edit Calendar',
          style: const TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _nameCtrl,
                  autofocus: true,
                  scrollPadding: keyboardManagedTextFieldScrollPadding,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Name',
                    labelStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF1A1B1E),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Color', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: widget.palette
                      .map((colorValue) {
                        final selected = colorValue == _selectedColor;
                        return InkWell(
                          onTap: () {
                            setState(() => _selectedColor = colorValue);
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Color(colorValue),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.12),
                                width: selected ? 3 : 1,
                              ),
                            ),
                          ),
                        );
                      })
                      .toList(growable: false),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = _nameCtrl.text.trim();
              if (name.isEmpty) return;
              Navigator.of(context).pop(
                _CalendarEditorResult(name: name, colorValue: _selectedColor),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
