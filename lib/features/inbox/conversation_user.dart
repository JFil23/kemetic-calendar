// lib/features/inbox/conversation_user.dart
// Shared model for conversation user profile

class ConversationUser {
  final String id;
  final String? displayName;
  final String? handle;
  final String? avatarUrl;
  final List<String> avatarGlyphIds;

  ConversationUser({
    required this.id,
    this.displayName,
    this.handle,
    this.avatarUrl,
    this.avatarGlyphIds = const [],
  });
}
