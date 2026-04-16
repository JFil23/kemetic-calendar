import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/journal/journal_controller.dart';
import 'package:mobile/features/journal/journal_overlay.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('badge section stays anchored when the keyboard opens', (
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
      _JournalHarness(
        controller: controller,
        bottomInset: 0,
      ),
    );
    await tester.pumpAndSettle();

    final before = tester.getTopLeft(find.text('Badges')).dy;

    await tester.pumpWidget(
      _JournalHarness(
        controller: controller,
        bottomInset: 320,
      ),
    );
    await tester.pumpAndSettle();

    final after = tester.getTopLeft(find.text('Badges')).dy;
    expect(after, closeTo(before, 0.1));
  });
}

class _JournalHarness extends StatelessWidget {
  const _JournalHarness({
    required this.controller,
    required this.bottomInset,
  });

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
