import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

class SpeechUnavailable implements Exception {
  const SpeechUnavailable([
    this.message = 'This pronunciation could not play. Please try again.',
  ]);
  final String message;
  @override
  String toString() => message;
}

abstract interface class SpeechAssetStore {
  Future<Uint8List> load(String asset, String digest);
}

/// Native builds contain the audio. Web saves the same public assets in IndexedDB
/// so a browser restart or account change does not require a speech provider.
/// This cache contains no user text, credentials, authored data, or pending writes.
class BundledSpeechAssetStore implements SpeechAssetStore {
  BundledSpeechAssetStore({
    Future<Uint8List> Function(String)? readAsset,
    Future<Uint8List?> Function(String)? readCache,
    Future<void> Function(String, Uint8List)? writeCache,
  }) : _readAsset = readAsset ?? _bundleBytes,
       _readCache = readCache ?? (kIsWeb ? _webRead : _noCacheRead),
       _writeCache = writeCache ?? (kIsWeb ? _webWrite : _noCacheWrite);
  final Future<Uint8List> Function(String) _readAsset;
  final Future<Uint8List?> Function(String) _readCache;
  final Future<void> Function(String, Uint8List) _writeCache;
  final _pending = <String, Future<Uint8List>>{};
  static Future<Box<Uint8List>>? _boxFuture;
  static Future<Box<Uint8List>> _box() async {
    final pending = _boxFuture ??= Hive.openBox<Uint8List>('speech_audio_v1');
    try {
      return await pending;
    } catch (_) {
      _boxFuture = null;
      rethrow;
    }
  }

  static Future<Uint8List?> _webRead(String key) async =>
      (await _box()).get(key);
  static Future<void> _webWrite(String key, Uint8List value) async =>
      (await _box()).put(key, value);
  static Future<Uint8List?> _noCacheRead(String _) async => null;
  static Future<void> _noCacheWrite(String _, Uint8List value) async {}
  static Future<Uint8List> _bundleBytes(String asset) async {
    final data = await rootBundle.load('assets/$asset');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  @override
  Future<Uint8List> load(String asset, String digest) async {
    final key = '$asset:$digest';
    final existing = _pending[key];
    if (existing != null) return existing;
    final request = _load(asset, digest, key);
    _pending[key] = request;
    try {
      return await request;
    } finally {
      _pending.remove(key);
    }
  }

  Future<Uint8List> _load(String asset, String digest, String key) async {
    Uint8List? cached;
    try {
      cached = await _readCache(key);
    } catch (_) {
      throw const SpeechUnavailable(
        'Audio storage is unavailable. Please try again.',
      );
    }
    if (cached != null && _valid(cached, digest)) return cached;
    Uint8List bytes;
    try {
      bytes = await _readAsset(asset);
    } catch (_) {
      throw const SpeechUnavailable(
        'Connect once to save this voice for offline pronunciation.',
      );
    }
    if (!_valid(bytes, digest)) {
      throw const SpeechUnavailable(
        'This voice download is incomplete. Please try again.',
      );
    }
    try {
      await _writeCache(key, bytes);
    } catch (_) {
      throw const SpeechUnavailable(
        'There is not enough available storage to save this voice. Please try again.',
      );
    }
    return bytes;
  }

  bool _valid(Uint8List bytes, String digest) =>
      bytes.isNotEmpty && sha256.convert(bytes).toString() == digest;
}
