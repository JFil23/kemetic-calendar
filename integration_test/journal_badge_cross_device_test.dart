import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/data/journal_repo.dart';
import 'package:mobile/features/journal/journal_badge_utils.dart';
import 'package:mobile/features/journal/journal_controller.dart';
import 'package:mobile/features/journal/journal_event_badge.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('journal badge persists across devices', (tester) async {
    final mode = const String.fromEnvironment('BADGE_SYNC_MODE');
    final badgeId = const String.fromEnvironment('BADGE_SYNC_BADGE_ID');
    final sessionB64 = const String.fromEnvironment('BADGE_SYNC_SESSION_B64');

    expect(
      mode,
      isIn(<String>['write', 'read', 'cleanup']),
      reason: 'Set BADGE_SYNC_MODE to write, read, or cleanup.',
    );
    expect(badgeId, isNotEmpty, reason: 'Set BADGE_SYNC_BADGE_ID.');
    expect(sessionB64, isNotEmpty, reason: 'Set BADGE_SYNC_SESSION_B64.');

    await _initializeSupabase();
    await Supabase.instance.client.auth.recoverSession(
      utf8.decode(base64Decode(sessionB64)),
    );

    final user = Supabase.instance.client.auth.currentUser;
    expect(user, isNotNull, reason: 'Cross-device test requires auth.');

    if (mode == 'cleanup') {
      final removed = await _removeLocalJournalCacheContainingBadge(
        user!.id,
        badgeId,
      );
      debugPrint(
        'CODEX_BADGE_CLEANUP_OK user=${user.id} badge=$badgeId removed=$removed',
      );
      return;
    }

    final controller = JournalController(Supabase.instance.client);
    await controller.init();

    if (mode == 'write') {
      final raw = EventBadgeToken.buildToken(
        id: badgeId,
        eventId: 'integration:$badgeId',
        title: 'Cross-device badge $badgeId',
        description: 'Added on Android emulator for cross-device sync QA.',
        color: Colors.amber,
      );
      await controller.appendToToday(
        'Cross-device badge persistence QA $badgeId $raw',
      );
      final saved = await controller.forceSave();
      expect(saved, isTrue, reason: 'Android write did not reach Supabase.');
      expect(controller.syncStatus, JournalSyncStatus.synced);

      final entry = await JournalRepo(
        Supabase.instance.client,
      ).getByDateStrict(DateTime.now());
      expect(entry, isNotNull);
      expect(entry!.body, contains(badgeId));
      debugPrint('CODEX_BADGE_WRITE_OK user=${user!.id} badge=$badgeId');
      return;
    }

    var found = false;
    for (var attempt = 0; attempt < 8; attempt++) {
      await controller.reloadToday();
      final doc = controller.currentDocument;
      if (doc != null) {
        final tokens = JournalBadgeUtils.tokensFromDocument(doc);
        found = tokens.any((token) => token.id == badgeId);
      }
      if (found) break;
      await Future<void>.delayed(const Duration(seconds: 1));
    }

    expect(
      found,
      isTrue,
      reason: 'iOS simulator did not read badge $badgeId from Supabase.',
    );
    debugPrint('CODEX_BADGE_READ_OK user=${user!.id} badge=$badgeId');
  });
}

Future<void> _initializeSupabase() async {
  final raw = await rootBundle.loadString('env/dev.json');
  final json = jsonDecode(raw) as Map<String, dynamic>;
  final url = (json['SUPABASE_URL'] as String).trim();
  final anonKey = (json['SUPABASE_ANON_KEY'] as String).trim();

  await Supabase.initialize(
    url: url.endsWith('/') ? url.substring(0, url.length - 1) : url,
    anonKey: anonKey,
    authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
  );
}

Future<int> _removeLocalJournalCacheContainingBadge(
  String userId,
  String badgeId,
) async {
  final prefs = await SharedPreferences.getInstance();
  final dateKey = _dateKey(DateTime.now());
  var removed = 0;

  for (final scope in <String>['user:$userId', 'local']) {
    final documentKey = 'journal:$scope:document:$dateKey';
    final draftKey = 'journal:$scope:draft:$dateKey';
    final document = prefs.getString(documentKey);
    final draft = prefs.getString(draftKey);
    final containsBadge =
        (document?.contains(badgeId) ?? false) ||
        (draft?.contains(badgeId) ?? false);
    if (!containsBadge) continue;

    for (final kind in <String>[
      'document',
      'draft',
      'document_dirty',
      'draft_dirty',
      'document_modified_at',
      'draft_modified_at',
    ]) {
      if (await prefs.remove('journal:$scope:$kind:$dateKey')) {
        removed++;
      }
    }
  }

  return removed;
}

String _dateKey(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)}';
}
