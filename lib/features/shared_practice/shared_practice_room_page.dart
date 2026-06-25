import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/completion_status.dart';
import '../../data/shared_practice_models.dart';
import '../../data/shared_practice_repo.dart';
import 'shared_practice_completion_sheet.dart';

const Color _base = Color(0xFF0B0906);
const Color _panel = Color(0xFF15110B);
const Color _gold = Color(0xFFD4AE43);
const Color _ink = Color(0xFFE7E0D2);
const Color _muted = Color(0xFF9E9A94);
const String _serif = 'CormorantGaramond';

class SharedPracticeRoomPage extends StatefulWidget {
  const SharedPracticeRoomPage({super.key, required this.roomId});

  final String roomId;

  @override
  State<SharedPracticeRoomPage> createState() => _SharedPracticeRoomPageState();
}

class _SharedPracticeRoomPageState extends State<SharedPracticeRoomPage> {
  late final SharedPracticeRepo _repo = SharedPracticeRepo(
    Supabase.instance.client,
  );
  late Future<SharedPracticeRoomSnapshot> _future;
  SharedPracticeRoomSnapshot? _snapshot;
  String? _presenceMarkedForClientEventId;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<SharedPracticeRoomSnapshot> _load() async {
    final snapshot = await _repo.getSharedPracticeRoom(
      roomId: widget.roomId,
      localDate: DateTime.now(),
    );
    if (mounted) {
      setState(() {
        _snapshot = snapshot;
      });
    } else {
      _snapshot = snapshot;
    }
    unawaited(_markOpened(snapshot));
    return snapshot;
  }

