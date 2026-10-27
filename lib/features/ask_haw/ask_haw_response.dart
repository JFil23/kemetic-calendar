import 'package:flutter/foundation.dart';

enum AskHawResponseKind {
  answer,
  choices,
  results,
  proposal,
  success,
  unavailable,
}

@immutable
class AskHawOption {
  const AskHawOption({
    required this.id,
    required this.label,
    this.detail,
    this.reason,
    this.secondary = false,
    this.menuOptions = const [],
  });
  final String id, label;
  final String? detail, reason;
  final bool secondary;
  final List<AskHawOption> menuOptions;
}

@immutable
class AskHawResponse {
  const AskHawResponse({
    required this.title,
    this.body,
    this.options = const [],
    this.kind = AskHawResponseKind.answer,
  });
  final String title;
  final String? body;
  final List<AskHawOption> options;
  final AskHawResponseKind kind;
}
