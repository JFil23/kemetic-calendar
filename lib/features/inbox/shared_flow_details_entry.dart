// lib/features/inbox/shared_flow_details_entry.dart
// Router widget that checks if flow is imported and routes accordingly

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/share_models.dart';
import '../../data/share_repo.dart';
import '../../data/user_events_repo.dart';
import 'shared_flow_details_page.dart';

class SharedFlowDetailsEntry extends StatefulWidget {
  final InboxShareItem share;

  const SharedFlowDetailsEntry({
    Key? key,
    required this.share,
  }) : super(key: key);

  @override
  State<SharedFlowDetailsEntry> createState() => _SharedFlowDetailsEntryState();
}

class _SharedFlowDetailsEntryState extends State<SharedFlowDetailsEntry> {
  Future<int?>? _flowIdFuture;
  bool _usePayloadMode = false;

  @override
  void initState() {
    super.initState();

    // Mark as viewed if current user is the recipient
    _markAsViewedIfRecipient();

    final payload = widget.share.payloadJson;

    // ---------------------------------------------------
    // 1. Determine whether the payload is actually usable
    // ✅ FIXED: Loosened check - use payload if it exists and is not empty
    // (Don't require specific keys like 'name' - payload may have events/rules even if name is missing)
    // ---------------------------------------------------
    final hasValidPayload = payload != null && payload.isNotEmpty;

    if (kDebugMode) {
      debugPrint('[SharedFlowDetailsEntry] share ${widget.share.shareId}');
      debugPrint('  hasValidPayload=$hasValidPayload');
      debugPrint('  payload keys=${payload?.keys.toList()}');
    }

    if (hasValidPayload) {
      // ---------------------------------------------------
      // 2. USE PAYLOAD MODE → no DB calls at all
      // Always prefer payload when present (sender's snapshot)
      // ---------------------------------------------------
      _usePayloadMode = true;
      _flowIdFuture = null;
      return;
    }

    // ---------------------------------------------------
    // 3. USE FLOW-ID MODE → fallback to DB lookup
    // Only for legacy/old shares without payload_json
    // ---------------------------------------------------
    _usePayloadMode = false;

    final repo = UserEventsRepo(Supabase.instance.client);

    _flowIdFuture = repo
        .getFlowIdByShareId(widget.share.shareId)
        .timeout(
          const Duration(seconds: 6),
          onTimeout: () {
            if (kDebugMode) {
              debugPrint(
                  "[SharedFlowDetailsEntry] getFlowIdByShareId TIMEOUT for shareId=${widget.share.shareId}");
            }
            return null;
          },
        );
  }

  /// Mark the share as viewed if the current user is the recipient
  Future<void> _markAsViewedIfRecipient() async {
    final share = widget.share;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    if (currentUserId == null) return;

    // Only if I'm the recipient and it hasn't been marked yet
    if (share.recipientId == currentUserId && share.viewedAt == null) {
      final repo = ShareRepo(Supabase.instance.client);
      try {
        await repo.markViewed(share.shareId, isFlow: share.isFlow);

        if (kDebugMode) {
          debugPrint(
            '[SharedFlowDetailsEntry] Marked share ${share.shareId} as viewed',
          );
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            '[SharedFlowDetailsEntry] Failed to mark viewed: $e',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ----------------------------------
    // PAYLOAD MODE → instant UI rendering
    // ----------------------------------
    if (_usePayloadMode) {
      return SharedFlowDetailsPage(
        share: widget.share,
      );
    }

    // ----------------------------------
    // FLOW-ID MODE → wait for database query
    // ----------------------------------
    return FutureBuilder<int?>(
      future: _flowIdFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(backgroundColor: Colors.black),
            body: Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final flowId = snapshot.data;

        if (flowId != null) {
          return SharedFlowDetailsPage(flowId: flowId);
        }

        // ---------------------------------------------------
        // 4. LAST RESORT:
        // If DB lookup failed, fallback to payload anyway
        // (User still sees something instead of infinite spinner)
        // ---------------------------------------------------
        return SharedFlowDetailsPage(
          share: widget.share,
        );
      },
    );
  }
}
