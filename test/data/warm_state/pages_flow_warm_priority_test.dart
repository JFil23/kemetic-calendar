import 'package:mobile/features/calendar/calendar_invalidation.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/data/account_view_cache.dart';
import 'package:mobile/data/flow_appearance.dart';
import 'package:mobile/data/flow_appearance_store.dart';
import 'package:mobile/data/flows_repo.dart';
import 'package:mobile/data/user_events_repo.dart';
import 'package:mobile/data/warm_state/app_warm_state.dart';
import 'package:mobile/data/warm_state/warm_snapshot_store.dart';
import 'package:mobile/features/pages/pages_arrangement.dart';
import 'package:mobile/features/pages/pages_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/pages/pages_resource_test.dart' show session, uid;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('displayed flow and artwork warm ahead of unrelated archives', () async {
    SharedPreferences.setMockInitialValues({});
    await WarmSnapshotStore.instance.forgetAccount(uid);
    FlowAppearanceStore.debugResetImageCacheForTesting();
    final cache = AccountViewCache.instance..enterAccount(uid);
    cache.evictPrefix(uid, '');
    final calls = <String>[];
    final at = DateTime.now().add(const Duration(hours: 2));
    final appearance = FlowAppearance(imageObjectPath: '$uid/selected.png');
    final flow = {
      'id': 42,
      'user_id': uid,
      'name': 'Displayed flow',
      'active': true,
      'visible_in_active_list': true,
      'is_hidden': false,
      'is_reminder': false,
      'is_saved': false,
      'rules': [],
      'appearance': appearance.toJsonOrNull(),
    };
    final client = SupabaseClient(
      'https://example.supabase.co',
      'key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        final table = request.url.path.split('/').last;
        final detail =
            table == 'flows' && request.url.queryParameters['id'] == 'eq.42';
        final events =
            table == 'user_event_filing_items_client' &&
            request.url.queryParameters['filed_flow_id'] == 'eq.42';
        calls.add(
          detail
              ? 'flow'
              : events
              ? 'events'
              : table,
        );
        expect(
          request.method == 'GET' ||
              (request.method == 'POST' && table.startsWith('get_')),
          isTrue,
          reason: 'Warm-up must not write, mark seen, or create subscriptions',
        );
        await Future<void>.delayed(const Duration(milliseconds: 80));
        Object data = [];
        if (detail) data = flow;
        if (table == 'get_my_filed_flows_v1') data = [flow];
        if (events) {
          final offset = int.parse(
            request.url.queryParameters['offset'] ?? '0',
          );
          data = [
            for (var i = offset; i < (offset == 0 ? 500 : 502); i++)
              {
                'id': 'event-$i',
                'client_event_id': 'event-$i',
                'user_id': uid,
                'filed_flow_id': 42,
                'title': 'Occurrence $i',
                'starts_at': at.toUtc().toIso8601String(),
                'all_day': false,
                'item_kind': 'flow',
                'lifecycle': 'active',
              },
          ];
        }
        if (table == 'get_commons_together_home_cards' ||
            table == 'get_together_inbox') {
          data = {};
        }
        return http.Response(
          jsonEncode(data),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    await client.auth.recoverSession(session());
    FlowAppearanceStore.debugDownloadImageForTesting = (_, path) async {
      expect(path, appearance.imageObjectPath);
      calls.add('artwork');
      await Future<void>.delayed(const Duration(milliseconds: 80));
      return Uint8List.fromList([1, 2, 3]);
    };
    cache.publish(uid, 'pages.flows', [
      PagesFlow(id: '42', name: 'Displayed flow', appearance: appearance),
    ]);
    cache.publish(
      uid,
      'pages.events',
      PagesEventWindow([
        PagesUpcomingEvent(flowId: '42', title: 'Selected occurrence', at: at),
      ], at.add(const Duration(days: 1))),
    );
    final watch = Stopwatch()..start();
    final warm = AppWarmState(client)..start();
    addTearDown(() async {
      warm.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await WarmSnapshotStore.instance.flushed;
      await client.dispose();
      FlowAppearanceStore.debugResetImageCacheForTesting();
    });
    final deadline = DateTime.now().add(const Duration(seconds: 8));
    while (FlowAppearanceStore(
              client,
            ).cachedImageBytes(appearance.imageObjectPath!) ==
            null &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    watch.stop();
    // A fast full-detail warm can finish before any archive request starts.
    // Keep the measured ready time, then observe background progress so the
    // original ordering assertion compares two actual request positions.
    while (!calls.contains('journal_entries') &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    warm.didChangeAppLifecycleState(AppLifecycleState.paused);
    final flowIndex = calls.indexOf('flow');
    expect(flowIndex, 0, reason: 'The displayed flow is the first warm read');
    debugPrint(
      'PAGES_FLOW_WARM ready_ms=${watch.elapsedMilliseconds} '
      'reads_before_flow=$flowIndex calls=${calls.join(',')}',
    );
    expect(FlowsRepo(client).cachedFlowById(42)?.name, 'Displayed flow');
    expect(UserEventsRepo(client).cachedFlowDetailEvents(42), hasLength(502));
    expect(
      FlowAppearanceStore(client).cachedImageBytes(appearance.imageObjectPath!),
      orderedEquals([1, 2, 3]),
    );
    expect(
      flowIndex,
      lessThan(calls.indexOf('journal_entries')),
      reason: 'The displayed flow must precede unrelated archive warming',
    );
    expect(calls.where((c) => c == 'flow'), hasLength(1));
    expect(calls.where((c) => c == 'events'), hasLength(2));
  });

  for (final boundary in ['background', 'account return', 'mutation']) {
    test('new Pages target is promoted and fenced across $boundary', () async {
      SharedPreferences.setMockInitialValues({});
      await WarmSnapshotStore.instance.forgetAccount(uid);
      FlowAppearanceStore.debugResetImageCacheForTesting();
      final cache = AccountViewCache.instance..enterAccount(uid);
      cache.evictPrefix(uid, '');
      final firstTodo = Completer<void>(), firstJournal = Completer<void>();
      final heldFlow = Completer<void>(), flowStarted = Completer<void>();
      final firstReads = Completer<void>();
      var blockingReads = 0, flowReads = 0, eventReads = 0, images = 0;
      var todos = 0, journals = 0;
      final at = DateTime.now().add(const Duration(hours: 2));
      final appearance = FlowAppearance(
        imageObjectPath: '$uid/priority-$boundary.png',
      );
      final row = {
        'id': 42,
        'user_id': uid,
        'name': 'Displayed flow',
        'active': true,
        'visible_in_active_list': true,
        'is_hidden': false,
        'is_reminder': false,
        'is_saved': false,
        'rules': [],
        'appearance': appearance.toJsonOrNull(),
      };
      final client = SupabaseClient(
        'https://example.supabase.co',
        'key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((r) async {
          final table = r.url.path.split('/').last;
          Object data = [];
          if (table == 'todos' && todos++ == 0 ||
              table == 'journal_entries' && journals++ == 0) {
            blockingReads++;
            if (blockingReads == 2) firstReads.complete();
            await (table == 'todos' ? firstTodo.future : firstJournal.future);
          }
          if (table == 'flows' && r.url.queryParameters['id'] == 'eq.42') {
            flowReads++;
            if (flowReads == 1) {
              flowStarted.complete();
              await heldFlow.future;
            }
            data = row;
          }
          if (table == 'get_my_filed_flows_v1') data = [row];
          if (table == 'user_event_filing_items_client' &&
              r.url.queryParameters['filed_flow_id'] == 'eq.42') {
            eventReads++;
            data = [
              {
                'id': 'target',
                'client_event_id': 'target-client',
                'user_id': uid,
                'filed_flow_id': 42,
                'title': 'Selected occurrence',
                'starts_at': at.toUtc().toIso8601String(),
                'all_day': false,
                'item_kind': 'flow',
                'lifecycle': 'active',
              },
            ];
          }
          if (table == 'logout' ||
              table == 'get_together_inbox' ||
              table == 'get_commons_together_home_cards') {
            data = {};
          }
          return http.Response(
            jsonEncode(data),
            200,
            headers: {'content-type': 'application/json'},
            request: r,
          );
        }),
      );
      await client.auth.recoverSession(session());
      FlowAppearanceStore.debugDownloadImageForTesting =
          (imageClient, objectPath) async {
            expect(imageClient, same(client));
            expect(objectPath, appearance.imageObjectPath);
            images++;
            return Uint8List.fromList([7]);
          };
      void publishSelection() {
        cache.publish(uid, 'pages.flows', [
          PagesFlow(id: '42', name: 'Displayed flow', appearance: appearance),
        ]);
        cache.publish(
          uid,
          'pages.events',
          PagesEventWindow([
            PagesUpcomingEvent(
              flowId: '42',
              title: 'Selected occurrence',
              at: at,
            ),
          ], at.add(const Duration(days: 1))),
        );
      }

      final warm = AppWarmState(client)..start();
      addTearDown(() async {
        warm.dispose();
        for (final held in [firstTodo, firstJournal, heldFlow]) {
          if (!held.isCompleted) held.complete();
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await WarmSnapshotStore.instance.flushed;
        await client.dispose();
        FlowAppearanceStore.debugResetImageCacheForTesting();
      });
      await firstReads.future.timeout(const Duration(seconds: 2));
      publishSelection();
      expect(flowReads, 0, reason: 'Keep the existing two-worker bound');
      firstJournal.complete();
      await flowStarted.future.timeout(const Duration(seconds: 2));
      if (boundary == 'background') {
        warm.didChangeAppLifecycleState(AppLifecycleState.paused);
      } else if (boundary == 'mutation') {
        row['name'] = 'Acknowledged flow update';
        CalendarInvalidationBus.instance.publish(
          const CalendarInvalidated(
            reason: CalendarInvalidationReason.flowStudioPersisted,
            flowId: 42,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
      } else {
        await client.auth.signOut(scope: SignOutScope.local);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await client.auth.recoverSession(session());
        await Future<void>.delayed(const Duration(milliseconds: 10));
        publishSelection();
      }
      heldFlow.complete();
      firstTodo.complete();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (boundary == 'background') {
        expect(WarmSnapshotStore.instance.peek(uid, 'flow.detail.42'), isNull);
        expect(eventReads, 0);
        expect(images, 0);
        warm.didChangeAppLifecycleState(AppLifecycleState.resumed);
      }
      final deadline = DateTime.now().add(const Duration(seconds: 3));
      while (images == 0 && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(
        FlowsRepo(client).cachedFlowById(42)?.name,
        boundary == 'mutation' ? 'Acknowledged flow update' : 'Displayed flow',
      );
      expect(UserEventsRepo(client).cachedFlowDetailEvents(42), hasLength(1));
      expect(flowReads, 2, reason: 'Only the current generation may publish');
      expect(eventReads, 1);
      expect(images, 1);
      publishSelection();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(
        flowReads,
        2,
        reason: 'Cache notifications cannot repeat warm reads',
      );
      warm.didChangeAppLifecycleState(AppLifecycleState.paused);
    });
  }
}
