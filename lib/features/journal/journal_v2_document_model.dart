// lib/features/journal/journal_v2_document_model.dart
// Journal V2 Document Model - Core data structures for rich text, drawing, and charts

const int kJournalDocVersion = 1;

/// Main document container for Journal V2
class JournalDocument {
  final int version;
  final List<JournalBlock> blocks;
  final Map<String, dynamic> meta;

  const JournalDocument({
    required this.version,
    required this.blocks,
    this.meta = const {},
  });

  /// Create from JSON (loaded from storage)
  factory JournalDocument.fromJson(Map<String, dynamic> json) {
    return JournalDocument(
      version: json['version'] ?? kJournalDocVersion,
      blocks: (json['blocks'] as List?)
          ?.map((b) => JournalBlock.fromJson(b as Map<String, dynamic>))
          .toList() ?? [],
      meta: json['meta'] as Map<String, dynamic>? ?? {},
    );
  }

  /// Convert to JSON (for storage)
  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'blocks': blocks.map((b) => b.toJson()).toList(),
      'meta': meta,
    };
  }

  /// Create from plain text (migration from V1)
  factory JournalDocument.fromPlainText(String text) {
    return JournalDocument(
      version: kJournalDocVersion,
      blocks: [
        ParagraphBlock(
          id: 'p-${DateTime.now().millisecondsSinceEpoch}',
          ops: [TextOp(insert: text.isEmpty ? '\n' : text)],
        ),
      ],
      meta: {'migrated_from_v1': true},
    );
  }

  /// Convert to plain text (for V1 compatibility)
  String toPlainText() {
    return blocks
        .whereType<ParagraphBlock>()
        .map((block) => block.ops.map((op) => op.insert).join())
        .join('\n');
  }

  /// Deep copy
  JournalDocument copyWith({
    int? version,
    List<JournalBlock>? blocks,
    Map<String, dynamic>? meta,
  }) {
    return JournalDocument(
      version: version ?? this.version,
      blocks: blocks ?? List.from(this.blocks),
      meta: meta ?? Map.from(this.meta),
    );
  }
}

/// Base class for all document blocks
abstract class JournalBlock {
  final String id;
  final String type;

  const JournalBlock({
    required this.id,
    required this.type,
  });

  /// Create from JSON
  factory JournalBlock.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    switch (type) {
      case 'paragraph':
        return ParagraphBlock.fromJson(json);
      case 'drawing':
        return DrawingBlock.fromJson(json);
      case 'chart':
        return ChartBlock.fromJson(json);
      default:
        throw ArgumentError('Unknown block type: $type');
    }
  }

  /// Convert to JSON
  Map<String, dynamic> toJson();
}

/// Text paragraph block with rich formatting
class ParagraphBlock extends JournalBlock {
  final List<TextOp> ops;

  const ParagraphBlock({
    required super.id,
    required this.ops,
  }) : super(type: 'paragraph');

