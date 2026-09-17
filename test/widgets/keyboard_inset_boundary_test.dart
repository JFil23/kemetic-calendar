import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/presentation/instrument_event_presentation_frame.dart';
import 'package:mobile/widgets/keyboard_aware.dart';
import 'package:mobile/widgets/kemetic_keyboard.dart';
import 'package:mobile/widgets/keyboard_viewport_metrics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('remaining-occlusion keyboard contract', () {
    testWidgets('native: boundary consumes raw inset; host remaining is 0', (
      tester,
    ) async {
      await _pumpBoundaryStack(
        tester,
        size: const Size(390, 844),
        rawInset: 344,
        resolver: (media) => KeyboardViewportMetrics.resolve(media: media),
      );

      expect(_ownerPad(tester), 344);
      expect(_innerRemaining(tester), 0);
      expect(_innerViewInsets(tester), 0);
    });

    testWidgets(
      'PWA layout-sized: boundary consumes resolver occlusion when raw is 0',
      (tester) async {
        await _pumpBoundaryStack(
          tester,
          size: const Size(390, 844),
          rawInset: 0,
          resolver: (media) => KeyboardViewportMetrics.resolve(
            media: media,
            webViewport: const (height: 500, layoutHeight: 844, offsetTop: 0),
          ),
        );

        expect(_ownerPad(tester), 344);
        expect(_innerRemaining(tester), 0);
        expect(_innerViewInsets(tester), 0);
      },
    );

    testWidgets('PWA visual-sized: remaining system inset stays 0', (
      tester,
    ) async {
      await _pumpBoundaryStack(
        tester,
        size: const Size(390, 500),
        rawInset: 0,
        resolver: (media) => KeyboardViewportMetrics.resolve(
          media: media,
          webViewport: const (height: 500, layoutHeight: 844, offsetTop: 0),
        ),
      );

      expect(_ownerPad(tester), 0);
      expect(_innerRemaining(tester), 0);
    });

    testWidgets('PWA pan: remaining is the layout-sized bottom occlusion', (
      tester,
    ) async {
      await _pumpBoundaryStack(
        tester,
        size: const Size(390, 844),
        rawInset: 0,
        resolver: (media) => KeyboardViewportMetrics.resolve(
          media: media,
          webViewport: const (height: 500, layoutHeight: 844, offsetTop: 100),
        ),
      );

      expect(_ownerPad(tester), 244);
      expect(_innerRemaining(tester), 0);
    });

    testWidgets(
      'transitional raw inset: visual-sized resolver wins over stale viewInsets',
      (tester) async {
        await _pumpBoundaryStack(
          tester,
          size: const Size(390, 524),
          rawInset: 320,
          resolver: (media) => KeyboardViewportMetrics.resolve(
            media: media,
            webViewport: const (height: 524, layoutHeight: 844, offsetTop: 120),
          ),
        );

        expect(_ownerPad(tester), 0);
        expect(_innerRemaining(tester), 0);
        expect(_innerViewInsets(tester), 0);
      },
    );

    testWidgets(
      'custom keyboard: system boundary leaves custom inset for descendants',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        late double remainingAfterBoundary;
        await tester.pumpWidget(
          MaterialApp(
            home: KemeticKeyboardScope(
              isCustomKeyboardVisible: true,
              customKeyboardInset: 300,
              systemKeyboardInset: 0,
              keyboardInset: 300,
              visibleTop: 0,
              visibleBottom: 844,
              isSystemKeyboardVisible: false,
              child: KeyboardInsetBoundary(
                child: Builder(
                  builder: (context) {
                    remainingAfterBoundary = keyboardInsetOf(context);
                    return const SizedBox.expand();
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(remainingAfterBoundary, 300);
      },
    );

    testWidgets('custom keyboard is consumed once by the sheet host', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      late double remainingInsideHost;
      await tester.pumpWidget(
        MaterialApp(
          home: KemeticKeyboardScope(
            isCustomKeyboardVisible: true,
            customKeyboardInset: 300,
            systemKeyboardInset: 0,
            keyboardInset: 300,
            visibleTop: 0,
            visibleBottom: 844,
            isSystemKeyboardVisible: false,
            child: InstrumentEventSheetHost(
              semanticLabel: 'Resize test sheet',
              handleColor: Colors.white,
              body: Builder(
                builder: (context) {
                  remainingInsideHost = keyboardInsetOf(context);
                  return const SizedBox.expand();
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(remainingInsideHost, 0);
    });
  });
}

Future<void> _pumpBoundaryStack(
  WidgetTester tester, {
  required Size size,
  required double rawInset,
  required KeyboardViewportMetricsResolver resolver,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.viewInsets = FakeViewPadding(bottom: rawInset);
  addTearDown(tester.view.reset);
  _InnerProbe.lastInsetHolder.value = -1;

  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => KemeticKeyboardHost(
        viewportMetricsResolver: resolver,
        child: child ?? const SizedBox.shrink(),
      ),
      home: KeyboardInsetBoundary(
        paddingKey: editableModalSystemInsetOwnerKey,
        child: InstrumentEventSheetHost(
          semanticLabel: 'Resize test sheet',
          handleColor: Colors.white,
          body: const _InnerProbe(),
        ),
      ),
    ),
  );
  await tester.pump();
}

double _ownerPad(WidgetTester tester) {
  final owner = tester.widget<Padding>(
    find.byKey(editableModalSystemInsetOwnerKey),
  );
  return (owner.padding as EdgeInsets).bottom;
}

double _innerRemaining(WidgetTester tester) {
  return tester.widget<_InnerProbe>(find.byType(_InnerProbe)).lastInset;
}

double _innerViewInsets(WidgetTester tester) {
  return MediaQuery.viewInsetsOf(
    tester.element(find.byType(_InnerProbe)),
  ).bottom;
}

class _InnerProbe extends StatelessWidget {
  const _InnerProbe();

  static final lastInsetHolder = ValueNotifier<double>(0);

  double get lastInset => lastInsetHolder.value;

  @override
  Widget build(BuildContext context) {
    lastInsetHolder.value = keyboardInsetOf(context);
    return const SizedBox.expand();
  }
}
