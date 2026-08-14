import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() async {
  final outputDirectory = Platform.environment['CALENDAR_BENCHMARK_OUTPUT_DIR'];
  final outputName =
      Platform.environment['CALENDAR_BENCHMARK_OUTPUT_NAME'] ??
      'calendar_boundary_performance';

  await integrationDriver(
    writeResponseOnFailure: true,
    responseDataCallback: (data) => writeResponseData(
      data,
      testOutputFilename: outputName,
      destinationDirectory: outputDirectory,
    ),
  );
}
