import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/services/device_calendar_bridge.dart';

// This test never requests or grants calendar access and never writes events.
// Run only on an authorized simulator/emulator or test device.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native bridge registers and reads without prompting', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('Native bridge ready'))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Native bridge ready'), findsOneWidget);

    final bridge = MethodChannelDeviceCalendarBridge();
    expect(bridge.supported, isTrue);
    final permissionBefore = await bridge.permissionStatus();
    expect(
      permissionBefore,
      isIn(['granted', 'notDetermined', 'denied', 'restricted']),
    );
    final identifier = await bridge.deviceId();
    expect(identifier, matches(RegExp(r'^(ios|android):.+')));
    expect(await bridge.deviceId(), identifier);
    var calendarCount = 0;
    if (permissionBefore == 'granted') {
      calendarCount = (await bridge.listCalendars()).length;
    } else {
      await expectLater(
        bridge.listCalendars(),
        throwsA(
          isA<DeviceCalendarFailure>().having(
            (failure) => failure.code,
            'code',
            'permission_denied',
          ),
        ),
      );
    }
    expect(await bridge.permissionStatus(), permissionBefore);
    const current = MethodChannel('com.kemetic.calendar/device_import_v1');
    await expectLater(
      current.invokeMethod<void>('saveEvent'),
      throwsA(isA<MissingPluginException>()),
    );
    const retired = MethodChannel('com.kemetic.calendar/sync');
    await expectLater(
      retired.invokeMethod<void>('fetchEvents'),
      throwsA(isA<MissingPluginException>()),
    );
    binding.reportData = {
      'native_channel_registered': true,
      'visible_frame': true,
      'permission': permissionBefore,
      'permission_unchanged': true,
      'stable_identifier': true,
      'inventory_count': calendarCount,
      'retired_channel_absent': true,
      'write_method_absent': true,
    };
  });
}
