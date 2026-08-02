import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final outputDirectory = Directory(
    Platform.environment['MAAT_CAPTURE_DIR'] ??
        '/private/tmp/maat-event-list-layout-parity-001/device-after',
  );
  await outputDirectory.create(recursive: true);
  final nativeIosDevice =
      Platform.environment['MAAT_NATIVE_IOS_DEVICE']?.trim() ?? '';

  await integrationDriver(
    onScreenshot: (name, bytes, [arguments]) async {
      final outputPath = '${outputDirectory.path}/$name.png';
      if (nativeIosDevice.isNotEmpty) {
        final result = await Process.run('xcrun', <String>[
          'simctl',
          'io',
          nativeIosDevice,
          'screenshot',
          outputPath,
        ]);
        if (result.exitCode != 0) {
          stderr.write(result.stderr);
          return false;
        }
      } else {
        await File(outputPath).writeAsBytes(bytes);
      }
      return true;
    },
  );
}
