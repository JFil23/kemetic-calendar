import 'package:flutter/foundation.dart';

/// A factual item from one decan. Text is either authored by the account owner
/// or a label from the source catalog; the review never infers a life outcome.
@immutable
class DecanMoment {
  const DecanMoment({
    required this.id,
    required this.kind,
    required this.sourceId,
    required this.occurredOn,
    required this.sourceLabel,
    required this.actionLabel,
    required this.text,
    this.flowId,
    this.eventNumber,
    this.flowKey,
    this.libraryId,
    this.journalEntryId,
    this.isQuote = false,
  });

  final String id;
  final String kind;
  final String sourceId;
  final DateTime? occurredOn;
  final String sourceLabel;
  final String actionLabel;
  final String text;
  final int? flowId, eventNumber;
  final String? flowKey;
  final String? libraryId;
  final String? journalEntryId;
  final bool isQuote;

  factory DecanMoment.fromJson(Map<String, dynamic> j) => DecanMoment(
    id: j['id'] as String,
    kind: j['kind'] as String,
    sourceId: j['source_id'] as String,
    occurredOn: j['occurred_on'] == null
        ? null
        : DateTime.parse(j['occurred_on'] as String),
    sourceLabel: j['source_label'] as String,
    actionLabel: j['action_label'] as String,
    text: j['text'] as String,
    flowId: (j['flow_id'] as num?)?.toInt(),
    eventNumber: (j['event_number'] as num?)?.toInt(),
    flowKey: j['flow_key'] as String?,
    libraryId: j['library_id'] as String?,
    journalEntryId: j['journal_entry_id'] as String?,
    isQuote: j['is_quote'] == true,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'source_id': sourceId,
    'occurred_on': occurredOn?.toIso8601String(),
    'source_label': sourceLabel,
    'action_label': actionLabel,
    'text': text,
    'flow_id': flowId,
    'event_number': eventNumber,
    'flow_key': flowKey,
    'library_id': libraryId,
    'journal_entry_id': journalEntryId,
    'is_quote': isQuote,
  };

  bool get isOwn => kind == 'own';
  bool get hasDestination =>
      flowId != null ||
      flowKey != null ||
      libraryId != null ||
      journalEntryId != null;

  int? dayIn(DateTime decanStart) {
    final date = occurredOn;
    if (date == null) return null;
    final start = DateTime.utc(
      decanStart.year,
      decanStart.month,
      decanStart.day,
    );
    final day =
        DateTime.utc(date.year, date.month, date.day).difference(start).inDays +
        1;
    return day >= 1 && day <= 10 ? day : null;
  }
}

@immutable
class DecanContinuation {
  const DecanContinuation({
    required this.id,
    required this.title,
    required this.reason,
    this.flowKey,
    this.libraryId,
  });

  final String id;
  final String title;
  final String reason;
  final String? flowKey;
  final String? libraryId;
  bool get isReading => libraryId != null;
}
