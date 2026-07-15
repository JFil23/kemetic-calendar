import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../data/app_restoration_repo.dart';
import '../core/navigation_persistence_policy.dart';
import '../core/route_location_sanitizer.dart';
import 'app_window_service.dart';
import 'app_window_platform_stub.dart'
    if (dart.library.html) 'app_window_platform_web.dart'
    as app_window_platform;
import 'restoration_trace.dart';

const Set<String> _validExpansionValues = <String>{
  'compact',
  'stacked',
  'labeled',
  'details',
};

const Set<String> _validCalendarAnchorTargets = <String>{
  'dayChip',
  'monthHeader',
  'monthBody',
};

const String eventDetailIdentityClientEventId = 'clientEventId';
const String eventDetailIdentityEventId = 'eventId';
const String eventDetailIdentityReminderId = 'reminderId';

const Set<String> _validEventDetailIdentityTypes = <String>{
  eventDetailIdentityClientEventId,
  eventDetailIdentityEventId,
  eventDetailIdentityReminderId,
};

Object? _canonicalJsonValue(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return <String, Object?>{
      for (final key in keys) key: _canonicalJsonValue(value[key]),
    };
  }
  if (value is Iterable) {
    return value.map<Object?>(_canonicalJsonValue).toList(growable: false);
  }
  return value;
}

String _restorationContentDigest(Object? value) {
  return jsonEncode(_canonicalJsonValue(value));
}

String _storedRestorationContentDigest(String serialized) {
  try {
    return _restorationContentDigest(jsonDecode(serialized));
  } catch (_) {
    return _restorationContentDigest(serialized);
  }
}

String _observedRestorationContentDigest(Object value) {
  return value is String
      ? _storedRestorationContentDigest(value)
      : _restorationContentDigest(value);
}

Map<String, dynamic>? _asJsonMap(Object? raw) {
  if (raw is! Map) {
    return null;
  }
  return raw.map<String, dynamic>(
    (dynamic key, dynamic value) => MapEntry(key.toString(), value),
  );
}

Map<String, Map<String, dynamic>> _asJsonMapByKey(Object? raw) {
  if (raw is! Map) {
    return const <String, Map<String, dynamic>>{};
  }
  final result = <String, Map<String, dynamic>>{};
  for (final entry in raw.entries) {
    final key = entry.key.toString().trim();
    final value = _asJsonMap(entry.value);
    if (key.isNotEmpty && value != null) {
      result[key] = value;
    }
  }
  return Map<String, Map<String, dynamic>>.unmodifiable(result);
}

List<Map<String, dynamic>> _asJsonMapList(Object? raw) {
  if (raw is! Iterable) {
    return const <Map<String, dynamic>>[];
  }
  return raw
      .map(_asJsonMap)
      .whereType<Map<String, dynamic>>()
      .map((entry) => Map<String, dynamic>.unmodifiable(entry))
      .toList(growable: false);
}

Object? _coerceJsonValue(Object? value) {
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  if (value is DateTime) {
    return value.toUtc().toIso8601String();
  }
  if (value is Map) {
    final result = <String, dynamic>{};
    for (final entry in value.entries) {
      final key = entry.key.toString().trim();
      if (key.isNotEmpty) {
        result[key] = _coerceJsonValue(entry.value);
      }
    }
    return result;
  }
  if (value is Iterable) {
    return value.map(_coerceJsonValue).toList(growable: false);
  }
  return value.toString();
}

Map<String, dynamic> _coerceJsonMap(Map<String, dynamic> raw) {
  final result = <String, dynamic>{};
  for (final entry in raw.entries) {
    final key = entry.key.trim();
    if (key.isNotEmpty) {
      result[key] = _coerceJsonValue(entry.value);
    }
  }
  return result;
}

Map<String, dynamic> _coerceOverlayEntry(Map<String, dynamic> raw) {
  final result = _coerceJsonMap(raw);
  final parentRoute = stableRouteLocationForContinuity(
    result['parentRoute'] as String?,
  );
  if (parentRoute == null) {
    result.remove('parentRoute');
  } else {
    result['parentRoute'] = parentRoute;
  }
  return result;
}

List<Map<String, dynamic>> _coerceOverlayStack(
  List<Map<String, dynamic>> overlayStack,
) {
  return overlayStack
      .where((entry) => entry.isNotEmpty)
      .map(_coerceOverlayEntry)
      .where((entry) => !_isTransientFlowStudioEditorOverlay(entry))
      .toList(growable: false);
}

bool _isTransientFlowStudioEditorOverlay(Map<String, dynamic> entry) {
  return entry['kind'] == 'calendar.flowStudio' && entry['mode'] == 'editor';
}

int? _overlayEntryUpdatedAtMs(Map<String, dynamic> entry) {
  final updatedAtMs = _asInt(entry['updatedAtMs']);
  if (updatedAtMs == null || updatedAtMs < 0) return null;
  return updatedAtMs;
}

int? _latestOverlayUpdatedAtMs(List<Map<String, dynamic>> overlayStack) {
  int? latest;
  for (final entry in overlayStack) {
    final updatedAtMs = _overlayEntryUpdatedAtMs(entry);
    if (updatedAtMs == null) continue;
    if (latest == null || updatedAtMs > latest) latest = updatedAtMs;
  }
  return latest;
}

List<Map<String, dynamic>> _overlayStackAfterDismissal(
  List<Map<String, dynamic>> overlayStack,
  int? overlayDismissedAtMs,
) {
  final dismissedAt = overlayDismissedAtMs;
  if (dismissedAt == null || dismissedAt < 0 || overlayStack.isEmpty) {
    return overlayStack;
  }
  return overlayStack
      .where((entry) {
        final updatedAtMs = _overlayEntryUpdatedAtMs(entry);
        return updatedAtMs == null || updatedAtMs > dismissedAt;
      })
      .toList(growable: false);
}

int? _asInt(Object? raw) => (raw as num?)?.toInt();

bool _isLeapKemeticYear(int kYear) => ((kYear - 1) % 4 + 4) % 4 == 2;

bool _isValidKemeticMonth(int kMonth) => kMonth >= 1 && kMonth <= 13;

int _maxDayForKemeticMonth(int kYear, int kMonth) {
  if (kMonth == 13) {
    return _isLeapKemeticYear(kYear) ? 6 : 5;
  }
  return 30;
}

bool _isValidKemeticDay(int kYear, int kMonth, int kDay) {
  if (!_isValidKemeticMonth(kMonth)) {
    return false;
  }
  return kDay >= 1 && kDay <= _maxDayForKemeticMonth(kYear, kMonth);
}

double? _readOptionalScrollOffset(Map<String, dynamic> raw) {
  if (!raw.containsKey('scrollOffset') || raw['scrollOffset'] == null) {
    return null;
  }
  final scrollOffset = (raw['scrollOffset'] as num?)?.toDouble();
  if (scrollOffset == null || !scrollOffset.isFinite || scrollOffset < 0) {
    return null;
  }
  return scrollOffset;
}

class CalendarRestorationState {
  const CalendarRestorationState({
    required this.kYear,
    required this.kMonth,
    required this.kDay,
    required this.showGregorian,
    required this.expansion,
    this.anchorTarget,
    this.anchorAlignment,
    this.viewportHeight,
    this.layoutRevision,
    this.scrollOffset,
  });

  final int kYear;
  final int kMonth;
  final int kDay;
  final bool showGregorian;
  final String expansion;
  final String? anchorTarget;
  final double? anchorAlignment;
  final double? viewportHeight;
  final int? layoutRevision;
  final double? scrollOffset;

  CalendarRestorationState copyWith({
    int? kYear,
    int? kMonth,
    int? kDay,
    bool? showGregorian,
    String? expansion,
    String? anchorTarget,
    double? anchorAlignment,
    double? viewportHeight,
    int? layoutRevision,
    double? scrollOffset,
    bool clearAnchorTarget = false,
    bool clearAnchorAlignment = false,
    bool clearViewportHeight = false,
    bool clearLayoutRevision = false,
    bool clearScrollOffset = false,
  }) {
    return CalendarRestorationState(
      kYear: kYear ?? this.kYear,
      kMonth: kMonth ?? this.kMonth,
      kDay: kDay ?? this.kDay,
      showGregorian: showGregorian ?? this.showGregorian,
      expansion: expansion ?? this.expansion,
      anchorTarget: clearAnchorTarget
          ? null
          : (anchorTarget ?? this.anchorTarget),
      anchorAlignment: clearAnchorAlignment
          ? null
          : (anchorAlignment ?? this.anchorAlignment),
      viewportHeight: clearViewportHeight
          ? null
          : (viewportHeight ?? this.viewportHeight),
      layoutRevision: clearLayoutRevision
          ? null
          : (layoutRevision ?? this.layoutRevision),
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
      if (anchorTarget != null) 'anchorTarget': anchorTarget,
      if (anchorAlignment != null) 'anchorAlignment': anchorAlignment,
      if (viewportHeight != null) 'viewportHeight': viewportHeight,
      if (layoutRevision != null) 'layoutRevision': layoutRevision,
      if (scrollOffset != null) 'scrollOffset': scrollOffset,
    };
  }

  static CalendarRestorationState? fromJson(Object? raw) {
    final json = _asJsonMap(raw);
    if (json == null) {
      return null;
    }
    final kYear = _asInt(json['kYear']);
    final kMonth = _asInt(json['kMonth']);
    final kDay = _asInt(json['kDay']);
    final showGregorian = json['showGregorian'] == true;
    final expansion = (json['expansion'] as String?)?.trim();
    final anchorTarget = (json['anchorTarget'] as String?)?.trim();
    final anchorAlignment = (json['anchorAlignment'] as num?)?.toDouble();
    final viewportHeight = (json['viewportHeight'] as num?)?.toDouble();
    final layoutRevision = _asInt(json['layoutRevision']);
    // Older centered calendar trees could persist negative raw offsets. The
    // logical Kemetic date remains valid even when that optional pixel is not.
    final scrollOffset = _readOptionalScrollOffset(json);
    if (kYear == null ||
        kMonth == null ||
        kDay == null ||
        expansion == null ||
        !_validExpansionValues.contains(expansion) ||
        !_isValidKemeticDay(kYear, kMonth, kDay) ||
        (json.containsKey('anchorTarget') &&
            json['anchorTarget'] != null &&
            (anchorTarget == null ||
                anchorTarget.isEmpty ||
                !_validCalendarAnchorTargets.contains(anchorTarget))) ||
        (json.containsKey('anchorAlignment') &&
            json['anchorAlignment'] != null &&
            (anchorAlignment == null ||
                !anchorAlignment.isFinite ||
                anchorAlignment < 0 ||
                anchorAlignment > 1)) ||
        (json.containsKey('viewportHeight') &&
            json['viewportHeight'] != null &&
            (viewportHeight == null ||
                !viewportHeight.isFinite ||
                viewportHeight <= 0)) ||
        (json.containsKey('layoutRevision') &&
            json['layoutRevision'] != null &&
            (layoutRevision == null || layoutRevision < 1))) {
      return null;
    }
    return CalendarRestorationState(
      kYear: kYear,
      kMonth: kMonth,
      kDay: kDay,
      showGregorian: showGregorian,
      expansion: expansion,
      anchorTarget: anchorTarget,
      anchorAlignment: anchorAlignment,
      viewportHeight: viewportHeight,
      layoutRevision: layoutRevision,
      scrollOffset: scrollOffset,
    );
  }
}

class EventDetailRestorationState {
  const EventDetailRestorationState({
    required this.kYear,
    required this.kMonth,
    required this.kDay,
    required this.identityType,
    required this.identityValue,
    this.parentSurface,
    this.updatedAtMs,
  });

  final int kYear;
  final int kMonth;
  final int kDay;
  final String identityType;
  final String identityValue;
  final String? parentSurface;
  final int? updatedAtMs;

  EventDetailRestorationState copyWith({
    int? kYear,
    int? kMonth,
    int? kDay,
    String? identityType,
    String? identityValue,
    String? parentSurface,
    int? updatedAtMs,
    bool clearParentSurface = false,
    bool clearUpdatedAtMs = false,
  }) {
    return EventDetailRestorationState(
      kYear: kYear ?? this.kYear,
      kMonth: kMonth ?? this.kMonth,
      kDay: kDay ?? this.kDay,
      identityType: identityType ?? this.identityType,
      identityValue: identityValue ?? this.identityValue,
      parentSurface: clearParentSurface
          ? null
          : (parentSurface ?? this.parentSurface),
      updatedAtMs: clearUpdatedAtMs ? null : (updatedAtMs ?? this.updatedAtMs),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'kYear': kYear,
      'kMonth': kMonth,
      'kDay': kDay,
      'identityType': identityType,
      'identityValue': identityValue,
      if (parentSurface != null && parentSurface!.trim().isNotEmpty)
        'parentSurface': parentSurface!.trim(),
      if (updatedAtMs != null) 'updatedAtMs': updatedAtMs,
    };
  }

