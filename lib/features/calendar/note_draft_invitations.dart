import '../../data/profile_repo.dart';
import '../../data/share_models.dart';

/// Editor-owned selection. Saving the event must be acknowledged before sharing.
/// A failed invitation retry reuses the saved event, never recreates the note.
class NoteDraftInvitations {
  NoteDraftInvitations({required this.accountId});

  final String? accountId;
  List<UserSearchResult> people = [];
  String? savedTargetId;
  bool busy = false;

  Map<String, dynamic> toJson() => {
    'accountId': accountId,
    'savedTargetId': savedTargetId,
    'people': people
        .map(
          (p) => {
            'userId': p.userId,
            'handle': p.handle,
            'displayName': p.displayName,
            'avatarUrl': p.avatarUrl,
            'avatarGlyphIds': p.avatarGlyphIds,
          },
        )
        .toList(),
  };

  factory NoteDraftInvitations.restore(Object? raw, String? currentAccountId) {
    final draft = NoteDraftInvitations(accountId: currentAccountId);
    if (raw is! Map ||
        raw['accountId'] != currentAccountId ||
        currentAccountId == null) {
      return draft;
    }
    draft.savedTargetId = raw['savedTargetId'] as String?;
    draft.people = (raw['people'] as List? ?? [])
        .whereType<Map>()
        .map(
          (p) => UserSearchResult(
            userId: p['userId'] as String,
            handle: p['handle'] as String?,
            displayName: p['displayName'] as String?,
            avatarUrl: p['avatarUrl'] as String?,
            avatarGlyphIds: (p['avatarGlyphIds'] as List? ?? []).cast<String>(),
          ),
        )
        .toList();
    return draft;
  }

  Future<bool> saveAndInvite({
    required String? Function() currentAccountId,
    required Future<String> Function() saveEvent,
    required Future<List<ShareResult>> Function(String, List<ShareRecipient>)
    send,
    required Future<void> Function() checkpoint,
  }) async {
    if (busy) return false;
    void checkAccount() {
      if (accountId == null || accountId != currentAccountId()) {
        throw StateError(
          'The account changed. Reopen the note in its account.',
        );
      }
    }

    busy = true;
    try {
      checkAccount();
      savedTargetId ??= await saveEvent();
      await checkpoint();
      checkAccount();
      final recipients = people.map((person) => person.toRecipient()).toList();
      final results = await send(savedTargetId!, recipients);
      checkAccount();
      final confirmed = results
          .where((result) => result.isSuccess)
          .map((result) => result.recipient?.value)
          .whereType<String>()
          .toSet();
      people = people
          .where((person) => !confirmed.contains(person.userId))
          .toList();
      await checkpoint();
      return people.isEmpty;
    } finally {
      busy = false;
    }
  }
}
