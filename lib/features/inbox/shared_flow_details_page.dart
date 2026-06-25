// lib/features/inbox/shared_flow_details_page.dart
// Dual-mode details page: supports both imported flows (flowId) and non-imported shares (share)

import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/navigation_fallback.dart';
import '../../data/share_models.dart';
import '../../data/share_repo.dart';
import '../../data/flows_repo.dart';
import '../../data/user_events_repo.dart';
import '../../repositories/inbox_repo.dart';
import '../../utils/detail_sanitizer.dart';
import '../../shared/glossy_text.dart' show KemeticGold;
import '../../features/calendar/calendar_page.dart'
    show
        CalendarPage,
        FlowDetailActionKind,
        FlowDetailActionPolicy,
        FlowDetailSource,
        ImportFlowData;
import '../../widgets/flow_start_date_picker.dart';

const Color _bg = Color(0xFF000000);

class SharedFlowDetailsPage extends StatefulWidget {
  final InboxShareItem? share; // non-imported
  final int? flowId; // imported
  final int?
  importedFlowId; // imported state while still rendering share payload
  final Map<String, dynamic>? payloadJson; // direct payload (e.g., flow post)
  final bool showImportFooter;
  final bool showRemoveButton;
  final Future<void> Function()? onRemove;
  final FlowDetailActionPolicy? actionPolicy;
  final String fallbackLocation;

  const SharedFlowDetailsPage({
    super.key,
    this.share,
    this.flowId,
    this.importedFlowId,
    this.payloadJson,
    this.showImportFooter = true,
    this.showRemoveButton = false,
    this.onRemove,
    this.actionPolicy,
    this.fallbackLocation = '/inbox',
  }) : assert(
         share != null || flowId != null || payloadJson != null,
         'Either share, flowId, or payloadJson must be provided',
       );

  @override
  State<SharedFlowDetailsPage> createState() => _SharedFlowDetailsPageState();
}

class _SharedFlowDetailsPageState extends State<SharedFlowDetailsPage> {
  late final UserEventsRepo _userEventsRepo;
  late Future<_SharedFlowData> _flowFuture;
  bool _trackedShareViewed = false;
  DateTime? _selectedStart;
  bool _isImporting = false;
  int? _localImportedFlowId;

  int? get _effectiveImportedFlowId =>
      _localImportedFlowId ?? widget.importedFlowId;

  /// Merge duplicate events (same day/title/time/detail/location) to avoid double rendering
  List<Map<String, dynamic>> _dedupeEvents(List<Map<String, dynamic>> events) {
    final seen = <String, Map<String, dynamic>>{};

    String keyFor(Map<String, dynamic> e) {
      final title = cleanFlowTitle(e['title'] as String?).trim().toLowerCase();
      final offset = (e['offset_days'] as num?)?.toInt() ?? 0;
      final allDay = (e['all_day'] as bool?) ?? false;
      final start = (e['start_time'] as String? ?? '').trim().toLowerCase();
      final end = (e['end_time'] as String? ?? '').trim().toLowerCase();
      final detail = cleanFlowDetail(
        e['detail'] as String?,
      ).trim().toLowerCase();
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
      final normalized = Map<String, dynamic>.from(e);
      normalized['detail'] = cleanFlowDetail(e['detail'] as String?);
      final k = keyFor(normalized);
      seen[k] = normalized; // keep latest; they are equivalent for display
    }
    return seen.values.toList();
  }

  @override
  void initState() {
    super.initState();
    _userEventsRepo = UserEventsRepo(Supabase.instance.client);

    // Mark as viewed if current user is the recipient (only for non-imported shares)
    if (widget.share != null) {
      _markAsViewedIfRecipient();
      if (!_trackedShareViewed) {
        _trackedShareViewed = true;
        unawaited(
          _userEventsRepo.trackShareViewed(
            shareId: widget.share!.shareId,
            source: 'inbox',
          ),
        );
      }
    }

    _configureFutures();
  }

