import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/profile_repo.dart';
import '../../../data/share_models.dart';
import '../../../data/share_repo.dart';
import '../../../repositories/inbox_repo.dart';
import '../../../repositories/dm_conversation_repo.dart';
import '../../profile/profile_search_page.dart';
import 'inbox_message_actions.dart';

class InboxReplyTarget {
  const InboxReplyTarget({
    required this.id,
    required this.kind,
    required this.text,
  });
  final String id;
  final String kind;
  final String text;
}

/// Route adapters supply identity and state callbacks. All message actions use
/// the existing account repositories, with one presentation/confirmation owner.
class InboxMessageActionHost extends StatelessWidget {
  const InboxMessageActionHost({
    super.key,
    required this.target,
    required this.createdAt,
    required this.isMine,
    required this.isText,
    required this.child,
    required this.onReply,
    required this.onRemoved,
    this.onTap,
    this.onDoubleTap,
  });
  final InboxReplyTarget target;
  final DateTime createdAt;
  final bool isMine;
  final bool isText;
  final Widget child;
  final ValueChanged<InboxReplyTarget> onReply;
  final VoidCallback onRemoved;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;

  Future<void> _run(
    BuildContext context,
    Future<void> Function() operation, {
    String? success,
  }) async {
    final account = Supabase.instance.client.auth.currentUser?.id;
    try {
      await operation();
      if (context.mounted &&
          account == Supabase.instance.client.auth.currentUser?.id &&
          success != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(success)));
      }
    } catch (_) {
      if (context.mounted &&
          account == Supabase.instance.client.auth.currentUser?.id) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not complete this action. Please try again.'),
          ),
        );
      }
    }
  }

  Future<void> _remove(BuildContext context, bool unsend) async {
    final account = Supabase.instance.client.auth.currentUser?.id;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(unsend ? 'Unsend this message?' : 'Delete for me?'),
        content: Text(
          unsend
              ? 'This removes the message for everyone. They may have already seen it.'
              : 'This removes the message from your Inbox only.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              unsend ? 'Unsend' : 'Delete for me',
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true ||
        !context.mounted ||
        account != Supabase.instance.client.auth.currentUser?.id) {
      return;
    }
    await _run(context, () async {
      final client = Supabase.instance.client;
      if (target.kind == 'dm') {
        await DmConversationRepo(
          client,
        ).actOnMessage(target.id, unsend: unsend);
      } else {
        await ShareRepo(
          client,
        ).actOnInboxMessage(target.kind, target.id, unsend: unsend);
      }
      if (context.mounted && account == client.auth.currentUser?.id) {
        onRemoved();
      }
    });
  }

  Future<void> _forward(BuildContext context) async {
    final account = Supabase.instance.client.auth.currentUser?.id;
    final recipient = await Navigator.of(context).push<UserSearchResult>(
      MaterialPageRoute(
        builder: (_) => const ProfileSearchPage(
          selectionMode: 'picker',
          returnFullResult: true,
          titleText: 'Forward to',
          fallbackLocation: '/inbox',
        ),
      ),
    );
    if (recipient == null ||
        !context.mounted ||
        account != Supabase.instance.client.auth.currentUser?.id) {
      return;
    }
    // Choosing a person is followed by a concrete send confirmation.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forward message?'),
        content: Text(
          target.text,
          maxLines: 6,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (confirmed != true ||
        !context.mounted ||
        account != Supabase.instance.client.auth.currentUser?.id) {
      return;
    }
    await _run(context, () async {
      final client = Supabase.instance.client;
      if (isText) {
        await InboxRepo(
          client,
        ).sendTextMessage(recipientId: recipient.userId, text: target.text);
      } else {
        final result = await ShareRepo(client).shareFlow(
          sourceShareId: target.id,
          recipients: [
            ShareRecipient(
              type: ShareRecipientType.user,
              value: recipient.userId,
            ),
          ],
        );
        if (result.length != 1 || !result.single.isSuccess) {
          throw StateError('Forward not acknowledged');
        }
      }
    }, success: 'Message forwarded');
  }

  @override
  Widget build(BuildContext context) => InboxMessageActions(
    createdAt: createdAt,
    onTap: onTap,
    onDoubleTap: onDoubleTap,
    onReply: () => onReply(target),
    onForward: isText || target.kind == 'flow' ? () => _forward(context) : null,
    onCopy: () => _run(
      context,
      () => Clipboard.setData(ClipboardData(text: target.text)),
      success: 'Copied',
    ),
    onDeleteForMe: () => _remove(context, false),
    onUnsend: isMine ? () => _remove(context, true) : null,
    child: child,
  );
}
