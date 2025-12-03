// lib/widgets/inbox_icon_with_badge.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/share_repo.dart';
import '../features/inbox/inbox_page.dart';

class InboxIconWithBadge extends StatelessWidget {
  final Color iconColor;
  final VoidCallback? onRefreshSync; // ✅ Keep original for backward compatibility
  final Future<void> Function(dynamic)? onRefreshAsync; // ✅ New async version
  final Future<void> Function(int? importedFlowId)? onImportFlow; // ✅ Import callback

  const InboxIconWithBadge({
    Key? key,
    this.iconColor = const Color(0xFFD4AF37),
    this.onRefreshSync,
    this.onRefreshAsync,
    this.onImportFlow,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: ShareRepo(Supabase.instance.client).watchUnreadCount(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;
        
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: Icon(Icons.mail_outline, color: iconColor),
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



