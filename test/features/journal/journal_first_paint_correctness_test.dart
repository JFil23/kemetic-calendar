import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/daily_reflection_question.dart';
import 'package:mobile/data/journal_repo.dart';
import 'package:mobile/features/journal/journal_controller.dart';
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

  testWidgets(
    'ordinary Journal first paint does not present an unresolved reflection',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repo = _DelayedJournalRepo();
      final controller = JournalController.withRepo(
        repo,
        currentUserId: () => 'user-a',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: app.JournalRoutePage(controllerForTesting: controller),
        ),
      );
      await tester.pump();
      await repo.requested.future;

      expect(find.text('JOURNAL'), findsOneWidget);
      final unresolvedQuestion = dailyReflectionQuestionForDate(DateTime.now());
      expect(unresolvedQuestion, isNotNull);
      final firstPaintField = tester.widget<TextField>(find.byType(TextField));
      expect(firstPaintField.decoration?.hintText, 'Write your day…');
      expect(
        firstPaintField.decoration?.hintText,
        isNot(unresolvedQuestion!.question),
      );

      repo.completeWith(_entry('Correct current journal entry.'));
      await tester.pumpAndSettle();

      expect(controller.currentDraft, 'Correct current journal entry.');
      expect(
        find.textContaining('Correct current journal entry.'),
        findsWidgets,
      );
    },
  );
}

JournalEntry _entry(String body) {
  final now = DateTime.now();
  return JournalEntry(
    id: 'entry-today',
    userId: 'user-a',
    gregDate: DateTime(now.year, now.month, now.day),
    body: body,
    meta: const <String, dynamic>{},
    category: null,
    createdAt: now,
    updatedAt: now,
  );
}

class _DelayedJournalRepo extends JournalRepo {
  _DelayedJournalRepo()
    : super(
        SupabaseClient(
          'https://example.test',
          'test-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  final requested = Completer<void>();
  final _response = Completer<JournalEntry?>();

  void completeWith(JournalEntry? entry) => _response.complete(entry);

  @override
  Future<JournalEntry?> getByDateStrict(DateTime localDate) {
    if (!requested.isCompleted) requested.complete();
    return _response.future;
  }
}
