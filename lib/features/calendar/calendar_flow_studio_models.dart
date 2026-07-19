part of 'calendar_page.dart';

// ───────────────────────── Flow Studio (date range → rule chips + per-day note editors) ─────────────────────────

/* ---------- helper types used by Flow Studio (top-level; not nested) ---------- */

/// Range bucket for a specific Kemetic decan inside a Kemetic month.
class _KemeticDecanSpan {
  final String key; // "ky-km-di"
  final int ky; // Kemetic year
  final int km; // 1..12
  final int di; // 0..2  (0=days 1..10, 1=11..20, 2=21..30)
  final String label; // "Month • Decan name"
  int minDay; // 1..10 (trimmed by range)
  int maxDay; // 1..10 (trimmed by range)
  DateTime gStart; // first Gregorian day in span within range
  DateTime gEnd; // last Gregorian day in span within range

  _KemeticDecanSpan({
    required this.key,
    required this.ky,
    required this.km,
    required this.di,
    required this.label,
    required this.minDay,
    required this.maxDay,
    required this.gStart,
    required this.gEnd,
  });
}

/// Range bucket for a Gregorian week (Mon..Sun).
class _WeekSpan {
  final String key; // ISO monday string "yyyy-mm-dd"
  final DateTime monday; // dateOnly, local
  int minWd; // 1..7
  int maxWd; // 1..7
  _WeekSpan({
    required this.key,
    required this.monday,
    required this.minWd,
    required this.maxWd,
  });
}

class _AlertOption {
  final String label;
  final int minutes;
  const _AlertOption(this.label, this.minutes);
}

// Sentinel for "no alert" selection in Flow Studio note drafts.
const int _alertNoneMinutes = -1;
const String _kCalendarOverlayKindSharedCalendars = 'calendar.sharedCalendars';
const String _kCalendarOverlayKindFlowStudio = 'calendar.flowStudio';
const String _kCalendarOverlayKindEventDetail = 'calendar.eventDetail';
const String _kCalendarParentSurfaceRoot = 'calendar.root';
const String _kCalendarParentSurfaceDayView = 'calendar.dayView';
const String _kProfileParentSurface = 'profile.page';
const String _kPlannerTodayParentSurface = 'planner.today';
const String _kPlannerParentSurface = 'planner.page';
const String _kRouteParentSurface = 'route.page';
const String _kFlowStudioDraftEditorKey = 'calendar.flowStudio.draft';
const String _kFlowStudioModeHub = 'hub';
const String _kFlowStudioModeMyFlows = 'myFlows';
const String _kFlowStudioModeMaatFlows = 'maatFlows';
const String _kFlowStudioModeMaatTemplate = 'maatTemplate';
const String _kFlowStudioModeEditor = 'editor';
const String _kMaatFlowsDisplayTitle = "Ma'at Flows";

const List<_AlertOption> _alertOptions = [
  _AlertOption('None', _alertNoneMinutes),
  _AlertOption('At time of event', 0),
  _AlertOption('5 minutes before', 5),
  _AlertOption('10 minutes before', 10),
  _AlertOption('15 minutes before', 15),
  _AlertOption('30 minutes before', 30),
  _AlertOption('1 hour before', 60),
  _AlertOption('2 hours before', 120),
  _AlertOption('1 day before', 60 * 24),
  _AlertOption('2 days before', 60 * 24 * 2),
  _AlertOption('1 week before', 60 * 24 * 7),
];

String _alertLabelFor(int? minutes) {
  final val = minutes ?? 0;
  final match = _alertOptions.firstWhere(
    (o) => o.minutes == val,
    orElse: () => const _AlertOption('At time of event', 0),
  );
  return match.label;
}

Map<String, dynamic>? _flowStudioJsonMap(Object? raw) {
  if (raw is! Map) return null;
  return raw.map<String, dynamic>(
    (dynamic key, dynamic value) => MapEntry(key.toString(), value),
  );
}

List<int> _flowStudioIntList(Object? raw) {
  if (raw is! Iterable) return const <int>[];
  return raw
      .map((value) => (value as num?)?.toInt())
      .whereType<int>()
      .toList(growable: false);
}

