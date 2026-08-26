import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/turning_record.dart';
import 'turning_record_repository.dart';

typedef FollowSkyPhotoUpload = Future<String> Function();
typedef FollowSkyPhotoReferencePersist =
    Future<TurningRecordSaveResult> Function(String objectPath);
typedef FollowSkyPhotoDelete = Future<void> Function(String objectPath);

/// Orders a retake so the old object remains authoritative until the new
/// reference is confirmed by the remote Turning Record store.
class FollowSkyPhotoReplacementCoordinator {
  const FollowSkyPhotoReplacementCoordinator();

  Future<TurningRecordSaveResult> replace({
    required String? previousObjectPath,
    required FollowSkyPhotoUpload uploadNew,
    required FollowSkyPhotoReferencePersist persistNewReference,
    required FollowSkyPhotoDelete deleteObject,
  }) async {
    final objectPath = await uploadNew();
    final result = await persistNewReference(objectPath);
    final previous = previousObjectPath?.trim();
    if (result.cloudSynced &&
        previous != null &&
        previous.isNotEmpty &&
        previous != objectPath) {
      try {
        await deleteObject(previous);
      } on Object {
        // The new reference is durable. Old-object cleanup is best effort.
      }
    }
    return result;
  }
}

class FollowSkyPhotoStore {
  const FollowSkyPhotoStore(this._client);

  static const String bucket = 'follow-sky-turnings';
  final SupabaseClient _client;

  Future<String> upload({
    required TurningRecord record,
    required Uint8List bytes,
    required String contentType,
    required String extension,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Sign in to archive a sky photo.');
    final safeClientId = record.clientEventId.replaceAll(
      RegExp(r'[^a-zA-Z0-9_-]'),
      '_',
    );
    final safeExtension = extension.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final path =
        '${user.id}/$safeClientId/${DateTime.now().toUtc().microsecondsSinceEpoch}.${safeExtension.isEmpty ? 'jpg' : safeExtension}';
    await _client.storage
        .from(bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );
    return path;
  }

  Future<void> delete(String objectPath) async {
    final path = objectPath.trim();
    if (path.isEmpty) return;
    await _client.storage.from(bucket).remove(<String>[path]);
  }
}
