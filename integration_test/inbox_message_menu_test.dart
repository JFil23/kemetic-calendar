import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/support/inbox_message_menu_scenarios.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Opening a route cancels the held long-press pointer asynchronously. Live
  // tests classify that framework cancellation as a device event; deliver it
  // as the real app does so the message recognizers can accept the next tap.
  binding.shouldPropagateDevicePointerEvents = true;
  WidgetController.hitTestWarningShouldBeFatal = true;
  setUpAll(
    () => SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
  );
  tearDownAll(() => SystemChrome.setPreferredOrientations([]));
  inboxMessageMenuScenarios();
}