  static EventDetailRestorationState? fromJson(Object? raw) {
    final json = _asJsonMap(raw);
    if (json == null) {
      return null;
    }

    final kYear = _asInt(json['kYear']);
    final kMonth = _asInt(json['kMonth']);
    final kDay = _asInt(json['kDay']);
    final identityType = (json['identityType'] as String?)?.trim();
    final identityValue = (json['identityValue'] as String?)?.trim();
    final parentSurface = (json['parentSurface'] as String?)?.trim();
    final updatedAtMs = _asInt(json['updatedAtMs']);

    if (kYear == null ||
        kMonth == null ||
        kDay == null ||
        !_isValidKemeticDay(kYear, kMonth, kDay) ||
        identityType == null ||
        !_validEventDetailIdentityTypes.contains(identityType) ||
        identityValue == null ||
        identityValue.isEmpty ||
        (json.containsKey('updatedAtMs') &&
            json['updatedAtMs'] != null &&
            (updatedAtMs == null || updatedAtMs < 0))) {
      return null;
    }

    return EventDetailRestorationState(
      kYear: kYear,
      kMonth: kMonth,
      kDay: kDay,
      identityType: identityType,
      identityValue: identityValue,
      parentSurface: parentSurface == null || parentSurface.isEmpty
          ? null
          : parentSurface,
      updatedAtMs: updatedAtMs,
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
    this.firstVisibleMinute,
    this.scrollOffset,
    this.eventDetail,
  });

  final bool isOpen;
  final int kYear;
  final int kMonth;
  final int kDay;
  final bool showGregorian;
  final int? firstVisibleMinute;
  final double? scrollOffset;
  final EventDetailRestorationState? eventDetail;

  DayViewRestorationState copyWith({
    bool? isOpen,
    int? kYear,
    int? kMonth,
    int? kDay,
    bool? showGregorian,
    int? firstVisibleMinute,
    double? scrollOffset,
    EventDetailRestorationState? eventDetail,
    bool clearFirstVisibleMinute = false,
    bool clearScrollOffset = false,
    bool clearEventDetail = false,
  }) {
    return DayViewRestorationState(
      isOpen: isOpen ?? this.isOpen,
      kYear: kYear ?? this.kYear,
      kMonth: kMonth ?? this.kMonth,
      kDay: kDay ?? this.kDay,
      showGregorian: showGregorian ?? this.showGregorian,
      firstVisibleMinute: clearFirstVisibleMinute
          ? null
          : (firstVisibleMinute ?? this.firstVisibleMinute),
      scrollOffset: clearScrollOffset
          ? null
          : (scrollOffset ?? this.scrollOffset),
      eventDetail: clearEventDetail ? null : (eventDetail ?? this.eventDetail),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'isOpen': isOpen,
      'kYear': kYear,
      'kMonth': kMonth,
      'kDay': kDay,
      'showGregorian': showGregorian,
      if (firstVisibleMinute != null) 'firstVisibleMinute': firstVisibleMinute,
      if (scrollOffset != null) 'scrollOffset': scrollOffset,
      if (eventDetail != null) 'eventDetail': eventDetail!.toJson(),
    };
  }

  static DayViewRestorationState? fromJson(Object? raw) {
    final json = _asJsonMap(raw);
    if (json == null) {
      return null;
    }
    final kYear = _asInt(json['kYear']);
    final kMonth = _asInt(json['kMonth']);
    final kDay = _asInt(json['kDay']);
    final firstVisibleMinute = _asInt(json['firstVisibleMinute']);
    final scrollOffset = _readOptionalScrollOffset(json);
    if (kYear == null ||
        kMonth == null ||
        kDay == null ||
        !_isValidKemeticDay(kYear, kMonth, kDay) ||
        (json.containsKey('firstVisibleMinute') &&
            json['firstVisibleMinute'] != null &&
            (firstVisibleMinute == null ||
                firstVisibleMinute < 0 ||
                firstVisibleMinute > 24 * 60 - 1)) ||
        (json.containsKey('scrollOffset') &&
            json['scrollOffset'] != null &&
            scrollOffset == null)) {
      return null;
    }
    return DayViewRestorationState(
      isOpen: json['isOpen'] == true,
      kYear: kYear,
      kMonth: kMonth,
      kDay: kDay,
      showGregorian: json['showGregorian'] == true,
      firstVisibleMinute: firstVisibleMinute,
      scrollOffset: scrollOffset,
      eventDetail: EventDetailRestorationState.fromJson(json['eventDetail']),
    );
  }
}

class AppRestorationSnapshot {
  const AppRestorationSnapshot({
    required this.userId,
    required this.windowId,
    required this.updatedAtMs,
    this.routeLocation,
    this.launchRouteMetadata,
    this.primarySelectionMetadata,
    this.calendar,
    this.dayView,
    this.daySheet,
    this.surfaces = const <String, Map<String, dynamic>>{},
    this.overlayStack = const <Map<String, dynamic>>[],
    this.overlayDismissedAtMs,
    this.editors = const <String, Map<String, dynamic>>{},
    this.cacheHints,
  });

  final String userId;
  final String windowId;
  final int updatedAtMs;
  final String? routeLocation;
  final NavigationLaunchRouteMetadata? launchRouteMetadata;
  final NavigationLaunchRouteMetadata? primarySelectionMetadata;
  final CalendarRestorationState? calendar;
  final DayViewRestorationState? dayView;
  final Map<String, dynamic>? daySheet;
  final Map<String, Map<String, dynamic>> surfaces;
  final List<Map<String, dynamic>> overlayStack;
  final int? overlayDismissedAtMs;
  final Map<String, Map<String, dynamic>> editors;
  final Map<String, dynamic>? cacheHints;

  static AppRestorationSnapshot? fromJson(Map<String, dynamic> raw) {
    final userId = (raw['userId'] as String?)?.trim();
    final windowId = (raw['windowId'] as String?)?.trim();
    final updatedAtMs = _asInt(raw['updatedAtMs']);
    if (userId == null ||
        userId.isEmpty ||
        windowId == null ||
        windowId.isEmpty ||
        updatedAtMs == null) {
      return null;
    }

    final routeMetadata = NavigationLaunchRouteMetadata.fromJson(
      raw[navigationLaunchRouteMetadataKey],
    );
    final policy = const NavigationPersistencePolicy();
    final sanitizedRouteLocation = stableRouteLocationForContinuity(
      raw['routeLocation'] as String?,
    );
    final routeLocation =
        policy.isValidDurableSurfaceRoute(sanitizedRouteLocation, routeMetadata)
        ? sanitizedRouteLocation
        : null;
    final rawPrimaryMetadata = NavigationLaunchRouteMetadata.fromJson(
      raw[navigationPrimarySelectionMetadataKey],
    );
    final legacyPrimaryMetadata =
        routeMetadata != null && policy.isValidPrimarySelection(routeMetadata)
        ? routeMetadata
        : null;
    final primarySelectionMetadata =
        policy.isValidPrimarySelection(rawPrimaryMetadata)
        ? rawPrimaryMetadata
        : legacyPrimaryMetadata;
    final daySheetRaw = raw['daySheet'];
    final overlayDismissedAtMs = _asInt(raw['overlayDismissedAtMs']);
    final overlayStack = _overlayStackAfterDismissal(
      _asJsonMapList(raw['overlayStack']),
      overlayDismissedAtMs,
    );
    return AppRestorationSnapshot(
      userId: userId,
      windowId: windowId,
      updatedAtMs: updatedAtMs,
      routeLocation: routeLocation,
      launchRouteMetadata: routeLocation == null ? null : routeMetadata,
      primarySelectionMetadata: primarySelectionMetadata,
      calendar: CalendarRestorationState.fromJson(raw['calendar']),
      dayView: DayViewRestorationState.fromJson(raw['dayView']),
      daySheet: _asJsonMap(daySheetRaw),
      surfaces: _asJsonMapByKey(raw['surfaces']),
      overlayStack: overlayStack,
      overlayDismissedAtMs: overlayDismissedAtMs,
      editors: _asJsonMapByKey(raw['editors']),
      cacheHints: _asJsonMap(raw['cacheHints']),
    );
  }
}

enum OverlayStackMutationReason {
  programmatic,
  userDismissed,
  lifecyclePause,
  routeDetachDuringPause,
}

enum AppRestorationReadStatus { restored, tentative, noSnapshot, awaitingAuth }

enum AppRestorationMutationStatus {
  persisted,
  deferred,
  notReady,
  invalid,
  superseded,
  droppedUserMismatch,
}

class AppRestorationMutationResult {
  const AppRestorationMutationResult(this.status);

  final AppRestorationMutationStatus status;
}

class AppRestorationReadResult {
  const AppRestorationReadResult({
    required this.status,
    required this.windowId,
    required this.activeUserId,
    this.snapshot,
    this.source,
    this.reason,
  });

  final AppRestorationReadStatus status;
  final String windowId;
  final String? activeUserId;
  final AppRestorationSnapshot? snapshot;
  final String? source;
  final String? reason;

  bool get hasSnapshot => snapshot != null;
  bool get isTentative => status == AppRestorationReadStatus.tentative;
  bool get isAwaitingAuth => status == AppRestorationReadStatus.awaitingAuth;
}

class _SnapshotCandidate {
  const _SnapshotCandidate({
    required this.snapshot,
    required this.raw,
    required this.source,
    this.precedenceSource,
  });

  final AppRestorationSnapshot snapshot;
  final Map<String, dynamic> raw;
  final String source;
  final String? precedenceSource;

  String get sourceForPrecedence => precedenceSource ?? source;
}

class _PendingCalendarRestorationIntent {
  const _PendingCalendarRestorationIntent({
    required this.userId,
    required this.windowId,
    required this.state,
  });

  final String userId;
  final String windowId;
  final CalendarRestorationState state;
}

class _PendingLaunchRouteRestorationIntent {
  const _PendingLaunchRouteRestorationIntent({
    required this.userId,
    required this.windowId,
    required this.location,
    required this.metadata,
  });

  final String userId;
  final String windowId;
  final String location;
  final NavigationLaunchRouteMetadata metadata;
}

String _snapshotTrace(AppRestorationSnapshot? snapshot) {
  if (snapshot == null) return '<none>';
  return 'route=${snapshot.routeLocation ?? '<none>'} '
      'updatedAtMs=${snapshot.updatedAtMs} '
      'overlayCount=${snapshot.overlayStack.length} '
      'overlayDismissedAtMs=${snapshot.overlayDismissedAtMs ?? '<none>'} '
      'overlay=${_overlayStackTrace(snapshot.overlayStack)} '
      'user=${snapshot.userId} window=${snapshot.windowId}';
}

String _candidateTrace(_SnapshotCandidate? candidate) {
  if (candidate == null) return '<none>';
  return 'source=${candidate.source} ${_snapshotTrace(candidate.snapshot)}';
}

String _overlayStackTrace(List<Map<String, dynamic>> overlayStack) {
  if (overlayStack.isEmpty) return '<empty>';
  return overlayStack
      .map((entry) {
        final kind = (entry['kind'] as String?)?.trim();
        final parentRoute = (entry['parentRoute'] as String?)?.trim();
        final mode = (entry['mode'] as String?)?.trim();
        final updatedAtMs = entry['updatedAtMs'];
        return '{kind=${kind == null || kind.isEmpty ? '<none>' : kind},'
            'parent=${parentRoute == null || parentRoute.isEmpty ? '<none>' : parentRoute},'
            'mode=${mode == null || mode.isEmpty ? '<none>' : mode},'
            'updatedAtMs=${updatedAtMs ?? '<none>'}}';
      })
      .join(',');
}

class AppRestorationService {
  AppRestorationService._();

  static const int schemaVersion = 1;
  static const String _keyPrefix = 'app_restoration_v1';
  static const String _latestUserKeyPrefix = 'app_restoration_latest_v2';
  static const String _lastActiveUserKey = 'app_restoration_last_user_v2';
  static const String _deviceIdPrefsKey = 'app_restoration_device_id_v1';
  static final AppRestorationService instance = AppRestorationService._();

  static String? Function()? debugUserIdResolver;
  static Future<Map<String, dynamic>?> Function(
    String userId,
    String deviceId,
    String windowId,
  )?
  debugRemoteWindowSnapshotReader;
  static Future<Map<String, dynamic>?> Function(String userId)?
  debugRemoteLatestSnapshotReader;
  static Future<void> Function(
    String userId,
    String deviceId,
    String windowId,
    Map<String, dynamic> snapshot,
  )?
  debugRemoteSnapshotWriter;
  static String? Function(String windowId)? debugCriticalSnapshotReader;
  static void Function(String windowId, String? serialized)?
  debugCriticalSnapshotWriter;
  static String? Function(String userId)? debugLatestCriticalSnapshotReader;
  static void Function(String userId, String? serialized)?
  debugLatestCriticalSnapshotWriter;
  static String? Function()? debugPlatformLastActiveUserIdReader;
  static void Function(String? userId)? debugPlatformLastActiveUserIdWriter;
  static void Function(String message)? debugLogWriter;
  static Future<void> Function()? debugBeforeMutationProvenanceRead;

