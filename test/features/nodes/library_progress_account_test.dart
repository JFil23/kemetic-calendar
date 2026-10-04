import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/nodes/library_read_progress_store.dart';
import 'package:mobile/features/nodes/library_read_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final nextAccount in <String?>['reader-b', null]) {
    test('queued Library progress retains its owner after '
        '${nextAccount == null ? 'logout' : 'account change'}', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      String? account = 'reader-a';
      final remote = _HeldProgressRemote();
      final store = LibraryReadProgressStore(
        prefs: prefs,
        currentUserIdProvider: () => account,
        remote: remote,
      );
      final opened = store.recordOpened('rekh_wer');
      await remote.started.future;
      final bookmark = store.setBookmark(
        nodeId: 'rekh_wer',
        progressPercent: 20,
        scrollOffset: 125,
      );
      final exited = store.saveScrollProgress(
        nodeId: 'rekh_wer',
        progressPercent: 40,
        lastScrollOffset: 250,
      );
      account = nextAccount;
      remote.release.complete();
      await Future.wait([opened, bookmark, exited]);

      expect(remote.owners, ['reader-a', 'reader-a', 'reader-a']);
      expect(prefs.getString('library_node_read_progress_v2:reader-b'), isNull);
      expect(prefs.getString('library_node_read_progress_v2:local'), isNull);
      final stored =
          jsonDecode(prefs.getString('library_node_read_progress_v2:reader-a')!)
              as Map;
      final progress = LibraryNodeProgress.fromJson(stored['rekh_wer'])!;
      expect(progress.lastScrollOffset, 250);
      expect(progress.bookmarkScrollOffset, 125);
      expect(progress.isBookmarked, isTrue);
    });
  }
}

class _HeldProgressRemote implements LibraryReadProgressRemote {
  final started = Completer<void>();
  final release = Completer<void>();
  final owners = <String>[];
  @override
  Future<List<LibraryNodeProgress>> fetchAll({required String userId}) async =>
      [];
  @override
  Future<LibraryNodeProgress?> upsert({
    required String userId,
    required LibraryNodeProgress progress,
  }) async {
    owners.add(userId);
    if (!started.isCompleted) {
      started.complete();
      await release.future;
    }
    return progress;
  }
}
