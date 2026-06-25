import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/completion_status.dart';
import '../../data/shared_practice_models.dart';
import '../../data/shared_practice_repo.dart';

const Color _gold = Color(0xFFD4AE43);
const Color _panel = Color(0xFF15110B);
const Color _ink = Color(0xFFE7E0D2);
const String _serif = 'CormorantGaramond';

Future<bool> showSharedPracticeCompletionSheet({
  required BuildContext context,
  required String roomId,
  required String calendarName,
  required String clientEventId,
  required int flowId,
  required DateTime completedOn,
  required CompletionStatus initialStatus,
  String? stepTitle,
  Map<String, dynamic>? completionMetadata,
}) async {
  final status = initialStatus == CompletionStatus.none
      ? CompletionStatus.observed
      : initialStatus;
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => SharedPracticeCompletionSheet(
      roomId: roomId,
      calendarName: calendarName,
      clientEventId: clientEventId,
      flowId: flowId,
      completedOn: completedOn,
      initialStatus: status,
      stepTitle: stepTitle,
      completionMetadata: completionMetadata,
    ),
  );
  return result == true;
}

class SharedPracticeCompletionSheet extends StatefulWidget {
  const SharedPracticeCompletionSheet({
    super.key,
    required this.roomId,
    required this.calendarName,
    required this.clientEventId,
    required this.flowId,
    required this.completedOn,
    required this.initialStatus,
    this.stepTitle,
    this.completionMetadata,
  });

  final String roomId;
  final String calendarName;
  final String clientEventId;
  final int flowId;
  final DateTime completedOn;
  final CompletionStatus initialStatus;
  final String? stepTitle;
  final Map<String, dynamic>? completionMetadata;

  @override
  State<SharedPracticeCompletionSheet> createState() =>
      _SharedPracticeCompletionSheetState();
}

class _SharedPracticeCompletionSheetState
    extends State<SharedPracticeCompletionSheet> {
  late CompletionStatus _status = widget.initialStatus;
  SharedPracticeVisibility _visibility = SharedPracticeVisibility.private;
  final TextEditingController _noteController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await SharedPracticeRepo(
        Supabase.instance.client,
      ).upsertSharedPracticeEntry(
        roomId: widget.roomId,
        clientEventId: widget.clientEventId,
        flowId: widget.flowId,
        completedOn: widget.completedOn,
        completionStatus: _status,
        bodyText: _noteController.text,
        visibility: _visibility,
        completionMetadata: _completionMetadataForSelectedStatus(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not record shared practice.')),
      );
    }
  }

  Map<String, dynamic>? _completionMetadataForSelectedStatus() {
    final original = widget.completionMetadata;
    if (original == null || original.isEmpty) return null;
    return <String, dynamic>{
      ...original,
      'completion_status': _status.wireName,
      'status': _status.maatStatusName,
    };
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final title = widget.stepTitle?.trim();
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Color(0x55D4AE43))),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Record completion',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.96),
                          fontFamily: _serif,
                          fontSize: 27,
                          fontWeight: FontWeight.w600,
                          height: 1.05,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close, color: _gold),
                    ),
                  ],
                ),
                if (title != null && title.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontFamily: _serif,
                      fontStyle: FontStyle.italic,
                      fontSize: 17,
                      height: 1.2,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                _SectionLabel('Completion'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _StatusButton(
                      label: 'Observed',
                      status: CompletionStatus.observed,
                      selected: _status,
                      enabled: !_saving,
                      onSelected: (status) => setState(() => _status = status),
                    ),
                    const SizedBox(width: 8),
                    _StatusButton(
                      label: 'Partly',
                      status: CompletionStatus.partial,
                      selected: _status,
                      enabled: !_saving,
                      onSelected: (status) => setState(() => _status = status),
                    ),
                    const SizedBox(width: 8),
                    _StatusButton(
                      label: 'Skipped',
                      status: CompletionStatus.skipped,
                      selected: _status,
                      enabled: !_saving,
                      onSelected: (status) => setState(() => _status = status),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionLabel('Entry'),
                const SizedBox(height: 8),
                TextField(
                  controller: _noteController,
                  enabled: !_saving,
                  minLines: 3,
                  maxLines: 5,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: _serif,
                    fontSize: 18,
                    height: 1.3,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Optional note',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.36),
                      fontFamily: _serif,
                      fontStyle: FontStyle.italic,
                    ),
                    filled: true,
                    fillColor: Colors.black.withValues(alpha: 0.28),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: _gold),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _SectionLabel('Visibility'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _VisibilityButton(
                      visibility: SharedPracticeVisibility.private,
                      selected: _visibility,
                      calendarName: widget.calendarName,
                      enabled: !_saving,
                      onSelected: (visibility) =>
                          setState(() => _visibility = visibility),
                    ),
                    const SizedBox(width: 10),
                    _VisibilityButton(
                      visibility: SharedPracticeVisibility.sharedWithCalendar,
                      selected: _visibility,
                      calendarName: widget.calendarName,
                      enabled: !_saving,
                      onSelected: (visibility) =>
                          setState(() => _visibility = visibility),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : () => unawaited(_save()),
                    style: FilledButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: const Color(0xFF181106),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF181106),
                            ),
                          )
                        : const Text(
                            'Save completion',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: _gold,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.6,
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({
    required this.label,
    required this.status,
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final String label;
  final CompletionStatus status;
  final CompletionStatus selected;
  final bool enabled;
  final ValueChanged<CompletionStatus> onSelected;

  @override
  Widget build(BuildContext context) {
    final isSelected = status == selected;
    return Expanded(
      child: OutlinedButton(
        onPressed: enabled ? () => onSelected(status) : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: isSelected ? const Color(0xFF181106) : _ink,
          backgroundColor: isSelected ? _gold : Colors.transparent,
          side: BorderSide(
            color: isSelected ? _gold : Colors.white.withValues(alpha: 0.18),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 11),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
      ),
    );
  }
}

class _VisibilityButton extends StatelessWidget {
  const _VisibilityButton({
    required this.visibility,
    required this.selected,
    required this.calendarName,
    required this.enabled,
    required this.onSelected,
  });

  final SharedPracticeVisibility visibility;
  final SharedPracticeVisibility selected;
  final String calendarName;
  final bool enabled;
  final ValueChanged<SharedPracticeVisibility> onSelected;

  @override
  Widget build(BuildContext context) {
    final isSelected = visibility == selected;
    final icon = visibility == SharedPracticeVisibility.private
        ? Icons.lock_outline
        : Icons.groups_2_outlined;
    return Expanded(
      child: InkWell(
        onTap: enabled ? () => onSelected(visibility) : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 68),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? _gold.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? _gold : Colors.white.withValues(alpha: 0.14),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: isSelected ? _gold : _ink, size: 19),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  visibility.labelForCalendar(calendarName),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    height: 1.15,
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
