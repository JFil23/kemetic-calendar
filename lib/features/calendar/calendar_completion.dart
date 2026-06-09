import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/core/completion_status.dart';
import 'package:mobile/features/journal/journal_event_badge.dart';

class CalendarCompletionRecord {
  const CalendarCompletionRecord({
    required this.completionStatus,
    this.reflectionStatus = ReflectionStatus.none,
  });

  final CompletionStatus completionStatus;
  final ReflectionStatus reflectionStatus;
}

class CalendarCompletionLocalStore {
  const CalendarCompletionLocalStore({this.scope = 'local'});

  final String scope;

  String _key(String identity) => 'calendar_completion:$scope:$identity';

  Future<CalendarCompletionRecord> load(String identity) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(identity));
    return CalendarCompletionRecord(
      completionStatus: CompletionStatusX.fromWireName(raw),
    );
  }

  Future<void> save({
    required String identity,
    required CompletionStatus status,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _key(identity);
    if (status == CompletionStatus.none) {
      await prefs.remove(key);
      return;
    }
    await prefs.setString(key, status.wireName);
  }
}

String calendarCompletionIdentity({
  String? eventId,
  String? clientEventId,
  String? reminderId,
  required String fallback,
}) {
  final id = eventId?.trim();
  if (id != null && id.isNotEmpty) return 'id:$id';

  final cid = clientEventId?.trim();
  if (cid != null && cid.isNotEmpty) return 'cid:$cid';

  final rid = reminderId?.trim();
  if (rid != null && rid.isNotEmpty) return 'rid:$rid';

  return 'sig:$fallback';
}

Color calendarCompletionBadgeColor(CompletionStatus status, Color eventColor) {
  switch (status) {
    case CompletionStatus.observed:
      return eventColor;
    case CompletionStatus.partial:
      return const Color(0xFFFFB347);
    case CompletionStatus.skipped:
      return Colors.white38;
    case CompletionStatus.none:
      return eventColor;
  }
}

String buildCalendarCompletionBadgeToken({
  required String identity,
  required CompletionSourceType sourceType,
  required CompletionStatus completionStatus,
  String? eventId,
  required String title,
  DateTime? start,
  DateTime? end,
  required Color color,
  String? description,
}) {
  final cleanTitle = title.trim().isEmpty ? 'Scheduled block' : title.trim();
  final cleanDescription = description?.trim();
  final statusLine = switch (completionStatus) {
    CompletionStatus.observed => 'Completion: observed.',
    CompletionStatus.partial => 'Completion: partial.',
    CompletionStatus.skipped => 'Completion: skipped.',
    CompletionStatus.none => '',
  };
  final details = <String>[
    if (statusLine.isNotEmpty) statusLine,
    if (cleanDescription != null && cleanDescription.isNotEmpty)
      cleanDescription,
  ].join(' ');

  return EventBadgeToken.buildToken(
    id: 'calendar:${sourceType.wireName}:$identity',
    eventId: eventId,
    title: cleanTitle,
    start: start,
    end: end,
    color: calendarCompletionBadgeColor(completionStatus, color),
    description: details.isEmpty ? null : details,
    completionStatus: completionStatus,
    sourceType: sourceType,
  );
}

Map<String, dynamic> calendarCompletionMetadata({
  required CompletionStatus completionStatus,
  required CompletionSourceType sourceType,
  required DateTime completedOnDate,
  String? flowTitle,
  String? eventTitle,
}) {
  final dateStr =
      '${completedOnDate.year}-${completedOnDate.month.toString().padLeft(2, '0')}-${completedOnDate.day.toString().padLeft(2, '0')}';
  return <String, dynamic>{
    'status': completionStatus.maatStatusName,
    'completion_status': completionStatus.wireName,
    'reflection_status': ReflectionStatus.none.wireName,
    'source_type': sourceType.wireName,
    'completed_on': dateStr,
    if (flowTitle != null && flowTitle.trim().isNotEmpty)
      'flow_title': flowTitle.trim(),
    if (eventTitle != null && eventTitle.trim().isNotEmpty)
      'event_title': eventTitle.trim(),
  };
}

class CalendarCompletionPicker extends StatelessWidget {
  const CalendarCompletionPicker({
    super.key,
    required this.current,
    required this.onChanged,
    this.saving = false,
    this.loading = false,
    this.showPartial = true,
    this.onReflect,
    this.observedButtonKey,
  });

