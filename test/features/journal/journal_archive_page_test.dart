import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/journal_repo.dart';
import 'package:mobile/features/journal/journal_archive_page.dart';
import 'package:mobile/features/journal/journal_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> _ensureSupabaseInitialized() async {
  try {
    Supabase.instance.client;
    return;
  } catch (_) {}

  await Supabase.initialize(
    url: 'https://example.supabase.co',
    anonKey: 'anon-key-0123456789012345678901234567890123456789',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await _ensureSupabaseInitialized();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('archive edit view keeps text editor usable above keyboard', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(tester.view.reset);

    final entry = _entry(
      body: List<String>.generate(
        12,
        (index) => 'Archive line ${index + 1}',
      ).join('\n'),
    );
    final repo = _ArchiveRepo(entry);
    final controller = JournalController.withRepo(
      repo,
      currentUserId: () => 'user-a',
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: JournalArchivePage(
          repo: repo,
          controller: controller,
          isPortrait: true,
          onClose: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Archive line 1').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('No badges for this entry'), findsNothing);

    final editorRect = tester.getRect(find.byType(TextField));
    expect(editorRect.height, greaterThanOrEqualTo(160));
    expect(editorRect.bottom, lessThanOrEqualTo(524));
    expect(tester.takeException(), isNull);
  });
}

JournalEntry _entry({required String body}) {
  final date = DateTime(2026, 5, 23);
  return JournalEntry(
    id: 'entry-1',
    userId: 'user-a',
    gregDate: date,
    body: body,
    meta: const {},
    category: null,
    createdAt: date,
    updatedAt: date,
  );
}

class _ArchiveRepo extends JournalRepo {
  _ArchiveRepo(this.entry)
    : super(
        SupabaseClient(
          'https://example.com',
          'test-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  final JournalEntry entry;

  @override
  Future<List<JournalEntry>> listRecent({int days = 30}) async => [entry];

  @override
  Future<JournalEntry?> getByDate(DateTime localDate) async => entry;

  @override
  Future<void> upsert({
    required DateTime localDate,
    required String body,
    Map<String, dynamic>? meta,
    String? category,
  }) async {}
}
