import 'dart:async';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Exercise the pinned preferences adapter without changing production IO.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:mobile/services/speech/speech_asset_store.dart';
import 'package:mobile/services/speech/speech_audio.dart';
import 'package:mobile/services/speech/speech_service.dart';

class MemoryAssets implements SpeechAssetStore {
  final requests = <String>[];
  Completer<Uint8List>? pending;
  bool fail = false;
  @override
  Future<Uint8List> load(String asset, String digest) async {
    requests.add(asset);
    if (fail) throw const SpeechUnavailable();
    return pending?.future ?? Uint8List.fromList([1, 2, 3]);
  }
}

class FakeAudio implements SpeechAudio {
  final events = StreamController<void>.broadcast();
  bool played = false;
  bool disposed = false;
  String? mime;
  @override
  Stream<void> get completed => events.stream;
  @override
  Future<void> play(Uint8List bytes, {required String mimeType}) async {
    played = true;
    mime = mimeType;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

class RejectingPreferences extends InMemorySharedPreferencesStore {
  RejectingPreferences()
    : super.withData({'flutter.speech:preferredVoiceId': 'haw-g'});
  bool reject = true;
  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (reject) return false;
    return super.setValue(type, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemoryAssets assets;
  late List<FakeAudio> players;
  late SpeechService service;
  setUp(() {
    SharedPreferences.setMockInitialValues({
      SpeechService.preferredVoiceKey: 'voice:en-us|fred',
    });
    assets = MemoryAssets();
    players = [];
    service = SpeechService(
      assets: assets,
      createAudio: () {
        final audio = FakeAudio();
        players.add(audio);
        return audio;
      },
    );
  });
  tearDown(() async {
    await service.stop();
    for (final player in players) {
      await player.events.close();
    }
  });
  test(
    'retired voice migrates to G under the unchanged key; H survives restart',
    () async {
      expect(await service.getPreferredVoice(), SpeechVoiceOption.g);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('speech:preferredVoiceId'), 'haw-g');
      await service.setPreferredVoice(SpeechVoiceOption.h);
      expect(
        await SpeechService(assets: assets).getPreferredVoice(),
        SpeechVoiceOption.h,
      );
    },
  );
  test(
    'failed preference write retains confirmed choice and can retry',
    () async {
      final store = RejectingPreferences();
      SharedPreferencesStorePlatform.instance = store;
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      expect(await service.getPreferredVoice(), SpeechVoiceOption.g);
      await expectLater(
        service.setPreferredVoice(SpeechVoiceOption.h),
        throwsA(isA<SpeechUnavailable>()),
      );
      expect(await service.getPreferredVoice(), SpeechVoiceOption.g);
      expect(prefs.getString(SpeechService.preferredVoiceKey), 'haw-g');
      expect(
        await SpeechService(assets: assets).getPreferredVoice(),
        SpeechVoiceOption.g,
      );
      store.reject = false;
      await service.setPreferredVoice(SpeechVoiceOption.h);
      expect(
        await SpeechService(assets: assets).getPreferredVoice(),
        SpeechVoiceOption.h,
      );
    },
  );
  test(
    'approved preview and month/decan use selected voice recordings',
    () async {
      await service.setPreferredVoice(SpeechVoiceOption.h);
      await service.preview(utteranceId: 'preview');
      expect(assets.requests.last, 'speech/previews/H.mp3');
      expect(players.last.mime, 'audio/mpeg');
      await service.speak('  Thoth,   Jehuty  ', utteranceId: 'month');
      expect(assets.requests.last, 'speech/library/H/month-01.m4a');
      expect(players.first.disposed, isTrue);
      expect(players.last.mime, 'audio/mp4');
      await service.speakPhonetic('Tepi-a Sebau', utteranceId: 'decan');
      expect(assets.requests.last, 'speech/library/H/decan-01.m4a');
      expect(service.activeUtteranceId.value, 'decan');
    },
  );
  test('stop during a pending load prevents late playback', () async {
    assets.pending = Completer();
    final playback = service.preview(utteranceId: 'preview');
    await Future<void>.delayed(Duration.zero);
    await service.stop();
    assets.pending!.complete(Uint8List.fromList([1]));
    await playback;
    expect(players, isEmpty);
    expect(service.activeUtteranceId.value, isNull);
  });
  test(
    'a newer utterance wins and old completion or scoped stop cannot clear it',
    () async {
      await service.preview(utteranceId: 'first');
      await service.speak('Thoth, Jehuty', utteranceId: 'second');
      players.first.events.add(null);
      await service.stop(utteranceId: 'first');
      await Future<void>.delayed(Duration.zero);
      expect(service.activeUtteranceId.value, 'second');
      players.last.events.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(service.activeUtteranceId.value, isNull);
      expect(service.isSpeaking.value, isFalse);
    },
  );
  test(
    'missing phrases and failed reads report errors without fallback',
    () async {
      await expectLater(
        service.speak('Unrecorded text'),
        throwsA(isA<SpeechUnavailable>()),
      );
      expect(assets.requests, isEmpty);
      assets.fail = true;
      await expectLater(service.preview(), throwsA(isA<SpeechUnavailable>()));
      expect(players, isEmpty);
      expect(service.activeUtteranceId.value, isNull);
    },
  );
  test(
    'partial library failure is retryable and readiness requires every asset',
    () async {
      assets.fail = true;
      await service.prepareLibrary();
      expect(service.libraryReady.value, isFalse);
      expect(service.libraryFailed.value, isTrue);
      assets.fail = false;
      await service.prepareLibrary();
      expect(service.libraryReady.value, isTrue);
      expect(service.libraryFailed.value, isFalse);
      expect(
        assets.requests.toSet().where((s) => s.endsWith('.mp3')).length,
        2,
      );
    },
  );
  test(
    'verified public bytes survive a store restart with the asset reader offline',
    () async {
      final cache = <String, Uint8List>{};
      final bytes = Uint8List.fromList([5, 4, 3]);
      final digest = sha256.convert(bytes).toString();
      final first = BundledSpeechAssetStore(
        readAsset: (_) async => bytes,
        readCache: (key) async => cache[key],
        writeCache: (key, data) async {
          cache[key] = data;
        },
      );
      await first.load('speech/test.m4a', digest);
      final restarted = BundledSpeechAssetStore(
        readAsset: (_) async => throw StateError('offline'),
        readCache: (key) async => cache[key],
        writeCache: (_, data) async => fail('Unexpected write'),
      );
      expect(await restarted.load('speech/test.m4a', digest), bytes);
      expect(cache.keys.single, 'speech/test.m4a:$digest');
    },
  );
  test(
    'corrupt cache is repaired; corrupt downloads are never cached',
    () async {
      var cached = Uint8List.fromList([0]);
      final good = Uint8List.fromList([1, 2]);
      final digest = sha256.convert(good).toString();
      var downloads = 0;
      final store = BundledSpeechAssetStore(
        readAsset: (_) async {
          downloads++;
          return good;
        },
        readCache: (_) async => cached,
        writeCache: (_, bytes) async {
          cached = bytes;
        },
      );
      expect(await store.load('clip', digest), good);
      expect(downloads, 1);
      expect(await store.load('clip', digest), good);
      expect(downloads, 1);
      final invalid = BundledSpeechAssetStore(
        readAsset: (_) async => Uint8List.fromList([0]),
        readCache: (_) async => null,
        writeCache: (_, bytes) async => fail('Invalid bytes cached'),
      );
      await expectLater(
        invalid.load('clip', digest),
        throwsA(isA<SpeechUnavailable>()),
      );
    },
  );
  test(
    'concurrent reads coalesce; storage rejection remains retryable',
    () async {
      final bytes = Uint8List.fromList([8]);
      final digest = sha256.convert(bytes).toString();
      final download = Completer<Uint8List>();
      var reads = 0;
      var reject = true;
      final store = BundledSpeechAssetStore(
        readAsset: (_) {
          reads++;
          return download.future;
        },
        readCache: (_) async => null,
        writeCache: (_, data) async {
          if (reject) throw StateError('full');
        },
      );
      final one = store.load('clip', digest);
      final two = store.load('clip', digest);
      final checks = Future.wait([
        expectLater(one, throwsA(isA<SpeechUnavailable>())),
        expectLater(two, throwsA(isA<SpeechUnavailable>())),
      ]);
      download.complete(bytes);
      await checks;
      expect(reads, 1);
      reject = false;
      expect(await store.load('clip', digest), bytes);
      expect(reads, 2);
    },
  );
}
