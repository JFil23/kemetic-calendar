import 'package:flutter/material.dart';

import 'completion_status.dart';

const Color kCompletionSkippedBadgeColor = Colors.white38;

Color completionStatusBadgeColor(
  CompletionStatus status, {
  required Color fallback,
}) {
  // Completion badges inherit the source event color; status lives in the
  // signifier. Skipped stays muted because it is not successful continuity.
  switch (status) {
    case CompletionStatus.observed:
    case CompletionStatus.partial:
      return fallback;
    case CompletionStatus.skipped:
      return kCompletionSkippedBadgeColor;
    case CompletionStatus.none:
      return fallback;
  }
}
