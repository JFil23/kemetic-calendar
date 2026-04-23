// lib/widgets/inbox_icon_with_badge.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/share_repo.dart';
import '../features/inbox/inbox_page.dart';
import '../shared/glossy_text.dart';

class InboxUnreadDotOverlay extends StatelessWidget {
  final Widget child;
  final double top;
  final double right;
  final double size;
  final Color dotColor;
  final Color borderColor;
  final double borderWidth;

  const InboxUnreadDotOverlay({
    super.key,
    required this.child,
    this.top = -2,
    this.right = -2,
    this.size = 10,
    this.dotColor = Colors.redAccent,
    this.borderColor = Colors.black,
    this.borderWidth = 1.5,
  });

  @override
  Widget build(BuildContext context) {
    final shareRepo = ShareRepo(Supabase.instance.client);
    return StreamBuilder<InboxUnreadState>(
      initialData: shareRepo.currentUnreadState,
      stream: shareRepo.watchUnreadState(),
      builder: (context, snapshot) {
        final show = (snapshot.data ?? const InboxUnreadState()).hasUnread;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            if (show)
              Positioned(
                top: top,
                right: right,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: borderColor, width: borderWidth),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class InboxIconWithBadge extends StatelessWidget {
  final Color iconColor;
  final VoidCallback?
  onRefreshSync; // ✅ Keep original for backward compatibility
  final Future<void> Function(dynamic)? onRefreshAsync; // ✅ New async version
  final Future<void> Function(int? importedFlowId)?
  onImportFlow; // ✅ Import callback

  const InboxIconWithBadge({
    super.key,
    this.iconColor = KemeticGold.base,
    this.onRefreshSync,
    this.onRefreshAsync,
    this.onImportFlow,
  });

  @override
  Widget build(BuildContext context) {
    final shareRepo = ShareRepo(Supabase.instance.client);
    return StreamBuilder<InboxUnreadState>(
      initialData: shareRepo.currentUnreadState,
      stream: shareRepo.watchUnreadState(),
      builder: (context, snapshot) {
        final unreadCount =
            (snapshot.data ?? const InboxUnreadState()).totalUnread;
        final useGoldGradient = iconColor == KemeticGold.base;
        final Widget iconWidget = useGoldGradient
            ? KemeticGold.icon(Icons.mail_outline)
            : Icon(Icons.mail_outline, color: iconColor);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: iconWidget,
              tooltip: 'Inbox',
              onPressed: () async {
                final importedFlowId = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const InboxPage()),
                );

                // Handle import callback first
                if (onImportFlow != null && importedFlowId != null) {
                  await onImportFlow!(importedFlowId);
                }

                // Handle both refresh callback types
                if (onRefreshAsync != null) {
                  await onRefreshAsync!(importedFlowId);
                } else if (onRefreshSync != null) {
                  onRefreshSync!();
                }
              },
            ),
            if (unreadCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
