import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/core/completion_badge_style.dart';
import 'package:mobile/core/completion_status.dart';
import 'package:mobile/features/journal/journal_event_badge.dart';

const Duration kCalendarCompletionFeedbackDelay = Duration(milliseconds: 500);

const String kCalendarCompletionRecordFailureMessage =
    'Could not record completion.';
const String kCalendarCompletionContinuityFailureMessage =
    'Completion recorded, but journal continuity could not be saved.';
const String kCalendarCompletionPostCommitFailureMessage =
    'Completion and journal continuity were saved, but refresh did not finish.';

class CalendarCompletionPostCommitException implements Exception {
  const CalendarCompletionPostCommitException([this.message]);

  final String? message;

  @override
  String toString() => message ?? kCalendarCompletionPostCommitFailureMessage;
}

bool calendarCompletionStatusTriggersFeedback(CompletionStatus status) {
  return status == CompletionStatus.observed ||
      status == CompletionStatus.partial ||
      status == CompletionStatus.skipped;
}

class CalendarCompletionFeedbackScheduler {
  Timer? _timer;

  void schedule(CompletionStatus status, VoidCallback callback) {
    cancel();
    if (!calendarCompletionStatusTriggersFeedback(status)) return;
    _timer = Timer(kCalendarCompletionFeedbackDelay, () {
      _timer = null;
      callback();
    });
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    cancel();
  }
}

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
  return completionStatusBadgeColor(status, fallback: eventColor);
}

