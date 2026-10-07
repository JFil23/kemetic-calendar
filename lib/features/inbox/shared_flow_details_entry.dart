import 'package:flutter/material.dart';

import '../../data/share_models.dart';
import 'shared_flow_details_page.dart';

/// Inbox data adapter. FlowDetail's canonical builders own all presentation,
/// account hydration, actions, and lifecycle; Inbox has no detail design.
class SharedFlowDetailsEntry extends StatelessWidget {
  const SharedFlowDetailsEntry({
    super.key,
    required this.share,
    this.fallbackLocation = '/inbox',
  });

  final InboxShareItem share;
  final String fallbackLocation;

  @override
  Widget build(BuildContext context) {
    if ((share.payloadJson?.isEmpty ?? true) &&
        share.currentlyActiveImportedFlowId != null) {
      return SharedFlowDetailsPage(
        flowId: share.currentlyActiveImportedFlowId,
        fallbackLocation: fallbackLocation,
      );
    }
    return SharedFlowDetailsPage(
      share: share,
      importedFlowId: share.currentlyActiveImportedFlowId,
      fallbackLocation: fallbackLocation,
    );
  }
}
