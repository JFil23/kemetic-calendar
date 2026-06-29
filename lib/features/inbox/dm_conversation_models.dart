import '../../data/profile_avatar_glyphs.dart';
import 'conversation_user.dart';

enum DmConversationType {
  direct,
  group;

  static DmConversationType fromString(String? raw) {
    return raw == 'direct'
        ? DmConversationType.direct
        : DmConversationType.group;
  }
}

class DmConversationMember {
  const DmConversationMember({
    required this.user,
    required this.role,
    this.joinedAt,
    this.leftAt,
    this.mutedAt,
    this.archivedAt,
    this.lastReadAt,
  });

  final ConversationUser user;
  final String role;
  final DateTime? joinedAt;
  final DateTime? leftAt;
  final DateTime? mutedAt;
  final DateTime? archivedAt;
  final DateTime? lastReadAt;

  factory DmConversationMember.fromJson(Map<String, dynamic> json) {
    final userId = _string(json['user_id']) ?? _string(json['id']) ?? '';
    return DmConversationMember(
      user: ConversationUser(
        id: userId,
        displayName: _string(json['display_name']),
        handle: _string(json['handle']),
        avatarUrl: _string(json['avatar_url']),
        avatarGlyphIds: parseProfileAvatarGlyphIds(json['avatar_glyphs']),
      ),
      role: _string(json['role']) ?? 'member',
      joinedAt: _date(json['joined_at']),
      leftAt: _date(json['left_at']),
      mutedAt: _date(json['muted_at']),
      archivedAt: _date(json['archived_at']),
      lastReadAt: _date(json['last_read_at']),
    );
  }
}

class DmConversationMessage {
  const DmConversationMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.kind,
    required this.createdAt,
    this.sender,
    this.clientMessageId,
    this.payloadJson,
    this.editedAt,
    this.deletedAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final String kind;
  final DateTime createdAt;
  final ConversationUser? sender;
  final String? clientMessageId;
  final Map<String, dynamic>? payloadJson;
  final DateTime? editedAt;
  final DateTime? deletedAt;

  factory DmConversationMessage.fromJson(Map<String, dynamic> json) {
    final senderId = _string(json['sender_id']) ?? '';
    return DmConversationMessage(
      id: _string(json['id']) ?? '',
      conversationId: _string(json['conversation_id']) ?? '',
      senderId: senderId,
      body: _string(json['body']) ?? '',
      kind: _string(json['kind']) ?? 'text',
      createdAt:
          _date(json['created_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      sender: ConversationUser(
        id: senderId,
        displayName: _string(json['sender_display_name']),
        handle: _string(json['sender_handle']),
        avatarUrl: _string(json['sender_avatar_url']),
        avatarGlyphIds: parseProfileAvatarGlyphIds(
          json['sender_avatar_glyphs'],
        ),
      ),
      clientMessageId: _string(json['client_message_id']),
      payloadJson: _jsonMap(json['payload_json']),
      editedAt: _date(json['edited_at']),
      deletedAt: _date(json['deleted_at']),
    );
  }
}

class DmConversationSummary {
  const DmConversationSummary({
    required this.id,
    required this.type,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.members,
    required this.unreadCount,
    this.title,
    this.lastReadAt,
    this.mutedAt,
    this.archivedAt,
    this.lastMessageId,
    this.lastSenderId,
    this.lastBody,
    this.lastKind,
    this.lastCreatedAt,
    this.lastSenderDisplayName,
    this.lastSenderHandle,
  });

  final String id;
  final DmConversationType type;
  final String? title;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<DmConversationMember> members;
  final int unreadCount;
  final DateTime? lastReadAt;
  final DateTime? mutedAt;
  final DateTime? archivedAt;
  final String? lastMessageId;
  final String? lastSenderId;
  final String? lastBody;
  final String? lastKind;
  final DateTime? lastCreatedAt;
  final String? lastSenderDisplayName;
  final String? lastSenderHandle;

  bool get hasUnread => unreadCount > 0;
  bool get isMuted => mutedAt != null;

  factory DmConversationSummary.fromJson(Map<String, dynamic> json) {
    return DmConversationSummary(
      id: _string(json['conversation_id']) ?? _string(json['id']) ?? '',
      type: DmConversationType.fromString(_string(json['type'])),
      title: _string(json['title']),
      createdBy: _string(json['created_by']) ?? '',
      createdAt:
          _date(json['created_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      updatedAt:
          _date(json['updated_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      members: _list(json['members'])
          .whereType<Map>()
          .map(
            (item) =>
                DmConversationMember.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((member) => member.user.id.isNotEmpty)
          .toList(growable: false),
      unreadCount: _int(json['unread_count']) ?? 0,
      lastReadAt: _date(json['last_read_at']),
      mutedAt: _date(json['muted_at']),
      archivedAt: _date(json['archived_at']),
      lastMessageId: _string(json['last_message_id']),
      lastSenderId: _string(json['last_sender_id']),
      lastBody: _string(json['last_body']),
      lastKind: _string(json['last_kind']),
      lastCreatedAt: _date(json['last_created_at']),
      lastSenderDisplayName: _string(json['last_sender_display_name']),
      lastSenderHandle: _string(json['last_sender_handle']),
    );
  }

  String titleFor(String? currentUserId) {
    final explicit = title?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;

    final others = members
        .where((member) => member.user.id != currentUserId)
        .map((member) => _displayName(member.user))
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
    if (others.isEmpty) {
      return type == DmConversationType.direct ? 'User' : 'Group chat';
    }
    if (type == DmConversationType.direct) return others.first;
    if (others.length <= 3) return others.join(', ');
    return '${others.take(3).join(', ')} +${others.length - 3}';
  }

  String previewFor(String? currentUserId) {
    final body = lastBody?.trim();
    if (body == null || body.isEmpty) return 'No messages yet';
    if (type == DmConversationType.group &&
        lastSenderId != null &&
        lastSenderId != currentUserId) {
      final sender = (lastSenderDisplayName?.trim().isNotEmpty == true)
          ? lastSenderDisplayName!.trim()
          : (lastSenderHandle?.trim().isNotEmpty == true
                ? '@${lastSenderHandle!.trim()}'
                : 'Someone');
      return '$sender: $body';
    }
    return body;
  }
}

String _displayName(ConversationUser user) {
  final displayName = user.displayName?.trim();
  if (displayName != null && displayName.isNotEmpty) return displayName;
  final handle = user.handle?.trim();
  if (handle != null && handle.isNotEmpty) return '@$handle';
  return 'User';
}

String? _string(Object? raw) {
  if (raw == null) return null;
  final text = raw is String ? raw : raw.toString();
  final trimmed = text.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int? _int(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw.trim());
  return null;
}

DateTime? _date(Object? raw) {
  final text = _string(raw);
  return text == null ? null : DateTime.tryParse(text);
}

List<dynamic> _list(Object? raw) {
  if (raw is List) return raw;
  return const [];
}

Map<String, dynamic>? _jsonMap(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return raw.cast<String, dynamic>();
  return null;
}
