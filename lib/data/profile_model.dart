// lib/data/profile_model.dart

class UserProfile {
  final String id;
  final String? handle;
  final String? displayName;
  final String? avatarUrl;
  final String? bio;
  final int? activeFlowsCount;
  final int? totalFlowEventsCount;
  final DateTime? createdAt;

  UserProfile({
    required this.id,
    this.handle,
    this.displayName,
    this.avatarUrl,
    this.bio,
    this.activeFlowsCount,
    this.totalFlowEventsCount,
    this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      handle: json['handle'] as String?,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      activeFlowsCount: json['active_flows_count'] as int?,
      totalFlowEventsCount: json['total_flow_events_count'] as int?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'handle': handle,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'bio': bio,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  String get effectiveName => displayName ?? handle ?? 'User';
  bool get isComplete => handle != null && handle!.isNotEmpty;
}

