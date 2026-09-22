import 'dart:collection';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class FlowAppearanceStore {
  FlowAppearanceStore(this._client);

  static const bucket = 'flow-appearance-images';
  static const _uuid = Uuid();
  static const _maxCachedImages = 8;
  static final LinkedHashMap<String, _FlowAppearanceImageCacheEntry>
  _imageCache = LinkedHashMap<String, _FlowAppearanceImageCacheEntry>();

  static Future<Uint8List> Function(SupabaseClient client, String objectPath)?
  debugDownloadImageForTesting;

  final SupabaseClient _client;

  String _cacheKey(String objectPath) =>
      '${_client.auth.currentUser?.id ?? 'anonymous'}::$objectPath';

  _FlowAppearanceImageCacheEntry? _touchCachedEntry(String objectPath) {
    final key = _cacheKey(objectPath);
    final entry = _imageCache.remove(key);
    if (entry != null) _imageCache[key] = entry;
    return entry;
  }

  void _storeCachedEntry(
    String objectPath,
    _FlowAppearanceImageCacheEntry entry,
  ) {
    final key = _cacheKey(objectPath);
    _imageCache
      ..remove(key)
      ..[key] = entry;
    while (_imageCache.length > _maxCachedImages) {
      _imageCache.remove(_imageCache.keys.first);
    }
  }

  Uint8List? cachedImageBytes(String objectPath) =>
      _touchCachedEntry(objectPath)?.bytes;

  Future<Uint8List> imageBytes(String objectPath) {
    final cached = _touchCachedEntry(objectPath);
    if (cached?.bytes != null) return Future<Uint8List>.value(cached!.bytes!);
    if (cached?.future != null) return cached!.future!;

    final entry = _FlowAppearanceImageCacheEntry();
    Future<Uint8List> load() async {
      try {
        final override = debugDownloadImageForTesting;
        final bytes = override == null
            ? await _client.storage.from(bucket).download(objectPath)
            : await override(_client, objectPath);
        if (identical(_imageCache[_cacheKey(objectPath)], entry)) {
          entry
            ..bytes = bytes
            ..future = null;
          _touchCachedEntry(objectPath);
        }
        return bytes;
      } catch (_) {
        final key = _cacheKey(objectPath);
        if (identical(_imageCache[key], entry)) _imageCache.remove(key);
        rethrow;
      }
    }

    entry.future = load();
    _storeCachedEntry(objectPath, entry);
    return entry.future!;
  }

  void rememberImageBytes(String objectPath, Uint8List bytes) {
    _storeCachedEntry(objectPath, _FlowAppearanceImageCacheEntry(bytes: bytes));
  }

  static void debugResetImageCacheForTesting() {
    _imageCache.clear();
    debugDownloadImageForTesting = null;
  }

  Future<String> uploadOwnedImage({
    required Uint8List bytes,
    required String filename,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('No user session');
    final mime = _contentTypeFor(filename, bytes);
    final extension = switch (mime) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    final path = '$userId/${_uuid.v4()}.$extension';
    await _client.storage
        .from(bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mime, upsert: false),
        );
    rememberImageBytes(path, bytes);
    return path;
  }

  Future<String?> materializeOwnedCopy(String? sourcePath) async {
    final path = sourcePath?.trim();
    final userId = _client.auth.currentUser?.id;
    if (path == null || path.isEmpty || userId == null) return path;
    if (path.startsWith('$userId/')) return path;
    final bytes = await imageBytes(path);
    final extension = path.split('.').last.toLowerCase();
    final safeExtension = {'jpg', 'jpeg', 'png', 'webp'}.contains(extension)
        ? extension
        : 'jpg';
    final ownedPath = '$userId/${_uuid.v4()}.$safeExtension';
    await _client.storage
        .from(bucket)
        .uploadBinary(
          ownedPath,
          bytes,
          fileOptions: FileOptions(
            contentType: _contentTypeFor(ownedPath, bytes),
            upsert: false,
          ),
        );
    rememberImageBytes(ownedPath, bytes);
    return ownedPath;
  }

  static String _contentTypeFor(String filename, Uint8List bytes) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png') ||
        (bytes.length >= 8 &&
            bytes[0] == 0x89 &&
            bytes[1] == 0x50 &&
            bytes[2] == 0x4E &&
            bytes[3] == 0x47)) {
      return 'image/png';
    }
    if (lower.endsWith('.webp') ||
        (bytes.length >= 12 &&
            String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP')) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }
}

class _FlowAppearanceImageCacheEntry {
  _FlowAppearanceImageCacheEntry({this.bytes});

  Uint8List? bytes;
  Future<Uint8List>? future;
}
