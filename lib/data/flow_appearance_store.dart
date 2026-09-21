import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class FlowAppearanceStore {
  FlowAppearanceStore(this._client);

  static const bucket = 'flow-appearance-images';
  static const _uuid = Uuid();

  final SupabaseClient _client;

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
    return path;
  }

  Future<String> signedUrl(String objectPath) => _client.storage
      .from(bucket)
      .createSignedUrl(objectPath, const Duration(hours: 1).inSeconds);

  Future<String?> materializeOwnedCopy(String? sourcePath) async {
    final path = sourcePath?.trim();
    final userId = _client.auth.currentUser?.id;
    if (path == null || path.isEmpty || userId == null) return path;
    if (path.startsWith('$userId/')) return path;
    final bytes = await _client.storage.from(bucket).download(path);
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
