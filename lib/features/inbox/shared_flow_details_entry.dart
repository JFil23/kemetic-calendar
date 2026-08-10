// lib/features/inbox/shared_flow_details_entry.dart
// Router widget that checks if flow is imported and routes accordingly

import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/share_models.dart';
import '../../data/share_repo.dart';
import '../calendar/calendar_invalidation.dart';
import 'shared_flow_details_page.dart';

class SharedFlowDetailsEntry extends StatefulWidget {
  final InboxShareItem share;
  final String fallbackLocation;

  const SharedFlowDetailsEntry({
    super.key,
    required this.share,
    this.fallbackLocation = '/inbox',
  });

  @override
  State<SharedFlowDetailsEntry> createState() => _SharedFlowDetailsEntryState();
}

class _SharedFlowDetailsEntryState extends State<SharedFlowDetailsEntry> {
  StreamSubscription<CalendarInvalidated>? _flowLifecycleSub;
  int? _activeImportedFlowId;
  bool _usePayloadMode = false;

  @override
  void initState() {
    super.initState();
    _activeImportedFlowId = widget.share.currentlyActiveImportedFlowId;
    _flowLifecycleSub = CalendarInvalidationBus.instance.stream
        .where(
          (event) =>
              event.reason == CalendarInvalidationReason.flowEndedCommitted,
        )
        .listen((event) {
          if (!mounted || event.flowId != _activeImportedFlowId) return;
          setState(() => _activeImportedFlowId = null);
        });

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
      // 2. USE PAYLOAD MODE → render the sender snapshot, but still check
      // import status so a route-backed import cannot keep offering Import.
      // ---------------------------------------------------
      _usePayloadMode = true;
      return;
    }

    // ---------------------------------------------------
    // 3. USE FLOW-ID MODE → fallback to DB lookup
    // Only for legacy/old shares without payload_json
    // ---------------------------------------------------
    _usePayloadMode = false;
  }

  @override
  void didUpdateWidget(covariant SharedFlowDetailsEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.share.shareId != widget.share.shareId ||
        oldWidget.share.currentlyActiveImportedFlowId !=
            widget.share.currentlyActiveImportedFlowId) {
      _activeImportedFlowId = widget.share.currentlyActiveImportedFlowId;
    }
    _usePayloadMode = widget.share.payloadJson?.isNotEmpty ?? false;
  }

  @override
  void dispose() {
    _flowLifecycleSub?.cancel();
    super.dispose();
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
          debugPrint('[SharedFlowDetailsEntry] Failed to mark viewed: $e');
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
        importedFlowId: _activeImportedFlowId,
        fallbackLocation: widget.fallbackLocation,
      );
    }

    // ----------------------------------
    // FLOW-ID MODE → use the inbox item's canonical current-state filing
    // ----------------------------------
    final flowId = _activeImportedFlowId;
    if (flowId != null) {
      return SharedFlowDetailsPage(
        flowId: flowId,
        fallbackLocation: widget.fallbackLocation,
      );
    }

    return SharedFlowDetailsPage(
      share: widget.share,
      fallbackLocation: widget.fallbackLocation,
    );
  }
}