  Future<void> _markOpened(SharedPracticeRoomSnapshot snapshot) async {
    final step = snapshot.todayStep;
    if (step == null ||
        step.clientEventId.isEmpty ||
        _presenceMarkedForClientEventId == step.clientEventId) {
      return;
    }
    _presenceMarkedForClientEventId = step.clientEventId;
    try {
      await _repo.markSharedStepOpened(
        roomId: snapshot.room.id,
        clientEventId: step.clientEventId,
        openedOn: snapshot.localDate,
      );
    } catch (_) {
      _presenceMarkedForClientEventId = null;
    }
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _openCompletionSheet(
    SharedPracticeRoomSnapshot snapshot, {
    CompletionStatus initialStatus = CompletionStatus.observed,
  }) async {
    final step = snapshot.todayStep;
    if (step == null || step.clientEventId.isEmpty || step.flowId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Today\'s shared step is not available.')),
      );
      return;
    }
    final saved = await showSharedPracticeCompletionSheet(
      context: context,
      roomId: snapshot.room.id,
      calendarName: snapshot.calendar.name,
      clientEventId: step.clientEventId,
      flowId: step.flowId,
      completedOn: snapshot.localDate,
      initialStatus: initialStatus,
      stepTitle: step.title,
      completionMetadata: <String, dynamic>{
        'completion_status': initialStatus.wireName,
        'source_type': 'maat_flow',
        'completed_on': _dateOnly(snapshot.localDate),
        'flow_title': snapshot.room.title,
        'event_title': step.title,
        if (snapshot.room.flowKey?.trim().isNotEmpty == true)
          'flow_key': snapshot.room.flowKey!.trim(),
      },
    );
    if (saved && mounted) _refresh();
  }

  void _openEntry(SharedPracticeEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EntrySheet(entry: entry),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _base,
      appBar: AppBar(
        backgroundColor: _base,
        foregroundColor: _gold,
        elevation: 0,
        title: const Text('Shared Practice'),
      ),
      body: FutureBuilder<SharedPracticeRoomSnapshot>(
        future: _future,
        builder: (context, snapshot) {
          final data = snapshot.data ?? _snapshot;
          if (data == null) {
            if (snapshot.hasError) {
              return _ErrorState(onRetry: _refresh);
            }
            return const Center(child: CircularProgressIndicator(color: _gold));
          }
          return RefreshIndicator(
            color: _gold,
            backgroundColor: _panel,
            onRefresh: () async => _refresh(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
              children: [
                _RoomHeader(snapshot: data),
                const SizedBox(height: 18),
                _MemberSection(
                  snapshot: data,
                  onOpenEntry: (entryId) {
                    final entry = data.visibleEntryById(entryId);
                    if (entry != null) _openEntry(entry);
                  },
                ),
                const SizedBox(height: 18),
                _EntriesSection(entries: data.entries, onOpenEntry: _openEntry),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: _snapshot == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => unawaited(
                          _openCompletionSheet(
                            _snapshot!,
                            initialStatus: CompletionStatus.observed,
                          ),
                        ),
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('Keep today\'s step'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _gold,
                          foregroundColor: const Color(0xFF181106),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filledTonal(
                      onPressed: () => unawaited(
                        _openCompletionSheet(
                          _snapshot!,
                          initialStatus: CompletionStatus.partial,
                        ),
                      ),
                      tooltip: 'Share note',
                      icon: const Icon(Icons.edit_note),
                      style: IconButton.styleFrom(
                        foregroundColor: _gold,
                        backgroundColor: _panel,
                        side: BorderSide(color: _gold.withValues(alpha: 0.4)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _RoomHeader extends StatelessWidget {
  const _RoomHeader({required this.snapshot});

  final SharedPracticeRoomSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final step = snapshot.todayStep;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          snapshot.calendar.name.toUpperCase(),
          style: const TextStyle(
            color: _gold,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          snapshot.room.title,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: _serif,
            fontSize: 42,
            fontWeight: FontWeight.w600,
            height: 0.98,
          ),
        ),
        const SizedBox(height: 8),
        if (step != null)
          Text(
            _stepLine(step),
            style: const TextStyle(color: _muted, fontSize: 13, height: 1.35),
          ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
          decoration: BoxDecoration(
            color: _panel.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _gold.withValues(alpha: 0.22)),
          ),
          child: Text(
            snapshot.factualSummary,
            style: const TextStyle(
              color: _ink,
              fontFamily: _serif,
              fontStyle: FontStyle.italic,
              fontSize: 20,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}

class _MemberSection extends StatelessWidget {
  const _MemberSection({required this.snapshot, required this.onOpenEntry});

  final SharedPracticeRoomSnapshot snapshot;
  final ValueChanged<String?> onOpenEntry;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Today\'s Circle',
      child: Column(
        children: [
          for (var i = 0; i < snapshot.members.length; i++) ...[
            if (i > 0) Divider(color: Colors.white.withValues(alpha: 0.07)),
            _MemberRow(member: snapshot.members[i], onOpenEntry: onOpenEntry),
          ],
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member, required this.onOpenEntry});

  final SharedPracticeMemberStatus member;
  final ValueChanged<String?> onOpenEntry;

  @override
  Widget build(BuildContext context) {
    final status = _statusLabel(member);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Avatar(label: member.displayLabel),
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
                    fontFamily: _serif,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  status,
                  style: TextStyle(
                    color: _statusColor(member),
                    fontSize: 12.5,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (member.progressLabel.isNotEmpty)
                Text(
                  member.progressLabel,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.42),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              const SizedBox(height: 5),
              InkWell(
                onTap: member.entryAvailableToViewer && member.entryHasBody
                    ? () => onOpenEntry(member.entryId)
                    : null,
                borderRadius: BorderRadius.circular(999),
                child: Text(
                  member.entryActionLabel,
                  style: TextStyle(
                    color: member.entryAvailableToViewer && member.entryHasBody
                        ? _gold
                        : Colors.white.withValues(alpha: 0.42),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EntriesSection extends StatelessWidget {
  const _EntriesSection({required this.entries, required this.onOpenEntry});

  final List<SharedPracticeEntry> entries;
  final ValueChanged<SharedPracticeEntry> onOpenEntry;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Shared Entries',
      child: entries.isEmpty
          ? Text(
              'No shared entries today.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontFamily: _serif,
                fontStyle: FontStyle.italic,
                fontSize: 17,
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < entries.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _EntryCard(entry: entries[i], onTap: onOpenEntry),
                ],
              ],
            ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, required this.onTap});

  final SharedPracticeEntry entry;
  final ValueChanged<SharedPracticeEntry> onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onTap(entry),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(14),
          border: Border(
            left: BorderSide(color: _entryAccent(entry), width: 2),
            top: BorderSide(color: Colors.white.withValues(alpha: 0.09)),
            right: BorderSide(color: Colors.white.withValues(alpha: 0.09)),
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.09)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Avatar(label: entry.authorLabel, size: 28),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    entry.authorLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: _serif,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _StatusPill(status: entry.completionStatus),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              entry.bodyText ?? '',
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _ink,
                fontFamily: _serif,
                fontSize: 18,
                height: 1.34,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntrySheet extends StatelessWidget {
  const _EntrySheet({required this.entry});

  final SharedPracticeEntry entry;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Color(0x55D4AE43))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _Avatar(label: entry.authorLabel),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      entry.authorLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: _serif,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _StatusPill(status: entry.completionStatus),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                entry.bodyText ?? '',
                style: const TextStyle(
                  color: _ink,
                  fontFamily: _serif,
                  fontSize: 23,
                  height: 1.38,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                entry.visibility == SharedPracticeVisibility.private
                    ? 'Private entry'
                    : 'Shared with calendar',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.44),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panel.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: _gold,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final CompletionStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: _completionColor(status).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: _completionColor(status).withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        _completionLabel(status),
        style: TextStyle(
          color: _completionColor(status),
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.label, this.size = 40});

  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final clean = label.replaceFirst('@', '').trim();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _gold,
        shape: BoxShape.circle,
        border: Border.all(color: _base, width: 2),
      ),
      child: Text(
        clean.isEmpty ? 'M' : clean.substring(0, 1).toUpperCase(),
        style: TextStyle(
          color: const Color(0xFF181106),
          fontFamily: _serif,
          fontSize: size * 0.44,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: _gold, size: 32),
            const SizedBox(height: 12),
            const Text(
              'Shared practice could not be loaded.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: _gold,
                side: const BorderSide(color: _gold),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

String _stepLine(SharedPracticeStep step) {
  final index = step.stepIndex;
  final total = step.totalSteps;
  if (index != null && total != null && total > 0) {
    return 'Today: ${step.title} · Step $index of $total';
  }
  return 'Today: ${step.title}';
}

String _statusLabel(SharedPracticeMemberStatus member) {
  switch (member.completionStatus) {
    case CompletionStatus.observed:
      return 'observed today';
    case CompletionStatus.partial:
      return 'partly completed today';
    case CompletionStatus.skipped:
      return 'skipped today';
    case CompletionStatus.none:
      switch (member.presenceStatus) {
        case SharedPracticePresenceStatus.carrying:
          return 'carrying today\'s step';
        case SharedPracticePresenceStatus.notYet:
          return 'not yet today';
      }
  }
}

String _completionLabel(CompletionStatus status) {
  switch (status) {
    case CompletionStatus.observed:
      return 'OBSERVED';
    case CompletionStatus.partial:
      return 'PARTLY';
    case CompletionStatus.skipped:
      return 'SKIPPED';
    case CompletionStatus.none:
      return 'NONE';
  }
}

Color _statusColor(SharedPracticeMemberStatus member) {
  if (member.completionStatus != CompletionStatus.none) {
    return _completionColor(member.completionStatus);
  }
  switch (member.presenceStatus) {
    case SharedPracticePresenceStatus.carrying:
      return const Color(0xFFB8A88A);
    case SharedPracticePresenceStatus.notYet:
      return const Color(0xFF6A6660);
  }
}

Color _completionColor(CompletionStatus status) {
  switch (status) {
    case CompletionStatus.observed:
      return const Color(0xFF9FB87A);
    case CompletionStatus.partial:
      return const Color(0xFFD8A24A);
    case CompletionStatus.skipped:
      return const Color(0xFF7C776E);
    case CompletionStatus.none:
      return const Color(0xFF6A6660);
  }
}

Color _entryAccent(SharedPracticeEntry entry) {
  return _completionColor(entry.completionStatus);
}

String _dateOnly(DateTime value) {
  final local = DateTime(value.year, value.month, value.day);
  return [
    local.year.toString().padLeft(4, '0'),
    local.month.toString().padLeft(2, '0'),
    local.day.toString().padLeft(2, '0'),
  ].join('-');
}
