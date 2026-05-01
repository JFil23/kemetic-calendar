import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_window_service.dart';

class CalendarRestorationState {
  const CalendarRestorationState({
    required this.kYear,
    required this.kMonth,
    required this.kDay,
    required this.showGregorian,
    required this.expansion,
    this.scrollOffset,
  });

  final int kYear;
  final int kMonth;
  final int kDay;
  final bool showGregorian;
  final String expansion;
  final double? scrollOffset;

  CalendarRestorationState copyWith({
    int? kYear,
    int? kMonth,
    int? kDay,
    bool? showGregorian,
    String? expansion,
    double? scrollOffset,
    bool clearScrollOffset = false,
  }) {
    return CalendarRestorationState(
      kYear: kYear ?? this.kYear,
      kMonth: kMonth ?? this.kMonth,
      kDay: kDay ?? this.kDay,
      showGregorian: showGregorian ?? this.showGregorian,
      expansion: expansion ?? this.expansion,
      scrollOffset: clearScrollOffset
          ? null
          : (scrollOffset ?? this.scrollOffset),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'kYear': kYear,
      'kMonth': kMonth,
      'kDay': kDay,
      'showGregorian': showGregorian,
      'expansion': expansion,
      if (scrollOffset != null) 'scrollOffset': scrollOffset,
    };
  }

  static CalendarRestorationState? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      return null;
    }
    final kYear = (raw['kYear'] as num?)?.toInt();
    final kMonth = (raw['kMonth'] as num?)?.toInt();
    final kDay = (raw['kDay'] as num?)?.toInt();
    final showGregorian = raw['showGregorian'] == true;
    final expansion = (raw['expansion'] as String?)?.trim();
    if (kYear == null || kMonth == null || kDay == null || expansion == null) {
      return null;
    }
    return CalendarRestorationState(
      kYear: kYear,
      kMonth: kMonth,
      kDay: kDay,
      showGregorian: showGregorian,
      expansion: expansion,
      scrollOffset: (raw['scrollOffset'] as num?)?.toDouble(),
    );
  }
}

class DayViewRestorationState {
  const DayViewRestorationState({
    required this.isOpen,
    required this.kYear,
    required this.kMonth,
    required this.kDay,
    required this.showGregorian,
    this.scrollOffset,
  });

  final bool isOpen;
  final int kYear;
  final int kMonth;
  final int kDay;
  final bool showGregorian;
  final double? scrollOffset;

  DayViewRestorationState copyWith({
    bool? isOpen,
    int? kYear,
    int? kMonth,
    int? kDay,
    bool? showGregorian,
    double? scrollOffset,
    bool clearScrollOffset = false,
  }) {
    return DayViewRestorationState(
      isOpen: isOpen ?? this.isOpen,
      kYear: kYear ?? this.kYear,
      kMonth: kMonth ?? this.kMonth,
      kDay: kDay ?? this.kDay,
      showGregorian: showGregorian ?? this.showGregorian,
      scrollOffset: clearScrollOffset
          ? null
          : (scrollOffset ?? this.scrollOffset),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'isOpen': isOpen,
      'kYear': kYear,
      'kMonth': kMonth,
      'kDay': kDay,
      'showGregorian': showGregorian,
      if (scrollOffset != null) 'scrollOffset': scrollOffset,
    };
  }

  static DayViewRestorationState? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      return null;
    }
    final kYear = (raw['kYear'] as num?)?.toInt();
    final kMonth = (raw['kMonth'] as num?)?.toInt();
    final kDay = (raw['kDay'] as num?)?.toInt();
    if (kYear == null || kMonth == null || kDay == null) {
      return null;
    }
    return DayViewRestorationState(
      isOpen: raw['isOpen'] == true,
      kYear: kYear,
      kMonth: kMonth,
      kDay: kDay,
      showGregorian: raw['showGregorian'] == true,
      scrollOffset: (raw['scrollOffset'] as num?)?.toDouble(),
    );
  }
}

class AppRestorationSnapshot {
  const AppRestorationSnapshot({
    required this.userId,
    required this.windowId,
    required this.updatedAtMs,
    this.routeLocation,
    this.calendar,
    this.dayView,
    this.daySheet,
  });

  final String userId;
  final String windowId;
  final int updatedAtMs;
  final String? routeLocation;
  final CalendarRestorationState? calendar;
  final DayViewRestorationState? dayView;
  final Map<String, dynamic>? daySheet;

  static AppRestorationSnapshot? fromJson(Map<String, dynamic> raw) {
    final userId = (raw['userId'] as String?)?.trim();
    final windowId = (raw['windowId'] as String?)?.trim();
    final updatedAtMs = (raw['updatedAtMs'] as num?)?.toInt();
    if (userId == null ||
        userId.isEmpty ||
        windowId == null ||
        windowId.isEmpty ||
        updatedAtMs == null) {
      return null;
    }

    final daySheetRaw = raw['daySheet'];
    return AppRestorationSnapshot(
      userId: userId,
      windowId: windowId,
      updatedAtMs: updatedAtMs,
      routeLocation: (raw['routeLocation'] as String?)?.trim(),
      calendar: CalendarRestorationState.fromJson(raw['calendar']),
      dayView: DayViewRestorationState.fromJson(raw['dayView']),
      daySheet: daySheetRaw is Map<String, dynamic>
          ? Map<String, dynamic>.from(daySheetRaw)
          : null,
    );
  }
}

