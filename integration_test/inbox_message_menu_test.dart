import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/support/inbox_message_menu_scenarios.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  setUpAll(
    () => SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
  );
  tearDownAll(() => SystemChrome.setPreferredOrientations([]));
  inboxMessageMenuScenarios();
}
