import 'package:flutter/material.dart';

import 'completion_status.dart';

const Color kCompletionObservedBadgeColor = Color(0xFF4CAF50);
const Color kCompletionPartialBadgeColor = Color(0xFF64B5F6);
const Color kCompletionSkippedBadgeColor = Colors.white38;

Color completionStatusBadgeColor(
  CompletionStatus status, {
  required Color fallback,
}) {
  switch (status) {
    case CompletionStatus.observed:
      return kCompletionObservedBadgeColor;
    case CompletionStatus.partial:
      return kCompletionPartialBadgeColor;
    case CompletionStatus.skipped:
      return kCompletionSkippedBadgeColor;
    case CompletionStatus.none:
      return fallback;
  }
}
