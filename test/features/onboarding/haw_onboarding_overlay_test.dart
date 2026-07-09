import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/onboarding/decan_compass_copy_repo.dart';
import 'package:mobile/features/onboarding/onboarding_overlay.dart';

const Color _readableOnboardingGhost = Color(0xFF746440);
const Color _wordmarkEmphasis = Color(0xFF8A7A58);

void main() {
  HawCompassCopy compassCopy() {
    return const HawCompassCopy(
      decanKey: 'm03_d3',
      dateLabel: 'Hathor 27',
      decanName: 'Sb: Sṯḥ',
      decanOrdinalLabel: 'third',
      monthName: 'Hathor',
      rhythmPhrase:
          'Sb: Sṯḥ centers on the settling of what the flood brought.',
      orientationQuestion: 'What remains when the water recedes?',
      dayAlignedReturnKey: 'settle_after_flood',
    );
  }

  testWidgets('runs slide 1 through slide 6 in one overlay sequence', (
    tester,
  ) async {
    final slides = <HawOnboardingSlide>[];
    final selectedStates = <String>[];
    var joinedFlow = false;
    var completed = false;
    final eventKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingOverlay(
          compassCopy: compassCopy(),
          dayViewEventTargetKey: eventKey,
          onSlideChanged: slides.add,
          onEntryStateSelected: (entryState) async {
            selectedStates.add(entryState);
          },
          onSkip: () {},
          onComplete: () {
            completed = true;
          },
          recommendedFlowBuilder: (context, onJoined) {
            return Center(
              child: ElevatedButton(
                onPressed: () async {
                  joinedFlow = true;
                  await onJoined(42);
                },
                child: const Text('Join Flow'),
              ),
            );
          },
          dayViewBuilder: (context, onEventOpened, onClosingComplete) {
            return Center(
              child: ElevatedButton(
                key: eventKey,
                onPressed: onEventOpened,
                child: const Text('The Return'),
              ),
            );
          },
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 6));
    expect(find.text('tap to begin'), findsOneWidget);
    expect(_textColor(tester, 'skip'), _readableOnboardingGhost);
    expect(_textColor(tester, 'tap to begin'), _readableOnboardingGhost);
    final openingWordmark = _textSpanForPlainText(tester, 'this is ḥꜣw');
    expect(openingWordmark.text, 'this is ');
    expect(openingWordmark.style?.color, _readableOnboardingGhost);
    expect(openingWordmark.style?.fontWeight, FontWeight.w300);
    final hawSpan = openingWordmark.children?.single as TextSpan;
    expect(hawSpan.text, 'ḥꜣw');
    expect(hawSpan.style?.color, _wordmarkEmphasis);
    expect(hawSpan.style?.fontWeight, FontWeight.w400);
    await tester.tap(find.text('tap to begin'));
    await tester.pumpAndSettle();

    await tester.pump(const Duration(milliseconds: 900));
    await tester.tap(find.text('I need focus'));
    await tester.pump(const Duration(milliseconds: 700));
    expect(selectedStates, <String>['focus']);

    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Today is Hathor 27'), findsOneWidget);
    expect(_richTextContaining('What has been deposited.'), findsOneWidget);
    expect(
      slides,
      containsAllInOrder(<HawOnboardingSlide>[
        HawOnboardingSlide.exhale,
        HawOnboardingSlide.segmentation,
        HawOnboardingSlide.orientation,
      ]),
    );
    expect(_textColor(tester, 'next'), _readableOnboardingGhost);
    await tester.tap(find.text('next'));
    await tester.pumpAndSettle();

    expect(find.text('Recommended First Flow'), findsOneWidget);
    await tester.tap(find.text('Join Flow'));
    await tester.pumpAndSettle();
    expect(joinedFlow, isTrue);

    expect(find.text('The Return'), findsOneWidget);
    await tester.tap(find.text('The Return'));
    await tester.pumpAndSettle();

    expect(slides, containsAll(HawOnboardingSlide.values));
    expect(completed, isFalse);
  });

  testWidgets('skip exits without joining the recommended flow', (
    tester,
  ) async {
    var skipped = false;
    var joinedFlow = false;
    final eventKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingOverlay(
          compassCopy: compassCopy(),
          dayViewEventTargetKey: eventKey,
          onEntryStateSelected: (_) async {},
          onSkip: () {
            skipped = true;
          },
          onComplete: () {},
          recommendedFlowBuilder: (context, onJoined) {
            return TextButton(
              onPressed: () async {
                joinedFlow = true;
                await onJoined(42);
              },
              child: const Text('Join Flow'),
            );
          },
          dayViewBuilder: (context, onEventOpened, onClosingComplete) {
            return SizedBox(key: eventKey);
          },
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 6));
    await tester.tap(find.text('skip'));
    await tester.pump();

    expect(skipped, isTrue);
    expect(joinedFlow, isFalse);
  });

  testWidgets('closing copy is removed before seal appears', (tester) async {
    final phases = <HawClosingPhase>[];
    var completed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: HawOnboardingClosingBanner(
              onPhaseChanged: phases.add,
              onComplete: () {
                completed = true;
              },
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.textContaining('At the end of the day'), findsOneWidget);
    expect(find.text('this is ḥꜣw'), findsNothing);

    await tester.tap(find.text('×'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.textContaining('At the end of the day'), findsOneWidget);
    expect(find.text('this is ḥꜣw'), findsNothing);

    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('At the end of the day'), findsNothing);
    expect(find.text('this is ḥꜣw'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    expect(completed, isTrue);
    expect(
      phases,
      containsAllInOrder(<HawClosingPhase>[
        HawClosingPhase.copyVisible,
        HawClosingPhase.copyFadingOut,
        HawClosingPhase.sealFadingIn,
        HawClosingPhase.sealHolding,
        HawClosingPhase.windowFadingOut,
        HawClosingPhase.complete,
      ]),
    );
  });

  test('Hathor third decan fallback keeps the orientation copy', () {
    final copy = DecanCompassCopyRepo.fallbackForDay(kMonth: 3, kDay: 27);

    expect(copy.decanKey, 'm03_d3');
    expect(copy.decanName, 'Sb: Sṯḥ');
    expect(
      copy.rhythmPhrase,
      'Sb: Sṯḥ centers on the settling of what the flood brought.',
    );
    expect(copy.orientationQuestion, 'What remains when the water recedes?');
    expect(copy.dayAlignedReturnKey, 'settle_after_flood');
  });

  test('compass fallback covers all 365 Kemetic days', () {
    final decanKeys = <String>{};

    for (var month = 1; month <= 12; month += 1) {
      for (var day = 1; day <= 30; day += 1) {
        final copy = DecanCompassCopyRepo.fallbackForDay(
          kMonth: month,
          kDay: day,
        );
        decanKeys.add(copy.decanKey);
        expect(copy.dateLabel, isNotEmpty);
        expect(copy.rhythmPhrase, isNotEmpty);
        expect(copy.orientationQuestion, isNotEmpty);
        expect(copy.dayAlignedReturnKey, isNot('return_to_attention'));
      }
    }

    for (var day = 1; day <= 5; day += 1) {
      final copy = DecanCompassCopyRepo.fallbackForDay(kMonth: 13, kDay: day);
      decanKeys.add(copy.decanKey);
      expect(copy.dateLabel, isNotEmpty);
      expect(copy.rhythmPhrase, isNotEmpty);
      expect(copy.orientationQuestion, isNotEmpty);
      expect(copy.dayAlignedReturnKey, 'guard_threshold');
    }

    expect(decanKeys.length, 37);
  });
}

Finder _richTextContaining(String text) {
  return find.byWidgetPredicate((widget) {
    return widget is RichText && widget.text.toPlainText().contains(text);
  });
}

TextSpan _textSpanForPlainText(WidgetTester tester, String text) {
  final richText = tester.widget<RichText>(
    find.byWidgetPredicate((widget) {
      return widget is RichText && widget.text.toPlainText() == text;
    }),
  );
  return richText.text as TextSpan;
}

Color? _textColor(WidgetTester tester, String text) {
  return tester.widget<Text>(find.text(text)).style?.color;
}
