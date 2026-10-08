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
    this.conversationId,
  });
  final String id;
  final String kind;
  final String text;
  final String? conversationId;
}

/// Route adapters supply identity and state callbacks. All message actions use
/// the existing account repositories, with one presentation/confirmation owner.
class InboxMessageActionHost extends StatefulWidget {
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

  @override
  State<InboxMessageActionHost> createState() => _InboxMessageActionHostState();
}

class _InboxMessageActionHostState extends State<InboxMessageActionHost> {
  bool _removing = false;

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
    if (_removing) return;
    setState(() => _removing = true);
    try {
      await _run(context, () async {
        final client = Supabase.instance.client;
        if (widget.target.kind == 'dm') {
          await DmConversationRepo(client).actOnMessage(
            widget.target.id,
            unsend: unsend,
            conversationId: widget.target.conversationId,
          );
        } else {
          await ShareRepo(client).actOnInboxMessage(
            widget.target.kind,
            widget.target.id,
            unsend: unsend,
          );
        }
        if (context.mounted && account == client.auth.currentUser?.id) {
          widget.onRemoved();
        }
      });
    } finally {
      if (mounted) setState(() => _removing = false);
    }
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
          widget.target.text,
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
      if (widget.isText) {
        await InboxRepo(client).sendTextMessage(
          recipientId: recipient.userId,
          text: widget.target.text,
        );
      } else {
        final result = await ShareRepo(client).shareFlow(
          sourceShareId: widget.target.id,
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
  Widget build(BuildContext context) => _removing
      ? const SizedBox.shrink()
      : InboxMessageActions(
          createdAt: widget.createdAt,
          onTap: widget.onTap,
          onDoubleTap: widget.onDoubleTap,
          onReply: () => widget.onReply(widget.target),
          onForward: widget.isText || widget.target.kind == 'flow'
              ? () => _forward(context)
              : null,
          onCopy: () => _run(
            context,
            () => Clipboard.setData(ClipboardData(text: widget.target.text)),
            success: 'Copied',
          ),
          onDeleteForMe: () => _remove(context, false),
          onUnsend: widget.isMine ? () => _remove(context, true) : null,
          child: widget.child,
        );
}
