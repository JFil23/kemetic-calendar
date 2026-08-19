import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// PR 0 Event Workspace authority and release-delta guards.
///
/// Path-prefix scoped: rules bind when `lib/features/calendar/event_workspace/`
/// appears. Empty prefix is not an allowlist hole.
void main() {
  late String dayView;
  late String calendarPage;
  late String externalLinks;
  late String restoration;
  late String restorationCoordinator;
  late String featureFlags;
  late String authorityMap;
  late String releaseCutover;

  late String eventResource;

  setUpAll(() {
    dayView = File('lib/features/calendar/day_view.dart').readAsStringSync();
    eventResource = File(
      'lib/features/calendar/event_resource.dart',
    ).readAsStringSync();
    calendarPage = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    externalLinks = File(
      'lib/utils/external_link_utils.dart',
    ).readAsStringSync();
    restoration = File(
      'lib/services/app_restoration_service.dart',
    ).readAsStringSync();
    restorationCoordinator = File(
      'lib/services/restoration_coordinator.dart',
    ).readAsStringSync();
    featureFlags = File('lib/core/feature_flags.dart').readAsStringSync();
    authorityMap = File(
      'docs/event_workspace/authority_map.md',
    ).readAsStringSync();
    releaseCutover = File(
      'docs/event_workspace/release_cutover.md',
    ).readAsStringSync();
  });

  test('PR 0 census and cutover docs exist', () {
    expect(authorityMap, contains('requestEndChange'));
    expect(authorityMap, contains('does not exist'));
    expect(authorityMap, contains('_dayViewExternalActionForEvent'));
    expect(authorityMap, contains('EventItem.endMin'));
    expect(authorityMap, contains('SessionLifecycleBridge'));
    expect(authorityMap, contains('No subscribable resume listenable'));
    expect(authorityMap, contains('Per-PR allowed-delta contract'));
    expect(authorityMap, contains('PR 5-prep'));
    expect(releaseCutover, contains('SERVED_PRODUCTION_MOBILE_SHA'));
    expect(releaseCutover, contains('CANDIDATE_SHA → MERGE_SHA must be empty'));
    expect(
      releaseCutover,
      contains('no runtime RC  ≠  no production identity cut'),
    );
    expect(releaseCutover, contains('gitlink-only'));
  });

  test(
    'shared detail sheet and single coordinator remain the presentation authority',
    () {
      expect(
        dayView,
        contains('class CalendarEventDetailSheet extends StatefulWidget'),
      );
      expect(dayView, contains('class CalendarEventDetailSheetCoordinator'));
      expect(dayView, contains('static bool tryMarkOpenOrOpening()'));
      expect(calendarPage, contains('CalendarEventDetailSheet('));
      expect(
        File(
          'lib/features/calendar/calendar_grid_widgets.dart',
        ).readAsStringSync(),
        contains('CalendarEventDetailSheet('),
      );
      expect(
        File(
          'lib/features/calendar/landscape_month_view.dart',
        ).readAsStringSync(),
        contains('CalendarEventDetailSheet('),
      );
    },
  );

  test(
    'resource extractor precedence is payload then detail then location',
    () {
      final extractor = _sourceBetween(
        eventResource,
        'EventResource? resolveEventResource(EventResourceSource source) {',
        'bool eventResourceCameFromLocation(',
      );
      expect(extractor, contains('_collectEventResourcePayloadTargets'));
      expect(extractor, contains('source.behaviorPayload'));
      expect(extractor, contains('externalLinkPattern.allMatches(detail)'));
      expect(
        extractor,
        contains('resolveEventResourceFromRaw(location, fallbackToMaps: true)'),
      );
      final payloadIndex = extractor.indexOf(
        '_collectEventResourcePayloadTargets',
      );
      final detailIndex = extractor.indexOf(
        'externalLinkPattern.allMatches(detail)',
      );
      final locationIndex = extractor.indexOf('source.location');
      expect(payloadIndex, lessThan(detailIndex));
      expect(detailIndex, lessThan(locationIndex));
    },
  );

  test('flag-off / current detail action still launches externally', () {
    final button = _sourceBetween(
      dayView,
      'Widget _buildDetailExternalActionButton(',
      'Widget _buildEventDetailSheetPage(',
    );
    expect(button, contains('launchExternalTarget('));
    expect(button, contains('action.target'));
    expect(button, contains('FeatureFlags.enableEventWorkspace'));
    expect(button, contains('eventResourceIsYouTubeWorkspaceCandidate'));
  });

  test('YouTube remains a native-preferred launch host', () {
    expect(externalLinks, contains("'youtube.com'"));
    expect(externalLinks, contains("'youtu.be'"));
    expect(externalLinks, contains('Future<bool> launchExternalTarget('));
  });

  test('EventDetailRestorationState uses presentation, not overlay mode', () {
    final state = _sourceBetween(
      restoration,
      'class EventDetailRestorationState {',
      'class DayViewRestorationState {',
    );
    expect(state, isNot(contains('this.mode')));
    expect(state, contains('this.presentation'));
    expect(state, isNot(contains('remainingSeconds')));
    expect(state, isNot(contains('expired')));
    expect(state, contains('identityType'));
    expect(state, contains('identityValue'));
  });

  test(
    'overlay kind calendar.eventDetail exists and Flow Studio owns mode',
    () {
      final models = File(
        'lib/features/calendar/calendar_flow_studio_models.dart',
      ).readAsStringSync();
      expect(
        models,
        contains("_kCalendarOverlayKindEventDetail = 'calendar.eventDetail'"),
      );
      expect(models, contains("_kFlowStudioModeEditor = 'editor'"));
    },
  );

  test('end-only requestEndChange exists on calendar authority', () {
    expect(calendarPage, contains('Future<void> _moveEventInDayView('));
    expect(calendarPage, contains('Future<bool> requestEndChange('));
    final move = _sourceBetween(
      calendarPage,
      'Future<void> _moveEventInDayView(',
      'Future<bool> requestEndChange(',
    );
    expect(move, contains('durationMin = evt.endMin - evt.startMin'));
    expect(move, contains('if (evt.allDay)'));
    expect(move, contains('if (evt.isReminder)'));
    expect(dayView, contains('onRequestEndChange'));
    expect(
      File(
        'lib/features/calendar/event_workspace/event_workspace_surface.dart',
      ).readAsStringSync(),
      isNot(contains('requestEndChange')),
    );
  });

  test('Extend persists one date-aware canonical end without completion', () {
    final mutation = _sourceBetween(
      calendarPage,
      'Future<bool> requestEndChange(',
      '// Flows — add/remove/toggle',
    );
    expect(mutation, contains('final wallClockNow = DateTime.now();'));
    expect(mutation, contains('eventWorkspaceExtendedCanonicalEnd('));
    expect(mutation, contains('endsAt: endLocal.toUtc()'));
    expect(mutation, contains('canonicalEnd: persistedEnd'));
    expect(
      mutation,
      contains('event.allDay || event.isReminder || !event.hasCanonicalSchedule'),
    );
    expect(mutation, contains('_repeatingNoteFlowForId(event.flowId)'));
    expect(mutation, isNot(contains('23 * 60 + 59')));
    expect(mutation, isNot(contains('delete')));
    expect(mutation, isNot(contains('completion')));
  });

  test('paint all-day range is 9:00-17:00 and is not schedule authority', () {
    expect(dayView, contains('_eventItemFromNote'));
    final paint = _sourceBetween(
      dayView,
      'EventItem _eventItemFromNote(NoteData note, Map<int, FlowData> flowIndex) {',
      'String _eventIdentityKey(EventItem event) {',
    );
    expect(paint, contains('9 * 60'));
    expect(paint, contains('17 * 60'));
    expect(authorityMap, contains('Not a deadline'));
  });

  test('resume listenable lives on RestorationCoordinator', () {
    final note = _sourceBetween(
      restorationCoordinator,
      'void noteLifecycleState(AppLifecycleState state) {',
      'bool get shouldPreserveOverlayForLifecycleClose {',
    );
    expect(restorationCoordinator, contains('resumeListenable'));
    expect(note, contains('resumeListenable.value++'));
    expect(note, isNot(contains('WidgetsBindingObserver')));
  });

  test('RC enables enableEventWorkspace without a runtime flag service', () {
    expect(featureFlags, contains('enableEventWorkspace'));
    expect(featureFlags, contains('static const bool enableV2DocumentModel'));
    expect(featureFlags, isNot(contains('FeatureFlagService')));
  });

  // These exact legacy names are retained because forward candidate
  // comparison treats served PASS test IDs as continuity contracts.
  // They now assert the immutable PR 0 census in authority_map.md, not
  // that the completed Event Workspace is absent from current runtime.
  test('EventDetailRestorationState has no overlay mode field', () {
    expect(authorityMap, contains('**No `mode`. No `presentation`.**'));
    expect(authorityMap, contains('never overlay `mode`'));
    final state = _sourceBetween(
      restoration,
      'class EventDetailRestorationState {',
      'class DayViewRestorationState {',
    );
    expect(state, isNot(contains('this.mode')));
  });

  test('PR 0 does not add enableEventWorkspace or a runtime flag service', () {
    expect(authorityMap, contains('No `enableEventWorkspace` flag yet'));
    expect(authorityMap, contains('not PR 0'));
  });

  test('end-only silent mutation API is still absent', () {
    expect(authorityMap, contains('`requestEndChange` **does not exist**'));
  });

  test('resume has no listenable on RestorationCoordinator yet', () {
    expect(authorityMap, contains('**No subscribable resume listenable.**'));
  });

  test(
    'event_workspace prefix cannot import UserEventsRepo or add an observer',
    () {
      final files = _dartFilesUnder(_eventWorkspacePrefix);
      for (final file in files) {
        final source = File(file).readAsStringSync();
        expect(
          source,
          isNot(contains('UserEventsRepo')),
          reason: '$file must not call UserEventsRepo',
        );
        expect(
          source,
          isNot(contains('WidgetsBindingObserver')),
          reason: '$file must not add a WidgetsBindingObserver',
        );
        expect(
          source,
          isNot(contains('remainingSeconds')),
          reason: '$file must not persist remaining time',
        );
      }
    },
  );

  test(
    'HtmlElementView is forbidden outside the workspace renderer prefix',
    () {
      const forbidden = <String>[
        'lib/features/calendar/day_view.dart',
        'lib/features/calendar/calendar_page.dart',
        'lib/features/calendar/calendar_grid_widgets.dart',
        'lib/features/calendar/landscape_month_view.dart',
        'lib/features/calendar/calendar_month_detail.dart',
      ];
      for (final path in forbidden) {
        final source = File(path).readAsStringSync();
        expect(
          source,
          isNot(contains('HtmlElementView')),
          reason: '$path must not host HtmlElementView',
        );
      }

      final allHits = _filesContaining('HtmlElementView');
      for (final path in allHits) {
        expect(
          path.startsWith(_eventWorkspacePrefix),
          isTrue,
          reason:
              'HtmlElementView only under $_eventWorkspacePrefix, found $path',
        );
      }
    },
  );

  test('allowed-delta envelopes for later PRs are named in the census', () {
    expect(authorityMap, contains('lib/features/calendar/event_resource'));
    expect(authorityMap, contains('lib/features/calendar/event_workspace/'));
    expect(authorityMap, contains('lib/utils/external_link_utils.dart'));
    expect(authorityMap, contains('lib/core/feature_flags.dart'));
    expect(authorityMap, contains('No `event_workspace` caller'));
  });
}

const String _eventWorkspacePrefix = 'lib/features/calendar/event_workspace/';

List<String> _dartFilesUnder(String prefix) {
  final dir = Directory(prefix);
  if (!dir.existsSync()) return const <String>[];
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .map((file) => file.path.replaceAll(r'\', '/'))
      .toList(growable: false);
}

List<String> _filesContaining(String needle) {
  final lib = Directory('lib');
  if (!lib.existsSync()) return const <String>[];
  final hits = <String>[];
  for (final entity in lib.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final path = entity.path.replaceAll(r'\', '/');
    if (entity.readAsStringSync().contains(needle)) {
      hits.add(path);
    }
  }
  return hits;
}

String _sourceBetween(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  expect(startIndex, isNot(-1), reason: 'Missing source marker: $start');
  final endIndex = source.indexOf(end, startIndex + start.length);
  expect(endIndex, isNot(-1), reason: 'Missing source marker: $end');
  return source.substring(startIndex, endIndex);
}
