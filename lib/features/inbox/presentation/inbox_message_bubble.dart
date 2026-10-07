import 'package:flutter/material.dart';
import 'inbox_message_actions.dart';
import '../../../shared/glossy_text.dart';
import '../../../widgets/kemetic_heart_icon.dart';

class InboxMessageBubble extends StatelessWidget {
  final String text;
  final DateTime createdAt;
  final bool isMine;
  final int likesCount;
  final bool likedByMe;
  final bool likeUpdating;
  final bool failed;
  final String? replyText;

  const InboxMessageBubble({
    super.key,
    required this.text,
    required this.createdAt,
    required this.isMine,
    required this.likesCount,
    required this.likedByMe,
    required this.likeUpdating,
    this.failed = false,
    this.replyText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: const BoxConstraints(maxWidth: 320),
      decoration: BoxDecoration(
        color: isMine
            ? KemeticGold.base.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMine
              ? KemeticGold.base.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (replyText != null) InboxReplyPreview(text: replyText!),
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 15,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatTime(createdAt),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 11,
                ),
              ),
              if (likeUpdating) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 11,
                  height: 11,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.redAccent),
                  ),
                ),
              ] else if (failed) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.error_outline,
                  size: 12,
                  color: Colors.redAccent,
                ),
                const SizedBox(width: 3),
                const Text(
                  'Not sent',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ] else if (likesCount > 0) ...[
                const SizedBox(width: 8),
                KemeticHeartIcon(
                  size: 12,
                  color: likedByMe
                      ? Colors.redAccent
                      : Colors.redAccent.withValues(alpha: 0.75),
                ),
                if (likesCount > 1) ...[
                  const SizedBox(width: 3),
                  Text(
                    '$likesCount',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime date) {
    final localDate = date.toLocal();
    final now = DateTime.now();
    final diff = now.difference(localDate);

    if (diff.inDays == 0) {
      final hours = localDate.hour % 12 == 0 ? 12 : localDate.hour % 12;
      final minutes = localDate.minute.toString().padLeft(2, '0');
      final suffix = localDate.hour >= 12 ? 'PM' : 'AM';
      return '$hours:$minutes $suffix';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${localDate.month}/${localDate.day}/${localDate.year}';
    }
  }
}
