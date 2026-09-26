import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/inbox/presentation/group_flow_inbox_preview_section.dart';

void main() {
  Future<void> pumpPreview(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Color(0xFF0D0B07),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: GroupFlowInboxPreviewSection(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('accepting the second member opens local group policy', (
    tester,
  ) async {
    await pumpPreview(tester);

    expect(
      find.byKey(const ValueKey<String>('group-flow-inbox-request')),
      findsOneWidget,
    );
    expect(find.text('UI PREVIEW'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('group-flow-inbox-request-accept')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('group-flow-second-member-policy')),
      findsOneWidget,
    );
    expect(find.text('Amina joined your flow'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('group-flow-visibility-public')),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('group-flow-request-audience-nobody')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('group-flow-public-closed-note')),
      findsOneWidget,
    );

    final save = find.byKey(const ValueKey<String>('group-flow-policy-save'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump();
    expect(find.text('Settings saved locally · UI preview'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('declined preview request can be restored', (tester) async {
    await pumpPreview(tester);

    await tester.tap(
      find.byKey(const ValueKey<String>('group-flow-inbox-request-decline')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('group-flow-inbox-request-declined')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('group-flow-request-undo')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('group-flow-inbox-request')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