Map<String, Set<int>> _flowStudioIntSetMap(Object? raw) {
  final map = _flowStudioJsonMap(raw);
  if (map == null) return const <String, Set<int>>{};
  return map.map(
    (key, value) => MapEntry(key, _flowStudioIntList(value).toSet()),
  );
}

DateTime? _flowStudioDateFromJson(Object? raw) {
  final text = raw as String?;
  if (text == null || text.trim().isEmpty) return null;
  final parsed = DateTime.tryParse(text);
  return parsed == null ? null : DateUtils.dateOnly(parsed.toLocal());
}

String? _flowStudioDateToJson(DateTime? date) =>
    date == null ? null : DateUtils.dateOnly(date).toIso8601String();

Future<int?> _pickAlertMinutes(BuildContext context, int? current) {
  return showCupertinoModalPopup<int>(
    context: context,
    builder: (sheetCtx) {
      return CupertinoActionSheet(
        title: const GlossyText(
          text: 'Alert',
          gradient: silverGloss,
          style: TextStyle(fontSize: 18),
        ),
        actions: [
          for (final opt in _alertOptions)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(sheetCtx, opt.minutes),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GlossyText(
                    text: opt.label,
                    gradient: goldGloss,
                    style: const TextStyle(fontSize: 17),
                  ),
                  if (current == opt.minutes)
                    const Icon(Icons.check, color: _silver),
                ],
              ),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(sheetCtx),
          child: const Text('Cancel'),
        ),
      );
    },
  );
}

Future<String?> _showCalendarChoiceSheet({
  required BuildContext context,
  required List<SharedCalendarSummary> calendars,
  required String? selectedCalendarId,
  String title = 'Calendar',
}) {
  final selectedId = selectedCalendarId?.trim();
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: const Color(0xFF050403),
    barrierColor: Colors.black.withValues(alpha: 0.72),
    isScrollControlled: true,
    builder: (sheetContext) {
      final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.72;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6F604A),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 18),
                GlossyText(
                  text: title,
                  gradient: goldGloss,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Cinzel',
                  ),
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: calendars.length,
                    separatorBuilder: (_, _) =>
                        const Divider(color: Color(0x1FFFFFFF), height: 1),
                    itemBuilder: (context, index) {
                      final calendar = calendars[index];
                      final name = calendar.isPersonal
                          ? 'My Calendar'
                          : calendar.name.trim().isEmpty
                          ? 'Calendar'
                          : calendar.name.trim();
                      final selected = calendar.id.trim() == selectedId;
                      final labelColor = _calendarChoiceLabelColor(
                        calendar.color,
                      );
                      return ListTile(
                        key: ValueKey<String>('calendar-choice-${calendar.id}'),
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: calendar.color,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: calendar.color.withValues(alpha: 0.34),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        title: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: labelColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'GentiumPlus',
                          ),
                        ),
                        subtitle: calendar.isPersonal
                            ? null
                            : Text(
                                calendar.roleLabel,
                                style: const TextStyle(
                                  color: Color(0xFFB7AAA0),
                                  fontSize: 13,
                                ),
                              ),
                        trailing: selected
                            ? const Icon(Icons.check, color: _gold)
                            : null,
                        onTap: () =>
                            Navigator.of(sheetContext).pop(calendar.id),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Color _calendarChoiceLabelColor(Color color) {
  if (color.computeLuminance() >= 0.22) return color;
  return Color.lerp(color, Colors.white, 0.62) ?? Colors.white;
}

/// Lightweight inputs holder for one planned note.
class _NoteDraft {
  _NoteDraft({VoidCallback? onChanged}) {
    if (onChanged != null) {
      attachChangeListener(onChanged);
    }
  }