  @override
  void didUpdateWidget(covariant SharedFlowDetailsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flowId != widget.flowId ||
        oldWidget.importedFlowId != widget.importedFlowId ||
        oldWidget.share?.shareId != widget.share?.shareId ||
        oldWidget.payloadJson != widget.payloadJson) {
      _configureFutures();
    }
  }

  void _configureFutures() {
    if (widget.flowId != null) {
      _flowFuture = _loadFromDb(widget.flowId!);
    } else if (widget.payloadJson != null) {
      _flowFuture = Future.value(_fromPayload(widget.payloadJson!));
    } else {
      _flowFuture = Future.value(
        _fromShare(widget.share!, importedFlowId: _effectiveImportedFlowId),
      );
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
          debugPrint('[SharedFlowDetailsPage] Failed to mark viewed: $e');
        }
      }
    }
  }

  DateTime? _parsePayloadDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
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
      startDate: row.startDate,
      endDate: row.endDate,
      active: row.active,
      isSaved: row.isSaved,
      share: null,
    );
  }

  _SharedFlowData _fromShare(InboxShareItem share, {int? importedFlowId}) {
    // ✅ 1) Try typed model first
    final payload = share.flowPayload;

    if (payload != null) {
      // Convert typed events to JSON format for _SharedFlowData
      final eventsJson = payload.events
          .map(
            (e) => <String, dynamic>{
              'offset_days': e.offsetDays,
              'title': e.title,
              'detail': e.detail,
              'location': e.location,
              'all_day': e.allDay,
              'start_time': e.startTime,
              'end_time': e.endTime,
              'action_id': e.actionId,
              'behavior_payload': e.behaviorPayload,
            },
          )
          .toList();

      if (kDebugMode) {
        debugPrint(
          '[SharedFlowDetailsPage._fromShare] Using typed payload model',
        );
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
        isImported: importedFlowId != null,
        flowId: importedFlowId,
        startDate: _parsePayloadDate(share.suggestedSchedule?.startDate),
        endDate: null,
        active: importedFlowId != null,
        isSaved: importedFlowId == null,
        share: share,
      );
    }

    // ✅ 2) Fallback to existing manual parsing
    final payloadMap = share.payloadJson ?? const <String, dynamic>{};

    if (kDebugMode) {
      debugPrint(
        '[SharedFlowDetailsPage._fromShare] Using manual parsing fallback',
      );
      debugPrint('  shareId=${share.shareId}');
      debugPrint('  payload keys=${payloadMap.keys.toList()}');
      debugPrint(
        '  events count=${(payloadMap['events'] as List<dynamic>?)?.length ?? 0}',
      );
      debugPrint(
        '  rules count=${(payloadMap['rules'] as List<dynamic>?)?.length ?? 0}',
      );
    }

    // ✅ Use share.title as fallback if payload['name'] is missing
    final nameFromPayload = payloadMap['name'] as String?;
    final safeName =
        (nameFromPayload != null && nameFromPayload.trim().isNotEmpty)
        ? nameFromPayload.trim()
        : (share.title.trim().isNotEmpty
              ? share.title.trim()
              : 'Untitled Flow');

    return _SharedFlowData(
      name: safeName,
      color: (payloadMap['color'] as int?) ?? 0xFF4DD0E1,
      notes: payloadMap['notes'] as String? ?? '',
      rulesJson: (payloadMap['rules'] as List<dynamic>? ?? const []),
      eventsJson: (payloadMap['events'] as List<dynamic>? ?? const []),
      suggestedScheduleJson: share.suggestedSchedule?.toJson(),
      isImported: importedFlowId != null,
      flowId: importedFlowId,
      startDate:
          _parsePayloadDate(payloadMap['start_date']) ??
          _parsePayloadDate(share.suggestedSchedule?.startDate),
      endDate: _parsePayloadDate(payloadMap['end_date']),
      active: importedFlowId != null,
      isSaved: importedFlowId == null,
      share: share,
    );
  }

  _SharedFlowData _fromPayload(Map<String, dynamic> payload) {
    final eventsJson = (payload['events'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();

    return _SharedFlowData(
      name: payload['name'] as String? ?? 'Flow',
      color: (payload['color'] as num?)?.toInt() ?? KemeticGold.base.toARGB32(),
      notes: payload['notes'] as String? ?? '',
      rulesJson: (payload['rules'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>(),
      eventsJson: _dedupeEvents(eventsJson),
      suggestedScheduleJson:
          payload['suggested_schedule'] as Map<String, dynamic>?,
      isImported: false,
      flowId: null,
      startDate: _parsePayloadDate(payload['start_date']),
      endDate: _parsePayloadDate(payload['end_date']),
      active: false,
      isSaved: true,
      share: null,
    );
  }

  FlowDetailActionPolicy _actionPolicyFor(_SharedFlowData data) {
    final explicitPolicy = widget.actionPolicy;
    if (explicitPolicy != null) return explicitPolicy;

    if (widget.showRemoveButton && widget.onRemove != null) {
      return FlowDetailActionPolicy(
        source: FlowDetailSource.profilePost,
        kind: FlowDetailActionKind.manage,
        label: 'Remove from profile',
        busyLabel: 'Removing...',
        icon: Icons.delete_outline,
        busy: _isImporting,
        onPressed: widget.onRemove,
      );
    }

    if (!widget.showImportFooter) {
      return CalendarPage.resolveCanonicalCustomFlowActionPolicy(
        source: FlowDetailSource.other,
        isLocalFlow: false,
        isReadOnly: true,
      );
    }

    if (data.isImported && data.flowId != null) {
      return CalendarPage.resolveCanonicalCustomFlowActionPolicy(
        source: FlowDetailSource.inboxShare,
        isLocalFlow: true,
        isImported: true,
        busy: _isImporting,
        onPressed: () => _openImportedFlow(data.flowId!),
      );
    }

    return CalendarPage.resolveCanonicalCustomFlowActionPolicy(
      source: FlowDetailSource.inboxShare,
      isLocalFlow: false,
      isImported: false,
      busy: _isImporting,
      onPressed: () => _handleSharedImport(data),
      startDateLabel: _startDateLabel(data),
      onStartDatePressed: () => _pickImportStartDate(data),
    );
  }

  String _startDateLabel(_SharedFlowData data) {
    final suggestedStr = data.suggestedScheduleJson?['start_date'] as String?;
    final suggestedDate = _parsePayloadDate(suggestedStr);
    final displayDate = _selectedStart ?? data.startDate ?? suggestedDate;
    if (displayDate == null) return 'Select a start date';
    final date = DateUtils.dateOnly(displayDate);
    return 'Start: ${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickImportStartDate(_SharedFlowData data) async {
    final suggestedStr = data.suggestedScheduleJson?['start_date'] as String?;
    final suggestedDate = _parsePayloadDate(suggestedStr);
    final picked = await FlowStartDatePicker.show(
      context,
      initialDate:
          _selectedStart ?? data.startDate ?? suggestedDate ?? DateTime.now(),
    );

    if (picked != null && mounted) {
      setState(() => _selectedStart = DateUtils.dateOnly(picked));
    }
  }

  Future<void> _openImportedFlow(int flowId) async {
    await CalendarPage.openFlowEditorFromAnyContext(
      context,
      flowId: flowId,
      fallbackLocation: widget.fallbackLocation,
      source: 'shared_flow_details',
    );
  }

  Future<void> _handleSharedImport(_SharedFlowData data) async {
    if (_isImporting) return;
    final share = data.share;
    if (share == null) return;

    final suggestedStr = data.suggestedScheduleJson?['start_date'] as String?;
    final suggestedDate = _parsePayloadDate(suggestedStr);
    final scheduledStart = _selectedStart ?? data.startDate ?? suggestedDate;
    if (scheduledStart == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a start date first.')),
      );
      return;
    }

    setState(() => _isImporting = true);

    try {
      final existingFlowId = await _userEventsRepo.getFlowIdByShareId(
        share.shareId,
      );
      if (existingFlowId != null) {
        final inboxRepo = InboxRepo(Supabase.instance.client);
        await inboxRepo.markImported(share.shareId, isFlow: true);
        if (!mounted) return;
        setState(() {
          _localImportedFlowId = existingFlowId;
          _isImporting = false;
          _configureFutures();
        });
        return;
      }

      final payload = share.payloadJson;
      if (payload == null) {
        throw Exception('No flow data available');
      }
      final originFlowId =
          (payload['flow_id'] as num?)?.toInt() ??
          int.tryParse(share.payloadId);
      final scheduledStartIso =
          '${scheduledStart.year}-${scheduledStart.month.toString().padLeft(2, '0')}-${scheduledStart.day.toString().padLeft(2, '0')}';

      if (!context.mounted) return;
      final flowId = await CalendarPage.importFlowFromShare(
        // ignore: use_build_context_synchronously
        context,
        ImportFlowData(
          share: share,
          name: (payload['name'] as String?) ?? share.title,
          color: payload['color'] as int? ?? 0xFF4DD0E1,
          notes: payload['notes'] as String?,
          rules: payload['rules'] as List<dynamic>? ?? const [],
          suggestedStartDate: scheduledStart,
          originFlowId: originFlowId,
          rootFlowId: originFlowId,
          originType: 'share_import',
        ),
      );

      if (!mounted) return;

      if (flowId != null) {
        final inboxRepo = InboxRepo(Supabase.instance.client);
        await inboxRepo.markImported(share.shareId, isFlow: true);
        unawaited(
          _userEventsRepo.trackFlowImported(
            flowId: flowId,
            shareId: share.shareId,
            originType: 'share_import',
            originFlowId: originFlowId,
            scheduledStartIso: scheduledStartIso,
          ),
        );
        if (!mounted) return;
        setState(() {
          _localImportedFlowId = flowId;
          _isImporting = false;
          _configureFutures();
        });
      } else {
        setState(() => _isImporting = false);
      }
    } catch (e) {
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
      unawaited(
        _userEventsRepo.trackFlowImportFailed(
          shareId: share.shareId,
          error: e.toString(),
        ),
      );
      setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_SharedFlowData>(
      future: _flowFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.black,
              leading: IconButton(
                icon: KemeticGold.icon(Icons.arrow_back),
                onPressed: () => popOrGo(context, widget.fallbackLocation),
              ),
            ),
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
        final eventsJson = _dedupeEvents(
          data.eventsJson.whereType<Map<String, dynamic>>().toList(),
        );
        final maatDetail = CalendarPage.buildCanonicalMaatFlowDetail(
          name: cleanFlowTitle(data.name),
          notes: data.notes,
          eventsJson: eventsJson,
        );
        if (maatDetail != null) return maatDetail;

        final actionPolicy = _actionPolicyFor(data);

        return CalendarPage.buildCanonicalCustomFlowDetail(
          name: cleanFlowTitle(data.name),
          color: data.color,
          notes: data.notes,
          rulesJson: data.rulesJson,
          eventsJson: eventsJson,
          flowId: data.flowId,
          startDate: data.startDate,
          endDate: data.endDate,
          active: data.active,
          isSaved: data.isSaved,
          previewAsTemplate: !data.isImported,
          actionPolicy: actionPolicy,
          showFlowOptions: false,
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
  final DateTime? startDate;
  final DateTime? endDate;
  final bool active;
  final bool isSaved;
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
    required this.startDate,
    required this.endDate,
    required this.active,
    required this.isSaved,
    required this.share,
  });
}
