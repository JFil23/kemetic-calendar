import 'package:flutter/material.dart';

import '../../data/shared_calendar_models.dart';
import '../../data/shared_calendars_repo.dart';
import '../../features/profile/profile_search_page.dart';
import '../../shared/glossy_text.dart';

class SharedCalendarsSheet extends StatefulWidget {
  const SharedCalendarsSheet({super.key, required this.repo});

  final SharedCalendarsRepo repo;

  static Future<bool?> show(
    BuildContext context, {
    required SharedCalendarsRepo repo,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SharedCalendarsSheet(repo: repo),
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
  bool _loading = true;
  bool _saving = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
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
    final userId = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const ProfileSearchPage(
          titleText: 'Invite to Calendar',
          hintText: 'Search by @handle or display name',
        ),
      ),
    );
    if (userId == null || userId.trim().isEmpty) return;

    final trimmedUserId = userId.trim();
    await _runAction(() async {
      await widget.repo.inviteUser(
        calendarId: calendar.id,
        userId: trimmedUserId,
      );
      await widget.repo.sendCalendarPush(
        userIds: <String>[trimmedUserId],
        title: calendar.name,
        body: 'You were invited to join this calendar.',
        data: <String, dynamic>{
          'kind': 'calendar_invite',
          'calendar_id': calendar.id,
          'calendar_name': calendar.name,
          'calendar_color': calendar.colorValue,
        },
      );
    });
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF101114),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          children: [
            Row(
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
                      Text(
                        calendar.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
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
                Switch(
                  value: isVisible,
                  activeThumbColor: calendar.color,
                  onChanged: (value) => _setCalendarVisible(calendar, value),
                ),
              ],
            ),
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
                    TextButton.icon(
                      onPressed: _saving
                          ? null
                          : () => _inviteToCalendar(calendar),
                      icon: Icon(Icons.person_add_alt_1, color: calendar.color),
                      label: const Text('Invite'),
                    ),
                  if (calendar.role == SharedCalendarRole.owner)
                    TextButton.icon(
                      onPressed: _saving ? null : () => _editCalendar(calendar),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
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

  Widget _inviteCard(SharedCalendarInvite invite) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF101114),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
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
                  child: Text(
                    invite.calendarName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
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
                            );
                            final inviterId = invite.invitedBy?.trim();
                            if (inviterId != null && inviterId.isNotEmpty) {
                              await widget.repo.sendCalendarPush(
                                userIds: <String>[inviterId],
                                title: invite.calendarName,
                                body: 'Your calendar invitation was declined.',
                                data: <String, dynamic>{
                                  'kind': 'calendar_invite_response',
                                  'calendar_id': invite.calendarId,
                                  'calendar_name': invite.calendarName,
                                  'calendar_color': invite.calendarColorValue,
                                  'invite_status': 'declined',
                                },
                              );
                            }
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
                            );
                            final inviterId = invite.invitedBy?.trim();
                            if (inviterId != null && inviterId.isNotEmpty) {
                              await widget.repo.sendCalendarPush(
                                userIds: <String>[inviterId],
                                title: invite.calendarName,
                                body: 'Your calendar invitation was accepted.',
                                data: <String, dynamic>{
                                  'kind': 'calendar_invite_response',
                                  'calendar_id': invite.calendarId,
                                  'calendar_name': invite.calendarName,
                                  'calendar_color': invite.calendarColorValue,
                                  'invite_status': 'accepted',
                                },
                              );
                            }
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