  /// Tie-break order for divergent snapshots with the same provenance time.
  ///
  /// Current-window stores outrank cross-window/latest stores, and every local
  /// store outranks remote state. Higher values are more authoritative.
  static const Map<String, int> _snapshotSourcePrecedence = <String, int>{
    'prefs': 500,
    'critical': 400,
    'latest_prefs': 300,
    'latest_critical': 200,
    'remote_window': 100,
    'remote_latest': 90,
  };

  String? _deviceId;
  Future<String>? _deviceIdFuture;
  Future<void> _mutationQueue = Future<void>.value();
  Future<void> _remoteWriteQueue = Future<void>.value();
  _PendingCalendarRestorationIntent? _pendingCalendarIntent;
  _PendingLaunchRouteRestorationIntent? _pendingLaunchRouteIntent;

  void resetForTesting() {
    _deviceId = null;
    _deviceIdFuture = null;
    _mutationQueue = Future<void>.value();
    _remoteWriteQueue = Future<void>.value();
    _pendingCalendarIntent = null;
    _pendingLaunchRouteIntent = null;
    debugLogWriter = null;
    debugBeforeMutationProvenanceRead = null;
  }

  Future<void> initialize() async {
    final windowId = await AppWindowService.instance.ensureInitialized();
    app_window_platform.registerCriticalSnapshotWindow(windowId);
  }

  void _log(String message) {
    debugLogWriter?.call(message);
    traceRestoration(message);
  }

