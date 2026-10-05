import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/data/flow_appearance_store.dart';
import 'package:mobile/data/warm_state/warm_snapshot_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/pages/pages_resource_test.dart' show session, uid;

const _otherUser = '11111111-1111-4111-8111-111111111111';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final bytes = Uint8List.fromList([0xff, 0xd8, 0xff, 1, 2, 3]);
  late SupabaseClient client;
  late FlowAppearanceStore store;
  late Completer<void> uploadStarted;
  late Completer<void> allowUpload;
  var uploadPath = '';
  var uploads = 0;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlowAppearanceStore.debugResetImageCacheForTesting();
    uploadStarted = Completer<void>();
    allowUpload = Completer<void>();
    uploadPath = '';
    uploads = 0;
    client = SupabaseClient(
      'https://example.supabase.co',
      'fixture-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.path.contains('/storage/v1/object/')) {
          uploads++;
          uploadPath = request.url.path.split('/flow-appearance-images/').last;
          uploadStarted.complete();
          await allowUpload.future;
          return http.Response(
            jsonEncode({'Key': 'flow-appearance-images/$uploadPath'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        throw StateError('Unexpected fixture request: ${request.method}');
      }),
    );
    await client.auth.recoverSession(session());
    store = FlowAppearanceStore(client);
  });

  tearDown(() async {
    if (!allowUpload.isCompleted) allowUpload.complete();
    FlowAppearanceStore.debugResetImageCacheForTesting();
    await client.dispose();
  });

  test(
    'acknowledged upload retains bytes for its initiating account',
    () async {
      final result = store.uploadOwnedImage(
        bytes: bytes,
        filename: 'photo.jpg',
      );
      await uploadStarted.future;
      expect(uploadPath, startsWith('$uid/'));
      expect(store.cachedImageBytes(uploadPath), isNull);
      allowUpload.complete();
      expect(await result, uploadPath);
      expect(store.cachedImageBytes(uploadPath), bytes);
      expect(uploads, 1);
    },
  );

  for (final returnToOriginal in [false, true]) {
    test('late upload is fenced across account departure '
        '(return=$returnToOriginal)', () async {
      final result = store.uploadOwnedImage(
        bytes: bytes,
        filename: 'photo.jpg',
      );
      final rejected = expectLater(result, throwsA(isA<WarmReadCancelled>()));
      await uploadStarted.future;
      await client.auth.recoverSession(session().replaceAll(uid, _otherUser));
      if (returnToOriginal) await client.auth.recoverSession(session());
      await Future<void>.delayed(Duration.zero);
      allowUpload.complete();
      await rejected;
      expect(store.cachedImageBytes(uploadPath), isNull);
      expect(uploads, 1);
    });
  }

  test('import does not upload after departure during source read', () async {
    final reading = Completer<void>();
    final downloaded = Completer<Uint8List>();
    FlowAppearanceStore.debugDownloadImageForTesting = (_, _) {
      reading.complete();
      return downloaded.future;
    };
    final result = store.materializeOwnedCopy('$_otherUser/source.jpg');
    final rejected = expectLater(result, throwsA(isA<WarmReadCancelled>()));
    await reading.future;
    await client.auth.recoverSession(session().replaceAll(uid, _otherUser));
    await client.auth.recoverSession(session());
    await Future<void>.delayed(Duration.zero);
    downloaded.complete(bytes);
    await rejected;
    expect(uploads, 0);
  });

  test('late imported upload cannot populate another account cache', () async {
    FlowAppearanceStore.debugDownloadImageForTesting = (_, _) async => bytes;
    final result = store.materializeOwnedCopy('$_otherUser/source.jpg');
    final rejected = expectLater(result, throwsA(isA<WarmReadCancelled>()));
    await uploadStarted.future;
    await client.auth.recoverSession(session().replaceAll(uid, _otherUser));
    await Future<void>.delayed(Duration.zero);
    allowUpload.complete();
    await rejected;
    expect(store.cachedImageBytes(uploadPath), isNull);
    expect(uploads, 1);
  });
}
