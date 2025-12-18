// lib/data/profile_model.dart

class UserProfile {
  final String id;
  final String? handle;
  final String? displayName;
  final String? avatarUrl;
  final String? bio;
  final String? location;
  final bool isDiscoverable;
  final bool allowIncomingShares;
  final int? activeFlowsCount;
  final int? totalFlowEventsCount;
  final DateTime? createdAt;

  UserProfile({
    required this.id,
    this.handle,
    this.displayName,
    this.avatarUrl,
    this.bio,
    this.location,
    this.isDiscoverable = true,
    this.allowIncomingShares = true,
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
      location: json['location'] as String?,
      isDiscoverable: json['is_discoverable'] as bool? ?? true,
      allowIncomingShares: json['allow_incoming_shares'] as bool? ?? true,
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
      'location': location,
      'is_discoverable': isDiscoverable,
      'allow_incoming_shares': allowIncomingShares,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  String get effectiveName => displayName ?? handle ?? 'User';
  bool get isComplete => handle != null && handle!.isNotEmpty;

  UserProfile copyWith({
    String? id,
    String? handle,
    String? displayName,
    String? avatarUrl,
    String? bio,
    String? location,
    bool? isDiscoverable,
    bool? allowIncomingShares,
    int? activeFlowsCount,
    int? totalFlowEventsCount,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      handle: handle ?? this.handle,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      location: location ?? this.location,
      isDiscoverable: isDiscoverable ?? this.isDiscoverable,
      allowIncomingShares: allowIncomingShares ?? this.allowIncomingShares,
      activeFlowsCount: activeFlowsCount ?? this.activeFlowsCount,
      totalFlowEventsCount: totalFlowEventsCount ?? this.totalFlowEventsCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
