import '../calendar/maat_flow_catalog.dart';
import '../calendar/maat_flow_identity.dart';

/// A stated intention selects exactly one current catalog product. Product data
/// and schedules remain owned by the Ma’at catalog and its detail surfaces.
enum HawEntryIntent {
  sky,
  nourishment,
  reading,
  stability,
  imagination;

  MaatFlowKind get kind => switch (this) {
    sky => MaatFlowKind.trackSky,
    nourishment => MaatFlowKind.offeringTable,
    reading => MaatFlowKind.readingHouse,
    stability => MaatFlowKind.theDjed,
    imagination => MaatFlowKind.theKar,
  };

  String get label => switch (this) {
    sky => 'I want to reconnect with the sky and seasons.',
    nourishment => 'I want to nourish myself more consistently.',
    reading => 'I want to make room for deep reading.',
    stability => 'I want to strengthen what holds me up.',
    imagination => 'I want to make room for imagination.',
  };

  String get closingCopy => switch (this) {
    sky =>
      'You gave the sky a place in your time.\n\nThe next turning will meet you here.',
    nourishment =>
      'You gave care a place in your time.\n\nReturn to what sustains you.',
    reading =>
      'You gave reading a place in your time.\n\nThe next sitting is waiting.',
    stability =>
      'You gave stability a place in your time.\n\nSmall returns strengthen what holds you.',
    imagination =>
      'You gave imagination a place in your time.\n\nYour next image has somewhere to arrive.',
  };

  static HawEntryIntent? fromWire(String? value) {
    for (final intent in values) {
      if (intent.name == value) return intent;
    }
    return null;
  }
}

class StarterFlowRecommendationService {
  const StarterFlowRecommendationService();
  MaatFlowCatalogEntry recommend(HawEntryIntent intent) {
    final entry = maatFlowCatalogEntry(intent.kind);
    if (!entry.isDiscoverable || !entry.isJoinable) {
      throw StateError('This recommendation is not available to join.');
    }
    return entry;
  }
}
