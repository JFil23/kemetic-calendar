// lib/features/inbox/shared_flow_details_page.dart
// Preview page for non-imported shared flows with Import button

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/shared/glossy_text.dart';
import '../../data/share_models.dart';
import '../../repositories/inbox_repo.dart';
import '../../features/calendar/calendar_page.dart' show CalendarPage, notesDecode;
import '../../widgets/flow_start_date_picker.dart';

class SharedFlowDetailsPage extends StatelessWidget {
  final InboxShareItem share;

  const SharedFlowDetailsPage({required this.share, super.key});

  @override
  Widget build(BuildContext context) {
    final payload = share.payloadJson ?? {};
    final notes = payload['notes'] as String? ?? '';
    
    // Decode notes to get overview (same pattern as _FlowDetailsPage)
    final meta = notesDecode(notes);
    final overview = meta.overview ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFD4AF37)),
        title: const Text(
          'Flow',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Title
                GlossyText(
                  text: share.title,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Overview
                if (overview.isNotEmpty) ...[
                  Text(
                    overview,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                
                // TODO: Add schedule preview based on payload['rules'] when ready
              ],
            ),
          ),
          
          // Import button
          SafeArea(
            minimum: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _onImportPressed(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Import to my calendar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onImportPressed(BuildContext context) async {
    // Determine initial date from suggested schedule or default to tomorrow
    DateTime? initial;
    if (share.suggestedSchedule != null) {
      try {
        initial = DateTime.parse(share.suggestedSchedule!.startDate);
      } catch (e) {
        // Fallback to tomorrow if parsing fails
        initial = DateTime.now().add(const Duration(days: 1));
      }
    } else {
      initial = DateTime.now().add(const Duration(days: 1));
    }

    // Show date picker
    final picked = await FlowStartDatePicker.show(
      context,
      initialDate: initial,
    );
    
    if (picked == null || !context.mounted) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
        ),
      ),
    );

    try {
      final inboxRepo = InboxRepo(Supabase.instance.client);
      final flowId = await inboxRepo.importSharedFlow(
        share: share,
        overrideStartDate: picked,
      );

      if (!context.mounted) return;

      // Close loading and preview
      Navigator.pop(context); // Close loading
      Navigator.pop(context); // Close preview

      // Navigate to Flow Studio with the imported flow
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CalendarPage(initialFlowIdToEdit: flowId),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      // Close loading
      Navigator.pop(context);

      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to import: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

