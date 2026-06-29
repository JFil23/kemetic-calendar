import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/journal_repo.dart';
import 'package:mobile/features/journal/journal_archive_page.dart';
import 'package:mobile/features/journal/journal_controller.dart';
import 'package:mobile/features/journal/journal_empty_badge_glyph.dart';
import 'package:mobile/features/reflections/decan_reflection_skin.dart';
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

  testWidgets('archive keeps date toggle, metadata, rows, and Decan skin', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    final entry = _entry(body: 'x');
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

    expect(find.byKey(journalArchiveReflectionSkinKey), findsOneWidget);
    expect(find.byType(DecanTrack), findsWidgets);
    expect(find.byKey(journalArchiveDateModeToggleKey), findsOneWidget);
    expect(find.text('Kemetic'), findsOneWidget);
    expect(find.text('Gregorian'), findsOneWidget);
    expect(find.text('x'), findsOneWidget);
    expect(find.text('1 characters'), findsOneWidget);

    await tester.tap(find.text('Gregorian'));
    await tester.pumpAndSettle();

    expect(find.text('Saturday, May 23'), findsOneWidget);
    expect(find.text('1 characters'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('archive empty badge section shows receiving-hand glyph only', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    final entry = _entry(body: 'Archive empty badge entry');
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

    await tester.tap(find.textContaining('Archive empty badge entry').first);
    await tester.pumpAndSettle();

    expect(find.byType(JournalEmptyBadgeGlyph), findsOneWidget);
    expect(find.text(kJournalEmptyBadgeGlyph), findsOneWidget);
    final glyph = tester.widget<JournalEmptyBadgeGlyph>(
      find.byType(JournalEmptyBadgeGlyph),
    );
    expect(glyph.width, 156);
    expect(glyph.height, 52);
    expect(glyph.fontSize, 52);
    expect(
      find.descendant(
        of: find.byType(JournalEmptyBadgeGlyph),
        matching: find.text(kJournalEmptyBadgeGlyph),
      ),
      findsOneWidget,
    );
    expect(find.text('No badges for this entry'), findsNothing);
    expect(find.text('No badges yet'), findsNothing);
    expect(
      find.text('Event badges you add from day view will appear here.'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('archive row still opens the existing entry detail/editor flow', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    final entry = _entry(body: 'Archive row opens detail');
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

    await tester.tap(find.textContaining('Archive row opens detail').first);
    await tester.pumpAndSettle();

    expect(find.text('Journal Entry'), findsOneWidget);
    expect(find.text('ENTRY FOR'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Save'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('archive close button still calls existing onClose callback', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    final repo = _ArchiveRepo(_entry(body: 'Close callback entry'));
    final controller = JournalController.withRepo(
      repo,
      currentUserId: () => 'user-a',
    );
    addTearDown(controller.dispose);

    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: JournalArchivePage(
          repo: repo,
          controller: controller,
          isPortrait: true,
          onClose: () => closed = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Close archive'));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('archive swipe-delete still calls repo delete and removes row', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    final entry = _entry(body: 'Swipe delete entry');
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

    expect(find.text('Swipe delete entry'), findsOneWidget);

    await tester.drag(find.text('Swipe delete entry'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(repo.deletedDates, contains(entry.gregDate));
    expect(find.text('Swipe delete entry'), findsNothing);
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
  _ArchiveRepo(JournalEntry entry)
    : super(
        SupabaseClient(
          'https://example.com',
          'test-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      ) {
    entries.add(entry);
  }

  final entries = <JournalEntry>[];
  final deletedDates = <DateTime>[];

  @override
  Future<List<JournalEntry>> listRecent({int days = 30}) async =>
      List<JournalEntry>.of(entries);

  @override
  Future<JournalEntry?> getByDate(DateTime localDate) async {
    for (final entry in entries) {
      if (DateUtils.isSameDay(entry.gregDate, localDate)) return entry;
    }
    return null;
  }

  @override
  Future<void> upsert({
    required DateTime localDate,
    required String body,
    Map<String, dynamic>? meta,
    String? category,
  }) async {}

  @override
  Future<void> deleteByDate(DateTime localDate) async {
    deletedDates.add(localDate);
    entries.removeWhere(
      (entry) => DateUtils.isSameDay(entry.gregDate, localDate),
    );
  }
}
