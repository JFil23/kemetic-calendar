// lib/features/inbox/shared_flow_details_entry.dart
// Router widget that checks if flow is imported and routes accordingly

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/share_models.dart';
import '../../data/user_events_repo.dart';
import '../../features/calendar/calendar_page.dart';
import 'shared_flow_details_page.dart';

class SharedFlowDetailsEntry extends StatefulWidget {
  final InboxShareItem share;

  const SharedFlowDetailsEntry({required this.share, super.key});

  @override
  State<SharedFlowDetailsEntry> createState() => _SharedFlowDetailsEntryState();
}

class _SharedFlowDetailsEntryState extends State<SharedFlowDetailsEntry> {
  late final Future<int?> _flowIdFuture;

  @override
  void initState() {
    super.initState();
    final userEventsRepo = UserEventsRepo(Supabase.instance.client);
    _flowIdFuture = userEventsRepo.getFlowIdByShareId(widget.share.shareId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int?>(
      future: _flowIdFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: const Color(0xFF000000),
              iconTheme: const IconThemeData(color: Color(0xFFD4AF37)),
            ),
            backgroundColor: const Color(0xFF000000),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Color(0xFF000000),
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
              ),
            ),
          );
        }

        final flowId = snapshot.data;
        if (flowId != null) {
          // Already imported → show same Flow Details as "My Flows"
          // This opens Flow Studio (editor) directly
          return CalendarPage(
            initialFlowIdToEdit: flowId,
          );
        }

        // Not imported yet → show shared preview with Import button
        return SharedFlowDetailsPage(share: widget.share);
      },
    );
  }
}

