import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/maat_flow_catalog.dart';
import 'package:mobile/features/calendar/maat_flow_identity.dart';

void main() {
  const approvedCoreKeys = <String>{
    'track-the-sky',
    'dawn-house-rite',
    'evening-threshold-rite',
    'the-offering-table',
    'the-weighing',
    'the-kept-word',
    'the-djed',
    'the-tending',
    'the-first-arrangement',
    'the-clearing',
    'the-reading-house',
    'the-wag',
    'the-days-outside-the-year',
  };

  test('all 33 historical identities have exactly one disposition', () {
    expect(MaatFlowKind.values, hasLength(33));
    expect(kMaatFlowCatalog, hasLength(33));
    expect(kMaatFlowCatalog.keys.toSet(), MaatFlowKind.values.toSet());

    for (final kind in MaatFlowKind.values) {
      final entry = maatFlowCatalogEntry(kind);
      expect(entry.kind, kind);
    }
  });

  test('catalog exposes exactly the approved 13 core products', () {
    expect(coreMaatFlowKinds, hasLength(13));
    expect(coreMaatFlowKeys, approvedCoreKeys);
    expect(coreMaatFlowKeys, hasLength(13));
    expect(coreMaatFlowKeys.toSet(), hasLength(13));
    expect(coreMaatFlowKinds.every(isCoreMaatFlowKind), isTrue);
    expect(coreMaatFlowKeys.every(isCoreMaatFlowKey), isTrue);
  });

  test(
    'catalog status totals are 13 core, 14 absorbed, 5 retired, 1 legacy',
    () {
      final counts = <MaatFlowCatalogStatus, int>{};
      for (final entry in kMaatFlowCatalog.values) {
        counts.update(entry.status, (count) => count + 1, ifAbsent: () => 1);
      }

      expect(counts, <MaatFlowCatalogStatus, int>{
        MaatFlowCatalogStatus.core: 13,
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
    },
  );

  test('core taxonomy verbs are complete and unique', () {
    final verbs = coreMaatFlowKinds
        .map((kind) => maatFlowCatalogEntry(kind).verb)
        .toList(growable: false);

    expect(verbs, everyElement(isNotNull));
    expect(verbs.toSet(), hasLength(13));
    expect(verbs.toSet(), <String?>{
      'ORIENT',
      'BEGIN',
      'CLOSE',
      'NOURISH',
      'CORRECT',
      'KEEP',
      'STABILIZE',
      'CARE',
      'ORDER',
      'CLEAR',
      'STUDY',
      'REMEMBER',
      'RENEW',
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
    'new-join gate rejects all 20 non-core kinds before side effects',
    () async {
      final nonCoreKinds = MaatFlowKind.values
          .where((kind) => !isCoreMaatFlowKind(kind))
          .toList(growable: false);
      expect(nonCoreKinds, hasLength(20));

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
