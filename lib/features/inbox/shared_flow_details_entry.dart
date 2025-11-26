// lib/features/inbox/shared_flow_details_entry.dart
// Router widget that checks if flow is imported and routes accordingly

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/share_models.dart';
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

    final payload = widget.share.payloadJson;

    // ---------------------------------------------------
    // 1. Determine whether the payload is actually usable
    // ---------------------------------------------------
    final hasValidPayload = payload != null &&
        payload.isNotEmpty &&
        payload.containsKey('name') &&
        payload['name'] != null;

    if (hasValidPayload) {
      // ---------------------------------------------------
      // 2. USE PAYLOAD MODE → no DB calls at all
      // ---------------------------------------------------
      _usePayloadMode = true;
      _flowIdFuture = null;
      return;
    }

    // ---------------------------------------------------
    // 3. USE FLOW-ID MODE → fallback to DB lookup
    // ---------------------------------------------------
    _usePayloadMode = false;

    final repo = UserEventsRepo(Supabase.instance.client);

    _flowIdFuture = repo
        .getFlowIdByShareId(widget.share.shareId)
        .timeout(
          const Duration(seconds: 6),
          onTimeout: () {
            if (kDebugMode) {
              print(
                  "[SharedFlowDetailsEntry] getFlowIdByShareId TIMEOUT for shareId=${widget.share.shareId}");
            }
            return null;
          },
        );
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