  /// Create from JSON
  factory ParagraphBlock.fromJson(Map<String, dynamic> json) {
    return ParagraphBlock(
      id: json['id'] as String,
      ops: (json['ops'] as List?)
          ?.map((o) => TextOp.fromJson(o as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  /// Convert to JSON
  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'ops': ops.map((o) => o.toJson()).toList(),
    };
  }

  /// Deep copy
  ParagraphBlock copyWith({
    String? id,
    List<TextOp>? ops,
  }) {
    return ParagraphBlock(
      id: id ?? this.id,
      ops: ops ?? List.from(this.ops),
    );
  }
}

/// Text operation with formatting attributes
class TextOp {
  final String insert;
  final TextAttrs? attrs;

  const TextOp({
    required this.insert,
    this.attrs,
  });

  /// Create from JSON
  factory TextOp.fromJson(Map<String, dynamic> json) {
    return TextOp(
      insert: json['insert'] as String,
      attrs: json['attrs'] != null
          ? TextAttrs.fromJson(json['attrs'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'insert': insert,
      if (attrs != null) 'attrs': attrs!.toJson(),
    };
  }

  /// Deep copy
  TextOp copyWith({
    String? insert,
    TextAttrs? attrs,
  }) {
    return TextOp(
      insert: insert ?? this.insert,
      attrs: attrs ?? this.attrs,
    );
  }
}

/// Text formatting attributes
class TextAttrs {
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strikethrough;
  final String? color;
  final String? backgroundColor;

  const TextAttrs({
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strikethrough = false,
    this.color,
    this.backgroundColor,
  });

  /// Create from JSON
  factory TextAttrs.fromJson(Map<String, dynamic> json) {
    return TextAttrs(
      bold: json['bold'] as bool? ?? false,
      italic: json['italic'] as bool? ?? false,
      underline: json['underline'] as bool? ?? false,
      strikethrough: json['strikethrough'] as bool? ?? false,
      color: json['color'] as String?,
      backgroundColor: json['backgroundColor'] as String?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{};
    if (bold) result['bold'] = bold;
    if (italic) result['italic'] = italic;
    if (underline) result['underline'] = underline;
    if (strikethrough) result['strikethrough'] = strikethrough;
    if (color != null) result['color'] = color;
    if (backgroundColor != null) result['backgroundColor'] = backgroundColor;
    return result;
  }

  /// Deep copy
  TextAttrs copyWith({
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strikethrough,
    String? color,
    String? backgroundColor,
  }) {
    return TextAttrs(
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      strikethrough: strikethrough ?? this.strikethrough,
      color: color ?? this.color,
      backgroundColor: backgroundColor ?? this.backgroundColor,
    );
  }

  /// Check if any formatting is applied
  bool get hasFormatting {
    return bold ||
        italic ||
        underline ||
        strikethrough ||
        color != null ||
        backgroundColor != null;
  }
}

/// Drawing block with strokes
class DrawingBlock extends JournalBlock {
  final List<DrawingStroke> strokes;
  final DrawingTransform? transform;

  const DrawingBlock({
    required super.id,
    required this.strokes,
    this.transform,
  }) : super(type: 'drawing');

  /// Create from JSON
  factory DrawingBlock.fromJson(Map<String, dynamic> json) {
    return DrawingBlock(
      id: json['id'] as String,
      strokes: (json['strokes'] as List?)
          ?.map((s) => DrawingStroke.fromJson(s as Map<String, dynamic>))
          .toList() ?? [],
      transform: json['transform'] != null
          ? DrawingTransform.fromJson(json['transform'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Convert to JSON
  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'strokes': strokes.map((s) => s.toJson()).toList(),
      if (transform != null) 'transform': transform!.toJson(),
    };
  }

  /// Deep copy
  DrawingBlock copyWith({
    String? id,
    List<DrawingStroke>? strokes,
    DrawingTransform? transform,
  }) {
    return DrawingBlock(
      id: id ?? this.id,
      strokes: strokes ?? List.from(this.strokes),
      transform: transform ?? this.transform,
    );
  }
}

/// Individual drawing stroke
class DrawingStroke {
  final List<StrokePoint> points;
  final int color;
  final double width;
  final String tool; // 'pen', 'highlighter', 'eraser'

  const DrawingStroke({
    required this.points,
    required this.color,
    required this.width,
    required this.tool,
  });

  /// Create from JSON
  factory DrawingStroke.fromJson(Map<String, dynamic> json) {
    return DrawingStroke(
      points: (json['points'] as List?)
          ?.map((p) => StrokePoint.fromJson(p as Map<String, dynamic>))
          .toList() ?? [],
      color: json['color'] as int,
      width: (json['width'] as num).toDouble(),
      tool: json['tool'] as String,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'points': points.map((p) => p.toJson()).toList(),
      'color': color,
      'width': width,
      'tool': tool,
    };
  }

  /// Deep copy
  DrawingStroke copyWith({
    List<StrokePoint>? points,
    int? color,
    double? width,
    String? tool,
  }) {
    return DrawingStroke(
      points: points ?? List.from(this.points),
      color: color ?? this.color,
      width: width ?? this.width,
      tool: tool ?? this.tool,
    );
  }
}

/// Point in a drawing stroke
class StrokePoint {
  final double x;
  final double y;

  const StrokePoint({
    required this.x,
    required this.y,
  });

  /// Create from JSON
  factory StrokePoint.fromJson(Map<String, dynamic> json) {
    return StrokePoint(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
    };
  }

  /// Deep copy
  StrokePoint copyWith({
    double? x,
    double? y,
  }) {
    return StrokePoint(
      x: x ?? this.x,
      y: y ?? this.y,
    );
  }
}

/// Drawing transform (scale, rotation, translation)
class DrawingTransform {
  final double scaleX;
  final double scaleY;
  final double rotation;
  final double translateX;
  final double translateY;

  const DrawingTransform({
    this.scaleX = 1.0,
    this.scaleY = 1.0,
    this.rotation = 0.0,
    this.translateX = 0.0,
    this.translateY = 0.0,
  });

  /// Create from JSON
  factory DrawingTransform.fromJson(Map<String, dynamic> json) {
    return DrawingTransform(
      scaleX: (json['scaleX'] as num?)?.toDouble() ?? 1.0,
      scaleY: (json['scaleY'] as num?)?.toDouble() ?? 1.0,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
      translateX: (json['translateX'] as num?)?.toDouble() ?? 0.0,
      translateY: (json['translateY'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'scaleX': scaleX,
      'scaleY': scaleY,
      'rotation': rotation,
      'translateX': translateX,
      'translateY': translateY,
    };
  }

  /// Deep copy
  DrawingTransform copyWith({
    double? scaleX,
    double? scaleY,
    double? rotation,
    double? translateX,
    double? translateY,
  }) {
    return DrawingTransform(
      scaleX: scaleX ?? this.scaleX,
      scaleY: scaleY ?? this.scaleY,
      rotation: rotation ?? this.rotation,
      translateX: translateX ?? this.translateX,
      translateY: translateY ?? this.translateY,
    );
  }
}

/// Chart block with data and options
class ChartBlock extends JournalBlock {
  final ChartData data;
  final ChartOptions options;

  const ChartBlock({
    required super.id,
    required this.data,
    required this.options,
  }) : super(type: 'chart');

  /// Create from JSON
  factory ChartBlock.fromJson(Map<String, dynamic> json) {
    return ChartBlock(
      id: json['id'] as String,
      data: ChartData.fromJson(json['data'] as Map<String, dynamic>),
      options: ChartOptions.fromJson(json['options'] as Map<String, dynamic>),
    );
  }

  /// Convert to JSON
  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'data': data.toJson(),
      'options': options.toJson(),
    };
  }

  /// Deep copy
  ChartBlock copyWith({
    String? id,
    ChartData? data,
    ChartOptions? options,
  }) {
    return ChartBlock(
      id: id ?? this.id,
      data: data ?? this.data,
      options: options ?? this.options,
    );
  }
}

/// Chart data structure
class ChartData {
  final List<String> labels;
  final List<ChartSeries> series;

  const ChartData({
    required this.labels,
    required this.series,
  });

  /// Create from JSON
  factory ChartData.fromJson(Map<String, dynamic> json) {
    return ChartData(
      labels: (json['labels'] as List?)?.cast<String>() ?? [],
      series: (json['series'] as List?)
          ?.map((s) => ChartSeries.fromJson(s as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'labels': labels,
      'series': series.map((s) => s.toJson()).toList(),
    };
  }

  /// Deep copy
  ChartData copyWith({
    List<String>? labels,
    List<ChartSeries>? series,
  }) {
    return ChartData(
      labels: labels ?? List.from(this.labels),
      series: series ?? List.from(this.series),
    );
  }
}

/// Chart series data
class ChartSeries {
  final String name;
  final List<num> values;
  final String color;

  const ChartSeries({
    required this.name,
    required this.values,
    required this.color,
  });

  /// Create from JSON
  factory ChartSeries.fromJson(Map<String, dynamic> json) {
    return ChartSeries(
      name: json['name'] as String,
      values: (json['values'] as List?)?.cast<num>() ?? [],
      color: json['color'] as String,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'values': values,
      'color': color,
    };
  }

  /// Deep copy
  ChartSeries copyWith({
    String? name,
    List<num>? values,
    String? color,
  }) {
    return ChartSeries(
      name: name ?? this.name,
      values: values ?? List.from(this.values),
      color: color ?? this.color,
    );
  }
}

/// Chart display options
class ChartOptions {
  final String type; // 'line', 'bar', 'pie', etc.
  final String title;
  final bool showLegend;
  final bool showGrid;
  final Map<String, dynamic> style;

  const ChartOptions({
    required this.type,
    required this.title,
    this.showLegend = true,
    this.showGrid = true,
    this.style = const {},
  });

  /// Create from JSON
  factory ChartOptions.fromJson(Map<String, dynamic> json) {
    return ChartOptions(
      type: json['type'] as String,
      title: json['title'] as String,
      showLegend: json['showLegend'] as bool? ?? true,
      showGrid: json['showGrid'] as bool? ?? true,
      style: json['style'] as Map<String, dynamic>? ?? {},
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'title': title,
      'showLegend': showLegend,
      'showGrid': showGrid,
      'style': style,
    };
  }

  /// Deep copy
  ChartOptions copyWith({
    String? type,
    String? title,
    bool? showLegend,
    bool? showGrid,
    Map<String, dynamic>? style,
  }) {
    return ChartOptions(
      type: type ?? this.type,
      title: title ?? this.title,
      showLegend: showLegend ?? this.showLegend,
      showGrid: showGrid ?? this.showGrid,
      style: style ?? Map.from(this.style),
    );
  }
}
