import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/notify.dart';

void main() {
  test('startup Darwin notification init does not request permission', () {
    const settings = Notify.debugStartupDarwinInitializationSettings;

    expect(settings.requestAlertPermission, isFalse);
    expect(settings.requestBadgePermission, isFalse);
    expect(settings.requestSoundPermission, isFalse);
  });

  test(
    'explicit local notification permission path remains user initiated',
    () {
      final notifySource = File(
        'lib/features/calendar/notify.dart',
      ).readAsStringSync();
      final permissionPath = _sliceBetween(
        notifySource,
        'static Future<bool> _localNotificationsEnabled({',
        'static Future<String?> localDeliveryPermissionWarning() async',
      );

      expect(permissionPath, contains('requestIfMissing'));
      expect(permissionPath, contains('requestNotificationsPermission()'));
      expect(permissionPath, contains('iosSpecific.requestPermissions('));
      expect(permissionPath, contains('macSpecific.requestPermissions('));
    },
  );
}

String _sliceBetween(String source, String startNeedle, String endNeedle) {
  final start = source.indexOf(startNeedle);
  expect(start, greaterThanOrEqualTo(0), reason: startNeedle);
  final end = source.indexOf(endNeedle, start);
  expect(end, greaterThan(start), reason: endNeedle);
  return source.substring(start, end);
}
