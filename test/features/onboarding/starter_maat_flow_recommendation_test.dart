import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/onboarding/starter_maat_flow_recommendation.dart';
import 'package:mobile/features/calendar/maat_flow_catalog.dart';
import 'package:mobile/features/calendar/maat_flow_identity.dart';

void main() {
  const service = StarterFlowRecommendationService();
  const expected = {
    HawEntryIntent.sky: MaatFlowKind.trackSky,
    HawEntryIntent.nourishment: MaatFlowKind.offeringTable,
    HawEntryIntent.reading: MaatFlowKind.readingHouse,
    HawEntryIntent.stability: MaatFlowKind.theDjed,
    HawEntryIntent.imagination: MaatFlowKind.theKar,
  };
  test('five distinct intentions cover exactly the live joinable catalog', () {
    expect(HawEntryIntent.values.toSet(), expected.keys.toSet());
    expect(expected.values.toSet(), kNewJoinAllowedMaatFlowKinds);
    expect(expected.values.toSet(), kDiscoverableMaatFlowKinds);
    for (final entry in expected.entries) {
      final recommendation = service.recommend(entry.key);
      expect(recommendation, same(maatFlowCatalogEntry(entry.value)));
      expect(recommendation.isDiscoverable, isTrue);
      expect(recommendation.isJoinable, isTrue);
      expect(service.recommend(entry.key), same(recommendation));
    }
  });
  test('every choice and closing belongs to its intention', () {
    expect(HawEntryIntent.values.map((i) => i.label).toSet(), hasLength(5));
    expect(
      HawEntryIntent.values.map((i) => i.closingCopy).toSet(),
      hasLength(5),
    );
    for (final intent in HawEntryIntent.values) {
      expect(HawEntryIntent.fromWire(intent.name), intent);
      expect(intent.label, isNotEmpty);
      expect(intent.closingCopy, isNot(contains('At the end of the day')));
    }
    expect(HawEntryIntent.fromWire(null), isNull);
    expect(HawEntryIntent.fromWire('focus'), isNull);
    expect(HawEntryIntent.fromWire('unknown'), isNull);
  });
}