  final titleCtrl = TextEditingController();
  final locationCtrl = TextEditingController();
  final detailCtrl = TextEditingController();
  bool allDay = false;
  TimeOfDay? start = const TimeOfDay(hour: 12, minute: 0);
  TimeOfDay? end = const TimeOfDay(hour: 13, minute: 0);
  String? category;
  int alertMinutesBefore =
      _alertNoneMinutes; // -1 = none, null = legacy default
  bool usesFlowAlertDefault = true;
  String? actionId;
  Map<String, dynamic>? behaviorPayload;
  VoidCallback? _changeListener;

  void attachChangeListener(VoidCallback listener) {
    if (_changeListener == listener) return;
    final previous = _changeListener;
    if (previous != null) {
      titleCtrl.removeListener(previous);
      locationCtrl.removeListener(previous);
      detailCtrl.removeListener(previous);
    }
    _changeListener = listener;
    titleCtrl.addListener(listener);
    locationCtrl.addListener(listener);
    detailCtrl.addListener(listener);
  }

  _Note toNote({required int flowAlertMinutesBefore}) {
    final t = titleCtrl.text.trim();
    final loc = locationCtrl.text.trim();
    final det = detailCtrl.text.trim();
    final effectiveAlert = usesFlowAlertDefault
        ? flowAlertMinutesBefore
        : alertMinutesBefore;
    return _Note(
      title: t,
      location: loc.isEmpty ? null : loc,
      detail: det.isEmpty ? null : det,
      allDay: allDay,
      start: allDay ? null : start,
      end: allDay ? null : end,
      category: category,
      alertOffsetMinutes: effectiveAlert,
      actionId: actionId,
      behaviorPayload: behaviorPayload == null
          ? null
          : Map<String, dynamic>.from(behaviorPayload!),
    );
  }

  void dispose() {
    final listener = _changeListener;
    if (listener != null) {
      titleCtrl.removeListener(listener);
      locationCtrl.removeListener(listener);
      detailCtrl.removeListener(listener);
    }
    titleCtrl.dispose();
    locationCtrl.dispose();
    detailCtrl.dispose();
  }
}

class _DraftNoteData {
  final String title;
  final String location;
  final String detail;
  final bool allDay;
  final int? startMinutes; // null when all-day
  final int? endMinutes; // null when all-day
  final String? category;
  final int alertMinutesBefore;
  final bool usesFlowAlertDefault;
  final String? actionId;
  final Map<String, dynamic>? behaviorPayload;

  const _DraftNoteData({
    required this.title,
    required this.location,
    required this.detail,
    required this.allDay,
    required this.startMinutes,
    required this.endMinutes,
    required this.category,
    required this.alertMinutesBefore,
    required this.usesFlowAlertDefault,
    this.actionId,
    this.behaviorPayload,
  });

  factory _DraftNoteData.fromDraft(_NoteDraft draft) {
    return _DraftNoteData(
      title: draft.titleCtrl.text,
      location: draft.locationCtrl.text,
      detail: draft.detailCtrl.text,
      allDay: draft.allDay,
      startMinutes: draft.allDay || draft.start == null
          ? null
          : draft.start!.hour * 60 + draft.start!.minute,
      endMinutes: draft.allDay || draft.end == null
          ? null
          : draft.end!.hour * 60 + draft.end!.minute,
      category: draft.category,
      alertMinutesBefore: draft.alertMinutesBefore,
      usesFlowAlertDefault: draft.usesFlowAlertDefault,
      actionId: draft.actionId,
      behaviorPayload: draft.behaviorPayload == null
          ? null
          : Map<String, dynamic>.from(draft.behaviorPayload!),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'title': title,
      'location': location,
      'detail': detail,
      'allDay': allDay,
      if (startMinutes != null) 'startMinutes': startMinutes,
      if (endMinutes != null) 'endMinutes': endMinutes,
      if (category != null) 'category': category,
      'alertMinutesBefore': alertMinutesBefore,
      'usesFlowAlertDefault': usesFlowAlertDefault,
      if (actionId != null) 'actionId': actionId,
      if (behaviorPayload != null) 'behaviorPayload': behaviorPayload,
    };
  }