String calendarCompletionBadgeId({
  required String identity,
  required CompletionSourceType sourceType,
}) {
  return 'calendar:${sourceType.wireName}:$identity';
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
    id: calendarCompletionBadgeId(identity: identity, sourceType: sourceType),
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

class CalendarCompletionPickerStyle {
  const CalendarCompletionPickerStyle({
    this.containerPadding = const EdgeInsets.all(12),
    this.containerColor = const Color(0x42000000),
    this.containerBorderColor = const Color(0x4DF5E8CB),
    this.containerBorderWidth = 1.0,
    this.containerRadius = 12,
    this.label = 'Completion',
    this.labelColor = const Color(0xFFFFD486),
    this.labelFontSize = 12,
    this.labelFontWeight = FontWeight.w700,
    this.labelLetterSpacing = 0,
    this.labelGap = 8,
    this.buttonGap = 8,
    this.selectedForegroundColor = Colors.black,
    this.selectedBackgroundColor = const Color(0xFFFFD486),
    this.selectedBorderColor = const Color(0xFFFFD486),
    this.unselectedForegroundColor = Colors.white,
    this.unselectedBackgroundColor = Colors.transparent,
    this.unselectedBorderColor = Colors.white24,
    this.buttonBorderWidth = 1.1,
    this.buttonPadding = const EdgeInsets.symmetric(
      horizontal: 8,
      vertical: 10,
    ),
    this.buttonRadius = 8,
    this.buttonFontSize = 12,
    this.buttonFontWeight = FontWeight.w700,
    this.buttonFontFamily,
    this.buttonFontFamilyFallback,
    this.buttonMinimumSize,
    this.buttonTapTargetSize,
    this.buttonVisualDensity,
  });

  final EdgeInsetsGeometry containerPadding;
  final Color containerColor;
  final Color containerBorderColor;
  final double containerBorderWidth;
  final double containerRadius;
  final String label;
  final Color labelColor;
  final double labelFontSize;
  final FontWeight labelFontWeight;
  final double labelLetterSpacing;
  final double labelGap;
  final double buttonGap;
  final Color selectedForegroundColor;
  final Color selectedBackgroundColor;
  final Color selectedBorderColor;
  final Color unselectedForegroundColor;
  final Color unselectedBackgroundColor;
  final Color unselectedBorderColor;
  final double buttonBorderWidth;
  final EdgeInsetsGeometry buttonPadding;
  final double buttonRadius;
  final double buttonFontSize;
  final FontWeight buttonFontWeight;
  final String? buttonFontFamily;
  final List<String>? buttonFontFamilyFallback;
  final Size? buttonMinimumSize;
  final MaterialTapTargetSize? buttonTapTargetSize;
  final VisualDensity? buttonVisualDensity;
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
    this.leadingContent,
    this.style,
  });

  final CompletionStatus current;
  final ValueChanged<CompletionStatus> onChanged;
  final bool saving;
  final bool loading;
  final bool showPartial;
  final VoidCallback? onReflect;
  final Key? observedButtonKey;
  final Widget? leadingContent;
  final CalendarCompletionPickerStyle? style;

  @override
  Widget build(BuildContext context) {
    final disabled = saving || loading;
    final pickerStyle = style ?? const CalendarCompletionPickerStyle();
    return Container(
      width: double.infinity,
      padding: pickerStyle.containerPadding,
      decoration: BoxDecoration(
        color: pickerStyle.containerColor,
        borderRadius: BorderRadius.circular(pickerStyle.containerRadius),
        border: Border.all(
          color: pickerStyle.containerBorderColor,
          width: pickerStyle.containerBorderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            pickerStyle.label,
            style: TextStyle(
              color: pickerStyle.labelColor,
              fontSize: pickerStyle.labelFontSize,
              fontWeight: pickerStyle.labelFontWeight,
              letterSpacing: pickerStyle.labelLetterSpacing,
            ),
          ),
          SizedBox(height: pickerStyle.labelGap),
          if (leadingContent != null) ...[
            leadingContent!,
            SizedBox(height: pickerStyle.labelGap),
          ],
          Row(
            children: [
              _CompletionStatusButton(
                key: observedButtonKey,
                status: CompletionStatus.observed,
                current: current,
                saving: disabled,
                onChanged: onChanged,
                style: pickerStyle,
              ),
              if (showPartial) ...[
                SizedBox(width: pickerStyle.buttonGap),
                _CompletionStatusButton(
                  status: CompletionStatus.partial,
                  current: current,
                  saving: disabled,
                  onChanged: onChanged,
                  style: pickerStyle,
                ),
              ],
              SizedBox(width: pickerStyle.buttonGap),
              _CompletionStatusButton(
                status: CompletionStatus.skipped,
                current: current,
                saving: disabled,
                onChanged: onChanged,
                style: pickerStyle,
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
    this.onClearStatus,
    this.onCreateContinuity,
    this.onUserCompletionFeedback,
    this.onReflect,
    this.observedButtonKey,
    this.reloadSignal,
    this.pickerStyle,
  });

  final String identity;
  final CompletionSourceType sourceType;
  final CalendarCompletionLocalStore localStore;
  final Future<CompletionStatus> Function()? loadStatus;
  final Future<void> Function(CompletionStatus status)? onRecordStatus;
  final Future<void> Function()? onClearStatus;
  final Future<void> Function(CompletionStatus status)? onCreateContinuity;
  final ValueChanged<CompletionStatus>? onUserCompletionFeedback;
  final VoidCallback? onReflect;
  final Key? observedButtonKey;
  final Object? reloadSignal;
  final CalendarCompletionPickerStyle? pickerStyle;

  @override
  State<CalendarEventCompletionPanel> createState() =>
      _CalendarEventCompletionPanelState();
}

class _CalendarEventCompletionPanelState
    extends State<CalendarEventCompletionPanel> {
  CompletionStatus _status = CompletionStatus.none;
  bool _loading = true;
  bool _saving = false;
  final CalendarCompletionFeedbackScheduler _completionFeedbackScheduler =
      CalendarCompletionFeedbackScheduler();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CalendarEventCompletionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity != widget.identity) {
      _cancelCompletionFeedback();
      _load();
    } else if (oldWidget.reloadSignal != widget.reloadSignal) {
      _load();
    }
  }

  @override
  void dispose() {
    _completionFeedbackScheduler.dispose();
    super.dispose();
  }

  void _cancelCompletionFeedback() {
    _completionFeedbackScheduler.cancel();
  }

  void _scheduleCompletionFeedback(CompletionStatus status) {
    final callback = widget.onUserCompletionFeedback;
    if (callback == null) {
      _cancelCompletionFeedback();
      return;
    }
    _completionFeedbackScheduler.schedule(status, () {
      if (!mounted) return;
      callback(status);
    });
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
    _scheduleCompletionFeedback(status);
    var completionRecorded = false;
    try {
      if (status == CompletionStatus.none) {
        if (widget.onClearStatus != null) {
          await widget.onClearStatus!();
        } else {
          await widget.onRecordStatus?.call(status);
        }
      } else {
        await widget.onRecordStatus?.call(status);
      }
      await widget.localStore.save(identity: widget.identity, status: status);
      completionRecorded = true;
      if (status.createsJournalContinuity) {
        await widget.onCreateContinuity?.call(status);
      }
      if (!mounted) return;
      setState(() {
        _status = status;
        _saving = false;
      });
    } on CalendarCompletionPostCommitException {
      if (!mounted) return;
      if (!completionRecorded) {
        _cancelCompletionFeedback();
        setState(() => _saving = false);
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text(kCalendarCompletionRecordFailureMessage),
          ),
        );
        return;
      }
      setState(() {
        _status = status;
        _saving = false;
      });
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text(kCalendarCompletionPostCommitFailureMessage),
        ),
      );
    } catch (_) {
      _cancelCompletionFeedback();
      if (!mounted) return;
      setState(() {
        if (completionRecorded) {
          _status = status;
        }
        _saving = false;
      });
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            completionRecorded
                ? kCalendarCompletionContinuityFailureMessage
                : kCalendarCompletionRecordFailureMessage,
          ),
        ),
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
      style: widget.pickerStyle,
      onChanged: (status) {
        final next = status == _status && widget.onClearStatus != null
            ? CompletionStatus.none
            : status;
        unawaited(_record(next));
      },
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
    required this.style,
  });

  final CompletionStatus status;
  final CompletionStatus current;
  final bool saving;
  final ValueChanged<CompletionStatus> onChanged;
  final CalendarCompletionPickerStyle style;

  @override
  Widget build(BuildContext context) {
    final selected = current == status;
    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: selected
              ? style.selectedForegroundColor
              : style.unselectedForegroundColor,
          backgroundColor: selected
              ? style.selectedBackgroundColor
              : style.unselectedBackgroundColor,
          side: BorderSide(
            color: selected
                ? style.selectedBorderColor
                : style.unselectedBorderColor,
            width: style.buttonBorderWidth,
          ),
          padding: style.buttonPadding,
          minimumSize: style.buttonMinimumSize,
          tapTargetSize: style.buttonTapTargetSize,
          visualDensity: style.buttonVisualDensity,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(style.buttonRadius),
          ),
        ),
        onPressed: saving ? null : () => onChanged(status),
        child: Text(
          status.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: style.buttonFontSize,
            fontWeight: style.buttonFontWeight,
            fontFamily: style.buttonFontFamily,
            fontFamilyFallback: style.buttonFontFamilyFallback,
          ),
        ),
      ),
    );
  }
}
