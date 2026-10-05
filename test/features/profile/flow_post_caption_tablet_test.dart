import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/data/flow_appearance.dart';
import 'package:mobile/features/profile/flow_post_caption_sheet.dart';
import 'package:mobile/features/profile/posted_flow_artifact.dart';
import 'package:mobile/widgets/kemetic_keyboard.dart';

void main() {
  const caption = 'A practice I just created on my iPad.';
  const field = ValueKey<String>('flow-post-caption-field');
  const submit = ValueKey<String>('flow-post-caption-submit');

  for (final size in const [Size(820, 1180), Size(1180, 820)]) {
    testWidgets('iPad caption can submit above the keyboard at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      String? result;
      await _pumpComposer(tester, onResult: (value) => result = value);
      await tester.tap(find.text('Open composer'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(field), caption);
      tester.view.viewInsets = const FakeViewPadding(bottom: 350);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(submit));
      await tester.pumpAndSettle();
      final button = tester.getRect(find.byKey(submit));
      expect(button.bottom, lessThanOrEqualTo(size.height - 350));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(submit));
      await tester.pumpAndSettle();
      expect(result, caption);
      expect(find.byKey(field), findsNothing);
    });
  }

  const phoneCaption = 'A practice I just created on my phone.';
  const phonePortraits = [
    (size: Size(375, 667), keyboard: 300.0, landscapeKeyboard: 216.0),
    (size: Size(390, 844), keyboard: 336.0, landscapeKeyboard: 216.0),
    (size: Size(430, 932), keyboard: 346.0, landscapeKeyboard: 226.0),
  ];

  for (final viewport in [
    for (final phone in phonePortraits)
      (size: phone.size, keyboard: phone.keyboard),
    (size: const Size(844, 390), keyboard: 216.0),
  ]) {
    testWidgets(
      'phone caption can submit above the keyboard at ${viewport.size}',
      (tester) async {
        tester.view.physicalSize = viewport.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        String? result;
        await _pumpComposer(tester, onResult: (value) => result = value);
        await tester.tap(find.text('Open composer'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(field), phoneCaption);
        tester.view.viewInsets = FakeViewPadding(bottom: viewport.keyboard);
        await tester.pumpAndSettle();
        await _expectSubmitReachable(tester, viewport.size, viewport.keyboard);
        await tester.tap(find.byKey(submit));
        await tester.pumpAndSettle();
        expect(result, phoneCaption);
        expect(find.byKey(field), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final phone in phonePortraits) {
    testWidgets(
      'phone caption draft and submit survive keyboard rotation at ${phone.size}',
      (tester) async {
        tester.view.physicalSize = phone.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        String? result;
        await _pumpComposer(tester, onResult: (value) => result = value);
        await tester.tap(find.text('Open composer'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(field), phoneCaption);
        tester.view.viewInsets = FakeViewPadding(bottom: phone.keyboard);
        await tester.pumpAndSettle();

        final landscape = Size(phone.size.height, phone.size.width);
        tester.view.physicalSize = landscape;
        tester.view.viewInsets = FakeViewPadding(
          bottom: phone.landscapeKeyboard,
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byKey(field)).controller!.text,
          phoneCaption,
        );
        await _expectSubmitReachable(
          tester,
          landscape,
          phone.landscapeKeyboard,
        );

        tester.view.physicalSize = phone.size;
        tester.view.viewInsets = FakeViewPadding(bottom: phone.keyboard);
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byKey(field)).controller!.text,
          phoneCaption,
        );
        await _expectSubmitReachable(tester, phone.size, phone.keyboard);
        await tester.tap(find.byKey(submit));
        await tester.pumpAndSettle();
        expect(result, phoneCaption);
        expect(find.byKey(field), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('caption draft and submit survive iPad rotation with keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    String? result;
    await _pumpComposer(tester, onResult: (value) => result = value);
    await tester.tap(find.text('Open composer'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(field), caption);
    tester.view.viewInsets = const FakeViewPadding(bottom: 350);
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(1180, 820);
    await tester.pumpAndSettle();
    final input = tester.widget<TextField>(find.byKey(field));
    expect(input.controller!.text, caption);
    await tester.ensureVisible(find.byKey(submit));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(submit)).bottom, lessThanOrEqualTo(470));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(submit));
    await tester.pumpAndSettle();
    expect(result, caption);
  });
}

Future<void> _expectSubmitReachable(
  WidgetTester tester,
  Size viewport,
  double keyboard,
) async {
  final submit = find.byKey(const ValueKey<String>('flow-post-caption-submit'));
  await tester.ensureVisible(submit);
  await tester.pumpAndSettle();
  final button = tester.getRect(submit);
  expect(button.top, greaterThanOrEqualTo(0));
  expect(button.bottom, lessThanOrEqualTo(viewport.height - keyboard));
  expect(button.left, greaterThanOrEqualTo(0));
  expect(button.right, lessThanOrEqualTo(viewport.width));
  expect(submit.hitTestable(), findsOneWidget);
  expect(tester.takeException(), isNull);
}

Future<void> _pumpComposer(
  WidgetTester tester, {
  required ValueChanged<String?> onResult,
}) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.dark,
    builder: (_, child) => KemeticKeyboardHost(child: child!),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () async {
              onResult(
                await showFlowPostCaptionSheet(
                  context: context,
                  actionLabel: 'Post flow',
                  preview: const PostedFlowArtifact(
                    name: 'Newly created practice',
                    color: 0xff6f93a8,
                    appearance: FlowAppearance.empty,
                    allowImageFetch: false,
                  ),
                ),
              );
            },
            child: const Text('Open composer'),
          ),
        ),
      ),
    ),
  ),
);
