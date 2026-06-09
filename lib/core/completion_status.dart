enum CompletionStatus { none, observed, partial, skipped }

extension CompletionStatusX on CompletionStatus {
  String get wireName {
    switch (this) {
      case CompletionStatus.none:
        return 'none';
      case CompletionStatus.observed:
        return 'observed';
      case CompletionStatus.partial:
        return 'partial';
      case CompletionStatus.skipped:
        return 'skipped';
    }
  }

  String get label {
    switch (this) {
      case CompletionStatus.none:
        return 'None';
      case CompletionStatus.observed:
        return 'Observed';
      case CompletionStatus.partial:
        return 'Partly';
      case CompletionStatus.skipped:
        return 'Skipped';
    }
  }

  String get maatStatusName {
    switch (this) {
      case CompletionStatus.none:
        return 'none';
      case CompletionStatus.observed:
        return 'observed';
      case CompletionStatus.partial:
        return 'observed_partly';
      case CompletionStatus.skipped:
        return 'skipped';
    }
  }

  bool get createsJournalContinuity => this != CompletionStatus.none;

  static CompletionStatus fromWireName(String? raw) {
    final value = raw?.trim().toLowerCase();
    switch (value) {
      case 'observed':
      case 'done':
      case 'complete':
      case 'completed':
        return CompletionStatus.observed;
      case 'partial':
      case 'partly':
      case 'observed_partly':
      case 'partly_observed':
      case 'in_progress':
        return CompletionStatus.partial;
      case 'skipped':
      case 'skip':
        return CompletionStatus.skipped;
      default:
        return CompletionStatus.none;
    }
  }
}

enum ReflectionStatus { none, userWritten, generated, linked }

extension ReflectionStatusX on ReflectionStatus {
  String get wireName {
    switch (this) {
      case ReflectionStatus.none:
        return 'none';
      case ReflectionStatus.userWritten:
        return 'user_written';
      case ReflectionStatus.generated:
        return 'generated';
      case ReflectionStatus.linked:
        return 'linked';
    }
  }
}

enum CompletionSourceType {
  maatFlow,
  userFlow,
  note,
  reminder,
  itinerary,
  calendarEvent,
}

extension CompletionSourceTypeX on CompletionSourceType {
  String get wireName {
    switch (this) {
      case CompletionSourceType.maatFlow:
        return 'maat_flow';
      case CompletionSourceType.userFlow:
        return 'user_flow';
      case CompletionSourceType.note:
        return 'note';
      case CompletionSourceType.reminder:
        return 'reminder';
      case CompletionSourceType.itinerary:
        return 'itinerary';
      case CompletionSourceType.calendarEvent:
        return 'calendar_event';
    }
  }
}
