import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'maat_guidance_model.dart';

class MaatGuidanceListResult {
  const MaatGuidanceListResult({required this.data, this.errorMessage});

  final List<MaatGuidanceDelivery> data;
  final String? errorMessage;

  bool get hasError => errorMessage != null;
}

class MaatGuidanceEvaluateResult {
  const MaatGuidanceEvaluateResult({
    this.localDate,
    this.decanDayIndex,
    this.periodKey,
    this.evaluationId,
    this.suppressed = const <String>[],
    this.created = const <Map<String, dynamic>>[],
    this.driftDecision,
    this.strengthDecision,
  });

  final String? localDate;
  final int? decanDayIndex;
  final String? periodKey;
  final String? evaluationId;
  final List<String> suppressed;
  final List<Map<String, dynamic>> created;
  final Map<String, dynamic>? driftDecision;
  final Map<String, dynamic>? strengthDecision;

  factory MaatGuidanceEvaluateResult.fromJson(Map<String, dynamic>? json) {
    final evaluation = _asMap(json?['evaluation']);
    return MaatGuidanceEvaluateResult(
      localDate: json?['local_date']?.toString(),
      decanDayIndex: _asInt(json?['decan_day_index']),
      periodKey: json?['period_key']?.toString(),
      evaluationId: evaluation?['id']?.toString(),
      suppressed: _asStringList(json?['suppressed']),
      created: _asMapList(json?['created']),
      driftDecision:
          _asMap(json?['drift_decision']) ??
          _asMap(_asMap(evaluation?['decision'])?['drift']),
      strengthDecision:
          _asMap(json?['strength_decision']) ??
          _asMap(_asMap(evaluation?['decision'])?['strength']),
    );
  }
}

abstract interface class MaatGuidanceDataSource {
  Future<MaatGuidanceDelivery?> fetchPending();
  Future<MaatGuidanceDelivery?> getById(String id);
  Future<void> ack({
    required String deliveryId,
    required String action,
    Map<String, dynamic>? metadata,
  });
  Future<MaatGuidanceEvaluateResult?> evaluate({String? timezone});
}

class MaatGuidanceRepo implements MaatGuidanceDataSource {
  const MaatGuidanceRepo(this._client);

  final SupabaseClient _client;

  @override
  Future<MaatGuidanceDelivery?> fetchPending() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    try {
      final res = await _client.functions.invoke(
        'fetch_maat_guidance_pending',
        body: const <String, dynamic>{},
      );
      final data = _asMap(res.data);
      final delivery = _asMap(data?['delivery']);
      if (delivery == null) return null;
      return MaatGuidanceDelivery.fromJson(delivery);
    } catch (error) {
      debugPrint('[MaatGuidanceRepo] fetchPending skipped: $error');
      return null;
    }
  }

  @override
  Future<MaatGuidanceDelivery?> getById(String id) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null || id.trim().isEmpty) return null;
    try {
      final res = await _client.functions.invoke(
        'fetch_maat_guidance_pending',
        body: <String, dynamic>{'delivery_id': id.trim()},
      );
      final data = _asMap(res.data);
      final delivery = _asMap(data?['delivery']);
      if (delivery == null) return null;
      return MaatGuidanceDelivery.fromJson(delivery);
    } catch (error) {
      debugPrint('[MaatGuidanceRepo] getById skipped: $error');
      return null;
    }
  }

  @override
  Future<void> ack({
    required String deliveryId,
    required String action,
    Map<String, dynamic>? metadata,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null || deliveryId.trim().isEmpty) return;
    try {
      await _client.functions.invoke(
        'ack_maat_guidance',
        body: <String, dynamic>{
          'delivery_id': deliveryId.trim(),
          'action': action,
          if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
        },
      );
    } catch (error) {
      debugPrint('[MaatGuidanceRepo] ack $action skipped: $error');
    }
  }

  @override
  Future<MaatGuidanceEvaluateResult?> evaluate({String? timezone}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    try {
      final res = await _client.functions.invoke(
        'evaluate_maat_guidance',
        body: <String, dynamic>{
          if (timezone != null && timezone.trim().isNotEmpty)
            'timezone': timezone.trim(),
        },
      );
      if (res.status < 200 || res.status >= 300) {
        debugPrint(
          '[MaatGuidanceRepo] evaluate failed: ${res.status} ${res.data}',
        );
        return null;
      }
      return MaatGuidanceEvaluateResult.fromJson(_asMap(res.data));
    } catch (error) {
      debugPrint('[MaatGuidanceRepo] evaluate skipped: $error');
      return null;
    }
  }

  Future<MaatGuidanceListResult> listDecanOpeningsForArchive() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      return const MaatGuidanceListResult(
        data: <MaatGuidanceDelivery>[],
        errorMessage: 'Sign in to view your decan openings.',
      );
    }
    try {
      final res = await _client
          .from('maat_guidance_deliveries')
          .select()
          .eq('user_id', uid)
          .eq('kind', MaatGuidanceKind.decanOpening.dbValue)
          .inFilter('status', <String>[
            MaatGuidanceStatus.opened.dbValue,
            MaatGuidanceStatus.acted.dbValue,
            MaatGuidanceStatus.archiveOnly.dbValue,
          ])
          .order('created_at', ascending: false);
      final rows = (res as List)
          .map(
            (row) => MaatGuidanceDelivery.fromJson(row as Map<String, dynamic>),
          )
          .toList(growable: false);
      return MaatGuidanceListResult(data: rows);
    } catch (error) {
      debugPrint(
        '[MaatGuidanceRepo] listDecanOpeningsForArchive skipped: $error',
      );
      return const MaatGuidanceListResult(
        data: <MaatGuidanceDelivery>[],
        errorMessage: 'Could not load decan openings.',
      );
    }
  }
}

Map<String, dynamic>? _asMap(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return null;
}

int? _asInt(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw?.toString() ?? '');
}

List<String> _asStringList(Object? raw) {
  if (raw is! Iterable) return const <String>[];
  return raw.map((value) => value.toString()).toList(growable: false);
}

List<Map<String, dynamic>> _asMapList(Object? raw) {
  if (raw is! Iterable) return const <Map<String, dynamic>>[];
  return raw
      .map(_asMap)
      .whereType<Map<String, dynamic>>()
      .toList(growable: false);
}
