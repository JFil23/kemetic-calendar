import '../domain/track_sky_course.dart';

/// Encodes/decodes course metadata into flow notes without owning the whole notes field.
class TrackSkyCourseMetadataCodec {
  static const String keyCourseId = 'sky_course_id';
  static const String keyLabel = 'sky_course';
  static const String keySource = 'sky_course_source';
  static const String keySourceType = 'sky_course_source_type';
  static const String keyCreatedAt = 'sky_course_created';
  static const String keyVersion = 'sky_course_version';

  static const Set<String> _managedKeys = {
    keyCourseId,
    keyLabel,
    keySource,
    keySourceType,
    keyCreatedAt,
    keyVersion,
  };

  /// Merges course tokens into existing notes, preserving unrelated tokens/prose.
  String encode(TrackSkyCourse course, {String? existingNotes}) {
    final map = _parseTokens(existingNotes);
    for (final key in _managedKeys) {
      map.remove(key);
    }
    map[keyCourseId] = course.courseId;
    map[keyLabel] = Uri.encodeComponent(course.label);
    map[keySourceType] = course.sourceType.wireName;
    if (course.sourceId != null && course.sourceId!.isNotEmpty) {
      map[keySource] = Uri.encodeComponent(course.sourceId!);
    } else {
      map.remove(keySource);
    }
    map[keyCreatedAt] = course.createdAt.toUtc().toIso8601String();
    map[keyVersion] = '${course.schemaVersion}';

    final freeform = _freeformRemainder(existingNotes);
    final encoded = map.entries.map((e) => '${e.key}=${e.value}').join(';');
    if (freeform.isEmpty) return encoded;
    return '$encoded;$freeform';
  }

  TrackSkyCourse? decode(String? flowNotes) {
    if (flowNotes == null || flowNotes.trim().isEmpty) return null;
    final map = _parseTokens(flowNotes);
    final labelRaw = map[keyLabel];
    if (labelRaw == null || labelRaw.isEmpty) return null;
    final label = Uri.decodeComponent(labelRaw);
    final courseId = map[keyCourseId];
    if (courseId == null || courseId.isEmpty) return null;

    TrackSkyCourseSourceType sourceType;
    try {
      sourceType = TrackSkyCourseSourceTypeX.parse(
        map[keySourceType] ?? 'freeText',
      );
    } catch (_) {
      return null;
    }

    final sourceRaw = map[keySource];
    final sourceId =
        sourceRaw == null || sourceRaw.isEmpty ? null : Uri.decodeComponent(sourceRaw);

    final createdRaw = map[keyCreatedAt];
    final createdAt = createdRaw == null
        ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
        : DateTime.tryParse(createdRaw)?.toUtc() ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

    final version = int.tryParse(map[keyVersion] ?? '') ??
        TrackSkyCourse.currentSchemaVersion;

    return TrackSkyCourse(
      courseId: courseId,
      label: label,
      sourceType: sourceType,
      sourceId: sourceId,
      createdAt: createdAt,
      schemaVersion: version,
    );
  }

  Map<String, String> _parseTokens(String? notes) {
    final out = <String, String>{};
    if (notes == null || notes.isEmpty) return out;
    for (final part in notes.split(';')) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      final eq = trimmed.indexOf('=');
      if (eq <= 0) continue;
      final key = trimmed.substring(0, eq).trim();
      final value = trimmed.substring(eq + 1).trim();
      if (key.isEmpty) continue;
      out[key] = value;
    }
    return out;
  }

  String _freeformRemainder(String? notes) {
    if (notes == null || notes.isEmpty) return '';
    final kept = <String>[];
    for (final part in notes.split(';')) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      final eq = trimmed.indexOf('=');
      if (eq <= 0) {
        kept.add(trimmed);
        continue;
      }
      final key = trimmed.substring(0, eq).trim();
      if (_managedKeys.contains(key)) continue;
      // Keep known non-course tokens and any other key=value pairs.
      kept.add(trimmed);
    }
    return kept.join(';');
  }
}
