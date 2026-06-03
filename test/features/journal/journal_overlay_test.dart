import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/journal_repo.dart';
import 'package:mobile/features/journal/journal_controller.dart';
import 'package:mobile/features/journal/journal_overlay.dart';
import 'package:mobile/features/journal/journal_v2_toolbar.dart';
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

  testWidgets('badge section and toolbar stay visible while keyboard is open', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() async {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final client = SupabaseClient(
      'https://example.com',
      'test-anon-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    final controller = JournalController(client);

    await tester.pumpWidget(
      _JournalHarness(controller: controller, bottomInset: 0),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Badges'), findsOneWidget);
    expect(find.byType(JournalV2Toolbar), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_hide), findsNothing);

    await tester.pumpWidget(
      _JournalHarness(controller: controller, bottomInset: 320),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Badges'), findsOneWidget);
    expect(find.byType(JournalV2Toolbar), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_hide), findsOneWidget);

    await tester.pumpWidget(
      _JournalHarness(controller: controller, bottomInset: 0),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Badges'), findsOneWidget);
    expect(find.byType(JournalV2Toolbar), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_hide), findsNothing);
  });

  testWidgets('typing does not show sync pending banner', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() async {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final controller = JournalController.withRepo(
      _NoopJournalRepo(),
      currentUserId: () => 'user-a',
    );
    await controller.updateDraft('Unsaved local text');

    await tester.pumpWidget(
      _JournalHarness(controller: controller, bottomInset: 320),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(controller.syncStatus, JournalSyncStatus.unsavedLocal);
    expect(find.textContaining('Sync pending'), findsNothing);
    expect(find.textContaining('Saved on this device'), findsNothing);

    await controller.forceSave();
  });

  testWidgets('page journal text field accepts focus and typed input', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() async {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final controller = JournalController.withRepo(
      _NoopJournalRepo(),
      currentUserId: () => 'user-a',
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _JournalHarness(controller: controller, bottomInset: 0),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final fieldFinder = find.byType(TextField);
    expect(fieldFinder, findsOneWidget);

    await tester.tap(fieldFinder);
    await tester.pump();

    final field = tester.widget<TextField>(fieldFinder);
    expect(field.readOnly, isFalse);
    expect(field.enabled, isNot(false));
    expect(field.focusNode?.hasFocus, isTrue);

    await tester.enterText(fieldFinder, 'Today I can write.');
    await tester.pump();

    expect(controller.currentDraft, 'Today I can write.');
    expect(field.focusNode?.hasFocus, isTrue);

    await controller.forceSave();
  });
}

class _NoopJournalRepo extends JournalRepo {
  _NoopJournalRepo()
    : super(
        SupabaseClient(
          'https://example.com',
          'test-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  @override
  Future<void> upsert({
    required DateTime localDate,
    required String body,
    Map<String, dynamic>? meta,
    String? category,
  }) async {}
}

class _JournalHarness extends StatelessWidget {
  const _JournalHarness({required this.controller, required this.bottomInset});

  final JournalController controller;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQueryData(
        size: const Size(390, 844),
        viewInsets: EdgeInsets.only(bottom: bottomInset),
      ),
      child: MaterialApp(
        home: JournalOverlay(
          controller: controller,
          isPortrait: true,
          onClose: () {},
          presentationMode: JournalPresentationMode.page,
        ),
      ),
    );
  }
}