  static _DraftNoteData? fromJson(Object? raw) {
    final json = _flowStudioJsonMap(raw);
    if (json == null) return null;
    final startMinutes = (json['startMinutes'] as num?)?.toInt();
    final endMinutes = (json['endMinutes'] as num?)?.toInt();
    return _DraftNoteData(
      title: json['title'] as String? ?? '',
      location: json['location'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
      allDay: json['allDay'] == true,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      category: json['category'] as String?,
      alertMinutesBefore:
          (json['alertMinutesBefore'] as num?)?.toInt() ?? _alertNoneMinutes,
      usesFlowAlertDefault: json['usesFlowAlertDefault'] != false,
      actionId: json['actionId'] as String?,
      behaviorPayload: _flowStudioJsonMap(json['behaviorPayload']),
    );
  }

  _NoteDraft toDraft({VoidCallback? onChanged}) {
    final d = _NoteDraft(onChanged: onChanged);
    d.titleCtrl.text = title;
    d.locationCtrl.text = location;
    d.detailCtrl.text = detail;
    d.allDay = allDay;
    if (!allDay && startMinutes != null && endMinutes != null) {
      d.start = TimeOfDay(
        hour: (startMinutes! ~/ 60) % 24,
        minute: startMinutes! % 60,
      );
      d.end = TimeOfDay(
        hour: (endMinutes! ~/ 60) % 24,
        minute: endMinutes! % 60,
      );
    } else {
      d.start = null;
      d.end = null;
    }
    d.category = category;
    d.alertMinutesBefore = alertMinutesBefore;
    d.usesFlowAlertDefault = usesFlowAlertDefault;
    d.actionId = actionId;
    d.behaviorPayload = behaviorPayload == null
        ? null
        : Map<String, dynamic>.from(behaviorPayload!);
    return d;
  }
}

class _FlowStudioDraft {
  final int? editingFlowId;
  final bool editingIsHidden;
  final String? calendarId;
  final String name;
  final bool active;
  final int selectedColorIndex;
  final String studioMode;
  final double? buildHue;
  final int? buildColorArgb;
  final bool buildColorWasDragged;
  final double? composeHue;
  final int? composeColorArgb;
  final bool composeColorWasDragged;
  final String composePrompt;
  final bool composeUseKemetic;
  final DateTime? composeStartDate;
  final DateTime? composeEndDate;
  final bool composeManualDateRangeEdited;
  final bool useKemetic;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool splitByPeriod;
  final Set<int> selectedDecanDays;
  final Set<int> selectedWeekdays;
  final Map<String, Set<int>> perDecanSel;
  final Map<String, Set<int>> perWeekSel;
  final Map<String, List<_DraftNoteData>> draftsByDay;
  final Map<String, _DraftNoteData> draftsByPattern;
  final String overview;
  final bool isAIGeneratedFlow;
  final int flowAlertMinutesBefore;
  final bool flowAlertMixed;

