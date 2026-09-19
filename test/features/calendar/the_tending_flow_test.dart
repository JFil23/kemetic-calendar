import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/maat_flow_catalog.dart';
import 'package:mobile/features/calendar/maat_flow_identity.dart';
import 'package:mobile/features/calendar/maat_flow_temporal_policy.dart';
import 'package:mobile/features/calendar/maat_flow_temporal_resolver.dart';

void main() {
  test('The Tending is recognized only as read-only archive history', () {
    const kind = MaatFlowKind.theTending;
    expect(kind.flowKey, 'the-tending');
    expect(resolveMaatFlowKind(flowName: 'The Tending'), kind);
    expect(isMaatFlowDiscoverableKind(kind), isFalse);
    expect(isMaatFlowNewJoinAllowedKind(kind), isFalse);
    expect(isMaatFlowCompatibilitySupportedKind(kind), isTrue);
    expect(maatFlowCatalogEntry(kind).status, MaatFlowCatalogStatus.archived);
    expect(archivedMaatFlowTitle(kind), 'The Tending');
    expect(archivedMaatFlowGlyph(kind), '𓇐');

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
