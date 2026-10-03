import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/data/external_calendar_repository.dart';
import 'package:mobile/data/warm_state/warm_snapshot_store.dart';
import 'package:mobile/features/calendar/calendar_invalidation.dart';
import '../features/pages/pages_resource_test.dart' show session, uid;
import 'package:mobile/features/calendar/snapshot/calendar_snapshot_models.dart';
import 'package:mobile/features/calendar/snapshot/calendar_snapshot_runtime.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const ownerA = 'fixture-owner-a', ownerB = 'fixture-owner-b';
  final day = DateTime.utc(2026, 11, 15);
  final rows = <Map<String, Object?>>[
    {
      'clientEventId': 'external:removed:event',
      'calendarId': 'external:removed',
      'externalCalendarLane': 'staging',
      'title': 'Removed external',
    },
    {
      'clientEventId': 'external:retained:event',
      'calendarId': 'external:retained',
      'externalCalendarLane': 'staging',
      'title': 'Other provider source',
    },
    {
      'clientEventId': 'external:production:event',
      'calendarId': 'external:removed',
      'externalCalendarLane': 'production',
      'title': 'Other lane',
    },
    {
      'clientEventId': 'manual:authored',
      'calendarId': 'personal',
      'title': 'Authored',
    },
    {
      'clientEventId': 'native:legacy',
      'calendarId': 'native',
      'title': 'Legacy native',
    },
  ];
  const overlay = <Map<String, Object?>>[
    {
      'kind': 'create_or_edit',
      'clientEventId': 'manual:pending',
      'note': {'title': 'Durable pending authored'},
    },
    {'kind': 'delete_tombstone', 'identity': 'manual:deleted'},
  ];
  CalendarSnapshotCommit commit(String owner) => CalendarSnapshotCommit(
    userScope: owner,
    serverRevision: 'fixture-server',
    overlayRevision: 'fixture-overlay',
    catalogFingerprint: 'fixture-catalog',
    origin: 'fixture',
    committedAtUtc: day,
    lastSuccessfulRefreshAtUtc: day,
    coverage: [
      CalendarSnapshotCoverageInterval(
        startUtc: day,
        endUtc: day.add(const Duration(days: 1)),
      ),
    ],
    eventsByDay: {'2026-3-1': rows},
    flows: const [],
    overlayRecords: overlay,
    calendarMetadata: const {'personalCalendarId': 'personal'},
  );

  setUpAll(() async {
    await Hive.openBox<String>(
      'calendar_snapshot_store_v1',
      bytes: Uint8List(0),
    );
    await calendarSnapshotStore.initialize();
  });
  tearDownAll(Hive.close);

  test(
    'acknowledged source removal without a mounted page preserves authored, overlays, other source, lane and account',
    () async {
      final client = SupabaseClient(
        'https://example.supabase.co',
        'fixture',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(client.dispose);
      SharedPreferences.setMockInitialValues({
        'calendar:warm_start:v1:$ownerA': jsonEncode({
          'userId': ownerA,
          'notes': {'2026-3-1': rows},
          'preservedMetadata': 'same',
        }),
        'calendar:warm_start:v1:$ownerB': jsonEncode({
          'userId': ownerB,
          'notes': {'2026-3-1': rows},
        }),
      });
      await calendarSnapshotStore.commit(commit(ownerA));
      await calendarSnapshotStore.commit(commit(ownerB));
      final beforeA = (await calendarSnapshotStore.readLatest(ownerA))!;
      final beforeB = (await calendarSnapshotStore.readLatest(ownerB))!;
      final repo = ExternalCalendarRepository(
        client,
        lane: 'staging',
        currentAccount: () => ownerA,
      );
      await repo.projectionChanged(
        removedSources: true,
        removedSourceIds: ['removed'],
      );
      final afterA = (await calendarSnapshotStore.readLatest(ownerA))!;
      final afterB = (await calendarSnapshotStore.readLatest(ownerB))!;
      expect(
        afterA.eventsByDay.values
            .expand((v) => v)
            .map((r) => r['clientEventId']),
        unorderedEquals([
          'external:retained:event',
          'external:production:event',
          'manual:authored',
          'native:legacy',
        ]),
      );
      expect(afterA.overlayRecords, beforeA.overlayRecords);
      expect(afterA.flows, beforeA.flows);
      expect(afterA.calendarMetadata, beforeA.calendarMetadata);
      expect(
        afterA.lastSuccessfulRefreshAtUtc,
        beforeA.lastSuccessfulRefreshAtUtc,
      );
      expect(afterB.canonicalDigest, beforeB.canonicalDigest);
      expect(repo.isSourceRemoved('external:removed', owner: ownerA), true);
      expect(repo.isSourceRemoved('external:removed', owner: ownerB), false);
      final envelope = jsonEncode({
        'userId': ownerA,
        'notes': {'2026-3-1': rows, 'unknown-bucket': 'preserve'},
        'pendingOverlays': overlay,
        'unknownMetadata': {
          'nested': [1, true, 'preserve'],
        },
      });
      final filteredEnvelope =
          jsonDecode(repo.filterSerializedWarmSnapshot(envelope, owner: ownerA))
              as Map;
      expect(filteredEnvelope['pendingOverlays'], overlay);
      expect(filteredEnvelope['unknownMetadata'], {
        'nested': [1, true, 'preserve'],
      });
      expect((filteredEnvelope['notes'] as Map)['unknown-bucket'], 'preserve');
      expect(
        ((filteredEnvelope['notes'] as Map)['2026-3-1'] as List).length,
        4,
      );
      expect(
        repo.filterSerializedWarmSnapshot(envelope, owner: ownerB),
        envelope,
      );
      for (final malformed in [
        'not json',
        '[1,2]',
        '{"userId":"other","notes":{}}',
        '{"userId":"fixture-owner-a","notes":3}',
      ]) {
        expect(
          repo.filterSerializedWarmSnapshot(malformed, owner: ownerA),
          malformed,
        );
      }
      final untouched = jsonEncode({
        'userId': ownerA,
        'notes': {
          'day': [rows[1]],
        },
        'other': true,
      });
      expect(
        repo.filterSerializedWarmSnapshot(untouched, owner: ownerA),
        untouched,
      );

      final prefs = await SharedPreferences.getInstance();
      final mirrorA =
          jsonDecode(prefs.getString('calendar:warm_start:v1:$ownerA')!) as Map;
      final mirrorB =
          jsonDecode(prefs.getString('calendar:warm_start:v1:$ownerB')!) as Map;
      expect(
        (mirrorA['notes'] as Map).values.expand((v) => v as List).length,
        4,
      );
      expect(mirrorA['preservedMetadata'], 'same');
      expect(
        (mirrorB['notes'] as Map).values.expand((v) => v as List).length,
        5,
      );

      // A caller from another account cannot prune this account's stored copies.
      final other = ExternalCalendarRepository(
        client,
        lane: 'staging',
        currentAccount: () => ownerB,
      );
      await other.pruneRemovedSources(ownerA, ['retained']);
      expect(
        (await calendarSnapshotStore.readLatest(ownerA))!.canonicalDigest,
        afterA.canonicalDigest,
      );
    },
  );

  test(
    'a pre-removal response cannot lift the fence but a confirmed reselect can',
    () async {
      SharedPreferences.setMockInitialValues({});
      await WarmSnapshotStore.instance.forgetAccount(uid);
      final requests = <http.Request>[];
      var response = Completer<http.Response>();
      final client = SupabaseClient(
        'https://example.supabase.co',
        'fixture',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) {
          requests.add(request);
          return response.future;
        }),
      );
      addTearDown(client.dispose);
      await client.auth.recoverSession(session());
      final repository = ExternalCalendarRepository(client, lane: 'staging');
      final from = DateTime.utc(2026, 11), until = DateTime.utc(2026, 12);
      final event = {
        'id': 'event',
        'client_event_id': 'external:removed:event',
        'source_id': 'removed',
        'title': 'Imported',
        'all_day': false,
        'starts_at': '2026-11-15T10:00:00Z',
        'ends_at': '2026-11-15T11:00:00Z',
        'calendar_name': 'Calendar',
      };
      void complete() => response.complete(
        http.Response(
          jsonEncode([event]),
          200,
          request: requests.last,
          headers: {'content-type': 'application/json'},
        ),
      );
      expect(await repository.visibleEvents(from, until), isEmpty);
      await Future<void>.delayed(Duration.zero);
      expect(requests, hasLength(1));
      await repository.projectionChanged(removedSourceIds: ['removed']);
      final rejected = CalendarInvalidationBus.instance.stream.first;
      complete();
      await rejected.timeout(const Duration(seconds: 2));
      await Future<void>.delayed(Duration.zero);
      expect(repository.isSourceRemoved('external:removed'), true);
      expect(
        WarmSnapshotStore.instance.peek(uid, repository.rangeKey(from, until)),
        null,
      );

      response = Completer<http.Response>();
      await repository.projectionChanged(removedSources: true);
      expect(await repository.visibleEvents(from, until), isEmpty);
      await Future<void>.delayed(Duration.zero);
      expect(requests, hasLength(2));
      final confirmed = CalendarInvalidationBus.instance.stream.first;
      complete();
      await confirmed.timeout(const Duration(seconds: 2));
      expect(repository.isSourceRemoved('external:removed'), false);
      expect(
        (await repository.visibleEvents(from, until)).single.title,
        'Imported',
      );
      await WarmSnapshotStore.instance.forgetAccount(uid);
    },
  );
}
