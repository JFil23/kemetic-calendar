// lib/features/inbox/shared_flow_details_page.dart
// Dual-mode details page: supports both imported flows (flowId) and non-imported shares (share)

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/material.dart' show DateUtils;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/share_models.dart';
import '../../data/share_repo.dart';
import '../../data/flows_repo.dart';
import '../../data/user_events_repo.dart';
import '../../repositories/inbox_repo.dart';
import '../../shared/glossy_text.dart';
import '../../features/calendar/calendar_page.dart' show CalendarPage, notesDecode, ImportFlowData;
import '../../features/calendar/kemetic_month_metadata.dart' show getMonthById;
import '../../widgets/flow_start_date_picker.dart';

const Color _bg = Color(0xFF000000);

/// Simple container for flow span summary (day count + date range)
class _FlowSpanSummary {
  final int dayCount;
  final DateTime start;
  final DateTime end;

  const _FlowSpanSummary({
    required this.dayCount,
    required this.start,
    required this.end,
  });
}

class SharedFlowDetailsPage extends StatefulWidget {
  final InboxShareItem? share; // non-imported
  final int? flowId;           // imported
  final Map<String, dynamic>? payloadJson; // direct payload (e.g., flow post)
  final bool showImportFooter;
  final bool showRemoveButton;
  final Future<void> Function()? onRemove;

  const SharedFlowDetailsPage({
    Key? key,
    this.share,
    this.flowId,
    this.payloadJson,
    this.showImportFooter = true,
    this.showRemoveButton = false,
    this.onRemove,
  })  : assert(share != null || flowId != null || payloadJson != null,
            'Either share, flowId, or payloadJson must be provided'),
        super(key: key);

  @override
  State<SharedFlowDetailsPage> createState() => _SharedFlowDetailsPageState();
}

class _SharedFlowDetailsPageState extends State<SharedFlowDetailsPage> {
  late final Future<_SharedFlowData> _flowFuture;
  Future<_FlowSpanSummary?>? _spanFuture;

  /// Merge duplicate events (same day/title/time/detail/location) to avoid double rendering
  List<Map<String, dynamic>> _dedupeEvents(List<Map<String, dynamic>> events) {
    final seen = <String, Map<String, dynamic>>{};

    String keyFor(Map<String, dynamic> e) {
      final title = (e['title'] as String? ?? '').trim().toLowerCase();
      final offset = (e['offset_days'] as num?)?.toInt() ?? 0;
      final allDay = (e['all_day'] as bool?) ?? false;
      final start = (e['start_time'] as String? ?? '').trim().toLowerCase();
      final end = (e['end_time'] as String? ?? '').trim().toLowerCase();
      final detail = (e['detail'] as String? ?? '').trim().toLowerCase();
      final location = (e['location'] as String? ?? '').trim().toLowerCase();
      return [
        title,
        'off:$offset',
        allDay ? 'allDay' : 'timed',
        's:$start',
        'e:$end',
        'd:$detail',
        'l:$location',
      ].join('|');
    }

    for (final e in events) {
      final k = keyFor(e);
      seen[k] = e; // keep latest; they are equivalent for display
    }
    return seen.values.toList();
  }

  @override
  void initState() {
    super.initState();
    
    // Mark as viewed if current user is the recipient (only for non-imported shares)
    if (widget.share != null) {
      _markAsViewedIfRecipient();
    }
    
    if (widget.flowId != null) {
      _flowFuture = _loadFromDb(widget.flowId!);
      _spanFuture = _loadSpanSummary(); // ✅ Only for imported flows
    } else if (widget.payloadJson != null) {
      _flowFuture = Future.value(_fromPayload(widget.payloadJson!));
      _spanFuture = Future.value(null);
    } else {
      _flowFuture = Future.value(_fromShare(widget.share!));
      _spanFuture = Future.value(null); // ✅ Not imported yet - no events
    }
  }

