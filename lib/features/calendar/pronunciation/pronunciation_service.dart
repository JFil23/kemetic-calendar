import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pronunciation_catalog.dart';
part 'device_pronunciation_voice.dart';

/// Drivers carry no calendar identity or speech mapping.
abstract interface class PronunciationAudio {
  Future<void> load(String asset);
  Future<void> play();
  Future<void> stop();
}

abstract interface class PronunciationFallback {
  Future<void> prepare();
  Future<void> speak(String catalogText);
  Future<void> stop();
}

class _BundledPronunciationAudio implements PronunciationAudio {
  AudioPlayer? _player;
  @override
  Future<void> load(String asset) async {
    await (_player ??= AudioPlayer()).setAsset(asset);
  }

  @override
  Future<void> play() async {
    final player = _player!;
    final error = Completer<void>();
    final subscription = player.playbackEventStream.listen(
      (_) {},
      onError: (Object e, StackTrace stack) {
        if (!error.isCompleted) error.completeError(e, stack);
      },
    );
    try {
      await Future.any([player.play(), error.future]);
    } finally {
      await subscription.cancel();
    }
  }

  @override
  Future<void> stop() async {
    await _player?.stop();
  }
}

/// Sole app-wide authority. Surfaces supply structural keys, never spoken text.
/// A generation and owner distinguish canceled loads, stale completions, and
/// two widgets playing the same key. Loading is serialized; playback is not.
class PronunciationService with WidgetsBindingObserver {
  PronunciationService({
    PronunciationAudio? audio,
    PronunciationFallback? fallback,
    bool observeLifecycle = false,
  }) : _audio = audio ?? _BundledPronunciationAudio(),
       _fallback = fallback ?? _DevicePronunciationVoice() {
    if (observeLifecycle) WidgetsBinding.instance.addObserver(this);
  }
  static final instance = PronunciationService(observeLifecycle: true);
  final PronunciationAudio _audio;
  final PronunciationFallback _fallback;
  final ValueNotifier<PronunciationKey?> activeKey = ValueNotifier(null);
  Object? _owner;
  int _generation = 0;
  Future<void> _preparation = Future.value();
  Completer<void>? _cancellation;

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _preparation.then((_) => action());
    _preparation = next.catchError((Object _) {});
    return next;
  }

  void _cancel() {
    _generation++;
    final cancellation = _cancellation;
    if (cancellation != null && !cancellation.isCompleted) {
      cancellation.complete();
    }
  }

  Future<void> _stopDrivers() => Future.wait([_audio.stop(), _fallback.stop()]);

  Future<void> stop({Object? owner, PronunciationKey? key}) {
    if ((owner != null && !identical(owner, _owner)) ||
        (key != null && key != activeKey.value)) {
      return Future.value();
    }
    _cancel();
    _owner = null;
    activeKey.value = null;
    // Interrupt a pending platform load immediately; serialize a final stop
    // before the next load as well so no old engine can start behind it.
    final immediate = _stopDrivers();
    return _enqueue(() async {
      await immediate;
      await _stopDrivers();
    });
  }

  Future<void> play(
    PronunciationKey key, {
    Object? owner,
    bool fallbackOnly = false,
  }) async {
    final row = PronunciationCatalog.lookup(key);
    _cancel();
    final generation = _generation;
    final canceled = _cancellation = Completer<void>();
    _owner = owner;
    activeKey.value = key;
    bool current() => generation == _generation;
    Future<void> wait(Future<void> operation) =>
        Future.any([operation, canceled.future]);
    final interruption = _stopDrivers();
    try {
      var loaded = false;
      await _enqueue(() async {
        await interruption;
        await _stopDrivers();
        if (!current() || fallbackOnly) return;
        try {
          await _audio.load(row.audioAsset).timeout(const Duration(seconds: 8));
          loaded = true;
        } catch (_) {
          /* Missing/undecodable assets use the catalog fallback. */
        }
      });
      if (!current()) return;
      if (loaded) {
        try {
          await wait(_audio.play());
          return;
        } catch (_) {
          if (!current()) return;
        }
      }
      await _enqueue(() async {
        await _audio.stop();
        if (current()) {
          await _fallback.prepare().timeout(const Duration(seconds: 8));
        }
      });
      if (!current()) return;
      await wait(_fallback.speak(row.readerRespelling));
      if (!current() || row.meaning.isEmpty) return;
      await wait(Future.delayed(Duration(milliseconds: row.pauseMilliseconds)));
      if (current()) await wait(_fallback.speak(row.meaning));
    } catch (_) {
      // Late failures from a canceled engine must not surface on the new owner.
      if (current()) rethrow;
    } finally {
      if (current()) {
        activeKey.value = null;
        _owner = null;
      }
    }
  }

  Future<void> previewFallback(PronunciationKey key, {Object? owner}) =>
      play(key, owner: owner, fallbackOnly: true);
  Future<List<SpeechVoiceOption>> getAvailableVoices({
    String? localePrefix,
    bool reload = false,
  }) async {
    final voice = _fallback;
    return voice is _DevicePronunciationVoice
        ? voice.voices(localePrefix: localePrefix, reload: reload)
        : const [];
  }

  Future<SpeechVoiceOption?> getPreferredVoice() async {
    final voice = _fallback;
    if (voice is! _DevicePronunciationVoice) return null;
    await voice.prepare();
    return voice._preferredVoice();
  }

  Future<void> setPreferredVoice(SpeechVoiceOption? selection) async {
    await stop();
    final voice = _fallback;
    if (voice is _DevicePronunciationVoice) {
      await _enqueue(() => voice.select(selection));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      unawaited(stop().catchError((Object _) {}));
    }
  }
}
