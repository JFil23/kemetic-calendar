import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/data/account_view_cache.dart';
import 'package:mobile/data/pages_read_repository.dart';
import 'package:mobile/features/pages/pages_controller.dart';
import 'package:mobile/features/pages/pages_models.dart';
import 'pages_resource_test.dart' show session, uid;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'a populated Journal card remains ready during and after a failed refresh',
    () async {
      SharedPreferences.setMockInitialValues({});
      final client = SupabaseClient(
        'https://example.supabase.co',
        'key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient(
          (_) async => throw StateError('unexpected network read'),
        ),
      );
      await client.auth.recoverSession(session());
      final cache = AccountViewCache()..enterAccount(uid);
      cache.publish(
        uid,
        'journal.overview',
        const JournalOverview(
          written: {},
          historyComplete: true,
          badgesByDay: {
            '2026-09-29': [PagesSignal('A saved moment')],
          },
        ),
      );
      final controller = PagesController(client, cache: cache);
      addTearDown(() async {
        controller.dispose();
        await client.dispose();
      });
      final card = controller.cards[PagesDestination.journal.index];
      expect(card.value.state, PagesLoadState.ready);
      final before = card.value.primary.title;
      final reply = Completer<JournalOverview>();
      cache.beginVisibleEntry();
      final read = cache.load<JournalOverview>(
        uid,
        'journal.overview',
        () => reply.future,
        stale: true,
        mayFetch: () => true,
      );
      await Future<void>.delayed(Duration.zero);
      expect(card.value.state, PagesLoadState.ready);
      reply.completeError(StateError('offline'));
      await read;
      expect(card.value.state, PagesLoadState.ready);
      expect(card.value.primary.title, before);
    },
  );
}