  /// Mark the share as viewed if the current user is the recipient
  /// Only works for non-imported shares (when share is provided)
  Future<void> _markAsViewedIfRecipient() async {
    // Only works for non-imported shares (when share is provided)
    if (widget.share == null) return;

    final share = widget.share!;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    if (currentUserId == null) return;

    if (share.recipientId == currentUserId && share.viewedAt == null) {
      final repo = ShareRepo(Supabase.instance.client);
      try {
        await repo.markViewed(share.shareId, isFlow: share.isFlow);

        if (kDebugMode) {
          debugPrint(
            '[SharedFlowDetailsPage] Marked share ${share.shareId} as viewed',
          );
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            '[SharedFlowDetailsPage] Failed to mark viewed: $e',
          );
        }
      }
    }
  }

  Future<_FlowSpanSummary?> _loadSpanSummary() async {
    // ✅ Only works for imported flows (widget.flowId != null)
    if (widget.flowId == null) return null;

    try {
      final repo = UserEventsRepo(Supabase.instance.client);
      final records = await repo.getEventsForFlow(widget.flowId!);

      if (records.isEmpty) return null;

      DateTime minDate = DateUtils.dateOnly(records.first.startsAtUtc.toLocal());
      DateTime maxDate = minDate;
      final dayKeys = <String>{};

      for (final r in records) {
        final local = r.startsAtUtc.toLocal();
        final only = DateUtils.dateOnly(local);

        if (only.isBefore(minDate)) minDate = only;
        if (only.isAfter(maxDate)) maxDate = only;

        // simple key to count distinct days
        dayKeys.add('${only.year}-${only.month}-${only.day}');
      }

      return _FlowSpanSummary(
        dayCount: dayKeys.length,
        start: minDate,
        end: maxDate,
      );
    } catch (e) {
      // If RLS or anything else blocks this, just don't show the label
      if (kDebugMode) {
        print('[SharedFlowDetailsPage] span summary error: $e');
      }
      return null;
    }
  }

  Future<_SharedFlowData> _loadFromDb(int flowId) async {
    final repo = FlowsRepo(Supabase.instance.client);
    final row = await repo.getFlowById(flowId);
    if (row == null) {
      throw Exception('Flow not found');
    }

    return _SharedFlowData(
      name: row.name,
      color: row.color,
      notes: row.notes ?? '',
      rulesJson: (row.rules as List<dynamic>? ?? const []),
      eventsJson: const [], // ✅ Imported flows don't have events[] in payload
      suggestedScheduleJson: null,
      isImported: true,
      flowId: flowId,
      share: null,
    );
  }

  _SharedFlowData _fromShare(InboxShareItem share) {
    // ✅ 1) Try typed model first
    final payload = share.flowPayload;

    if (payload != null) {
      // Convert typed events to JSON format for _SharedFlowData
      final eventsJson = payload.events.map((e) => <String, dynamic>{
        'offset_days': e.offsetDays,
        'title': e.title,
        'detail': e.detail,
        'location': e.location,
        'all_day': e.allDay,
        'start_time': e.startTime,
        'end_time': e.endTime,
      }).toList();

      if (kDebugMode) {
        debugPrint('[SharedFlowDetailsPage._fromShare] Using typed payload model');
        debugPrint('  shareId=${share.shareId}');
        debugPrint('  name=${payload.name}, events=${payload.events.length}');
        debugPrint('  rules count=${payload.rules.length}');
    }

    return _SharedFlowData(
        name: payload.name,
        color: payload.color ?? 0xFF4DD0E1,
        notes: payload.notes ?? '',
        rulesJson: payload.rules,
        eventsJson: eventsJson, // ✅ List<dynamic> format
        suggestedScheduleJson: share.suggestedSchedule?.toJson(),
        isImported: false,
        flowId: null,
        share: share,
      );
    }

    // ✅ 2) Fallback to existing manual parsing
    final payloadMap = share.payloadJson ?? const <String, dynamic>{};

    if (kDebugMode) {
      debugPrint('[SharedFlowDetailsPage._fromShare] Using manual parsing fallback');
      debugPrint('  shareId=${share.shareId}');
      debugPrint('  payload keys=${payloadMap.keys.toList()}');
      debugPrint('  events count=${(payloadMap['events'] as List<dynamic>?)?.length ?? 0}');
      debugPrint('  rules count=${(payloadMap['rules'] as List<dynamic>?)?.length ?? 0}');
    }

    // ✅ Use share.title as fallback if payload['name'] is missing
    final nameFromPayload = payloadMap['name'] as String?;
    final safeName = (nameFromPayload != null && nameFromPayload.trim().isNotEmpty)
        ? nameFromPayload.trim()
        : (share.title.trim().isNotEmpty ? share.title.trim() : 'Untitled Flow');

    return _SharedFlowData(
      name: safeName,
      color: (payloadMap['color'] as int?) ?? 0xFF4DD0E1,
      notes: payloadMap['notes'] as String? ?? '',
      rulesJson: (payloadMap['rules'] as List<dynamic>? ?? const []),
      eventsJson: (payloadMap['events'] as List<dynamic>? ?? const []),
      suggestedScheduleJson: share.suggestedSchedule?.toJson(),
      isImported: false,
      flowId: null,
      share: share,
    );
  }

  _SharedFlowData _fromPayload(Map<String, dynamic> payload) {
    final eventsJson = (payload['events'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();

    return _SharedFlowData(
      name: payload['name'] as String? ?? 'Flow',
      color: (payload['color'] as num?)?.toInt() ?? 0xFFD4AF37,
      notes: payload['notes'] as String? ?? '',
      rulesJson: (payload['rules'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>(),
      eventsJson: _dedupeEvents(eventsJson),
      suggestedScheduleJson: payload['suggested_schedule'] as Map<String, dynamic>?,
      isImported: false,
      flowId: null,
      share: null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_SharedFlowData>(
      future: _flowFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(backgroundColor: Colors.black),
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: _bg,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data!;
        final meta = notesDecode(data.notes);
        // ✅ Show overview from notesDecode, or fallback to raw notes if overview is empty
        final overview = meta.overview?.trim().isNotEmpty == true 
            ? meta.overview!.trim() 
            : (data.notes.trim().isNotEmpty ? data.notes.trim() : '');
        final kemetic = meta.kemetic;
        final split = meta.split;

        final rulesJson = data.rulesJson
            .whereType<Map<String, dynamic>>()
            .toList();
        final eventsJson = _dedupeEvents(
          data.eventsJson.whereType<Map<String, dynamic>>().toList(),
        );

        return Scaffold(
          backgroundColor: _bg,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0.5,
            title: const Text(
              'Flow',
              style: TextStyle(color: Colors.white),
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding:
                      const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 24.0),
                  children: [
                    // Name
                    GlossyText(
                      text: data.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                      gradient: goldGloss,
                    ),
                    const SizedBox(height: 10),

                    // Overview
                    const GlossyText(
                      text: 'Overview',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      gradient: goldGloss,
                    ),
                    const SizedBox(height: 4),
                    // ✅ Show overview if available, otherwise show raw notes, otherwise show dash
                    Text(
                      overview.isNotEmpty 
                          ? overview 
                          : (data.notes.trim().isNotEmpty ? data.notes.trim() : '—'),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Mode
                    Row(
                      children: [
                        Text(
                          kemetic ? 'Kemetic' : 'Gregorian',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                        if (split)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Text(
                              'Custom dates',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Schedule
                    const GlossyText(
                      text: 'Schedule',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      gradient: goldGloss,
                    ),
                    const SizedBox(height: 4),

                    // ⭐️ New tiny range/length label (only for imported flows)
                    FutureBuilder<_FlowSpanSummary?>(
                      future: _spanFuture,
                      builder: (context, snapshot) {
                        final summary = snapshot.data;
                        if (summary == null) {
                          return const SizedBox.shrink();
                        }

                        String fmt(DateTime d) {
                          const months = [
                            'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                            'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
                          ];
                          final m = months[d.month - 1];
                          return '$m ${d.day}, ${d.year}';
                        }

                        final label =
                            '${summary.dayCount} day${summary.dayCount == 1 ? '' : 's'} • '
                            '${fmt(summary.start)} → ${fmt(summary.end)}';

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            label,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 4),

                    if (rulesJson.isEmpty)
                      const Text(
                        'No schedule information.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      )
                    else
                      _SharedFlowSchedulePreview(
                        rulesJson: rulesJson,
                        kemetic: kemetic,
                      ),
                    const SizedBox(height: 24),

                    // Events section - always show if events exist
                    // ✅ Removed isImported check since we set it to false for inbox shares
                    if (eventsJson.isNotEmpty) ...[
                      const GlossyText(
                        text: 'Events',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        gradient: goldGloss,
                      ),
                      const SizedBox(height: 4),
                      ...eventsJson.map((event) {
                        return _SharedEventTile(event: event);
                      }).toList(),
                    ],
                  ],
                ),
              ),

              // Footer
              if (widget.showRemoveButton && widget.onRemove != null)
                SafeArea(
                  minimum: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent.withOpacity(0.15),
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      await widget.onRemove!();
                    },
                    child: const Text('Remove from profile'),
                  ),
                )
              else if (widget.showImportFooter)
                SafeArea(
                  minimum: const EdgeInsets.all(16),
                  child: data.isImported
                      ? _ImportedFlowFooter(flowId: data.flowId!)
                      : _SharedFlowImportFooter(flowData: data),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Simple container for the data we need to render the details page.
class _SharedFlowData {
  final String name;
  final int color;
  final String notes;
  final List<dynamic> rulesJson;
  final List<dynamic> eventsJson; // ✅ Added for events[] array
  final Map<String, dynamic>? suggestedScheduleJson;
  final bool isImported;
  final int? flowId;
  final InboxShareItem? share;

  _SharedFlowData({
    required this.name,
    required this.color,
    required this.notes,
    required this.rulesJson,
    required this.eventsJson, // ✅ Added
    required this.suggestedScheduleJson,
    required this.isImported,
    required this.flowId,
    required this.share,
  });
}

class _SharedFlowSchedulePreview extends StatelessWidget {
  final List<Map<String, dynamic>> rulesJson;
  final bool kemetic;

  const _SharedFlowSchedulePreview({
    Key? key,
    required this.rulesJson,
    required this.kemetic,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (rulesJson.isEmpty) {
      return const SizedBox.shrink();
    }

    final ruleJson = rulesJson.first;
    final type = ruleJson['type'] as String?;

    if (type == 'decan') {
      return _buildDecanRuleFromJson(ruleJson);
    } else if (type == 'week') {
      return _buildWeekRuleFromJson(ruleJson);
    } else if (type == 'dates') {
      return _buildDatesRuleFromJson(ruleJson);
    }

    return const Text(
      'Custom schedule',
      style: TextStyle(fontSize: 13, color: Colors.white70),
    );
  }

  Widget _buildDecanRuleFromJson(Map<String, dynamic> json) {
    final months =
        (json['months'] as List<dynamic>? ?? const []).cast<int>()..sort();
    final decans =
        (json['decans'] as List<dynamic>? ?? const []).cast<int>()..sort();
    final days =
        (json['daysInDecan'] as List<dynamic>? ?? const []).cast<int>()
          ..sort();

    final monthLabels = months
        .map((m) => getMonthById(m).displayFull)
        .join(', ');

    final decanLabels =
        decans.map((d) => ['I', 'II', 'III'][d - 1]).join(', ');

    if (days.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Months: $monthLabels',
            style:
                const TextStyle(fontSize: 13, color: Colors.white),
          ),
          Text(
            'Decans: $decanLabels',
            style:
                const TextStyle(fontSize: 13, color: Colors.white),
          ),
          Text(
            'Days in decan: ${days.join(', ')}',
            style:
                const TextStyle(fontSize: 13, color: Colors.white),
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Months: $monthLabels',
            style:
                const TextStyle(fontSize: 13, color: Colors.white),
          ),
          Text(
            'Decans: $decanLabels (all days)',
            style:
                const TextStyle(fontSize: 13, color: Colors.white),
          ),
        ],
      );
    }
  }

  Widget _buildWeekRuleFromJson(Map<String, dynamic> json) {
    final weekdays =
        (json['weekdays'] as List<dynamic>? ?? const []).cast<int>()
          ..sort();

    const weekdayNames = <int, String>{
      DateTime.monday: 'Mon',
      DateTime.tuesday: 'Tue',
      DateTime.wednesday: 'Wed',
      DateTime.thursday: 'Thu',
      DateTime.friday: 'Fri',
      DateTime.saturday: 'Sat',
      DateTime.sunday: 'Sun',
    };

    final labels =
        weekdays.map((w) => weekdayNames[w] ?? 'Day $w').join(', ');

    return Text(
      'Repeats on: $labels',
      style: const TextStyle(fontSize: 13, color: Colors.white),
    );
  }

  Widget _buildDatesRuleFromJson(Map<String, dynamic> json) {
    final msList =
        (json['dates'] as List<dynamic>? ?? const []).cast<int>();
    if (msList.isEmpty) {
      return const Text(
        'No dates selected',
        style: TextStyle(fontSize: 13, color: Colors.white70),
      );
    }

    final dates = msList
        .map((ms) =>
            DateUtils.dateOnly(DateTime.fromMillisecondsSinceEpoch(ms)))
        .toList()
      ..sort();

    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    if (dates.length == 1) {
      return Text(
        'Occurs on: ${fmt(dates.first)}',
        style: const TextStyle(fontSize: 13, color: Colors.white),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Occurs on ${dates.length} dates',
          style: const TextStyle(fontSize: 13, color: Colors.white),
        ),
        Text(
          'From ${fmt(dates.first)} to ${fmt(dates.last)}',
          style: const TextStyle(fontSize: 13, color: Colors.white70),
        ),
      ],
    );
  }
}

/// Widget to display a single event from the events[] array in payloadJson
class _SharedEventTile extends StatelessWidget {
  final Map<String, dynamic> event;

  const _SharedEventTile({
    Key? key,
    required this.event,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final title = (event['title'] as String?) ?? 'Untitled Event';
    final detail = event['detail'] as String?;
    final location = event['location'] as String?;
    final allDay = event['all_day'] as bool? ?? false;
    final startTime = event['start_time'] as String?;
    final endTime = event['end_time'] as String?;
    final int? offsetDays = (event['offset_days'] as num?)?.toInt();
    final int? dayNumber =
        offsetDays != null ? (offsetDays + 1) : null; // Snapshot offsets are zero-based

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and offset
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          if (dayNumber != null)
            Text(
              'Day $dayNumber',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
            ],
          ),

          // Time
          if (!allDay && startTime != null) ...[
            const SizedBox(height: 4),
            Text(
              endTime != null ? '$startTime - $endTime' : startTime,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ] else if (allDay) ...[
            const SizedBox(height: 4),
            const Text(
              'All day',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ],

          // Detail
          if (detail != null && detail.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              detail.trim(),
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white,
              ),
            ),
          ],

          // Location
          if (location != null && location.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              location.trim(),
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF4DA3FF),
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ImportedFlowFooter extends StatelessWidget {
  final int flowId;

  const _ImportedFlowFooter({
    Key? key,
    required this.flowId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => CalendarPage(
                initialFlowIdToEdit: flowId,
              ),
            ),
          );
        },
        child: const Text('Edit Flow'),
      ),
    );
  }
}

class _SharedFlowImportFooter extends StatefulWidget {
  final _SharedFlowData flowData;

  const _SharedFlowImportFooter({
    Key? key,
    required this.flowData,
  }) : super(key: key);

  @override
  State<_SharedFlowImportFooter> createState() =>
      _SharedFlowImportFooterState();
}

class _SharedFlowImportFooterState extends State<_SharedFlowImportFooter> {
  DateTime? _selectedStart;
  bool _isWorking = false;

  @override
  Widget build(BuildContext context) {
    final suggestedStr =
        widget.flowData.suggestedScheduleJson?['start_date'] as String?;
    final DateTime? suggestedDate =
        suggestedStr != null ? DateTime.tryParse(suggestedStr) : null;

    final displayDate = _selectedStart ?? suggestedDate;

    final label = displayDate == null
        ? 'Select a start date'
        : 'Start: ${displayDate.year}-${displayDate.month.toString().padLeft(2, '0')}-${displayDate.day.toString().padLeft(2, '0')}';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _isWorking
                ? null
                : () async {
                    final picked = await FlowStartDatePicker.show(
                      context,
                      initialDate: displayDate ?? DateTime.now(),
                    );

                    if (picked != null && mounted) {
                      setState(() => _selectedStart = picked);
                    }
                  },
            child: Text(label),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isWorking
                ? null
                : () async {
                    if (_selectedStart == null && suggestedDate == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Please select a start date first.'),
                        ),
                      );
                      return;
                    }

                    setState(() => _isWorking = true);

                    try {
                      final share = widget.flowData.share!;
                      final payload = share.payloadJson;
                      if (payload == null) {
                        throw Exception('No flow data available');
                      }

                      final flowId = await CalendarPage.importFlowFromShare(
                        context,
                        ImportFlowData(
                          share: share,
                          name: (payload['name'] as String?) ?? share.title,
                          color: payload['color'] as int? ?? 0xFF4DD0E1,
                          notes: payload['notes'] as String?,
                          rules: payload['rules'] as List<dynamic>? ?? const [],
                          suggestedStartDate: _selectedStart ?? suggestedDate,
                        ),
                      );

                      if (!mounted) return;

                      if (flowId != null) {
                        final inboxRepo = InboxRepo(Supabase.instance.client);
                        await inboxRepo.markImported(share.shareId, isFlow: true);
                        Navigator.pop<int>(context, flowId);
                      } else {
                        setState(() => _isWorking = false);
                      }
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Import failed: $e')),
                      );
                      setState(() => _isWorking = false);
                    }
                  },
            child:
                Text(_isWorking ? 'Importing…' : 'Import Flow'),
          ),
        ),
      ],
    );
  }
}
