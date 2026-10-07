import 'dart:async';

// Exercise the pinned player adapter while controlling only device completion.
// ignore: depend_on_referenced_packages
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/speech/speech_service.dart';

/// Uses real bundled clips, SpeechService and DeviceSpeechAudio; only the audio
/// device is controlled so gestures can be tested before a recording finishes.
class ControlledSpeechPlayback extends AudioplayersPlatformInterface {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');

  final players = <String, StreamController<AudioEvent>>{};
  final interrupted = <String>[];
  final resumed = <String>[];
  late Completer<void> _disposed;

  void install() {
    final original = AudioplayersPlatformInterface.instance;
    final originalGlobal = GlobalAudioplayersPlatformInterface.instance;
    AudioplayersPlatformInterface.instance = this;
    GlobalAudioplayersPlatformInterface.instance = _GlobalAudio();
    addTearDown(() async {
      await SpeechService.instance.stop();
      AudioplayersPlatformInterface.instance = original;
      GlobalAudioplayersPlatformInterface.instance = originalGlobal;
    });
  }

  Future<void> tapAndStart(WidgetTester tester, Finder button) async {
    await tester.runAsync(() async {
      _disposed = Completer<void>();
      final started = Completer<void>();
      final speaking = SpeechService.instance.isSpeaking;
      void onSpeaking() {
        if (speaking.value && !started.isCompleted) started.complete();
      }

      speaking.addListener(onSpeaking);
      try {
        await tester.tap(button);
        await started.future.timeout(const Duration(seconds: 10));
      } finally {
        speaking.removeListener(onSpeaking);
      }
    });
    await tester.pump();
    expect(SpeechService.instance.isSpeaking.value, isTrue);
    expect(resumed, hasLength(1));
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.runAsync(() async {
      players[resumed.last]!.add(
        const AudioEvent(eventType: AudioEventType.complete),
      );
      await _disposed.future;
    });
  }

  @override
  Future<void> create(String playerId) async {
    players[playerId] = StreamController<AudioEvent>.broadcast();
  }

  @override
  Stream<AudioEvent> getEventStream(String playerId) =>
      players[playerId]!.stream;

  @override
  Future<void> setSourceBytes(
    String playerId,
    Uint8List bytes, {
    String? mimeType,
  }) async {
    expect(bytes, isNotEmpty);
    expect(mimeType, 'audio/mp4');
    players[playerId]!.add(
      const AudioEvent(eventType: AudioEventType.prepared, isPrepared: true),
    );
  }

  @override
  Future<void> resume(String playerId) async => resumed.add(playerId);

  @override
  Future<int?> getCurrentPosition(String playerId) async => 0;

  @override
  Future<int?> getDuration(String playerId) async => 3000;

  @override
  Future<void> stop(String playerId) async => interrupted.add(playerId);

  @override
  Future<void> release(String playerId) async => interrupted.add(playerId);

  @override
  Future<void> dispose(String playerId) async {
    interrupted.add(playerId);
    await players[playerId]!.close();
    _disposed.complete();
  }
}

class _GlobalAudio extends GlobalAudioplayersPlatformInterface {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
  @override
  Future<void> init() async {}

  @override
  Stream<GlobalAudioEvent> getGlobalEventStream() => const Stream.empty();
}
