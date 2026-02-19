class DecanReflection {
  final String id;
  final String decanName;
  final String? decanTheme;
  final DateTime decanStart;
  final DateTime decanEnd;
  final int badgeCount;
  final String reflectionText;
  final DateTime createdAt;

  DecanReflection({
    required this.id,
    required this.decanName,
    required this.decanTheme,
    required this.decanStart,
    required this.decanEnd,
    required this.badgeCount,
    required this.reflectionText,
    required this.createdAt,
  });

  factory DecanReflection.fromJson(Map<String, dynamic> json) {
    return DecanReflection(
      id: json['id'] as String,
      decanName: json['decan_name'] as String? ?? '',
      decanTheme: json['decan_theme'] as String?,
      decanStart: DateTime.parse(json['decan_start'] as String),
      decanEnd: DateTime.parse(json['decan_end'] as String),
      badgeCount: json['badge_count'] as int? ?? 0,
      reflectionText: json['reflection_text'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
