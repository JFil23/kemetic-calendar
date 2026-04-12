import 'package:flutter/foundation.dart';

enum InsightSourceType { nodeUserText, journalEntry, reflectionEntry }

enum InsightTargetType { node, journalEntry, reflectionEntry }

@immutable
class InsightLink {
  final String id;
  final String userId;
  final InsightSourceType sourceType;
  final String sourceId;
  final int start;
  final int end;
  final String selectedText;
  final InsightTargetType targetType;
  final String targetId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const InsightLink({
    required this.id,
    required this.userId,
    required this.sourceType,
    required this.sourceId,
    required this.start,
    required this.end,
    required this.selectedText,
    required this.targetType,
    required this.targetId,
    required this.createdAt,
    required this.updatedAt,
  });

  InsightLink copyWith({
    int? start,
    int? end,
    String? selectedText,
    DateTime? updatedAt,
  }) {
    return InsightLink(
      id: id,
      userId: userId,
      sourceType: sourceType,
      sourceId: sourceId,
      start: start ?? this.start,
      end: end ?? this.end,
      selectedText: selectedText ?? this.selectedText,
      targetType: targetType,
      targetId: targetId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'sourceType': sourceType.name,
      'sourceId': sourceId,
      'start': start,
      'end': end,
      'selectedText': selectedText,
      'targetType': targetType.name,
      'targetId': targetId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory InsightLink.fromJson(Map<String, dynamic> json) {
    InsightSourceType _src(String v) =>
        InsightSourceType.values.firstWhere((e) => e.name == v);
    InsightTargetType _tgt(String v) =>
        InsightTargetType.values.firstWhere((e) => e.name == v);
    return InsightLink(
      id: json['id'] as String,
      userId: json['userId'] as String? ?? '',
      sourceType: _src(json['sourceType'] as String),
      sourceId: json['sourceId'] as String,
      start: json['start'] as int,
      end: json['end'] as int,
      selectedText: json['selectedText'] as String? ?? '',
      targetType: _tgt(json['targetType'] as String),
      targetId: json['targetId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

@immutable
class NodeUserContent {
  final String id;
  final String userId;
  final String nodeId;
  final String text;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NodeUserContent({
    required this.id,
    required this.userId,
    required this.nodeId,
    required this.text,
    required this.createdAt,
    required this.updatedAt,
  });

  NodeUserContent copyWith({
    String? text,
    DateTime? updatedAt,
  }) {
    return NodeUserContent(
      id: id,
      userId: userId,
      nodeId: nodeId,
      text: text ?? this.text,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'nodeId': nodeId,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory NodeUserContent.fromJson(Map<String, dynamic> json) {
    return NodeUserContent(
      id: json['id'] as String,
      userId: json['userId'] as String? ?? '',
      nodeId: json['nodeId'] as String,
      text: json['text'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
