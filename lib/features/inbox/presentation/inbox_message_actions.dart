import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

/// One lifted-message menu for every Inbox conversation. The route supplies
/// verified capabilities; this owner controls their presentation and dismissal.
class InboxMessageActions extends StatelessWidget {
  const InboxMessageActions({
    super.key,
    required this.child,
    required this.createdAt,
    this.onTap,
    this.onDoubleTap,
    this.onReply,
    this.onForward,
    this.onCopy,
    this.onDeleteForMe,
    this.onUnsend,
    this.onRetry,
  });

  final Widget child;
  final DateTime createdAt;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onReply;
  final VoidCallback? onForward;
  final VoidCallback? onCopy;
  final VoidCallback? onDeleteForMe;
  final VoidCallback? onUnsend;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Builder(
    builder: (anchorContext) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onLongPress: () => _open(anchorContext),
      child: child,
    ),
  );

  void _open(BuildContext context) {
    final box = context.findRenderObject()! as RenderBox;
    final anchor = box.localToGlobal(Offset.zero) & box.size;
    final themes = InheritedTheme.capture(
      from: context,
      to: Navigator.of(context, rootNavigator: true).context,
    );
    HapticFeedback.selectionClick();
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss message actions',
      barrierColor: Colors.black38,
      transitionDuration: const Duration(milliseconds: 160),
      transitionBuilder: (context, animation, secondary, child) =>
          FadeTransition(opacity: animation, child: child),
      pageBuilder: (context, animation, secondaryAnimation) => themes.wrap(
        Builder(
          builder: (context) {
            final media = MediaQuery.of(context);
            final width = (media.size.width - 40).clamp(0.0, 360.0);
            final height = media.size.height - media.padding.vertical - 32;
            final previewHeight = (height * .35).clamp(50.0, 280.0);
            final left = anchor.right > media.size.width / 2
                ? (anchor.right - width).clamp(
                    20.0,
                    media.size.width - width - 20,
                  )
                : 20.0;
            final top = anchor.top.clamp(
              media.padding.top + 16,
              (media.size.height - media.padding.bottom - previewHeight - 350)
                  .clamp(media.padding.top + 16, media.size.height),
            );
            Widget action(
              String label,
              IconData icon,
              VoidCallback callback, {
              bool destructive = false,
            }) => InkWell(
              onTap: () {
                Navigator.of(context).pop();
                callback();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 13,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 16,
                          color: destructive ? Colors.redAccent : Colors.white,
                        ),
                      ),
                    ),
                    Icon(
                      icon,
                      size: 20,
                      color: destructive ? Colors.redAccent : Colors.white70,
                    ),
                  ],
                ),
              ),
            );
            final local = createdAt.toLocal();
            final date = MaterialLocalizations.of(
              context,
            ).formatMediumDate(local);
            final time = MaterialLocalizations.of(
              context,
            ).formatTimeOfDay(TimeOfDay.fromDateTime(local));
            // The scrolling preview is wider than the visible action menu.
            // Own outside taps here so its transparent areas cannot swallow
            // them before they reach the route's modal barrier.
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTap: () => Navigator.of(context).pop(),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                      child: const SizedBox.expand(),
                    ),
                  ),
                  Positioned(
                    left: left,
                    top: top,
                    width: width,
                    child: Material(
                      type: MaterialType.transparency,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight:
                              media.size.height -
                              media.padding.bottom -
                              top -
                              16,
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment:
                                anchor.center.dx > media.size.width / 2
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight: previewHeight,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: SingleChildScrollView(
                                    child: IgnorePointer(child: child),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                excludeFromSemantics: true,
                                // Menu chrome is inside the menu; action rows
                                // retain their own tap handlers below it.
                                onTap: () {},
                                child: Container(
                                  width: 250,
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF242426),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Text(
                                          '$date · $time',
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      if (onRetry != null)
                                        action(
                                          'Retry',
                                          Icons.refresh,
                                          onRetry!,
                                        ),
                                      if (onReply != null)
                                        action('Reply', Icons.reply, onReply!),
                                      if (onForward != null)
                                        action(
                                          'Forward',
                                          Icons.forward,
                                          onForward!,
                                        ),
                                      if (onCopy != null)
                                        action(
                                          'Copy',
                                          Icons.copy_outlined,
                                          onCopy!,
                                        ),
                                      if (onDeleteForMe != null)
                                        action(
                                          'Delete for me',
                                          Icons.delete_outline,
                                          onDeleteForMe!,
                                        ),
                                      if (onUnsend != null)
                                        action(
                                          'Unsend',
                                          Icons.undo,
                                          onUnsend!,
                                          destructive: true,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The same quoted context in the composer and the delivered message.
class InboxReplyPreview extends StatelessWidget {
  const InboxReplyPreview({super.key, required this.text, this.onCancel});
  final String text;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
    decoration: const BoxDecoration(
      border: Border(left: BorderSide(color: Color(0xFFD1AF32), width: 2)),
      color: Color(0xFF171719),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Replying to',
                style: TextStyle(fontSize: 11, color: Color(0xFFD1AF32)),
              ),
              Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: Colors.white70),
              ),
            ],
          ),
        ),
        if (onCancel != null)
          IconButton(
            tooltip: 'Cancel reply',
            onPressed: onCancel,
            icon: const Icon(Icons.close, size: 18, color: Colors.white70),
          ),
      ],
    ),
  );
}