  const _FlowStudioDraft({
    required this.editingFlowId,
    required this.editingIsHidden,
    required this.calendarId,
    required this.name,
    required this.active,
    required this.selectedColorIndex,
    required this.studioMode,
    required this.buildHue,
    required this.buildColorArgb,
    required this.buildColorWasDragged,
    required this.composeHue,
    required this.composeColorArgb,
    required this.composeColorWasDragged,
    required this.composePrompt,
    required this.composeUseKemetic,
    required this.composeStartDate,
    required this.composeEndDate,
    required this.composeManualDateRangeEdited,
    required this.useKemetic,
    required this.startDate,
    required this.endDate,
    required this.splitByPeriod,
    required this.selectedDecanDays,
    required this.selectedWeekdays,
    required this.perDecanSel,
    required this.perWeekSel,
    required this.draftsByDay,
    required this.draftsByPattern,
    required this.overview,
    required this.isAIGeneratedFlow,
    required this.flowAlertMinutesBefore,
    required this.flowAlertMixed,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (editingFlowId != null) 'editingFlowId': editingFlowId,
      'editingIsHidden': editingIsHidden,
      if (calendarId != null) 'calendarId': calendarId,
      'name': name,
      'active': active,
      'selectedColorIndex': selectedColorIndex,
      'studioMode': studioMode,
      if (buildHue != null) 'buildHue': buildHue,
      if (buildColorArgb != null) 'buildColorArgb': buildColorArgb,
      'buildColorWasDragged': buildColorWasDragged,
      if (composeHue != null) 'composeHue': composeHue,
      if (composeColorArgb != null) 'composeColorArgb': composeColorArgb,
      'composeColorWasDragged': composeColorWasDragged,
      'composePrompt': composePrompt,
      'composeUseKemetic': composeUseKemetic,
      if (_flowStudioDateToJson(composeStartDate) != null)
        'composeStartDate': _flowStudioDateToJson(composeStartDate),
      if (_flowStudioDateToJson(composeEndDate) != null)
        'composeEndDate': _flowStudioDateToJson(composeEndDate),
      'composeManualDateRangeEdited': composeManualDateRangeEdited,
      'useKemetic': useKemetic,
      if (_flowStudioDateToJson(startDate) != null)
        'startDate': _flowStudioDateToJson(startDate),
      if (_flowStudioDateToJson(endDate) != null)
        'endDate': _flowStudioDateToJson(endDate),
      'splitByPeriod': splitByPeriod,
      'selectedDecanDays': selectedDecanDays.toList(growable: false),
      'selectedWeekdays': selectedWeekdays.toList(growable: false),
      'perDecanSel': perDecanSel.map(
        (key, value) => MapEntry(key, value.toList(growable: false)),
      ),
      'perWeekSel': perWeekSel.map(
        (key, value) => MapEntry(key, value.toList(growable: false)),
      ),
      'draftsByDay': draftsByDay.map(
        (key, value) =>
            MapEntry(key, value.map((note) => note.toJson()).toList()),
      ),
      'draftsByPattern': draftsByPattern.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
      'overview': overview,
      'isAIGeneratedFlow': isAIGeneratedFlow,
      'flowAlertMinutesBefore': flowAlertMinutesBefore,
      'flowAlertMixed': flowAlertMixed,
    };
  }

