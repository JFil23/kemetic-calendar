import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/maat_flow_catalog.dart';
import 'package:mobile/features/calendar/maat_flow_identity.dart';
import 'package:mobile/features/calendar/maat_flow_temporal_policy.dart';
import 'package:mobile/features/calendar/maat_flow_temporal_resolver.dart';

void main() {
  test('The Wag is recognized only as read-only archive history', () {
    const kind = MaatFlowKind.theWag;
    expect(kind.flowKey, 'the-wag');
    expect(resolveMaatFlowKind(flowName: 'The Wag'), kind);
    expect(isMaatFlowDiscoverableKind(kind), isFalse);
    expect(isMaatFlowNewJoinAllowedKind(kind), isFalse);
    expect(isMaatFlowCompatibilitySupportedKind(kind), isTrue);
    expect(maatFlowCatalogEntry(kind).status, MaatFlowCatalogStatus.archived);
    expect(archivedMaatFlowTitle(kind), 'The Wag');
    expect(archivedMaatFlowGlyph(kind), '𓊝');

    final context = MaatFlowTemporalContext.fromInstant(
      nowUtc: DateTime.utc(2026, 9, 6),
      ianaTimeZone: 'UTC',
    );
    expect(
      () => const MaatFlowTemporalResolver().resolve(
        kind: kind,
        context: context,
      ),
      throwsUnsupportedError,
    );
  });
}
