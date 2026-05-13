import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/event_filing_engine.dart';
import '../../data/shared_calendar_models.dart';
import '../../data/shared_calendars_repo.dart';
import '../../shared/glossy_text.dart';

typedef SharedCalendarAddEventCallback =
    Future<bool> Function(SharedCalendarSummary calendar);

class SharedCalendarsSheet extends StatefulWidget {
  const SharedCalendarsSheet({
    super.key,
    required this.repo,
    this.onAddEventRequested,
    this.initialExpandedCalendarIds = const <String>[],
    this.onContinuityChanged,
  });

  final SharedCalendarsRepo repo;
  final SharedCalendarAddEventCallback? onAddEventRequested;
  final List<String> initialExpandedCalendarIds;
  final ValueChanged<Map<String, dynamic>>? onContinuityChanged;

  static Future<bool?> show(
    BuildContext context, {
    required SharedCalendarsRepo repo,
    SharedCalendarAddEventCallback? onAddEventRequested,
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _leaveCalendar(SharedCalendarSummary calendar) async {
    final isOwner = calendar.role == SharedCalendarRole.owner;
    final label = isOwner ? 'Delete calendar?' : 'Leave calendar?';
    final detail = isOwner
        ? 'This removes the shared calendar and its events for everyone.'
        : 'You will stop seeing events from this calendar.';
    final shouldContinue = await showDialog<bool>(
      context: context,
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
    final ids = _expandedCalendarIds
        .where(
          (id) =>
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
      builder: (ctx) => _CalendarEditorDialog(
        initialName: initialName,
        initialColorValue: initialColorValue ?? _palette.first,
        palette: _palette,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.9,
          child: Column(
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
                            style: TextStyle(
                              color: Color(0xFFBFC3C7),
                              fontSize: 13,
                            ),
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
          ),
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
                          Text(
                            calendar.isPersonal
                                ? 'Personal calendar'
                                : '${calendar.memberCount} members • ${calendar.roleLabel}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.62),
                              fontSize: 13,
                            ),
                          ),
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
                  if (calendar.pendingInviteCount > 0)
                    Text(
                      '${calendar.pendingInviteCount} pending',
                      style: TextStyle(
                        color: calendar.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (calendar.canManageMembers)
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
                  if (calendar.canEdit && widget.onAddEventRequested != null)
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

    return Padding(
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
    return AlertDialog(
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
    );
  }
}