class AppRestorationService {
  AppRestorationService._();

  static const int schemaVersion = 1;
  static const String _keyPrefix = 'app_restoration_v1';
  static final AppRestorationService instance = AppRestorationService._();

  static String? Function()? debugUserIdResolver;

  Future<void> initialize() async {
    await AppWindowService.instance.ensureInitialized();
  }

  Future<String?> _currentUserId() async {
    final debugResolver = debugUserIdResolver;
    if (debugResolver != null) {
      final resolved = debugResolver()?.trim();
      return resolved == null || resolved.isEmpty ? null : resolved;
    }
    try {
      final resolved = Supabase.instance.client.auth.currentUser?.id.trim();
      return resolved == null || resolved.isEmpty ? null : resolved;
    } catch (_) {
      return null;
    }
  }

  Future<String> _currentWindowId() =>
      AppWindowService.instance.ensureInitialized();

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  String _prefsKey(String userId, String windowId) =>
      '$_keyPrefix:$userId:$windowId';

  Future<Map<String, dynamic>?> _loadRawFor(
    String userId,
    String windowId, {
    required bool clearIfInvalid,
  }) async {
    final prefs = await _prefs();
    final key = _prefsKey(userId, windowId);
    final rawString = prefs.getString(key);
    if (rawString == null || rawString.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawString);
      if (decoded is! Map<String, dynamic>) {
        if (clearIfInvalid) {
          await prefs.remove(key);
        }
        return null;
      }
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      if (clearIfInvalid) {
        await prefs.remove(key);
      }
      return null;
    }
  }

  Future<AppRestorationSnapshot?> readSnapshot() async {
    final userId = await _currentUserId();
    if (userId == null) {
      return null;
    }
    final windowId = await _currentWindowId();
    final raw = await _loadRawFor(userId, windowId, clearIfInvalid: true);
    if (raw == null) {
      return null;
    }
    return AppRestorationSnapshot.fromJson(raw);
  }

  Future<void> _mutate(
    void Function(Map<String, dynamic> current) update,
  ) async {
    final userId = await _currentUserId();
    if (userId == null) {
      return;
    }
    final windowId = await _currentWindowId();
    final current =
        await _loadRawFor(userId, windowId, clearIfInvalid: false) ??
        <String, dynamic>{};
    update(current);
    current['schemaVersion'] = schemaVersion;
    current['userId'] = userId;
    current['windowId'] = windowId;
    current['updatedAtMs'] = DateTime.now().millisecondsSinceEpoch;
    final prefs = await _prefs();
    await prefs.setString(_prefsKey(userId, windowId), jsonEncode(current));
  }

  Future<void> clearCurrentSnapshot() async {
    final userId = await _currentUserId();
    if (userId == null) {
      return;
    }
    final windowId = await _currentWindowId();
    final prefs = await _prefs();
    await prefs.remove(_prefsKey(userId, windowId));
  }

  Future<String?> readRouteLocation() async {
    final snapshot = await readSnapshot();
    final location = snapshot?.routeLocation?.trim();
    if (location == null || location.isEmpty) {
      return null;
    }
    return location;
  }

  Future<void> saveRouteLocation(String location) async {
    final normalized = location.trim();
    if (normalized.isEmpty) {
      return;
    }
    await _mutate((current) {
      current['routeLocation'] = normalized;
    });
  }

  Future<CalendarRestorationState?> readCalendarState() async {
    return (await readSnapshot())?.calendar;
  }

  Future<void> saveCalendarState(CalendarRestorationState state) async {
    await _mutate((current) {
      current['calendar'] = state.toJson();
    });
  }

  Future<DayViewRestorationState?> readDayViewState() async {
    return (await readSnapshot())?.dayView;
  }

  Future<void> saveDayViewState(DayViewRestorationState? state) async {
    await _mutate((current) {
      if (state == null) {
        current.remove('dayView');
        return;
      }
      current['dayView'] = state.toJson();
    });
  }

  Future<Map<String, dynamic>?> readDaySheetState() async {
    final snapshot = await readSnapshot();
    final raw = snapshot?.daySheet;
    if (raw == null) {
      return null;
    }
    return Map<String, dynamic>.from(raw);
  }

  Future<void> saveDaySheetState(Map<String, dynamic>? state) async {
    await _mutate((current) {
      if (state == null || state.isEmpty) {
        current.remove('daySheet');
      } else {
        current['daySheet'] = state;
      }
    });
  }
}
