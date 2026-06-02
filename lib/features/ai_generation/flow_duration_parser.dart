const int defaultAiFlowDurationDays = 10;

enum FlowDateRangeSource { prompt, defaultDuration, manual }

class FlowDateRange {
  const FlowDateRange({
    required this.startDate,
    required this.endDate,
    required this.durationDays,
    required this.source,
  });

  final DateTime startDate;
  final DateTime endDate;
  final int durationDays;
  final FlowDateRangeSource source;
}

int? extractFlowDurationDays(String prompt) {
  final match = RegExp(
    r'\b([1-9]\d*)\s*(?:-\s*)?(day|days|week|weeks)\b',
    caseSensitive: false,
  ).firstMatch(prompt);
  if (match == null) return null;

  final value = int.tryParse(match.group(1)!);
  if (value == null || value <= 0) return null;

  final unit = match.group(2)!.toLowerCase();
  if (unit.startsWith('week')) return value * 7;
  return value;
}

FlowDateRange flowDateRangeForDuration({
  required DateTime startDate,
  required int durationDays,
  required FlowDateRangeSource source,
}) {
  final safeDuration = durationDays < 1 ? 1 : durationDays;
  final start = dateOnlyForAiFlow(startDate);
  return FlowDateRange(
    startDate: start,
    endDate: DateTime(start.year, start.month, start.day + safeDuration - 1),
    durationDays: safeDuration,
    source: source,
  );
}

FlowDateRange resolveAiFlowDateRange({
  required String prompt,
  required DateTime defaultStartDate,
  DateTime? manualStartDate,
  DateTime? manualEndDate,
  bool useManualRange = false,
}) {
  if (useManualRange && manualStartDate != null && manualEndDate != null) {
    final start = dateOnlyForAiFlow(manualStartDate);
    final end = dateOnlyForAiFlow(manualEndDate);
    return FlowDateRange(
      startDate: start,
      endDate: end,
      durationDays: end.difference(start).inDays + 1,
      source: FlowDateRangeSource.manual,
    );
  }

  final promptDuration = extractFlowDurationDays(prompt);
  return flowDateRangeForDuration(
    startDate: defaultStartDate,
    durationDays: promptDuration ?? defaultAiFlowDurationDays,
    source: promptDuration == null
        ? FlowDateRangeSource.defaultDuration
        : FlowDateRangeSource.prompt,
  );
}

DateTime dateOnlyForAiFlow(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}
