import 'package:mobile/features/calendar/calendar_period_descriptions.dart';
import 'package:flutter/material.dart';
import 'package:mobile/features/onboarding/starter_maat_flow_recommendation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/onboarding/decan_compass_copy_repo.dart';
import 'package:mobile/features/onboarding/onboarding_overlay.dart';

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

  testWidgets('runs the seven slides in one overlay sequence', (tester) async {
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
    await tester.tap(find.text('tap to begin'));
    await tester.pumpAndSettle();

    expect(find.text('Bring your time with you.'), findsOneWidget);
    await tester.tap(find.text('not now'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.tap(find.text(HawEntryIntent.sky.label));
    await tester.pump(const Duration(milliseconds: 700));
    expect(selectedStates, <String>['sky']);

    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Today is Hathor 27'), findsOneWidget);
    expect(_richTextContaining('ḥꜣw’s interpretation:'), findsOneWidget);
    expect(
      _richTextContaining(decanInterpretationForKey('m03_d3')!.body),
      findsOneWidget,
    );
    expect(
      slides,
      containsAllInOrder(<HawOnboardingSlide>[
        HawOnboardingSlide.exhale,
        HawOnboardingSlide.calendarConnection,
        HawOnboardingSlide.segmentation,
        HawOnboardingSlide.orientation,
      ]),
    );
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

  for (final day in [1, 10, 11, 19, 20, 21, 30]) {
    testWidgets('orientation describes the decan containing day $day', (
      tester,
    ) async {
      final copy = DecanCompassCopyRepo.fallbackForDay(kMonth: 7, kDay: day);
      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingOverlay(
            initialSlide: HawOnboardingSlide.orientation,
            compassCopy: copy,
            dayViewEventTargetKey: GlobalKey(),
            recommendedFlowBuilder: (_, _) => const SizedBox(),
            dayViewBuilder: (_, _, _) => const SizedBox(),
            onEntryStateSelected: (_) async {},
            onSkip: () {},
            onComplete: () {},
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 4));
      final ordinal = day <= 10
          ? 'first'
          : day <= 20
          ? 'second'
          : 'third';
      expect(find.text('Today is Rekh-Nedjes $day'), findsOneWidget);
      expect(
        _richTextContaining('the $ordinal decan of Rekh-Nedjes.'),
        findsOneWidget,
      );
      expect(_richTextContaining('ḥꜣw’s interpretation:'), findsOneWidget);
      final description = decanInterpretationForKey(copy.decanKey)!;
      expect(_richTextContaining(description.theme), findsOneWidget);
      expect(_richTextContaining(description.body), findsOneWidget);
      expect(_richTextContaining(copy.orientationQuestion), findsNothing);
      expect(_richTextContaining('Phamenoth'), findsNothing);
      expect(_richTextContaining(copy.decanName), findsNothing);
      expect(_richTextContaining('centers on'), findsNothing);
    });
  }

  test('all decans reuse the existing period descriptions', () {
    for (var month = 1; month <= 12; month++) {
      for (var decan = 1; decan <= 3; decan++) {
        final key = 'm${month.toString().padLeft(2, '0')}_d$decan';
        final description = decanInterpretationForKey(key)!;
        final existing = calendarDecanDescriptions[(month - 1) * 3 + decan - 1];
        expect(description.theme, isNotEmpty);
        expect(description.body, isNotEmpty);
        expect(existing, contains(description.theme));
        expect(existing, contains(description.body));
        for (var day = (decan - 1) * 10 + 1; day <= decan * 10; day++) {
          final copy = DecanCompassCopyRepo.fallbackForDay(
            kMonth: month,
            kDay: day,
          );
          expect(decanInterpretationForKey(copy.decanKey), description);
        }
      }
    }
    final extraDays = decanInterpretationForKey('epagomenal')!;
    expect(calendarMonthDescriptions[13], contains(extraDays.body));
    expect(decanInterpretationForKey('m13_d1'), isNull);
    expect(decanInterpretationForKey('m07_d4'), isNull);
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