  final CompletionStatus current;
  final ValueChanged<CompletionStatus> onChanged;
  final bool saving;
  final bool loading;
  final bool showPartial;
  final VoidCallback? onReflect;
  final Key? observedButtonKey;

  @override
  Widget build(BuildContext context) {
    final disabled = saving || loading;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFF5E8CB).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Completion',
            style: TextStyle(
              color: Color(0xFFFFD486),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _CompletionStatusButton(
                key: observedButtonKey,
                status: CompletionStatus.observed,
                current: current,
                saving: disabled,
                onChanged: onChanged,
              ),
              if (showPartial) ...[
                const SizedBox(width: 8),
                _CompletionStatusButton(
                  status: CompletionStatus.partial,
                  current: current,
                  saving: disabled,
                  onChanged: onChanged,
                ),
              ],
              const SizedBox(width: 8),
              _CompletionStatusButton(
                status: CompletionStatus.skipped,
                current: current,
                saving: disabled,
                onChanged: onChanged,
              ),
            ],
          ),
          if (onReflect != null &&
              (current == CompletionStatus.observed ||
                  current == CompletionStatus.partial)) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: disabled ? null : onReflect,
              icon: const Icon(
                Icons.edit_note,
                size: 18,
                color: Color(0xFFFFD486),
              ),
              label: const Text(
                'Add reflection',
                style: TextStyle(
                  color: Color(0xFFFFD486),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class CalendarEventCompletionPanel extends StatefulWidget {
  const CalendarEventCompletionPanel({
    super.key,
    required this.identity,
    required this.sourceType,
    this.localStore = const CalendarCompletionLocalStore(),
    this.loadStatus,
    this.onRecordStatus,
    this.onCreateContinuity,
    this.onReflect,
    this.observedButtonKey,
  });

  final String identity;
  final CompletionSourceType sourceType;
  final CalendarCompletionLocalStore localStore;
  final Future<CompletionStatus> Function()? loadStatus;
  final Future<void> Function(CompletionStatus status)? onRecordStatus;
  final Future<void> Function(CompletionStatus status)? onCreateContinuity;
  final VoidCallback? onReflect;
  final Key? observedButtonKey;

  @override
  State<CalendarEventCompletionPanel> createState() =>
      _CalendarEventCompletionPanelState();
}

class _CalendarEventCompletionPanelState
    extends State<CalendarEventCompletionPanel> {
  CompletionStatus _status = CompletionStatus.none;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CalendarEventCompletionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity != widget.identity) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    CompletionStatus loaded = CompletionStatus.none;
    try {
      final remote = await widget.loadStatus?.call();
      if (remote != null && remote != CompletionStatus.none) {
        loaded = remote;
      } else {
        loaded = (await widget.localStore.load(
          widget.identity,
        )).completionStatus;
      }
    } catch (_) {
      loaded = (await widget.localStore.load(widget.identity)).completionStatus;
    }
    if (!mounted) return;
    setState(() {
      _status = loaded;
      _loading = false;
    });
  }

  Future<void> _record(CompletionStatus status) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.onRecordStatus?.call(status);
      await widget.localStore.save(identity: widget.identity, status: status);
      if (status.createsJournalContinuity) {
        await widget.onCreateContinuity?.call(status);
      }
      if (!mounted) return;
      setState(() {
        _status = status;
        _saving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Could not record completion.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CalendarCompletionPicker(
      current: _status,
      saving: _saving,
      loading: _loading,
      observedButtonKey: widget.observedButtonKey,
      onReflect: widget.onReflect,
      onChanged: (status) => unawaited(_record(status)),
    );
  }
}

class _CompletionStatusButton extends StatelessWidget {
  const _CompletionStatusButton({
    super.key,
    required this.status,
    required this.current,
    required this.saving,
    required this.onChanged,
  });

  final CompletionStatus status;
  final CompletionStatus current;
  final bool saving;
  final ValueChanged<CompletionStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = current == status;
    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: selected ? Colors.black : Colors.white,
          backgroundColor: selected
              ? const Color(0xFFFFD486)
              : Colors.transparent,
          side: BorderSide(
            color: selected ? const Color(0xFFFFD486) : Colors.white24,
            width: 1.1,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: saving ? null : () => onChanged(status),
        child: Text(
          status.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
