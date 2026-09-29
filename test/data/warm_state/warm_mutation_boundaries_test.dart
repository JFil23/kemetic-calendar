import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/data/journal_repo.dart';
import 'package:mobile/data/warm_state/warm_snapshot_store.dart';
import 'package:mobile/repositories/dm_conversation_repo.dart';
import '../../features/pages/pages_resource_test.dart' show session, uid;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Journal reads preserve snapshots, while saves invalidate them',
    () async {
      SharedPreferences.setMockInitialValues({});
      final client = SupabaseClient(
        'https://example.supabase.co',
        'key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient(
          (request) async => http.Response(
            '[]',
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      await client.auth.recoverSession(session());
      final store = WarmSnapshotStore.instance;
      await store.refresh(
        uid,
        'journal.entry.test',
        () async => {},
        isCurrent: () => true,
      );
      await JournalRepo(client).getByDate(DateTime(2026, 9, 29));
      expect(store.peek(uid, 'journal.entry.test'), isNotNull);
      await JournalRepo(
        client,
      ).upsert(localDate: DateTime(2026, 9, 29), body: 'Edited');
      expect(store.peek(uid, 'journal.entry.test'), isNull);
      await client.dispose();
    },
  );
  test(
    'read receipts retain messages, while sending fences the message snapshot',
    () async {
      SharedPreferences.setMockInitialValues({});
      final client = SupabaseClient(
        'https://example.supabase.co',
        'key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient(
          (request) async => http.Response(
            '{}',
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      await client.auth.recoverSession(session());
      final store = WarmSnapshotStore.instance;
      await store.refresh(
        uid,
        'dm.messages.test',
        () async => [],
        isCurrent: () => true,
      );
      final repo = DmConversationRepo(client);
      await repo.markRead('test');
      expect(store.peek(uid, 'dm.messages.test'), isNotNull);
      await repo.sendMessage(conversationId: 'test', text: 'A message');
      expect(store.peek(uid, 'dm.messages.test'), isNull);
      await client.dispose();
    },
  );
}
