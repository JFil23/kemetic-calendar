// lib/features/inbox/conversation_user.dart
// Shared model for conversation user profile

class ConversationUser {
  final String id;
  final String? displayName;
  final String? handle;
  final String? avatarUrl;

  ConversationUser({
    required this.id,
    this.displayName,
    this.handle,
    this.avatarUrl,
  });
}




