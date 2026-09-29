import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/pronunciation/pronunciation_catalog.dart';
import 'package:mobile/features/calendar/pronunciation/pronunciation_identity.dart';
import 'package:mobile/features/calendar/pronunciation/pronunciation_service.dart';

class Audio implements PronunciationAudio {
  final loaded = <String>[];
  bool loadFails = false;
  bool playFails = false;
  int plays = 0;
  int stops = 0;
  Completer<void>? loadGate;
  Completer<void>? playGate;
  @override
  Future<void> load(String asset) async {
    loaded.add(asset);
    await loadGate?.future;
    if (loadFails) throw StateError('missing or corrupt');
  }

  @override
  Future<void> play() async {
    plays++;
    if (playFails) throw StateError('decode');
    await playGate?.future;
  }

  @override
  Future<void> stop() async {
    stops++;
  }
}

class Fallback implements PronunciationFallback {
  final spoken = <String>[];
  int prepares = 0;
  int stops = 0;
  bool fails = false;
  Completer<void>? gate;
  @override
  Future<void> prepare() async {
    prepares++;
  }

  @override
  Future<void> speak(String text) async {
    spoken.add(text);
    if (fails) throw StateError('no voice');
    await gate?.future;
  }

  @override
  Future<void> stop() async {
    stops++;
  }
}

Future<void> turn() => Future<void>.delayed(Duration.zero);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('successful assets never initialize or use device TTS', () async {
    final a = Audio();
    final f = Fallback();
    final s = PronunciationService(audio: a, fallback: f);
    await s.play(PronunciationKey.decan(1, 1));
    expect(a.loaded, ['assets/pronunciation/decan_01_01.mp3']);
    expect(a.plays, 1);
    expect(f.prepares, 0);
    expect(f.spoken, isEmpty);
    expect(s.activeKey.value, isNull);
  });
  for (final decodeFailure in [false, true]) {
    test(
      'asset ${decodeFailure ? 'playback' : 'load'} failure uses catalog name then gloss once',
      () async {
        final a = Audio()
          ..loadFails = !decodeFailure
          ..playFails = decodeFailure;
        final f = Fallback();
        final s = PronunciationService(audio: a, fallback: f);
        final key = PronunciationKey.decan(1, 1);
        await s.play(key);
        final row = PronunciationCatalog.lookup(key);
        expect(f.spoken, [row.readerRespelling, row.meaning]);
        expect(f.prepares, 1);
        expect(s.activeKey.value, isNull);
      },
    );
  }
  test(
    'name-only clip has no duplicate name gloss and preview skips asset',
    () async {
      final a = Audio();
      final f = Fallback();
      final s = PronunciationService(audio: a, fallback: f);
      final key = PronunciationKey.month(1);
      await s.previewFallback(key);
      expect(a.loaded, isEmpty);
      expect(f.spoken, [PronunciationCatalog.lookup(key).readerRespelling]);
    },
  );
  test(
    'rapid replacement suppresses stale load failure and old completion',
    () async {
      final gate = Completer<void>();
      final a = Audio()..loadGate = gate;
      final f = Fallback();
      final s = PronunciationService(audio: a, fallback: f);
      final first = s.play(PronunciationKey.month(1));
      await turn();
      final second = s.play(PronunciationKey.month(2));
      await turn();
      gate.complete();
      await Future.wait([first, second]);
      expect(a.plays, 1);
      expect(f.spoken, isEmpty);
      expect(s.activeKey.value, isNull);
    },
  );
  test(
    'stop during load and lifecycle interruption cannot trigger fallback',
    () async {
      final gate = Completer<void>();
      final a = Audio()
        ..loadGate = gate
        ..loadFails = true;
      final f = Fallback();
      final s = PronunciationService(audio: a, fallback: f);
      final playing = s.play(PronunciationKey.month(1));
      await turn();
      s.didChangeAppLifecycleState(AppLifecycleState.paused);
      gate.complete();
      await playing;
      await turn();
      expect(a.plays, 0);
      expect(f.spoken, isEmpty);
      expect(s.activeKey.value, isNull);
    },
  );
  test(
    'disposing another same-key owner cannot stop current playback',
    () async {
      final gate = Completer<void>();
      final a = Audio()..playGate = gate;
      final f = Fallback();
      final s = PronunciationService(audio: a, fallback: f);
      final owner = Object();
      final key = PronunciationKey.month(1);
      final playing = s.play(key, owner: owner);
      await turn();
      await s.stop(owner: Object());
      expect(s.activeKey.value, key);
      await s.stop(owner: owner);
      await playing;
      expect(s.activeKey.value, isNull);
      gate.complete();
    },
  );
  test(
    'cancel between fallback name and gloss prevents remaining speech',
    () async {
      final gate = Completer<void>();
      final a = Audio()..loadFails = true;
      final f = Fallback()..gate = gate;
      final s = PronunciationService(audio: a, fallback: f);
      final playing = s.play(PronunciationKey.decan(1, 1));
      await turn();
      await s.stop();
      await playing;
      gate.complete();
      expect(f.spoken, hasLength(1));
      expect(s.activeKey.value, isNull);
    },
  );
  test(
    'fallback failure clears activity and propagates a recoverable error',
    () async {
      final s = PronunciationService(
        audio: Audio()..loadFails = true,
        fallback: Fallback()..fails = true,
      );
      await expectLater(s.play(PronunciationKey.month(1)), throwsStateError);
      expect(s.activeKey.value, isNull);
    },
  );
  test('structural adapters include all five birthdays, exclude leap six', () {
    for (var d = 1; d <= 5; d++) {
      expect(
        PronunciationIdentity.dayKey('epagomenal_${d}_1'),
        PronunciationKey.epagomenal(d),
      );
    }
    expect(PronunciationIdentity.dayKey('epagomenal_6_1'), isNull);
    expect(
      PronunciationIdentity.compass('m06_d2'),
      PronunciationKey.decan(6, 2),
    );
    expect(
      PronunciationIdentity.compass('epagomenal'),
      PronunciationKey.month(13),
    );
    expect(
      PronunciationIdentity.period('2026-05-29:2026-06-07:3-2'),
      PronunciationKey.decan(3, 2),
    );
    expect(PronunciationIdentity.compass('ḥry-ib'), isNull);
  });
}
