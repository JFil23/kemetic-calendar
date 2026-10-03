import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DeviceCalendarFailure implements Exception {
  const DeviceCalendarFailure(this.code);
  final String code;
  @override
  String toString() => 'DeviceCalendarFailure($code)';
}

class DeviceCalendarInventorySource {
  const DeviceCalendarInventorySource({
    required this.nativeId,
    required this.label,
    required this.accountLabel,
    required this.kind,
    this.color,
  });
  final String nativeId, label, accountLabel, kind;
  final String? color;
  factory DeviceCalendarInventorySource.fromJson(Map<String, dynamic> data) {
    final id = data['native_id'];
    if (id is! String || id.isEmpty || data['label'] is! String) {
      throw const DeviceCalendarFailure('invalid_inventory');
    }
    return DeviceCalendarInventorySource(
      nativeId: id,
      label: data['label'] as String,
      accountLabel: data['account_label'] as String? ?? 'This phone',
      kind: data['kind'] as String? ?? 'device',
      color: data['color'] as String?,
    );
  }
  Map<String, dynamic> toJson() => {
    'native_id': nativeId,
    'label': label,
    'account_label': accountLabel,
    'kind': kind,
    'color': color,
  };
}

/// Only a complete, validated snapshot can cross the projection write boundary.
class DeviceCalendarSnapshot {
  DeviceCalendarSnapshot._(this.from, this.until, this.eventsByCalendar);
  final DateTime from, until;
  final Map<String, List<Map<String, dynamic>>> eventsByCalendar;

  factory DeviceCalendarSnapshot.validate(
    Map<String, dynamic> data, {
    required List<String> calendarIds,
    required DateTime from,
    required DateTime until,
  }) {
    final ids = data['calendarIds'];
    final events = data['events'];
    if (data['complete'] != true ||
        ids is! List ||
        events is! List ||
        events.length > 50000 ||
        ids.length != calendarIds.length ||
        ids.toSet().length != ids.length ||
        !setEquals(ids.toSet(), calendarIds.toSet()) ||
        data['fromMs'] != from.millisecondsSinceEpoch ||
        data['untilMs'] != until.millisecondsSinceEpoch) {
      throw const DeviceCalendarFailure('incomplete_snapshot');
    }
    final result = <String, List<Map<String, dynamic>>>{
      for (final id in calendarIds) id: [],
    };
    final identities = <String>{};
    for (final raw in events) {
      if (raw is! Map) throw const DeviceCalendarFailure('invalid_event');
      final row = Map<String, dynamic>.from(raw);
      final calendar = row.remove('native_calendar_id');
      if (calendar is! String ||
          !result.containsKey(calendar) ||
          row['provider_event_id'] is! String ||
          (row['provider_event_id'] as String).isEmpty ||
          row['recurrence_id'] is! String ||
          (row['recurrence_id'] as String).isEmpty ||
          row['title'] is! String ||
          row['all_day'] is! bool) {
        throw const DeviceCalendarFailure('invalid_event');
      }
      final start = _instant(row['starts_at']);
      final end = _instant(row['ends_at']);
      if (!end.isAfter(start)) {
        throw const DeviceCalendarFailure('invalid_event');
      }
      if (row['all_day'] == true) {
        final first = _civil(row['start_date']);
        final last = _civil(row['end_date']);
        if (!last.isAfter(first)) {
          throw const DeviceCalendarFailure('invalid_event');
        }
      }
      // Separators are length-prefixed so provider identifiers remain opaque.
      final components = [
        calendar,
        row['provider_event_id'] as String,
        row['recurrence_id'] as String,
      ];
      final identity = components
          .map((value) => '${value.length}:$value')
          .join();
      if (!identities.add(identity)) {
        throw const DeviceCalendarFailure('ambiguous_identity');
      }
      result[calendar]!.add(Map.unmodifiable(row));
    }
    return DeviceCalendarSnapshot._(
      from,
      until,
      Map.unmodifiable({
        for (final entry in result.entries)
          entry.key: List<Map<String, dynamic>>.unmodifiable(entry.value),
      }),
    );
  }

