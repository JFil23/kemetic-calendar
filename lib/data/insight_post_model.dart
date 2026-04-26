import 'profile_avatar_glyphs.dart';

class InsightPost {
  final String id;
  final String userId;
  final String insightEntryId;
  final String nodeId;
  final String nodeTitle;
  final String? nodeGlyph;
  final String bodyText;
  final DateTime entryDate;
  final bool isHidden;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? authorHandle;
  final String? authorDisplayName;
  final String? authorAvatarUrl;
  final List<String> authorAvatarGlyphIds;
  final double? feedScore;
  final bool isFollowingAuthor;

  const InsightPost({
    required this.id,
    required this.userId,
    required this.insightEntryId,
    required this.nodeId,
    required this.nodeTitle,
    required this.bodyText,
    required this.entryDate,
    required this.createdAt,
    required this.updatedAt,
    this.nodeGlyph,
    this.isHidden = false,
    this.authorHandle,
    this.authorDisplayName,
    this.authorAvatarUrl,
    this.authorAvatarGlyphIds = const [],
    this.feedScore,
    this.isFollowingAuthor = false,
  });

  factory InsightPost.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic raw, DateTime fallback) {
      if (raw is String) {
        final parsed = DateTime.tryParse(raw);
        if (parsed != null) return parsed;
      }
      return fallback;
    }

    final node = _extractNodeMap(json);
    final profile = _extractProfileMap(json);
    final now = DateTime.now();

    return InsightPost(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      insightEntryId:
          _stringOrNull(json['insight_entry_id']) ??
          _stringOrNull(json['entry_id']) ??
          '',
      nodeId:
          _stringOrNull(json['node_slug']) ??
          _stringOrNull(node?['slug']) ??
          '',
      nodeTitle:
          _stringOrNull(json['node_title']) ??
          _stringOrNull(node?['title']) ??
          'Insight',
      nodeGlyph:
          _stringOrNull(json['node_glyph']) ?? _stringOrNull(node?['glyph']),
      bodyText: json['body_text'] as String? ?? '',
      entryDate: parseDate(json['entry_date'], now),
      isHidden: json['is_hidden'] as bool? ?? false,
      createdAt: parseDate(json['created_at'], now),
      updatedAt: parseDate(json['updated_at'], now),
      authorHandle:
          _stringOrNull(json['author_handle']) ??
          _stringOrNull(profile?['handle']),
      authorDisplayName:
          _stringOrNull(json['author_display_name']) ??
          _stringOrNull(profile?['display_name']),
      authorAvatarUrl:
          _stringOrNull(json['author_avatar_url']) ??
          _stringOrNull(profile?['avatar_url']),
      authorAvatarGlyphIds: parseProfileAvatarGlyphIds(
        json['author_avatar_glyphs'] ?? profile?['avatar_glyphs'],
      ),
      feedScore: (json['score'] as num?)?.toDouble(),
      isFollowingAuthor: (json['is_following_author'] as bool?) ?? false,
    );
  }

  String get authorLabel {
    final display = authorDisplayName?.trim();
    if (display != null && display.isNotEmpty) {
      return display;
    }
    final handle = authorHandle?.trim();
    if (handle != null && handle.isNotEmpty) {
      return '@$handle';
    }
    return 'Community';
  }

  static Map<String, dynamic>? _extractNodeMap(Map<String, dynamic> json) {
    final raw = json['nodes'];
    if (raw is Map<String, dynamic>) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return null;
  }

  static Map<String, dynamic>? _extractProfileMap(Map<String, dynamic> json) {
    final raw = json['profiles'];
    if (raw is Map<String, dynamic>) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return null;
  }

  static String? _stringOrNull(dynamic value) {
    final text = value as String?;
    if (text == null) return null;
    final trimmed = text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
