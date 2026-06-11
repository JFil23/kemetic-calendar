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
      'teaser_text': 'Tend to measure.',
      'body_text': 'Begin with one measured act.',
      'payload': {'lead_axis': 'M'},
      'cta_type': 'node',
      'cta_ref': 'djehuty',
      'trigger_reason': 'band_worsened',
      'created_at': '2026-05-16T12:00:00Z',
    });

    expect(delivery.id, 'delivery-1');
    expect(delivery.kind, MaatGuidanceKind.driftNudge);
    expect(delivery.kind.title, 'Ma’at Grounding');
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

  test('archive_only status round-trips from database value', () {
    final delivery = MaatGuidanceDelivery.fromJson({
      'id': 'archive-only',
      'kind': 'decan_opening',
      'decan_period_key': '2026-05-29:2026-06-07:3-2',
      'status': 'archive_only',
      'teaser_text': 'Archived guidance.',
      'body_text': 'Archived guidance.',
    });

    expect(delivery.status, MaatGuidanceStatus.archiveOnly);
    expect(delivery.status.dbValue, 'archive_only');
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

  test('opening title and teaser name the decan when payload provides it', () {
    final delivery = MaatGuidanceDelivery.fromJson({
      'id': 'opening-named',
      'kind': 'decan_opening',
      'decan_period_key': '2026-05-29:2026-06-07:3-2',
      'teaser_text':
          'This decan marks harmonization. Say clearly who you build with.',
      'body_text': 'Opening body.',
      'payload': {'decan_short_name': 'ḥry-ib sꜣḥ'},
    });

    expect(delivery.decanDisplayName, 'ḥry-ib sꜣḥ');
    expect(delivery.bannerTitle, 'You are in ḥry-ib sꜣḥ');
    expect(
      delivery.displayTeaserText,
      'ḥry-ib sꜣḥ marks harmonization. Say clearly who you build with.',
    );
  });

  test('personalized flow CTA parses as consent action', () {
    final delivery = MaatGuidanceDelivery.fromJson({
      'id': 'drift-flow',
      'kind': 'drift_nudge',
      'decan_period_key': '2026-05-16:2026-05-25:1-1',
      'teaser_text': 'Tend to provision.',
      'body_text': 'Preview the flow before creating it.',
      'cta_type': 'flow_personalized',
      'cta_ref': 'mfb_v1_drift_restore_provision_M',
    });

    expect(delivery.ctaType, MaatGuidanceCtaType.flowPersonalized);
    expect(delivery.hasCta, isTrue);
    expect(delivery.ctaLabel, 'Create this flow');
  });

  test('flow template CTA uses suggested-flow label', () {
    final delivery = MaatGuidanceDelivery.fromJson({
      'id': 'drift-template-flow',
      'kind': 'drift_nudge',
      'decan_period_key': '2026-05-16:2026-05-25:1-1',
      'teaser_text': 'Tend to provision.',
      'body_text': 'Tend to provision by restoring one check.',
      'cta_type': 'flow_template',
      'cta_ref': 'dawn-house-rite',
    });

    expect(delivery.ctaType, MaatGuidanceCtaType.flowTemplate);
    expect(delivery.hasCta, isTrue);
    expect(delivery.ctaLabel, 'Open suggested flow');
  });

  test('compiled package text owns visible guidance copy', () {
    final delivery = MaatGuidanceDelivery.fromJson({
      'id': 'compiled-delivery',
      'kind': 'drift_nudge',
      'decan_period_key': '2026-05-16:2026-05-25:1-1',
      'teaser_text': 'Legacy teaser should not render.',
      'body_text': 'Legacy body should not render.',
      'payload': {
        'compiled_output_package': {
          'package_version': 'compiled_output_package_v1',
          'teaser_text': 'Compiled teaser renders.',
          'final_text': 'Compiled final body renders.',
          'push_text': 'Compiled push renders.',
        },
      },
    });

    expect(delivery.teaserText, 'Compiled teaser renders.');
    expect(delivery.bodyText, 'Compiled final body renders.');
  });

  test('deterministic Weighing orientation exposes lower-third badge copy', () {
    final delivery = MaatGuidanceDelivery.fromJson({
      'id': 'orientation-delivery',
      'kind': 'decan_opening',
      'decan_period_key': '2026-05-29:2026-06-07:3-2',
      'teaser_text': 'Legacy teaser should not render.',
      'body_text': 'Legacy body should not render.',
      'payload': {
        'maat_flow_response_renderer': {
          'renderer': 'deterministic_spectrum',
          'used_llm': false,
          'llm_cost': 0,
          'spectrum_flow_key': 'the-weighing',
          'response_kind': 'orientation',
          'badge_role': 'opening_orientation',
          'preferred_surface': 'lower_third_badge',
          'badge_title': 'Orientation',
        },
        'maat_flow_response': {
          'responseKind': 'orientation',
          'body': 'Keep the record plain before drawing meaning from it.',
          'badgeTitle': 'Orientation',
          'badgeBody': 'Keep the record plain before drawing meaning from it.',
          'selectedSeed': {
            'seed': 'Keep the record plain before drawing meaning from it.',
            'flowKey': 'the-weighing',
            'badgeRole': 'opening_orientation',
            'preferredSurface': 'lower_third_badge',
          },
        },
      },
    });

    expect(delivery.isDeterministicWeighingOpeningOrientation, isTrue);
    expect(delivery.renderMetadata?.renderer, 'deterministic_spectrum');
    expect(delivery.renderMetadata?.usedLlm, isFalse);
    expect(delivery.renderMetadata?.llmCost, 0);
    expect(delivery.renderMetadata?.spectrumFlowKey, 'the-weighing');
    expect(delivery.renderMetadata?.responseKind, 'orientation');
    expect(delivery.renderMetadata?.badgeRole, 'opening_orientation');
    expect(delivery.lowerThirdBadgeTitle, 'Orientation');
    expect(
      delivery.lowerThirdBadgeText,
      'Keep the record plain before drawing meaning from it.',
    );
    expect(
      delivery.detailText,
      'Keep the record plain before drawing meaning from it.',
    );
    expect(delivery.lowerThirdBadgeText, isNot(contains('Legacy teaser')));
  });
}