  static DateTime _instant(Object? value) {
    if (value is! String || !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(value)) {
      throw const DeviceCalendarFailure('invalid_event');
    }
    final date = DateTime.tryParse(value);
    if (date == null) throw const DeviceCalendarFailure('invalid_event');
    return date.toUtc();
  }

  static DateTime _civil(Object? value) {
    if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      throw const DeviceCalendarFailure('invalid_event');
    }
    final parts = value.split('-').map(int.parse).toList();
    final date = DateTime.utc(parts[0], parts[1], parts[2]);
    if (date.year != parts[0] ||
        date.month != parts[1] ||
        date.day != parts[2]) {
      throw const DeviceCalendarFailure('invalid_event');
    }
    return date;
  }
}

abstract interface class DeviceCalendarBridge {
  bool get supported;
  Stream<void> get changes;
  Future<String> permissionStatus();
  Future<String> requestPermission();
  Future<String> deviceId();
  Future<List<DeviceCalendarInventorySource>> listCalendars();
  Future<DeviceCalendarSnapshot> readSnapshot(
    List<String> calendarIds,
    DateTime from,
    DateTime until,
  );
}

class MethodChannelDeviceCalendarBridge implements DeviceCalendarBridge {
  MethodChannelDeviceCalendarBridge({
    MethodChannel? channel,
    EventChannel? events,
    this.requestTimeout = const Duration(seconds: 25),
    bool? supported,
  }) : _channel =
           channel ??
           const MethodChannel('com.kemetic.calendar/device_import_v1'),
       _events =
           events ??
           const EventChannel('com.kemetic.calendar/device_import_changes_v1'),
       _supported = supported;
  final MethodChannel _channel;
  final EventChannel _events;
  final Duration requestTimeout;
  final bool? _supported;
  static bool get supportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);
  @override
  bool get supported => _supported ?? supportedPlatform;
  @override
  Stream<void> get changes =>
      _events.receiveBroadcastStream().map<void>((_) {});

  Future<T> _call<T>(String method, [Map<String, dynamic>? arguments]) async {
    if (!supported) throw const DeviceCalendarFailure('unsupported');
    try {
      final value = await _channel
          .invokeMethod<T>(method, arguments)
          .timeout(
            method == 'requestPermission'
                ? const Duration(seconds: 95)
                : requestTimeout,
          );
      if (value == null) throw const DeviceCalendarFailure('invalid_response');
      return value;
    } on PlatformException catch (error) {
      throw DeviceCalendarFailure(error.code);
    } on MissingPluginException {
      throw const DeviceCalendarFailure('unsupported');
    } on TimeoutException {
      throw const DeviceCalendarFailure('timeout');
    }
  }

  @override
  Future<String> permissionStatus() => _call<String>('permissionStatus');
  @override
  Future<String> requestPermission() => _call<String>('requestPermission');
  @override
  Future<String> deviceId() => _call<String>('deviceId');
  @override
  Future<List<DeviceCalendarInventorySource>> listCalendars() async {
    final rows = await _call<List<dynamic>>('listCalendars');
    final sources = rows
        .map(
          (row) => DeviceCalendarInventorySource.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(growable: false);
    if (sources.map((source) => source.nativeId).toSet().length !=
        sources.length) {
      throw const DeviceCalendarFailure('invalid_inventory');
    }
    return sources;
  }

  @override
  Future<DeviceCalendarSnapshot> readSnapshot(
    List<String> calendarIds,
    DateTime from,
    DateTime until,
  ) async {
    if (calendarIds.isEmpty ||
        calendarIds.length > 50 ||
        !until.isAfter(from) ||
        until.difference(from) > const Duration(days: 730)) {
      throw const DeviceCalendarFailure('invalid_range');
    }
    final value = await _call<Map<dynamic, dynamic>>('readSnapshot', {
      'calendarIds': calendarIds,
      'fromMs': from.millisecondsSinceEpoch,
      'untilMs': until.millisecondsSinceEpoch,
    });
    return DeviceCalendarSnapshot.validate(
      Map<String, dynamic>.from(value),
      calendarIds: calendarIds,
      from: from,
      until: until,
    );
  }
}
