import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/features/calendar/pronunciation/pronunciation_catalog.dart';
import 'package:mobile/features/calendar/pronunciation/pronunciation_service.dart';
import 'package:mobile/widgets/pronounce_icon_button.dart';

class RejectFallback implements PronunciationFallback {
  int calls = 0;
  @override
  Future<void> prepare() async {
    calls++;
    throw StateError('Bundled asset must play');
  }

  @override
  Future<void> speak(String text) async {
    throw StateError('Unexpected fallback');
  }

  @override
  Future<void> stop() async {}
}

class MissingAsset implements PronunciationAudio {
  @override
  Future<void> load(String asset) async {
    throw StateError('Forced missing asset');
  }

  @override
  Future<void> play() async {
    throw StateError('Unreachable');
  }

  @override
  Future<void> stop() async {}
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native asset play, second tap, navigation stop, and device fallback',
    (tester) async {
      final fallback = RejectFallback();
      final service = PronunciationService(fallback: fallback);
      final key = PronunciationKey.decan(1, 1);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  PronounceIconButton(
                    pronunciationKey: key,
                    color: Colors.amber,
                    service: service,
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            const Scaffold(body: Text('Next route')),
                      ),
                    ),
                    child: const Text('Navigate'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Play pronunciation'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(service.activeKey.value, key);
      expect(find.byTooltip('Stop pronunciation'), findsOneWidget);
      await tester.tap(find.byTooltip('Stop pronunciation'));
      await tester.pump(const Duration(milliseconds: 150));
      expect(service.activeKey.value, isNull);
      expect(fallback.calls, 0);
      await tester.tap(find.byTooltip('Play pronunciation'));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.text('Navigate'));
      await tester.pumpAndSettle();
      expect(service.activeKey.value, isNull);
      expect(fallback.calls, 0);
      // Actual plugin completion, not only a brief load: all three ID kinds.
      for (final identity in [
        PronunciationKey.month(13),
        key,
        PronunciationKey.epagomenal(5),
      ]) {
        await service.play(identity).timeout(const Duration(seconds: 20));
        expect(service.activeKey.value, isNull);
      }
      expect(fallback.calls, 0);
      final emergency = PronunciationService(audio: MissingAsset());
      await emergency
          .play(PronunciationKey.month(1))
          .timeout(const Duration(seconds: 20));
      expect(emergency.activeKey.value, isNull);
      await emergency.stop();
      await service.stop();
    },
  );
}
