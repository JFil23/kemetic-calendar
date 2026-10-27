import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/profile/profile_backdrop_timeline.dart';

Future<String> pixels(File file) async {
  final codec = await ui.instantiateImageCodec(await file.readAsBytes());
  try {
    final frame = await codec.getNextFrame();
    try {
      expect(frame.image.width, 2730);
      expect(frame.image.height, 1536);
      final rgba = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      return sha256.convert(rgba!.buffer.asUint8List()).toString();
    } finally {
      frame.image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'lossless profile delivery preserves every approved source pixel',
    () async {
      final reference =
          jsonDecode(
                File(
                  'test/fixtures/profile_backdrop_source_pixels.v1.json',
                ).readAsStringSync(),
              )
              as Map;
      final frames = (reference['frames'] as List).cast<Map>();
      expect(frames, hasLength(profileBackdropFrames.length));
      var originalBytes = 0, deliveryBytes = 0;
      for (final frame in profileBackdropFrames) {
        final reference = frames.singleWhere(
          (r) => r['asset'] == frame.assetPath,
        );
        final optimized = File(frame.assetPath);
        expect(
          await pixels(optimized),
          reference['rgba_sha256'],
          reason: frame.assetPath,
        );
        originalBytes += reference['source_bytes'] as int;
        deliveryBytes += await optimized.length();
      }
      expect(deliveryBytes, lessThan(originalBytes));
      final manifest = File('pubspec.yaml').readAsStringSync();
      expect(manifest, contains('    - assets/profile/day_cycle_alt_2/'));
      expect(
        manifest,
        isNot(contains('    - assets/profile/day_cycle_alt_2_lossless/')),
      );
    },
  );
}
