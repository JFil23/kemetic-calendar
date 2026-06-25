import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/shared_calendar_models.dart';
import '../../data/shared_practice_models.dart';
import '../../data/shared_practice_repo.dart';

const Color _gold = Color(0xFFD4AE43);
const Color _panel = Color(0xFF15110B);
const Color _ink = Color(0xFFE7E0D2);
const String _serif = 'CormorantGaramond';

Future<String?> showSharedPracticeCalendarChooser({
  required BuildContext context,
  required int sourceFlowId,
  required String flowTitle,
  int? stepCount,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => SharedPracticeCalendarChooserSheet(
      sourceFlowId: sourceFlowId,
      flowTitle: flowTitle,
      stepCount: stepCount,
    ),
  );
}

class SharedPracticeCalendarChooserSheet extends StatefulWidget {
  const SharedPracticeCalendarChooserSheet({
    super.key,
    required this.sourceFlowId,
    required this.flowTitle,
    this.stepCount,
  });

  final int sourceFlowId;
  final String flowTitle;
  final int? stepCount;

  @override
  State<SharedPracticeCalendarChooserSheet> createState() =>
      _SharedPracticeCalendarChooserSheetState();
}

class _SharedPracticeCalendarChooserSheetState
    extends State<SharedPracticeCalendarChooserSheet> {
  late Future<List<SharedCalendarOption>> _future;
  SharedCalendarOption? _selected;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _future = SharedPracticeRepo(
      Supabase.instance.client,
    ).getEligibleSharedCalendarsForPractice();
  }

  Future<void> _submit() async {
    final selected = _selected;
    if (selected == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      final room = await SharedPracticeRepo(Supabase.instance.client)
          .createSharedPracticeFromFlow(
            calendarId: selected.calendar.id,
            sourceFlowId: widget.sourceFlowId,
          );
      if (!mounted) return;
      Navigator.of(context).pop(room.id);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not start shared practice.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        border: Border(top: BorderSide(color: Color(0x55D4AE43))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: FutureBuilder<List<SharedCalendarOption>>(
            future: _future,
            builder: (context, snapshot) {
              final options = snapshot.data ?? const <SharedCalendarOption>[];
              if (_selected == null && options.isNotEmpty) {
                _selected = options.first;
              }
              return Column(
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Practice together',
                              style: TextStyle(
                                color: Colors.white,
                                fontFamily: _serif,
                                fontSize: 30,
                                fontWeight: FontWeight.w600,
                                height: 1.02,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Keep this with people you trust',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.58),
                                fontFamily: _serif,
                                fontStyle: FontStyle.italic,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _submitting
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: _gold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _FlowSummary(
                    title: widget.flowTitle,
                    stepCount: widget.stepCount,
                  ),
                  const SizedBox(height: 12),
                  if (snapshot.connectionState != ConnectionState.done &&
                      options.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: CircularProgressIndicator(color: _gold),
                      ),
                    )
                  else if (options.isEmpty)
                    const _NoCalendars()
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: options.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final option = options[index];
                          return _CalendarCard(
                            option: option,
                            selected:
                                _selected?.calendar.id == option.calendar.id,
                            onTap: _submitting
                                ? null
                                : () => setState(() => _selected = option),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed:
                          _selected == null || _submitting || options.isEmpty
                          ? null
                          : () => unawaited(_submit()),
                      style: FilledButton.styleFrom(
                        backgroundColor: _gold,
                        foregroundColor: const Color(0xFF181106),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF181106),
                              ),
                            )
                          : Text(
                              _selected == null
                                  ? 'Add flow'
                                  : 'Add flow to ${_selected!.calendar.name}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FlowSummary extends StatelessWidget {
  const _FlowSummary({required this.title, this.stepCount});

  final String title;
  final int? stepCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: _gold, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title.trim().isEmpty ? 'Ma\'at Flow' : title.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: _serif,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                height: 1.08,
              ),
            ),
          ),
          if (stepCount != null && stepCount! > 0) ...[
            const SizedBox(width: 10),
            Text(
              '$stepCount steps',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final SharedCalendarOption option;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final calendar = option.calendar;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: selected
              ? _gold.withValues(alpha: 0.07)
              : Colors.black.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? _gold : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          children: [
            _CalendarGlyph(calendar: calendar),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    calendar.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: _serif,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    calendar.memberCount == 1
                        ? '1 member'
                        : '${calendar.memberCount} members',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.58),
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _MemberPreview(members: option.members),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? _gold : Colors.white.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarGlyph extends StatelessWidget {
  const _CalendarGlyph({required this.calendar});

  final SharedCalendarSummary calendar;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: calendar.color.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(color: calendar.color.withValues(alpha: 0.62)),
      ),
      child: const Icon(Icons.groups_2_outlined, color: _gold, size: 22),
    );
  }
}

class _MemberPreview extends StatelessWidget {
  const _MemberPreview({required this.members});

  final List<SharedCalendarMember> members;

  @override
  Widget build(BuildContext context) {
    final shown = members.take(4).toList(growable: false);
    if (shown.isEmpty) {
      return Text(
        'Private by default',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.42),
          fontSize: 11.5,
        ),
      );
    }
    return Row(
      children: [
        for (var i = 0; i < shown.length; i++)
          Transform.translate(
            offset: Offset(i == 0 ? 0 : -7.0 * i, 0),
            child: _Avatar(member: shown[i]),
          ),
        if (members.length > shown.length)
          Transform.translate(
            offset: Offset(-7.0 * shown.length, 0),
            child: Text(
              '+${members.length - shown.length}',
              style: const TextStyle(
                color: _ink,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.member});

  final SharedCalendarMember member;

  @override
  Widget build(BuildContext context) {
    final label = member.displayLabel;
    final initial = label.replaceFirst('@', '').trim();
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _gold,
        shape: BoxShape.circle,
        border: Border.all(color: _panel, width: 2),
      ),
      child: Text(
        initial.isEmpty ? 'M' : initial.substring(0, 1).toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF181106),
          fontFamily: _serif,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _NoCalendars extends StatelessWidget {
  const _NoCalendars();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'No eligible shared calendars',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Create or join a shared calendar with edit permission first.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              context.push('/calendars');
            },
            icon: const Icon(Icons.calendar_month_outlined, size: 18),
            label: const Text('Open calendars'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _gold,
              side: const BorderSide(color: _gold),
            ),
          ),
        ],
      ),
    );
  }
}
