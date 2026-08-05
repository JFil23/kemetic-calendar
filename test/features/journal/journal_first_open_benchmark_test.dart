import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/journal_repo.dart';
import 'package:mobile/features/journal/journal_controller.dart';
import 'package:mobile/features/journal/journal_v2_document_model.dart';
import 'package:mobile/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.test',
      anonKey: 'test-anon-key',
    );
  });

  testWidgets('measures ordinary Journal first usable paint', (tester) async {
    final results = <int>[];

    for (var run = 0; run < 5; run += 1) {
      final today = DateTime.now();
      final dateKey =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      SharedPreferences.setMockInitialValues({
        'journal:user:user-a:lastOpenDay': dateKey,
        'journal:user:user-a:document:$dateKey': jsonEncode(
          JournalDocument.fromPlainText(
            'Existing cached journal text.',
          ).toJson(),
        ),
      });

      final controller = JournalController.withRepo(
        _TenSecondJournalRepo(),
        currentUserId: () => 'user-a',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: app.JournalRoutePage(controllerForTesting: controller),
        ),
      );

      var elapsedMs = 0;
      while (find.text('JOURNAL').evaluate().isEmpty && elapsedMs < 12000) {
        await tester.pump(const Duration(milliseconds: 100));
        elapsedMs += 100;
      }
      results.add(elapsedMs);
      expect(find.text('JOURNAL'), findsOneWidget);

      final remainingMs = 10000 - elapsedMs;
      if (remainingMs > 0) {
        await tester.pump(Duration(milliseconds: remainingMs));
      }
      await tester.pump();
      expect(controller.currentDraft, 'Existing cached journal text.');
      expect(
        find.textContaining('Existing cached journal text.'),
        findsWidgets,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      await tester.pump(const Duration(milliseconds: 500));
    }

    // ignore: avoid_print
    print('JOURNAL_FIRST_OPEN_MS=${jsonEncode(results)}');
  });
}

class _TenSecondJournalRepo extends JournalRepo {
  _TenSecondJournalRepo()
    : super(
        SupabaseClient(
          'https://example.test',
          'test-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  @override
  Future<JournalEntry?> getByDateStrict(DateTime localDate) async {
    await Future<void>.delayed(const Duration(seconds: 10));
    return null;
  }
}
