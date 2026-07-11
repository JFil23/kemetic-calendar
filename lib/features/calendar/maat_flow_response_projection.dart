import 'package:mobile/core/completion_status.dart';

import 'maat_flow_response_journal_blocks.dart';
import 'maat_flow_response_models.dart';

export 'maat_flow_response_journal_blocks.dart'
    show MaatJournalResponseProjectionKind;

class MaatJournalResponseProjection {
  const MaatJournalResponseProjection({required this.block});

  final MaatJournalResponseBlock block;
}

List<MaatJournalResponseProjection> buildMaatJournalResponseProjections({
  required List<MaatFlowResponseSpec> specs,
  required Map<String, MaatFlowResponseValue> values,
  required CompletionStatus completionStatus,
  required DateTime localDate,
  required String Function(MaatFlowResponseSpec spec) sourceIdForSpec,
  required String Function(MaatFlowResponseSpec spec, String groupId)
  sourceIdForGroup,
}) {
  if (specs.isEmpty) return const <MaatJournalResponseProjection>[];

  final formattedSpecs = <MaatFlowResponseSpec>[];
  final plainTextSpecs = <MaatFlowResponseSpec>[];
  for (final spec in specs) {
    switch (spec.journalBehavior) {
      case MaatFlowJournalBehavior.formatted:
        formattedSpecs.add(spec);
      case MaatFlowJournalBehavior.plainUserText:
        plainTextSpecs.add(spec);
      case MaatFlowJournalBehavior.none:
        break;
    }
  }

  final projections = <MaatJournalResponseProjection>[];
  if (formattedSpecs.isNotEmpty) {
    final previews = buildMaatFlowResponseJournalPreviews(
      specs: formattedSpecs,
      values: values,
      completionStatus: completionStatus,
      localDate: localDate,
      sourceIdForSpec: sourceIdForSpec,
      sourceIdForGroup: sourceIdForGroup,
    );
    final blocks = buildMaatJournalResponseBlocksForPolicy(
      sourceIds: _sourceIdsForSpecs(
        specs: formattedSpecs,
        sourceIdForSpec: sourceIdForSpec,
        sourceIdForGroup: sourceIdForGroup,
      ),
      previews: previews,
      localDate: localDate,
      includedOfferSourceIds: _includedOfferSourceIds(previews),
    );
    projections.addAll(
      blocks.map((block) => MaatJournalResponseProjection(block: block)),
    );
  }

  if (plainTextSpecs.isNotEmpty) {
    final includeText =
        completionStatus == CompletionStatus.observed ||
        completionStatus == CompletionStatus.partial;
    final blocks = buildMaatJournalPlainUserTextBlocks(
      sourceIds: _sourceIdsForSpecs(
        specs: plainTextSpecs,
        sourceIdForSpec: sourceIdForSpec,
        sourceIdForGroup: sourceIdForGroup,
      ),
      specs: plainTextSpecs,
      values: values,
      localDate: localDate,
      includeText: includeText,
      sourceIdForSpec: sourceIdForSpec,
      sourceIdForGroup: sourceIdForGroup,
    );
    projections.addAll(
      blocks.map((block) => MaatJournalResponseProjection(block: block)),
    );
  }

  return projections;
}

List<String> _sourceIdsForSpecs({
  required List<MaatFlowResponseSpec> specs,
  required String Function(MaatFlowResponseSpec spec) sourceIdForSpec,
  required String Function(MaatFlowResponseSpec spec, String groupId)
  sourceIdForGroup,
}) {
  final sourceIds = <String>[];
  final seenGroups = <String>{};
  for (final spec in specs) {
    final groupId = spec.normalizedJournalGroupId;
    if (groupId == null) {
      sourceIds.add(sourceIdForSpec(spec));
      continue;
    }
    if (seenGroups.add(groupId)) {
      sourceIds.add(sourceIdForGroup(spec, groupId));
    }
  }
  return sourceIds;
}

Set<String> _includedOfferSourceIds(
  Iterable<MaatFlowResponseJournalPreview> previews,
) {
  return previews
      .where((preview) => preview.includeInJournalByDefault)
      .map((preview) => preview.sourceId)
      .toSet();
}
