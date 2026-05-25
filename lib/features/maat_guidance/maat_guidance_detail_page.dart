import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/navigation_fallback.dart';
import '../../data/maat_guidance_model.dart';
import '../../data/maat_guidance_repo.dart';
import '../../services/ai_flow_generation_service.dart';
import '../../shared/glossy_text.dart';
import '../calendar/calendar_page.dart';
import 'maat_guidance_controller.dart';

typedef MaatGuidanceFlowStudioOpener =
    Future<void> Function(
      BuildContext context,
      Map<String, dynamic> restorationState,
    );

class MaatGuidanceDetailPage extends StatefulWidget {
  const MaatGuidanceDetailPage({
    super.key,
    required this.deliveryId,
    this.repo,
    this.flowStudioOpener,
  });

  final String deliveryId;
  final MaatGuidanceDataSource? repo;
  final MaatGuidanceFlowStudioOpener? flowStudioOpener;

  @override
  State<MaatGuidanceDetailPage> createState() => _MaatGuidanceDetailPageState();
}

class _MaatGuidanceDetailPageState extends State<MaatGuidanceDetailPage> {
  late final MaatGuidanceDataSource _repo =
      widget.repo ?? MaatGuidanceRepo(Supabase.instance.client);
  MaatGuidanceController? _controller;
  MaatGuidanceDelivery? _delivery;
  bool _loading = true;
  bool _loadStarted = false;
  bool _creatingPersonalizedFlow = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = MaatGuidanceScope.maybeOf(context);
    if (_loadStarted) return;
    _loadStarted = true;
    _load();
  }

  Future<void> _load() async {
    final delivery = await _repo.getById(widget.deliveryId);
    if (delivery != null) {
      final controller = _controller;
      if (controller != null) {
        await controller.markOpened(delivery);
      } else {
        await _repo.ack(deliveryId: delivery.id, action: 'opened');
      }
    }
    if (!mounted) return;
    setState(() {
      _delivery = delivery;
      _loading = false;
    });
  }

  Future<void> _handleCta() async {
    final delivery = _delivery;
    if (delivery == null || !delivery.hasCta) return;
    if (delivery.ctaType == MaatGuidanceCtaType.flowPersonalized) {
      await _handlePersonalizedFlow(delivery);
      return;
    }
    _markActedInBackground(delivery);

    final ref = delivery.ctaRef;
    switch (delivery.ctaType) {
      case MaatGuidanceCtaType.node:
        if (ref != null) {
          context.go('/nodes/${Uri.encodeComponent(ref)}');
        }
        return;
      case MaatGuidanceCtaType.flow:
        await _openFlowStudio(<String, dynamic>{
          'mode': 'myFlows',
          if (ref != null && int.tryParse(ref) != null)
            'initialFlowId': int.parse(ref),
        });
        return;
      case MaatGuidanceCtaType.flowTemplate:
        await _openFlowStudio(<String, dynamic>{
          'mode': ref == null ? 'maatFlows' : 'maatTemplate',
          if (ref != null) 'templateKey': ref,
        });
        return;
      case MaatGuidanceCtaType.flowPersonalized:
        return;
      case MaatGuidanceCtaType.none:
        return;
    }
  }

  void _markActedInBackground(MaatGuidanceDelivery delivery) {
    unawaited(_markActed(delivery));
  }

  Future<void> _markActed(
    MaatGuidanceDelivery delivery, {
    Map<String, dynamic>? metadata,
  }) async {
    final controller = _controller;
    if (controller != null) {
      await controller.markActed(delivery, metadata: metadata);
    } else {
      await _repo.ack(
        deliveryId: delivery.id,
        action: 'acted',
        metadata: metadata,
      );
    }
  }

  Future<void> _openFlowStudio(Map<String, dynamic> restorationState) async {
    if (!mounted) return;
    final opener = widget.flowStudioOpener;
    if (opener != null) {
      await opener(context, restorationState);
      return;
    }
    await CalendarPage.openFlowStudioFromAnyContext(
      context,
      restorationState: restorationState,
    );
  }

  Future<void> _handlePersonalizedFlow(MaatGuidanceDelivery delivery) async {
    if (_creatingPersonalizedFlow) return;
    final brief = _asStringKeyedMap(delivery.payload['flow_brief']);
    final description = _trimmed(brief?['description']);
    final sourceText = _trimmed(brief?['sourceText']);
    final durationDays = _asInt(brief?['durationDays']) ?? 7;
    final fallbackTemplateKey = _fallbackTemplateKey(delivery);

    if (description == null || sourceText == null) {
      await _openFallbackFlow(fallbackTemplateKey);
      return;
    }

    setState(() => _creatingPersonalizedFlow = true);
    try {
      final start = DateUtils.dateOnly(DateTime.now());
      final end = start.add(Duration(days: durationDays - 1));
      final response = await AIFlowGenerationService(Supabase.instance.client)
          .generate(
            description: description,
            sourceText: sourceText,
            startDate: start,
            endDate: end,
            flowColor: '#4dd0e1',
            maatDeliveryId: delivery.id,
            maatBriefId:
                _trimmed(delivery.payload['brief_id']) ?? delivery.ctaRef,
          );
      if (!mounted) return;

      if (response.success != true) {
        await _openFallbackFlow(fallbackTemplateKey);
        return;
      }

      final flowId = await CalendarPage.importGeneratedFlowFromAnyContext(
        context,
        response: response,
        baseStart: start,
      );
      if (!mounted || flowId == null) return;

      final metadata = <String, dynamic>{
        'brief_id': _trimmed(delivery.payload['brief_id']) ?? delivery.ctaRef,
        'generation_id': response.generationId,
        'flow_id': flowId,
        'cta_type': 'flow_personalized',
      };
      await _markActed(delivery, metadata: metadata);
    } finally {
      if (mounted) setState(() => _creatingPersonalizedFlow = false);
    }
  }

  Future<void> _handleChooseAnotherPath(MaatGuidanceDelivery delivery) async {
    await _openFallbackFlow(_fallbackTemplateKey(delivery));
  }

  String? _fallbackTemplateKey(MaatGuidanceDelivery delivery) {
    final brief = _asStringKeyedMap(delivery.payload['flow_brief']);
    return _trimmed(brief?['fallbackTemplateKey']) ??
        _trimmed(delivery.payload['fallback_template_key']);
  }

  Future<void> _openFallbackFlow(String? fallbackTemplateKey) async {
    if (!mounted) return;
    await _openFlowStudio(<String, dynamic>{
      'mode': fallbackTemplateKey == null ? 'maatFlows' : 'maatTemplate',
      if (fallbackTemplateKey != null) 'templateKey': fallbackTemplateKey,
    });
  }

  @override
  Widget build(BuildContext context) {
    final delivery = _delivery;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: KemeticGold.icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => popOrGo(context, '/'),
        ),
        title: Text(
          delivery?.kind.title ?? 'Guidance',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(KemeticGold.base),
              ),
            )
          : delivery == null
          ? Center(
              child: Text(
                'Guidance not found',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
            )
          : _buildBody(delivery),
    );
  }

  Widget _buildBody(MaatGuidanceDelivery delivery) {
    final openingContext = delivery.kind == MaatGuidanceKind.decanOpening
        ? _buildOpeningContext(delivery)
        : null;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KemeticGold.text(
            delivery.kind.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          if (openingContext != null) ...[
            openingContext,
            const SizedBox(height: 18),
          ],
          SelectableText(
            delivery.bodyText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.5,
              letterSpacing: 0,
            ),
          ),
          if (delivery.ctaType == MaatGuidanceCtaType.flowPersonalized)
            _buildFlowPreview(delivery),
          if (delivery.hasCta) ...[
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _handleCta,
                style: OutlinedButton.styleFrom(
                  foregroundColor: KemeticGold.base,
                  side: BorderSide(
                    color: KemeticGold.base.withValues(alpha: 0.55),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _creatingPersonalizedFlow
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            KemeticGold.base,
                          ),
                        ),
                      )
                    : Text(
                        delivery.ctaLabel,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
          if (delivery.ctaType == MaatGuidanceCtaType.flowPersonalized) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _creatingPersonalizedFlow
                    ? null
                    : () => _handleChooseAnotherPath(delivery),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white.withValues(alpha: 0.76),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Choose another path',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget? _buildOpeningContext(MaatGuidanceDelivery delivery) {
    final variants = _asStringKeyedMap(delivery.payload['surface_variants']);
    final contextCard = _asStringKeyedMap(variants?['context_card']);
    final rows = _openingContextRows(contextCard?['rows']);
    if (rows.isEmpty) return null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        border: Border.all(color: KemeticGold.base.withValues(alpha: 0.26)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final row in rows)
              _OpeningContextRow(label: row.key, value: row.value),
          ],
        ),
      ),
    );
  }

  Widget _buildFlowPreview(MaatGuidanceDelivery delivery) {
    final brief = _asStringKeyedMap(delivery.payload['flow_brief']);
    final preview = _asStringKeyedMap(brief?['preview']);
    final summary =
        _trimmed(delivery.payload['preview_summary']) ??
        _trimmed(preview?['overviewSummary']);
    final sampleDays = _asStringList(
      delivery.payload['sample_days'] ?? preview?['sampleDays'],
    );
    if (summary == null && sampleDays.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: KemeticGold.base.withValues(alpha: 0.28)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KemeticGold.text(
                'Flow preview',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (summary != null) ...[
                const SizedBox(height: 8),
                Text(
                  summary,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.4,
                    letterSpacing: 0,
                  ),
                ),
              ],
              if (sampleDays.isNotEmpty) ...[
                const SizedBox(height: 10),
                for (final day in sampleDays.take(3))
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '- $day',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 13,
                        height: 1.35,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OpeningContextRow extends StatelessWidget {
  const _OpeningContextRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KemeticGold.text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 13,
              height: 1.38,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

Map<String, dynamic>? _asStringKeyedMap(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return null;
}

String? _trimmed(Object? raw) {
  final text = raw?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

int? _asInt(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw?.toString() ?? '');
}

List<String> _asStringList(Object? raw) {
  if (raw is! Iterable) return const <String>[];
  return raw
      .map((item) => item?.toString().trim())
      .whereType<String>()
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

List<MapEntry<String, String>> _openingContextRows(Object? raw) {
  if (raw is! Iterable) return const <MapEntry<String, String>>[];
  return raw
      .map((item) {
        final row = _asStringKeyedMap(item);
        final label = _trimmed(row?['label']);
        final value = _trimmed(row?['value']);
        if (label == null || value == null) return null;
        return MapEntry(label, value);
      })
      .whereType<MapEntry<String, String>>()
      .toList(growable: false);
}
