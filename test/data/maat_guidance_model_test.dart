import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/maat_guidance_model.dart';

void main() {
  test('parses guidance delivery rows from Supabase JSON', () {
    final delivery = MaatGuidanceDelivery.fromJson({
      'id': 'delivery-1',
      'kind': 'drift_nudge',
      'decan_period_key': '2026-05-16:2026-05-25:1-1',
      'status': 'pending',
      'priority': 20,
      'teaser_text': 'A path back to balance is available.',
      'body_text': 'Begin with one measured act.',
      'payload': {'lead_axis': 'M'},
      'cta_type': 'node',
      'cta_ref': 'djehuty',
      'trigger_reason': 'band_worsened',
      'created_at': '2026-05-16T12:00:00Z',
    });

    expect(delivery.id, 'delivery-1');
    expect(delivery.kind, MaatGuidanceKind.driftNudge);
    expect(delivery.status, MaatGuidanceStatus.pending);
    expect(delivery.hasCta, isTrue);
    expect(delivery.ctaLabel, 'Open Node');
    expect(delivery.payload['lead_axis'], 'M');
  });

  test('opening guidance defaults to safe no-cta values', () {
    final delivery = MaatGuidanceDelivery.fromJson({
      'id': 'opening-1',
      'kind': 'decan_opening',
      'decan_period_key': '2026-05-16:2026-05-25:1-1',
      'teaser_text': 'Begin with measure.',
      'body_text': 'Begin with measure.',
    });

    expect(delivery.kind, MaatGuidanceKind.decanOpening);
    expect(delivery.status, MaatGuidanceStatus.pending);
    expect(delivery.ctaType, MaatGuidanceCtaType.none);
    expect(delivery.hasCta, isFalse);
  });

  test('opening node CTA uses user-facing label', () {
    final delivery = MaatGuidanceDelivery.fromJson({
      'id': 'opening-node',
      'kind': 'decan_opening',
      'decan_period_key': '2026-05-16:2026-05-25:1-1',
      'teaser_text': 'Begin with measure.',
      'body_text': 'Begin with measure.',
      'cta_type': 'node',
      'cta_ref': 'maat',
    });

    expect(delivery.hasCta, isTrue);
    expect(delivery.ctaLabel, 'Read the guiding node');
  });

  test('personalized flow CTA parses as consent action', () {
    final delivery = MaatGuidanceDelivery.fromJson({
      'id': 'drift-flow',
      'kind': 'drift_nudge',
      'decan_period_key': '2026-05-16:2026-05-25:1-1',
      'teaser_text': 'A path back to balance is available.',
      'body_text': 'Preview the flow before creating it.',
      'cta_type': 'flow_personalized',
      'cta_ref': 'mfb_v1_drift_restore_provision_M',
    });

    expect(delivery.ctaType, MaatGuidanceCtaType.flowPersonalized);
    expect(delivery.hasCta, isTrue);
    expect(delivery.ctaLabel, 'Create this flow');
  });
}
