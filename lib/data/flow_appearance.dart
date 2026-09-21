import 'package:flutter/foundation.dart';

enum FlowSignKind {
  palmCount('palm_count'),
  shen('shen'),
  gatheringVessel('gathering_vessel'),
  riverPath('river_path'),
  papyrus('papyrus'),
  kheper('kheper');

  const FlowSignKind(this.wireName);

  final String wireName;

  static FlowSignKind? fromWireName(Object? value) {
    final wireName = value?.toString().trim();
    if (wireName == null || wireName.isEmpty) return null;
    for (final kind in values) {
      if (kind.wireName == wireName) return kind;
    }
    return null;
  }
}

@immutable
class FlowAppearance {
  const FlowAppearance({
    this.imageObjectPath,
    this.signKind,
    this.signLabel,
    this.accentArgb,
  });

  static const int schemaVersion = 1;
  static const empty = FlowAppearance();

  final String? imageObjectPath;
  final FlowSignKind? signKind;
  final String? signLabel;
  final int? accentArgb;

  bool get hasImage => imageObjectPath?.trim().isNotEmpty == true;
  bool get hasSign => signKind != null;
  // Accent is supporting color, not an appearance on its own. A flow with
  // neither an image nor a sign must continue to use the legacy surfaces.
  bool get isEmpty => !hasImage && !hasSign;

  FlowAppearance copyWith({
    String? imageObjectPath,
    bool clearImage = false,
    FlowSignKind? signKind,
    bool clearSign = false,
    String? signLabel,
    bool clearSignLabel = false,
    int? accentArgb,
    bool clearAccent = false,
  }) {
    return FlowAppearance(
      imageObjectPath: clearImage
          ? null
          : (imageObjectPath ?? this.imageObjectPath),
      signKind: clearSign ? null : (signKind ?? this.signKind),
      signLabel: clearSignLabel ? null : (signLabel ?? this.signLabel),
      accentArgb: clearAccent ? null : (accentArgb ?? this.accentArgb),
    );
  }

  Map<String, dynamic>? toJsonOrNull() {
    if (isEmpty) return null;
    return <String, dynamic>{
      'version': schemaVersion,
      if (hasImage) 'image_object_path': imageObjectPath!.trim(),
      if (signKind != null) 'sign_kind': signKind!.wireName,
      if (signLabel?.trim().isNotEmpty == true) 'sign_label': signLabel!.trim(),
      if (accentArgb != null) 'accent_argb': accentArgb,
    };
  }

  factory FlowAppearance.fromJson(Object? raw) {
    if (raw is! Map) return empty;
    final json = raw.map<String, dynamic>(
      (key, value) => MapEntry(key.toString(), value),
    );
    final imagePath = json['image_object_path']?.toString().trim();
    final label = json['sign_label']?.toString().trim();
    return FlowAppearance(
      imageObjectPath: imagePath == null || imagePath.isEmpty
          ? null
          : imagePath,
      signKind: FlowSignKind.fromWireName(json['sign_kind']),
      signLabel: label == null || label.isEmpty ? null : label,
      accentArgb: (json['accent_argb'] as num?)?.toInt(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FlowAppearance &&
      other.imageObjectPath == imageObjectPath &&
      other.signKind == signKind &&
      other.signLabel == signLabel &&
      other.accentArgb == accentArgb;

  @override
  int get hashCode =>
      Object.hash(imageObjectPath, signKind, signLabel, accentArgb);
}
