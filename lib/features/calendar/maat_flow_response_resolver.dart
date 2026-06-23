import 'maat_flow_response_models.dart';
import 'the_decan_watch_flow.dart';

const List<MaatFlowResponseSpec> kPilotMaatFlowResponseSpecs =
    <MaatFlowResponseSpec>[
      MaatFlowResponseSpec(
        id: 'moon-return-set-down',
        flowKey: 'the-moon-return',
        eventKey: 'new',
        surface: MaatFlowResponseSurface.calendarSheet,
        kind: MaatFlowResponseKind.text,
        label: 'What do you set down?',
        journalPolicy: MaatFlowJournalPolicy.mirror,
        journalLabel: 'Moon Return',
      ),
      MaatFlowResponseSpec(
        id: 'moon-return-filled',
        flowKey: 'the-moon-return',
        eventKey: 'full',
        surface: MaatFlowResponseSurface.calendarSheet,
        kind: MaatFlowResponseKind.text,
        label: 'What has filled?',
        journalPolicy: MaatFlowJournalPolicy.mirror,
        journalLabel: 'Moon Return',
      ),
      MaatFlowResponseSpec(
        id: 'course-hour-action',
        flowKey: 'the-course',
        surface: MaatFlowResponseSurface.calendarSheet,
        kind: MaatFlowResponseKind.text,
        label: 'What action fits this hour?',
        journalPolicy: MaatFlowJournalPolicy.mirror,
        journalLabel: 'The Course',
      ),
      MaatFlowResponseSpec(
        id: kDecanWatchResponseVisibilitySpecId,
        flowKey: kDecanWatchFlowKey,
        surface: MaatFlowResponseSurface.calendarSheet,
        kind: MaatFlowResponseKind.choice,
        label: 'Visibility',
        options: <MaatFlowResponseOption>[
          MaatFlowResponseOption(
            id: kDecanWatchVisibilityOutside,
            label: 'Outside',
          ),
          MaatFlowResponseOption(
            id: kDecanWatchVisibilityInside,
            label: 'Inside',
          ),
          MaatFlowResponseOption(
            id: kDecanWatchVisibilityClouded,
            label: 'Clouded',
          ),
          MaatFlowResponseOption(
            id: kDecanWatchVisibilityNotVisible,
            label: 'Not visible',
          ),
        ],
        journalPolicy: MaatFlowJournalPolicy.mirror,
        journalLabel: kDecanWatchTitle,
        journalGroupId: kDecanWatchResponseJournalGroupId,
        journalGroupLabel: kDecanWatchTitle,
        journalFormatter: MaatFlowResponseJournalFormatter.decanWatch,
        journalRole: 'visibility',
      ),
      MaatFlowResponseSpec(
        id: kDecanWatchResponseSkyNoteSpecId,
        flowKey: kDecanWatchFlowKey,
        surface: MaatFlowResponseSurface.calendarSheet,
        kind: MaatFlowResponseKind.multiline,
        label: 'What did the sky show?',
        journalPolicy: MaatFlowJournalPolicy.mirror,
        journalLabel: kDecanWatchTitle,
        journalGroupId: kDecanWatchResponseJournalGroupId,
        journalGroupLabel: kDecanWatchTitle,
        journalFormatter: MaatFlowResponseJournalFormatter.decanWatch,
        journalRole: 'sky_note',
      ),
      MaatFlowResponseSpec(
        id: kDecanWatchResponseBearingSpecId,
        flowKey: kDecanWatchFlowKey,
        surface: MaatFlowResponseSurface.calendarSheet,
        kind: MaatFlowResponseKind.multiline,
        label: 'What bearing do you carry into the next ten days?',
        journalPolicy: MaatFlowJournalPolicy.mirror,
        journalLabel: kDecanWatchTitle,
        journalGroupId: kDecanWatchResponseJournalGroupId,
        journalGroupLabel: kDecanWatchTitle,
        journalFormatter: MaatFlowResponseJournalFormatter.decanWatch,
        journalRole: 'bearing',
      ),
    ];

class MaatFlowResponseResolver {
  const MaatFlowResponseResolver({this.specs = const <MaatFlowResponseSpec>[]});

  final List<MaatFlowResponseSpec> specs;

  List<MaatFlowResponseSpec> resolve({
    required String flowKey,
    required MaatFlowResponseSurface surface,
    String? eventKey,
    String? sittingKey,
  }) {
    final normalizedFlowKey = flowKey.trim();
    if (normalizedFlowKey.isEmpty || specs.isEmpty) {
      return const <MaatFlowResponseSpec>[];
    }

    final normalizedEventKey = eventKey?.trim();
    final normalizedSittingKey = sittingKey?.trim();
    return specs
        .where((spec) {
          if (spec.flowKey != normalizedFlowKey) return false;
          if (!spec.supportsSurface(surface)) return false;
          if (!_optionalKeyMatches(spec.eventKey, normalizedEventKey)) {
            return false;
          }
          if (!_optionalKeyMatches(spec.sittingKey, normalizedSittingKey)) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  bool supports({
    required String flowKey,
    required MaatFlowResponseSurface surface,
    String? eventKey,
    String? sittingKey,
  }) {
    return resolve(
      flowKey: flowKey,
      surface: surface,
      eventKey: eventKey,
      sittingKey: sittingKey,
    ).isNotEmpty;
  }
}

const MaatFlowResponseResolver kDefaultMaatFlowResponseResolver =
    MaatFlowResponseResolver(specs: kPilotMaatFlowResponseSpecs);

List<MaatFlowResponseSpec> resolveMaatFlowResponseSpecs({
  required String flowKey,
  required MaatFlowResponseSurface surface,
  String? eventKey,
  String? sittingKey,
  MaatFlowResponseResolver resolver = kDefaultMaatFlowResponseResolver,
}) {
  return resolver.resolve(
    flowKey: flowKey,
    surface: surface,
    eventKey: eventKey,
    sittingKey: sittingKey,
  );
}

bool _optionalKeyMatches(String? specKey, String? requestedKey) {
  final normalizedSpecKey = specKey?.trim();
  if (normalizedSpecKey == null || normalizedSpecKey.isEmpty) return true;
  return normalizedSpecKey == requestedKey;
}