  static _FlowStudioDraft? fromJson(Object? raw) {
    final json = _flowStudioJsonMap(raw);
    if (json == null) return null;

    final draftsByDay = <String, List<_DraftNoteData>>{};
    final rawDraftsByDay = _flowStudioJsonMap(json['draftsByDay']);
    if (rawDraftsByDay != null) {
      for (final entry in rawDraftsByDay.entries) {
        final notes = entry.value is Iterable
            ? (entry.value as Iterable)
                  .map(_DraftNoteData.fromJson)
                  .whereType<_DraftNoteData>()
                  .toList(growable: false)
            : const <_DraftNoteData>[];
        if (notes.isNotEmpty) {
          draftsByDay[entry.key] = notes;
        }
      }
    }

    final draftsByPattern = <String, _DraftNoteData>{};
    final rawDraftsByPattern = _flowStudioJsonMap(json['draftsByPattern']);
    if (rawDraftsByPattern != null) {
      for (final entry in rawDraftsByPattern.entries) {
        final note = _DraftNoteData.fromJson(entry.value);
        if (note != null) {
          draftsByPattern[entry.key] = note;
        }
      }
    }

    return _FlowStudioDraft(
      editingFlowId: (json['editingFlowId'] as num?)?.toInt(),
      editingIsHidden: json['editingIsHidden'] == true,
      calendarId: (json['calendarId'] as String?)?.trim(),
      name: json['name'] as String? ?? '',
      active: json['active'] != false,
      selectedColorIndex: (json['selectedColorIndex'] as num?)?.toInt() ?? 0,
      studioMode: json['studioMode'] as String? ?? 'build',
      buildHue: (json['buildHue'] as num?)?.toDouble(),
      buildColorArgb: (json['buildColorArgb'] as num?)?.toInt(),
      buildColorWasDragged: json['buildColorWasDragged'] == true,
      composeHue: (json['composeHue'] as num?)?.toDouble(),
      composeColorArgb: (json['composeColorArgb'] as num?)?.toInt(),
      composeColorWasDragged: json['composeColorWasDragged'] == true,
      composePrompt: json['composePrompt'] as String? ?? '',
      composeUseKemetic: json['composeUseKemetic'] == true,
      composeStartDate: _flowStudioDateFromJson(json['composeStartDate']),
      composeEndDate: _flowStudioDateFromJson(json['composeEndDate']),
      composeManualDateRangeEdited:
          json['composeManualDateRangeEdited'] == true,
      useKemetic: json['useKemetic'] == true,
      startDate: _flowStudioDateFromJson(json['startDate']),
      endDate: _flowStudioDateFromJson(json['endDate']),
      splitByPeriod: json['splitByPeriod'] == true,
      selectedDecanDays: _flowStudioIntList(json['selectedDecanDays']).toSet(),
      selectedWeekdays: _flowStudioIntList(json['selectedWeekdays']).toSet(),
      perDecanSel: _flowStudioIntSetMap(json['perDecanSel']),
      perWeekSel: _flowStudioIntSetMap(json['perWeekSel']),
      draftsByDay: draftsByDay,
      draftsByPattern: draftsByPattern,
      overview: json['overview'] as String? ?? '',
      isAIGeneratedFlow: json['isAIGeneratedFlow'] == true,
      flowAlertMinutesBefore:
          (json['flowAlertMinutesBefore'] as num?)?.toInt() ??
          _alertNoneMinutes,
      flowAlertMixed: json['flowAlertMixed'] == true,
    );
  }
}

/// One concrete selected day derived from the chips.
class _SelectedDay {
  final String key; // "ky-km-kd"
  final int ky, km, kd;
  final DateTime g; // Gregorian
  _SelectedDay(this.key, this.ky, this.km, this.kd, this.g);
}

/// One editor group: either a concrete day or a pattern (weekday / decan day).
class _EditorGroup {
  final String key; // day key: "ky-km-kd"; pattern key: "WD-2" / "DD-3"
  final bool isPattern; // true for pattern (repeat), false for per-day
  final String header; // display header
  final List<_SelectedDay> days; // all concrete days this editor applies to
  const _EditorGroup({
    required this.key,
    required this.isPattern,
    required this.header,
    required this.days,
  });
}

/// A note to add on a specific Kemetic day (result payload).
class ImportFlowData {
  final InboxShareItem share;
  final String name;
  final int color;
  final String? calendarId;
  final String? calendarName;
  final String? notes;
  final List<dynamic> rules;
  final DateTime? suggestedStartDate;
  final DateTime? suggestedEndDate;
  final String? overview;
  final String? generationId;
  final int? originFlowId;
  final int? rootFlowId;
  final String? originType;
  final Map<String, dynamic>? aiMetadata;
  const ImportFlowData({
    required this.share,
    required this.name,
    required this.color,
    this.calendarId,
    this.calendarName,
    this.notes,
    required this.rules,
    this.suggestedStartDate,
    this.suggestedEndDate,
    this.overview,
    this.generationId,
    this.originFlowId,
    this.rootFlowId,
    this.originType,
    this.aiMetadata,
  });
}

class _PlannedNote {
  final int ky, km, kd; // Kemetic Y/M/D
  final _Note note;
  const _PlannedNote({
    required this.ky,
    required this.km,
    required this.kd,
    required this.note,
  });
}

class _FlowStudioResult {
  final _Flow? savedFlow;
  final int? deleteFlowId;
  final List<_PlannedNote> plannedNotes;
  final String? originType;
  final int? originFlowId;
  final String? originShareId;
  final String? originGenerationId;
  final int? rootFlowId;
  final Map<String, dynamic>? aiMetadata;
  const _FlowStudioResult({
    this.savedFlow,
    this.deleteFlowId,
    this.plannedNotes = const [],
    this.originType,
    this.originFlowId,
    this.originShareId,
    this.originGenerationId,
    this.rootFlowId,
    this.aiMetadata,
  });
}

/* ---------------------------------- page ---------------------------------- */
