import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String between(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  expect(startIndex, isNonNegative, reason: 'missing start marker $start');
  final endIndex = source.indexOf(end, startIndex + start.length);
  expect(endIndex, isNonNegative, reason: 'missing end marker $end');
  return source.substring(startIndex, endIndex);
}

void main() {
  late String calendar;
  late String flowPages;

  setUpAll(() {
    calendar = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    flowPages = File(
      'lib/features/calendar/calendar_flow_pages.dart',
    ).readAsStringSync();
  });

  test('completion policy separates staging, navigation, and hydration', () {
    final policy = between(
      calendar,
      'static bool _didStageFlowStudioEvents',
      '// Headless persistence helper',
    );

    expect(policy, contains('_shouldOpenDayViewAfterFlowStudioAdd'));
    expect(policy, contains('_shouldSkipExplicitHydrate'));
    expect(policy, contains('flow.id <= 0'));
    expect(policy, isNot(contains('originType')));
    expect(policy, isNot(contains('originShareId')));
  });

  test(
    'persistence failure clears intent before rollback and resolves entry',
    () {
      final persistence = between(
        calendar,
        'static void _startStagedFlowPersistence',
        'static FlowDetailActionPolicy resolveCanonicalCustomFlowActionPolicy',
      );
      final rollback = between(
        calendar,
        'Future<void> _rollbackStagedFlowLocally',
        'int _removeLocalNotesForFlowReplacement',
      );

      final clearIndex = persistence.indexOf('_clearStagedFlowDayViewIntent');
      final rollbackIndex = persistence.indexOf('await pending.rollback');
      final terminalIndex = persistence.indexOf(
        'pending.completePersistence',
        rollbackIndex,
      );
      expect(clearIndex, isNonNegative);
      expect(rollbackIndex, greaterThan(clearIndex));
      expect(terminalIndex, greaterThan(rollbackIndex));
      expect(persistence, contains('pending.consumeCompletion()'));
      expect(rollback, contains('_flows.removeWhere'));
      expect(rollback, contains('notes.removeWhere'));
      expect(rollback, contains('_unconfirmed.forget'));
    },
  );

  test('Day View consumption never starts persistence a second time', () {
    final consumer = between(
      calendar,
      'Future<void> _consumePendingStagedFlowDayViewIfAny',
      'Future<void> _completeMountedMaatJoinWithDayView',
    );

    expect(consumer, contains('_consumeStagedFlowCompletion(flowId)'));
    expect(consumer, contains('Could not stage the first day of this flow.'));
    expect(consumer, isNot(contains('_startStagedFlowPersistence')));
  });

  test('detached Ma_at and Studio use one outer-route completion', () {
    final completion = between(
      calendar,
      'static void _completeDetachedStagedFlowWithDayView',
      'static Widget _buildDetachedMyFlowsPage',
    );
    final studio = between(
      calendar,
      'static Future<_FlowStudioResult?> _pushDetachedFlowStudioEditor',
      'static Future<_Flow> _moveReadingHouseFlowToCalendarHeadless',
    );
    final maat = between(
      calendar,
      'static Future<void> _completeDetachedMaatJoinWithDayView',
      'static void _completeDetachedStagedFlowWithDayView',
    );

    expect(completion, contains('_armStagedFlowDayView(flowId)'));
    expect(completion, contains('onClose()'));
    expect(completion, contains("closeOrReturn(navigator.context, '/')"));
    expect(completion, contains('_schedulePendingStagedFlowDayViewIfAny()'));
    expect(studio, contains('_completeDetachedStagedFlowWithDayView'));
    expect(maat, contains('_completeDetachedStagedFlowWithDayView'));
  });

  test(
    'shared, preview, and generated callers finish on Calendar Day View',
    () {
      final details = File(
        'lib/features/inbox/shared_flow_details_page.dart',
      ).readAsStringSync();
      final preview = File(
        'lib/features/sharing/share_preview_page.dart',
      ).readAsStringSync();
      final guidance = File(
        'lib/features/maat_guidance/maat_guidance_detail_page.dart',
      ).readAsStringSync();

      for (final source in <String>[details, preview, guidance]) {
        expect(source, contains('completeStagedFlowAddFromAnyContext'));
        expect(source, contains('didStageEvents'));
      }
    },
  );

  test(
    'saved snapshot import stages one deduplicated universal write list',
    () {
      final import = between(
        flowPages,
        'Future<({int flowId, bool didStageEvents})> _importSavedFlow',
        'List<PlannedNoteWrite> _materializeSavedFlowRules',
      );

      expect(import, contains('PlannedNoteWrite('));
      expect(import, contains('actionId: e.actionId'));
      expect(import, contains('behaviorPayload: e.behaviorPayload'));
      expect(import, contains('detailMeta.alertMinutes'));
      expect(import, contains('write.clientEventId: write'));
      expect(import, contains('stagePlannedNotesAndDeferPersist'));
      expect(import, contains('completionRequired: true'));
      expect(import, contains('_startStagedFlowPersistence(newId)'));
      expect(import, isNot(contains('await _eventsRepo.upsertByClientId')));
      expect(import, isNot(contains('getEventsForFlow(newId)')));
    },
  );

  test('saved rules materializer preserves inclusive 91-day semantics', () {
    final materialize = between(
      flowPages,
      'List<PlannedNoteWrite> _materializeSavedFlowRules',
      '({String? detail, String? location, String? category, int? alertMinutes})',
    );

    expect(materialize, contains('Duration(days: 90)'));
    expect(materialize, contains('!date.isAfter(scheduleEnd)'));
    expect(materialize, contains('PlannedNoteWrite('));
    expect(materialize, contains('detailWithMeta ?? noteMeta.detail'));
    expect(materialize, contains('noteMeta.alertMinutes ?? _alertNoneMinutes'));
    expect(materialize, isNot(contains('upsertByClientId')));
  });
}
