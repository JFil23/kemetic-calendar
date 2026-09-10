import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/maat_flow_catalog.dart';
import 'package:mobile/features/calendar/maat_flow_identity.dart';

void main() {
  const approvedProductKeys = <String>{
    'track-the-sky',
    'the-offering-table',
    'the-djed',
    'the-reading-house',
    'the-kar',
  };
  const archivedKinds = <MaatFlowKind>{
    MaatFlowKind.dawnHouseRite,
    MaatFlowKind.eveningThresholdRite,
    MaatFlowKind.theWeighing,
    MaatFlowKind.keptWord,
    MaatFlowKind.theTending,
    MaatFlowKind.firstArrangement,
    MaatFlowKind.clearing,
    MaatFlowKind.theWag,
    MaatFlowKind.daysOutsideTheYear,
  };

  test('all 34 historical identities have exactly one disposition', () {
    expect(MaatFlowKind.values, hasLength(34));
    expect(kMaatFlowCatalog, hasLength(34));
    expect(kMaatFlowCatalog.keys.toSet(), MaatFlowKind.values.toSet());

    for (final kind in MaatFlowKind.values) {
      final entry = maatFlowCatalogEntry(kind);
      expect(entry.kind, kind);
    }
  });

  test('catalog exposes exactly the five active products', () {
    expect(discoverableMaatFlowKinds, hasLength(5));
    expect(discoverableMaatFlowKeys, approvedProductKeys);
    expect(coreMaatFlowKinds, hasLength(5));
    expect(coreMaatFlowKeys, approvedProductKeys);
    expect(coreMaatFlowKinds.every(isCoreMaatFlowKind), isTrue);
    expect(coreMaatFlowKeys.every(isCoreMaatFlowKey), isTrue);
    expect(approvedProductKeys.every(isMaatFlowNewJoinAllowed), isTrue);
  });

  test('catalog separates five core products from nine archived products', () {
    final counts = <MaatFlowCatalogStatus, int>{};
    for (final entry in kMaatFlowCatalog.values) {
      counts.update(entry.status, (count) => count + 1, ifAbsent: () => 1);
    }

    expect(counts, <MaatFlowCatalogStatus, int>{
      MaatFlowCatalogStatus.core: 5,
      MaatFlowCatalogStatus.archived: 9,
      MaatFlowCatalogStatus.absorbed: 14,
      MaatFlowCatalogStatus.retired: 5,
      MaatFlowCatalogStatus.legacy: 1,
    });
    expect(
      kMaatFlowCatalog.values
          .where((entry) => entry.status != MaatFlowCatalogStatus.core)
          .every((entry) => !entry.isJoinable),
      isTrue,
    );
  });

  test(
    'all nine archived identities resolve but remain compatibility-only',
    () {
      expect(kArchivedCompatibilityMaatFlowKinds, archivedKinds);
      for (final kind in archivedKinds) {
        expect(
          resolveMaatFlowKind(
            behaviorPayload: <String, dynamic>{'flow_key': kind.flowKey},
          ),
          kind,
          reason: kind.flowKey,
        );
        expect(
          maatFlowCatalogEntry(kind).status,
          MaatFlowCatalogStatus.archived,
        );
        expect(isMaatFlowCompatibilitySupported(kind.flowKey), isTrue);
        expect(isMaatFlowDiscoverable(kind.flowKey), isFalse);
        expect(isMaatFlowNewJoinAllowed(kind.flowKey), isFalse);
      }
    },
  );

  test('active product taxonomy verbs are complete and unique', () {
    final verbs = coreMaatFlowKinds
        .map((kind) => maatFlowCatalogEntry(kind).verb)
        .toList(growable: false);

    expect(verbs, everyElement(isNotNull));
    expect(verbs.toSet(), hasLength(5));
    expect(verbs.toSet(), <String?>{
      'ORIENT',
      'NOURISH',
      'STABILIZE',
      'STUDY',
      'IMAGINE',
    });
  });

  test('recognized import evidence uses catalog disposition', () {
    expect(
      isNewFlowCreationAllowedByMaatCatalog(
        flowNotes: 'mode=kemetic;maat=the-moon-return',
      ),
      isFalse,
    );
    expect(
      isNewFlowCreationAllowedByMaatCatalog(
        events: const <Map<String, dynamic>>[
          <String, dynamic>{
            'behavior_payload': <String, dynamic>{
              'flow_key': 'the-decan-watch',
            },
          },
        ],
      ),
      isFalse,
    );
    expect(
      isNewFlowCreationAllowedByMaatCatalog(
        events: const <Map<String, dynamic>>[
          <String, dynamic>{'action_id': 'the-course-event-01'},
        ],
      ),
      isFalse,
    );
    expect(
      isNewFlowCreationAllowedByMaatCatalog(
        flowName: 'Follow the Sky',
        events: const <Map<String, dynamic>>[
          <String, dynamic>{'action_id': 'the-course-event-01'},
        ],
      ),
      isFalse,
      reason: 'Historical event identity outranks a conflicting display name.',
    );
    expect(
      isNewFlowCreationAllowedByMaatCatalog(
        flowNotes: 'mode=kemetic;maat=track-the-sky',
      ),
      isTrue,
    );
    expect(
      isNewFlowCreationAllowedByMaatCatalog(flowName: 'Custom practice'),
      isTrue,
    );
  });

  test(
    'new-join gate rejects all 29 non-product kinds before side effects',
    () async {
      final nonCoreKinds = MaatFlowKind.values
          .where((kind) => !isCoreMaatFlowKind(kind))
          .toList(growable: false);
      expect(nonCoreKinds, hasLength(29));

      for (final kind in nonCoreKinds) {
        var flowWrites = 0;
        var eventWrites = 0;
        var stagedNotes = 0;
        var deliveries = 0;
        var invalidations = 0;

        final result = await applyMaatFlowNewJoinPolicy<int>(
          flowKey: kind.flowKey,
          rejectedValue: -1,
          create: () {
            flowWrites++;
            eventWrites++;
            stagedNotes++;
            deliveries++;
            invalidations++;
            return 1;
          },
        );

        expect(result, -1, reason: kind.flowKey);
        expect(flowWrites, 0, reason: kind.flowKey);
        expect(eventWrites, 0, reason: kind.flowKey);
        expect(stagedNotes, 0, reason: kind.flowKey);
        expect(deliveries, 0, reason: kind.flowKey);
        expect(invalidations, 0, reason: kind.flowKey);
      }
    },
  );

  test('new-join gate allows every core identity', () async {
    for (final kind in coreMaatFlowKinds) {
      var creates = 0;
      final result = await applyMaatFlowNewJoinPolicy<int>(
        flowKey: kind.flowKey,
        rejectedValue: -1,
        create: () {
          creates++;
          return 1;
        },
      );
      expect(result, 1, reason: kind.flowKey);
      expect(creates, 1, reason: kind.flowKey);
    }
  });
}
