import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/navigation_fallback.dart';
import '../../data/maat_guidance_model.dart';
import '../../data/maat_guidance_repo.dart';
import '../../services/ai_flow_generation_service.dart';
import '../../shared/glossy_text.dart';
import '../calendar/calendar_page.dart';
import '../nodes/kemetic_node_library.dart';
import 'maat_guidance_controller.dart';

class MaatGuidanceDetailPage extends StatefulWidget {
  const MaatGuidanceDetailPage({
    super.key,
    required this.deliveryId,
    this.repo,
  });

  final String deliveryId;
  final MaatGuidanceDataSource? repo;

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
    final controller = _controller;
    if (controller != null) {
      await controller.markActed(delivery);
    } else {
      await _repo.ack(deliveryId: delivery.id, action: 'acted');
    }
    if (!mounted) return;

    final ref = delivery.ctaRef;
    switch (delivery.ctaType) {
      case MaatGuidanceCtaType.node:
        if (ref != null) {
          context.go('/nodes/${Uri.encodeComponent(ref)}');
        }
        return;
      case MaatGuidanceCtaType.flow:
        await CalendarPage.openFlowStudioFromAnyContext(
          context,
          restorationState: <String, dynamic>{
            'mode': 'myFlows',
            if (ref != null && int.tryParse(ref) != null)
              'initialFlowId': int.parse(ref),
          },
        );
        return;
      case MaatGuidanceCtaType.flowTemplate:
        await CalendarPage.openFlowStudioFromAnyContext(
          context,
          restorationState: <String, dynamic>{
            'mode': ref == null ? 'maatFlows' : 'maatTemplate',
            if (ref != null) 'templateKey': ref,
          },
        );
        return;
      case MaatGuidanceCtaType.flowPersonalized:
        return;
      case MaatGuidanceCtaType.none:
        return;
    }
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
    await CalendarPage.openFlowStudioFromAnyContext(
      context,
      restorationState: <String, dynamic>{
        'mode': fallbackTemplateKey == null ? 'maatFlows' : 'maatTemplate',
        if (fallbackTemplateKey != null) 'templateKey': fallbackTemplateKey,
      },
    );
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
          if (delivery.kind == MaatGuidanceKind.decanOpening) ...[
            _buildOpeningContext(delivery),
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

  Widget _buildOpeningContext(MaatGuidanceDelivery delivery) {
    final todayLine = _openingTodayLine(delivery);
    final axisLabel = _axisLabel(_trimmed(delivery.payload['lead_axis']));
    final moveLabel = _moveLabel(_trimmed(delivery.payload['reflection_move']));
    final nodeRef =
        _trimmed(delivery.payload['node_ref']) ??
        (delivery.ctaType == MaatGuidanceCtaType.node ? delivery.ctaRef : null);
    final node = nodeRef == null ? null : KemeticNodeLibrary.resolve(nodeRef);

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
            if (todayLine != null)
              _OpeningContextRow(label: 'Today', value: todayLine),
            _OpeningContextRow(
              label: 'Journey signal',
              value:
                  'This opening is tracking ${axisLabel.toLowerCase()} in your current pattern. Move forward by choosing one step that can be seen, recorded, and repeated: ${moveLabel.toLowerCase()}.',
            ),
            if (node != null)
              _OpeningContextRow(
                label: 'Guiding node',
                value: '${node.glyph} ${node.title}',
              ),
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

String? _openingTodayLine(MaatGuidanceDelivery delivery) {
  for (final paragraph in delivery.bodyText.split(RegExp(r'\n\s*\n'))) {
    final text = paragraph.trim();
    if (text.startsWith('Today centers')) return text;
  }

  final index = delivery.teaserText.indexOf('Today centers');
  if (index < 0) return null;
  return delivery.teaserText.substring(index).trim();
}

String _axisLabel(String? axis) {
  switch (axis) {
    case 'T':
      return 'Truth';
    case 'M':
      return 'Measure';
    case 'H':
      return 'Life-preserving rhythm';
    case 'V':
      return 'Care';
    case 'J':
      return 'Due measure';
    case 'S':
      return 'Provision';
    case 'E':
      return 'Seasonal flow';
    case 'R':
      return 'Restraint';
    case 'C':
      return 'Cohesion';
    default:
      return 'Ma\'at';
  }
}

String _moveLabel(String? move) {
  switch (move) {
    case 'affirm':
      return 'preserve the rhythm that is already holding';
    case 'correct':
      return 'repair the smallest broken promise first';
    case 'inquire':
    default:
      return 'make one concrete record before deciding';
  }
}
