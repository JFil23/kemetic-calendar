import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'speech_asset_store.dart';
import 'speech_audio.dart';
import 'speech_catalog.g.dart';
import 'speech_voice.dart';
export 'speech_voice.dart';
export 'speech_asset_store.dart' show SpeechUnavailable;

/// Plays only the approved, bundled pronunciation recordings. No runtime TTS.
class SpeechService {
  SpeechService({
    SpeechAssetStore? assets,
    SpeechAudio Function()? createAudio,
    Future<SharedPreferences> Function()? preferences,
  }) : _assets = assets ?? BundledSpeechAssetStore(),
       _createAudio = createAudio ?? DeviceSpeechAudio.new,
       _preferences = preferences ?? SharedPreferences.getInstance;
  static final instance = SpeechService();
  static const preferredVoiceKey = 'speech:preferredVoiceId';
  final SpeechAssetStore _assets;
  final SpeechAudio Function() _createAudio;
  final Future<SharedPreferences> Function() _preferences;
  Future<void>? _initializing;
  Future<void>? _preparing;
  bool _ready = false;
  SpeechVoiceOption _voice = SpeechVoiceOption.g;
  int _generation = 0;
  SpeechAudio? _audio;
  StreamSubscription<void>? _completion;
  final isSpeaking = ValueNotifier<bool>(false);
  final activeUtteranceId = ValueNotifier<String?>(null);
  final libraryStatus = ValueNotifier<String>('Saving voices for offline use…');
  final libraryReady = ValueNotifier<bool>(false);
  final libraryFailed = ValueNotifier<bool>(false);
  static const Map<String, String> _transliterationReplacements = {
    'ꜣ': 'a',
    'Ꜣ': 'a',
    'ꜥ': 'a',
    'Ꜥ': 'a',
    'ḥ': 'h',
    'Ḥ': 'h',
    'ḫ': 'kh',
    'Ḫ': 'kh',
    'ẖ': 'kh',
    'š': 'sh',
    'Š': 'sh',
    'ṯ': 't',
    'Ṯ': 't',
    'ḏ': 'dj',
    'Ḏ': 'dj',
    'ȝ': 'a',
    'Ȝ': 'a',
    'ỉ': 'i',
    'Ỉ': 'i',
    'ʿ': 'a',
    'ʾ': 'a',
  };

  Future<void> _ensureReady() async {
    if (_ready) return;
    if (_initializing != null) return _initializing!;
    final future = _loadPreference();
    _initializing = future;
    try {
      await future;
    } finally {
      _initializing = null;
    }
  }

  Future<void> _loadPreference() async {
    final prefs = await _preferences();
    final saved = prefs.getString(preferredVoiceKey);
    _voice = SpeechVoiceOption.resolve(saved);
    // Preserve the deployed preference key; retired device voices become G.
    if (saved != _voice.id) await _savePreference(prefs, _voice.id);
    _ready = true;
  }

  Future<SpeechVoiceOption> getPreferredVoice() async {
    await _ensureReady();
    return _voice;
  }

  Future<void> setPreferredVoice(SpeechVoiceOption voice) async {
    await _ensureReady();
    await stop();
    final resolved = SpeechVoiceOption.resolve(voice.id);
    final prefs = await _preferences();
    await _savePreference(prefs, resolved.id);
    _voice = resolved;
  }

  Future<void> _savePreference(SharedPreferences prefs, String id) async {
    try {
      if (!await prefs.setString(preferredVoiceKey, id)) {
        throw StateError('Preference write rejected');
      }
    } catch (_) {
      // SharedPreferences updates its memory cache before awaiting the write.
      // Restore the confirmed value after failure instead of adopting it later.
      try {
        await prefs.reload();
      } catch (_) {
        /* Original write still failed. */
      }
      throw const SpeechUnavailable(
        'Your voice choice could not be saved. Please try again.',
      );
    }
  }

  /// Save the public corpus once on web. Native apps already bundle every file.
  /// One failed attempt is retryable; verified clips survive partial downloads.
  Future<void> prepareLibrary() async {
    if (libraryReady.value) return;
    if (_preparing != null) return _preparing!;
    final future = _prepare();
    _preparing = future;
    try {
      await future;
    } finally {
      _preparing = null;
    }
  }

  Future<void> _prepare() async {
    libraryFailed.value = false;
    var done = 0;
    final files = speechAssetDigests.entries.toList();
    var next = 0;
    libraryStatus.value = 'Saving voices for offline use…';
    Future<void> worker() async {
      while (next < files.length) {
        final entry = files[next++];
        await _assets.load(entry.key, entry.value);
        done++;
        libraryStatus.value =
            'Saving voices for offline use ($done/${files.length})…';
      }
    }

    try {
      await Future.wait(List.generate(4, (_) => worker()));
      libraryReady.value = true;
      libraryStatus.value = 'Both voices are ready for offline pronunciation.';
    } catch (_) {
      libraryFailed.value = true;
      libraryStatus.value =
          'Some recordings could not be saved. Reconnect and try again.';
    }
  }

  Future<void> preview({String? utteranceId}) => _play(null, utteranceId);
  Future<void> speak(String text, {String? utteranceId}) =>
      _play(text, utteranceId);
  Future<void> speakPhonetic(String text, {String? utteranceId}) =>
      speak(text, utteranceId: utteranceId);

  Future<void> _play(String? text, String? utteranceId) async {
    final generation = ++_generation;
    final previous = _releasePlayer();
    activeUtteranceId.value = utteranceId?.trim().isNotEmpty == true
        ? utteranceId!.trim()
        : '__speech_service__anonymous__';
    try {
      await previous;
      await _ensureReady();
      if (generation != _generation) return;
      final clip = text == null ? null : speechClipIds[_speechSafeText(text)];
      if (text != null && clip == null) {
        throw const SpeechUnavailable(
          'This phrase does not have a saved pronunciation yet.',
        );
      }
      final letter = _voice == SpeechVoiceOption.h ? 'H' : 'G';
      final asset = text == null
          ? _voice.previewAsset
          : 'speech/library/$letter/$clip.m4a';
      final digest = speechAssetDigests[asset];
      if (digest == null) throw const SpeechUnavailable();
      final bytes = await _assets.load(asset, digest);
      if (generation != _generation) return;
      final audio = _createAudio();
      _audio = audio;
      _completion = audio.completed.listen(
        (_) {
          if (generation == _generation) unawaited(stop());
        },
        onError: (Object _) {
          if (generation == _generation) unawaited(stop());
        },
      );
      await audio.play(
        bytes,
        mimeType: text == null ? 'audio/mpeg' : 'audio/mp4',
      );
      if (generation == _generation) isSpeaking.value = true;
    } catch (error) {
      if (generation != _generation) return;
      await stop();
      if (error is SpeechUnavailable) rethrow;
      throw const SpeechUnavailable();
    }
  }

  Future<void> stop({String? utteranceId}) async {
    if (utteranceId?.trim().isNotEmpty == true &&
        activeUtteranceId.value != utteranceId!.trim()) {
      return;
    }
    ++_generation;
    final released = _releasePlayer();
    activeUtteranceId.value = null;
    await released;
  }

  Future<void> _releasePlayer() async {
    final audio = _audio;
    final completion = _completion;
    _audio = null;
    _completion = null;
    isSpeaking.value = false;
    await completion?.cancel();
    try {
      await audio?.dispose();
    } catch (_) {
      /* Already stopped. */
    }
  }

  String _speechSafeText(String input) {
    var text = input;
    _transliterationReplacements.forEach((from, to) {
      text = text.replaceAll(from, to);
    });
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
