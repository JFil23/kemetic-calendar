import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/inbox_message_menu_scenarios.dart';

void main() {
  for (final size in [Size(320, 844), Size(390, 844), Size(844, 390)]) {
    group('$size', () => inboxMessageMenuScenarios(viewport: size));
  }
}