  String? _currentUserIdNow() {
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

  Future<String?> _currentUserId() async => _currentUserIdNow();

  Future<String> _currentWindowId() =>
      AppWindowService.instance.ensureInitialized();

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<T> _enqueueMutationOperation<T>(Future<T> Function() operation) {
    final next = _mutationQueue.then((_) => operation());
    _mutationQueue = next.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return next;
  }

  String? _readCriticalSnapshot(String windowId) {
    final debugReader = debugCriticalSnapshotReader;
    return debugReader != null
        ? debugReader(windowId)
        : app_window_platform.readCriticalSnapshot(windowId);
  }

  String? _readLatestCriticalSnapshot(String userId) {
    final debugReader = debugLatestCriticalSnapshotReader;
    return debugReader != null
        ? debugReader(userId)
        : app_window_platform.readLatestCriticalSnapshot(userId);
  }

  Future<void> _queuePrefsChangeIfUnchanged({
    required String key,
    required Object observedContent,
    required String? replacement,
    required String reason,
  }) {
    final expectedDigest = _observedRestorationContentDigest(observedContent);
    return _enqueueMutationOperation(() async {
      final prefs = await _prefs();
      final current = prefs.getString(key);
      if (current == null ||
          _storedRestorationContentDigest(current) != expectedDigest) {
        _log(
          'conditional prefs change skipped key=$key reason=content_changed',
        );
        return;
      }
      if (replacement == null) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, replacement);
      }
      _log('conditional prefs change committed key=$key reason=$reason');
    });
  }

  Future<void> _queueCriticalChangeIfUnchanged({
    required String storageKey,
    required Object observedContent,
    required String? replacement,
    required String reason,
    required String? Function() readCurrent,
    required void Function(String? serialized) writeCurrent,
  }) {
    final expectedDigest = _observedRestorationContentDigest(observedContent);
    return _enqueueMutationOperation(() async {
      final current = readCurrent();
      if (current == null ||
          _storedRestorationContentDigest(current) != expectedDigest) {
        _log(
          'conditional critical change skipped key=$storageKey '
          'reason=content_changed',
        );
        return;
      }
      writeCurrent(replacement);
      _log(
        'conditional critical change committed key=$storageKey reason=$reason',
      );
    });
  }

  Future<String> _currentDeviceId() {
    final cached = _deviceId;
    if (cached != null && cached.isNotEmpty) {
      return Future<String>.value(cached);
    }
    final inFlight = _deviceIdFuture;
    if (inFlight != null) {
      return inFlight;
    }
    _deviceIdFuture = () async {
      final prefs = await _prefs();
      final existing = prefs.getString(_deviceIdPrefsKey)?.trim();
      if (existing != null && existing.isNotEmpty) {
        _deviceId = existing;
        return existing;
      }
      final generated = const Uuid().v4();
      await prefs.setString(_deviceIdPrefsKey, generated);
      _deviceId = generated;
      return generated;
    }();
    return _deviceIdFuture!;
  }

  AppRestorationRepo? _remoteRepo() {
    try {
      return AppRestorationRepo(Supabase.instance.client);
    } catch (_) {
      return null;
    }
  }

  String _prefsKey(String userId, String windowId) =>
      '$_keyPrefix:$userId:$windowId';

  String _latestPrefsKey(String userId) => '$_latestUserKeyPrefix:$userId';

  Future<String?> _readLastActiveUserId() async {
    final prefs = await _prefs();
    final raw = prefs.getString(_lastActiveUserKey)?.trim();
    return raw == null || raw.isEmpty ? null : raw;
  }

  String? _readPlatformLastActiveUserId() {
    final debugReader = debugPlatformLastActiveUserIdReader;
    final raw = debugReader != null
        ? debugReader()?.trim()
        : app_window_platform.readPlatformLastActiveUserId()?.trim();
    return raw == null || raw.isEmpty ? null : raw;
  }

  void _writePlatformLastActiveUserId(String? userId) {
    final debugWriter = debugPlatformLastActiveUserIdWriter;
    if (debugWriter != null) {
      debugWriter(userId);
      return;
    }
    app_window_platform.updatePlatformLastActiveUserId(userId);
  }

  Future<String?> _readBootFallbackUserId() async {
    final fromPrefs = await _readLastActiveUserId();
    if (fromPrefs != null) {
      return fromPrefs;
    }
    return _readPlatformLastActiveUserId();
  }

  Future<void> clearBootFallbackIdentity() async {
    final prefs = await _prefs();
    await prefs.remove(_lastActiveUserKey);
    _writePlatformLastActiveUserId(null);
    final windowId = await _currentWindowId();
    _writeCriticalSnapshot(windowId, null);
    _log('cleared boot fallback identity window=$windowId');
  }

  Map<String, dynamic>? _migrateRawSnapshot(Map<String, dynamic> raw) {
    final version = _asInt(raw['schemaVersion']);
    if (version == null) {
      return null;
    }
    switch (version) {
      case schemaVersion:
        final migrated = Map<String, dynamic>.from(raw);
        final routeMetadata = NavigationLaunchRouteMetadata.fromJson(
          migrated[navigationLaunchRouteMetadataKey],
        );
        final policy = const NavigationPersistencePolicy();
        final sanitizedRouteLocation = stableRouteLocationForContinuity(
          migrated['routeLocation'] as String?,
        );
        final routeLocation =
            policy.isValidDurableSurfaceRoute(
              sanitizedRouteLocation,
              routeMetadata,
            )
            ? sanitizedRouteLocation
            : null;
        if (routeLocation == null || routeMetadata == null) {
          migrated.remove('routeLocation');
          migrated.remove(navigationLaunchRouteMetadataKey);
        } else {
          migrated['routeLocation'] = routeLocation;
          migrated[navigationLaunchRouteMetadataKey] = routeMetadata.toJson();
        }
        final primaryMetadata = NavigationLaunchRouteMetadata.fromJson(
          migrated[navigationPrimarySelectionMetadataKey],
        );
        final legacyPrimaryMetadata =
            routeMetadata != null &&
                policy.isValidPrimarySelection(routeMetadata)
            ? routeMetadata
            : null;
        final validPrimaryMetadata =
            policy.isValidPrimarySelection(primaryMetadata)
            ? primaryMetadata
            : legacyPrimaryMetadata;
        if (validPrimaryMetadata == null) {
          migrated.remove(navigationPrimarySelectionMetadataKey);
        } else {
          migrated[navigationPrimarySelectionMetadataKey] = validPrimaryMetadata
              .toJson();
        }
        final overlayStack = _coerceOverlayStack(
          _asJsonMapList(migrated['overlayStack']),
        );
        final overlayDismissedAtMs = _asInt(migrated['overlayDismissedAtMs']);
        if (overlayDismissedAtMs == null || overlayDismissedAtMs < 0) {
          migrated.remove('overlayDismissedAtMs');
        } else {
          migrated['overlayDismissedAtMs'] = overlayDismissedAtMs;
        }
        if (overlayStack.isEmpty) {
          migrated.remove('overlayStack');
        } else {
          final survivingOverlayStack = _overlayStackAfterDismissal(
            overlayStack,
            overlayDismissedAtMs,
          );
          if (survivingOverlayStack.isEmpty) {
            migrated.remove('overlayStack');
          } else {
            migrated['overlayStack'] = survivingOverlayStack;
          }
        }
        return migrated;
      default:
        return null;
    }
  }

  bool _rawSnapshotChanged(
    Map<String, dynamic> original,
    Map<String, dynamic> migrated,
  ) {
    return jsonEncode(original) != jsonEncode(migrated);
  }

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
          await _queuePrefsChangeIfUnchanged(
            key: key,
            observedContent: rawString,
            replacement: null,
            reason: 'invalid_json_shape',
          );
        }
        return null;
      }
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      if (clearIfInvalid) {
        await _queuePrefsChangeIfUnchanged(
          key: key,
          observedContent: rawString,
          replacement: null,
          reason: 'invalid_json',
        );
      }
      return null;
    }
  }

  Future<Map<String, dynamic>?> _loadLatestRawForUser(
    String userId, {
    required bool clearIfInvalid,
  }) async {
    final prefs = await _prefs();
    final key = _latestPrefsKey(userId);
    final rawString = prefs.getString(key);
    if (rawString == null || rawString.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawString);
      if (decoded is! Map<String, dynamic>) {
        if (clearIfInvalid) {
          await _queuePrefsChangeIfUnchanged(
            key: key,
            observedContent: rawString,
            replacement: null,
            reason: 'invalid_json_shape',
          );
        }
        return null;
      }
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      if (clearIfInvalid) {
        await _queuePrefsChangeIfUnchanged(
          key: key,
          observedContent: rawString,
          replacement: null,
          reason: 'invalid_json',
        );
      }
      return null;
    }
  }

  Future<Map<String, dynamic>?> _loadCriticalRawFor(
    String windowId, {
    required bool clearIfInvalid,
  }) async {
    final rawString = _readCriticalSnapshot(windowId);
    if (rawString == null || rawString.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawString);
      if (decoded is! Map<String, dynamic>) {
        if (clearIfInvalid) {
          await _queueCriticalChangeIfUnchanged(
            storageKey: 'critical:$windowId',
            observedContent: rawString,
            replacement: null,
            reason: 'invalid_json_shape',
            readCurrent: () => _readCriticalSnapshot(windowId),
            writeCurrent: (serialized) =>
                _writeCriticalSnapshot(windowId, serialized),
          );
        }
        return null;
      }
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      if (clearIfInvalid) {
        await _queueCriticalChangeIfUnchanged(
          storageKey: 'critical:$windowId',
          observedContent: rawString,
          replacement: null,
          reason: 'invalid_json',
          readCurrent: () => _readCriticalSnapshot(windowId),
          writeCurrent: (serialized) =>
              _writeCriticalSnapshot(windowId, serialized),
        );
      }
      return null;
    }
  }

  Future<Map<String, dynamic>?> _loadLatestCriticalRawForUser(
    String userId, {
    required bool clearIfInvalid,
  }) async {
    final rawString = _readLatestCriticalSnapshot(userId);
    if (rawString == null || rawString.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawString);
      if (decoded is! Map<String, dynamic>) {
        if (clearIfInvalid) {
          await _queueCriticalChangeIfUnchanged(
            storageKey: 'latest_critical:$userId',
            observedContent: rawString,
            replacement: null,
            reason: 'invalid_json_shape',
            readCurrent: () => _readLatestCriticalSnapshot(userId),
            writeCurrent: (serialized) =>
                _writeLatestCriticalSnapshot(userId, serialized),
          );
        }
        return null;
      }
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      if (clearIfInvalid) {
        await _queueCriticalChangeIfUnchanged(
          storageKey: 'latest_critical:$userId',
          observedContent: rawString,
          replacement: null,
          reason: 'invalid_json',
          readCurrent: () => _readLatestCriticalSnapshot(userId),
          writeCurrent: (serialized) =>
              _writeLatestCriticalSnapshot(userId, serialized),
        );
      }
      return null;
    }
  }

  Future<_SnapshotCandidate?> _loadPrefsCandidate(
    String userId,
    String windowId, {
    required bool clearIfInvalid,
    String precedenceSource = 'prefs',
  }) async {
    final raw = await _loadRawFor(
      userId,
      windowId,
      clearIfInvalid: clearIfInvalid,
    );
    if (raw == null) {
      return null;
    }
    final migrated = _migrateRawSnapshot(raw);
    if (migrated == null) {
      if (clearIfInvalid) {
        await _queuePrefsChangeIfUnchanged(
          key: _prefsKey(userId, windowId),
          observedContent: raw,
          replacement: null,
          reason: 'unsupported_snapshot',
        );
      }
      return null;
    }
    final snapshot = AppRestorationSnapshot.fromJson(migrated);
    if (snapshot == null ||
        snapshot.userId != userId ||
        snapshot.windowId != windowId) {
      if (clearIfInvalid) {
        await _queuePrefsChangeIfUnchanged(
          key: _prefsKey(userId, windowId),
          observedContent: raw,
          replacement: null,
          reason: 'snapshot_mismatch',
        );
      }
      _log(
        'candidate rejected source=prefs user=$userId window=$windowId '
        'reason=snapshot_mismatch',
      );
      return null;
    }
    if (clearIfInvalid && _rawSnapshotChanged(raw, migrated)) {
      await _queuePrefsChangeIfUnchanged(
        key: _prefsKey(userId, windowId),
        observedContent: raw,
        replacement: jsonEncode(migrated),
        reason: 'snapshot_migration',
      );
    }
    final candidate = _SnapshotCandidate(
      snapshot: snapshot,
      raw: migrated,
      source: 'prefs',
      precedenceSource: precedenceSource,
    );
    _log('candidate loaded ${_candidateTrace(candidate)}');
    return candidate;
  }

  Future<_SnapshotCandidate?> _loadCriticalCandidate(
    String windowId, {
    String? expectedUserId,
    required bool clearIfInvalid,
  }) async {
    final raw = await _loadCriticalRawFor(
      windowId,
      clearIfInvalid: clearIfInvalid,
    );
    if (raw == null) {
      return null;
    }
    final migrated = _migrateRawSnapshot(raw);
    if (migrated == null) {
      if (clearIfInvalid) {
        await _queueCriticalChangeIfUnchanged(
          storageKey: 'critical:$windowId',
          observedContent: raw,
          replacement: null,
          reason: 'unsupported_snapshot',
          readCurrent: () => _readCriticalSnapshot(windowId),
          writeCurrent: (serialized) =>
              _writeCriticalSnapshot(windowId, serialized),
        );
      }
      return null;
    }
    final snapshot = AppRestorationSnapshot.fromJson(migrated);
    final userMismatch =
        expectedUserId != null &&
        snapshot != null &&
        snapshot.userId != expectedUserId;
    if (snapshot == null || snapshot.windowId != windowId || userMismatch) {
      if (clearIfInvalid) {
        await _queueCriticalChangeIfUnchanged(
          storageKey: 'critical:$windowId',
          observedContent: raw,
          replacement: null,
          reason: 'snapshot_mismatch',
          readCurrent: () => _readCriticalSnapshot(windowId),
          writeCurrent: (serialized) =>
              _writeCriticalSnapshot(windowId, serialized),
        );
      }
      _log(
        'candidate rejected source=critical window=$windowId '
        'expectedUser=${expectedUserId ?? '<any>'} reason=snapshot_mismatch',
      );
      return null;
    }
    if (clearIfInvalid && _rawSnapshotChanged(raw, migrated)) {
      await _queueCriticalChangeIfUnchanged(
        storageKey: 'critical:$windowId',
        observedContent: raw,
        replacement: jsonEncode(migrated),
        reason: 'snapshot_migration',
        readCurrent: () => _readCriticalSnapshot(windowId),
        writeCurrent: (serialized) =>
            _writeCriticalSnapshot(windowId, serialized),
      );
    }
    final candidate = _SnapshotCandidate(
      snapshot: snapshot,
      raw: migrated,
      source: 'critical',
    );
    _log('candidate loaded ${_candidateTrace(candidate)}');
    return candidate;
  }

  Future<_SnapshotCandidate?> _loadLatestPrefsCandidate(
    String userId, {
    required bool clearIfInvalid,
  }) async {
    final raw = await _loadLatestRawForUser(
      userId,
      clearIfInvalid: clearIfInvalid,
    );
    if (raw == null) {
      return null;
    }
    final migrated = _migrateRawSnapshot(raw);
    if (migrated == null) {
      if (clearIfInvalid) {
        await _queuePrefsChangeIfUnchanged(
          key: _latestPrefsKey(userId),
          observedContent: raw,
          replacement: null,
          reason: 'unsupported_snapshot',
        );
      }
      return null;
    }
    final snapshot = AppRestorationSnapshot.fromJson(migrated);
    if (snapshot == null || snapshot.userId != userId) {
      if (clearIfInvalid) {
        await _queuePrefsChangeIfUnchanged(
          key: _latestPrefsKey(userId),
          observedContent: raw,
          replacement: null,
          reason: 'snapshot_mismatch',
        );
      }
      _log(
        'candidate rejected source=latest_prefs user=$userId '
        'reason=snapshot_mismatch',
      );
      return null;
    }
    if (clearIfInvalid && _rawSnapshotChanged(raw, migrated)) {
      await _queuePrefsChangeIfUnchanged(
        key: _latestPrefsKey(userId),
        observedContent: raw,
        replacement: jsonEncode(migrated),
        reason: 'snapshot_migration',
      );
    }
    final candidate = _SnapshotCandidate(
      snapshot: snapshot,
      raw: migrated,
      source: 'latest_prefs',
    );
    _log('candidate loaded ${_candidateTrace(candidate)}');
    return candidate;
  }

  Future<_SnapshotCandidate?> _loadLatestCriticalCandidate(
    String userId, {
    required bool clearIfInvalid,
  }) async {
    final raw = await _loadLatestCriticalRawForUser(
      userId,
      clearIfInvalid: clearIfInvalid,
    );
    if (raw == null) {
      return null;
    }
    final migrated = _migrateRawSnapshot(raw);
    if (migrated == null) {
      if (clearIfInvalid) {
        await _queueCriticalChangeIfUnchanged(
          storageKey: 'latest_critical:$userId',
          observedContent: raw,
          replacement: null,
          reason: 'unsupported_snapshot',
          readCurrent: () => _readLatestCriticalSnapshot(userId),
          writeCurrent: (serialized) =>
              _writeLatestCriticalSnapshot(userId, serialized),
        );
      }
      return null;
    }
    final snapshot = AppRestorationSnapshot.fromJson(migrated);
    if (snapshot == null || snapshot.userId != userId) {
      if (clearIfInvalid) {
        await _queueCriticalChangeIfUnchanged(
          storageKey: 'latest_critical:$userId',
          observedContent: raw,
          replacement: null,
          reason: 'snapshot_mismatch',
          readCurrent: () => _readLatestCriticalSnapshot(userId),
          writeCurrent: (serialized) =>
              _writeLatestCriticalSnapshot(userId, serialized),
        );
      }
      _log(
        'candidate rejected source=latest_critical user=$userId '
        'reason=snapshot_mismatch',
      );
      return null;
    }
    if (clearIfInvalid && _rawSnapshotChanged(raw, migrated)) {
      await _queueCriticalChangeIfUnchanged(
        storageKey: 'latest_critical:$userId',
        observedContent: raw,
        replacement: jsonEncode(migrated),
        reason: 'snapshot_migration',
        readCurrent: () => _readLatestCriticalSnapshot(userId),
        writeCurrent: (serialized) =>
            _writeLatestCriticalSnapshot(userId, serialized),
      );
    }
    final candidate = _SnapshotCandidate(
      snapshot: snapshot,
      raw: migrated,
      source: 'latest_critical',
    );
    _log('candidate loaded ${_candidateTrace(candidate)}');
    return candidate;
  }

  Future<_SnapshotCandidate?> _candidateFromRemoteRaw(
    Map<String, dynamic>? raw, {
    required String expectedUserId,
    required String source,
  }) async {
    if (raw == null) {
      return null;
    }
    final provenanceTimestamp = _asInt(raw['updatedAtMs']);
    if (provenanceTimestamp == null || provenanceTimestamp < 0) {
      _log(
        'candidate rejected source=$source expectedUser=$expectedUserId '
        'reason=no_provenance_timestamp',
      );
      return null;
    }
    final migrated = _migrateRawSnapshot(raw);
    if (migrated == null) {
      return null;
    }
    final snapshot = AppRestorationSnapshot.fromJson(migrated);
    if (snapshot == null || snapshot.userId != expectedUserId) {
      _log(
        'candidate rejected source=$source expectedUser=$expectedUserId '
        'reason=remote_snapshot_mismatch',
      );
      return null;
    }
    final candidate = _SnapshotCandidate(
      snapshot: snapshot,
      raw: migrated,
      source: source,
    );
    _log('candidate loaded ${_candidateTrace(candidate)}');
    return candidate;
  }

  Future<_SnapshotCandidate?> _loadRemoteWindowCandidate(
    String userId,
    String windowId,
  ) async {
    final deviceId = await _currentDeviceId();
    _log(
      'remote window read start user=$userId window=$windowId '
      'device=$deviceId',
    );
    final debugReader = debugRemoteWindowSnapshotReader;
    if (debugReader != null) {
      return _candidateFromRemoteRaw(
        await debugReader(userId, deviceId, windowId),
        expectedUserId: userId,
        source: 'remote_window',
      );
    }

    final repo = _remoteRepo();
    if (repo == null) {
      return null;
    }
    try {
      final remote = await repo.readWindowSnapshot(
        userId: userId,
        deviceId: deviceId,
        windowId: windowId,
      );
      return _candidateFromRemoteRaw(
        remote?.snapshot,
        expectedUserId: userId,
        source: remote?.source ?? 'remote_window',
      );
    } catch (error) {
      _log('remote window read skipped: $error');
      return null;
    }
  }

  Future<_SnapshotCandidate?> _loadRemoteLatestCandidate(String userId) async {
    _log('remote latest read start user=$userId');
    final debugReader = debugRemoteLatestSnapshotReader;
    if (debugReader != null) {
      return _candidateFromRemoteRaw(
        await debugReader(userId),
        expectedUserId: userId,
        source: 'remote_latest',
      );
    }

    final repo = _remoteRepo();
    if (repo == null) {
      return null;
    }
    try {
      final remote = await repo.readLatestSnapshot(userId: userId);
      return _candidateFromRemoteRaw(
        remote?.snapshot,
        expectedUserId: userId,
        source: remote?.source ?? 'remote_latest',
      );
    } catch (error) {
      _log('remote latest read skipped: $error');
      return null;
    }
  }

  Future<_SnapshotCandidate?> _scanPrefsCandidatesForUser(
    String userId, {
    required bool clearIfInvalid,
  }) async {
    final prefs = await _prefs();
    final prefix = '$_keyPrefix:$userId:';
    final candidates = <_SnapshotCandidate>[];
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(prefix)) {
        continue;
      }
      final windowId = key.substring(prefix.length).trim();
      if (windowId.isEmpty) {
        if (clearIfInvalid) {
          final observed = prefs.getString(key);
          if (observed != null) {
            await _queuePrefsChangeIfUnchanged(
              key: key,
              observedContent: observed,
              replacement: null,
              reason: 'invalid_window_key',
            );
          }
        }
        continue;
      }
      final candidate = await _loadPrefsCandidate(
        userId,
        windowId,
        clearIfInvalid: clearIfInvalid,
        precedenceSource: 'latest_prefs',
      );
      if (candidate != null) {
        candidates.add(candidate);
      }
    }
    return _pickNewestCandidate(candidates);
  }

  _SnapshotCandidate? _pickNewestCandidate(
    Iterable<_SnapshotCandidate> candidates,
  ) {
    _SnapshotCandidate? winner;
    for (final candidate in candidates) {
      final currentWinner = winner;
      if (currentWinner == null ||
          _candidateOutranks(candidate, currentWinner)) {
        winner = candidate;
      }
    }
    return winner;
  }

  bool _candidateOutranks(
    _SnapshotCandidate candidate,
    _SnapshotCandidate incumbent,
  ) {
    final candidateTimestamp = candidate.snapshot.updatedAtMs;
    final incumbentTimestamp = incumbent.snapshot.updatedAtMs;
    if (candidateTimestamp != incumbentTimestamp) {
      return candidateTimestamp > incumbentTimestamp;
    }

    final candidateDigest = _restorationContentDigest(candidate.raw);
    final incumbentDigest = _restorationContentDigest(incumbent.raw);
    if (candidateDigest == incumbentDigest) {
      return false;
    }

    final candidateSource = candidate.sourceForPrecedence;
    final incumbentSource = incumbent.sourceForPrecedence;
    final candidateRank = _snapshotSourcePrecedence[candidateSource] ?? 0;
    final incumbentRank = _snapshotSourcePrecedence[incumbentSource] ?? 0;
    _log(
      'candidate collision updatedAtMs=$candidateTimestamp '
      'candidateSource=$candidateSource incumbentSource=$incumbentSource '
      'reason=timestamp_collision_content_divergence',
    );
    if (candidateRank != incumbentRank) {
      return candidateRank > incumbentRank;
    }
    final sourceOrder = candidateSource.compareTo(incumbentSource);
    if (sourceOrder != 0) {
      return sourceOrder < 0;
    }
    return candidateDigest.compareTo(incumbentDigest) < 0;
  }

  Future<_SnapshotCandidate?> _readSnapshotCandidateForUser(
    String userId,
    String windowId, {
    required bool clearIfInvalid,
  }) async {
    final prefsCandidate = await _loadPrefsCandidate(
      userId,
      windowId,
      clearIfInvalid: clearIfInvalid,
    );
    final criticalCandidate = await _loadCriticalCandidate(
      windowId,
      expectedUserId: userId,
      clearIfInvalid: clearIfInvalid,
    );
    return _pickNewestCandidate(<_SnapshotCandidate>[
      if (prefsCandidate != null) prefsCandidate,
      if (criticalCandidate != null) criticalCandidate,
    ]);
  }

  Future<_SnapshotCandidate?> _readLatestLocalSnapshotCandidateForUser(
    String userId, {
    required bool clearIfInvalid,
  }) async {
    final latestPrefsCandidate = await _loadLatestPrefsCandidate(
      userId,
      clearIfInvalid: clearIfInvalid,
    );
    final latestCriticalCandidate = await _loadLatestCriticalCandidate(
      userId,
      clearIfInvalid: clearIfInvalid,
    );
    final scannedPrefsCandidate = await _scanPrefsCandidatesForUser(
      userId,
      clearIfInvalid: clearIfInvalid,
    );
    return _pickNewestCandidate(<_SnapshotCandidate>[
      if (latestPrefsCandidate != null) latestPrefsCandidate,
      if (latestCriticalCandidate != null) latestCriticalCandidate,
      if (scannedPrefsCandidate != null) scannedPrefsCandidate,
    ]);
  }

  Future<_SnapshotCandidate?> _readStableSnapshotCandidateForUser(
    String userId,
    String windowId, {
    required bool clearIfInvalid,
    bool includeRemote = false,
  }) async {
    final currentWindowCandidate = await _readSnapshotCandidateForUser(
      userId,
      windowId,
      clearIfInvalid: clearIfInvalid,
    );
    final latestLocalCandidate = await _readLatestLocalSnapshotCandidateForUser(
      userId,
      clearIfInvalid: clearIfInvalid,
    );
    if (!includeRemote) {
      return _selectStableCandidate(
        userId: userId,
        windowId: windowId,
        includeRemote: includeRemote,
        currentWindowCandidate: currentWindowCandidate,
        latestUserCandidate: latestLocalCandidate,
        remoteWindowCandidate: null,
      );
    }
    final localWinner = _selectStableCandidate(
      userId: userId,
      windowId: windowId,
      includeRemote: true,
      currentWindowCandidate: currentWindowCandidate,
      latestUserCandidate: latestLocalCandidate,
      remoteWindowCandidate: null,
    );
    if (localWinner != null &&
        !_isRootRouteLocation(localWinner.snapshot.routeLocation)) {
      _log(
        'winner selected local_first_non_root ${_candidateTrace(localWinner)}',
      );
      return localWinner;
    }
    final remoteWindowCandidate = await _loadRemoteWindowCandidate(
      userId,
      windowId,
    );
    final remoteLatestCandidate = await _loadRemoteLatestCandidate(userId);
    final latestUserCandidate = _pickNewestCandidate(<_SnapshotCandidate>[
      if (latestLocalCandidate != null) latestLocalCandidate,
      if (remoteLatestCandidate != null) remoteLatestCandidate,
    ]);
    return _selectStableCandidate(
      userId: userId,
      windowId: windowId,
      includeRemote: includeRemote,
      currentWindowCandidate: currentWindowCandidate,
      latestUserCandidate: latestUserCandidate,
      remoteWindowCandidate: remoteWindowCandidate,
    );
  }

  _SnapshotCandidate? _selectStableCandidate({
    required String userId,
    required String windowId,
    required bool includeRemote,
    required _SnapshotCandidate? currentWindowCandidate,
    required _SnapshotCandidate? latestUserCandidate,
    required _SnapshotCandidate? remoteWindowCandidate,
  }) {
    _SnapshotCandidate? selected;
    var reason = 'none';
    if (currentWindowCandidate == null) {
      selected = _pickNewestCandidate(<_SnapshotCandidate>[
        if (remoteWindowCandidate != null) remoteWindowCandidate,
        if (latestUserCandidate != null) latestUserCandidate,
      ]);
      reason = selected == null ? 'no_candidates' : 'no_current_window_newest';
      _logStableSelection(
        userId: userId,
        windowId: windowId,
        includeRemote: includeRemote,
        currentWindowCandidate: currentWindowCandidate,
        latestUserCandidate: latestUserCandidate,
        remoteWindowCandidate: remoteWindowCandidate,
        selected: selected,
        reason: reason,
      );
      return selected;
    }
    if (!includeRemote) {
      selected = currentWindowCandidate;
      reason = 'current_window_local';
      _logStableSelection(
        userId: userId,
        windowId: windowId,
        includeRemote: includeRemote,
        currentWindowCandidate: currentWindowCandidate,
        latestUserCandidate: latestUserCandidate,
        remoteWindowCandidate: remoteWindowCandidate,
        selected: selected,
        reason: reason,
      );
      return selected;
    }

    if (remoteWindowCandidate != null &&
        remoteWindowCandidate.snapshot.updatedAtMs >
            currentWindowCandidate.snapshot.updatedAtMs) {
      selected = remoteWindowCandidate;
      reason = 'remote_window_newer_than_current';
      _logStableSelection(
        userId: userId,
        windowId: windowId,
        includeRemote: includeRemote,
        currentWindowCandidate: currentWindowCandidate,
        latestUserCandidate: latestUserCandidate,
        remoteWindowCandidate: remoteWindowCandidate,
        selected: selected,
        reason: reason,
      );
      return selected;
    }

    final latestHasOverlay =
        latestUserCandidate?.snapshot.overlayStack.isNotEmpty == true;
    if (latestUserCandidate != null &&
        latestHasOverlay &&
        currentWindowCandidate.snapshot.overlayStack.isEmpty &&
        latestUserCandidate.snapshot.updatedAtMs >
            currentWindowCandidate.snapshot.updatedAtMs) {
      final latestOverlayUpdatedAtMs = _latestOverlayUpdatedAtMs(
        latestUserCandidate.snapshot.overlayStack,
      );
      final currentOverlayDismissedAtMs =
          currentWindowCandidate.snapshot.overlayDismissedAtMs;
      if (latestOverlayUpdatedAtMs != null &&
          currentOverlayDismissedAtMs != null &&
          latestOverlayUpdatedAtMs <= currentOverlayDismissedAtMs) {
        selected = currentWindowCandidate;
        reason = 'latest_overlay_rejected_due_to_dismissal';
        _logStableSelection(
          userId: userId,
          windowId: windowId,
          includeRemote: includeRemote,
          currentWindowCandidate: currentWindowCandidate,
          latestUserCandidate: latestUserCandidate,
          remoteWindowCandidate: remoteWindowCandidate,
          selected: selected,
          reason: reason,
        );
        return selected;
      }
      selected = latestUserCandidate;
      reason = 'latest_overlay_over_current_without_overlay';
      _logStableSelection(
        userId: userId,
        windowId: windowId,
        includeRemote: includeRemote,
        currentWindowCandidate: currentWindowCandidate,
        latestUserCandidate: latestUserCandidate,
        remoteWindowCandidate: remoteWindowCandidate,
        selected: selected,
        reason: reason,
      );
      return selected;
    }

    if (latestUserCandidate != null &&
        _canLatestRouteOnlyReplaceCurrentWindowRoot(
          latestUserCandidate,
          currentWindowCandidate,
        )) {
      selected = latestUserCandidate;
      reason = 'latest_local_durable_primary_over_current_root';
      _logStableSelection(
        userId: userId,
        windowId: windowId,
        includeRemote: includeRemote,
        currentWindowCandidate: currentWindowCandidate,
        latestUserCandidate: latestUserCandidate,
        remoteWindowCandidate: remoteWindowCandidate,
        selected: selected,
        reason: reason,
      );
      return selected;
    }

    selected = currentWindowCandidate;
    reason = 'current_window';
    _logStableSelection(
      userId: userId,
      windowId: windowId,
      includeRemote: includeRemote,
      currentWindowCandidate: currentWindowCandidate,
      latestUserCandidate: latestUserCandidate,
      remoteWindowCandidate: remoteWindowCandidate,
      selected: selected,
      reason: reason,
    );
    return selected;
  }

  void _logStableSelection({
    required String userId,
    required String windowId,
    required bool includeRemote,
    required _SnapshotCandidate? currentWindowCandidate,
    required _SnapshotCandidate? latestUserCandidate,
    required _SnapshotCandidate? remoteWindowCandidate,
    required _SnapshotCandidate? selected,
    required String reason,
  }) {
    _log(
      'selection user=$userId window=$windowId includeRemote=$includeRemote '
      'current=${_candidateTrace(currentWindowCandidate)} '
      'latest=${_candidateTrace(latestUserCandidate)} '
      'remoteWindow=${_candidateTrace(remoteWindowCandidate)} '
      'selected=${_candidateTrace(selected)} reason=$reason',
    );
  }

  void _writeCriticalSnapshot(String windowId, String? serialized) {
    final debugWriter = debugCriticalSnapshotWriter;
    if (debugWriter != null) {
      debugWriter(windowId, serialized);
      return;
    }
    if (serialized == null || serialized.trim().isEmpty) {
      app_window_platform.clearCriticalSnapshot(windowId);
      return;
    }
    app_window_platform.updateCriticalSnapshot(windowId, serialized);
  }

  void _writeLatestCriticalSnapshot(String userId, String? serialized) {
    final debugWriter = debugLatestCriticalSnapshotWriter;
    if (debugWriter != null) {
      debugWriter(userId, serialized);
      return;
    }
    if (serialized == null || serialized.trim().isEmpty) {
      app_window_platform.clearLatestCriticalSnapshot(userId);
      return;
    }
    app_window_platform.updateLatestCriticalSnapshot(userId, serialized);
  }

  bool _isRemoteSource(String? source) =>
      source != null && source.startsWith('remote_');

  bool _isRootRouteLocation(String? location) {
    final normalized = location?.trim();
    if (normalized == null || normalized.isEmpty) return true;
    final uri = Uri.tryParse(normalized);
    return uri == null || uri.path.isEmpty || uri.path == '/';
  }

  bool _sourceCanEvictDurableSurface(NavigationSource source) {
    switch (source) {
      case NavigationSource.userPrimaryTab:
      case NavigationSource.userDrawerSelection:
      case NavigationSource.userBack:
      case NavigationSource.userDismissal:
      case NavigationSource.userExplicitOpen:
        return true;
      case NavigationSource.programmatic:
      case NavigationSource.restoreReplay:
      case NavigationSource.authGate:
      case NavigationSource.launchPlaceholder:
      case NavigationSource.lifecycle:
      case NavigationSource.calendarDidPushNext:
      case NavigationSource.calendarDispose:
      case NavigationSource.detailRestoration:
      case NavigationSource.modalLifecycle:
      case NavigationSource.notificationTap:
      case NavigationSource.searchResultTap:
      case NavigationSource.sharedCalendarEventTap:
      case NavigationSource.nodeActionUrl:
      case NavigationSource.authCallback:
      case NavigationSource.appLink:
      case NavigationSource.sessionResume:
      case NavigationSource.bootRestore:
      case NavigationSource.unknown:
        return false;
    }
  }

  bool _sourceCanPersistDurableSurface(NavigationSource source) {
    switch (source) {
      case NavigationSource.restoreReplay:
      case NavigationSource.authGate:
      case NavigationSource.launchPlaceholder:
      case NavigationSource.lifecycle:
        return false;
      case NavigationSource.userPrimaryTab:
      case NavigationSource.userDrawerSelection:
      case NavigationSource.userBack:
      case NavigationSource.userDismissal:
      case NavigationSource.userExplicitOpen:
      case NavigationSource.programmatic:
      case NavigationSource.calendarDidPushNext:
      case NavigationSource.calendarDispose:
      case NavigationSource.detailRestoration:
      case NavigationSource.modalLifecycle:
      case NavigationSource.notificationTap:
      case NavigationSource.searchResultTap:
      case NavigationSource.sharedCalendarEventTap:
      case NavigationSource.nodeActionUrl:
      case NavigationSource.authCallback:
      case NavigationSource.appLink:
      case NavigationSource.sessionResume:
      case NavigationSource.bootRestore:
      case NavigationSource.unknown:
        return true;
    }
  }

  bool _sourceClearsPrimarySelectionOnRoot(NavigationSource source) {
    switch (source) {
      case NavigationSource.userBack:
      case NavigationSource.userDismissal:
        return true;
      case NavigationSource.userPrimaryTab:
      case NavigationSource.userDrawerSelection:
      case NavigationSource.userExplicitOpen:
      case NavigationSource.programmatic:
      case NavigationSource.restoreReplay:
      case NavigationSource.authGate:
      case NavigationSource.launchPlaceholder:
      case NavigationSource.lifecycle:
      case NavigationSource.calendarDidPushNext:
      case NavigationSource.calendarDispose:
      case NavigationSource.detailRestoration:
      case NavigationSource.modalLifecycle:
      case NavigationSource.notificationTap:
      case NavigationSource.searchResultTap:
      case NavigationSource.sharedCalendarEventTap:
      case NavigationSource.nodeActionUrl:
      case NavigationSource.authCallback:
      case NavigationSource.appLink:
      case NavigationSource.sessionResume:
      case NavigationSource.bootRestore:
      case NavigationSource.unknown:
        return false;
    }
  }

  bool _isDurablePrimaryRouteLocation(String? location) {
    final normalized = location?.trim();
    if (normalized == null || normalized.isEmpty) return false;
    final uri = Uri.tryParse(normalized);
    if (uri == null || uri.hasScheme || uri.host.isNotEmpty) return false;
    if (uri.path == '/' || uri.path.isEmpty) return false;
    return const NavigationPersistencePolicy().sectionForDurableRoute(
          normalized,
        ) !=
        null;
  }

  bool _canLatestRouteOnlyReplaceCurrentWindowRoot(
    _SnapshotCandidate latestUserCandidate,
    _SnapshotCandidate currentWindowCandidate,
  ) {
    if (_isRemoteSource(latestUserCandidate.source)) return false;
    if (latestUserCandidate.snapshot.overlayStack.isNotEmpty) return false;
    if (currentWindowCandidate.snapshot.overlayStack.isNotEmpty) return false;
    if (!_isRootRouteLocation(currentWindowCandidate.snapshot.routeLocation)) {
      return false;
    }
    if (!_isDurablePrimaryRouteLocation(
      latestUserCandidate.snapshot.routeLocation,
    )) {
      return false;
    }
    return latestUserCandidate.snapshot.updatedAtMs >
        currentWindowCandidate.snapshot.updatedAtMs;
  }

  Future<int?> _newestDurableUpdatedAtMs(String userId, String windowId) async {
    int? newest;
    void consider(
      Map<String, dynamic>? raw, {
      required bool requireCurrentWindow,
    }) {
      if (raw == null) return;
      final migrated = _migrateRawSnapshot(raw);
      final snapshot = migrated == null
          ? null
          : AppRestorationSnapshot.fromJson(migrated);
      if (snapshot == null || snapshot.userId != userId) return;
      if (requireCurrentWindow && snapshot.windowId != windowId) return;
      if (newest == null || snapshot.updatedAtMs > newest!) {
        newest = snapshot.updatedAtMs;
      }
    }

    consider(
      await _loadRawFor(userId, windowId, clearIfInvalid: false),
      requireCurrentWindow: true,
    );
    consider(
      await _loadCriticalRawFor(windowId, clearIfInvalid: false),
      requireCurrentWindow: true,
    );
    consider(
      await _loadLatestRawForUser(userId, clearIfInvalid: false),
      requireCurrentWindow: false,
    );
    consider(
      await _loadLatestCriticalRawForUser(userId, clearIfInvalid: false),
      requireCurrentWindow: false,
    );
    return newest;
  }

  void _preserveNewerPrimaryRouteAuthority(
    Map<String, dynamic> pending, {
    required String userId,
    required String windowId,
    required int observedUpdatedAtMs,
  }) {
    Map<String, dynamic>? decodePrimaryAuthority(
      String? serialized, {
      required bool requireCurrentWindow,
    }) {
      if (serialized == null || serialized.trim().isEmpty) return null;
      try {
        final raw = _asJsonMap(jsonDecode(serialized));
        if (raw == null) return null;
        final snapshot = AppRestorationSnapshot.fromJson(raw);
        if (snapshot == null || snapshot.userId != userId) return null;
        if (requireCurrentWindow && snapshot.windowId != windowId) return null;
        final metadata = NavigationLaunchRouteMetadata.fromJson(
          raw[navigationPrimarySelectionMetadataKey],
        );
        final route = stableRouteLocationForContinuity(
          raw['routeLocation'] as String?,
        );
        if (metadata?.source != NavigationSource.userPrimaryTab ||
            route == null ||
            !const NavigationPersistencePolicy().isValidDurableLaunchRoute(
              route,
              metadata!,
            )) {
          return null;
        }
        return raw;
      } catch (_) {
        return null;
      }
    }

    final current = decodePrimaryAuthority(
      _readCriticalSnapshot(windowId),
      requireCurrentWindow: true,
    );
    final latest = decodePrimaryAuthority(
      _readLatestCriticalSnapshot(userId),
      requireCurrentWindow: false,
    );
    final currentUpdatedAtMs = _asInt(current?['updatedAtMs']) ?? -1;
    final latestUpdatedAtMs = _asInt(latest?['updatedAtMs']) ?? -1;
    final authoritative = latestUpdatedAtMs > currentUpdatedAtMs
        ? latest
        : current;
    final authoritativeUpdatedAtMs = currentUpdatedAtMs > latestUpdatedAtMs
        ? currentUpdatedAtMs
        : latestUpdatedAtMs;
    if (authoritative == null ||
        authoritativeUpdatedAtMs <= observedUpdatedAtMs) {
      return;
    }

    final authoritativeRoute = authoritative['routeLocation'] as String;
    final pendingRoute = pending['routeLocation'];
    pending['routeLocation'] = authoritativeRoute;
    pending[navigationLaunchRouteMetadataKey] = Map<String, dynamic>.from(
      _asJsonMap(authoritative[navigationLaunchRouteMetadataKey]) ??
          const <String, dynamic>{},
    );
    pending[navigationPrimarySelectionMetadataKey] = Map<String, dynamic>.from(
      _asJsonMap(authoritative[navigationPrimarySelectionMetadataKey]) ??
          const <String, dynamic>{},
    );
    _log(
      'mutation preserved newer primary authority user=$userId '
      'window=$windowId pendingRoute=${pendingRoute ?? '<none>'} '
      'authoritativeRoute=$authoritativeRoute '
      'observedAtMs=$observedUpdatedAtMs '
      'authorityAtMs=$authoritativeUpdatedAtMs',
    );
  }

  Future<bool> _persistRawSnapshotLocally(
    String userId,
    String windowId,
    Map<String, dynamic> raw,
  ) async {
    final incomingUpdatedAtMs = _asInt(raw['updatedAtMs']);
    if (incomingUpdatedAtMs == null || incomingUpdatedAtMs < 0) {
      _log(
        'write local rejected user=$userId window=$windowId '
        'reason=no_provenance_timestamp',
      );
      return false;
    }
    final durableUpdatedAtMs = await _newestDurableUpdatedAtMs(
      userId,
      windowId,
    );
    if (durableUpdatedAtMs != null &&
        incomingUpdatedAtMs <= durableUpdatedAtMs) {
      _log(
        'write local rejected user=$userId window=$windowId '
        'incoming=$incomingUpdatedAtMs durable=$durableUpdatedAtMs '
        'reason=non_monotonic_timestamp',
      );
      return false;
    }
    _log(
      'write local start user=$userId window=$windowId '
      'route=${raw['routeLocation'] ?? '<none>'} '
      'overlayCount=${_asJsonMapList(raw['overlayStack']).length} '
      'overlay=${_overlayStackTrace(_asJsonMapList(raw['overlayStack']))} '
      'updatedAtMs=${raw['updatedAtMs'] ?? '<none>'} '
      'targets=critical,latest_critical,prefs,latest_prefs,last_user',
    );
    final encoded = jsonEncode(raw);
    _writeCriticalSnapshot(windowId, encoded);
    _writeLatestCriticalSnapshot(userId, encoded);
    _writePlatformLastActiveUserId(userId);
    final prefs = await _prefs();
    await Future.wait<bool>(<Future<bool>>[
      prefs.setString(_prefsKey(userId, windowId), encoded),
      prefs.setString(_latestPrefsKey(userId), encoded),
      prefs.setString(_lastActiveUserKey, userId),
    ]);
    _log(
      'write local done user=$userId window=$windowId '
      'route=${raw['routeLocation'] ?? '<none>'} '
      'updatedAtMs=${raw['updatedAtMs'] ?? '<none>'}',
    );
    return true;
  }

  Future<AppRestorationSnapshot?> _adoptRemoteSnapshot(
    _SnapshotCandidate candidate,
    String userId,
    String windowId,
  ) async {
    final raw = Map<String, dynamic>.from(candidate.raw);
    final provenanceTimestamp = _asInt(raw['updatedAtMs']);
    if (provenanceTimestamp == null || provenanceTimestamp < 0) {
      _log(
        'adoption rejected source=${candidate.source} user=$userId '
        'window=$windowId reason=no_provenance_timestamp',
      );
      return null;
    }
    raw['schemaVersion'] = schemaVersion;
    raw['userId'] = userId;
    raw['windowId'] = windowId;
    final snapshot = AppRestorationSnapshot.fromJson(raw);
    if (snapshot == null) {
      return null;
    }
    return _enqueueMutationOperation(() async {
      final persisted = await _persistRawSnapshotLocally(userId, windowId, raw);
      if (persisted) {
        _log(
          'adopted ${candidate.source} snapshot '
          'user=$userId window=$windowId',
        );
        return snapshot;
      }
      final current = await _readStableSnapshotCandidateForUser(
        userId,
        windowId,
        clearIfInvalid: false,
      );
      return current?.snapshot;
    });
  }

  Future<AppRestorationSnapshot?> readSnapshotForUser(
    String userId, {
    String? windowId,
    bool includeRemote = false,
  }) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return null;
    }
    final resolvedWindowId = windowId ?? await _currentWindowId();
    final candidate = await _readStableSnapshotCandidateForUser(
      normalizedUserId,
      resolvedWindowId,
      clearIfInvalid: true,
      includeRemote: includeRemote,
    );
    if (candidate != null && _isRemoteSource(candidate.source)) {
      return _adoptRemoteSnapshot(
        candidate,
        normalizedUserId,
        resolvedWindowId,
      );
    }
    return candidate?.snapshot;
  }

  Future<AppRestorationReadResult> readBestSnapshot({
    bool includeRemote = false,
  }) async {
    final windowId = await _currentWindowId();
    app_window_platform.registerCriticalSnapshotWindow(windowId);
    final activeUserId = await _currentUserId();
    if (activeUserId != null) {
      final candidate = await _readStableSnapshotCandidateForUser(
        activeUserId,
        windowId,
        clearIfInvalid: true,
        includeRemote: includeRemote,
      );
      if (candidate != null) {
        final snapshot = _isRemoteSource(candidate.source)
            ? await _adoptRemoteSnapshot(candidate, activeUserId, windowId)
            : candidate.snapshot;
        if (snapshot == null) {
          return AppRestorationReadResult(
            status: AppRestorationReadStatus.noSnapshot,
            windowId: windowId,
            activeUserId: activeUserId,
            source: 'none',
            reason: 'invalid_adopted_remote_snapshot',
          );
        }
        _log(
          'read status=restored source=${candidate.source} '
          'user=$activeUserId window=$windowId '
          '${_snapshotTrace(snapshot)} reason=matched_current_user',
        );
        return AppRestorationReadResult(
          status: AppRestorationReadStatus.restored,
          windowId: windowId,
          activeUserId: activeUserId,
          snapshot: snapshot,
          source: candidate.source,
          reason: 'matched_current_user',
        );
      }
      _log(
        'read status=no_snapshot user=$activeUserId window=$windowId '
        'reason=no_snapshot_for_current_user',
      );
      return AppRestorationReadResult(
        status: AppRestorationReadStatus.noSnapshot,
        windowId: windowId,
        activeUserId: activeUserId,
        source: 'none',
        reason: 'no_snapshot_for_current_user',
      );
    }

    final lastActiveUserId = await _readBootFallbackUserId();
    final tentativeCandidate = lastActiveUserId == null
        ? await _loadCriticalCandidate(windowId, clearIfInvalid: true)
        : await _pickNewestTentativeCandidate(lastActiveUserId, windowId);
    if (tentativeCandidate != null) {
      _log(
        'read status=tentative source=${tentativeCandidate.source} '
        'snapshot_user=${tentativeCandidate.snapshot.userId} window=$windowId '
        '${_snapshotTrace(tentativeCandidate.snapshot)} '
        'reason=auth_not_ready',
      );
      return AppRestorationReadResult(
        status: AppRestorationReadStatus.tentative,
        windowId: windowId,
        activeUserId: null,
        snapshot: tentativeCandidate.snapshot,
        source: tentativeCandidate.source,
        reason: 'auth_not_ready',
      );
    }

    _log(
      'read status=awaiting_auth window=$windowId '
      'reason=no_authenticated_user',
    );
    return AppRestorationReadResult(
      status: AppRestorationReadStatus.awaitingAuth,
      windowId: windowId,
      activeUserId: null,
      source: 'none',
      reason: 'no_authenticated_user',
    );
  }

  Future<_SnapshotCandidate?> _pickNewestTentativeCandidate(
    String lastActiveUserId,
    String windowId,
  ) async {
    final userScopedCandidate = await _readStableSnapshotCandidateForUser(
      lastActiveUserId,
      windowId,
      clearIfInvalid: true,
    );
    final currentWindowCriticalCandidate = await _loadCriticalCandidate(
      windowId,
      expectedUserId: lastActiveUserId,
      clearIfInvalid: true,
    );
    return _pickNewestCandidate(<_SnapshotCandidate>[
      if (userScopedCandidate != null) userScopedCandidate,
      if (currentWindowCriticalCandidate != null)
        currentWindowCriticalCandidate,
    ]);
  }

  Future<AppRestorationSnapshot?> readSnapshot({
    bool includeRemote = false,
  }) async {
    final userId = await _currentUserId();
    if (userId == null) {
      return null;
    }
    return readSnapshotForUser(userId, includeRemote: includeRemote);
  }

  Future<AppRestorationMutationResult> _mutate(
    void Function(Map<String, dynamic> current) update, {
    String? expectedUserId,
    String? expectedWindowId,
  }) async {
    return _enqueueMutationOperation(
      () => _mutateNow(
        update,
        expectedUserId: expectedUserId,
        expectedWindowId: expectedWindowId,
      ),
    );
  }

  Future<AppRestorationMutationResult> _mutateNow(
    void Function(Map<String, dynamic> current) update, {
    String? expectedUserId,
    String? expectedWindowId,
  }) async {
    final userId = await _currentUserId();
    if (userId == null) {
      _log('mutation rejected reason=auth_not_ready');
      return const AppRestorationMutationResult(
        AppRestorationMutationStatus.notReady,
      );
    }
    if (expectedUserId != null && userId != expectedUserId) {
      _log(
        'mutation dropped expected=$expectedUserId actual=$userId '
        'reason=user_mismatch',
      );
      return const AppRestorationMutationResult(
        AppRestorationMutationStatus.droppedUserMismatch,
      );
    }
    final windowId = expectedWindowId ?? await _currentWindowId();
    app_window_platform.registerCriticalSnapshotWindow(windowId);
    final snapshotCandidate = await _readStableSnapshotCandidateForUser(
      userId,
      windowId,
      clearIfInvalid: false,
    );
    final baseline =
        snapshotCandidate?.raw ??
        await _loadRawFor(userId, windowId, clearIfInvalid: false) ??
        <String, dynamic>{};
    final observedUpdatedAtMs = _asInt(baseline['updatedAtMs']) ?? -1;
    final current = Map<String, dynamic>.from(baseline);
    update(current);
    current['schemaVersion'] = schemaVersion;
    current['userId'] = userId;
    current['windowId'] = windowId;
    await debugBeforeMutationProvenanceRead?.call();
    final durableUpdatedAtMs = await _newestDurableUpdatedAtMs(
      userId,
      windowId,
    );
    _preserveNewerPrimaryRouteAuthority(
      current,
      userId: userId,
      windowId: windowId,
      observedUpdatedAtMs: observedUpdatedAtMs,
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    current['updatedAtMs'] = durableUpdatedAtMs == null
        ? now
        : (now > durableUpdatedAtMs ? now : durableUpdatedAtMs + 1);
    final persisted = await _persistRawSnapshotLocally(
      userId,
      windowId,
      current,
    );
    if (persisted) {
      _scheduleRemoteSnapshotWrite(current);
      return const AppRestorationMutationResult(
        AppRestorationMutationStatus.persisted,
      );
    }
    return const AppRestorationMutationResult(
      AppRestorationMutationStatus.superseded,
    );
  }

  void _scheduleRemoteSnapshotWrite(Map<String, dynamic> raw) {
    final snapshot = Map<String, dynamic>.from(raw);
    final next = _remoteWriteQueue.then(
      (_) => _writeRemoteSnapshot(snapshot),
      onError: (_) => _writeRemoteSnapshot(snapshot),
    );
    _remoteWriteQueue = next.catchError((_) {});
    unawaited(_remoteWriteQueue);
  }

  Future<void> _writeRemoteSnapshot(Map<String, dynamic> raw) async {
    final userId = (raw['userId'] as String?)?.trim();
    final windowId = (raw['windowId'] as String?)?.trim();
    final updatedAtMs = _asInt(raw['updatedAtMs']);
    if (userId == null ||
        userId.isEmpty ||
        windowId == null ||
        windowId.isEmpty ||
        updatedAtMs == null) {
      _log(
        'remote write skipped reason=invalid_snapshot '
        'user=${userId ?? '<none>'} window=${windowId ?? '<none>'}',
      );
      return;
    }

    final deviceId = await _currentDeviceId();
    final debugWriter = debugRemoteSnapshotWriter;
    if (debugWriter != null) {
      _log(
        'remote write debug user=$userId window=$windowId '
        'route=${raw['routeLocation'] ?? '<none>'} '
        'updatedAtMs=$updatedAtMs',
      );
      await debugWriter(
        userId,
        deviceId,
        windowId,
        Map<String, dynamic>.from(raw),
      );
      return;
    }

    final repo = _remoteRepo();
    if (repo == null) {
      _log(
        'remote write skipped reason=no_repo user=$userId window=$windowId '
        'route=${raw['routeLocation'] ?? '<none>'}',
      );
      return;
    }
    try {
      _log(
        'remote write start user=$userId window=$windowId '
        'route=${raw['routeLocation'] ?? '<none>'} updatedAtMs=$updatedAtMs',
      );
      await repo.upsertSnapshots(
        userId: userId,
        deviceId: deviceId,
        windowId: windowId,
        schemaVersion: schemaVersion,
        updatedAtMs: updatedAtMs,
        snapshot: Map<String, dynamic>.from(raw),
      );
    } catch (error) {
      _log('remote write skipped: $error');
    }
  }

  void _deferCalendarIntent(_PendingCalendarRestorationIntent intent) {
    _pendingCalendarIntent = intent;
    _log(
      'calendar mutation deferred user=${intent.userId} '
      'window=${intent.windowId} reason=auth_not_ready',
    );
  }

  Future<AppRestorationMutationResult> _persistCalendarIntent(
    _PendingCalendarRestorationIntent intent,
  ) async {
    final result = await _mutate(
      (current) {
        current['calendar'] = intent.state.toJson();
      },
      expectedUserId: intent.userId,
      expectedWindowId: intent.windowId,
    );
    if (result.status == AppRestorationMutationStatus.notReady) {
      if (_pendingCalendarIntent == null) {
        _deferCalendarIntent(intent);
      }
      return const AppRestorationMutationResult(
        AppRestorationMutationStatus.deferred,
      );
    }
    if (result.status == AppRestorationMutationStatus.droppedUserMismatch) {
      _log(
        'calendar mutation dropped expected=${intent.userId} '
        'reason=user_mismatch',
      );
    }
    return result;
  }

  Future<AppRestorationMutationResult?> handleSessionReady(
    String? userId,
  ) async {
    final normalizedUserId = userId?.trim();
    if (normalizedUserId == null || normalizedUserId.isEmpty) {
      return const AppRestorationMutationResult(
        AppRestorationMutationStatus.notReady,
      );
    }
    AppRestorationMutationResult? routeResult;
    final routeIntent = _pendingLaunchRouteIntent;
    _pendingLaunchRouteIntent = null;
    if (routeIntent != null && routeIntent.userId != normalizedUserId) {
      _log(
        'launch route mutation dropped expected=${routeIntent.userId} '
        'actual=$normalizedUserId reason=user_mismatch',
      );
      routeResult = const AppRestorationMutationResult(
        AppRestorationMutationStatus.droppedUserMismatch,
      );
    } else if (routeIntent != null) {
      routeResult = await _persistLaunchRouteIntent(routeIntent);
    }

    final calendarIntent = _pendingCalendarIntent;
    _pendingCalendarIntent = null;
    if (calendarIntent == null) return routeResult;
    if (calendarIntent.userId != normalizedUserId) {
      _log(
        'calendar mutation dropped expected=${calendarIntent.userId} '
        'actual=$normalizedUserId reason=user_mismatch',
      );
      return const AppRestorationMutationResult(
        AppRestorationMutationStatus.droppedUserMismatch,
      );
    }
    return _persistCalendarIntent(calendarIntent);
  }

  Future<void> flushPendingWrites() async {
    final userId = await _currentUserId();
    if (userId != null) {
      await handleSessionReady(userId);
    }
    await _mutationQueue;
    await _remoteWriteQueue;
  }

  Future<void> clearCurrentSnapshot() async {
    final userId = await _currentUserId();
    if (userId == null) {
      return;
    }
    final windowId = await _currentWindowId();
    final prefs = await _prefs();
    await prefs.remove(_prefsKey(userId, windowId));
    _writeCriticalSnapshot(windowId, null);
  }

  bool recordPrimaryTabSelectionCriticalSnapshot(
    String location, {
    required NavigationLaunchRouteMetadata metadata,
  }) {
    final normalized = stableRouteLocationForContinuity(location);
    final policy = const NavigationPersistencePolicy();
    if (normalized == null ||
        normalized.isEmpty ||
        metadata.source != NavigationSource.userPrimaryTab ||
        !metadata.isCurrentUserPrimaryDurable ||
        !policy.isValidDurableLaunchRoute(normalized, metadata)) {
      _log(
        'critical primary route rejected input=$location '
        'section=${metadata.section?.wireName ?? '<none>'} '
        'reason=policy_rejected',
      );
      return false;
    }

    final userId = _currentUserIdNow();
    final windowId = AppWindowService.instance.currentWindowId;
    if (userId == null || windowId == null || windowId.isEmpty) {
      _log(
        'critical primary route rejected input=$location '
        'section=${metadata.section?.wireName ?? '<none>'} '
        'reason=identity_not_initialized',
      );
      return false;
    }

    Map<String, dynamic>? decodeCritical(
      String? serialized, {
      required bool requireCurrentWindow,
    }) {
      if (serialized == null || serialized.trim().isEmpty) return null;
      try {
        final raw = _asJsonMap(jsonDecode(serialized));
        if (raw == null) return null;
        final snapshot = AppRestorationSnapshot.fromJson(raw);
        if (snapshot == null || snapshot.userId != userId) return null;
        if (requireCurrentWindow && snapshot.windowId != windowId) return null;
        return Map<String, dynamic>.from(raw);
      } catch (_) {
        return null;
      }
    }

    final currentCritical = decodeCritical(
      _readCriticalSnapshot(windowId),
      requireCurrentWindow: true,
    );
    final latestCritical = decodeCritical(
      _readLatestCriticalSnapshot(userId),
      requireCurrentWindow: false,
    );
    final currentUpdatedAtMs = _asInt(currentCritical?['updatedAtMs']) ?? -1;
    final latestUpdatedAtMs = _asInt(latestCritical?['updatedAtMs']) ?? -1;
    final baseline = latestUpdatedAtMs > currentUpdatedAtMs
        ? latestCritical
        : currentCritical;
    final next = baseline == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(baseline);
    final durableUpdatedAtMs = currentUpdatedAtMs > latestUpdatedAtMs
        ? currentUpdatedAtMs
        : latestUpdatedAtMs;
    final now = DateTime.now().millisecondsSinceEpoch;
    final updatedAtMs = now > durableUpdatedAtMs ? now : durableUpdatedAtMs + 1;

    next['schemaVersion'] = schemaVersion;
    next['userId'] = userId;
    next['windowId'] = windowId;
    next['updatedAtMs'] = updatedAtMs;
    next['routeLocation'] = normalized;
    next[navigationLaunchRouteMetadataKey] = metadata.toJson();
    next[navigationPrimarySelectionMetadataKey] = metadata.toJson();
    final encoded = jsonEncode(next);

    app_window_platform.registerCriticalSnapshotWindow(windowId);
    _writeCriticalSnapshot(windowId, encoded);
    _writeLatestCriticalSnapshot(userId, encoded);
    final verifyCurrent =
        debugCriticalSnapshotReader != null ||
        app_window_platform.supportsSynchronousCriticalSnapshotStorage;
    final verifyLatest =
        debugLatestCriticalSnapshotReader != null ||
        app_window_platform.supportsSynchronousCriticalSnapshotStorage;
    final currentReadback = verifyCurrent
        ? _readCriticalSnapshot(windowId)
        : encoded;
    final latestReadback = verifyLatest
        ? _readLatestCriticalSnapshot(userId)
        : encoded;
    final expectedDigest = _storedRestorationContentDigest(encoded);
    final currentCommitted =
        currentReadback != null &&
        _storedRestorationContentDigest(currentReadback) == expectedDigest;
    final latestCommitted =
        latestReadback != null &&
        _storedRestorationContentDigest(latestReadback) == expectedDigest;
    if (!currentCommitted || !latestCommitted) {
      _log(
        'critical primary route failed reason=durable_readback '
        'route=$normalized section=${metadata.section?.wireName ?? '<none>'} '
        'user=$userId window=$windowId current=$currentCommitted '
        'latest=$latestCommitted updatedAtMs=$updatedAtMs',
      );
      return false;
    }
    _writePlatformLastActiveUserId(userId);
    _log(
      'critical primary route committed route=$normalized '
      'section=${metadata.section?.wireName ?? '<none>'} '
      'user=$userId window=$windowId updatedAtMs=$updatedAtMs',
    );
    return true;
  }

  Future<AppRestorationMutationResult> saveDurableLaunchRoute(
    String location, {
    required NavigationLaunchRouteMetadata metadata,
  }) async {
    final normalized = stableRouteLocationForContinuity(location);
    final accepted = const NavigationPersistencePolicy()
        .isValidDurableLaunchRoute(normalized, metadata);
    if (!accepted || normalized == null || normalized.isEmpty) {
      _log(
        'save launch route rejected input=$location '
        'source=${metadata.source.wireName} '
        'classification=${metadata.routeClass.wireName} '
        'schemaVersion=${metadata.schemaVersion} '
        'section=${metadata.section?.wireName ?? '<none>'} '
        'canonical=${metadata.canonicalRoute ?? '<none>'} '
        'reason=policy_rejected',
      );
      return const AppRestorationMutationResult(
        AppRestorationMutationStatus.invalid,
      );
    }
    if (!_sourceCanPersistDurableSurface(metadata.source)) {
      _log(
        'save launch route rejected input=$location '
        'source=${metadata.source.wireName} '
        'classification=${metadata.routeClass.wireName} '
        'schemaVersion=${metadata.schemaVersion} '
        'section=${metadata.section?.wireName ?? '<none>'} '
        'canonical=${metadata.canonicalRoute ?? '<none>'} '
        'reason=passive_source_cannot_persist',
      );
      return const AppRestorationMutationResult(
        AppRestorationMutationStatus.invalid,
      );
    }
    _log(
      'save launch route input=$location sanitized=$normalized '
      'source=${metadata.source.wireName} '
      'classification=${metadata.routeClass.wireName} '
      'schemaVersion=${metadata.schemaVersion} '
      'section=${metadata.section?.wireName ?? '<none>'} '
      'canonical=${metadata.canonicalRoute ?? '<none>'} accepted=true',
    );
    final activeUserId = await _currentUserId();
    final boundUserId = activeUserId ?? await _readBootFallbackUserId();
    if (boundUserId == null) {
      _log('launch route mutation rejected reason=no_bound_user');
      return const AppRestorationMutationResult(
        AppRestorationMutationStatus.notReady,
      );
    }
    final intent = _PendingLaunchRouteRestorationIntent(
      userId: boundUserId,
      windowId: await _currentWindowId(),
      location: normalized,
      metadata: metadata,
    );
    if (activeUserId == null) {
      _deferLaunchRouteIntent(intent);
      return const AppRestorationMutationResult(
        AppRestorationMutationStatus.deferred,
      );
    }
    return _persistLaunchRouteIntent(intent);
  }

  void _deferLaunchRouteIntent(_PendingLaunchRouteRestorationIntent intent) {
    _pendingLaunchRouteIntent = intent;
    _log(
      'launch route mutation deferred user=${intent.userId} '
      'window=${intent.windowId} route=${intent.location} '
      'reason=auth_not_ready',
    );
  }

  Future<AppRestorationMutationResult> _persistLaunchRouteIntent(
    _PendingLaunchRouteRestorationIntent intent,
  ) async {
    final location = intent.location;
    final metadata = intent.metadata;
    final result = await _mutate(
      (current) {
        if (_isRootRouteLocation(location) &&
            !_sourceCanEvictDurableSurface(metadata.source)) {
          final existingMetadata = NavigationLaunchRouteMetadata.fromJson(
            current[navigationLaunchRouteMetadataKey],
          );
          final existingRoute = (current['routeLocation'] as String?)?.trim();
          if (existingMetadata?.source == NavigationSource.userPrimaryTab &&
              !_isRootRouteLocation(existingRoute)) {
            _log(
              'save launch route rejected input=$location '
              'source=${metadata.source.wireName} '
              'classification=${metadata.routeClass.wireName} '
              'schemaVersion=${metadata.schemaVersion} '
              'section=${metadata.section?.wireName ?? '<none>'} '
              'canonical=${metadata.canonicalRoute ?? '<none>'} '
              'existingRoute=${existingRoute ?? '<none>'} '
              'existingSource=${existingMetadata!.source.wireName} '
              'reason=programmatic_root_cannot_evict_user_primary',
            );
            return;
          }
          final primaryMetadata = NavigationLaunchRouteMetadata.fromJson(
            current[navigationPrimarySelectionMetadataKey],
          );
          final primaryRoute = primaryMetadata?.canonicalRoute?.trim();
          if (primaryMetadata?.source == NavigationSource.userPrimaryTab &&
              primaryRoute != null &&
              primaryRoute.isNotEmpty &&
              !_isRootRouteLocation(primaryRoute) &&
              const NavigationPersistencePolicy().isValidPrimarySelection(
                primaryMetadata,
              )) {
            _log(
              'save launch route rejected input=$location '
              'source=${metadata.source.wireName} '
              'classification=${metadata.routeClass.wireName} '
              'schemaVersion=${metadata.schemaVersion} '
              'section=${metadata.section?.wireName ?? '<none>'} '
              'canonical=${metadata.canonicalRoute ?? '<none>'} '
              'primaryRoute=$primaryRoute '
              'primarySource=${primaryMetadata!.source.wireName} '
              'reason=programmatic_root_cannot_evict_primary_selection',
            );
            return;
          }
          if (existingRoute != null && !_isRootRouteLocation(existingRoute)) {
            _log(
              'save launch route rejected input=$location '
              'source=${metadata.source.wireName} '
              'classification=${metadata.routeClass.wireName} '
              'schemaVersion=${metadata.schemaVersion} '
              'section=${metadata.section?.wireName ?? '<none>'} '
              'canonical=${metadata.canonicalRoute ?? '<none>'} '
              'existingRoute=$existingRoute '
              'reason=programmatic_root_cannot_evict_durable_surface',
            );
            return;
          }
        }
        final previous = (current['routeLocation'] as String?)?.trim();
        current['routeLocation'] = location;
        current[navigationLaunchRouteMetadataKey] = metadata.toJson();
        if (metadata.isCurrentUserPrimaryDurable) {
          current[navigationPrimarySelectionMetadataKey] = metadata.toJson();
        } else if (_isRootRouteLocation(location) &&
            _sourceClearsPrimarySelectionOnRoot(metadata.source)) {
          current.remove(navigationPrimarySelectionMetadataKey);
        }
        _log(
          'save launch route committed before='
          '${previous == null || previous.isEmpty ? '<none>' : previous} '
          'after=$location source=${metadata.source.wireName} '
          'classification=${metadata.routeClass.wireName} '
          'section=${metadata.section?.wireName ?? '<none>'}',
        );
      },
      expectedUserId: intent.userId,
      expectedWindowId: intent.windowId,
    );
    if (result.status == AppRestorationMutationStatus.notReady) {
      if (_pendingLaunchRouteIntent == null) {
        _deferLaunchRouteIntent(intent);
      }
      return const AppRestorationMutationResult(
        AppRestorationMutationStatus.deferred,
      );
    }
    if (result.status == AppRestorationMutationStatus.droppedUserMismatch) {
      _log(
        'launch route mutation dropped expected=${intent.userId} '
        'route=$location reason=user_mismatch',
      );
    }
    return result;
  }

  Future<CalendarRestorationState?> readCalendarState() async {
    return (await readSnapshot())?.calendar;
  }

  Future<AppRestorationMutationResult> saveCalendarState(
    CalendarRestorationState state,
  ) async {
    final validated = CalendarRestorationState.fromJson(state.toJson());
    if (validated == null) {
      return const AppRestorationMutationResult(
        AppRestorationMutationStatus.invalid,
      );
    }
    final activeUserId = await _currentUserId();
    final boundUserId = activeUserId ?? await _readBootFallbackUserId();
    if (boundUserId == null) {
      _log('calendar mutation rejected reason=no_bound_user');
      return const AppRestorationMutationResult(
        AppRestorationMutationStatus.notReady,
      );
    }
    final intent = _PendingCalendarRestorationIntent(
      userId: boundUserId,
      windowId: await _currentWindowId(),
      state: validated,
    );
    if (activeUserId == null) {
      _deferCalendarIntent(intent);
      return const AppRestorationMutationResult(
        AppRestorationMutationStatus.deferred,
      );
    }
    return _persistCalendarIntent(intent);
  }

  Future<DayViewRestorationState?> readDayViewState() async {
    return (await readSnapshot())?.dayView;
  }

  Future<AppRestorationMutationResult> saveDayViewState(
    DayViewRestorationState? state,
  ) async {
    return _mutate((current) {
      if (state == null) {
        current.remove('dayView');
        return;
      }
      final validated = DayViewRestorationState.fromJson(state.toJson());
      if (validated == null) {
        return;
      }
      current['dayView'] = validated.toJson();
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

  Future<AppRestorationMutationResult> saveDaySheetState(
    Map<String, dynamic>? state,
  ) async {
    return _mutate((current) {
      if (state == null || state.isEmpty) {
        current.remove('daySheet');
      } else {
        current['daySheet'] = _coerceJsonMap(state);
      }
    });
  }

  Future<Map<String, dynamic>?> readSurfaceState(String key) async {
    final normalizedKey = key.trim();
    if (normalizedKey.isEmpty) {
      return null;
    }
    final snapshot = await readSnapshot();
    final state = snapshot?.surfaces[normalizedKey];
    return state == null ? null : Map<String, dynamic>.from(state);
  }

  Future<AppRestorationMutationResult> saveSurfaceState(
    String key,
    Map<String, dynamic>? state,
  ) async {
    final normalizedKey = key.trim();
    if (normalizedKey.isEmpty) {
      return const AppRestorationMutationResult(
        AppRestorationMutationStatus.invalid,
      );
    }
    return _mutate((current) {
      final surfaces = _asJsonMapByKey(current['surfaces']);
      final next = <String, Map<String, dynamic>>{...surfaces};
      if (state == null || state.isEmpty) {
        next.remove(normalizedKey);
      } else {
        next[normalizedKey] = _coerceJsonMap(state);
      }
      if (next.isEmpty) {
        current.remove('surfaces');
      } else {
        current['surfaces'] = next;
      }
    });
  }

  Future<List<Map<String, dynamic>>> readOverlayStack() async {
    final snapshot = await readSnapshot();
    return snapshot?.overlayStack
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList(growable: false) ??
        const <Map<String, dynamic>>[];
  }

  Future<AppRestorationMutationResult> saveOverlayStack(
    List<Map<String, dynamic>> overlayStack, {
    OverlayStackMutationReason reason = OverlayStackMutationReason.programmatic,
  }) async {
    final next = _coerceOverlayStack(overlayStack);
    final tombstoneDismissal =
        next.isEmpty && reason == OverlayStackMutationReason.userDismissed;
    final dismissedAtMs = tombstoneDismissal
        ? DateTime.now().millisecondsSinceEpoch
        : null;
    final action = tombstoneDismissal
        ? 'tombstone'
        : next.isEmpty
        ? 'clear'
        : 'save';
    _log(
      'save overlayStack action=$action '
      'reason=${reason.name} '
      'inputCount=${overlayStack.length} overlayCount=${next.length} '
      'overlay=${_overlayStackTrace(next)}'
      '${dismissedAtMs == null ? '' : ' dismissedAtMs=$dismissedAtMs'}',
    );
    return _mutate((current) {
      if (next.isEmpty) {
        current.remove('overlayStack');
        if (dismissedAtMs != null) {
          current['overlayDismissedAtMs'] = dismissedAtMs;
        }
      } else {
        current['overlayStack'] = next;
        current.remove('overlayDismissedAtMs');
      }
    });
  }

  Future<Map<String, dynamic>?> readEditorState(String key) async {
    final normalizedKey = key.trim();
    if (normalizedKey.isEmpty) {
      return null;
    }
    final snapshot = await readSnapshot();
    final state = snapshot?.editors[normalizedKey];
    return state == null ? null : Map<String, dynamic>.from(state);
  }

  Future<AppRestorationMutationResult> saveEditorState(
    String key,
    Map<String, dynamic>? state,
  ) async {
    final normalizedKey = key.trim();
    if (normalizedKey.isEmpty) {
      return const AppRestorationMutationResult(
        AppRestorationMutationStatus.invalid,
      );
    }
    return _mutate((current) {
      final editors = _asJsonMapByKey(current['editors']);
      final next = <String, Map<String, dynamic>>{...editors};
      if (state == null || state.isEmpty) {
        next.remove(normalizedKey);
      } else {
        next[normalizedKey] = _coerceJsonMap(state);
      }
      if (next.isEmpty) {
        current.remove('editors');
      } else {
        current['editors'] = next;
      }
    });
  }

  Future<Map<String, dynamic>?> readCacheHints() async {
    final snapshot = await readSnapshot();
    final hints = snapshot?.cacheHints;
    return hints == null ? null : Map<String, dynamic>.from(hints);
  }

  Future<AppRestorationMutationResult> saveCacheHints(
    Map<String, dynamic>? hints,
  ) async {
    return _mutate((current) {
      if (hints == null || hints.isEmpty) {
        current.remove('cacheHints');
      } else {
        current['cacheHints'] = _coerceJsonMap(hints);
      }
    });
  }
}
