import 'package:mobile/core/completion_status.dart';
import 'package:mobile/core/composition/composition_engine.dart';
import 'package:mobile/core/composition/composition_models.dart';
import 'package:mobile/features/calendar/decan_reflection_composition/maat_flow_cross_flow_analyzer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MaatFlowDecanCompletion {
  const MaatFlowDecanCompletion({
    required this.completedOn,
    required this.completionStatus,
    required this.flowKey,
    this.flowTitle,
  });

  final DateTime completedOn;
  final CompletionStatus completionStatus;
  final String flowKey;
  final String? flowTitle;

  static MaatFlowDecanCompletion? fromRow(Map<String, dynamic> row) {
    final metadata = row['metadata'];
    if (metadata is! Map) return null;
    final meta = Map<String, dynamic>.from(metadata);
    final flowKey = meta['flow_key']?.toString().trim();
    if (flowKey == null || flowKey.isEmpty) return null;

    final sourceType = meta['source_type']?.toString().trim();
    if (sourceType != null &&
        sourceType.isNotEmpty &&
        sourceType != 'maat_flow') {
      return null;
    }

    final date = DateTime.tryParse(row['completed_on']?.toString() ?? '');
    if (date == null) return null;

    final status = CompletionStatusX.fromWireName(
      meta['completion_status']?.toString() ?? meta['status']?.toString(),
    );
    if (status == CompletionStatus.none) return null;

    final flowTitle = meta['flow_title']?.toString().trim();
    return MaatFlowDecanCompletion(
      completedOn: DateTime(date.year, date.month, date.day),
      completionStatus: status,
      flowKey: flowKey,
      flowTitle: flowTitle == null || flowTitle.isEmpty ? null : flowTitle,
    );
  }
}

class MaatFlowDecanFactCollector {
  const MaatFlowDecanFactCollector(this._client);

  final SupabaseClient _client;

  Future<CompositionFactSnapshot> collect({
    required DateTime decanStart,
    required DateTime decanEnd,
    required String surface,
  }) async {
    final rows = await _client
        .from('user_event_completions')
        .select('completed_on, metadata')
        .gte('completed_on', _formatDate(decanStart))
        .lte('completed_on', _formatDate(decanEnd))
        .order('completed_on', ascending: true);
    final completions = (rows as List)
        .whereType<Map>()
        .map(
          (row) =>
              MaatFlowDecanCompletion.fromRow(Map<String, dynamic>.from(row)),
        )
        .whereType<MaatFlowDecanCompletion>()
        .toList(growable: false);
    return snapshotFromCompletions(
      completions: completions,
      decanStart: decanStart,
      decanEnd: decanEnd,
      surface: surface,
    );
  }

  static CompositionFactSnapshot snapshotFromCompletions({
    required List<MaatFlowDecanCompletion> completions,
    required DateTime decanStart,
    required DateTime decanEnd,
    required String surface,
  }) {
    final observedCount = completions
        .where((row) => row.completionStatus == CompletionStatus.observed)
        .length;
    final partialCount = completions
        .where((row) => row.completionStatus == CompletionStatus.partial)
        .length;
    final skippedCount = completions
        .where((row) => row.completionStatus == CompletionStatus.skipped)
        .length;
    final activeDays = completions
        .map((row) => _formatDate(row.completedOn))
        .toSet()
        .length;
    final flowCounts = <String, int>{};
    for (final row in completions) {
      flowCounts[row.flowKey] = (flowCounts[row.flowKey] ?? 0) + 1;
    }
    final dominantFlowKey = _dominantFlowKey(flowCounts);
    final total = completions.length;
    final distinctFlowCount = flowCounts.length;
    final zeroData = total == 0;
    final lowData = total == 1;
    final mostlyObserved = total >= 2 && observedCount / total >= 0.6;
    final mostlyPartial = total >= 2 && partialCount / total >= 0.5;
    final manySkips = total >= 2 && skippedCount / total >= 0.4;
    final lowFollowThrough = total >= 2 && observedCount / total < 0.6;
    final singleFlowDepth = total >= 2 && distinctFlowCount == 1;
    final broadFlowSpread = total >= 3 && distinctFlowCount >= 3;

    final facts = <String, Object?>{
      'observed_count': observedCount,
      'partial_count': partialCount,
      'skipped_count': skippedCount,
      'active_days_count': activeDays,
      'distinct_flow_count': distinctFlowCount,
      'dominant_flow_key': dominantFlowKey,
      'total_interactions': total,
      'mostly_observed': mostlyObserved,
      'mostly_partial': mostlyPartial,
      'many_skips': manySkips,
      'low_follow_through': lowFollowThrough,
      'zero_data': zeroData,
      'low_data': lowData,
    };
    final signals = <String>{
      if (zeroData) 'zero_data',
      if (lowData) 'low_data',
      if (mostlyObserved) 'mostly_observed',
      if (mostlyPartial) 'mostly_partial',
      if (manySkips) 'many_skips',
      if (lowFollowThrough) 'low_follow_through',
      if (singleFlowDepth) 'single_flow_depth',
      if (broadFlowSpread) 'broad_flow_spread',
      if (activeDays >= 4 && mostlyObserved) 'steady_presence',
      if (partialCount > 0) 'has_partial',
      if (skippedCount > 0) 'has_skipped',
    };
    final summary = <String, Object?>{
      'observed_count': observedCount,
      'partial_count': partialCount,
      'skipped_count': skippedCount,
      'active_days_count': activeDays,
      'distinct_flow_count': distinctFlowCount,
      'dominant_flow_key': dominantFlowKey,
      'total_interactions': total,
    };
    final fingerprint = stableCompositionFingerprint(<String, Object?>{
      'window_start': _formatDate(decanStart),
      'window_end': _formatDate(decanEnd),
      'facts': facts,
      'signals': signals.toList()..sort(),
    });
    final crossFlowInference = const MaatFlowCrossFlowAnalyzer()
        .analyze(completions)
        ?.toJson();

    return CompositionFactSnapshot(
      surface: surface,
      windowStart: decanStart,
      windowEnd: decanEnd,
      facts: facts,
      signals: signals,
      factFingerprint: fingerprint,
      factSummary: summary,
      crossFlowInference: crossFlowInference,
    );
  }
}

String? _dominantFlowKey(Map<String, int> flowCounts) {
  if (flowCounts.isEmpty) return null;
  final entries = flowCounts.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      if (byCount != 0) return byCount;
      return a.key.compareTo(b.key);
    });
  return entries.first.key;
}

String _formatDate(DateTime date) {
  final local = DateTime(date.year, date.month, date.day);
  final yyyy = local.year.toString().padLeft(4, '0');
  final mm = local.month.toString().padLeft(2, '0');
  final dd = local.day.toString().padLeft(2, '0');
  return '$yyyy-$mm-$dd';
}
