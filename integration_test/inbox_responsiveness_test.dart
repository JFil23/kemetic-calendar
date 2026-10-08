import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/support/inbox_responsiveness_scenarios.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  setUpAll(() async {
    await SystemChrome.setPreferredOrientations([
      const bool.fromEnvironment('INBOX_TEST_LANDSCAPE')
          ? DeviceOrientation.landscapeLeft
          : DeviceOrientation.portraitUp,
    ]);
  });
  tearDownAll(() => SystemChrome.setPreferredOrientations([]));
  inboxResponsivenessScenarios();
}
